# `Pdf.Component.Signature`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.1/lib/pdf/component/signature.ex#L1)

Signature component for PDF documents.

Renders a signature line with name, title/role, and optional date.
Useful for contracts, letters, and formal documents.

## Examples

    doc |> Pdf.Component.Signature.render({50, 200}, %{
      name: "John Doe",
      title: "CEO, Acme Corp"
    })

    doc |> Pdf.Component.Signature.render({50, 200}, %{
      name: "Jane Smith",
      title: "Chief Architect",
      date: "May 19, 2026",
      width: 250
    })

# `render`

Render a signature block at `{x, y}`.

## Style options

- `:name` — signer name (required)
- `:title` — role/title below name
- `:date` — optional date string
- `:width` — line width (default `200`)
- `:font` — font name (default `"Helvetica"`)
- `:line_color` — signature line color
- `:name_color` — name text color
- `:title_color` — title/date text color
- `:label` — label above line (e.g. "Authorized by")

---

*Consult [api-reference.md](api-reference.md) for complete listing*
