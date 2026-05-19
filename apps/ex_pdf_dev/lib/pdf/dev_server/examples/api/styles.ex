defmodule Pdf.DevServer.Examples.Api.Styles do
  @moduledoc false

  def render do
    Pdf.new(size: :a4, margin: 50, compress: false)
    |> Pdf.set_info(title: "Styled Text")
    |> Pdf.text("Normal text (Helvetica 12)", %{})
    |> Pdf.spacer(5)
    |> Pdf.text("Bold text", %{bold: true})
    |> Pdf.spacer(5)
    |> Pdf.text("Large red text", %{font_size: 24, color: :red})
    |> Pdf.spacer(5)
    |> Pdf.text("Blue italic", %{italic: true, color: :blue, font_size: 16})
    |> Pdf.spacer(5)
    |> Pdf.text("Small gray text", %{font_size: 8, color: :gray})
    |> Pdf.spacer(10)
    |> Pdf.horizontal_line(%{color: :gray})
    |> Pdf.spacer(5)
    |> Pdf.text("After a horizontal line", %{font_size: 14})
  end
end
