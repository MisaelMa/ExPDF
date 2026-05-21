defmodule Pdf.Reader.Filter do
  @moduledoc """
  PDF stream filter pipeline — behaviour definition and apply_chain dispatcher.

  Each filter is a module implementing the `Pdf.Reader.Filter` behaviour with
  a single `decode/2` callback. The `apply_chain/3` function runs filters
  in sequence (outermost first, matching the order in which they appear in
  the PDF stream's `/Filter` array).

  ## Supported filters

  | Module                      | Filter names                          |
  |-----------------------------|---------------------------------------|
  | `Pdf.Reader.Filter.Flate`   | `FlateDecode`, `Fl`                   |
  | `Pdf.Reader.Filter.ASCII85` | `ASCII85Decode`, `A85`                |
  | `Pdf.Reader.Filter.ASCIIHex`| `ASCIIHexDecode`, `AHx`               |
  | `Pdf.Reader.Filter.RLE`     | `RunLengthDecode`, `RL`               |
  | `Pdf.Reader.Filter.LZW`     | `LZWDecode`, `LZW`                    |

  Unknown filters return `{:error, {:unsupported_filter, name_atom}}`.
  """

  @callback decode(binary(), params :: map()) :: {:ok, binary()} | {:error, term()}

  @filter_map %{
    "FlateDecode" => Pdf.Reader.Filter.Flate,
    "Fl" => Pdf.Reader.Filter.Flate,
    "ASCII85Decode" => Pdf.Reader.Filter.ASCII85,
    "A85" => Pdf.Reader.Filter.ASCII85,
    "ASCIIHexDecode" => Pdf.Reader.Filter.ASCIIHex,
    "AHx" => Pdf.Reader.Filter.ASCIIHex,
    "RunLengthDecode" => Pdf.Reader.Filter.RLE,
    "RL" => Pdf.Reader.Filter.RLE,
    "LZWDecode" => Pdf.Reader.Filter.LZW,
    "LZW" => Pdf.Reader.Filter.LZW
  }

  @doc """
  Apply a chain of filters to `bytes`.

  `names` may be:
  - A list of filter name strings or atoms (multi-filter case)
  - A single filter name string or atom (single-filter convenience)

  `params` may be:
  - A list of param maps (aligned with `names`)
  - A single map (used for all filters)
  - `:null` entries in the list become `%{}`

  Filters are applied left to right (outermost first per PDF spec).
  Returns `{:ok, decoded_bytes}` or `{:error, reason}`.
  """
  @spec apply_chain(binary(), names :: list() | binary() | atom(), params :: list() | map()) ::
          {:ok, binary()} | {:error, term()}
  def apply_chain(bytes, names, params) do
    names_list = normalize_names(names)
    params_list = normalize_params(params, length(names_list))
    do_chain(bytes, names_list, params_list)
  end

  defp do_chain(bytes, [], []), do: {:ok, bytes}

  defp do_chain(bytes, [name | rest_names], [p | rest_params]) do
    case resolve_module(name) do
      {:ok, mod} ->
        case mod.decode(bytes, p) do
          {:ok, decoded} -> do_chain(decoded, rest_names, rest_params)
          {:error, _} = err -> err
        end

      {:error, _} = err ->
        err
    end
  end

  defp resolve_module(name) when is_atom(name) do
    resolve_module(Atom.to_string(name))
  end

  defp resolve_module(name) when is_binary(name) do
    case Map.get(@filter_map, name) do
      nil -> {:error, {:unsupported_filter, String.to_atom(name)}}
      mod -> {:ok, mod}
    end
  end

  # Handle {:name, binary()} tuples from the parser's tagged-tuple convention.
  defp resolve_module({:name, name}) when is_binary(name) do
    resolve_module(name)
  end

  # Normalize single-value names to a list
  defp normalize_names(names) when is_list(names), do: names
  defp normalize_names(name), do: [name]

  # Normalize params: single map → repeated list; :null entries → %{}
  defp normalize_params(params, _count) when is_list(params) do
    Enum.map(params, fn
      :null -> %{}
      nil -> %{}
      p when is_map(p) -> p
      _ -> %{}
    end)
  end

  defp normalize_params(params, count) when is_map(params) do
    List.duplicate(params, max(count, 1))
  end

  defp normalize_params(:null, count), do: List.duplicate(%{}, max(count, 1))
  defp normalize_params(nil, count), do: List.duplicate(%{}, max(count, 1))
end
