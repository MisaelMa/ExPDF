defmodule Pdf.DevServer.Examples.Component.MetricDemo do
  @moduledoc false

  def render do
    dark = {0.1, 0.1, 0.1}
    accent = {0.0, 0.45, 0.75}
    gray = {0.45, 0.45, 0.45}

    doc =
      Pdf.new(size: :a4, margin: 40)
      |> Pdf.set_font("Helvetica", 24)
      |> Pdf.set_fill_color(dark)
      |> Pdf.text_at({40, 780}, "Metric Component", %{bold: true})
      |> Pdf.set_font("Helvetica", 10)
      |> Pdf.set_fill_color(gray)
      |> Pdf.text_at({40, 764}, "Before/after comparisons with delta indicators")

    # ── Row of metrics ──
    doc =
      doc
      |> Pdf.set_font("Helvetica", 12)
      |> Pdf.set_fill_color(accent)
      |> Pdf.text_at({40, 730}, "Dashboard Metrics", %{bold: true})
      |> Pdf.Component.Metric.render({40, 710}, %{
        label: "REVENUE",
        current: "$12,450",
        previous: "$10,200",
        delta: "+22%",
        delta_direction: :up,
        background: {0.97, 0.99, 0.97},
        width: 160
      })
      |> Pdf.Component.Metric.render({210, 710}, %{
        label: "USERS",
        current: "1,284",
        previous: "1,150",
        delta: "+134",
        delta_direction: :up,
        background: {0.97, 0.97, 1.0},
        width: 160
      })
      |> Pdf.Component.Metric.render({380, 710}, %{
        label: "CHURN",
        current: "3.2%",
        previous: "2.8%",
        delta: "+0.4%",
        delta_direction: :down,
        background: {1.0, 0.97, 0.97},
        width: 160
      })

    # ── Neutral delta ──
    doc =
      doc
      |> Pdf.set_font("Helvetica", 12)
      |> Pdf.set_fill_color(accent)
      |> Pdf.text_at({40, 620}, "Neutral / No Change", %{bold: true})
      |> Pdf.Component.Metric.render({40, 600}, %{
        label: "CONVERSION RATE",
        current: "4.5%",
        previous: "4.5%",
        delta: "0%",
        delta_direction: :neutral,
        background: {0.97, 0.97, 0.97},
        width: 200
      })

    # ── Without previous ──
    doc
    |> Pdf.set_font("Helvetica", 12)
    |> Pdf.set_fill_color(accent)
    |> Pdf.text_at({40, 510}, "Simple (no comparison)", %{bold: true})
    |> Pdf.Component.Metric.render({40, 490}, %{
      label: "TOTAL ORDERS",
      current: "8,921",
      width: 180,
      background: {0.96, 0.96, 0.96}
    })
    |> Pdf.Component.Metric.render({240, 490}, %{
      label: "AVG ORDER VALUE",
      current: "$87.30",
      width: 180,
      background: {0.96, 0.96, 0.96}
    })
  end
end
