defmodule Pdf.DevServer.Examples.Api.HelloWorld do
  @moduledoc false

  def render do
    Pdf.new(size: :a4)
    |> Pdf.set_info(title: "Hello World")
    |> Pdf.set_font("Helvetica", 24)
    |> Pdf.text_at({200, 600}, "Hello World!")
    |> Pdf.set_font("Helvetica", 12)
    |> Pdf.text_at({200, 570}, "Generated with elixir-pdf")
  end
end
