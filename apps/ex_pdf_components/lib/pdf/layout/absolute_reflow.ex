defmodule Pdf.Layout.AbsoluteReflow do
  @moduledoc """
  HTML-like reflow for absolutely-positioned box children.

  - Text wraps within the parent width (`break_text` applied automatically)
  - Vertical stacks (same x column) push siblings below down
  - Content at/after `reflow_anchor` shifts down when the header grows
  - Box height grows via `measure/4`
  """

  alias Pdf.Component.KeyValue
  alias Pdf.Layout.{AbsoluteMeasure, Flow}

  @default_column_tolerance 4

  @doc """
  Returns children with updated positions/styles after reflow.
  """
  @spec prepare(list, number, map, any) :: list
  def prepare(children, inner_width, style, doc \\ nil) do
    anchor = Map.get(style, :reflow_anchor, auto_anchor(children))
    tolerance = Map.get(style, :column_tolerance, @default_column_tolerance)

    children = List.flatten(children)

    header = reflow_zone(children, inner_width, doc, tolerance, 0, anchor)
    delta = header_delta(header, anchor, inner_width, doc)

    header
    |> shift_zone(anchor, :infinity, delta)
    |> reflow_zone(inner_width, doc, tolerance, anchor, :infinity)
  end

  @doc """
  Measure inner height after reflow.
  """
  @spec measure(list, number, map, any) :: number
  def measure(children, inner_width, style, doc \\ nil) do
    children
    |> prepare(inner_width, style, doc)
    |> AbsoluteMeasure.measure(inner_width, doc)
  end

  # ── Zones ────────────────────────────────────────────────────────

  defp reflow_zone(children, inner_w, doc, tolerance, min_top, max_top) do
    in_zone = fn child ->
      top = pref_top(child)
      top >= min_top and (max_top == :infinity or top < max_top)
    end

    repositioned =
      children
      |> Enum.with_index()
      |> Enum.filter(fn {child, _idx} -> in_zone.(child) end)
      |> group_stacks_indexed(tolerance)
      |> Enum.flat_map(fn stack -> reflow_stack(stack, inner_w, doc) end)
      |> Map.new()

    Enum.with_index(children)
    |> Enum.map(fn {child, idx} ->
      if in_zone.(child) do
        Map.get(repositioned, idx, enable_wrap(child, inner_w))
      else
        child
      end
    end)
  end

  defp group_stacks_indexed(indexed_children, tolerance) do
    indexed_children
    |> Enum.group_by(fn {child, _idx} -> x_bucket(child_x(child), tolerance) end)
    |> Map.values()
    |> Enum.map(fn group ->
      group
      |> Enum.sort_by(fn {child, _idx} -> pref_top(child) end)
      |> Enum.map(fn {child, idx} -> {idx, child} end)
    end)
  end

  defp shift_zone(children, _min_top, _max_top, delta) when delta <= 0, do: children

  defp shift_zone(children, min_top, max_top, delta) do
    in_zone = fn child ->
      top = pref_top(child)
      top >= min_top and (max_top == :infinity or top < max_top)
    end

    Enum.map(children, fn child ->
      if in_zone.(child), do: shift_y(child, delta), else: child
    end)
  end

  defp header_delta(header, anchor, inner_w, doc) do
    header
    |> Enum.filter(fn child -> pref_top(child) < anchor end)
    |> Enum.map(fn child -> pref_top(child) + child_height(child, inner_w, doc) end)
    |> case do
      [] -> 0
      bottoms -> max(0, Enum.max(bottoms) - anchor)
    end
  end

  # ── Column stacks ────────────────────────────────────────────────

  defp reflow_stack(indexed_stack, inner_w, doc) do
    stack = Enum.map(indexed_stack, fn {_idx, child} -> child end)

    cond do
      vertical_stack?(stack) and stackable?(stack) ->
        indexed_stack
        |> Enum.reduce({[], nil}, fn {idx, child}, {acc, prev} ->
          child = enable_wrap(child, inner_w)
          height = child_height(child, inner_w, doc)
          orig_top = pref_top(child)

          new_top =
            case prev do
              nil ->
                orig_top

              {prev_top, prev_h, prev_orig_top} ->
                spacing = orig_top - prev_orig_top - prev_h
                prev_top + prev_h + max(spacing, 0)
            end

          shifted = set_pref_top(child, new_top)
          {acc ++ [{idx, shifted}], {new_top, height, orig_top}}
        end)
        |> elem(0)

      length(indexed_stack) == 1 ->
        [{idx, child}] = indexed_stack
        [{idx, enable_wrap(child, inner_w)}]

      true ->
        Enum.map(indexed_stack, fn {idx, child} -> {idx, enable_wrap(child, inner_w)} end)
    end
  end

  defp vertical_stack?(stack) do
    tops = Enum.map(stack, &pref_top/1)
    tops == Enum.sort(tops) and length(Enum.uniq(tops)) == length(tops)
  end

  defp stackable?(stack) do
    Enum.all?(stack, &stackable_child?/1)
  end

  defp stackable_child?(%{type: :line_segment}), do: false
  defp stackable_child?(%{type: :avatar}), do: false
  defp stackable_child?(%{type: :chip}), do: false
  defp stackable_child?(%{type: :key_value}), do: false
  defp stackable_child?(%{avatar: _}), do: false
  defp stackable_child?(%{chip: _}), do: false
  defp stackable_child?(%{key_value: _}), do: false
  defp stackable_child?(_), do: true

  # ── Child metrics ────────────────────────────────────────────────

  defp child_height(%{type: :text, props: props}, inner_w, doc) do
    style = Map.get(props, :style, %{})
    {x, _} = Map.get(style, :position, {0, 0})
    wrap_w = text_wrap_width(inner_w, x)
    Flow.measure_text(Map.get(props, :content, ""), style, wrap_w, doc)
  end

  defp child_height(%{text: text} = child, inner_w, doc) do
    x = Map.get(child, :x, 0)
    style = Map.drop(child, [:text, :x, :y, :position])
    Flow.measure_text(text, style, text_wrap_width(inner_w, x), doc)
  end

  defp child_height(%{type: :key_value, props: props}, inner_w, _doc) do
    style = Map.get(props, :style, %{})
    {x, _} = Map.get(style, :position, {0, 0})
    pairs = Map.get(props, :pairs, [])
    KeyValue.measure_height(style, pairs, inner_w, x_offset: kv_x_offset(x))
  end

  defp child_height(%{key_value: {x, _}, pairs: pairs} = child, inner_w, _doc) do
    style = Map.drop(child, [:key_value, :pairs])
    KeyValue.measure_height(style, pairs, inner_w, x_offset: kv_x_offset(x))
  end

  defp child_height(%{type: :avatar, props: props}, _inner_w, _doc) do
    {_, h} = normalize_size(Map.get(Map.get(props, :style, %{}), :size, 40))
    h
  end

  defp child_height(%{avatar: _} = child, _inner_w, _doc) do
    style = Map.drop(child, [:avatar])
    {_, h} = normalize_size(Map.get(style, :size, 40))
    h
  end

  defp child_height(%{type: :chip, props: props}, _inner_w, _doc) do
    Map.get(Map.get(props, :style, %{}), :height, 24)
  end

  defp child_height(%{chip: _} = child, _inner_w, _doc) do
    style = Map.drop(child, [:chip])
    Map.get(style, :height, 24)
  end

  defp child_height(%{type: :line_segment}, _inner_w, _doc), do: 0
  defp child_height(_, _inner_w, _doc), do: 0

  defp enable_wrap(%{type: :text, props: props} = child, inner_w) do
    style = Map.get(props, :style, %{})
    {x, _} = Map.get(style, :position, {0, 0})

    new_style =
      style
      |> Map.put(:break_text, true)
      |> Map.put(:wrap_width, text_wrap_width(inner_w, x))

    put_in(child, [:props, :style], new_style)
  end

  defp enable_wrap(%{text: text} = child, inner_w) when is_binary(text) do
    x = Map.get(child, :x, 0)

    child
    |> Map.put(:break_text, true)
    |> Map.put(:wrap_width, text_wrap_width(inner_w, x))
  end

  defp enable_wrap(%{type: :key_value, props: props} = child, inner_w) do
    style = Map.get(props, :style, %{})
    {x, _} = Map.get(style, :position, {0, 0})
    x_off = kv_x_offset(x)
    width = KeyValue.content_width(style, inner_w, x_off)
    put_in(child, [:props, :style], Map.put(style, :width, width))
  end

  defp enable_wrap(child, _inner_w), do: child

  # ── Position helpers ─────────────────────────────────────────────

  defp pref_top(%{type: :line_segment, props: props}) do
    style = Map.get(props, :style, %{})
    {_, y} = Map.get(style, :from, {0, 0})
    abs(y)
  end

  defp pref_top(%{type: _, props: props}) do
    {_, y} = Map.get(Map.get(props, :style, %{}), :position, {0, 0})
    abs(y)
  end

  defp pref_top(%{text: _} = child), do: abs(Map.get(child, :y, 0))
  defp pref_top(%{key_value: {_, y}}), do: abs(y)
  defp pref_top(%{avatar: {_, y}}), do: abs(y)
  defp pref_top(%{chip: {_, y}}), do: abs(y)
  defp pref_top(_), do: 0

  defp child_x(%{type: :line_segment, props: props}) do
    style = Map.get(props, :style, %{})
    {x, _} = Map.get(style, :from, {0, 0})
    x
  end

  defp child_x(%{type: _, props: props}) do
    {x, _} = Map.get(Map.get(props, :style, %{}), :position, {0, 0})
    x
  end

  defp child_x(%{text: _} = child), do: Map.get(child, :x, 0)
  defp child_x(%{key_value: {x, _}}), do: x
  defp child_x(%{avatar: {x, _}}), do: x
  defp child_x(%{chip: {x, _}}), do: x
  defp child_x(_), do: 0

  defp set_pref_top(%{type: :text, props: props} = child, top) do
    style = Map.get(props, :style, %{})
    {x, _} = Map.get(style, :position, {0, 0})
    put_in(child, [:props, :style], Map.put(style, :position, {x, -top}))
  end

  defp set_pref_top(%{text: _} = child, top) do
    x = Map.get(child, :x, 0)
    child |> Map.put(:x, x) |> Map.put(:y, -top)
  end

  defp set_pref_top(%{type: :key_value, props: props} = child, top) do
    style = Map.get(props, :style, %{})
    {x, _} = Map.get(style, :position, {0, 0})
    put_in(child, [:props, :style], Map.put(style, :position, {x, -top}))
  end

  defp set_pref_top(%{key_value: {x, _}} = child, top), do: Map.put(child, :key_value, {x, -top})

  defp set_pref_top(%{type: :avatar, props: props} = child, top) do
    style = Map.get(props, :style, %{})
    {x, _} = Map.get(style, :position, {0, 0})
    put_in(child, [:props, :style], Map.put(style, :position, {x, -top}))
  end

  defp set_pref_top(%{avatar: {x, _}} = child, top), do: Map.put(child, :avatar, {x, -top})

  defp set_pref_top(%{type: :chip, props: props} = child, top) do
    style = Map.get(props, :style, %{})
    {x, _} = Map.get(style, :position, {0, 0})
    put_in(child, [:props, :style], Map.put(style, :position, {x, -top}))
  end

  defp set_pref_top(%{chip: {x, _}} = child, top), do: Map.put(child, :chip, {x, -top})

  defp set_pref_top(child, _top), do: child

  defp shift_y(%{type: :line_segment, props: props} = child, delta) do
    style = Map.get(props, :style, %{})

    new_style =
      style
      |> update_point_y(:from, delta)
      |> update_point_y(:to, delta)

    put_in(child, [:props, :style], new_style)
  end

  defp shift_y(%{type: _, props: props} = child, delta) do
    style = Map.get(props, :style, %{})

    case Map.get(style, :position) do
      {x, y} ->
        put_in(child, [:props, :style], Map.put(style, :position, {x, y - delta}))

      _ ->
        child
    end
  end

  defp shift_y(%{text: _} = child, delta) do
    y = Map.get(child, :y, 0)
    Map.put(child, :y, y - delta)
  end

  defp shift_y(%{key_value: {x, y}} = child, delta), do: Map.put(child, :key_value, {x, y - delta})
  defp shift_y(%{avatar: {x, y}} = child, delta), do: Map.put(child, :avatar, {x, y - delta})
  defp shift_y(%{chip: {x, y}} = child, delta), do: Map.put(child, :chip, {x, y - delta})
  defp shift_y(child, _delta), do: child

  defp update_point_y(style, key, delta) do
    case Map.get(style, key) do
      {x, y} -> Map.put(style, key, {x, y - delta})
      _ -> style
    end
  end

  defp auto_anchor(children) do
    children
    |> Enum.filter(fn child ->
      case child do
        %{type: :line_segment, props: props} ->
          style = Map.get(props, :style, %{})
          {x, _} = Map.get(style, :from, {0, 0})
          x == 0 or x == :full

        _ ->
          false
      end
    end)
    |> Enum.map(&pref_top/1)
    |> case do
      [] ->
        children
        |> Enum.map(&pref_top/1)
        |> Enum.reject(&(&1 == 0))
        |> case do
          [] -> 0
          tops -> Enum.min(tops)
        end

      tops ->
        Enum.min(tops)
    end
  end

  defp child_id(_child), do: nil

  defp x_bucket(:full, _tolerance), do: :full

  defp x_bucket(x, tolerance) do
    trunc(Pdf.Dimension.resolve(x, 10_000) / max(tolerance, 1))
  end

  defp text_wrap_width(inner_w, x) do
    x_resolved = if x == :full, do: 0, else: abs(trunc(x))
    max(inner_w - x_resolved, 1)
  end

  defp kv_x_offset(x) when is_number(x), do: abs(trunc(x))
  defp kv_x_offset(_), do: 0

  defp normalize_size(size) when is_number(size), do: {size, size}
  defp normalize_size({w, h}), do: {w, h}
end
