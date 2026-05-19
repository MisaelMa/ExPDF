defmodule Pdf.DevServer.Examples.Api.MarginsCursor do
  @moduledoc false

  def render do
    Pdf.new(size: :a4, margin: %{top: 60, bottom: 60, left: 50, right: 50})
    |> Pdf.set_info(title: "Margins & Cursor")
    |> Pdf.set_font("Helvetica", 14)
    |> Pdf.text("This document has margins: top=60, bottom=60, left=50, right=50")
    |> Pdf.spacer(10)
    |> Pdf.text("The cursor automatically starts inside the content area.")
    |> Pdf.spacer(20)
    |> Pdf.text("After spacer(20)")
    |> Pdf.spacer(10)
    |> Pdf.horizontal_line()
    |> Pdf.spacer(10)
    |> Pdf.text("After a horizontal line and spacer(10)")
    |> Pdf.spacer(30)
    |> Pdf.text("Content wraps within margins when using Pdf.text/2,3")
  end
end
