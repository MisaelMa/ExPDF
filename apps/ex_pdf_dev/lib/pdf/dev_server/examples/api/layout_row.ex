defmodule Pdf.DevServer.Examples.Api.LayoutRow do
  @moduledoc false

  def render do
    Pdf.new(size: :a4)
    |> Pdf.set_info(title: "Layout Row")
    |> Pdf.set_font("Helvetica", 11)
    |> then(fn doc ->
      page = doc.current

      page =
        Pdf.Layout.row(page, {50, 750}, {500, 80}, [
          {1, fn page, area ->
            Pdf.Layout.box(page, {area.x, area.y}, {area.width, area.height},
              [style: %{padding: 8, border: 1, background: {1.0, 0.9, 0.9}}],
              fn page, a ->
                Pdf.Page.text_at(page, {a.x, a.y - 12}, "Col 1 (weight 1)", [])
              end)
          end},
          {2, fn page, area ->
            Pdf.Layout.box(page, {area.x, area.y}, {area.width, area.height},
              [style: %{padding: 8, border: 1, background: {0.9, 1.0, 0.9}}],
              fn page, a ->
                Pdf.Page.text_at(page, {a.x, a.y - 12}, "Col 2 (weight 2, double width)", [])
              end)
          end},
          {1, fn page, area ->
            Pdf.Layout.box(page, {area.x, area.y}, {area.width, area.height},
              [style: %{padding: 8, border: 1, background: {0.9, 0.9, 1.0}}],
              fn page, a ->
                Pdf.Page.text_at(page, {a.x, a.y - 12}, "Col 3 (weight 1)", [])
              end)
          end}
        ], gap: 8)

      %{doc | current: page}
    end)
  end
end
