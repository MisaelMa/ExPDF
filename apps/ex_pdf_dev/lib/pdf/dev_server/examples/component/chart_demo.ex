defmodule Pdf.DevServer.Examples.Component.ChartDemo do
  @moduledoc false

  def render do
    dark = {0.1, 0.1, 0.1}
    gray = {0.5, 0.5, 0.5}
    blue = {0.23, 0.55, 0.83}
    red = {0.90, 0.38, 0.27}
    green = {0.30, 0.75, 0.47}
    orange = {0.95, 0.68, 0.20}
    purple = {0.60, 0.35, 0.75}
    teal = {0.15, 0.70, 0.68}

    Pdf.new(size: :a4, margin: %{top: 40, bottom: 40, left: 50, right: 50})
    |> Pdf.set_info(title: "Chart Component Demo")

    # Apply header + footer
    |> Pdf.Component.PageHeader.apply(%{
      title: "Chart Component Demo",
      right: :date,
      color: dark
    })
    |> Pdf.Component.Paginator.apply(%{
      format: :center,
      font_size: 8,
      color: gray,
      prefix: "Page "
    })

    # ══════════════════════════════════════════════════════════════
    # PAGE 1 — Bar Charts
    # ══════════════════════════════════════════════════════════════
    |> Pdf.set_font("Helvetica", 16, bold: true)
    |> Pdf.set_fill_color(dark)
    |> Pdf.text_at({50, 740}, "Bar Charts")
    |> Pdf.set_font("Helvetica", 9)
    |> Pdf.set_fill_color(gray)
    |> Pdf.text_at({50, 724}, "Vertical bar charts with auto-scaling, grid lines, and value labels")

    # Bar chart — Quarterly revenue
    |> Pdf.Component.Chart.bar_chart({50, 700}, %{
      width: 240, height: 180,
      title: "Quarterly Revenue ($K)",
      data: [
        %{label: "Q1", value: 120, color: blue},
        %{label: "Q2", value: 185, color: teal},
        %{label: "Q3", value: 95,  color: orange},
        %{label: "Q4", value: 220, color: green}
      ]
    })

    # Bar chart — Monthly users
    |> Pdf.Component.Chart.bar_chart({310, 700}, %{
      width: 240, height: 180,
      title: "Active Users",
      data: [
        %{label: "Jan", value: 3200, color: purple},
        %{label: "Feb", value: 4100, color: purple},
        %{label: "Mar", value: 3800, color: purple},
        %{label: "Apr", value: 5200, color: purple},
        %{label: "May", value: 4800, color: purple},
        %{label: "Jun", value: 6100, color: purple}
      ],
      bar_gap: 0.2
    })

    # Horizontal bar chart
    |> Pdf.set_font("Helvetica", 16, bold: true)
    |> Pdf.set_fill_color(dark)
    |> Pdf.text_at({50, 490}, "Horizontal Bar Chart")

    |> Pdf.Component.Chart.horizontal_bar_chart({50, 475}, %{
      width: 300, height: 180,
      title: "Top Languages",
      data: [
        %{label: "Elixir",     value: 92, color: purple},
        %{label: "TypeScript", value: 78, color: blue},
        %{label: "Rust",       value: 65, color: orange},
        %{label: "Go",         value: 58, color: teal},
        %{label: "Python",     value: 45, color: green}
      ]
    })

    # ══════════════════════════════════════════════════════════════
    # PAGE 2 — Line Charts
    # ══════════════════════════════════════════════════════════════
    |> Pdf.add_page(:a4)
    |> Pdf.set_font("Helvetica", 16, bold: true)
    |> Pdf.set_fill_color(dark)
    |> Pdf.text_at({50, 740}, "Line Charts")
    |> Pdf.set_font("Helvetica", 9)
    |> Pdf.set_fill_color(gray)
    |> Pdf.text_at({50, 724}, "Multi-series line charts with dots, grid, and legend")

    # Single series
    |> Pdf.Component.Chart.line_chart({50, 700}, %{
      width: 240, height: 180,
      title: "Monthly Sales",
      series: [
        %{label: "Sales", values: [12, 25, 18, 42, 35, 50, 38], color: blue}
      ],
      x_labels: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul"]
    })

    # Multi-series
    |> Pdf.Component.Chart.line_chart({310, 700}, %{
      width: 240, height: 180,
      title: "Revenue vs Expenses",
      series: [
        %{label: "Revenue",  values: [30, 45, 38, 52, 48, 65], color: green},
        %{label: "Expenses", values: [20, 28, 35, 30, 32, 40], color: red}
      ],
      x_labels: ["Jan", "Feb", "Mar", "Apr", "May", "Jun"]
    })

    # Larger line chart
    |> Pdf.Component.Chart.line_chart({50, 480}, %{
      width: 500, height: 200,
      title: "Website Traffic (thousands)",
      series: [
        %{label: "Visits",    values: [15, 22, 28, 25, 35, 42, 38, 50, 48, 55, 62, 58], color: blue},
        %{label: "Unique",    values: [10, 15, 20, 18, 25, 30, 28, 35, 32, 40, 45, 42], color: teal},
        %{label: "Bounced",   values: [5, 8, 10, 9, 12, 14, 12, 16, 15, 18, 20, 18],    color: orange}
      ],
      x_labels: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"],
      line_width: 2
    })

    # ══════════════════════════════════════════════════════════════
    # PAGE 3 — Pie Charts
    # ══════════════════════════════════════════════════════════════
    |> Pdf.add_page(:a4)
    |> Pdf.set_font("Helvetica", 16, bold: true)
    |> Pdf.set_fill_color(dark)
    |> Pdf.text_at({50, 740}, "Pie & Donut Charts")
    |> Pdf.set_font("Helvetica", 9)
    |> Pdf.set_fill_color(gray)
    |> Pdf.text_at({50, 724}, "Pie charts with labels, percentages, and donut variant")

    # Standard pie
    |> Pdf.Component.Chart.pie_chart({150, 610}, %{
      radius: 75,
      title: "Device Distribution",
      data: [
        %{label: "Mobile",  value: 52, color: blue},
        %{label: "Desktop", value: 35, color: green},
        %{label: "Tablet",  value: 13, color: orange}
      ]
    })

    # Donut chart
    |> Pdf.Component.Chart.pie_chart({400, 610}, %{
      radius: 75,
      title: "Market Share",
      donut: 0.5,
      data: [
        %{label: "Chrome",  value: 65, color: blue},
        %{label: "Safari",  value: 19, color: teal},
        %{label: "Firefox", value: 8,  color: orange},
        %{label: "Edge",    value: 5,  color: green},
        %{label: "Other",   value: 3,  color: gray}
      ]
    })

    # More segments
    |> Pdf.Component.Chart.pie_chart({150, 380}, %{
      radius: 70,
      title: "Budget Allocation",
      data: [
        %{label: "Engineering", value: 35, color: blue},
        %{label: "Marketing",   value: 22, color: red},
        %{label: "Sales",       value: 18, color: green},
        %{label: "Operations",  value: 15, color: orange},
        %{label: "HR",          value: 10, color: purple}
      ]
    })

    # Donut with fewer segments
    |> Pdf.Component.Chart.pie_chart({400, 380}, %{
      radius: 70,
      title: "Satisfaction Score",
      donut: 0.55,
      data: [
        %{label: "Very Happy", value: 60, color: green},
        %{label: "Happy",      value: 25, color: teal},
        %{label: "Neutral",    value: 10, color: orange},
        %{label: "Unhappy",    value: 5,  color: red}
      ]
    })

  end
end
