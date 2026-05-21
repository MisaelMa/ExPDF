defmodule Pdf.DevServer.Examples.Component.BlockquoteDemo do
  @moduledoc false

  def render do
    dark = {0.1, 0.1, 0.1}
    accent = {0.0, 0.45, 0.75}
    gray = {0.45, 0.45, 0.45}

    doc =
      Pdf.new(size: :a4, margin: 40)
      |> Pdf.set_font("Helvetica", 24)
      |> Pdf.set_fill_color(dark)
      |> Pdf.text_at({40, 780}, "Blockquote Component", %{bold: true})
      |> Pdf.set_font("Helvetica", 10)
      |> Pdf.set_fill_color(gray)
      |> Pdf.text_at({40, 764}, "Indented text with colored left bar and optional citation")

    # ── Simple blockquote ──
    doc =
      doc
      |> Pdf.set_font("Helvetica", 12)
      |> Pdf.set_fill_color(accent)
      |> Pdf.text_at({40, 730}, "Simple Quote", %{bold: true})
      |> Pdf.Component.Blockquote.render({50, 710}, %{width: 450},
        "The best way to predict the future is to invent it.")

    # ── With citation ──
    doc =
      doc
      |> Pdf.set_font("Helvetica", 12)
      |> Pdf.set_fill_color(accent)
      |> Pdf.text_at({40, 640}, "With Citation", %{bold: true})
      |> Pdf.Component.Blockquote.render({50, 620}, %{
        width: 450,
        bar_color: {0.2, 0.5, 0.8},
        cite: "— Alan Kay, 1971"
      }, "The best way to predict the future is to invent it. Technology alone is not enough — it is technology married with liberal arts, married with the humanities, that yields us the results that make our heart sing.")

    # ── With background ──
    doc =
      doc
      |> Pdf.set_font("Helvetica", 12)
      |> Pdf.set_fill_color(accent)
      |> Pdf.text_at({40, 490}, "With Background", %{bold: true})
      |> Pdf.Component.Blockquote.render({50, 470}, %{
        width: 450,
        bar_color: {0.8, 0.2, 0.2},
        background: {1.0, 0.96, 0.96},
        cite: "— Important Notice"
      }, "Please review all documents carefully before signing. Changes cannot be made after submission. Contact support if you have any questions.")

    # ── Non-italic style ──
    doc
    |> Pdf.set_font("Helvetica", 12)
    |> Pdf.set_fill_color(accent)
    |> Pdf.text_at({40, 350}, "Non-Italic (Technical)", %{bold: true})
    |> Pdf.Component.Blockquote.render({50, 330}, %{
      width: 450,
      bar_color: {0.4, 0.7, 0.3},
      background: {0.95, 0.98, 0.95},
      italic: false,
      font_size: 9
    }, "Note: When deploying to production, ensure all environment variables are set correctly. The application will fail to start without DATABASE_URL and SECRET_KEY_BASE configured.")
  end
end
