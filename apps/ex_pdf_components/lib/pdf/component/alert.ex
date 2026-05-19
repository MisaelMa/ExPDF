defmodule Pdf.Component.Alert do
  @moduledoc """
  Alert/Callout component for PDF documents.

  Renders a colored notification box with an icon character, title,
  and message text. Supports info, warning, error, and success variants.

  ## Examples

      doc |> Pdf.Component.Alert.render({50, 700}, %{
        type: :info,
        title: "Note",
        message: "This is an informational message.",
        width: 400
      })

      doc |> Pdf.Component.Alert.render({50, 700}, %{
        type: :error,
        title: "Error",
        message: "Something went wrong. Please try again.",
        width: 400
      })
  """

  @presets %{
    info: %{
      icon: "i",
      bg: {0.93, 0.95, 1.0},
      bar: {0.25, 0.47, 0.85},
      icon_bg: {0.25, 0.47, 0.85},
      title_color: {0.15, 0.30, 0.60}
    },
    success: %{
      icon: "!",
      bg: {0.93, 0.98, 0.93},
      bar: {0.20, 0.65, 0.30},
      icon_bg: {0.20, 0.65, 0.30},
      title_color: {0.12, 0.45, 0.18}
    },
    warning: %{
      icon: "!",
      bg: {1.0, 0.97, 0.90},
      bar: {0.85, 0.65, 0.10},
      icon_bg: {0.85, 0.65, 0.10},
      title_color: {0.60, 0.45, 0.05}
    },
    error: %{
      icon: "x",
      bg: {1.0, 0.93, 0.93},
      bar: {0.80, 0.20, 0.20},
      icon_bg: {0.80, 0.20, 0.20},
      title_color: {0.60, 0.12, 0.12}
    }
  }

  @default_font "Helvetica"
  @default_padding 12
  @default_border_radius 5

  @doc """
  Render an alert at `{x, y}`.

  ## Style options

  - `:type` — `:info` (default), `:success`, `:warning`, or `:error`
  - `:title` — bold title text
  - `:message` — body message text (required)
  - `:width` — alert width (required)
  - `:font` — font name (default `"Helvetica"`)
  - `:padding` — inner padding (default `12`)
  - `:border_radius` — corner radius (default `5`)
  - `:icon` — override icon character
  """
  def render(doc, {x, y}, style \\ %{}) do
    type = Map.get(style, :type, :info)
    preset = Map.get(@presets, type, @presets.info)
    title = Map.get(style, :title)
    message = Map.get(style, :message, "")
    width = Map.get(style, :width, 400)
    font = Map.get(style, :font, @default_font)
    padding = Map.get(style, :padding, @default_padding)
    radius = Map.get(style, :border_radius, @default_border_radius)
    icon = Map.get(style, :icon, preset.icon)

    bg = Map.get(style, :background, preset.bg)
    bar_color = Map.get(style, :bar_color, preset.bar)
    icon_bg = Map.get(style, :icon_bg, preset.icon_bg)
    title_color = Map.get(style, :title_color, preset.title_color)
    message_color = Map.get(style, :message_color, {0.25, 0.25, 0.25})

    icon_size = 18
    icon_area = icon_size + 8
    text_x = x + padding + icon_area + 8
    avail_w = width - padding * 2 - icon_area - 8

    # Calculate height
    line_h = 14
    title_h = if title, do: 16, else: 0

    chars_per_line = max(trunc(avail_w / (10 * 0.52)), 10)
    msg_lines = wrap_text(message, chars_per_line)
    msg_h = length(msg_lines) * line_h
    total_h = padding + max(title_h + msg_h, icon_area) + padding

    # Background
    doc =
      doc
      |> Pdf.save_state()
      |> Pdf.set_fill_color(bg)
      |> Pdf.rounded_rectangle({x, y - total_h}, {width, total_h}, radius)
      |> Pdf.fill()
      |> Pdf.restore_state()

    # Left accent bar
    bar_w = 4
    doc =
      doc
      |> Pdf.save_state()
      |> Pdf.set_fill_color(bar_color)
      |> Pdf.rectangle({x, y - total_h}, {bar_w, total_h})
      |> Pdf.fill()
      |> Pdf.restore_state()

    # Icon circle
    icon_cx = x + padding + icon_size / 2 + 2
    icon_cy = y - padding - icon_size / 2

    icon_r = icon_size / 2
    icon_box_x = icon_cx - icon_r
    icon_box_y = icon_cy - icon_r

    doc =
      doc
      |> Pdf.save_state()
      |> Pdf.set_fill_color(icon_bg)
      |> Pdf.rounded_rectangle({icon_box_x, icon_box_y}, {icon_size, icon_size}, icon_r)
      |> Pdf.fill()
      |> Pdf.restore_state()
      |> Pdf.set_font(font, 11, bold: true)
      |> Pdf.set_fill_color({1.0, 1.0, 1.0})
      |> Pdf.text_at({icon_cx - 3, icon_cy - 4}, icon)

    # Title
    {doc, text_y} =
      if title do
        doc =
          doc
          |> Pdf.set_font(font, 11, bold: true)
          |> Pdf.set_fill_color(title_color)
          |> Pdf.text_at({text_x, y - padding - 11}, title)

        {doc, y - padding - title_h - 11}
      else
        {doc, y - padding - 11}
      end

    # Message lines
    Enum.with_index(msg_lines)
    |> Enum.reduce(doc, fn {line, i}, d ->
      d
      |> Pdf.set_font(font, 10)
      |> Pdf.set_fill_color(message_color)
      |> Pdf.text_at({text_x, text_y - i * line_h}, line)
    end)
  end

  defp wrap_text(text, chars_per_line) do
    words = String.split(text, " ")

    {lines, current} =
      Enum.reduce(words, {[], ""}, fn word, {lines, current} ->
        candidate = if current == "", do: word, else: current <> " " <> word

        if String.length(candidate) > chars_per_line and current != "" do
          {[current | lines], word}
        else
          {lines, candidate}
        end
      end)

    Enum.reverse(if current != "", do: [current | lines], else: lines)
  end
end
