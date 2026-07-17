defmodule Pdf.StyledTable do
  @moduledoc """
  Styled table component with CSS-like configuration.
  Includes custom word-wrap, multiline support, and rich text capabilities for dynamic cell heights.
  """
  @moduledoc """
  Styled table component with CSS-like configuration for PDF generation.

  ## Ejemplo de uso

      data = [
        ["Nombre", "Cantidad", "Precio"],
        ["Producto A", "10", "$100.00"],
        [{:regular, "Producto B"}, {:bold, "5"}, {:regular, "$50.00"}]
      ]

      Pdf.StyledTable.render(doc, data, %{
        columns: [
          %{width: 200, align: :left},
          %{width: 50, align: :center},
          %{width: 100, align: :right}
        ],
        header: %{bold: true, background: "#E6E6E6", padding: 5},
        row: %{padding: 5, border_bottom: 0.5},
        border: 1
      })

  Este componente incluye soporte para:
  - Ajuste de texto automático (Word-wrap).
  - Estilos dinámicos por fila (Header, Body, Alt-row).
  - Texto enriquecido (Rich Text) pasando tuplas `{:bold, "texto"}` o `{:regular, "texto"}`.
  """

  alias Pdf.{Page, Style}

  @default_opts %{
    columns: [],
    header: nil,
    row: %{},
    alt_row: nil,
    footer: nil,
    border: 0,
    border_color: :black,
    border_radius: 0,
    background: nil,
    padding: {4, 6, 4, 6},
    font: "Helvetica",
    font_size: 10,
    color: :black,
    line_height: 14
  }
  @doc """
  Render a styled table on the document at the current cursor position.

  Returns the updated document with cursor moved below the table.

  ## Options

  - `:columns` — list of column config maps: `%{width: n, align: :left|:center|:right, style: %{}}`
  - `:header` — style map for header row (first row of data), or `nil` to treat all rows as body
  - `:row` — default style map for body rows
  - `:alt_row` — style map merged into every other body row (zebra stripes)
  - `:footer` — style map for the last row
  - `:border` — outer border width (number)
  - `:border_color` — outer border color
  - `:border_radius` — corner radius for outer border
  - `:background` — default cell background
  - `:padding` — default cell padding (CSS shorthand)
  - `:font`, `:font_size`, `:color` — default text styling
  - `:line_height` — height per text line in points
  """

  def render(document, data, opts \\ %{}) when is_list(data) do
    opts = Map.merge(@default_opts, opts)
    {at, opts} = Map.pop(opts, :at)
    table_width = Map.get(opts, :table_width)

    area = Pdf.content_area(document)
    available_width = table_width || area.width

    {table_x, table_y} =
      case at do
        {x, y} when is_number(x) and is_number(y) ->
          {x, y}

        _ ->
          pos = Pdf.cursor_xy(document)
          {pos.x, pos.y}
      end

    cols = resolve_columns(data, opts, available_width)
    total_width = Enum.reduce(cols, 0, fn col, acc -> acc + col.width end)

    rows = prepare_rows(data, opts, cols, document)
    total_height = Enum.reduce(rows, 0, fn row, acc -> acc + row.height end)

    r = opts.border_radius

    document = draw_clipped_backgrounds(document, rows, cols, {table_x, table_y}, {total_width, total_height}, r, opts)

    {document, _y} =
      Enum.reduce(rows, {document, table_y}, fn row, {doc, y} ->
        doc = draw_row_content(doc, row, cols, {table_x, y}, opts)
        {doc, y - row.height}
      end)

    document = draw_outer_border(document, {table_x, table_y}, {total_width, total_height}, opts)

    if at == nil do
      Pdf.set_cursor(document, table_y - total_height)
    else
      document
    end
  end

  def render_on_page(page, {x, y}, data, opts \\ %{}) do
    opts = Map.merge(@default_opts, opts)

    cols = resolve_columns_with_total(data, opts)
    total_width = Enum.reduce(cols, 0, fn col, acc -> acc + col.width end)

    rows = prepare_rows(data, opts, cols, page)
    total_height = Enum.reduce(rows, 0, fn row, acc -> acc + row.height end)
    r = opts.border_radius

    page = draw_clipped_backgrounds_page(page, rows, cols, {x, y}, {total_width, total_height}, r, opts)

    {page, _y} =
      Enum.reduce(rows, {page, y}, fn row, {pg, cy} ->
        pg = draw_row_content_page(pg, row, cols, {x, cy}, opts)
        {pg, cy - row.height}
      end)

    draw_outer_border_page(page, {x, y}, {total_width, total_height}, opts)
  end

  # ── Column resolution ──────────────────────────────────────────────

  defp resolve_columns(data, opts, available_width) do
    num_cols = data |> List.first([]) |> length()
    col_defs = opts.columns

    Enum.map(0..(num_cols - 1), fn i ->
      col_def = Enum.at(col_defs, i, %{})
      width = Map.get(col_def, :width)

      %{
        index: i,
        width: width,
        align: Map.get(col_def, :align, :left),
        style: Map.get(col_def, :style, %{})
      }
    end)
    |> distribute_widths(available_width)
  end

  defp resolve_columns_with_total(data, opts) do
    num_cols = data |> List.first([]) |> length()
    col_defs = opts.columns
    total = Enum.reduce(col_defs, 0, fn c, acc -> acc + Map.get(c, :width, 100) end)

    Enum.map(0..(num_cols - 1), fn i ->
      col_def = Enum.at(col_defs, i, %{})

      %{
        index: i,
        width: Map.get(col_def, :width, total / num_cols),
        align: Map.get(col_def, :align, :left),
        style: Map.get(col_def, :style, %{})
      }
    end)
  end

  defp distribute_widths(cols, available_width) do
    {fixed, flexible} = Enum.split_with(cols, fn c -> c.width != nil end)
    fixed_total = Enum.reduce(fixed, 0, fn c, acc -> acc + c.width end)
    remaining = available_width - fixed_total
    flex_count = length(flexible)

    if flex_count > 0 do
      flex_width = remaining / flex_count

      Enum.map(cols, fn c ->
        if c.width == nil, do: %{c | width: flex_width}, else: c
      end)
    else
      cols
    end
  end

  # ── Row preparation (Multilínea & Rich Text inyectado) ─────────────

  defp prepare_rows(data, opts, cols, doc \\ nil) do
    total = length(data)
    has_header = opts.header != nil
    has_footer = opts.footer != nil

    data
    |> Enum.with_index()
    |> Enum.map(fn {cells, idx} ->
      row_type =
        cond do
          has_header and idx == 0 -> :header
          has_footer and idx == total - 1 -> :footer
          true -> :body
        end

      body_idx = if has_header, do: idx - 1, else: idx
      is_alt = rem(body_idx, 2) == 1

      row_style = row_style_for(row_type, is_alt, opts)
      padding = Style.expand_shorthand(Map.get(row_style, :padding, opts.padding))
      {pt, pr, pb, pl} = padding

      font = Map.get(row_style, :font, opts.font)
      font_size = Map.get(row_style, :font_size, opts.font_size)
      bold = Map.get(row_style, :bold, false)
      italic = Map.get(row_style, :italic, false)
      line_h = Map.get(row_style, :line_height, opts.line_height)

      wrapped_cells =
        Enum.map(cols, fn col ->
          cell_data = Enum.at(cells, col.index, "")
          max_w = col.width - pl - pr
          wrap_text(cell_data, max_w, font, font_size, bold, italic, doc)
        end)

      max_lines = Enum.map(wrapped_cells, &length/1) |> Enum.max(fn -> 1 end)

      %{
        cells: cells,
        wrapped_cells: wrapped_cells,
        type: row_type,
        style: row_style,
        height: pt + (line_h * max_lines) + pb,
        padding: padding,
        line_height: line_h
      }
    end)
  end

  # Support for rich text blocks
  defp wrap_text(blocks, max_width, font, font_size, default_bold, default_italic, doc) when is_list(blocks) do
    Enum.flat_map(blocks, fn
      {:bold, text} ->
        wrap_text(to_string(text), max_width, font, font_size, true, default_italic, doc)
        |> Enum.map(&{&1, true, default_italic})

      {:regular, text} ->
        wrap_text(to_string(text), max_width, font, font_size, false, default_italic, doc)
        |> Enum.map(&{&1, false, default_italic})

      text ->
        wrap_text(to_string(text), max_width, font, font_size, default_bold, default_italic, doc)
        |> Enum.map(&{&1, default_bold, default_italic})
    end)
  end

  # Legacy support for standard strings
  defp format_cell_data(data) when is_binary(data), do: data
  defp wrap_text(text, max_width, font, font_size, bold, italic, doc) when is_binary(text) do
    if text == "" do
      [""]
    else
      text
      |> String.split("\n")
      |> Enum.flat_map(fn paragraph ->
        paragraph
        |> String.split(" ")
        |> Enum.reduce([""], fn word, [current_line | rest] ->
          if current_line == "" do
            [word | rest]
          else
            test_line = current_line <> " " <> word
            if estimate_text_width(test_line, font, font_size, bold, italic, doc) <= max_width do
              [test_line | rest]
            else
              [word, current_line | rest]
            end
          end
        end)
        |> Enum.reverse()
      end)
    end
  end

  defp wrap_text(text, max_width, font, font_size, bold, italic, doc) do
    wrap_text(to_string(text), max_width, font, font_size, bold, italic, doc)
  end

  defp row_style_for(:header, _is_alt, opts), do: opts.header || %{}
  defp row_style_for(:footer, _is_alt, opts), do: Map.merge(opts.row, opts.footer || %{})
  defp row_style_for(:body, true, opts) do
    if opts.alt_row, do: Map.merge(opts.row, opts.alt_row), else: opts.row
  end
  defp row_style_for(:body, false, opts), do: opts.row

  # ── Drawing (Document level) ───────────────────────────────────────

  defp draw_clipped_backgrounds(document, rows, cols, {table_x, table_y}, {w, h}, r, opts) do
    document =
      if opts.background do
        document
        |> Pdf.save_state()
        |> Pdf.set_fill_color(opts.background)
        |> draw_shape(document, {table_x, table_y - h}, {w, h}, r)
        |> Pdf.fill()
        |> Pdf.restore_state()
      else
        document
      end

    has_row_bg = Enum.any?(rows, fn row -> Map.get(row.style, :background) != nil end)

    if has_row_bg do
      document =
        document
        |> Pdf.save_state()
        |> draw_shape(document, {table_x, table_y - h}, {w, h}, r)
        |> Pdf.clip()

      {document, _y} =
        Enum.reduce(rows, {document, table_y}, fn row, {doc, y} ->
          row_h = row.height
          row_y = y - row_h

          doc =
            case Map.get(row.style, :background) do
              nil -> doc
              bg ->
                doc
                |> Pdf.save_state()
                |> Pdf.set_fill_color(bg)
                |> Pdf.Document.rectangle({table_x, row_y}, {total_width(cols), row_h})
                |> Pdf.fill()
                |> Pdf.restore_state()
            end

          {doc, y - row_h}
        end)

      Pdf.restore_state(document)
    else
      document
    end
  end

  defp draw_outer_border(document, {x, y}, {w, h}, opts) do
    border = opts.border
    r = opts.border_radius

    if border > 0 do
      document
      |> Pdf.save_state()
      |> Pdf.set_stroke_color(opts.border_color)
      |> Pdf.set_line_width(border)
      |> draw_shape(document, {x, y - h}, {w, h}, r)
      |> Pdf.stroke()
      |> Pdf.restore_state()
    else
      document
    end
  end

  defp draw_shape(doc, _doc_ref, {x, y}, {w, h}, r) when r > 0 do
    Pdf.Document.rounded_rectangle(doc, {x, y}, {w, h}, r)
  end

  defp draw_shape(doc, _doc_ref, {x, y}, {w, h}, _r) do
    Pdf.Document.rectangle(doc, {x, y}, {w, h})
  end

  defp draw_row_content(document, row, cols, {table_x, y}, opts) do
    {pt, _pr, _pb, _pl} = row.padding
    row_h = row.height
    row_y = y - row_h

    border_bottom = Map.get(row.style, :border_bottom, 0)

    document =
      if border_bottom > 0 do
        bc = Map.get(row.style, :border_color, Map.get(opts, :border_color, :black))

        document
        |> Pdf.save_state()
        |> Pdf.set_stroke_color(bc)
        |> Pdf.set_line_width(border_bottom)
        |> Pdf.line({table_x, row_y}, {table_x + total_width(cols), row_y})
        |> Pdf.stroke()
        |> Pdf.restore_state()
      else
        document
      end

    font = Map.get(row.style, :font, opts.font)
    font_size = Map.get(row.style, :font_size, opts.font_size)
    color = Map.get(row.style, :color, opts.color)

    document = Pdf.set_fill_color(document, color)

    {document, _x} =
      Enum.reduce(cols, {document, table_x}, fn col, {doc, cx} ->
        lines = Enum.at(row.wrapped_cells, col.index, [])
        {_pt, pr, _pb, pl} = row.padding
        line_h = row.line_height

        doc =
          lines
          |> Enum.with_index()
          |> Enum.reduce(doc, fn {line_data, line_idx}, doc_acc ->

            {line_str, l_bold, l_italic} =
              case line_data do
                {s, b, i} -> {s, b, i}
                s -> {s, Map.get(row.style, :bold, false), Map.get(row.style, :italic, false)}
              end

            doc_acc = Pdf.set_font(doc_acc, font, font_size, bold: l_bold, italic: l_italic)

            text_x = cell_text_x(cx, pl, pr, col.width, col.align, line_str, font, font_size, l_bold, l_italic, doc_acc)
            text_y = y - pt - font_size - (line_idx * line_h)

            Pdf.text_at(doc_acc, {text_x, text_y}, line_str)
          end)

        {doc, cx + col.width}
      end)

    document
  end

  defp cell_text_x(cx, pl, _pr, _col_w, :left, _text, _font, _fs, _b, _i, _doc), do: cx + pl

  defp cell_text_x(cx, pl, pr, col_w, :center, text, font, font_size, bold, italic, doc) do
    text_w = estimate_text_width(text, font, font_size, bold, italic, doc)
    inner = col_w - pl - pr
    cx + pl + (inner - text_w) / 2
  end

  defp cell_text_x(cx, _pl, pr, col_w, :right, text, font, font_size, bold, italic, doc) do
    text_w = estimate_text_width(text, font, font_size, bold, italic, doc)
    cx + col_w - pr - text_w
  end

  defp estimate_text_width(text, _font, font_size, _bold, _italic, _doc) do
    String.length(text) * font_size * 0.45
  end

  defp total_width(cols), do: Enum.reduce(cols, 0, fn c, acc -> acc + c.width end)

  # ── Drawing (Page level) ───────────────────────────────────────────

  defp draw_shape_page(page, {x, y}, {w, h}, r) when r > 0 do
    Page.rounded_rectangle(page, {x, y}, {w, h}, r)
  end

  defp draw_shape_page(page, {x, y}, {w, h}, _r) do
    Page.rectangle(page, {x, y}, {w, h})
  end

  defp draw_clipped_backgrounds_page(page, rows, cols, {table_x, table_y}, {w, h}, r, opts) do
    page =
      if opts.background do
        page
        |> Page.save_state()
        |> Page.set_fill_color(opts.background)
        |> draw_shape_page({table_x, table_y - h}, {w, h}, r)
        |> Page.fill()
        |> Page.restore_state()
      else
        page
      end

    has_row_bg = Enum.any?(rows, fn row -> Map.get(row.style, :background) != nil end)

    if has_row_bg do
      page =
        page
        |> Page.save_state()
        |> draw_shape_page({table_x, table_y - h}, {w, h}, r)
        |> Page.clip()

      {page, _y} =
        Enum.reduce(rows, {page, table_y}, fn row, {pg, y} ->
          row_h = row.height
          row_y = y - row_h

          pg =
            case Map.get(row.style, :background) do
              nil -> pg
              bg ->
                pg
                |> Page.save_state()
                |> Page.set_fill_color(bg)
                |> Page.rectangle({table_x, row_y}, {total_width(cols), row_h})
                |> Page.fill()
                |> Page.restore_state()
            end

          {pg, y - row_h}
        end)

      Page.restore_state(page)
    else
      page
    end
  end

  defp draw_outer_border_page(page, {x, y}, {w, h}, opts) do
    border = opts.border
    r = opts.border_radius

    if border > 0 do
      page
      |> Page.save_state()
      |> Page.set_stroke_color(opts.border_color)
      |> Page.set_line_width(border)
      |> draw_shape_page({x, y - h}, {w, h}, r)
      |> Page.stroke()
      |> Page.restore_state()
    else
      page
    end
  end

  defp draw_row_content_page(page, row, cols, {table_x, y}, opts) do
    {pt, _pr, _pb, _pl} = row.padding
    row_h = row.height
    row_y = y - row_h

    border_bottom = Map.get(row.style, :border_bottom, 0)

    page =
      if border_bottom > 0 do
        bc = Map.get(row.style, :border_color, Map.get(opts, :border_color, :black))

        page
        |> Page.save_state()
        |> Page.set_stroke_color(bc)
        |> Page.set_line_width(border_bottom)
        |> Page.line({table_x, row_y}, {table_x + total_width(cols), row_y})
        |> Page.stroke()
        |> Page.restore_state()
      else
        page
      end

    font = Map.get(row.style, :font, opts.font)
    font_size = Map.get(row.style, :font_size, opts.font_size)

    {page, _x} =
      Enum.reduce(cols, {page, table_x}, fn col, {pg, cx} ->
        lines = Enum.at(row.wrapped_cells, col.index, [])
        {_pt, _pr, _pb, pl} = row.padding
        line_h = row.line_height
        text_x = cx + pl

        pg =
          lines
          |> Enum.with_index()
          |> Enum.reduce(pg, fn {line_data, line_idx}, pg_acc ->

            {line_str, l_bold, _l_italic} =
              case line_data do
                {s, b, i} -> {s, b, i}
                s -> {s, Map.get(row.style, :bold, false), Map.get(row.style, :italic, false)}
              end

            text_y = y - pt - font_size - (line_idx * line_h)
            Page.text_at(pg_acc, {text_x, text_y}, line_str, font: font, size: font_size)
          end)

        {pg, cx + col.width}
      end)

    page
  end
end
