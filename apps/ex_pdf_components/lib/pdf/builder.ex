defmodule Pdf.Builder do
  @moduledoc """
  Declarative PDF builder from template lists.

  Renders a list of content tuples into a PDF document, applying
  global configuration for page size, margins, fonts, and templates.

  ## Example

      template = [
        {:text, "Title", %{font_size: 24, bold: true}},
        {:spacer, 10},
        {:text, "Body text", %{font_size: 12}},
        {:line, %{color: :gray}},
        {:page_break},
        {:text, "Page 2", %{font_size: 18}}
      ]

      config = %{
        size: :a4,
        margin: 40,
        font: "Helvetica",
        font_size: 12
      }

      doc = Pdf.Builder.render(template, config)
      binary = Pdf.export(doc)
  """

  @doc """
  Render a template list with the given config into a PDF document.

  ## Config keys

  - `:size` — page size (default `:a4`)
  - `:margin` — margin value or map (default `0`)
  - `:font` — default font name (default `"Helvetica"`)
  - `:font_size` — default font size (default `12`)
  - `:compress` — compress streams (default `true`)
  - `:header` — `fn doc, page_info -> doc end` template
  - `:footer` — `fn doc, page_info -> doc end` template
  - `:watermark` — `fn doc, page_info -> doc end` template
  - `:background` — `fn doc, page_info -> doc end` template
  """
  def render(template, config \\ %{}) when is_list(template) do
    config = normalize_config(config)

    opts = [
      size: config.size,
      margin: config.margin,
      compress: config.compress
    ]

    doc = Pdf.new(opts)

    doc = register_templates(doc, config)

    doc =
      doc
      |> Pdf.set_font(config.font, config.font_size)

    Enum.reduce(List.flatten(template), doc, &render_element/2)
  end

  @doc """
  Render a template list into an existing document.
  Nested lists are automatically flattened.
  """
  def render_into(document, template) when is_list(template) do
    Enum.reduce(List.flatten(template), document, &render_element/2)
  end

  defp normalize_config(config) when is_map(config) do
    %{
      size: Map.get(config, :size, :a4),
      margin: Map.get(config, :margin, 0),
      font: Map.get(config, :font, "Helvetica"),
      font_size: Map.get(config, :font_size, 12),
      compress: Map.get(config, :compress, true),
      header: Map.get(config, :header),
      footer: Map.get(config, :footer),
      watermark: Map.get(config, :watermark),
      background: Map.get(config, :background),
      styles: Map.get(config, :styles, %{}),
      debug: Map.get(config, :debug)
    }
  end

  defp register_templates(doc, config) do
    doc
    |> register_styles(config.styles)
    |> maybe_register(:header, config.header)
    |> maybe_register(:footer, config.footer)
    |> maybe_register(:watermark, config.watermark)
    |> maybe_register(:background, config.background)
    |> maybe_debug_grid(config.debug)
  end

  defp maybe_debug_grid(doc, nil), do: doc
  defp maybe_debug_grid(doc, true), do: Pdf.debug_grid(doc)

  defp maybe_debug_grid(doc, debug_opts) when is_map(debug_opts),
    do: Pdf.debug_grid(doc, debug_opts)

  defp register_styles(doc, styles) when map_size(styles) == 0, do: doc
  defp register_styles(doc, styles), do: Pdf.register_styles(doc, styles)

  defp maybe_register(doc, _name, nil), do: doc

  defp maybe_register(doc, name, func) when is_function(func, 2) do
    Pdf.on_page(doc, name, func)
  end

  # ── Cursor-based component renderers ─────────────────────────────
  # When position is :cursor, resolve from document cursor + content_area.
  # Width :full resolves to content_area.width.
  # Cursor advances by element height after rendering.
  # Auto-pagination: if the element won't fit, a page break is inserted.

  defp render_element(%{box: :cursor, size: {w, h}} = el, doc) do
    {x, y, width} = resolve_cursor(doc, w)
    children = Map.get(el, :children, [])
    style = Map.drop(el, [:box, :size, :children])

    ca = Pdf.content_area(doc)

    if is_number(h) and h > ca.height do
      area = %{x: x, y: y, width: width, height: h}
      {doc, last_bottom} = render_children_paged(doc, children, area)
      Pdf.set_cursor(doc, last_bottom)
    else
      doc = maybe_page_break(doc, h)
      {x, y, width} = resolve_cursor(doc, w)

      doc =
        Pdf.Component.Box.render(doc, {x, y}, {width, h}, style, fn doc, area ->
          render_children(doc, children, area)
        end)

      Pdf.move_down(doc, h)
    end
  end

  defp render_element(%{row: :cursor, size: {w, h}} = el, doc) do
    {x, y, width} = resolve_cursor(doc, w)
    children = Map.get(el, :children, [])
    gap = Map.get(el, :gap, 0)

    ca = Pdf.content_area(doc)

    if is_number(h) and h > ca.height do
      render_multipage_row(doc, {x, y}, {width, h}, children, gap)
    else
      doc = maybe_page_break(doc, h)
      {x, y, width} = resolve_cursor(doc, w)

      columns =
        Enum.map(children, fn {weight, child_elements} ->
          {weight, fn doc, area ->
            render_children(doc, child_elements, area)
          end}
        end)

      doc = Pdf.Component.Row.render(doc, {x, y}, {width, h}, columns, gap: gap)
      Pdf.move_down(doc, h)
    end
  end

  defp render_element(%{column: :cursor, size: {w, h}} = el, doc) do
    {x, y, width} = resolve_cursor(doc, w)
    children = Map.get(el, :children, [])
    gap = Map.get(el, :gap, 0)

    ca = Pdf.content_area(doc)

    if is_number(h) and h > ca.height do
      render_multipage_column(doc, {x, y}, {width, h}, children, gap)
    else
      doc = maybe_page_break(doc, h)
      {x, y, width} = resolve_cursor(doc, w)

      rows =
        Enum.map(children, fn {height, child_elements} ->
          {height, fn doc, area ->
            render_children(doc, child_elements, area)
          end}
        end)

      doc = Pdf.Component.Column.render(doc, {x, y}, {width, h}, rows, gap: gap)
      Pdf.move_down(doc, h)
    end
  end

  defp render_element(%{rect: :cursor, size: {w, h}} = el, doc) do
    doc = maybe_page_break(doc, h)
    {x, cursor_y, width} = resolve_cursor(doc, w)
    # rect uses bottom-left in PDF coords; cursor_y is the top
    y = cursor_y - h
    el = el |> Map.put(:rect, {x, y}) |> Map.put(:size, {width, h})
    doc = render_element(el, doc)
    Pdf.move_down(doc, h)
  end

  defp render_element(%{card: :cursor, size: {w, h}} = el, doc) do
    {x, y, width} = resolve_cursor(doc, w)
    children = Map.get(el, :children, [])
    style = Map.drop(el, [:card, :size, :children])

    ca = Pdf.content_area(doc)

    if is_number(h) and h > ca.height do
      area = %{x: x, y: y, width: width, height: h}
      {doc, last_bottom} = render_children_paged(doc, children, area)
      Pdf.set_cursor(doc, last_bottom)
    else
      doc = maybe_page_break(doc, h)
      {x, y, width} = resolve_cursor(doc, w)

      doc =
        Pdf.Component.Card.render(doc, {x, y}, {width, h}, style, fn doc, area ->
          render_children(doc, children, area)
        end)

      Pdf.move_down(doc, h)
    end
  end

  # ── Absolute component renderers (box, row, column) ────────────
  # These patterns also contain keys like :background, :size, etc.
  # so they must match before the simpler map-based element renderers.

  defp render_element(%{box: {x, y}, size: {w, h}} = el, doc) do
    children = Map.get(el, :children, [])
    style = Map.drop(el, [:box, :size, :children])

    Pdf.Component.Box.render(doc, {x, y}, {w, h}, style, fn doc, area ->
      render_children(doc, children, area)
    end)
  end

  defp render_element(%{row: {x, y}, size: {w, h}} = el, doc) do
    children = Map.get(el, :children, [])
    gap = Map.get(el, :gap, 0)

    columns =
      Enum.map(children, fn {weight, child_elements} ->
        {weight, fn doc, area ->
          render_children(doc, child_elements, area)
        end}
      end)

    Pdf.Component.Row.render(doc, {x, y}, {w, h}, columns, gap: gap)
  end

  defp render_element(%{column: {x, y}, size: {w, _h}} = el, doc) do
    children = Map.get(el, :children, [])
    gap = Map.get(el, :gap, 0)
    h = elem(Map.get(el, :size), 1)

    rows =
      Enum.map(children, fn {height, child_elements} ->
        {height, fn doc, area ->
          render_children(doc, child_elements, area)
        end}
      end)

    Pdf.Component.Column.render(doc, {x, y}, {w, h}, rows, gap: gap)
  end

  # ── Map-based element renderers ─────────────────────────────────

  defp render_element(%{avatar: {x, y}} = el, doc) do
    style = Map.drop(el, [:avatar])
    Pdf.Component.Avatar.render(doc, {x, y}, style)
  end

  defp render_element(%{divider: {x, y}} = el, doc) do
    style = Map.drop(el, [:divider])
    Pdf.Component.Divider.render(doc, {x, y}, style)
  end

  defp render_element(%{badge: {x, y}} = el, doc) do
    style = Map.drop(el, [:badge])
    Pdf.Component.Badge.render(doc, {x, y}, style)
  end

  defp render_element(%{chip: {x, y}} = el, doc) do
    style = Map.drop(el, [:chip])
    {doc, _width} = Pdf.Component.Chip.render(doc, {x, y}, style)
    doc
  end

  defp render_element(%{progress: {x, y}} = el, doc) do
    style = Map.drop(el, [:progress])
    Pdf.Component.Progress.render(doc, {x, y}, style)
  end

  defp render_element(%{card: {x, y}, size: {w, h}} = el, doc) do
    children = Map.get(el, :children, [])
    style = Map.drop(el, [:card, :size, :children])

    Pdf.Component.Card.render(doc, {x, y}, {w, h}, style, fn doc, area ->
      render_children(doc, children, area)
    end)
  end

  defp render_element(%{key_value: {x, y}, pairs: pairs} = el, doc) do
    style = Map.drop(el, [:key_value, :pairs])
    Pdf.Component.KeyValue.render(doc, {x, y}, style, pairs)
  end

  defp render_element(%{text: string} = el, doc) do
    style = Map.drop(el, [:text])
    if map_size(style) == 0, do: Pdf.text(doc, string), else: Pdf.text(doc, string, style)
  end

  defp render_element(%{custom: func}, doc) when is_function(func, 1) do
    func.(doc)
  end

  defp render_element(%{spacer: amount}, doc) do
    Pdf.spacer(doc, amount)
  end

  defp render_element(%{line: style}, doc) when is_map(style) do
    Pdf.horizontal_line(doc, style)
  end

  defp render_element(%{line: true}, doc) do
    Pdf.horizontal_line(doc)
  end

  defp render_element(%{page_break: true}, doc) do
    Pdf.page_break(doc)
  end

  defp render_element(%{page_break: size}, doc) do
    Pdf.page_break(doc, size)
  end

  defp render_element(%{watermark: text} = el, doc) do
    style = Map.drop(el, [:watermark])
    if map_size(style) == 0, do: Pdf.watermark(doc, text), else: Pdf.watermark(doc, text, style)
  end

  defp render_element(%{background: style}, doc) do
    Pdf.background(doc, style)
  end

  defp render_element(%{rect: {x, y}, size: {w, h}} = el, doc) do
    fill = Map.get(el, :fill)
    stroke = Map.get(el, :stroke)
    lw = Map.get(el, :line_width, 0.5)
    r = Map.get(el, :border_radius, 0)

    doc = Pdf.save_state(doc)
    doc = Pdf.set_line_width(doc, lw)

    draw_rect = if r > 0 do
      &Pdf.rounded_rectangle(&1, {x, y}, {w, h}, r)
    else
      &Pdf.rectangle(&1, {x, y}, {w, h})
    end

    doc =
      if fill do
        doc |> Pdf.set_fill_color(fill) |> draw_rect.() |> Pdf.fill()
      else
        doc
      end

    doc =
      if stroke do
        doc |> Pdf.set_stroke_color(stroke) |> draw_rect.() |> Pdf.stroke()
      else
        doc
      end

    Pdf.restore_state(doc)
  end

  defp render_element(%{line_from: {x1, y1}, line_to: {x2, y2}} = el, doc) do
    stroke = Map.get(el, :stroke, {0, 0, 0})
    lw = Map.get(el, :line_width, 0.5)

    doc
    |> Pdf.save_state()
    |> Pdf.set_stroke_color(stroke)
    |> Pdf.set_line_width(lw)
    |> Pdf.line({x1, y1}, {x2, y2})
    |> Pdf.stroke()
    |> Pdf.restore_state()
  end

  # Horizontal line at cursor — offset version (relative x offsets within content area)
  defp render_element(%{line: :cursor} = el, doc) do
    stroke = Map.get(el, :stroke, {0.82, 0.82, 0.82})
    lw = Map.get(el, :line_width, 0.5)
    area = Pdf.content_area(doc)
    pos = Pdf.cursor_xy(doc)
    x1 = area.x + Map.get(el, :indent_left, 0)
    x2 = area.x + area.width - Map.get(el, :indent_right, 0)

    doc
    |> Pdf.save_state()
    |> Pdf.set_stroke_color(stroke)
    |> Pdf.set_line_width(lw)
    |> Pdf.line({x1, pos.y}, {x2, pos.y})
    |> Pdf.stroke()
    |> Pdf.restore_state()
    |> Pdf.move_down(lw + 2)
  end

  # ── Standardized type-based renderers ────────────────────────────
  # Format: %{type: :component, props: %{...data, style: %{position:, size:, ...}}}

  defp render_element(%{type: type, props: props}, doc) when is_atom(type) and is_map(props) do
    render_typed(type, props, doc)
  end

  defp render_element(%{type: type}, doc) when is_atom(type) do
    render_typed(type, %{}, doc)
  end

  # ── Tuple-based element renderers ────────────────────────────────

  defp render_element({:text, string}, doc) do
    Pdf.text(doc, string)
  end

  defp render_element({:text, string, style}, doc) do
    Pdf.text(doc, string, style)
  end

  defp render_element({:spacer, amount}, doc) do
    Pdf.spacer(doc, amount)
  end

  defp render_element({:line}, doc) do
    Pdf.horizontal_line(doc)
  end

  defp render_element({:line, style}, doc) do
    Pdf.horizontal_line(doc, style)
  end

  defp render_element({:page_break}, doc) do
    Pdf.page_break(doc)
  end

  defp render_element({:page_break, size}, doc) do
    Pdf.page_break(doc, size)
  end

  defp render_element({:watermark, text}, doc) do
    Pdf.watermark(doc, text)
  end

  defp render_element({:watermark, text, style}, doc) do
    Pdf.watermark(doc, text, style)
  end

  defp render_element({:background, style}, doc) do
    Pdf.background(doc, style)
  end

  defp render_element({:image, path, style}, doc) do
    pos = Pdf.cursor_xy(doc)
    opts = []
    opts = if Map.has_key?(style, :width), do: [{:width, style.width} | opts], else: opts
    opts = if Map.has_key?(style, :height), do: [{:height, style.height} | opts], else: opts
    Pdf.add_image(doc, {pos.x, pos.y}, path, opts)
  end

  defp render_element({:image, path}, doc) do
    pos = Pdf.cursor_xy(doc)
    Pdf.add_image(doc, {pos.x, pos.y}, path)
  end

  defp render_element({:table, data, opts}, doc) do
    Pdf.StyledTable.render(doc, data, opts)
  end

  defp render_element({:table, data}, doc) do
    Pdf.StyledTable.render(doc, data)
  end

  defp render_element({:set_font, name, size}, doc) do
    Pdf.set_font(doc, name, size)
  end

  defp render_element({:set_font, name, size, opts}, doc) do
    Pdf.set_font(doc, name, size, opts)
  end

  defp render_element({:list, items, style}, doc) do
    pos = Pdf.cursor_xy(doc)
    Pdf.Component.List.render(doc, {pos.x, pos.y}, style, items)
  end

  defp render_element({:list, items}, doc) do
    pos = Pdf.cursor_xy(doc)
    Pdf.Component.List.render(doc, {pos.x, pos.y}, %{}, items)
  end

  defp render_element({:blockquote, text, style}, doc) do
    pos = Pdf.cursor_xy(doc)
    Pdf.Component.Blockquote.render(doc, {pos.x, pos.y}, style, text)
  end

  defp render_element({:blockquote, text}, doc) do
    pos = Pdf.cursor_xy(doc)
    Pdf.Component.Blockquote.render(doc, {pos.x, pos.y}, %{}, text)
  end

  defp render_element({:code_block, code, style}, doc) do
    pos = Pdf.cursor_xy(doc)
    Pdf.Component.CodeBlock.render(doc, {pos.x, pos.y}, style, code)
  end

  defp render_element({:code_block, code}, doc) do
    pos = Pdf.cursor_xy(doc)
    Pdf.Component.CodeBlock.render(doc, {pos.x, pos.y}, %{}, code)
  end

  defp render_element({:signature, style}, doc) do
    pos = Pdf.cursor_xy(doc)
    Pdf.Component.Signature.render(doc, {pos.x, pos.y}, style)
  end

  defp render_element({:stat_card, style}, doc) do
    pos = Pdf.cursor_xy(doc)
    Pdf.Component.StatCard.render(doc, {pos.x, pos.y}, style)
  end

  defp render_element({:alert, style}, doc) do
    pos = Pdf.cursor_xy(doc)
    Pdf.Component.Alert.render(doc, {pos.x, pos.y}, style)
  end

  defp render_element({:key_value, pairs, style}, doc) do
    pos = Pdf.cursor_xy(doc)
    Pdf.Component.KeyValue.render(doc, {pos.x, pos.y}, style, pairs)
  end

  defp render_element({:key_value, pairs}, doc) do
    pos = Pdf.cursor_xy(doc)
    Pdf.Component.KeyValue.render(doc, {pos.x, pos.y}, %{}, pairs)
  end

  defp render_element({:timeline, events, style}, doc) do
    pos = Pdf.cursor_xy(doc)
    Pdf.Component.Timeline.render(doc, {pos.x, pos.y}, style, events)
  end

  defp render_element({:timeline, events}, doc) do
    pos = Pdf.cursor_xy(doc)
    Pdf.Component.Timeline.render(doc, {pos.x, pos.y}, %{}, events)
  end

  defp render_element({:step_indicator, steps, style}, doc) do
    pos = Pdf.cursor_xy(doc)
    Pdf.Component.StepIndicator.render(doc, {pos.x, pos.y}, style, steps)
  end

  defp render_element({:step_indicator, steps}, doc) do
    pos = Pdf.cursor_xy(doc)
    Pdf.Component.StepIndicator.render(doc, {pos.x, pos.y}, %{}, steps)
  end

  defp render_element({:rating, style}, doc) do
    pos = Pdf.cursor_xy(doc)
    Pdf.Component.Rating.render(doc, {pos.x, pos.y}, style)
  end

  defp render_element({:metric, style}, doc) do
    pos = Pdf.cursor_xy(doc)
    Pdf.Component.Metric.render(doc, {pos.x, pos.y}, style)
  end

  defp render_element({:toc, entries, style}, doc) do
    pos = Pdf.cursor_xy(doc)
    Pdf.Component.TOC.render(doc, {pos.x, pos.y}, style, entries)
  end

  defp render_element({:toc, entries}, doc) do
    pos = Pdf.cursor_xy(doc)
    Pdf.Component.TOC.render(doc, {pos.x, pos.y}, %{}, entries)
  end

  defp render_element({:footnote, notes, style}, doc) do
    pos = Pdf.cursor_xy(doc)
    Pdf.Component.Footnote.render(doc, {pos.x, pos.y}, style, notes)
  end

  defp render_element({:footnote, notes}, doc) do
    pos = Pdf.cursor_xy(doc)
    Pdf.Component.Footnote.render(doc, {pos.x, pos.y}, %{}, notes)
  end

  defp render_element({:paginator, style}, doc) do
    Pdf.Component.Paginator.apply(doc, style)
  end

  defp render_element({:paginator}, doc) do
    Pdf.Component.Paginator.apply(doc)
  end

  # ── Type-based render dispatch ──────────────────────────────────────

  defp render_typed(:text, props, doc) do
    content = Map.get(props, :content, "")
    style = Map.get(props, :style, %{})
    {pos, visual} = Map.pop(style, :position)
    visual = Map.drop(visual, [:size])

    text_style =
      case pos do
        {x, y} -> Map.merge(visual, %{x: x, y: y})
        _ -> visual
      end

    if map_size(text_style) == 0,
      do: Pdf.text(doc, content),
      else: Pdf.text(doc, content, text_style)
  end

  defp render_typed(:spacer, props, doc) do
    Pdf.spacer(doc, Map.get(props, :amount, 10))
  end

  defp render_typed(:page_break, _props, doc), do: Pdf.page_break(doc)

  defp render_typed(:line, props, doc) do
    style = Map.get(props, :style, %{})
    visual = Map.drop(style, [:position, :size])

    if map_size(visual) == 0,
      do: Pdf.horizontal_line(doc),
      else: Pdf.horizontal_line(doc, visual)
  end

  defp render_typed(:avatar, props, doc) do
    e = extract_typed_props(props)
    style = if e.size, do: Map.put(e.style, :size, e.size), else: e.style
    Pdf.Component.Avatar.render(doc, e.position, style)
  end

  defp render_typed(:divider, props, doc) do
    e = extract_typed_props(props)
    Pdf.Component.Divider.render(doc, e.position, e.style)
  end

  defp render_typed(:badge, props, doc) do
    e = extract_typed_props(props)
    Pdf.Component.Badge.render(doc, e.position, e.style)
  end

  defp render_typed(:chip, props, doc) do
    e = extract_typed_props(props)
    {doc, _w} = Pdf.Component.Chip.render(doc, e.position, e.style)
    doc
  end

  defp render_typed(:progress, props, doc) do
    e = extract_typed_props(props)
    Pdf.Component.Progress.render(doc, e.position, e.style)
  end

  defp render_typed(:key_value, props, doc) do
    e = extract_typed_props(props)
    pairs = Map.get(props, :pairs, [])
    Pdf.Component.KeyValue.render(doc, e.position, e.style, pairs)
  end

  defp render_typed(:box, props, doc) do
    e = extract_typed_props(props)
    render_typed_container(Pdf.Component.Box, e, doc)
  end

  defp render_typed(:card, props, doc) do
    e = extract_typed_props(props)
    render_typed_container(Pdf.Component.Card, e, doc)
  end

  defp render_typed(:row, props, doc) do
    e = extract_typed_props(props)
    gap = Map.get(e.style, :gap, 0)
    _style = Map.drop(e.style, [:gap])

    case e.position do
      :cursor ->
        {w_spec, h} = e.size
        {x, y, w} = resolve_cursor(doc, w_spec)

        ca = Pdf.content_area(doc)

        if is_number(h) and h > ca.height do
          render_multipage_row(doc, {x, y}, {w, h}, e.children, gap)
        else
          doc = maybe_page_break(doc, h)
          {x, y, w} = resolve_cursor(doc, w_spec)

          columns =
            Enum.map(e.children, fn {weight, child_elements} ->
              {weight, fn doc, area -> render_children(doc, child_elements, area) end}
            end)

          doc = Pdf.Component.Row.render(doc, {x, y}, {w, h}, columns, gap: gap)
          Pdf.move_down(doc, h)
        end

      {x, y} ->
        {w, h} = e.size

        columns =
          Enum.map(e.children, fn {weight, child_elements} ->
            {weight, fn doc, area -> render_children(doc, child_elements, area) end}
          end)

        Pdf.Component.Row.render(doc, {x, y}, {w, h}, columns, gap: gap)
    end
  end

  defp render_typed(:column, props, doc) do
    e = extract_typed_props(props)
    gap = Map.get(e.style, :gap, 0)

    case e.position do
      :cursor ->
        {w_spec, h} = e.size
        {x, y, w} = resolve_cursor(doc, w_spec)

        ca = Pdf.content_area(doc)

        if is_number(h) and h > ca.height do
          render_multipage_column(doc, {x, y}, {w, h}, e.children, gap)
        else
          doc = maybe_page_break(doc, h)
          {x, y, w} = resolve_cursor(doc, w_spec)

          rows =
            Enum.map(e.children, fn {height, child_elements} ->
              {height, fn doc, area -> render_children(doc, child_elements, area) end}
            end)

          doc = Pdf.Component.Column.render(doc, {x, y}, {w, h}, rows, gap: gap)
          Pdf.move_down(doc, h)
        end

      {x, y} ->
        {w, h} = e.size

        rows =
          Enum.map(e.children, fn {height, child_elements} ->
            {height, fn doc, area -> render_children(doc, child_elements, area) end}
          end)

        Pdf.Component.Column.render(doc, {x, y}, {w, h}, rows, gap: gap)
    end
  end

  defp render_typed(:rect, props, doc) do
    e = extract_typed_props(props)
    {x, y} = e.position
    {w, h} = e.size
    fill = Map.get(e.style, :fill)
    stroke = Map.get(e.style, :stroke)
    lw = Map.get(e.style, :line_width, 0.5)
    r = Map.get(e.style, :border_radius, 0)

    draw_fn =
      if r > 0,
        do: &Pdf.rounded_rectangle(&1, {x, y}, {w, h}, r),
        else: &Pdf.rectangle(&1, {x, y}, {w, h})

    doc = Pdf.save_state(doc) |> Pdf.set_line_width(lw)
    doc = if fill, do: doc |> Pdf.set_fill_color(fill) |> draw_fn.() |> Pdf.fill(), else: doc
    doc = if stroke, do: doc |> Pdf.set_stroke_color(stroke) |> draw_fn.() |> Pdf.stroke(), else: doc
    Pdf.restore_state(doc)
  end

  defp render_typed(:line_segment, props, doc) do
    style = Map.get(props, :style, %{})
    {x1, y1} = Map.get(style, :from, {0, 0})
    {x2, y2} = Map.get(style, :to, {0, 0})
    stroke = Map.get(style, :stroke, {0, 0, 0})
    lw = Map.get(style, :line_width, 0.5)

    doc
    |> Pdf.save_state()
    |> Pdf.set_stroke_color(stroke)
    |> Pdf.set_line_width(lw)
    |> Pdf.line({x1, y1}, {x2, y2})
    |> Pdf.stroke()
    |> Pdf.restore_state()
  end

  defp render_typed(:watermark, props, doc) do
    content = Map.get(props, :content, "")
    style = Map.get(props, :style, %{})
    visual = Map.drop(style, [:position, :size])
    if map_size(visual) == 0, do: Pdf.watermark(doc, content), else: Pdf.watermark(doc, content, visual)
  end

  defp render_typed(:background, props, doc) do
    style = Map.get(props, :style, %{})
    Pdf.background(doc, style)
  end

  defp render_typed(:alert, props, doc) do
    e = extract_typed_props(props)
    Pdf.Component.Alert.render(doc, e.position, e.style)
  end

  defp render_typed(:blockquote, props, doc) do
    e = extract_typed_props(props)
    text = Map.get(props, :text, "")
    Pdf.Component.Blockquote.render(doc, e.position, e.style, text)
  end

  defp render_typed(:code_block, props, doc) do
    e = extract_typed_props(props)
    code = Map.get(props, :code, "")
    Pdf.Component.CodeBlock.render(doc, e.position, e.style, code)
  end

  defp render_typed(:footnote, props, doc) do
    e = extract_typed_props(props)
    notes = Map.get(props, :notes, [])
    Pdf.Component.Footnote.render(doc, e.position, e.style, notes)
  end

  defp render_typed(:list, props, doc) do
    e = extract_typed_props(props)
    items = Map.get(props, :items, [])
    Pdf.Component.List.render(doc, e.position, e.style, items)
  end

  defp render_typed(:metric, props, doc) do
    e = extract_typed_props(props)
    Pdf.Component.Metric.render(doc, e.position, e.style)
  end

  defp render_typed(:rating, props, doc) do
    e = extract_typed_props(props)
    Pdf.Component.Rating.render(doc, e.position, e.style)
  end

  defp render_typed(:signature, props, doc) do
    e = extract_typed_props(props)
    Pdf.Component.Signature.render(doc, e.position, e.style)
  end

  defp render_typed(:stat_card, props, doc) do
    e = extract_typed_props(props)
    Pdf.Component.StatCard.render(doc, e.position, e.style)
  end

  defp render_typed(:step_indicator, props, doc) do
    e = extract_typed_props(props)
    steps = Map.get(props, :steps, [])
    Pdf.Component.StepIndicator.render(doc, e.position, e.style, steps)
  end

  defp render_typed(:timeline, props, doc) do
    e = extract_typed_props(props)
    events = Map.get(props, :events, [])
    Pdf.Component.Timeline.render(doc, e.position, e.style, events)
  end

  defp render_typed(:toc, props, doc) do
    e = extract_typed_props(props)
    entries = Map.get(props, :entries, [])
    Pdf.Component.TOC.render(doc, e.position, e.style, entries)
  end

  defp render_typed(:barcode, props, doc) do
    e = extract_typed_props(props)
    data = Map.get(props, :data, "")
    Pdf.Component.Barcode.render(doc, e.position, Map.put(e.style, :data, data))
  end

  defp render_typed(:qr, props, doc) do
    e = extract_typed_props(props)
    data = Map.get(props, :data, "")
    Pdf.Component.QrCode.render(doc, e.position, Map.put(e.style, :data, data))
  end

  defp render_typed(:paginator, props, doc) do
    style = Map.get(props, :style, %{})
    Pdf.Component.Paginator.apply(doc, style)
  end

  defp render_typed(:custom, props, doc) do
    func = Map.get(props, :callback)
    if is_function(func, 1), do: func.(doc), else: doc
  end

  # ── Type-based container helper ────────────────────────────────────

  defp render_typed_container(module, %{position: pos, size: size, style: style, children: children}, doc) do
    case pos do
      :cursor ->
        {w_spec, h} = size
        {x, y, w} = resolve_cursor(doc, w_spec)

        ca = Pdf.content_area(doc)

        if is_number(h) and h > ca.height do
          area = %{x: x, y: y, width: w, height: h}
          {doc, last_bottom} = render_children_paged(doc, children, area)
          Pdf.set_cursor(doc, last_bottom)
        else
          doc = maybe_page_break(doc, h)
          {x, y, w} = resolve_cursor(doc, w_spec)
          callback = fn doc, area -> render_children(doc, children, area) end
          doc = module.render(doc, {x, y}, {w, h}, style, callback)
          Pdf.move_down(doc, h)
        end

      {x, y} ->
        {w, h} = size
        callback = fn doc, area -> render_children(doc, children, area) end
        module.render(doc, {x, y}, {w, h}, style, callback)
    end
  end

  # ── Type-based props extraction ────────────────────────────────────

  defp extract_typed_props(props) do
    style = Map.get(props, :style, %{})
    {position, style} = Map.pop(style, :position, {0, 0})
    {size, style} = Map.pop(style, :size)
    children = Map.get(props, :children, [])
    data = Map.drop(props, [:style, :children])
    merged = Map.merge(data, style)

    %{position: position, size: size, style: merged, children: children}
  end

  # ── Child positioning helpers ──────────────────────────────────────

  defp render_children(doc, children, area) do
    children
    |> List.flatten()
    |> Enum.reduce(doc, fn child, doc ->
      child
      |> offset_child(area)
      |> render_element(doc)
    end)
  end

  defp offset_child(%{position: :absolute} = child, _area) do
    Map.delete(child, :position)
  end

  defp offset_child(%{text: _} = child, area) do
    x = Map.get(child, :x, 0) + area.x
    y = Map.get(child, :y, 0) + area.y
    Map.merge(child, %{x: x, y: y})
  end

  defp offset_child(%{rect: {rx, ry}, size: _} = child, area) do
    %{child | rect: {rx + area.x, ry + area.y}}
  end

  defp offset_child(%{line_from: {x1, y1}, line_to: {x2, y2}} = child, area) do
    %{child | line_from: {x1 + area.x, y1 + area.y}, line_to: {x2 + area.x, y2 + area.y}}
  end

  defp offset_child(%{avatar: {ax, ay}} = child, area) do
    %{child | avatar: {ax + area.x, ay + area.y}}
  end

  defp offset_child(%{divider: {dx, dy}} = child, area) do
    %{child | divider: {dx + area.x, dy + area.y}}
  end

  defp offset_child(%{badge: {bx, by}} = child, area) do
    %{child | badge: {bx + area.x, by + area.y}}
  end

  defp offset_child(%{chip: {cx, cy}} = child, area) do
    %{child | chip: {cx + area.x, cy + area.y}}
  end

  defp offset_child(%{key_value: {kx, ky}} = child, area) do
    %{child | key_value: {kx + area.x, ky + area.y}}
  end

  defp offset_child(%{progress: {px, py}} = child, area) do
    %{child | progress: {px + area.x, py + area.y}}
  end

  defp offset_child(%{card: {cx, cy}} = child, area) do
    child = %{child | card: {cx + area.x, cy + area.y}}
    resolve_child_size(child, area)
  end

  defp offset_child(%{box: {bx, by}} = child, area) do
    child = %{child | box: {bx + area.x, by + area.y}}
    resolve_child_size(child, area)
  end

  defp offset_child(%{row: {rx, ry}} = child, area) do
    child = %{child | row: {rx + area.x, ry + area.y}}
    resolve_child_size(child, area)
  end

  defp offset_child(%{column: {cx, cy}} = child, area) do
    child = %{child | column: {cx + area.x, cy + area.y}}
    resolve_child_size(child, area)
  end

  # ── Type-based offset (single generic handler) ─────────────────────

  defp offset_child(%{type: :line_segment, props: %{style: style} = props} = child, area) do
    from = Map.get(style, :from, {0, 0})
    to = Map.get(style, :to, {0, 0})

    new_style =
      style
      |> Map.put(:from, resolve_and_offset_point(from, area))
      |> Map.put(:to, resolve_and_offset_point(to, area))

    %{child | props: %{props | style: new_style}}
  end

  defp offset_child(%{type: _, props: props} = child, area) do
    style = Map.get(props, :style, %{})

    case Map.get(style, :position) do
      {px, py} ->
        new_style = Map.put(style, :position, {px + area.x, py + area.y})

        new_style =
          case Map.get(new_style, :size) do
            {_, _} = size -> Map.put(new_style, :size, Pdf.Dimension.resolve_size(size, area))
            _ -> new_style
          end

        new_style = resolve_style_dims(new_style, area)

        %{child | props: Map.put(props, :style, new_style)}

      _ ->
        child
    end
  end

  defp offset_child(child, _area), do: child

  # ── Dimension resolution helpers ───────────────────────────────

  defp resolve_style_dims(style, area) do
    style
    |> resolve_dim(:width, area.width)
    |> resolve_dim(:height, area.height)
  end

  defp resolve_dim(style, key, parent_dim) do
    case Map.get(style, key) do
      nil -> style
      val -> Map.put(style, key, Pdf.Dimension.resolve(val, parent_dim))
    end
  end

  defp resolve_and_offset_point({x, y}, area) do
    {Pdf.Dimension.resolve(x, area.width) + area.x,
     Pdf.Dimension.resolve(y, area.height) + area.y}
  end

  # ── Relative size resolution ─────────────────────────────────────

  defp resolve_child_size(%{size: size} = child, area) do
    %{child | size: Pdf.Dimension.resolve_size(size, area)}
  end

  defp resolve_child_size(child, _area), do: child

  # ── Auto-pagination ─────────────────────────────────────────────
  # If the element height would push the cursor below the content area
  # bottom boundary, insert a page break first.

  defp maybe_page_break(doc, h) when is_number(h) and h > 0 do
    pos = Pdf.cursor_xy(doc)
    area = Pdf.content_area(doc)
    bottom = area.y - area.height

    if pos.y - h < bottom do
      Pdf.page_break(doc)
    else
      doc
    end
  end

  defp maybe_page_break(doc, _h), do: doc

  # ── Multi-page overflow support ──────────────────────────────────
  # When a row is taller than the available page space, these helpers
  # split rendering across pages: non-overflowing columns render first
  # (staying on the current page), then overflowing columns auto-paginate.

  defp child_y_bounds(%{type: _, props: props}) do
    style = Map.get(props, :style, %{})

    case {Map.get(style, :position), Map.get(style, :size)} do
      {{_px, py}, {_w, h}} when is_number(py) and is_number(h) -> {py, h}
      _ -> :unknown
    end
  end

  defp child_y_bounds(%{box: {_, by}, size: {_, h}}) when is_number(h), do: {by, h}
  defp child_y_bounds(%{row: {_, ry}, size: {_, h}}) when is_number(h), do: {ry, h}
  defp child_y_bounds(%{column: {_, cy}, size: {_, h}}) when is_number(h), do: {cy, h}
  defp child_y_bounds(%{card: {_, cy}, size: {_, h}}) when is_number(h), do: {cy, h}
  defp child_y_bounds(%{rect: {_, ry}, size: {_, h}}) when is_number(h), do: {ry, h}
  defp child_y_bounds(_), do: :unknown

  defp column_overflows?(children, area, page_bottom) do
    children
    |> List.flatten()
    |> Enum.any?(fn child ->
      case child_y_bounds(child) do
        {y_off, h} -> area.y + y_off - h < page_bottom
        :unknown -> false
      end
    end)
  end

  defp render_children_paged(doc, children, area) do
    {doc, _area, last_bottom} =
      children
      |> List.flatten()
      |> Enum.reduce({doc, area, area.y}, fn child, {doc, current_area, last_bottom} ->
        case child_y_bounds(child) do
          {y_off, h} ->
            abs_bottom = current_area.y + y_off - h
            page_ca = Pdf.content_area(doc)
            page_bottom = page_ca.y - page_ca.height

            if abs_bottom < page_bottom do
              doc = Pdf.page_break(doc)
              new_ca = Pdf.content_area(doc)
              new_area = %{current_area | y: new_ca.y - y_off}
              new_bottom = new_area.y + y_off - h
              doc = child |> offset_child(new_area) |> render_element(doc)
              {doc, new_area, new_bottom}
            else
              doc = child |> offset_child(current_area) |> render_element(doc)
              {doc, current_area, abs_bottom}
            end

          :unknown ->
            doc = child |> offset_child(current_area) |> render_element(doc)
            {doc, current_area, last_bottom}
        end
      end)

    {doc, last_bottom}
  end

  defp render_multipage_row(doc, {x, y}, {w, h}, column_defs, gap) do
    total_weight = column_defs |> Enum.map(&elem(&1, 0)) |> Enum.sum()
    gap_total = gap * max(length(column_defs) - 1, 0)
    available_w = w - gap_total

    {cols, _} =
      Enum.reduce(column_defs, {[], x}, fn {weight, child_elements}, {acc, col_x} ->
        col_w = available_w * (weight / total_weight)
        col_area = %{x: col_x, y: y, width: col_w, height: h}
        {acc ++ [{child_elements, col_area}], col_x + col_w + gap}
      end)

    ca = Pdf.content_area(doc)
    page_bottom = ca.y - ca.height

    {fitting, overflowing} =
      Enum.split_with(cols, fn {children, area} ->
        not column_overflows?(children, area, page_bottom)
      end)

    doc =
      Enum.reduce(fitting, doc, fn {children, area}, doc ->
        render_children(doc, children, area)
      end)

    {doc, last_bottom} =
      Enum.reduce(overflowing, {doc, y}, fn {children, area}, {doc, _} ->
        render_children_paged(doc, children, area)
      end)

    Pdf.set_cursor(doc, last_bottom)
  end

  defp render_multipage_column(doc, {x, y}, {w, _h}, row_defs, gap) do
    {doc, last_y} =
      Enum.reduce(row_defs, {doc, y}, fn {row_h, child_elements}, {doc, row_y} ->
        abs_bottom = row_y - row_h
        page_ca = Pdf.content_area(doc)
        page_bottom = page_ca.y - page_ca.height

        {doc, row_y} =
          if abs_bottom < page_bottom do
            doc = Pdf.page_break(doc)
            new_ca = Pdf.content_area(doc)
            {doc, new_ca.y}
          else
            {doc, row_y}
          end

        area = %{x: x, y: row_y, width: w, height: row_h}
        doc = render_children(doc, child_elements, area)
        {doc, row_y - row_h - gap}
      end)

    Pdf.set_cursor(doc, last_y + gap)
  end

  # ── Cursor position resolution ─────────────────────────────────

  defp resolve_cursor(doc, width) do
    area = Pdf.content_area(doc)
    pos = Pdf.cursor_xy(doc)
    w = resolve_width(width, area.width)
    {area.x, pos.y, w}
  end

  defp resolve_width(:full, area_width), do: area_width
  defp resolve_width(w, _area_width) when is_number(w), do: w
end
