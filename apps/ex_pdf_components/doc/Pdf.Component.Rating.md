# `Pdf.Component.Rating`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.2/lib/pdf/component/rating.ex#L1)

Rating component for PDF documents.

Renders a star/score rating display with filled and empty indicators.

## Examples

    doc |> Pdf.Component.Rating.render({50, 700}, %{value: 4, max: 5})

    doc |> Pdf.Component.Rating.render({50, 700}, %{
      value: 3.5,
      max: 5,
      filled_color: {0.95, 0.7, 0.0},
      size: 16
    })

# `render`

Render a rating at `{x, y}`.

## Style options

- `:value` — current score (default `0`)
- `:max` — maximum score (default `5`)
- `:size` — star size (default `14`)
- `:filled_color` — filled star color (default gold)
- `:empty_color` — empty star color (default light gray)
- `:gap` — space between stars (default `4`)
- `:show_label` — show "3.5/5" text (default `false`)
- `:label_color` — label text color

---

*Consult [api-reference.md](api-reference.md) for complete listing*
