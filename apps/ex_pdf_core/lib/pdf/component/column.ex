defmodule Pdf.Component.Column do
  @moduledoc """
  Column component for PDF documents.

  Stacks content vertically with fixed heights per row.
  Operates at Document level.

  ## Example

      doc
      |> Pdf.Component.Column.render({50, 700}, {300, 400}, [
        {50, fn doc, area -> Pdf.text_at(doc, {area.x, area.y - 14}, "Row 1") end},
        {80, fn doc, area -> Pdf.text_at(doc, {area.x, area.y - 14}, "Row 2") end}
      ], gap: 5)
  """

  @doc """
  Render a vertical column at `{x, y}` with size `{w, h}`.

  `rows` is a list of `{height, callback}` tuples where each callback
  receives `(doc, %{x, y, width, height})`.

  ## Options

  - `:gap` — space between rows (default `0`)
  """
  def render(doc, {x, y}, {w, _h}, rows, opts \\ []) when is_list(rows) do
    gap = Keyword.get(opts, :gap, 0)

    {doc, _y} =
      Enum.reduce(rows, {doc, y}, fn {row_h, callback}, {doc, row_y} ->
        doc = callback.(doc, %{x: x, y: row_y, width: w, height: row_h})
        {doc, row_y - row_h - gap}
      end)

    doc
  end
end
