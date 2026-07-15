defmodule Pdf.Layout.Reflow do
  @moduledoc false

  alias Pdf.Layout.Flow

  @default_gap 4
  @default_row_threshold 12

  @doc """
  Measure total inner height for reflow layout.

  ## Options

  - `:gap` — vertical space between rows (default `4`)
  - `:row_threshold` — band size in points to group children on the same row (default `12`)
  """
  def measure(children, inner_width, doc \\ nil, opts \\ []) do
    gap = Keyword.get(opts, :gap, @default_gap)
    threshold = Keyword.get(opts, :row_threshold, @default_row_threshold)

    children
    |> List.flatten()
    |> to_occupancies(inner_width, doc)
    |> cluster_rows(threshold)
    |> layout_rows(gap)
    |> elem(1)
  end

  @doc false
  def render(doc, area, style, children, render_child) when is_function(render_child, 3) do
    gap = Map.get(style, :gap, @default_gap)
    threshold = Map.get(style, :row_threshold, @default_row_threshold)

    {doc, _height} =
      children
      |> List.flatten()
      |> to_occupancies(area.width, doc)
      |> cluster_rows(threshold)
      |> Enum.reduce({doc, 0}, fn row, {doc, cursor} ->
        {row_h, placements} = place_row(row, cursor, gap)

        doc =
          Enum.reduce(placements, doc, fn {child, x, top, width}, doc ->
            child_area = %{
              area
              | x: area.x + x,
                y: area.y - top,
                width: width
            }

            render_placed_child(doc, child, child_area, render_child)
          end)

        {doc, cursor + row_h + gap}
      end)

    doc
  end

  defp layout_rows(rows, gap) do
    Enum.reduce(rows, {[], 0}, fn row, {acc, cursor} ->
      {row_h, _placements} = place_row(row, cursor, gap)
      {acc ++ [{row, row_h}], cursor + row_h + gap}
    end)
  end

  defp place_row(row, cursor, gap) do
    spacing = if cursor == 0, do: 0, else: gap
    preferred_top = row |> Enum.map(& &1.pref_top) |> Enum.min()
    actual_top = max(preferred_top, cursor + spacing)
    row_h = row |> Enum.map(& &1.height) |> Enum.max()

    placements =
      Enum.map(row, fn occ ->
        {occ.child, occ.x, actual_top, occ.width}
      end)

    {row_h, placements}
  end

  defp cluster_rows(occupancies, threshold) do
    occupancies
    |> Enum.sort_by(& &1.pref_top)
    |> Enum.group_by(&row_band(&1.pref_top, threshold))
    |> Enum.sort_by(fn {band, _} -> band end)
    |> Enum.map(fn {_band, row} -> row end)
  end

  defp row_band(pref_top, threshold) do
    div(pref_top, max(threshold, 1))
  end

  defp to_occupancies(children, inner_width, doc) do
    Enum.map(children, fn child ->
      {x, y} = child_position(child)
      pref_top = abs(y)
      width = child_width(child, inner_width, x)
      height = child_height(child, width, doc)

      %{child: child, x: x, pref_top: pref_top, width: width, height: height}
    end)
    |> Enum.reject(&skip_child?/1)
  end

  defp skip_child?(%{child: child}), do: Map.get(child, :position) == :absolute

  defp render_placed_child(doc, child, area, render_child) do
    case child do
      %{type: :text, props: props} ->
        style =
          props
          |> Map.get(:style, %{})
          |> Map.put(:position, {0, 0})
          |> Map.put(:break_text, true)
          |> Map.put(:wrap_width, area.width)

        child
        |> put_in([:props, :style], style)
        |> then(&render_child.(doc, &1, area))

      %{text: _} = map_child ->
        map_child
        |> Map.put(:x, 0)
        |> Map.put(:y, 0)
        |> Map.put(:break_text, true)
        |> Map.put(:wrap_width, area.width)
        |> then(&render_child.(doc, &1, area))

      _ ->
        child
        |> place_child()
        |> then(&render_child.(doc, &1, area))
    end
  end

  defp place_child(%{type: _, props: props} = child) do
    style = Map.get(props, :style, %{}) |> Map.put(:position, {0, 0})
    put_in(child, [:props, :style], style)
  end

  defp place_child(child), do: child |> Map.put(:x, 0) |> Map.put(:y, 0)

  defp child_width(child, inner_width, x) do
    case child do
      %{type: :key_value, props: props} ->
        style = Map.get(props, :style, %{})
        resolve_width(Map.get(style, :width, inner_width), inner_width)

      %{key_value: _} = map_child ->
        style = Map.drop(map_child, [:key_value, :pairs])
        resolve_width(Map.get(style, :width, inner_width), inner_width)

      _ ->
        max(inner_width - x, 1)
    end
  end

  defp child_height(%{type: :text, props: props}, width, doc) do
    Flow.measure_text(Map.get(props, :content, ""), Map.get(props, :style, %{}), width, doc)
  end

  defp child_height(%{text: text} = child, width, doc) do
    style = Map.drop(child, [:text, :x, :y, :position])
    Flow.measure_text(text, style, width, doc)
  end

  defp child_height(%{type: :key_value, props: props}, width, _doc) do
    style = Map.get(props, :style, %{})
    {x, _} = Map.get(style, :position, {0, 0})
    x_off = if is_number(x), do: abs(trunc(x)), else: 0
    Pdf.Component.KeyValue.measure_height(style, Map.get(props, :pairs, []), width, x_offset: x_off)
  end

  defp child_height(%{key_value: {x, _}, pairs: pairs} = child, width, _doc) do
    style = Map.drop(child, [:key_value, :pairs])
    x_off = if is_number(x), do: abs(trunc(x)), else: 0
    Pdf.Component.KeyValue.measure_height(style, pairs, width, x_offset: x_off)
  end

  defp child_height(%{type: :avatar, props: props}, _width, _doc) do
    {_, h} = normalize_size(Map.get(Map.get(props, :style, %{}), :size, 40))
    h
  end

  defp child_height(%{avatar: _} = child, _width, _doc) do
    style = Map.drop(child, [:avatar])
    {_, h} = normalize_size(Map.get(style, :size, 40))
    h
  end

  defp child_height(%{type: :chip, props: props}, _width, _doc) do
    Map.get(Map.get(props, :style, %{}), :height, 24)
  end

  defp child_height(%{type: :line_segment}, _width, _doc), do: 1

  defp child_height(%{spacer: amount}, _width, _doc), do: amount
  defp child_height(_, _width, _doc), do: 0

  defp child_position(%{type: :line_segment, props: props}) do
    style = Map.get(props, :style, %{})

    case Map.get(style, :from, {0, 0}) do
      {x, y} -> {x, y}
    end
  end

  defp child_position(%{type: _, props: props}) do
    Map.get(Map.get(props, :style, %{}), :position, {0, 0})
  end

  defp child_position(%{text: _} = child), do: {Map.get(child, :x, 0), Map.get(child, :y, 0)}
  defp child_position(%{key_value: {x, y}}), do: {x, y}
  defp child_position(%{avatar: {x, y}}), do: {x, y}
  defp child_position(%{chip: {x, y}}), do: {x, y}
  defp child_position(_), do: {0, 0}

  defp normalize_size(size) when is_number(size), do: {size, size}
  defp normalize_size({w, h}), do: {w, h}

  defp resolve_width(:full, parent), do: parent
  defp resolve_width(value, parent), do: Pdf.Dimension.resolve(value, parent)
end
