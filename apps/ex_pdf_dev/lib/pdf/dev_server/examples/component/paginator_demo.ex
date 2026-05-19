defmodule Pdf.DevServer.Examples.Component.PaginatorDemo do
  @moduledoc false

  def render do
    dark = {0.1, 0.1, 0.1}
    accent = {0.0, 0.45, 0.75}
    gray = {0.45, 0.45, 0.45}

    doc =
      Pdf.new(size: :a4, margin: 40)
      |> Pdf.Component.Paginator.apply(%{
        format: :center,
        prefix: "Page ",
        show_total: true,
        total_pages: 4
      })

    # ── Page 1 ──
    doc =
      doc
      |> Pdf.set_font("Helvetica", 24)
      |> Pdf.set_fill_color(dark)
      |> Pdf.text_at({40, 780}, "Paginator Component", %{bold: true})
      |> Pdf.set_font("Helvetica", 10)
      |> Pdf.set_fill_color(gray)
      |> Pdf.text_at({40, 764}, "Automatic page numbering in footer — applied via on_page callback")
      |> Pdf.set_font("Helvetica", 14)
      |> Pdf.set_fill_color(accent)
      |> Pdf.text_at({40, 700}, "Page 1: Center Aligned", %{bold: true})
      |> Pdf.set_font("Helvetica", 11)
      |> Pdf.set_fill_color(dark)
      |> Pdf.text_at({40, 680}, "This page uses centered page numbers: \"Page 1 of 4\".")
      |> Pdf.text_at({40, 664}, "The paginator registers a footer template that renders on every page.")
      |> Pdf.text_at({40, 640}, "Look at the bottom of this page to see the footer.")

    # ── Page 2 ──
    doc =
      doc
      |> Pdf.add_page(:a4)
      |> Pdf.set_font("Helvetica", 14)
      |> Pdf.set_fill_color(accent)
      |> Pdf.text_at({40, 780}, "Page 2: Content Continues", %{bold: true})
      |> Pdf.set_font("Helvetica", 11)
      |> Pdf.set_fill_color(dark)
      |> Pdf.text_at({40, 760}, "Each page automatically gets its page number in the footer.")
      |> Pdf.text_at({40, 744}, "No manual positioning needed — the paginator handles it.")

    # ── Page 3 ──
    doc =
      doc
      |> Pdf.add_page(:a4)
      |> Pdf.set_font("Helvetica", 14)
      |> Pdf.set_fill_color(accent)
      |> Pdf.text_at({40, 780}, "Page 3: More Content", %{bold: true})
      |> Pdf.set_font("Helvetica", 11)
      |> Pdf.set_fill_color(dark)
      |> Pdf.text_at({40, 760}, "The paginator supports :center, :left, and :right alignment.")
      |> Pdf.text_at({40, 744}, "You can customize prefix, font size, and color.")

    # ── Page 4 ──
    doc
    |> Pdf.add_page(:a4)
    |> Pdf.set_font("Helvetica", 14)
    |> Pdf.set_fill_color(accent)
    |> Pdf.text_at({40, 780}, "Page 4: Last Page", %{bold: true})
    |> Pdf.set_font("Helvetica", 11)
    |> Pdf.set_fill_color(dark)
    |> Pdf.text_at({40, 760}, "Usage:")
    |> Pdf.set_font("Courier", 10)
    |> Pdf.set_fill_color({0.3, 0.3, 0.3})
    |> Pdf.text_at({50, 738}, "doc |> Pdf.Component.Paginator.apply(%{")
    |> Pdf.text_at({50, 724}, "  format: :center,")
    |> Pdf.text_at({50, 710}, "  prefix: \"Page \",")
    |> Pdf.text_at({50, 696}, "  show_total: true,")
    |> Pdf.text_at({50, 682}, "  total_pages: 4")
    |> Pdf.text_at({50, 668}, "})")
  end
end
