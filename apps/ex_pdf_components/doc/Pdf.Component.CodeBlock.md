# `Pdf.Component.CodeBlock`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.1/lib/pdf/component/code_block.ex#L1)

Code block component for PDF documents.

Renders monospaced text with a background box, optional line numbers,
and syntax-like styling. Designed for code snippets and terminal output.

## Examples

    doc |> Pdf.Component.CodeBlock.render({50, 700}, %{width: 400},
      "defmodule Hello do\n  def world, do: :ok\nend")

    doc |> Pdf.Component.CodeBlock.render({50, 700}, %{
      width: 400,
      line_numbers: true,
      background: {0.15, 0.15, 0.18}
      color: {0.9, 0.9, 0.9}
    }, code)

# `render`

Render a code block at `{x, y}`.

## Style options

- `:width` — block width (required)
- `:font` — monospaced font (default `"Courier"`)
- `:font_size` — text size (default `9`)
- `:color` — text color (default dark)
- `:background` — background color (default light gray)
- `:border_color` — border color (default gray)
- `:border_radius` — corner radius (default `4`)
- `:padding` — inner padding (default `10`)
- `:line_height` — spacing between lines (default `13`)
- `:line_numbers` — show line numbers (default `false`)
- `:line_number_color` — line number color (default muted)
- `:title` — optional title/filename above the block

---

*Consult [api-reference.md](api-reference.md) for complete listing*
