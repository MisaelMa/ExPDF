defmodule Pdf.Component.Table do
  @moduledoc """
  `<table>` con encabezados mergeados y subencabezados (grid de consumo).

  ## Builder

      %{type: :table, props: %{
        rows: [["Básico", "01273", ...], ...],
        style: %{position: :cursor, width: :full}
      }}
  """

  alias Pdf.Component.Draw

  @h1 11
  @h2 9
  @rh 9.5

  def measure(%{rows: rows}) when is_list(rows), do: @h1 + @h2 + length(rows) * @rh
  def measure(_), do: @h1 + @h2 + @rh * 4

  def render(doc, {x, y}, style) do
    w = Map.get(style, :width, 575)
    rows = Map.get(style, :rows, [])

    cols = Draw.scale_cols([76, 35, 29, 35, 29, 41, 43, 52], w)
    xs = Draw.col_starts(x, cols)
    table_h = measure(style)

    doc =
      doc
      |> Draw.merged_header_rounded(y - @h1, xs, cols, @h1, [
        {0, 1, "Concepto"},
        {1, 2, "Lectura actual"},
        {3, 2, "Lectura anterior"},
        {5, 1, "Total\nperiodo"},
        {6, 1, "Precio\n(MXN)"},
        {7, 1, "Subtotal\n(MXN)"}
      ])
      |> Draw.sub_header(y - @h1 - @h2, xs, cols, @h2, [
        {1, "Medida"},
        {2, "Estimada"},
        {3, "Medida"},
        {4, "Estimada"}
      ])

    doc =
      Enum.with_index(rows)
      |> Enum.reduce({doc, y - @h1 - @h2}, fn {row, idx}, {d, ry} ->
        y2 = ry - @rh
        bold = Draw.row_bold?(row)

        {bg, fg} =
          cond do
            idx == 0 -> {Draw.green_row(), Draw.white()}
            bold -> {Draw.bg_total(), Draw.black()}
            rem(idx, 2) == 0 -> {Draw.white(), Draw.black()}
            true -> {{0.975, 0.975, 0.975}, Draw.black()}
          end

        d =
          d
          |> Draw.fill_row(y2, xs, cols, @rh, bg)
          |> Draw.grid_row(y2, xs, cols, @rh)
          |> then(fn dd ->
            Enum.with_index(row)
            |> Enum.reduce(dd, fn {cell, ci}, acc ->
              align = if ci >= 5, do: :right, else: :left
              pad = 2

              Draw.text_cell(
                acc,
                Enum.at(xs, ci) + pad,
                ry - 6,
                Enum.at(cols, ci) - pad * 2,
                cell,
                bold: bold or idx == 0,
                align: align,
                size: 6,
                color: fg
              )
            end)
          end)

        {d, y2}
      end)
      |> elem(0)

    x0 = hd(xs)
    Draw.stroke_rounded_rect(doc, x0, y, Enum.sum(cols), table_h, 2.5, 0.35, Draw.line())
  end
end
