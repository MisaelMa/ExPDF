# `Pdf.Component.StatCard`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.0/lib/pdf/component/stat_card.ex#L1)

Stat card component for PDF documents.

Renders a dashboard-style KPI card with a large number/value,
a label, and optional trend indicator. Useful for reports and dashboards.

## Examples

    doc |> Pdf.Component.StatCard.render({50, 700}, %{
      value: "$12,450",
      label: "Monthly Revenue",
      width: 150
    })

    doc |> Pdf.Component.StatCard.render({50, 700}, %{
      value: "98.5%",
      label: "Uptime",
      trend: "+2.1%",
      trend_color: {0.2, 0.7, 0.3},
      accent_color: {0.2, 0.5, 0.9}
    })

# `render`

Render a stat card at `{x, y}` (top-left).

## Style options

- `:value` — the main number/text (required)
- `:label` — description below the value
- `:trend` — optional trend string (e.g. "+5.2%")
- `:trend_color` — color for the trend text
- `:width` — card width (default `150`)
- `:height` — card height (default `90`)
- `:background` — card background (default white)
- `:accent_color` — top accent bar color (default blue)
- `:value_color` — value text color
- `:label_color` — label text color
- `:border_radius` — corner radius (default `6`)
- `:border` — border width (default `0.5`)
- `:border_color` — border color

---

*Consult [api-reference.md](api-reference.md) for complete listing*
