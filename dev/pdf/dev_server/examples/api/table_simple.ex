defmodule Pdf.DevServer.Examples.Api.TableSimple do
  @moduledoc false

  def render do
    Pdf.new(size: :a4, margin: 50)
    |> Pdf.set_info(title: "Simple Table")
    |> Pdf.text("Simple Styled Table", %{font_size: 20, bold: true})
    |> Pdf.spacer(15)
    |> Pdf.styled_table([
      ["Product", "Category", "Price"],
      ["Elixir in Action", "Book", "$44.99"],
      ["Phoenix LiveView", "Book", "$39.99"],
      ["Nerves Project", "Hardware", "$89.00"],
      ["LiveBook Pro", "Software", "$29.00"]
    ], %{
      columns: [
        %{width: 200},
        %{width: 140, align: :center},
        %{width: 100, align: :right}
      ],
      header: %{bold: true, background: {0.15, 0.23, 0.38}, color: :white, padding: 10},
      row: %{padding: 8, border_bottom: 0.5, border_color: {0.85, 0.85, 0.85}},
      border: 1,
      border_color: {0.15, 0.23, 0.38},
      border_radius: 4,
      
    })
    |> Pdf.spacer(20)
    |> Pdf.text("Table with header, borders, and rounded corners.", %{font_size: 10, color: :gray})
  end
end
