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
