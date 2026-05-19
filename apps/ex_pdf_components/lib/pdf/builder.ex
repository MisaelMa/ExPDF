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

  defp render_element(%{box: :cursor, size: {w, h}} = el, doc) do
    {x, y, width} = resolve_cursor(doc, w)
    children = Map.get(el, :children, [])
    style = Map.drop(el, [:box, :size, :children])

    doc =
      Pdf.Component.Box.render(doc, {x, y}, {width, h}, style, fn doc, area ->
        render_children(doc, children, area)
      end)

    Pdf.move_down(doc, h)
  end

  defp render_element(%{row: :cursor, size: {w, h}} = el, doc) do
    {x, y, width} = resolve_cursor(doc, w)
    children = Map.get(el, :children, [])
    gap = Map.get(el, :gap, 0)

    columns =
      Enum.map(children, fn {weight, child_elements} ->
        {weight, fn doc, area ->
          render_children(doc, child_elements, area)
        end}
      end)

    doc = Pdf.Component.Row.render(doc, {x, y}, {width, h}, columns, gap: gap)
    Pdf.move_down(doc, h)
  end

  defp render_element(%{column: :cursor, size: {w, h}} = el, doc) do
    {x, y, width} = resolve_cursor(doc, w)
    children = Map.get(el, :children, [])
    gap = Map.get(el, :gap, 0)

    rows =
      Enum.map(children, fn {height, child_elements} ->
        {height, fn doc, area ->
          render_children(doc, child_elements, area)
        end}
      end)

    doc = Pdf.Component.Column.render(doc, {x, y}, {width, h}, rows, gap: gap)
    Pdf.move_down(doc, h)
  end

  defp render_element(%{rect: :cursor, size: {w, h}} = el, doc) do
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

    doc =
      Pdf.Component.Card.render(doc, {x, y}, {width, h}, style, fn doc, area ->
        render_children(doc, children, area)
      end)

    Pdf.move_down(doc, h)
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

  defp offset_child(child, _area), do: child

  # ── Relative size resolution ─────────────────────────────────────

  defp resolve_child_size(%{size: size} = child, area) do
    %{child | size: Pdf.Dimension.resolve_size(size, area)}
  end

  defp resolve_child_size(child, _area), do: child

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
