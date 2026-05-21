# `Pdf.Component.Metric`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.1/lib/pdf/component/metric.ex#L1)

Metric comparison component for PDF documents.

Renders a before/after or current vs previous value with delta indicator.
Useful for reports and dashboards.

## Examples

    doc |> Pdf.Component.Metric.render({50, 700}, %{
      label: "Revenue",
      current: "$12,450",
      previous: "$10,200",
      delta: "+22%",
      delta_direction: :up
    })

# `render`

Render a metric at `{x, y}`.

## Style options

- `:label` — metric name
- `:current` — current/primary value (large)
- `:previous` — previous value (small, muted)
- `:delta` — change string (e.g. "+22%")
- `:delta_direction` — `:up`, `:down`, or `:neutral`
- `:width` — component width (default `200`)
- `:font` — font name
- `:background` — optional background color
- `:border_radius` — corner radius (default `6`)

---

*Consult [api-reference.md](api-reference.md) for complete listing*
