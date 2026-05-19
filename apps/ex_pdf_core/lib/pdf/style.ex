defmodule Pdf.Style do
  @moduledoc """
  CSS-like styling system for PDF elements.

  Styles are maps with atom keys that can be created, merged, and resolved.
  Supports shorthand notation for padding, margin, and border (similar to CSS).

  ## Examples

      Style.new(%{font_size: 14, color: :red, padding: 10})
      Style.new(%{font: "Helvetica", bold: true, opacity: 0.5})
      Style.merge(parent_style, child_style)
  """

  defstruct font: "Helvetica",
            font_size: 12,
            bold: false,
            italic: false,
            color: :black,
            align: :left,
            leading: nil,
            underline: false,
            width: nil,
            height: nil,
            padding: {0, 0, 0, 0},
            margin: {0, 0, 0, 0},
            border: {0, 0, 0, 0},
            border_color: :black,
            background: nil,
            opacity: 1.0,
            fill_opacity: nil,
            stroke_opacity: nil,
            line_width: 1,
            stroke_color: :black,
            border_radius: 0,
            rotate: 0,
            x: nil,
            y: nil

  @type t :: %__MODULE__{}

  @doc """
  Create a new Style from a map or keyword list.

  ## Examples

      iex> Pdf.Style.new(%{font_size: 14, color: :red})
      %Pdf.Style{font_size: 14, color: :red}

      iex> Pdf.Style.new(font_size: 14, padding: 10)
      %Pdf.Style{font_size: 14, padding: {10, 10, 10, 10}}
  """
  @spec new(map | keyword) :: t()
  def new(attrs \\ %{})

  def new(attrs) when is_map(attrs) do
    attrs
    |> normalize_shorthands()
    |> then(&struct(__MODULE__, &1))
  end

  def new(attrs) when is_list(attrs) do
    attrs |> Map.new() |> new()
  end

  @doc """
  Merge two styles. The child style overrides the parent for any non-nil fields
  explicitly set in the child.

  ## Examples

      iex> parent = Pdf.Style.new(%{font_size: 12, color: :black})
      iex> child = Pdf.Style.new(%{color: :red, bold: true})
      iex> merged = Pdf.Style.merge(parent, child)
      iex> merged.font_size
      12
      iex> merged.color
      :red
      iex> merged.bold
      true
  """
  @spec merge(t(), t() | map | keyword) :: t()
  def merge(%__MODULE__{} = parent, %__MODULE__{} = child) do
    merge(parent, Map.from_struct(child))
  end

  def merge(%__MODULE__{} = parent, child) when is_map(child) do
    overrides =
      child
      |> normalize_shorthands()
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    struct(parent, overrides)
  end

  def merge(%__MODULE__{} = parent, child) when is_list(child) do
    merge(parent, Map.new(child))
  end

  @doc """
  Normalize a shorthand value into a {top, right, bottom, left} tuple.

  Supports CSS-like shorthand:
  - `10` → `{10, 10, 10, 10}`
  - `{5, 10}` → `{5, 10, 5, 10}`
  - `{5, 10, 15}` → `{5, 10, 15, 10}`
  - `{5, 10, 15, 20}` → `{5, 10, 15, 20}`
  """
  @spec expand_shorthand(number | tuple) :: {number, number, number, number}
  def expand_shorthand(value) when is_number(value), do: {value, value, value, value}
  def expand_shorthand({top, right, bottom, left}), do: {top, right, bottom, left}
  def expand_shorthand({vertical, horizontal}), do: {vertical, horizontal, vertical, horizontal}
  def expand_shorthand({top, horizontal, bottom}), do: {top, horizontal, bottom, horizontal}

  @doc """
  Convert a Style struct to a keyword list suitable for passing to
  existing Page/Document functions.
  """
  @spec to_opts(t()) :: keyword
  def to_opts(%__MODULE__{} = style) do
    []
    |> maybe_put(:bold, style.bold, false)
    |> maybe_put(:italic, style.italic, false)
    |> maybe_put(:font_size, style.font_size, nil)
    |> maybe_put(:color, style.color, nil)
    |> maybe_put(:align, style.align, :left)
    |> maybe_put(:leading, style.leading, nil)
    |> maybe_put(:kerning, false, false)
  end

  defp maybe_put(opts, _key, default, default), do: opts
  defp maybe_put(opts, _key, nil, _default), do: opts
  defp maybe_put(opts, key, value, _default), do: Keyword.put(opts, key, value)

  defp normalize_shorthands(attrs) do
    attrs
    |> normalize_shorthand_field(:padding)
    |> normalize_shorthand_field(:margin)
    |> normalize_shorthand_field(:border)
  end

  defp normalize_shorthand_field(attrs, key) do
    case Map.get(attrs, key) do
      nil -> attrs
      value when is_number(value) -> Map.put(attrs, key, expand_shorthand(value))
      {_, _} = value -> Map.put(attrs, key, expand_shorthand(value))
      {_, _, _} = value -> Map.put(attrs, key, expand_shorthand(value))
      {_, _, _, _} -> attrs
    end
  end
end
