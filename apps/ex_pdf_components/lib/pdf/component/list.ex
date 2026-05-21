defmodule Pdf.Component.List do
  @moduledoc """
  List component for PDF documents.

  Renders bulleted or numbered lists with support for nesting,
  custom markers, and per-level styling.

  ## Examples

      doc |> Pdf.Component.List.render({50, 700}, %{}, [
        "First item",
        "Second item",
        {:nested, ["Sub-item A", "Sub-item B"]},
        "Third item"
      ])

      doc |> Pdf.Component.List.render({50, 700}, %{type: :numbered}, [
        "Step one",
        "Step two",
        "Step three"
      ])
  """

  @default_font "Helvetica"
  @default_font_size 10
  @default_color {0.1, 0.1, 0.1}
  @default_line_height 16
  @default_indent 15
  @default_marker_gap 8

  @bullets ["-", "-", "-"]
  @numbered_formats [:decimal, :alpha, :roman]

  @doc """
  Render a list at `{x, y}`.

  ## Style options

  - `:type` — `:bullet` (default) or `:numbered`
  - `:font` — font name (default `"Helvetica"`)
  - `:font_size` — text size (default `10`)
  - `:color` — text color (default dark)
  - `:line_height` — spacing between items (default `16`)
  - `:indent` — indentation per nesting level (default `15`)
  - `:marker_gap` — space between marker and text (default `8`)
  - `:marker_color` — marker color (defaults to `:color`)

  ## Items format

  Items is a flat list where:
  - `"string"` — a list item
  - `{:nested, [items]}` — a nested sub-list
  """
  def render(doc, {x, y}, style \\ %{}, items) do
    type = Map.get(style, :type, :bullet)
    font = Map.get(style, :font, @default_font)
    font_size = Map.get(style, :font_size, @default_font_size)
    color = Map.get(style, :color, @default_color)
    line_height = Map.get(style, :line_height, @default_line_height)
    indent = Map.get(style, :indent, @default_indent)
    marker_gap = Map.get(style, :marker_gap, @default_marker_gap)
    marker_color = Map.get(style, :marker_color, color)

    ctx = %{
      type: type,
      font: font,
      font_size: font_size,
      color: color,
      line_height: line_height,
      indent: indent,
      marker_gap: marker_gap,
      marker_color: marker_color
    }

    {doc, _y} = render_items(doc, x, y, items, 0, 1, ctx)
    doc
  end

  defp render_items(doc, x, y, items, level, counter, ctx) do
    Enum.reduce(items, {doc, y, counter}, fn item, {d, cy, n} ->
      case item do
        {:nested, sub_items} ->
          {d2, cy2} = render_items(d, x, cy, sub_items, level + 1, 1, ctx)
          {d2, cy2, n}

        text when is_binary(text) ->
          item_x = x + level * ctx.indent
          marker = get_marker(ctx.type, level, n)

          d2 =
            d
            |> Pdf.set_font(ctx.font, ctx.font_size)
            |> Pdf.set_fill_color(ctx.marker_color)
            |> Pdf.text_at({item_x, cy}, marker)
            |> Pdf.set_fill_color(ctx.color)
            |> Pdf.text_at({item_x + marker_width(marker, ctx.font_size) + ctx.marker_gap, cy}, text)

          {d2, cy - ctx.line_height, n + 1}
      end
    end)
    |> then(fn {doc, y, _counter} -> {doc, y} end)
  end

  defp get_marker(:bullet, level, _n) do
    Enum.at(@bullets, rem(level, length(@bullets)))
  end

  defp get_marker(:numbered, level, n) do
    format = Enum.at(@numbered_formats, rem(level, length(@numbered_formats)))
    format_number(n, format) <> "."
  end

  defp format_number(n, :decimal), do: Integer.to_string(n)
  defp format_number(n, :alpha) when n in 1..26, do: <<(n + 96)>>
  defp format_number(n, :alpha), do: Integer.to_string(n)
  defp format_number(n, :roman), do: to_roman(n)

  defp to_roman(n) when n <= 0, do: ""
  defp to_roman(n) when n >= 10, do: String.duplicate("x", div(n, 10)) <> to_roman(rem(n, 10))
  defp to_roman(9), do: "ix"
  defp to_roman(n) when n >= 5, do: "v" <> String.duplicate("i", n - 5)
  defp to_roman(4), do: "iv"
  defp to_roman(n), do: String.duplicate("i", n)

  defp marker_width(marker, font_size) do
    String.length(marker) * font_size * 0.52
  end
end
