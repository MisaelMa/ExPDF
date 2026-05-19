defmodule Pdf.Component.Row do
  @moduledoc """
  Row component for PDF documents.

  Distributes content horizontally in columns by weight.
  Operates at Document level.

  ## Example

      doc
      |> Pdf.Component.Row.render({50, 700}, {400, 80}, [
        {1, fn doc, area -> Pdf.text_at(doc, {area.x, area.y - 14}, "Col 1") end},
        {2, fn doc, area -> Pdf.text_at(doc, {area.x, area.y - 14}, "Col 2") end}
      ], gap: 10)
  """

  @doc """
  Render a horizontal row at `{x, y}` with size `{w, h}`.

  `columns` is a list of `{weight, callback}` tuples where each callback
  receives `(doc, %{x, y, width, height})`.

  ## Options

  - `:gap` — space between columns (default `0`)
  """
  def render(doc, {x, y}, {w, h}, columns, opts \\ []) when is_list(columns) do
    gap = Keyword.get(opts, :gap, 0)
    total_weight = columns |> Enum.map(&elem(&1, 0)) |> Enum.sum()
    gap_total = gap * max(length(columns) - 1, 0)
    available_w = w - gap_total

    {doc, _x} =
      Enum.reduce(columns, {doc, x}, fn {weight, callback}, {doc, col_x} ->
        col_w = available_w * (weight / total_weight)
        doc = callback.(doc, %{x: col_x, y: y, width: col_w, height: h})
        {doc, col_x + col_w + gap}
      end)

    doc
  end
end
