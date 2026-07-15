defmodule Pdf.Layout.Stack do
  @moduledoc """
  Vertical stack layout — children flow top-to-bottom without individual `y` positions.

  Like HTML block elements: only the stack origin uses `position`, children stack
  automatically with wrap.
  """

  alias Pdf.Layout.Flow

  @doc """
  Measure total height of stacked children in points.
  """
  @spec measure(list, number, map, any) :: number
  def measure(children, inner_width, style \\ %{}, doc \\ nil) do
    gap = Map.get(style, :gap, 0)
    {x, _} = Map.get(style, :position, {0, 0})
    wrap_w = wrap_width(inner_width, x, style)

    children
    |> List.flatten()
    |> Enum.with_index()
    |> Enum.reduce(0, fn {child, index}, total ->
      height = child_height(child, wrap_w, doc)
      spacing = if index == 0, do: 0, else: gap
      total + spacing + height
    end)
  end

  @doc """
  Render stacked children starting at absolute `{x, y}` on the document.
  """
  @spec render(any(), {number(), number()}, map(), list(), (any(), any(), map() -> any())) :: any()
  def render(doc, {x, y}, style, children, render_item) when is_function(render_item, 3) do
    gap = Map.get(style, :gap, 0)
    inner_w = Map.get(style, :inner_width, 300)
    {ox, _} = Map.get(style, :position, {0, 0})
    wrap_w = wrap_width(inner_w, ox, style)

    {doc, _y} =
      children
      |> List.flatten()
      |> Enum.reduce({doc, y}, fn child, {doc, current_y} ->
        height = child_height(child, wrap_w, doc)

        doc =
          render_item.(doc, child, %{
            x: x,
            y: current_y,
            width: wrap_w,
            break_text: true
          })

        {doc, current_y - height - gap}
      end)

    doc
  end

  @doc """
  Bottom edge relative to stack origin top (position y is negative down from box top).
  """
  @spec extent(map, list, number, any) :: number
  def extent(style, children, inner_width, doc \\ nil) do
    {_, top} = Map.get(style, :position, {0, 0})
    abs(top) + measure(children, inner_width, style, doc)
  end

  defp wrap_width(inner_width, x, style) do
    case Map.get(style, :width) do
      nil -> text_offset_width(inner_width, x || 0)
      w -> Pdf.Dimension.resolve(w, inner_width)
    end
  end

  defp text_offset_width(inner_width, x) do
    x_off = if is_number(x), do: abs(trunc(x)), else: 0
    max(inner_width - x_off, 1)
  end

  defp child_height(%{type: :text, props: props}, wrap_w, doc) do
    style = Map.get(props, :style, %{})
    Flow.measure_text(Map.get(props, :content, ""), style, wrap_w, doc)
  end

  defp child_height(%{text: text} = child, wrap_w, doc) do
    style = Map.drop(child, [:text])
    Flow.measure_text(text, style, wrap_w, doc)
  end

  defp child_height(_, _wrap_w, _doc), do: 0
end
