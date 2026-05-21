defmodule Pdf.DevServer.Examples.Api.TableZebra do
  @moduledoc false

  def render do
    Pdf.new(size: :a4, margin: 50)
    |> Pdf.set_info(title: "Zebra Stripe Table")
    |> Pdf.text("Zebra Stripe Table", %{font_size: 20, bold: true})
    |> Pdf.spacer(15)
    |> Pdf.StyledTable.render([
      ["#", "Employee", "Department", "Status"],
      ["1", "Alice Johnson", "Engineering", "Active"],
      ["2", "Bob Smith", "Marketing", "Active"],
      ["3", "Carol Williams", "Engineering", "On Leave"],
      ["4", "David Brown", "Sales", "Active"],
      ["5", "Eve Davis", "Engineering", "Active"],
      ["6", "Frank Miller", "Marketing", "Inactive"],
      ["7", "Grace Wilson", "Sales", "Active"],
      ["8", "Henry Taylor", "Engineering", "Active"]
    ], %{
      columns: [
        %{width: 40, align: :center},
        %{width: 170},
        %{width: 130, align: :center},
        %{width: 100, align: :center}
      ],
      header: %{bold: true, background: {0.2, 0.6, 0.4}, color: :white, padding: 10},
      row: %{padding: 8, border_bottom: 0.3, border_color: {0.9, 0.9, 0.9}},
      alt_row: %{background: {0.94, 0.98, 0.95}},
      border: 1.5,
      border_color: {0.2, 0.6, 0.4},
      border_radius: 8
    })
  end
end
