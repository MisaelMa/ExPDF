# `Pdf.Component.Alert`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.0/lib/pdf/component/alert.ex#L1)

Alert/Callout component for PDF documents.

Renders a colored notification box with an icon character, title,
and message text. Supports info, warning, error, and success variants.

## Examples

    doc |> Pdf.Component.Alert.render({50, 700}, %{
      type: :info,
      title: "Note",
      message: "This is an informational message.",
      width: 400
    })

    doc |> Pdf.Component.Alert.render({50, 700}, %{
      type: :error,
      title: "Error",
      message: "Something went wrong. Please try again.",
      width: 400
    })

# `render`

Render an alert at `{x, y}`.

## Style options

- `:type` — `:info` (default), `:success`, `:warning`, or `:error`
- `:title` — bold title text
- `:message` — body message text (required)
- `:width` — alert width (required)
- `:font` — font name (default `"Helvetica"`)
- `:padding` — inner padding (default `12`)
- `:border_radius` — corner radius (default `5`)
- `:icon` — override icon character

---

*Consult [api-reference.md](api-reference.md) for complete listing*
