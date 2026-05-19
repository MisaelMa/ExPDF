defmodule Pdf.DevServer.Examples.Api.OpacityTransforms do
  @moduledoc false

  def render do
    Pdf.new(size: :a4)
    |> Pdf.set_info(title: "Opacity & Transforms")
    |> Pdf.set_font("Helvetica", 12)
    |> Pdf.text_at({50, 800}, "Normal text (full opacity)")
    # Semi-transparent rectangles
    |> Pdf.save_state()
    |> Pdf.set_fill_color(:red)
    |> Pdf.set_fill_opacity(1.0)
    |> Pdf.rectangle({50, 650}, {150, 100})
    |> Pdf.fill()
    |> Pdf.restore_state()
    |> Pdf.save_state()
    |> Pdf.set_fill_color(:blue)
    |> Pdf.set_fill_opacity(0.5)
    |> Pdf.rectangle({120, 620}, {150, 100})
    |> Pdf.fill()
    |> Pdf.restore_state()
    |> Pdf.save_state()
    |> Pdf.set_fill_color(:green)
    |> Pdf.set_fill_opacity(0.3)
    |> Pdf.rectangle({190, 590}, {150, 100})
    |> Pdf.fill()
    |> Pdf.restore_state()
    # Rotated text
    |> Pdf.save_state()
    |> Pdf.set_font("Helvetica", 20)
    |> Pdf.translate({300, 400})
    |> Pdf.rotate(30)
    |> Pdf.text_at({0, 0}, "Rotated 30 degrees")
    |> Pdf.restore_state()
    # Scaled text
    |> Pdf.save_state()
    |> Pdf.set_font("Helvetica", 12)
    |> Pdf.translate({50, 300})
    |> Pdf.scale({2.0, 2.0})
    |> Pdf.text_at({0, 0}, "Scaled 2x")
    |> Pdf.restore_state()
  end
end
