defmodule Pdf.DevServer.Examples.Api.ImageShowcase do
  @moduledoc false

  def render do
    dark = {0.1, 0.1, 0.1}
    gray = {0.45, 0.45, 0.45}
    accent = {0.0, 0.45, 0.75}
    light_bg = {0.96, 0.96, 0.98}

    # Generate sample images as in-memory PNG binaries
    red_png = make_solid_png(80, 60, {220, 60, 60})
    blue_png = make_solid_png(80, 60, {40, 100, 200})
    green_png = make_solid_png(80, 60, {50, 180, 80})
    gradient_png = make_gradient_png(120, 80)
    checker_png = make_checker_png(80, 80, 10)

    doc =
      Pdf.new(size: :a4, margin: 40)
      |> Pdf.set_info(title: "Image Showcase")

    # ── Title ──
    doc =
      doc
      |> Pdf.set_font("Helvetica", 24)
      |> Pdf.set_fill_color(dark)
      |> Pdf.text_at({40, 780}, "Image Types & Placement", %{bold: true})
      |> Pdf.set_font("Helvetica", 10)
      |> Pdf.set_fill_color(gray)
      |> Pdf.text_at({40, 764}, "ExPDF supports PNG and JPEG images — from files or in-memory binary data.")

    # ── Section 1: Basic PNG Images ──
    doc =
      doc
      |> Pdf.set_font("Helvetica", 14)
      |> Pdf.set_fill_color(accent)
      |> Pdf.text_at({40, 730}, "PNG — Solid Colors (in-memory binary)", %{bold: true})
      |> Pdf.set_font("Helvetica", 9)
      |> Pdf.set_fill_color(gray)
      |> Pdf.text_at({40, 716}, "Generated as raw PNG bytes with :zlib, passed via {:binary, data}")

    # Red
    doc =
      doc
      |> Pdf.add_image({50, 640}, {:binary, red_png})
      |> Pdf.set_font("Helvetica", 9)
      |> Pdf.set_fill_color(dark)
      |> Pdf.text_at({55, 635}, "80×60 Red")

    # Blue
    doc =
      doc
      |> Pdf.add_image({180, 640}, {:binary, blue_png})
      |> Pdf.set_font("Helvetica", 9)
      |> Pdf.text_at({185, 635}, "80×60 Blue")

    # Green
    doc =
      doc
      |> Pdf.add_image({310, 640}, {:binary, green_png})
      |> Pdf.set_font("Helvetica", 9)
      |> Pdf.text_at({315, 635}, "80×60 Green")

    # ── Section 2: Patterns ──
    doc =
      doc
      |> Pdf.set_font("Helvetica", 14)
      |> Pdf.set_fill_color(accent)
      |> Pdf.text_at({40, 610}, "PNG — Patterns (generated)", %{bold: true})

    doc =
      doc
      |> Pdf.add_image({50, 510}, {:binary, gradient_png})
      |> Pdf.set_font("Helvetica", 9)
      |> Pdf.set_fill_color(dark)
      |> Pdf.text_at({55, 505}, "120×80 Gradient")
      |> Pdf.add_image({220, 510}, {:binary, checker_png})
      |> Pdf.set_font("Helvetica", 9)
      |> Pdf.text_at({225, 505}, "80×80 Checkerboard")

    # ── Section 3: Scaling ──
    doc =
      doc
      |> Pdf.set_font("Helvetica", 14)
      |> Pdf.set_fill_color(accent)
      |> Pdf.text_at({40, 480}, "Image Scaling", %{bold: true})
      |> Pdf.set_font("Helvetica", 9)
      |> Pdf.set_fill_color(gray)
      |> Pdf.text_at({40, 466}, "Same 80×60 image rendered at different sizes using :width and :height options")

    scales = [
      {50, "40×30", [width: 40, height: 30]},
      {120, "80×60 (original)", []},
      {230, "160×120", [width: 160, height: 120]},
    ]

    doc =
      Enum.reduce(scales, doc, fn {x, label, opts}, d ->
        d
        |> Pdf.add_image({x, 370}, {:binary, blue_png}, opts)
        |> Pdf.set_font("Helvetica", 8)
        |> Pdf.set_fill_color(dark)
        |> Pdf.text_at({x, 362}, label)
      end)

    # ── Section 4: Aspect Ratio ──
    doc =
      doc
      |> Pdf.set_font("Helvetica", 14)
      |> Pdf.set_fill_color(accent)
      |> Pdf.text_at({40, 340}, "Width-only / Height-only Scaling", %{bold: true})
      |> Pdf.set_font("Helvetica", 9)
      |> Pdf.set_fill_color(gray)
      |> Pdf.text_at({40, 326}, "Specify only width or height — the image stretches to that dimension")

    doc =
      doc
      |> Pdf.add_image({50, 240}, {:binary, red_png}, width: 200)
      |> Pdf.set_font("Helvetica", 8)
      |> Pdf.set_fill_color(dark)
      |> Pdf.text_at({55, 234}, "width: 200 (stretched)")
      |> Pdf.add_image({300, 240}, {:binary, red_png}, height: 100)
      |> Pdf.set_font("Helvetica", 8)
      |> Pdf.text_at({305, 234}, "height: 100 (stretched)")

    # ── Code hint ──
    doc =
      doc
      |> Pdf.save_state()
      |> Pdf.set_fill_color(light_bg)
      |> Pdf.rectangle({40, 80}, {515, 100})
      |> Pdf.fill()
      |> Pdf.restore_state()
      |> Pdf.set_font("Courier", 9)
      |> Pdf.set_fill_color(dark)
      |> Pdf.text_at({55, 165}, "# From file path:")
      |> Pdf.text_at({55, 152}, "Pdf.add_image(doc, {x, y}, \"photo.png\")")
      |> Pdf.text_at({55, 135}, "# From binary data:")
      |> Pdf.text_at({55, 122}, "Pdf.add_image(doc, {x, y}, {:binary, png_bytes})")
      |> Pdf.text_at({55, 105}, "# Scaled:")
      |> Pdf.text_at({55, 92}, "Pdf.add_image(doc, {x, y}, path, width: 200, height: 150)")

    doc
  end

  # ---------------------------------------------------------------------------
  # PNG generators — produce valid in-memory PNG binary data
  # ---------------------------------------------------------------------------

  defp make_solid_png(w, h, {r, g, b}) do
    row = <<0>> <> :binary.copy(<<r, g, b>>, w)
    raw = :binary.copy(row, h)
    encode_png(w, h, raw)
  end

  defp make_gradient_png(w, h) do
    rows =
      for y <- 0..(h - 1), into: <<>> do
        row =
          for x <- 0..(w - 1), into: <<>> do
            r = trunc(x / w * 255)
            g = trunc(y / h * 255)
            b = 180
            <<r, g, b>>
          end
        <<0, row::binary>>
      end
    encode_png(w, h, rows)
  end

  defp make_checker_png(w, h, cell) do
    rows =
      for y <- 0..(h - 1), into: <<>> do
        row =
          for x <- 0..(w - 1), into: <<>> do
            if rem(div(x, cell) + div(y, cell), 2) == 0 do
              <<230, 230, 230>>
            else
              <<80, 80, 80>>
            end
          end
        <<0, row::binary>>
      end
    encode_png(w, h, rows)
  end

  defp encode_png(w, h, raw_pixels) do
    signature = <<137, 80, 78, 71, 13, 10, 26, 10>>

    ihdr_data = <<w::32, h::32, 8, 2, 0, 0, 0>>
    ihdr = chunk("IHDR", ihdr_data)

    compressed = zlib_deflate(raw_pixels)
    idat = chunk("IDAT", compressed)

    iend = chunk("IEND", <<>>)

    signature <> ihdr <> idat <> iend
  end

  defp chunk(type, data) do
    payload = <<type::binary, data::binary>>
    crc = :erlang.crc32(payload)
    <<byte_size(data)::32, payload::binary, crc::32>>
  end

  defp zlib_deflate(data) do
    z = :zlib.open()
    :zlib.deflateInit(z)
    compressed = :zlib.deflate(z, data, :finish)
    :zlib.deflateEnd(z)
    :zlib.close(z)
    IO.iodata_to_binary(compressed)
  end
end
