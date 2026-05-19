defmodule Pdf.Reader.Trailer do
  @moduledoc """
  Locates the `startxref` byte offset in a PDF binary and parses the
  trailer dictionary at a given xref section offset.

  ## PDF spec references
  - § 7.5.5 — File Trailer
  - § 7.5.4 — Cross-Reference Table
  """

  alias Pdf.Reader.Parser

  # ---------------------------------------------------------------------------
  # Struct
  # ---------------------------------------------------------------------------

  @type t :: %__MODULE__{
          root: Pdf.Reader.Document.ref() | nil,
          info: Pdf.Reader.Document.ref() | nil,
          size: pos_integer() | nil,
          encrypt: term(),
          id: [{:hex_string, binary()} | {:string, binary()} | binary()] | nil,
          prev: non_neg_integer() | nil,
          dict: map()
        }

  defstruct root: nil,
            info: nil,
            size: nil,
            encrypt: nil,
            id: nil,
            prev: nil,
            dict: %{}

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Scans `binary` in reverse for `%%EOF`, then reads the `startxref` offset
  on the line immediately before it.

  Returns `{:ok, offset}` or `{:error, :malformed}`.

  Per PDF spec § 7.5.5: the file ends with `%%EOF`. The line above that is
  the byte offset to the xref section. The line above that is the keyword
  `startxref`.
  """
  @spec locate_startxref(binary()) :: {:ok, non_neg_integer()} | {:error, :malformed}
  def locate_startxref(binary) when is_binary(binary) do
    # Split into lines, iterate from the end to find %%EOF
    lines = binary |> String.split(~r/\r\n|\r|\n/) |> Enum.reverse()
    find_eof_and_offset(lines)
  end

  @doc """
  Parses the xref section and trailer dictionary at `offset` within `binary`.

  Seeks forward from `offset` to the `trailer` keyword, then parses the
  dictionary that follows. Populates a `%Pdf.Reader.Trailer{}` struct.

  Returns `{:ok, %Pdf.Reader.Trailer{}}` or `{:error, :malformed}`.
  """
  @spec parse(binary(), non_neg_integer()) ::
          {:ok, t()} | {:error, :malformed}
  def parse(binary, offset) when is_binary(binary) and is_integer(offset) do
    total = byte_size(binary)

    if offset >= total do
      {:error, :malformed}
    else
      # Slice from offset to end
      slice = binary_part(binary, offset, total - offset)

      # Find "trailer" keyword in the slice, then parse the dict that follows
      case find_trailer_dict(slice) do
        {:ok, dict_binary} ->
          {dict, _rest} = Parser.parse_value(dict_binary)
          {:ok, build_trailer(dict)}

        :error ->
          {:error, :malformed}
      end
    end
  end

  # ---------------------------------------------------------------------------
  # locate_startxref helpers
  # ---------------------------------------------------------------------------

  # Walk reversed lines: skip blank lines, find %%EOF, then read offset + startxref
  defp find_eof_and_offset(lines) do
    lines
    |> Enum.drop_while(&blank_or_whitespace?/1)
    |> do_find_eof()
  end

  defp do_find_eof([line | rest]) do
    if String.trim(line) == "%%EOF" do
      extract_offset(rest)
    else
      # %%EOF not the first non-blank — might be multiple %%EOF blocks (linearized)
      # or junk at end. Keep looking.
      do_find_eof(Enum.drop_while(rest, &(String.trim(&1) != "%%EOF")))
    end
  end

  defp do_find_eof([]), do: {:error, :malformed}

  defp extract_offset(lines) do
    # Skip blank lines to find the offset number
    lines = Enum.drop_while(lines, &blank_or_whitespace?/1)

    case lines do
      [offset_line | rest] ->
        case Integer.parse(String.trim(offset_line)) do
          {offset, ""} ->
            # Verify the line before is `startxref`
            rest = Enum.drop_while(rest, &blank_or_whitespace?/1)

            case rest do
              [kw | _] ->
                if String.trim(kw) == "startxref" do
                  {:ok, offset}
                else
                  # Be lenient — accept valid integer even without keyword verification
                  {:ok, offset}
                end

              [] ->
                {:ok, offset}
            end

          _ ->
            {:error, :malformed}
        end

      [] ->
        {:error, :malformed}
    end
  end

  defp blank_or_whitespace?(str), do: String.trim(str) == ""

  # ---------------------------------------------------------------------------
  # parse helpers
  # ---------------------------------------------------------------------------

  # Find the `trailer` keyword in the slice and return everything after it
  defp find_trailer_dict(slice) do
    case :binary.match(slice, "trailer") do
      {pos, len} ->
        after_keyword = binary_part(slice, pos + len, byte_size(slice) - pos - len)
        # Skip whitespace to reach <<
        trimmed = String.trim_leading(after_keyword)
        {:ok, trimmed}

      :nomatch ->
        :error
    end
  end

  # ---------------------------------------------------------------------------
  # Build Trailer struct from parsed dict
  # ---------------------------------------------------------------------------

  defp build_trailer(dict) when is_map(dict) do
    %__MODULE__{
      root: Map.get(dict, "Root"),
      info: Map.get(dict, "Info"),
      size: extract_integer(dict, "Size"),
      encrypt: Map.get(dict, "Encrypt"),
      id: extract_id(dict),
      prev: extract_integer(dict, "Prev"),
      dict: dict
    }
  end

  defp build_trailer(_), do: %__MODULE__{}

  defp extract_integer(dict, key) do
    case Map.get(dict, key) do
      v when is_integer(v) -> v
      _ -> nil
    end
  end

  defp extract_id(dict) do
    case Map.get(dict, "ID") do
      list when is_list(list) -> list
      _ -> nil
    end
  end
end
