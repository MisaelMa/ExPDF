defmodule Pdf.Reader.XRef do
  @moduledoc """
  Facade that dispatches to the appropriate xref reader and follows /Prev chains.

  ## Dispatch logic (PDF 1.7 § 7.5.8)

  At a given `startxref` offset, peeks at the first non-whitespace bytes:

  - Starts with `xref` → **classic** xref table (§ 7.5.4). Delegates to
    `Pdf.Reader.XRef.Classic`.
  - Starts with digits matching `N G obj` → **xref stream** (§ 7.5.8).
    Delegates to `Pdf.Reader.XRef.Stream`.

  Both formats carry `/Prev` chain links that reference older xref sections.
  Those are followed recursively, with newer entries overriding older ones.

  ## Hybrid PDFs

  Incremental updates may mix classic and stream xrefs in the same /Prev chain.
  `load/2` handles this transparently by dispatching each chain link independently.

  ## Linear scan recovery (PDF 1.7 § 7.5.4, § 7.5.8)

  When normal xref loading fails (corrupt or missing `%%EOF`, bad `startxref`
  offset), `recover/1` performs a linear scan of the full PDF binary to
  reconstruct the cross-reference table without relying on the `startxref`
  pointer or the on-disk xref section.

  Algorithm:
  1. Use `:binary.matches/2` to find all occurrences of `" obj"` in the binary.
  2. Back-scan each match for a `\\n<digits> <digits> ` prefix — this distinguishes
     real object headers from `obj` substrings inside content streams or strings.
  3. Build a map of `{obj_num, gen_num} => {:in_use, offset, gen_num}` entries.
  4. On collision (same `obj_num`, different `gen_num`), keep the highest
     `gen_num`; ties are broken by the later (higher) byte offset.
  5. Synthesise a trailer dict by scanning the binary for the LAST
     `trailer\\n<<...>>` block. If none is found, scan recovered object entries
     for one containing `/Type /Catalog` to derive `/Root`.
  6. Returns `{:ok, entries_map, trailer_struct}`.

  ## Spec references

  - PDF 1.7 § 7.5.4 — Cross-reference table
  - PDF 1.7 § 7.5.5 — File trailer
  - PDF 1.7 § 7.5.8 — Cross-reference streams
  """

  alias Pdf.Reader.{Trailer, XRef.Classic, XRef.Stream, Parser}

  @type entry :: Pdf.Reader.Document.xref_entry()
  @type entries :: %{Pdf.Reader.Document.ref() => entry()}

  @doc """
  Loads all xref sections reachable from `start_offset` (following `/Prev` links)
  and merges them into a single entries map.

  Newer sections' entries override older ones on conflict (reverse-chain order).

  Returns `{:ok, entries_map, trailer_struct}` or `{:error, reason}`.
  """
  @spec load(binary(), non_neg_integer()) ::
          {:ok, entries(), Trailer.t()} | {:error, term()}
  def load(binary, start_offset) do
    load_chain(binary, start_offset, %{}, nil)
  end

  @doc """
  Recovers a cross-reference table from a PDF binary by linear scan, without
  relying on `startxref` or any xref section in the file.

  ## Algorithm

  1. Use `:binary.matches/2` to find every `" obj"` substring in `binary`.
  2. For each match position, back-scan to validate the `\\n<digits> <digits> `
     prefix that characterises a real indirect-object header. This rejects false
     positives where `obj` appears inside a content stream or string literal.
  3. Parse `(obj_num, gen_num)` from the prefix and compute the byte offset of
     the object (start of `N G obj`).
  4. Deduplicate by `obj_num`: when the same number appears more than once keep
     the entry with the highest `gen_num`. If `gen_num` values tie, the entry
     at the larger byte offset wins (later in the file = more recent revision).
  5. Synthesise a `%Pdf.Reader.Trailer{}` by scanning for the last
     `trailer\\n<<...>>` block. If none is found, scan recovered entries for an
     object whose dict contains `/Type /Catalog` and use its ref as `/Root`.

  Returns `{:ok, entries_map, trailer_struct}` where `entries_map` is keyed by
  `{obj_num, gen_num}` tuples.

  PDF 1.7 § 7.5.4 — Cross-reference table
  PDF 1.7 § 7.5.8 — Cross-reference streams
  """
  @spec recover(binary()) :: {:ok, entries(), Trailer.t()}
  def recover(binary) when is_binary(binary) do
    entries = scan_for_objects(binary)
    trailer = synthesise_trailer(binary, entries)
    {:ok, entries, trailer}
  end

  # ---------------------------------------------------------------------------
  # Linear scan helpers
  # ---------------------------------------------------------------------------

  # Scan the binary for all " obj" matches and back-validate each one to
  # confirm it is a real object header (not " obj" inside a stream or string).
  # Returns a deduplicated map keyed by {obj_num, gen_num}.
  defp scan_for_objects(binary) do
    positions = :binary.matches(binary, " obj")

    Enum.reduce(positions, %{}, fn {pos, _len}, acc ->
      case back_scan_header(binary, pos) do
        {:ok, obj_num, gen_num, header_start} ->
          entry = {:in_use, header_start, gen_num}
          merge_entry(acc, obj_num, gen_num, header_start, entry)

        :error ->
          acc
      end
    end)
  end

  # Back-scan from `pos` (the position of the space in " obj") to find the
  # "\n<digits> <digits>" prefix.
  #
  # Returns {:ok, obj_num, gen_num, header_start_offset} or :error.
  #
  # A valid object header looks like (PDF 1.7 § 7.3.10):
  #   \n<obj_num> <gen_num> obj\n
  #
  # The space at `pos` is the last character before "obj". The bytes before
  # that space (on the same line) are "<gen_num>". The bytes before that are
  # "<obj_num>" separated by another space. All of this follows a '\n'.
  defp back_scan_header(binary, pos) do
    # Find the '\n' that starts this line (or offset 0 for the very first line).
    line_start = find_preceding_newline(binary, pos - 1)

    # The slice from line_start to pos is the "<obj_num> <gen_num>" part.
    if pos > line_start do
      slice = binary_part(binary, line_start, pos - line_start)
      trimmed = String.trim_leading(slice)

      case parse_obj_gen(trimmed) do
        {:ok, obj_num, gen_num} -> {:ok, obj_num, gen_num, line_start}
        :error -> :error
      end
    else
      :error
    end
  end

  # Find the offset just AFTER the last '\n' before byte position `pos`.
  # Returns 0 if no '\n' is found (object is on the first line of the binary).
  defp find_preceding_newline(_binary, pos) when pos < 0, do: 0

  defp find_preceding_newline(binary, pos) do
    byte = :binary.at(binary, pos)

    if byte == ?\n do
      pos + 1
    else
      find_preceding_newline(binary, pos - 1)
    end
  end

  # Parse "<digits> <digits>" from a string.
  # Returns {:ok, obj_num, gen_num} or :error.
  defp parse_obj_gen(str) do
    case Regex.run(~r/^(\d+)\s+(\d+)\s*$/, str) do
      [_, n_str, g_str] ->
        {:ok, String.to_integer(n_str), String.to_integer(g_str)}

      _ ->
        :error
    end
  end

  # Merge a new entry into the accumulator, keeping highest gen_num.
  # Tie on gen_num → keep the later offset (higher byte position).
  defp merge_entry(acc, obj_num, gen_num, offset, entry) do
    case find_existing_for_obj(acc, obj_num) do
      nil ->
        Map.put(acc, {obj_num, gen_num}, entry)

      {existing_key, existing_gen, existing_offset} ->
        cond do
          gen_num > existing_gen ->
            # Remove old entry, add new (higher gen wins)
            acc |> Map.delete(existing_key) |> Map.put({obj_num, gen_num}, entry)

          gen_num == existing_gen and offset > existing_offset ->
            # Same gen, later offset wins
            acc |> Map.delete(existing_key) |> Map.put({obj_num, gen_num}, entry)

          true ->
            # Existing entry wins — discard new one
            acc
        end
    end
  end

  # Find an existing entry for a given obj_num (ignoring gen_num).
  # Returns {key, gen_num, offset} or nil.
  defp find_existing_for_obj(acc, obj_num) do
    Enum.find_value(acc, fn {{n, g}, {:in_use, off, _}} ->
      if n == obj_num, do: {{n, g}, g, off}
    end)
  end

  # ---------------------------------------------------------------------------
  # Trailer synthesis
  # ---------------------------------------------------------------------------

  # Synthesise a %Trailer{} by:
  # 1. Scanning the binary for the LAST "trailer\n<<...>>" block.
  # 2. If absent, scanning recovered entries for /Type /Catalog.
  # 3. If still absent, return a minimal empty-root trailer.
  defp synthesise_trailer(binary, entries) do
    case find_last_trailer_dict(binary) do
      {:ok, dict} ->
        build_trailer_from_dict(dict)

      :error ->
        case find_catalog_root(binary, entries) do
          {:ok, root_ref} ->
            %Trailer{root: root_ref, dict: %{"Root" => root_ref}}

          :error ->
            %Trailer{dict: %{}}
        end
    end
  end

  # Find the LAST occurrence of "trailer" in the binary and parse the dict.
  defp find_last_trailer_dict(binary) do
    all_matches = :binary.matches(binary, "trailer")

    case List.last(all_matches) do
      nil ->
        :error

      {pos, len} ->
        after_keyword = binary_part(binary, pos + len, byte_size(binary) - pos - len)
        trimmed = String.trim_leading(after_keyword)

        case trimmed do
          <<"<<", _::binary>> ->
            {dict, _rest} = Parser.parse_value(trimmed)

            if is_map(dict) do
              {:ok, dict}
            else
              :error
            end

          _ ->
            :error
        end
    end
  end

  # Scan recovered entries to find an object whose dict contains /Type /Catalog.
  # Returns {:ok, {:ref, n, g}} or :error.
  defp find_catalog_root(binary, entries) do
    total = byte_size(binary)

    result =
      Enum.find_value(entries, fn {{n, g}, {:in_use, offset, _gen}} ->
        if offset < total do
          slice = binary_part(binary, offset, total - offset)

          case Parser.parse_object(slice) do
            {:ok, _ref, dict, _rest} when is_map(dict) ->
              case Map.get(dict, "Type") do
                {:name, "Catalog"} -> {:ref, n, g}
                _ -> nil
              end

            _ ->
              nil
          end
        end
      end)

    case result do
      nil -> :error
      ref -> {:ok, ref}
    end
  end

  # build_trailer_from_dict/1 is defined later in the module (shared with load_stream).

  # ---------------------------------------------------------------------------
  # Chain loading — dispatch to classic or stream based on content at offset
  # ---------------------------------------------------------------------------

  defp load_chain(binary, offset, acc_entries, acc_trailer) do
    total = byte_size(binary)

    if offset >= total do
      {:error, :xref_offset_out_of_range}
    else
      slice = binary_part(binary, offset, total - offset)

      cond do
        # Classic xref section starts with the literal keyword "xref"
        String.starts_with?(slice, "xref") ->
          load_classic(binary, offset, acc_entries, acc_trailer)

        # XRef stream: starts with digits (object header "N G obj")
        starts_with_object_header?(slice) ->
          load_stream(binary, offset, acc_entries, acc_trailer)

        true ->
          {:error, :xref_not_found}
      end
    end
  end

  # Peek at the bytes to determine if this looks like "N G obj" (an indirect object).
  # PDF 1.7 § 7.5.8: an xref stream IS an indirect object whose dict has /Type /XRef.
  defp starts_with_object_header?(slice) do
    # Pattern: optional whitespace, then digit(s), space, digit(s), space, "obj"
    trimmed = String.trim_leading(slice)
    Regex.match?(~r/^\d+ \d+ obj/, trimmed)
  end

  # ---------------------------------------------------------------------------
  # Classic xref loading
  # ---------------------------------------------------------------------------

  defp load_classic(binary, offset, acc_entries, _acc_trailer) do
    with {:ok, entries} <- Classic.parse(binary, offset),
         {:ok, trailer} <- Trailer.parse(binary, offset) do
      # Merge: newer (current) entries override older (acc)
      merged = Map.merge(acc_entries, entries)

      case trailer.prev do
        nil ->
          {:ok, merged, trailer}

        prev_offset when is_integer(prev_offset) ->
          # Load older section, then override with what we have
          case load_chain(binary, prev_offset, %{}, nil) do
            {:ok, older_entries, _older_trailer} ->
              # newer (merged) wins over older
              final = Map.merge(older_entries, merged)
              {:ok, final, trailer}

            error ->
              error
          end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # XRef stream loading (PDF 1.5+)
  # ---------------------------------------------------------------------------

  defp load_stream(binary, offset, acc_entries, _acc_trailer) do
    total = byte_size(binary)
    slice = binary_part(binary, offset, total - offset)

    # Parse the full stream object at this offset.
    case Parser.parse_object(slice) do
      {:ok, _ref, {:stream, dict, raw_body}, _rest} ->
        case Stream.parse({:stream, dict, raw_body}) do
          {:ok, entries} ->
            # Build a Trailer struct from the stream dict (§ 7.5.8:
            # the xref stream dict doubles as the trailer dict).
            trailer = build_trailer_from_dict(dict)

            # Merge: newer (current) entries override older (acc)
            merged = Map.merge(acc_entries, entries)

            case trailer.prev do
              nil ->
                {:ok, merged, trailer}

              prev_offset when is_integer(prev_offset) ->
                # Load older section, then override with what we have
                case load_chain(binary, prev_offset, %{}, nil) do
                  {:ok, older_entries, _older_trailer} ->
                    final = Map.merge(older_entries, merged)
                    {:ok, final, trailer}

                  error ->
                    error
                end
            end

          {:error, _} = err ->
            err
        end

      {:error, _} = err ->
        err

      _ ->
        {:error, :xref_stream_parse_failed}
    end
  end

  # Build a Pdf.Reader.Trailer struct from an xref stream's dict.
  # Per PDF 1.7 § 7.5.8: the xref stream dict contains the same fields
  # as a classic trailer dict (/Root, /Info, /Prev, /Encrypt, /ID, /Size).
  defp build_trailer_from_dict(dict) do
    %Trailer{
      root: Map.get(dict, "Root"),
      info: Map.get(dict, "Info"),
      size: integer_from_dict(dict, "Size"),
      encrypt: Map.get(dict, "Encrypt"),
      id: list_from_dict(dict, "ID"),
      prev: integer_from_dict(dict, "Prev"),
      dict: dict
    }
  end

  defp integer_from_dict(dict, key) do
    case Map.get(dict, key) do
      v when is_integer(v) -> v
      _ -> nil
    end
  end

  defp list_from_dict(dict, key) do
    case Map.get(dict, key) do
      l when is_list(l) -> l
      _ -> nil
    end
  end
end
