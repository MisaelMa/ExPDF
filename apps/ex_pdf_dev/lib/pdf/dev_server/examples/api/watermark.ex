defmodule Pdf.DevServer.Examples.Api.Watermark do
  @moduledoc false

  def render do
    Pdf.new(size: :a4, margin: 50)
    |> Pdf.set_info(title: "Watermark Example")
    |> Pdf.text("This page has a DRAFT watermark", %{font_size: 18})
    |> Pdf.spacer(15)
    |> Pdf.text("The watermark is rendered behind the content with low opacity.")
    |> Pdf.spacer(10)
    |> Pdf.text("It uses save_state/restore_state, opacity, translate, and rotate.")
    |> Pdf.watermark("DRAFT", %{opacity: 0.08, rotate: 45, font_size: 72, color: :red})
  end
end
