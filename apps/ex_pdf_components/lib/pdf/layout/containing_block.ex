defmodule Pdf.Layout.ContainingBlock do
  @moduledoc """
  CSS-like containing block — resolves relative sizes against a parent area.

  Use inside boxes, rows, and columns so children can declare `width: :full`
  or `"50%"` and inherit the parent's available space (similar to HTML width: 100%).
  """

  @type area :: %{required(:width) => number, optional(:height) => number, optional(:x) => number, optional(:y) => number}

  @doc "Resolve a width value against the parent area width."
  @spec resolve_width(any, area() | number) :: number
  def resolve_width(parent, parent_width) when is_number(parent_width) do
    Pdf.Dimension.resolve(parent, parent_width)
  end

  def resolve_width(value, %{width: width}), do: resolve_width(value, width)

  @doc "Resolve a height value against the parent area height."
  @spec resolve_height(any, area() | number) :: number
  def resolve_height(parent, parent_height) when is_number(parent_height) do
    Pdf.Dimension.resolve(parent, parent_height)
  end

  def resolve_height(value, %{height: height}), do: resolve_height(value, height)

  @doc "Resolve `{w, h}` against a parent area."
  @spec resolve_size({any, any}, area()) :: {number, number}
  def resolve_size(size, area), do: Pdf.Dimension.resolve_size(size, area)

  @doc """
  Text wrap width for a child at horizontal offset `x` inside the area.
  Like CSS: `width: calc(100% - x)`.
  """
  @spec text_width(area(), number) :: number
  def text_width(%{width: w}, x_offset) do
    max(w - resolve_width(x_offset, w), 1)
  end

  @doc """
  Apply width/height resolution to a style map using the parent area.
  Resolves `:width`, `:height`, and `:wrap_width` when present.
  """
  @spec resolve_style(map, area()) :: map
  def resolve_style(style, area) when is_map(style) do
    style
    |> resolve_style_key(:width, area.width)
    |> resolve_style_key(:height, Map.get(area, :height, area.width))
    |> resolve_style_key(:wrap_width, area.width)
  end

  defp resolve_style_key(style, key, parent_dim) do
    case Map.get(style, key) do
      nil -> style
      val -> Map.put(style, key, Pdf.Dimension.resolve(val, parent_dim))
    end
  end
end
