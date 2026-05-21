# `Pdf.Component.Chart`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.1/lib/pdf/component/chart.ex#L1)

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

# `bar_chart`

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

# `horizontal_bar_chart`

Render a horizontal bar chart — useful for ranking or comparison data.

`{x, y}` is the top-left corner.

## Style options

Same as `bar_chart/3` but bars grow left-to-right.

# `line_chart`

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

# `pie_chart`

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

---

*Consult [api-reference.md](api-reference.md) for complete listing*
