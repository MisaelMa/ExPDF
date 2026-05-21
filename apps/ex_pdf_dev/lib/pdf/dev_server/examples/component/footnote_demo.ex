defmodule Pdf.DevServer.Examples.Component.FootnoteDemo do
  @moduledoc false

  def render do
    dark = {0.1, 0.1, 0.1}
    accent = {0.0, 0.45, 0.75}
    gray = {0.45, 0.45, 0.45}

    doc =
      Pdf.new(size: :a4, margin: 40)
      |> Pdf.set_font("Helvetica", 24)
      |> Pdf.set_fill_color(dark)
      |> Pdf.text_at({40, 780}, "Footnote Component", %{bold: true})
      |> Pdf.set_font("Helvetica", 10)
      |> Pdf.set_fill_color(gray)
      |> Pdf.text_at({40, 764}, "Numbered footnotes with separator line")

    # ── Sample body text ──
    doc =
      doc
      |> Pdf.set_font("Helvetica", 11)
      |> Pdf.set_fill_color(dark)
      |> Pdf.text_at({40, 730}, "Global GDP grew by 3.2% in 2025, driven by emerging markets (1).")
      |> Pdf.text_at({40, 714}, "The technology sector accounted for 28% of total growth (2),")
      |> Pdf.text_at({40, 698}, "while manufacturing output declined in several regions (3).")

    # ── Footnotes at bottom ──
    doc =
      doc
      |> Pdf.Component.Footnote.render({40, 640}, %{width: 480}, [
        "Source: World Bank Global Economic Prospects, 2025 Edition",
        "Technology sector includes software, hardware, and digital services",
        "Manufacturing PMI data from select OECD countries, Q4 2025"
      ])

    # ── Second example with custom styling ──
    doc =
      doc
      |> Pdf.set_font("Helvetica", 12)
      |> Pdf.set_fill_color(accent)
      |> Pdf.text_at({40, 560}, "Custom Styled", %{bold: true})
      |> Pdf.set_font("Helvetica", 11)
      |> Pdf.set_fill_color(dark)
      |> Pdf.text_at({40, 540}, "The contract terms (1) specify delivery within 30 days (2).")

    doc =
      doc
      |> Pdf.Component.Footnote.render({40, 490}, %{
        font_size: 8,
        color: {0.3, 0.3, 0.5},
        line_color: {0.6, 0.6, 0.8},
        separator_width: 120,
        line_height: 13
      }, [
        "As defined in Section 4.2 of the Master Services Agreement",
        "Business days only; excludes weekends and national holidays"
      ])

    # ── Continued numbering ──
    doc
    |> Pdf.set_font("Helvetica", 12)
    |> Pdf.set_fill_color(accent)
    |> Pdf.text_at({40, 410}, "Continued Numbering", %{bold: true})
    |> Pdf.set_font("Helvetica", 11)
    |> Pdf.set_fill_color(dark)
    |> Pdf.text_at({40, 390}, "Additional notes can continue from a specific number.")
    |> Pdf.Component.Footnote.render({40, 350}, %{start_number: 4}, [
      "This is footnote number 4",
      "And this is number 5",
      "Continued sequencing from previous section"
    ])
  end
end
