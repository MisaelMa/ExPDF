defmodule Pdf.DevServer.Examples.Api.Background do
  @moduledoc false

  def render do
    Pdf.new(size: :a4, margin: 50)
    |> Pdf.set_info(title: "Background Color")
    |> Pdf.background(%{background: {0.95, 0.95, 1.0}})
    |> Pdf.text("This page has a light blue background", %{font_size: 18})
    |> Pdf.spacer(10)
    |> Pdf.text("The background fills the entire page behind all content.")
  end
end
