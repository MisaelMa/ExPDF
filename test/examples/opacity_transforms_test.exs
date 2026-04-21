defmodule Pdf.Examples.OpacityTransformsTest do
  use Pdf.Case, async: true

  @open false
  test "generate document with opacity and transforms" do
    file_path = output("opacity_transforms.pdf")

    pdf = Pdf.new(size: :a4, compress: false)

    pdf
    |> Pdf.set_info(title: "Opacity & Transforms Test")
    |> Pdf.set_font("Helvetica", 16, bold: true)
    |> Pdf.text_at({20, 800}, "Opacity & Transform Demo")
    |> Pdf.set_font("Helvetica", 12)
    # Opacity demo - overlapping rectangles
    |> Pdf.set_fill_color(:red)
    |> Pdf.set_opacity(1.0)
    |> Pdf.rectangle({50, 600}, {100, 100})
    |> Pdf.fill()
    |> Pdf.set_fill_color(:blue)
    |> Pdf.set_fill_opacity(0.5)
    |> Pdf.rectangle({100, 650}, {100, 100})
    |> Pdf.fill()
    |> Pdf.set_fill_color(:green)
    |> Pdf.set_fill_opacity(0.3)
    |> Pdf.rectangle({75, 625}, {100, 100})
    |> Pdf.fill()
    # Reset opacity
    |> Pdf.set_opacity(1.0)
    |> Pdf.set_fill_color(:black)
    |> Pdf.text_at({50, 580}, "Overlapping semi-transparent rectangles")
    # Rotation demo
    |> Pdf.save_state()
    |> Pdf.translate({300, 500})
    |> Pdf.rotate(30)
    |> Pdf.set_fill_color(:purple)
    |> Pdf.rectangle({0, 0}, {100, 50})
    |> Pdf.fill()
    |> Pdf.restore_state()
    |> Pdf.set_fill_color(:black)
    |> Pdf.text_at({280, 480}, "Rotated rectangle (30 deg)")
    # Scale demo
    |> Pdf.save_state()
    |> Pdf.translate({50, 400})
    |> Pdf.scale({2, 0.5})
    |> Pdf.set_stroke_color(:red)
    |> Pdf.set_line_width(1)
    |> Pdf.rectangle({0, 0}, {50, 50})
    |> Pdf.stroke()
    |> Pdf.restore_state()
    |> Pdf.set_fill_color(:black)
    |> Pdf.text_at({50, 380}, "Scaled rectangle (2x width, 0.5x height)")
    # Watermark-style rotated text with opacity
    |> Pdf.save_state()
    |> Pdf.set_fill_opacity(0.15)
    |> Pdf.set_fill_color(:gray)
    |> Pdf.set_font("Helvetica", 60, bold: true)
    |> Pdf.translate({150, 300})
    |> Pdf.rotate(45)
    |> Pdf.text_at({0, 0}, "WATERMARK")
    |> Pdf.restore_state()
    |> Pdf.write_to(file_path)

    assert File.exists?(file_path)
    if @open, do: System.cmd("open", ["-g", file_path])
  end
end
