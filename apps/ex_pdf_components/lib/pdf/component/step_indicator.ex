defmodule Pdf.Component.StepIndicator do
  @moduledoc """
  Step indicator component for PDF documents.

  Renders numbered steps with a connecting line, showing progress
  through a multi-step process (wizard-style).

  ## Examples

      doc |> Pdf.Component.StepIndicator.render({50, 700}, %{width: 450}, [
        %{label: "Account", status: :completed},
        %{label: "Profile", status: :active},
        %{label: "Review", status: :pending},
        %{label: "Done", status: :pending}
      ])
  """

  @default_font "Helvetica"
  @default_step_size 24
  @default_completed_color {0.2, 0.7, 0.3}
  @default_active_color {0.2, 0.5, 0.9}
  @default_pending_color {0.75, 0.75, 0.75}
  @default_line_color {0.85, 0.85, 0.85}

  @doc """
  Render a step indicator at `{x, y}`.

  ## Style options

  - `:width` — total width (default `400`)
  - `:step_size` — circle diameter (default `24`)
  - `:completed_color` — completed step color
  - `:active_color` — active step color
  - `:pending_color` — pending step color
  - `:font` — font name

  ## Steps format

  List of maps: `%{label: "Step name", status: :completed | :active | :pending}`
  """
  def render(doc, {x, y}, style \\ %{}, steps) do
    width = Map.get(style, :width, 400)
    step_size = Map.get(style, :step_size, @default_step_size)
    completed = Map.get(style, :completed_color, @default_completed_color)
    active = Map.get(style, :active_color, @default_active_color)
    pending = Map.get(style, :pending_color, @default_pending_color)
    line_color = Map.get(style, :line_color, @default_line_color)
    font = Map.get(style, :font, @default_font)

    count = length(steps)
    spacing = if count > 1, do: (width - step_size) / (count - 1), else: 0
    r = step_size / 2
    center_y = y - r

    # Connecting line
    doc =
      if count > 1 do
        doc
        |> Pdf.save_state()
        |> Pdf.set_stroke_color(line_color)
        |> Pdf.set_line_width(2)
        |> Pdf.line({x + r, center_y}, {x + r + spacing * (count - 1), center_y})
        |> Pdf.stroke()
        |> Pdf.restore_state()
      else
        doc
      end

    # Steps
    steps
    |> Enum.with_index()
    |> Enum.reduce(doc, fn {step, i}, d ->
      cx = x + r + i * spacing
      status = Map.get(step, :status, :pending)
      label = Map.get(step, :label, "")

      color = case status do
        :completed -> completed
        :active -> active
        _ -> pending
      end

      # Circle background
      d =
        d
        |> Pdf.save_state()
        |> Pdf.set_fill_color(color)
        |> Pdf.rounded_rectangle({cx - r, center_y - r}, {step_size, step_size}, r)
        |> Pdf.fill()
        |> Pdf.restore_state()

      # Number or checkmark
      text = if status == :completed, do: "ok", else: "#{i + 1}"
      text_x = cx - String.length(text) * 3.5
      d =
        d
        |> Pdf.set_font(font, 10, bold: true)
        |> Pdf.set_fill_color({1.0, 1.0, 1.0})
        |> Pdf.text_at({text_x, center_y - 4}, text)

      # Label below
      if label != "" do
        label_w = String.length(label) * 5
        d
        |> Pdf.set_font(font, 8)
        |> Pdf.set_fill_color(color)
        |> Pdf.text_at({cx - label_w / 2, center_y - r - 14}, label)
      else
        d
      end
    end)
  end
end
