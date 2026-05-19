defmodule Pdf.DevServer.Examples.Api.PageTemplates do
  @moduledoc false

  def render do
    Pdf.new(size: :a4, margin: %{top: 60, bottom: 50, left: 50, right: 50})
    |> Pdf.set_info(title: "Page Templates")
    |> Pdf.on_page(:header, fn doc, info ->
      doc
      |> Pdf.set_font("Helvetica", 9)
      |> Pdf.set_fill_color(:gray)
      |> Pdf.text_at({50, 810}, "Pdf Dev Server - Page Templates Example")
      |> Pdf.text_at({480, 810}, "Page #{info.number}")
      |> Pdf.save_state()
      |> Pdf.set_stroke_color(:gray)
      |> Pdf.set_line_width(0.5)
      |> Pdf.line({50, 805}, {545, 805})
      |> Pdf.stroke()
      |> Pdf.restore_state()
      |> Pdf.set_fill_color(:black)
    end)
    |> Pdf.on_page(:footer, fn doc, _info ->
      doc
      |> Pdf.save_state()
      |> Pdf.set_stroke_color(:gray)
      |> Pdf.set_line_width(0.5)
      |> Pdf.line({50, 45}, {545, 45})
      |> Pdf.stroke()
      |> Pdf.restore_state()
      |> Pdf.set_font("Helvetica", 8)
      |> Pdf.set_fill_color(:gray)
      |> Pdf.text_at({230, 33}, "Generated with elixir-pdf")
      |> Pdf.set_fill_color(:black)
    end)
    |> Pdf.set_font("Helvetica", 18)
    |> Pdf.text("Page 1 - Header & Footer", %{font_size: 18})
    |> Pdf.spacer(15)
    |> Pdf.text("This page has automatic header and footer templates.")
    |> Pdf.spacer(10)
    |> Pdf.text("When you add a new page, they appear automatically.")
    |> Pdf.page_break()
    |> Pdf.text("Page 2 - Same templates", %{font_size: 18})
    |> Pdf.spacer(15)
    |> Pdf.text("Notice the header and footer are here too!")
    |> Pdf.page_break()
    |> Pdf.text("Page 3 - Still going", %{font_size: 18})
    |> Pdf.spacer(15)
    |> Pdf.text("Templates persist across all pages.")
  end
end
