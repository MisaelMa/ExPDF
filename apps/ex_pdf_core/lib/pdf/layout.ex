defmodule Pdf.Layout do
  @moduledoc """
  Layout helpers for positioning content in PDF documents.

  Provides `box/4`, `row/4`, and `column/4` containers that manage
  coordinates, padding, margin, and borders based on `Pdf.Style`.
  """

  alias Pdf.{Page, Style}

  @doc """
  Render content inside a box with padding, margin, border, and optional background.

  The callback receives `(page, %{x, y, width, height})` with the inner content area
  (after padding/margin are applied) and must return the updated page.

  ## Example

      Layout.box(page, {50, 700}, {200, 100}, style: %{padding: 10, border: 1}, fn page, area ->
        Page.text_at(page, {area.x, area.y - 12}, "Inside box")
      end)
  """
  def box(page, {x, y}, {w, h}, opts \\ [], callback) do
    {w, h} = maybe_resolve_size({w, h}, opts)
    style = parse_style(opts)
    {mt, mr, mb, ml} = style.margin
    {pt, pr, pb, pl} = style.padding
    {bt, br, bb, bl} = style.border

    outer_x = x + ml
    outer_y = y - mt
    outer_w = w - ml - mr
    outer_h = h - mt - mb

    page =
      if style.background do
        page
        |> Page.save_state()
        |> Page.set_fill_color(style.background)
        |> Page.rectangle({outer_x, outer_y - outer_h}, {outer_w, outer_h})
        |> Page.fill()
        |> Page.restore_state()
      else
        page
      end

    page = draw_borders(page, {outer_x, outer_y, outer_w, outer_h}, style)

    inner_x = outer_x + bl + pl
    inner_y = outer_y - bt - pt
    inner_w = outer_w - bl - br - pl - pr
    inner_h = outer_h - bt - bb - pt - pb

    callback.(page, %{x: inner_x, y: inner_y, width: inner_w, height: inner_h})
  end

  @doc """
  Distribute content horizontally in columns.

  Takes a list of `{weight, callback}` tuples. The available width is
  split proportionally by weight.

  ## Example

      Layout.row(page, {50, 700}, {400, 100}, [
        {1, fn page, area -> Page.text_at(page, {area.x, area.y - 12}, "Left") end},
        {2, fn page, area -> Page.text_at(page, {area.x, area.y - 12}, "Center (2x wide)") end},
        {1, fn page, area -> Page.text_at(page, {area.x, area.y - 12}, "Right") end}
      ])
  """
  def row(page, {x, y}, {w, h}, columns, opts \\ []) do
    {w, h} = maybe_resolve_size({w, h}, opts)
    style = parse_style(opts)
    {_mt, _mr, _mb, _ml} = style.margin
    gap = Keyword.get(opts, :gap, 0)

    total_weight = columns |> Enum.map(&elem(&1, 0)) |> Enum.sum()
    gap_total = gap * max(length(columns) - 1, 0)
    available_w = w - gap_total

    {page, _x} =
      Enum.reduce(columns, {page, x}, fn {weight, callback}, {page, col_x} ->
        col_w = available_w * (weight / total_weight)
        page = callback.(page, %{x: col_x, y: y, width: col_w, height: h})
        {page, col_x + col_w + gap}
      end)

    page
  end

  @doc """
  Stack content vertically.

  Takes a list of `{height, callback}` tuples. Each item is placed
  below the previous one.

  ## Example

      Layout.column(page, {50, 700}, {400, 300}, [
        {20, fn page, area -> Page.text_at(page, {area.x, area.y - 12}, "Row 1") end},
        {20, fn page, area -> Page.text_at(page, {area.x, area.y - 12}, "Row 2") end}
      ])
  """
  def column(page, {x, y}, {w, h}, rows, opts \\ []) do
    {w, _h} = maybe_resolve_size({w, h}, opts)
    gap = Keyword.get(opts, :gap, 0)

    {page, _y} =
      Enum.reduce(rows, {page, y}, fn {row_h, callback}, {page, row_y} ->
        page = callback.(page, %{x: x, y: row_y, width: w, height: row_h})
        {page, row_y - row_h - gap}
      end)

    page
  end

  defp maybe_resolve_size(size, opts) do
    case Keyword.get(opts, :parent) do
      %{width: _, height: _} = parent -> Pdf.Dimension.resolve_size(size, parent)
      _ -> size
    end
  end

  defp parse_style(opts) do
    case Keyword.get(opts, :style) do
      nil -> Style.new()
      %Style{} = s -> s
      map -> Style.new(map)
    end
  end

  defp draw_borders(page, {x, y, w, h}, style) do
    {bt, br, bb, bl} = style.border

    if bt == 0 and br == 0 and bb == 0 and bl == 0 do
      page
    else
      page = Page.save_state(page)
      page = Page.set_stroke_color(page, style.border_color)

      page =
        if bt > 0 do
          page |> Page.set_line_width(bt) |> Page.line({x, y}, {x + w, y}) |> Page.stroke()
        else
          page
        end

      page =
        if br > 0 do
          page
          |> Page.set_line_width(br)
          |> Page.line({x + w, y}, {x + w, y - h})
          |> Page.stroke()
        else
          page
        end

      page =
        if bb > 0 do
          page
          |> Page.set_line_width(bb)
          |> Page.line({x, y - h}, {x + w, y - h})
          |> Page.stroke()
        else
          page
        end

      page =
        if bl > 0 do
          page |> Page.set_line_width(bl) |> Page.line({x, y}, {x, y - h}) |> Page.stroke()
        else
          page
        end

      Page.restore_state(page)
    end
  end
end
