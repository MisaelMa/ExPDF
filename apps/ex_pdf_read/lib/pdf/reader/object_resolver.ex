defmodule Pdf.Reader.ObjectResolver do
  @moduledoc """
  Lazy indirect-object resolver with Map-based cache.

  Per the design (`sdd/pdf-reader-core/design` § 5 "Lazy Resolution Contract"):

  - **Cache**: a plain `Map` on `%Pdf.Reader.Document{}.cache`. No GenServer.
    Key: `{obj_num, gen_num}`. Value: the resolved Elixir term.
  - **Signature**: `resolve(doc, {:ref, n, g}) :: {:ok, value, doc} | {:error, reason}`.
    The returned `doc` carries the updated cache. The caller threads `doc` forward
    for cache benefit; dropping the updated doc still yields correct results on
    the next call (re-parse, same value — the binary is immutable).
  - **Idempotent**: calling `resolve/2` twice on the same ref with the same doc
    returns the same value. The cache is a hint, not state.

  ## Resolution paths

  1. **Cache hit**: `Map.get(doc.cache, {n, g})` → immediate return.
  2. **In-use (classic)**: look up `{n, g}` in `doc.xref` → `{:in_use, offset, _gen}`.
     Slice `binary_part(doc.binary, offset, ...)`, run `Parser.parse_object/1`.
  3. **Compressed (ObjStm)**: look up `{n, g}` → `{:compressed, objstm_n, index}`.
     Recursively `resolve(doc, {:ref, objstm_n, 0})`, decode filters, then
     `ObjectStream.fetch/3`.
  4. **Free / absent**: `{:error, {:unresolved_ref, {n, g}}}`.

  ## Ref chasing

  `resolve/2` does **NOT** automatically follow nested refs. If a resolved value
  is itself `{:ref, _, _}`, the caller decides whether to chase it. This avoids
  infinite loops on circular references and keeps the interface predictable.
  """

  alias Pdf.Reader.{Document, Filter, ObjectStream, Parser}
  alias Pdf.Reader.Encryption.{StandardHandler, V1V2, V4, V5}

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Resolve an indirect object reference to its value.

  Returns `{:ok, value, updated_doc}` on success, where `updated_doc` has
  the resolved value cached. Returns `{:error, reason}` on failure.

  The caller should thread the returned `doc` forward to benefit from caching
  on subsequent resolutions.

  ## Error reasons

  - `{:error, {:unresolved_ref, {n, g}}}` — ref is absent from xref or is a free entry.
  - `{:error, :malformed}` — parse failure.
  - `{:error, {:unsupported_filter, name}}` — propagated from filter chain.
  """
  @spec resolve(Document.t(), {:ref, pos_integer(), non_neg_integer()}) ::
          {:ok, term(), Document.t()} | {:error, term()}
  def resolve(%Document{} = doc, {:ref, n, g}) do
    key = {n, g}

    case Map.get(doc.cache, key) do
      nil ->
        # Cache miss — look up in xref and resolve from binary.
        do_resolve(doc, key)

      value ->
        # Cache hit — return immediately, doc unchanged.
        {:ok, value, doc}
    end
  end

  # ---------------------------------------------------------------------------
  # Internal — xref dispatch
  # ---------------------------------------------------------------------------

  defp do_resolve(doc, {n, g} = key) do
    case Map.get(doc.xref, key) do
      nil ->
        {:error, {:unresolved_ref, {n, g}}}

      :free ->
        {:error, {:unresolved_ref, {n, g}}}

      {:in_use, offset, _gen} ->
        resolve_in_use(doc, key, offset)

      {:compressed, objstm_n, index} ->
        resolve_compressed(doc, key, objstm_n, index)
    end
  end

  # ---------------------------------------------------------------------------
  # Internal — in-use resolution path
  # ---------------------------------------------------------------------------

  defp resolve_in_use(doc, {n, g} = key, offset) do
    total = byte_size(doc.binary)

    if offset >= total do
      {:error, {:unresolved_ref, key}}
    else
      # Slice from offset to end of binary (Parser reads until endobj).
      slice = binary_part(doc.binary, offset, total - offset)

      case Parser.parse_object(slice) do
        {:ok, _ref, value, _rest} ->
          # R-ENC9: decryption hook MUST be here, AFTER parse, BEFORE cache write.
          # R-ENC11: when doc.encryption is nil, skip entirely — no perf regression.
          value = maybe_decrypt_value(value, n, g, doc.encryption)
          # Cache the resolved (and possibly decrypted) value.
          updated_doc = %{doc | cache: Map.put(doc.cache, key, value)}
          {:ok, value, updated_doc}

        {:error, _} ->
          {:error, :malformed}
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Internal — compressed resolution path (ObjStm)
  # ---------------------------------------------------------------------------

  # Per design § 5: ObjStm resolution steps:
  # 1. Recursively resolve the ObjStm object itself → {:stream, dict, raw_bytes}.
  #    The ObjStm stream's raw bytes are decrypted by resolve_in_use/3 (the encryption
  #    hook fires there). After that point the ObjStm body is already plaintext.
  # 2. Apply filter chain to decode the body.
  # 3. Call ObjectStream.fetch/3 with decoded body, /First, and index.
  # 4. Cache the result and return.
  #
  # INVARIANT (R-ENC10): This function MUST NOT apply any decryption to inner
  # objects. Objects extracted from an ObjStm are already plaintext after the
  # ObjStm stream itself was decrypted in step 1. Decrypting them here would
  # corrupt their values (double-decryption). Never add a decrypt_value call
  # anywhere in this function.
  defp resolve_compressed(doc, key, objstm_n, index) do
    with {:ok, stream_value, doc2} <- resolve(doc, {:ref, objstm_n, 0}),
         {:stream, dict, raw_body} <- ensure_stream(stream_value),
         {:ok, decoded_body} <- decode_stream_body(dict, raw_body),
         {:ok, first} <- extract_first(dict),
         {:ok, value} <- ObjectStream.fetch(first, decoded_body, index) do
      # Cache the compressed object under its own key.
      updated_doc = %{doc2 | cache: Map.put(doc2.cache, key, value)}
      {:ok, value, updated_doc}
    else
      {:error, _} = err -> err
      :not_a_stream -> {:error, {:objstm_unsupported, :not_a_stream}}
    end
  end

  defp ensure_stream({:stream, _, _} = stream), do: stream
  defp ensure_stream(_), do: :not_a_stream

  # Decode the ObjStm stream body through the filter chain.
  # Filter names may be {:name, binary()} tuples (from the parser) or plain strings.
  # Filter.apply_chain/3 handles both via its internal resolve_module/1.
  defp decode_stream_body(dict, raw_body) do
    filter = Map.get(dict, "Filter")
    parms = Map.get(dict, "DecodeParms")

    if is_nil(filter) do
      {:ok, raw_body}
    else
      Filter.apply_chain(raw_body, filter, parms || %{})
    end
  end

  defp extract_first(dict) do
    case Map.get(dict, "First") do
      v when is_integer(v) -> {:ok, v}
      _ -> {:error, {:objstm_unsupported, :missing_first}}
    end
  end

  # ---------------------------------------------------------------------------
  # Encryption value walker (R-ENC9, R-ENC11, R-ENC12, R-ENC16)
  # ---------------------------------------------------------------------------

  # R-ENC11: when encryption is nil, return value unchanged — no branches executed.
  defp maybe_decrypt_value(value, _obj_num, _gen_num, nil), do: value

  # Dispatch by handler version to the correct decrypt module.
  defp maybe_decrypt_value(value, obj_num, gen_num, %StandardHandler{} = handler) do
    decrypt_value(value, obj_num, gen_num, handler)
  end

  # Streams: decrypt raw_bytes, recurse into dict for embedded strings (R-ENC12, R-ENC16).
  # R-ENC15: /EncryptMetadata false and /Identity crypt filter short-circuit in V4/V5.
  # The stream dict may contain string values (e.g. /Author) that must also be decrypted.
  defp decrypt_value({:stream, dict, raw_bytes}, obj_num, gen_num, handler) do
    # Decrypt the stream bytes using the version-appropriate function.
    decrypted_bytes =
      case do_decrypt_stream(raw_bytes, dict, obj_num, gen_num, handler) do
        {:ok, plain} -> plain
        # On error (e.g. bad PKCS7 padding with wrong key), keep ciphertext intact
        # to avoid masking authentication failures with crashes.
        _ -> raw_bytes
      end

    # Recurse into the stream dict to decrypt any embedded string values.
    decrypted_dict = decrypt_dict_values(dict, obj_num, gen_num, handler)
    {:stream, decrypted_dict, decrypted_bytes}
  end

  # Dicts: recurse into values, decrypting every string leaf (R-ENC16).
  defp decrypt_value(dict, obj_num, gen_num, handler) when is_map(dict) do
    decrypt_dict_values(dict, obj_num, gen_num, handler)
  end

  # Arrays: recurse into each element (R-ENC16).
  defp decrypt_value(list, obj_num, gen_num, handler) when is_list(list) do
    Enum.map(list, &decrypt_value(&1, obj_num, gen_num, handler))
  end

  # String values: decrypt using per-object key (R-ENC16).
  defp decrypt_value({:string, bytes}, obj_num, gen_num, handler) when is_binary(bytes) do
    case do_decrypt_string(bytes, obj_num, gen_num, handler) do
      {:ok, plain} -> {:string, plain}
      _ -> {:string, bytes}
    end
  end

  defp decrypt_value({:hex_string, bytes}, obj_num, gen_num, handler) when is_binary(bytes) do
    case do_decrypt_string(bytes, obj_num, gen_num, handler) do
      {:ok, plain} -> {:hex_string, plain}
      _ -> {:hex_string, bytes}
    end
  end

  # Plain values (numbers, bools, names, refs, null, atoms) pass through unchanged.
  defp decrypt_value(value, _obj_num, _gen_num, _handler), do: value

  # ---------------------------------------------------------------------------
  # Dict recursion — decrypt all string values in a dict map
  # ---------------------------------------------------------------------------

  defp decrypt_dict_values(dict, obj_num, gen_num, handler) when is_map(dict) do
    Map.new(dict, fn {k, v} ->
      {k, decrypt_value(v, obj_num, gen_num, handler)}
    end)
  end

  # ---------------------------------------------------------------------------
  # Version dispatch for stream decryption
  # ---------------------------------------------------------------------------

  defp do_decrypt_stream(bytes, stream_dict, obj_num, gen_num, %StandardHandler{version: v} = h)
       when v in [1, 2] do
    V1V2.decrypt_stream(bytes, stream_dict, obj_num, gen_num, h)
  end

  defp do_decrypt_stream(bytes, stream_dict, obj_num, gen_num, %StandardHandler{version: 4} = h) do
    V4.decrypt_stream(bytes, stream_dict, obj_num, gen_num, h)
  end

  defp do_decrypt_stream(bytes, stream_dict, obj_num, gen_num, %StandardHandler{version: 5} = h) do
    V5.decrypt_stream(bytes, stream_dict, obj_num, gen_num, h)
  end

  defp do_decrypt_stream(bytes, _stream_dict, _obj_num, _gen_num, _handler), do: {:ok, bytes}

  # ---------------------------------------------------------------------------
  # Version dispatch for string decryption
  # ---------------------------------------------------------------------------

  defp do_decrypt_string(bytes, obj_num, gen_num, %StandardHandler{version: v} = h)
       when v in [1, 2] do
    V1V2.decrypt_string(bytes, obj_num, gen_num, h)
  end

  defp do_decrypt_string(bytes, obj_num, gen_num, %StandardHandler{version: 4} = h) do
    V4.decrypt_string(bytes, obj_num, gen_num, h)
  end

  defp do_decrypt_string(bytes, obj_num, gen_num, %StandardHandler{version: 5} = h) do
    V5.decrypt_string(bytes, obj_num, gen_num, h)
  end

  defp do_decrypt_string(bytes, _obj_num, _gen_num, _handler), do: {:ok, bytes}
end
