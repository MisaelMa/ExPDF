# `Pdf.Builder`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.0/lib/pdf/builder.ex#L1)

Declarative PDF builder from template lists.

Renders a list of content tuples into a PDF document, applying
global configuration for page size, margins, fonts, and templates.

## Example

    template = [
      {:text, "Title", %{font_size: 24, bold: true}},
      {:spacer, 10},
      {:text, "Body text", %{font_size: 12}},
      {:line, %{color: :gray}},
      {:page_break},
      {:text, "Page 2", %{font_size: 18}}
    ]

    config = %{
      size: :a4,
      margin: 40,
      font: "Helvetica",
      font_size: 12
    }

    doc = Pdf.Builder.render(template, config)
    binary = Pdf.export(doc)

# `render`

Render a template list with the given config into a PDF document.

## Config keys

- `:size` — page size (default `:a4`)
- `:margin` — margin value or map (default `0`)
- `:font` — default font name (default `"Helvetica"`)
- `:font_size` — default font size (default `12`)
- `:compress` — compress streams (default `true`)
- `:header` — `fn doc, page_info -> doc end` template
- `:footer` — `fn doc, page_info -> doc end` template
- `:watermark` — `fn doc, page_info -> doc end` template
- `:background` — `fn doc, page_info -> doc end` template

# `render_into`

Render a template list into an existing document.
Nested lists are automatically flattened.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
