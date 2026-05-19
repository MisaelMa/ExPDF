defmodule Pdf.Reader.Encoding.Differences do
  @moduledoc """
  Applies a PDF `/Differences` array on top of a base encoding override map.

  Spec reference: PDF 1.7 § 9.6.5.1.

  ## Format

  `/Differences` is an array mixing integers and names:

      [32 /space 65 /A /B /C 200 /uni0024 ...]

  - An integer `N` sets the current code position to `N`.
  - Each subsequent name installs that glyph name at position, then increments by 1.

  ## API

      apply(base_overrides, differences_array) :: %{integer() => glyph_name :: binary()}

  The output is a byte→glyph_name map. Codepoint resolution (via AGL or ToUnicode)
  happens later in the encoding facade (`Pdf.Reader.Encoding`).

  `/Differences` entries override the base map. Base entries not touched by
  `/Differences` are preserved.
  """

  @doc """
  Applies a `/Differences` array on top of `base`, returning the merged
  byte→glyph_name override map.

  `differences` is a list of integers and `{:name, binary()}` tuples, matching
  the tagged-tuple convention used by the reader's parser.
  """
  @spec apply(%{non_neg_integer() => binary()}, list()) :: %{non_neg_integer() => binary()}
  def apply(base, differences) when is_map(base) and is_list(differences) do
    do_apply(differences, base, 0)
  end

  defp do_apply([], acc, _pos), do: acc

  defp do_apply([n | rest], acc, _pos) when is_integer(n) do
    do_apply(rest, acc, n)
  end

  defp do_apply([{:name, name} | rest], acc, pos) when is_binary(name) do
    do_apply(rest, Map.put(acc, pos, name), pos + 1)
  end

  # Handle bare atom/string names if parser uses those shapes
  defp do_apply([name | rest], acc, pos) when is_binary(name) do
    do_apply(rest, Map.put(acc, pos, name), pos + 1)
  end
end
