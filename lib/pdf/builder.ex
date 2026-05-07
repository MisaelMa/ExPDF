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

  # ── Map-based element renderers ─────────────────────────────────

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

    doc = Pdf.save_state(doc)
    doc = Pdf.set_line_width(doc, lw)

    doc =
      if fill do
        doc |> Pdf.set_fill_color(fill) |> Pdf.rectangle({x, y}, {w, h}) |> Pdf.fill()
      else
        doc
      end

    doc =
      if stroke do
        doc |> Pdf.set_stroke_color(stroke) |> Pdf.rectangle({x, y}, {w, h}) |> Pdf.stroke()
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

  # ── Element renderers ──────────────────────────────────────────────

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
    Pdf.styled_table(doc, data, opts)
  end

  defp render_element({:table, data}, doc) do
    Pdf.styled_table(doc, data)
  end

  defp render_element({:set_font, name, size}, doc) do
    Pdf.set_font(doc, name, size)
  end

  defp render_element({:set_font, name, size, opts}, doc) do
    Pdf.set_font(doc, name, size, opts)
  end
end
