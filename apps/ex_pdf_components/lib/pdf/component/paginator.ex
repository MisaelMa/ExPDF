defmodule Pdf.Component.Paginator do
  @moduledoc """
  Paginator component for PDF documents.

  Registers a footer template that renders page numbers on every page.
  Uses `Pdf.on_page(:footer, ...)` internally.

  ## Examples

      doc |> Pdf.Component.Paginator.apply()

      doc |> Pdf.Component.Paginator.apply(%{
        format: :center,
        font_size: 9,
        color: {0.5, 0.5, 0.5},
        prefix: "Page "
      })
  """

  @default_font "Helvetica"
  @default_font_size 9
  @default_color {0.5, 0.5, 0.5}
  @default_margin_bottom 30

  @doc """
  Apply page numbering to the document.

  This registers a footer template — all subsequent pages will
  have page numbers rendered automatically.

  ## Style options

  - `:format` — `:center` (default), `:right`, or `:left`
  - `:font` — font name (default `"Helvetica"`)
  - `:font_size` — text size (default `9`)
  - `:color` — text color (default gray)
  - `:margin_bottom` — distance from page bottom (default `30`)
  - `:prefix` — text before number (default `"Page "`)
  - `:show_total` — show "of N" suffix (default `false`)
  - `:total_pages` — total page count (required if `:show_total` is `true`)
  - `:separator` — separator between number and total (default `" of "`)
  """
  def apply(doc, style \\ %{}) do
    format = Map.get(style, :format, :center)
    font = Map.get(style, :font, @default_font)
    font_size = Map.get(style, :font_size, @default_font_size)
    color = Map.get(style, :color, @default_color)
    margin_bottom = Map.get(style, :margin_bottom, @default_margin_bottom)
    prefix = Map.get(style, :prefix, "Page ")
    show_total = Map.get(style, :show_total, false)
    total_pages = Map.get(style, :total_pages, 0)
    separator = Map.get(style, :separator, " of ")

    Pdf.on_page(doc, :footer, fn d, info ->
      page_num = info.number
      %{width: pw} = Pdf.size(d)

      text = prefix <> "#{page_num}"
      text = if show_total and total_pages > 0 do
        text <> separator <> "#{total_pages}"
      else
        text
      end

      text_w = String.length(text) * font_size * 0.52

      x = case format do
        :center -> (pw - text_w) / 2
        :right -> pw - text_w - 40
        :left -> 40
      end

      d
      |> Pdf.set_font(font, font_size)
      |> Pdf.set_fill_color(color)
      |> Pdf.text_at({x, margin_bottom}, text)
    end)
  end
end
