defmodule Pdf.Component.Signature do
  @moduledoc """
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
  """

  @default_width 200
  @default_line_color {0.3, 0.3, 0.3}
  @default_name_color {0.1, 0.1, 0.1}
  @default_title_color {0.45, 0.45, 0.45}
  @default_font "Helvetica"

  @doc """
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
  """
  def render(doc, {x, y}, style \\ %{}) do
    name = Map.get(style, :name, "")
    title = Map.get(style, :title)
    date = Map.get(style, :date)
    label = Map.get(style, :label)
    width = Map.get(style, :width, @default_width)
    font = Map.get(style, :font, @default_font)
    line_color = Map.get(style, :line_color, @default_line_color)
    name_color = Map.get(style, :name_color, @default_name_color)
    title_color = Map.get(style, :title_color, @default_title_color)

    # Optional label above the line
    {doc, line_y} =
      if label do
        doc =
          doc
          |> Pdf.set_font(font, 8)
          |> Pdf.set_fill_color(title_color)
          |> Pdf.text_at({x, y}, label)

        {doc, y - 16}
      else
        {doc, y}
      end

    # Signature line
    doc =
      doc
      |> Pdf.save_state()
      |> Pdf.set_stroke_color(line_color)
      |> Pdf.set_line_width(0.8)
      |> Pdf.line({x, line_y}, {x + width, line_y})
      |> Pdf.stroke()
      |> Pdf.restore_state()

    # Name
    doc =
      doc
      |> Pdf.set_font(font, 10, bold: true)
      |> Pdf.set_fill_color(name_color)
      |> Pdf.text_at({x, line_y - 14}, name)

    # Title
    doc =
      if title do
        doc
        |> Pdf.set_font(font, 9)
        |> Pdf.set_fill_color(title_color)
        |> Pdf.text_at({x, line_y - 26}, title)
      else
        doc
      end

    # Date (right-aligned)
    if date do
      date_w = String.length(date) * 9 * 0.52
      doc
      |> Pdf.set_font(font, 9)
      |> Pdf.set_fill_color(title_color)
      |> Pdf.text_at({x + width - date_w, line_y - 14}, date)
    else
      doc
    end
  end
end
