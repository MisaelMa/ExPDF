defmodule Pdf.Component.Chart do
  @moduledoc """
  Chart component for PDF documents — renders bar, line, and pie charts.

  All charts are rendered using PDF drawing primitives (rectangles, lines,
  arcs) with no external dependencies.

  ## Bar chart

      Pdf.Component.Chart.bar_chart(doc, {50, 500}, %{
        width: 300, height: 200,
        data: [
          %{label: "Q1", value: 120, color: {0.2, 0.6, 0.9}},
          %{label: "Q2", value: 180, color: {0.9, 0.4, 0.2}},
          %{label: "Q3", value: 95,  color: {0.3, 0.8, 0.4}},
          %{label: "Q4", value: 210, color: {0.8, 0.2, 0.5}}
        ],
        title: "Quarterly Revenue"
      })

  ## Line chart

      Pdf.Component.Chart.line_chart(doc, {50, 500}, %{
        width: 300, height: 200,
        series: [
          %{label: "Sales",    values: [10, 25, 18, 42, 35], color: {0.2, 0.5, 0.9}},
          %{label: "Expenses", values: [8, 15, 22, 30, 28],  color: {0.9, 0.3, 0.3}}
        ],
        x_labels: ["Jan", "Feb", "Mar", "Apr", "May"],
        title: "Monthly Trend"
      })

  ## Pie chart

      Pdf.Component.Chart.pie_chart(doc, {50, 500}, %{
        radius: 80,
        data: [
          %{label: "Mobile",  value: 45, color: {0.2, 0.6, 0.9}},
          %{label: "Desktop", value: 35, color: {0.9, 0.4, 0.2}},
          %{label: "Tablet",  value: 20, color: {0.3, 0.8, 0.4}}
        ],
        title: "Device Distribution"
      })
  """

  @default_font "Helvetica"
  @default_font_size 8
  @default_title_size 11
  @default_axis_color {0.4, 0.4, 0.4}
  @default_grid_color {0.85, 0.85, 0.85}
  @default_text_color {0.2, 0.2, 0.2}
  @default_colors [
    {0.23, 0.55, 0.83},
    {0.90, 0.38, 0.27},
    {0.30, 0.75, 0.47},
    {0.95, 0.68, 0.20},
    {0.60, 0.35, 0.75},
    {0.15, 0.70, 0.68},
    {0.85, 0.25, 0.50},
    {0.50, 0.50, 0.50}
  ]

  # ════════════════════════════════════════════════════════════════
  # BAR CHART
  # ════════════════════════════════════════════════════════════════

  @doc """
  Render a vertical bar chart.

  `{x, y}` is the top-left corner of the chart area.

  ## Style options

  - `:data` — list of `%{label: str, value: number}` (required)
  - `:width` / `:height` — chart dimensions (default `300` × `200`)
  - `:title` — optional title above chart
  - `:show_values` — display value on top of each bar (default `true`)
  - `:show_grid` — horizontal grid lines (default `true`)
  - `:grid_lines` — number of grid lines (default `5`)
  - `:bar_gap` — fraction of bar width used as gap (default `0.3`)
  - `:bar_radius` — top corner radius (default `0`)
  - `:colors` — list of colors to cycle through
  - `:axis_color` / `:grid_color` / `:text_color`
  """
  def bar_chart(doc, _pos, %{data: []}), do: doc
  def bar_chart(doc, _pos, %{data: nil}), do: doc

  def bar_chart(doc, {x, y}, style) do
    data = Map.get(style, :data, [])
    w = Map.get(style, :width, 300)
    h = Map.get(style, :height, 200)
    title = Map.get(style, :title)
    show_values = Map.get(style, :show_values, true)
    show_grid = Map.get(style, :show_grid, true)
    grid_lines = Map.get(style, :grid_lines, 5)
    bar_gap = Map.get(style, :bar_gap, 0.3)
    colors = Map.get(style, :colors, @default_colors)
    axis_color = Map.get(style, :axis_color, @default_axis_color)
    grid_color = Map.get(style, :grid_color, @default_grid_color)
    text_color = Map.get(style, :text_color, @default_text_color)
    font = Map.get(style, :font, @default_font)
    font_size = Map.get(style, :font_size, @default_font_size)
    title_size = Map.get(style, :title_font_size, @default_title_size)

    # Layout: leave margin for axis labels
    left_margin = 40
    bottom_margin = 20
    top_margin = if title, do: title_size + 8, else: 4

    chart_x = x + left_margin
    chart_y = y - h + bottom_margin
    chart_w = w - left_margin
    chart_h = h - bottom_margin - top_margin

    max_val = data |> Enum.map(& &1.value) |> Enum.max() |> max(1)
    # Round up to nice number
    max_val = nice_max(max_val)
    n = length(data)

    # Title
    doc = if title do
      doc
      |> Pdf.set_font(font, title_size, bold: true)
      |> Pdf.set_fill_color(text_color)
      |> Pdf.text_at({x + w / 2 - String.length(title) * title_size * 0.25, y - title_size}, title)
    else
      doc
    end

    # Grid lines
    doc = if show_grid do
      Enum.reduce(0..grid_lines, doc, fn i, d ->
        gy = chart_y + chart_h * i / grid_lines
        val = round(max_val * i / grid_lines)
        val_str = format_number(val)

        d
        |> Pdf.save_state()
        |> Pdf.set_stroke_color(grid_color)
        |> Pdf.set_line_width(0.5)
        |> Pdf.line({chart_x, gy}, {chart_x + chart_w, gy})
        |> Pdf.stroke()
        |> Pdf.restore_state()
        |> Pdf.set_font(font, font_size - 1)
        |> Pdf.set_fill_color(axis_color)
        |> Pdf.text_at({chart_x - String.length(val_str) * (font_size - 1) * 0.55 - 4, gy - 3}, val_str)
      end)
    else
      doc
    end

    # Axes
    doc =
      doc
      |> Pdf.save_state()
      |> Pdf.set_stroke_color(axis_color)
      |> Pdf.set_line_width(1)
      |> Pdf.line({chart_x, chart_y}, {chart_x, chart_y + chart_h})
      |> Pdf.stroke()
      |> Pdf.line({chart_x, chart_y}, {chart_x + chart_w, chart_y})
      |> Pdf.stroke()
      |> Pdf.restore_state()

    # Bars
    bar_total_w = chart_w / n
    bar_w = bar_total_w * (1 - bar_gap)
    bar_offset = bar_total_w * bar_gap / 2

    doc =
      data
      |> Enum.with_index()
      |> Enum.reduce(doc, fn {item, i}, d ->
        color = Map.get(item, :color, Enum.at(colors, rem(i, length(colors))))
        bar_h = item.value / max_val * chart_h
        bx = chart_x + i * bar_total_w + bar_offset
        by = chart_y

        d =
          d
          |> Pdf.save_state()
          |> Pdf.set_fill_color(color)
          |> Pdf.rectangle({bx, by}, {bar_w, bar_h})
          |> Pdf.fill()
          |> Pdf.restore_state()

        # Value on top
        d = if show_values do
          val_str = format_number(item.value)
          tw = String.length(val_str) * font_size * 0.5
          d
          |> Pdf.set_font(font, font_size)
          |> Pdf.set_fill_color(text_color)
          |> Pdf.text_at({bx + bar_w / 2 - tw / 2, by + bar_h + 3}, val_str)
        else
          d
        end

        # Label below
        label = Map.get(item, :label, "")
        lw = String.length(label) * font_size * 0.5
        d
        |> Pdf.set_font(font, font_size)
        |> Pdf.set_fill_color(text_color)
        |> Pdf.text_at({bx + bar_w / 2 - lw / 2, chart_y - font_size - 2}, label)
      end)

    doc
  end

  # ════════════════════════════════════════════════════════════════
  # LINE CHART
  # ════════════════════════════════════════════════════════════════

  @doc """
  Render a line chart with one or more series.

  `{x, y}` is the top-left corner.

  ## Style options

  - `:series` — list of `%{label: str, values: [number], color: color}` (required)
  - `:x_labels` — labels for the x-axis points
  - `:width` / `:height` — chart dimensions (default `300` × `200`)
  - `:title` — optional title
  - `:show_dots` — render dots at data points (default `true`)
  - `:show_grid` — horizontal grid lines (default `true`)
  - `:grid_lines` — number of grid lines (default `5`)
  - `:dot_radius` — radius of data point dots (default `2.5`)
  - `:line_width` — stroke width for lines (default `1.5`)
  - `:show_legend` — show legend below chart (default `true`)
  """
  def line_chart(doc, _pos, %{series: []}), do: doc
  def line_chart(doc, _pos, %{series: nil}), do: doc

  def line_chart(doc, {x, y}, style) do
    series = Map.get(style, :series, [])
    x_labels = Map.get(style, :x_labels, [])
    w = Map.get(style, :width, 300)
    h = Map.get(style, :height, 200)
    title = Map.get(style, :title)
    show_dots = Map.get(style, :show_dots, true)
    show_grid = Map.get(style, :show_grid, true)
    show_legend = Map.get(style, :show_legend, true)
    grid_lines = Map.get(style, :grid_lines, 5)
    dot_radius = Map.get(style, :dot_radius, 2.5)
    line_w = Map.get(style, :line_width, 1.5)
    colors = Map.get(style, :colors, @default_colors)
    axis_color = Map.get(style, :axis_color, @default_axis_color)
    grid_color = Map.get(style, :grid_color, @default_grid_color)
    text_color = Map.get(style, :text_color, @default_text_color)
    font = Map.get(style, :font, @default_font)
    font_size = Map.get(style, :font_size, @default_font_size)
    title_size = Map.get(style, :title_font_size, @default_title_size)

    left_margin = 40
    bottom_margin = 20
    top_margin = if title, do: title_size + 8, else: 4
    legend_margin = if show_legend, do: 16, else: 0

    chart_x = x + left_margin
    chart_y = y - h + bottom_margin + legend_margin
    chart_w = w - left_margin
    chart_h = h - bottom_margin - top_margin - legend_margin

    all_values = Enum.flat_map(series, & &1.values)
    max_val = all_values |> Enum.max() |> nice_max()
    min_val = min(0, Enum.min(all_values))

    max_points = series |> Enum.map(&length(&1.values)) |> Enum.max(fn -> 0 end)

    # Title
    doc = if title do
      doc
      |> Pdf.set_font(font, title_size, bold: true)
      |> Pdf.set_fill_color(text_color)
      |> Pdf.text_at({x + w / 2 - String.length(title) * title_size * 0.25, y - title_size}, title)
    else
      doc
    end

    # Grid
    doc = if show_grid do
      Enum.reduce(0..grid_lines, doc, fn i, d ->
        gy = chart_y + chart_h * i / grid_lines
        val = round(min_val + (max_val - min_val) * i / grid_lines)
        val_str = format_number(val)

        d
        |> Pdf.save_state()
        |> Pdf.set_stroke_color(grid_color)
        |> Pdf.set_line_width(0.5)
        |> Pdf.line({chart_x, gy}, {chart_x + chart_w, gy})
        |> Pdf.stroke()
        |> Pdf.restore_state()
        |> Pdf.set_font(font, font_size - 1)
        |> Pdf.set_fill_color(axis_color)
        |> Pdf.text_at({chart_x - String.length(val_str) * (font_size - 1) * 0.55 - 4, gy - 3}, val_str)
      end)
    else
      doc
    end

    # Axes
    doc =
      doc
      |> Pdf.save_state()
      |> Pdf.set_stroke_color(axis_color)
      |> Pdf.set_line_width(1)
      |> Pdf.line({chart_x, chart_y}, {chart_x, chart_y + chart_h})
      |> Pdf.stroke()
      |> Pdf.line({chart_x, chart_y}, {chart_x + chart_w, chart_y})
      |> Pdf.stroke()
      |> Pdf.restore_state()

    # X-axis labels
    doc =
      if x_labels != [] do
        x_labels
        |> Enum.with_index()
        |> Enum.reduce(doc, fn {label, i}, d ->
          px = chart_x + i / max(max_points - 1, 1) * chart_w
          lw = String.length(label) * font_size * 0.5
          d
          |> Pdf.set_font(font, font_size)
          |> Pdf.set_fill_color(text_color)
          |> Pdf.text_at({px - lw / 2, chart_y - font_size - 2}, label)
        end)
      else
        doc
      end

    # Draw each series
    range = max_val - min_val

    doc =
      series
      |> Enum.with_index()
      |> Enum.reduce(doc, fn {s, si}, d ->
        color = Map.get(s, :color, Enum.at(colors, rem(si, length(colors))))
        points = s.values
        n = length(points)

        coords =
          points
          |> Enum.with_index()
          |> Enum.map(fn {v, i} ->
            px = chart_x + i / max(n - 1, 1) * chart_w
            py = chart_y + (v - min_val) / max(range, 1) * chart_h
            {px, py}
          end)

        # Draw line segments
        d =
          case coords do
            [first | rest] ->
              d = d
                |> Pdf.save_state()
                |> Pdf.set_stroke_color(color)
                |> Pdf.set_line_width(line_w)
                |> Pdf.move_to(first)

              d = Enum.reduce(rest, d, fn pt, acc -> Pdf.line_append(acc, pt) end)

              d |> Pdf.stroke() |> Pdf.restore_state()

            _ -> d
          end

        # Draw dots
        if show_dots do
          Enum.reduce(coords, d, fn {cx, cy}, acc ->
            draw_filled_circle(acc, cx, cy, dot_radius, color)
          end)
        else
          d
        end
      end)

    # Legend
    doc = if show_legend and length(series) > 1 do
      legend_y = chart_y - bottom_margin - legend_margin + 2
      series
      |> Enum.with_index()
      |> Enum.reduce({doc, chart_x}, fn {s, si}, {d, lx} ->
        color = Map.get(s, :color, Enum.at(colors, rem(si, length(colors))))
        label = Map.get(s, :label, "Series #{si + 1}")

        d =
          d
          |> Pdf.save_state()
          |> Pdf.set_fill_color(color)
          |> Pdf.rectangle({lx, legend_y}, {10, 8})
          |> Pdf.fill()
          |> Pdf.restore_state()
          |> Pdf.set_font(font, font_size)
          |> Pdf.set_fill_color(text_color)
          |> Pdf.text_at({lx + 13, legend_y}, label)

        {d, lx + 13 + String.length(label) * font_size * 0.55 + 15}
      end)
      |> elem(0)
    else
      doc
    end

    doc
  end

  # ════════════════════════════════════════════════════════════════
  # PIE CHART
  # ════════════════════════════════════════════════════════════════

  @doc """
  Render a pie chart.

  `{x, y}` is the center of the pie.

  ## Style options

  - `:data` — list of `%{label: str, value: number}` (required)
  - `:radius` — pie radius (default `80`)
  - `:title` — optional title above
  - `:donut` — inner radius fraction for donut chart (default `0`, set to `0.5` for donut)
  - `:show_labels` — draw labels with lines (default `true`)
  - `:show_percentages` — show % in labels (default `true`)
  - `:colors` — color cycle
  """
  def pie_chart(doc, _pos, %{data: []}), do: doc
  def pie_chart(doc, _pos, %{data: nil}), do: doc

  def pie_chart(doc, {cx, cy}, style) do
    data = Map.get(style, :data, [])
    radius = Map.get(style, :radius, 80)
    title = Map.get(style, :title)
    donut = Map.get(style, :donut, 0)
    show_labels = Map.get(style, :show_labels, true)
    show_pct = Map.get(style, :show_percentages, true)
    colors = Map.get(style, :colors, @default_colors)
    text_color = Map.get(style, :text_color, @default_text_color)
    font = Map.get(style, :font, @default_font)
    font_size = Map.get(style, :font_size, @default_font_size)
    title_size = Map.get(style, :title_font_size, @default_title_size)

    total = Enum.reduce(data, 0, fn item, acc -> acc + item.value end)
    total = max(total, 1)

    # Title
    doc = if title do
      doc
      |> Pdf.set_font(font, title_size, bold: true)
      |> Pdf.set_fill_color(text_color)
      |> Pdf.text_at({cx - String.length(title) * title_size * 0.25, cy + radius + title_size + 4}, title)
    else
      doc
    end

    inner_r = radius * donut
    segments = 36

    # Draw slices
    {doc, _} =
      data
      |> Enum.with_index()
      |> Enum.reduce({doc, -:math.pi() / 2}, fn {item, i}, {d, start_angle} ->
        fraction = item.value / total
        sweep = fraction * 2 * :math.pi()
        end_angle = start_angle + sweep
        color = Map.get(item, :color, Enum.at(colors, rem(i, length(colors))))

        # Draw slice as filled polygon (pie wedge approximation)
        steps = max(round(segments * fraction), 2)

        outer_points =
          for s <- 0..steps do
            a = start_angle + sweep * s / steps
            {cx + radius * :math.cos(a), cy + radius * :math.sin(a)}
          end

        points = if donut > 0 do
          inner_points =
            for s <- steps..0//-1 do
              a = start_angle + sweep * s / steps
              {cx + inner_r * :math.cos(a), cy + inner_r * :math.sin(a)}
            end
          outer_points ++ inner_points
        else
          [{cx, cy} | outer_points]
        end

        d = draw_filled_polygon(d, points, color)

        # Slice outline
        d =
          d
          |> Pdf.save_state()
          |> Pdf.set_stroke_color({1, 1, 1})
          |> Pdf.set_line_width(1.5)

        d = case points do
          [first | rest] ->
            d = Pdf.move_to(d, first)
            d = Enum.reduce(rest, d, fn pt, acc -> Pdf.line_append(acc, pt) end)
            d |> Pdf.close_path() |> Pdf.stroke()
          _ -> d
        end

        d = Pdf.restore_state(d)

        # Label with leader line
        d = if show_labels do
          mid_angle = start_angle + sweep / 2
          label_r = radius + 15
          lx = cx + label_r * :math.cos(mid_angle)
          ly = cy + label_r * :math.sin(mid_angle)

          tip_x = cx + (radius + 4) * :math.cos(mid_angle)
          tip_y = cy + (radius + 4) * :math.sin(mid_angle)

          label = Map.get(item, :label, "")
          pct_str = if show_pct do
            " (#{round(fraction * 100)}%)"
          else
            ""
          end
          full_label = label <> pct_str

          # Leader line
          d =
            d
            |> Pdf.save_state()
            |> Pdf.set_stroke_color(text_color)
            |> Pdf.set_line_width(0.5)
            |> Pdf.line({tip_x, tip_y}, {lx, ly})
            |> Pdf.stroke()
            |> Pdf.restore_state()

          # Text
          text_x = if :math.cos(mid_angle) >= 0, do: lx + 3, else: lx - String.length(full_label) * font_size * 0.5 - 3

          d
          |> Pdf.set_font(font, font_size)
          |> Pdf.set_fill_color(text_color)
          |> Pdf.text_at({text_x, ly - 3}, full_label)
        else
          d
        end

        {d, end_angle}
      end)

    doc
  end

  # ════════════════════════════════════════════════════════════════
  # HORIZONTAL BAR CHART
  # ════════════════════════════════════════════════════════════════

  @doc """
  Render a horizontal bar chart — useful for ranking or comparison data.

  `{x, y}` is the top-left corner.

  ## Style options

  Same as `bar_chart/3` but bars grow left-to-right.
  """
  def horizontal_bar_chart(doc, _pos, %{data: []}), do: doc
  def horizontal_bar_chart(doc, _pos, %{data: nil}), do: doc

  def horizontal_bar_chart(doc, {x, y}, style) do
    data = Map.get(style, :data, [])
    w = Map.get(style, :width, 300)
    h = Map.get(style, :height, 200)
    title = Map.get(style, :title)
    show_values = Map.get(style, :show_values, true)
    colors = Map.get(style, :colors, @default_colors)
    text_color = Map.get(style, :text_color, @default_text_color)
    font = Map.get(style, :font, @default_font)
    font_size = Map.get(style, :font_size, @default_font_size)
    title_size = Map.get(style, :title_font_size, @default_title_size)
    bar_gap = Map.get(style, :bar_gap, 0.25)

    left_margin = 80
    top_margin = if title, do: title_size + 8, else: 4

    chart_x = x + left_margin
    chart_y = y - h
    chart_w = w - left_margin - 40
    chart_h = h - top_margin

    max_val = data |> Enum.map(& &1.value) |> Enum.max() |> nice_max()
    n = length(data)

    # Title
    doc = if title do
      doc
      |> Pdf.set_font(font, title_size, bold: true)
      |> Pdf.set_fill_color(text_color)
      |> Pdf.text_at({x + w / 2 - String.length(title) * title_size * 0.25, y - title_size}, title)
    else
      doc
    end

    bar_total_h = chart_h / n
    bar_h = bar_total_h * (1 - bar_gap)
    bar_offset = bar_total_h * bar_gap / 2

    doc =
      data
      |> Enum.with_index()
      |> Enum.reduce(doc, fn {item, i}, d ->
        color = Map.get(item, :color, Enum.at(colors, rem(i, length(colors))))
        bar_w = item.value / max_val * chart_w
        by = chart_y + chart_h - (i + 1) * bar_total_h + bar_offset

        # Bar
        d =
          d
          |> Pdf.save_state()
          |> Pdf.set_fill_color(color)
          |> Pdf.rectangle({chart_x, by}, {bar_w, bar_h})
          |> Pdf.fill()
          |> Pdf.restore_state()

        # Label on left
        label = Map.get(item, :label, "")
        d =
          d
          |> Pdf.set_font(font, font_size)
          |> Pdf.set_fill_color(text_color)
          |> Pdf.text_at({x + 2, by + bar_h / 2 - 3}, label)

        # Value on right of bar
        if show_values do
          val_str = format_number(item.value)
          d
          |> Pdf.set_font(font, font_size)
          |> Pdf.set_fill_color(text_color)
          |> Pdf.text_at({chart_x + bar_w + 4, by + bar_h / 2 - 3}, val_str)
        else
          d
        end
      end)

    doc
  end

  # ════════════════════════════════════════════════════════════════
  # PRIVATE HELPERS
  # ════════════════════════════════════════════════════════════════

  @kappa 0.5522847498

  defp draw_filled_circle(doc, cx, cy, r, color) do
    k = r * @kappa

    doc
    |> Pdf.save_state()
    |> Pdf.set_fill_color(color)
    |> Pdf.move_to({cx + r, cy})
    |> Pdf.curve_to({cx + r, cy + k}, {cx + k, cy + r}, {cx, cy + r})
    |> Pdf.curve_to({cx - k, cy + r}, {cx - r, cy + k}, {cx - r, cy})
    |> Pdf.curve_to({cx - r, cy - k}, {cx - k, cy - r}, {cx, cy - r})
    |> Pdf.curve_to({cx + k, cy - r}, {cx + r, cy - k}, {cx + r, cy})
    |> Pdf.close_path()
    |> Pdf.fill()
    |> Pdf.restore_state()
  end

  defp draw_filled_polygon(doc, points, color) do
    case points do
      [first | rest] ->
        doc =
          doc
          |> Pdf.save_state()
          |> Pdf.set_fill_color(color)
          |> Pdf.move_to(first)

        doc = Enum.reduce(rest, doc, fn pt, d -> Pdf.line_append(d, pt) end)

        doc
        |> Pdf.close_path()
        |> Pdf.fill()
        |> Pdf.restore_state()

      _ ->
        doc
    end
  end

  defp nice_max(val) when val <= 0, do: 10
  defp nice_max(val) do
    magnitude = :math.pow(10, floor(:math.log10(val)))
    normalized = val / magnitude

    nice = cond do
      normalized <= 1.0 -> 1.0
      normalized <= 1.5 -> 1.5
      normalized <= 2.0 -> 2.0
      normalized <= 3.0 -> 3.0
      normalized <= 5.0 -> 5.0
      normalized <= 7.5 -> 7.5
      true -> 10.0
    end

    round(nice * magnitude)
  end

  defp format_number(n) when is_float(n), do: :erlang.float_to_binary(n, decimals: 1)
  defp format_number(n) when is_integer(n) and n >= 1_000_000 do
    "#{Float.round(n / 1_000_000, 1)}M"
  end
  defp format_number(n) when is_integer(n) and n >= 10_000 do
    "#{Float.round(n / 1_000, 1)}K"
  end
  defp format_number(n), do: "#{n}"
end
