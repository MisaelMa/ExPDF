defmodule Pdf.Layout.Flow do
  @moduledoc false

  @default_gap 0
  @default_font "Helvetica"
  @default_font_size 12

  @doc """
  Measure total vertical space needed for flow children inside `inner_width`.
  """
  def measure_children(children, inner_width, doc \\ nil, opts \\ []) do
    gap = Keyword.get(opts, :gap, @default_gap)

    children
    |> List.flatten()
    |> Enum.with_index()
    |> Enum.reduce(0, fn {child, index}, total ->
      {child_height, _gap} = child_metrics(child, inner_width, doc, gap)
      spacing = if index == 0, do: 0, else: gap
      total + spacing + child_height
    end)
    |> max(0)
  end

  @doc """
  Render children in vertical flow inside `area`.

  `render_child` is `fn doc, child, child_area -> doc`.
  """
  def render(doc, area, style, children, render_child) when is_function(render_child, 3) do
    gap = Map.get(style, :gap, @default_gap)

    {doc, _y} =
      children
      |> List.flatten()
      |> Enum.reduce({doc, area.y}, fn child, {doc, current_y} ->
        {child_height, gap} = child_metrics(child, area.width, doc, gap)
        x_offset = child_x_offset(child, area.width)
        child_area = %{area | x: area.x + x_offset, y: current_y, width: area.width - x_offset}

        doc = render_child.(doc, child, child_area)
        {doc, current_y - child_height - gap}
      end)

    doc
  end

  @doc """
  Compute inner content width for a box style and outer width.
  """
  def inner_width(outer_width, style) do
    style = Pdf.Style.new(style)
    {_mt, mr, _mb, ml} = style.margin
    {_pt, pr, _pb, pl} = style.padding
    {_bt, br, _bb, bl} = style.border

    outer_w = outer_width - ml - mr
    outer_w - bl - br - pl - pr
  end

  @doc """
  Compute total outer box height from inner content height and style insets.
  """
  def outer_height(inner_content_height, style) do
    style = Pdf.Style.new(style)
    {mt, _mr, mb, _ml} = style.margin
    {pt, _pr, pb, _pl} = style.padding
    {bt, _br, bb, _bl} = style.border

    inner_content_height + pt + pb + bt + bb + mt + mb
  end

  defp child_metrics(%{position: :absolute}, _width, _doc, gap), do: {0, gap}

  defp child_metrics(%{type: type, props: props}, width, doc, gap) do
    measure_typed(type, props, width, doc, gap)
  end

  defp child_metrics(child, width, doc, gap) do
    cond do
      Map.has_key?(child, :text) -> measure_text_child(child, width, doc, gap)
      Map.has_key?(child, :key_value) -> measure_key_value_child(child, width, gap)
      Map.has_key?(child, :avatar) -> measure_avatar_child(child, gap)
      Map.has_key?(child, :chip) -> measure_chip_child(child, gap)
      Map.has_key?(child, :spacer) -> {Map.get(child, :spacer, 0), gap}
      Map.has_key?(child, :box) -> measure_box_child(child, width, doc, gap)
      Map.has_key?(child, :row) -> measure_row_child(child, gap)
      Map.has_key?(child, :column) -> measure_column_child(child, gap)
      Map.has_key?(child, :line_segment) -> {0, gap}
      true -> {0, gap}
    end
  end

  defp measure_typed(:text, props, width, doc, gap) do
    content = Map.get(props, :content, "")
    style = Map.get(props, :style, %{})
    x_offset = resolve_offset(elem(Map.get(style, :position, {0, 0}), 0), width)
    wrap_width = max(width - x_offset, 1)
    {measure_text(content, style, wrap_width, doc), gap}
  end

  defp measure_typed(:key_value, props, width, _doc, gap) do
    style = Map.get(props, :style, %{})
    pairs = Map.get(props, :pairs, [])
    {x, _} = Map.get(style, :position, {0, 0})
    x_off = resolve_offset(x, width)

    {Pdf.Component.KeyValue.measure_height(style, pairs, width, x_offset: x_off), gap}
  end

  defp measure_typed(:avatar, props, _width, _doc, gap) do
    style = Map.get(props, :style, %{})
    {_, h} = normalize_size(Map.get(style, :size, 40))
    {h, gap}
  end

  defp measure_typed(:chip, props, _width, _doc, gap) do
    style = Map.get(props, :style, %{})
    {Map.get(style, :height, 24), gap}
  end

  defp measure_typed(:spacer, props, _width, _doc, gap) do
    {Map.get(props, :amount, 10), gap}
  end

  defp measure_typed(:box, props, width, doc, gap) do
    style = Map.get(props, :style, %{})
    children = Map.get(props, :children, [])
    {w_spec, h_spec} = Map.get(style, :size, {:full, :auto})

    inner_w =
      w_spec
      |> resolve_width(width)
      |> then(&inner_width(&1, style))

    height =
      case h_spec do
        :auto -> inner_content_height(children, inner_w, style, doc)
        h -> resolve_height(h, width)
      end

    {height, gap}
  end

  defp measure_typed(:row, props, width, _doc, gap) do
    style = Map.get(props, :style, %{})
    {_, h} = Map.get(style, :size, {:full, 0})
    {resolve_height(h, width), gap}
  end

  defp measure_typed(:column, props, width, _doc, gap) do
    style = Map.get(props, :style, %{})
    children = Map.get(props, :children, [])
    row_gap = Map.get(style, :gap, 0)

    total =
      Enum.reduce(children, 0, fn {row_h, _children}, acc ->
        acc + resolve_height(row_h, width) + row_gap
      end)

    {max(total - row_gap, 0), gap}
  end

  defp measure_typed(_type, _props, _width, _doc, gap), do: {0, gap}

  defp measure_text_child(child, width, doc, gap) do
    x_offset = resolve_offset(Map.get(child, :x, 0), width)
    wrap_width = max(width - x_offset, 1)
    style = Map.drop(child, [:text, :x, :y, :position])
    {measure_text(Map.get(child, :text, ""), style, wrap_width, doc), gap}
  end

  defp measure_key_value_child(child, width, gap) do
    style = Map.drop(child, [:key_value, :pairs])
    pairs = Map.get(child, :pairs, [])
    {x, _} = Map.get(child, :key_value, {0, 0})
    x_off = resolve_offset(x, width)
    {Pdf.Component.KeyValue.measure_height(style, pairs, width, x_offset: x_off), gap}
  end

  defp measure_avatar_child(child, gap) do
    style = Map.drop(child, [:avatar])
    {_, h} = normalize_size(Map.get(style, :size, 40))
    {h, gap}
  end

  defp measure_chip_child(child, gap) do
    style = Map.drop(child, [:chip])
    {Map.get(style, :height, 24), gap}
  end

  defp measure_box_child(child, width, doc, gap) do
    style = Map.drop(child, [:box, :children])
    children = Map.get(child, :children, [])
    {w_spec, h_spec} = Map.get(child, :size, {:full, :auto})

    inner_w =
      w_spec
      |> resolve_width(width)
      |> then(&inner_width(&1, style))

    height =
      case h_spec do
        :auto -> inner_content_height(children, inner_w, style, doc)
        h -> resolve_height(h, width)
      end

    {height, gap}
  end

  defp measure_row_child(child, gap) do
    {_, h} = Map.get(child, :size, {:full, 0})
    {h, gap}
  end

  defp measure_column_child(child, gap) do
    children = Map.get(child, :children, [])
    row_gap = Map.get(child, :gap, 0)

    total =
      Enum.reduce(children, 0, fn {row_h, _children}, acc ->
        acc + row_h + row_gap
      end)

    {max(total - row_gap, 0), gap}
  end

  @doc """
  Measure a vertical stack of `{text, style}` entries with word wrap.
  """
  def measure_text_stack(entries, width, doc \\ nil, opts \\ []) do
    gap = Keyword.get(opts, :gap, 0)

    entries
    |> Enum.with_index()
    |> Enum.reduce(0, fn {{text, style}, index}, total ->
      height = measure_text(text, style, width, doc)
      spacing = if index == 0, do: 0, else: gap
      total + spacing + height
    end)
  end

  @doc false
  def measure_text(content, style, wrap_width, doc \\ nil) do
    font_size = Map.get(style, :font_size, default_font_size(doc))
    line_height = Map.get(style, :line_height, line_height_for(font_size, style))
    font = font_for(style, doc)
    line_count = content |> wrap_lines(wrap_width, font, font_size) |> length()
    line_count * line_height
  end

  defp wrap_lines(content, wrap_width, font, font_size) when is_binary(content) do
    content
    |> then(&Pdf.Text.chunk_text(&1, font, font_size))
    |> Pdf.Text.wrap_all_chunks(wrap_width)
    |> Enum.map(fn {:line, chunks} ->
      chunks
      |> Enum.reject(&(elem(&1, 1) == 0.00))
      |> Enum.map_join("", &elem(&1, 0))
    end)
  end

  defp wrap_lines(content, wrap_width, font, font_size) when is_list(content) do
    words =
      Enum.flat_map(content, fn
        %{text: text} = seg ->
          color = Map.get(seg, :color, :black)

          text
          |> String.split(~r/\s+/, trim: true)
          |> Enum.map(fn word -> {word, color} end)

        text when is_binary(text) ->
          text
          |> String.split(~r/\s+/, trim: true)
          |> Enum.map(fn word -> {word, :black} end)
      end)

    wrap_colored_words(words, font, font_size, wrap_width)
  end

  defp wrap_colored_words(words, font, font_size, max_width) do
    {lines, {curr_words, _curr_w}} =
      Enum.reduce(words, {[], {[], 0}}, fn
        {word, _color}, {lines, {[], 0}} ->
          word_w = Pdf.Font.text_width(font, word, font_size)
          {lines, {[word], word_w}}

        {word, _color}, {lines, {curr_words, curr_w}} ->
          word_w = Pdf.Font.text_width(font, word, font_size)
          space_w = Pdf.Font.text_width(font, " ", font_size)

          if curr_w + space_w + word_w <= max_width do
            {lines, {curr_words ++ [word], curr_w + space_w + word_w}}
          else
            {lines ++ [Enum.join(curr_words, " ")], {[word], word_w}}
          end
      end)

    lines =
      case curr_words do
        [] -> lines
        words -> lines ++ [Enum.join(words, " ")]
      end

    Enum.reject(lines, &(&1 == ""))
  end

  defp child_x_offset(%{position: :absolute}, _width), do: 0

  defp child_x_offset(%{type: _, props: props}, width) do
    style = Map.get(props, :style, %{})
    resolve_offset(elem(Map.get(style, :position, {0, 0}), 0), width)
  end

  defp child_x_offset(child, width) do
    resolve_offset(Map.get(child, :x, 0), width)
  end

  defp resolve_offset(value, parent_width) do
    Pdf.Dimension.resolve(value, parent_width)
  end

  defp resolve_width(:full, parent_width), do: parent_width
  defp resolve_width(value, parent_width), do: Pdf.Dimension.resolve(value, parent_width)

  defp resolve_height(:full, parent_height), do: parent_height
  defp resolve_height(value, parent_height), do: Pdf.Dimension.resolve(value, parent_height)

  defp normalize_size(size) when is_number(size), do: {size, size}
  defp normalize_size({w, h}), do: {w, h}

  defp inner_content_height(children, inner_w, style, doc) do
    children
    |> measure_children(inner_w, doc)
    |> then(&inner_insets(&1, style))
  end

  defp inner_insets(content_height, style) do
    style = Pdf.Style.new(style)
    {pt, _pr, pb, _pl} = style.padding
    {bt, _br, bb, _bl} = style.border
    content_height + pt + pb + bt + bb
  end

  defp line_height_for(font_size, style) do
    case Map.get(style, :leading) do
      nil -> font_size * 1.2
      leading -> leading
    end
  end

  defp font_for(style, doc) do
    font_name = Map.get(style, :font, @default_font)
    bold = Map.get(style, :bold, false)
    italic = Map.get(style, :italic, false)

    case Pdf.Fonts.get_internal_font(font_name, bold: bold, italic: italic) do
      nil ->
        doc
        |> current_font()
        |> fallback_font()

      font ->
        font
    end
  end

  defp default_font_size(doc) do
    case doc do
      %{current: %{current_font_size: size}} when is_number(size) -> size
      _ -> @default_font_size
    end
  end

  defp current_font(%{current: %{current_font: %{module: font}}}), do: font
  defp current_font(_), do: nil

  defp fallback_font(nil), do: Pdf.Fonts.get_internal_font(@default_font, [])
  defp fallback_font(font), do: font
end
