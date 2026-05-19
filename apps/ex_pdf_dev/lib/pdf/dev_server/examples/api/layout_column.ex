defmodule Pdf.DevServer.Examples.Api.LayoutColumn do
  @moduledoc false

  def render do
    Pdf.new(size: :a4)
    |> Pdf.set_info(title: "Layout Column")
    |> Pdf.set_font("Helvetica", 11)
    |> then(fn doc ->
      page = doc.current

      page =
        Pdf.Layout.column(page, {50, 750}, {300, 400}, [
          {50, fn page, area ->
            Pdf.Layout.box(page, {area.x, area.y}, {area.width, area.height},
              [style: %{padding: 10, border: 1, background: {1.0, 0.95, 0.9}}],
              fn page, a ->
                Pdf.Page.text_at(page, {a.x, a.y - 14}, "Row 1 - height 50", [])
              end)
          end},
          {80, fn page, area ->
            Pdf.Layout.box(page, {area.x, area.y}, {area.width, area.height},
              [style: %{padding: 10, border: 1, background: {0.9, 0.95, 1.0}}],
              fn page, a ->
                Pdf.Page.text_at(page, {a.x, a.y - 14}, "Row 2 - height 80", [])
              end)
          end},
          {40, fn page, area ->
            Pdf.Layout.box(page, {area.x, area.y}, {area.width, area.height},
              [style: %{padding: 10, border: 1, background: {0.95, 1.0, 0.9}}],
              fn page, a ->
                Pdf.Page.text_at(page, {a.x, a.y - 14}, "Row 3 - height 40", [])
              end)
          end}
        ], gap: 10)

      %{doc | current: page}
    end)
  end
end
