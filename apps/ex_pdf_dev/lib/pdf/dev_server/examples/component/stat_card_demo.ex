defmodule Pdf.DevServer.Examples.Component.StatCardDemo do
  @moduledoc false

  def render do
    dark = {0.1, 0.1, 0.1}
    accent = {0.0, 0.45, 0.75}
    gray = {0.45, 0.45, 0.45}

    doc =
      Pdf.new(size: :a4, margin: 40)
      |> Pdf.set_font("Helvetica", 24)
      |> Pdf.set_fill_color(dark)
      |> Pdf.text_at({40, 780}, "StatCard Component", %{bold: true})
      |> Pdf.set_font("Helvetica", 10)
      |> Pdf.set_fill_color(gray)
      |> Pdf.text_at({40, 764}, "Dashboard KPI cards with value, label, and trend indicator")

    # ── Row of 3 stat cards ──
    doc =
      doc
      |> Pdf.set_font("Helvetica", 12)
      |> Pdf.set_fill_color(accent)
      |> Pdf.text_at({40, 730}, "Dashboard Row", %{bold: true})
      |> Pdf.Component.StatCard.render({40, 710}, %{
        value: "$12,450",
        label: "Monthly Revenue",
        trend: "+8.2%",
        trend_color: {0.2, 0.7, 0.3},
        accent_color: {0.2, 0.5, 0.9},
        width: 155
      })
      |> Pdf.Component.StatCard.render({210, 710}, %{
        value: "1,284",
        label: "Active Users",
        trend: "+12%",
        trend_color: {0.2, 0.7, 0.3},
        accent_color: {0.3, 0.7, 0.4},
        width: 155
      })
      |> Pdf.Component.StatCard.render({380, 710}, %{
        value: "98.5%",
        label: "Uptime",
        trend: "-0.1%",
        trend_color: {0.8, 0.2, 0.2},
        accent_color: {0.7, 0.3, 0.7},
        width: 155
      })

    # ── Different accent colors ──
    doc =
      doc
      |> Pdf.set_font("Helvetica", 12)
      |> Pdf.set_fill_color(accent)
      |> Pdf.text_at({40, 600}, "Color Variants", %{bold: true})
      |> Pdf.Component.StatCard.render({40, 580}, %{
        value: "342",
        label: "Open Issues",
        accent_color: {0.85, 0.35, 0.15},
        width: 155
      })
      |> Pdf.Component.StatCard.render({210, 580}, %{
        value: "87/100",
        label: "Test Coverage",
        accent_color: {0.1, 0.6, 0.5},
        width: 155
      })
      |> Pdf.Component.StatCard.render({380, 580}, %{
        value: "4.8s",
        label: "Avg Response",
        accent_color: {0.5, 0.3, 0.8},
        width: 155
      })

    # ── Large single card ──
    doc
    |> Pdf.set_font("Helvetica", 12)
    |> Pdf.set_fill_color(accent)
    |> Pdf.text_at({40, 470}, "Large Card", %{bold: true})
    |> Pdf.Component.StatCard.render({40, 450}, %{
      value: "$1,234,567",
      label: "Total Revenue (YTD)",
      trend: "+23.4% vs last year",
      trend_color: {0.2, 0.7, 0.3},
      accent_color: {0.15, 0.4, 0.75},
      width: 300,
      height: 100
    })
  end
end
