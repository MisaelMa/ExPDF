defmodule Pdf.Layout.AbsoluteMeasure do
  @moduledoc """
  Measures the minimum inner height for a box with absolutely-positioned children.

  Like CSS `height: auto` on a positioned container: walk children, find the
  lowest bottom edge (relative to the inner area top), and return that height.
  """

  alias Pdf.Component.KeyValue
  alias Pdf.Layout.Flow

  @doc """
  Returns the minimum inner content height in points.
  """
  @spec measure(list, number, any) :: number
  def measure(children, inner_width, doc \\ nil) do
    children
    |> List.flatten()
    |> Enum.reduce(0, fn child, max_h ->
      max(max_h, child_extent(child, inner_width, doc))
    end)
  end

  @doc """
  Height of a weighted row's tallest column.
  """
  @spec row_height(list, number, number, any) :: number
  def row_height(children, inner_w, gap \\ 0, doc \\ nil) do
    total_w = inner_w - gap * max(length(children) - 1, 0)
    total_weight = children |> Enum.map(&elem(&1, 0)) |> Enum.sum()

    Enum.reduce(children, 0, fn {weight, col_children}, max_h ->
      col_w = total_w * (weight / total_weight)

      col_h =
        col_children
        |> List.flatten()
        |> measure(col_w, doc)

      max(max_h, col_h)
    end)
  end

  defp child_extent(%{stack: {x, y}, children: children} = child, inner_w, doc) do
    gap = Map.get(child, :gap, 0)
    style = %{position: {x, y}, gap: gap}
    abs(y) + Pdf.Layout.Stack.measure(children, inner_w, style, doc)
  end

  defp child_extent(%{type: :row, props: props}, inner_w, doc) do
    style = Map.get(props, :style, %{})
    {_, py} = Map.get(style, :position, {0, 0})
    gap = Map.get(style, :gap, 0)
    children = Map.get(props, :children, [])
    abs(py) + row_height(children, inner_w, gap, doc)
  end

  defp child_extent(%{type: :stack, props: props}, inner_w, doc) do
    style = Map.get(props, :style, %{})
    {_, py} = Map.get(style, :position, {0, 0})
    children = Map.get(props, :children, [])
    abs(py) + Pdf.Layout.Stack.measure(children, inner_w, style, doc)
  end

  defp child_extent(%{type: :key_value, props: props}, inner_w, _doc) do
    style = Map.get(props, :style, %{})
    {px, py} = Map.get(style, :position, {0, 0})
    pairs = Map.get(props, :pairs, [])
    x = resolve_offset(px, inner_w)
    kv_h = KeyValue.measure_height(style, pairs, inner_w, x_offset: x)
    abs(py) + kv_h
  end

  defp child_extent(%{type: :text, props: props}, inner_w, doc) do
    style = Map.get(props, :style, %{})
    {px, py} = Map.get(style, :position, {0, 0})
    content = Map.get(props, :content, "")
    x = resolve_offset(px, inner_w)
    wrap_w = max(inner_w - x, 1)

    text_h =
      if Map.get(style, :break_text, false) do
        Flow.measure_text(content, style, wrap_w, doc)
      else
        font_size = Map.get(style, :font_size, 12)
        Map.get(style, :line_height, font_size * 1.2)
      end

    abs(py) + text_h
  end

  defp child_extent(%{type: :avatar, props: props}, _inner_w, _doc) do
    style = Map.get(props, :style, %{})
    {_, py} = Map.get(style, :position, {0, 0})
    {_, h} = normalize_size(Map.get(style, :size, {40, 40}))
    abs(py) + h
  end

  defp child_extent(%{type: :chip, props: props}, _inner_w, _doc) do
    style = Map.get(props, :style, %{})
    {_, py} = Map.get(style, :position, {0, 0})
    h = Map.get(style, :height, 24)
    abs(py) + h
  end

  defp child_extent(%{type: :line_segment, props: props}, _inner_w, _doc) do
    style = Map.get(props, :style, %{})

    {_, y1} = Map.get(style, :from, {0, 0})
    {_, y2} = Map.get(style, :to, {0, 0})
    max(abs(y1), abs(y2))
  end

  defp child_extent(%{type: :box, props: props}, inner_w, doc) do
    style = Map.get(props, :style, %{})
    {_, py} = Map.get(style, :position, {0, 0})
    children = Map.get(props, :children, [])
    {w_spec, h_spec} = Map.get(style, :size, {:full, :auto})

    child_inner_w =
      w_spec
      |> resolve_offset(inner_w)
      |> then(&Flow.inner_width(&1, style))

    h =
      case h_spec do
        :auto -> measure(children, child_inner_w, doc)
        h -> resolve_offset(h, inner_w)
      end

    abs(py) + h
  end

  defp child_extent(%{key_value: {px, py}, pairs: pairs} = child, inner_w, _doc) do
    style = Map.drop(child, [:key_value, :pairs])
    x = if is_number(px), do: abs(trunc(px)), else: 0
    kv_h = KeyValue.measure_height(style, pairs, inner_w, x_offset: x)
    abs(py) + kv_h
  end

  defp child_extent(%{text: text} = child, inner_w, doc) do
    py = Map.get(child, :y, 0)
    px = Map.get(child, :x, 0)
    style = Map.drop(child, [:text, :x, :y])
    wrap_w = max(inner_w - px, 1)

    text_h =
      if Map.get(child, :break_text, false) do
        Flow.measure_text(text, style, wrap_w, doc)
      else
        font_size = Map.get(style, :font_size, 12)
        Map.get(style, :line_height, font_size * 1.2)
      end

    abs(py) + text_h
  end

  defp child_extent(%{avatar: {_, py}} = child, _inner_w, _doc) do
    style = Map.drop(child, [:avatar])
    {_, h} = normalize_size(Map.get(style, :size, {40, 40}))
    abs(py) + h
  end

  defp child_extent(%{chip: {_, py}} = child, _inner_w, _doc) do
    style = Map.drop(child, [:chip])
    h = Map.get(style, :height, 24)
    abs(py) + h
  end

  defp child_extent(_child, _inner_w, _doc), do: 0

  defp normalize_size(size) when is_number(size), do: {size, size}
  defp normalize_size({w, h}), do: {w, h}

  defp resolve_offset(value, parent), do: Pdf.Dimension.resolve(value, parent)
end
