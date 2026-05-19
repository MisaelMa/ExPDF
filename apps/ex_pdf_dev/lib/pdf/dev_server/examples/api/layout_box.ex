defmodule Pdf.DevServer.Examples.Api.LayoutBox do
  @moduledoc false

  def render do
    Pdf.new(size: :a4)
    |> Pdf.set_info(title: "Layout Box")
    |> Pdf.set_font("Helvetica", 12)
    |> then(fn doc ->
      page = doc.current

      page =
        Pdf.Layout.box(
          page,
          {50, 750},
          {250, 120},
          [style: %{padding: 15, border: 2, border_color: :navy, background: {0.93, 0.93, 1.0}}],
          fn page, area ->
            page
            |> Pdf.Page.text_at({area.x, area.y - 14}, "Box with padding, border & background", [])
            |> Pdf.Page.text_at({area.x, area.y - 30}, "Inner area: #{area.width}x#{area.height}", [])
          end
        )

      page =
        Pdf.Layout.box(
          page,
          {320, 750},
          {220, 120},
          [style: %{padding: 10, margin: 5, border: 1, border_color: :gray}],
          fn page, area ->
            page
            |> Pdf.Page.text_at({area.x, area.y - 14}, "Box with margin", [])
            |> Pdf.Page.text_at({area.x, area.y - 30}, "margin=5, padding=10", [])
          end
        )

      %{doc | current: page}
    end)
  end
end
