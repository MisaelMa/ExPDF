defmodule Pdf.DevServer.Examples.Api.ImageBackground do
  @moduledoc false

  def render do
    dark = {0.15, 0.15, 0.15}
    white = {1.0, 1.0, 1.0}

    # Generate a subtle pattern image for the background
    pattern = make_dot_pattern(595, 842, 20)

    doc =
      Pdf.new(size: :a4, margin: %{top: 0, bottom: 0, left: 0, right: 0})
      |> Pdf.set_info(title: "Image Background")

    # ── Page 1: Full-page image background ──
    doc =
      doc
      |> Pdf.add_image({0, 0}, {:binary, pattern}, width: 595, height: 842)

    # Overlay a white card on top
    doc =
      doc
      |> Pdf.save_state()
      |> Pdf.set_fill_color(white)
      |> Pdf.set_fill_opacity(0.92)
      |> Pdf.rectangle({60, 300}, {475, 280})
      |> Pdf.fill()
      |> Pdf.restore_state()

    # Card border
    doc =
      doc
      |> Pdf.save_state()
      |> Pdf.set_stroke_color({0.8, 0.8, 0.8})
      |> Pdf.set_line_width(0.5)
      |> Pdf.rectangle({60, 300}, {475, 280})
      |> Pdf.stroke()
      |> Pdf.restore_state()

    # Text on the card
    doc =
      doc
      |> Pdf.set_font("Helvetica", 28)
      |> Pdf.set_fill_color(dark)
      |> Pdf.text_at({85, 545}, "Image as Page Background", %{bold: true})
      |> Pdf.set_font("Helvetica", 12)
      |> Pdf.set_fill_color({0.4, 0.4, 0.4})
      |> Pdf.text_at({85, 518}, "The entire page has a dot-pattern PNG rendered behind all content.")
      |> Pdf.text_at({85, 500}, "The white card uses fill_opacity to let the pattern peek through.")
      |> Pdf.set_font("Courier", 10)
      |> Pdf.set_fill_color(dark)
      |> Pdf.text_at({85, 470}, "# Render image at full page size, positioned at origin:")
      |> Pdf.text_at({85, 455}, "Pdf.add_image(doc, {0, 0}, {:binary, png},")
      |> Pdf.text_at({85, 440}, "              width: 595, height: 842)")
      |> Pdf.set_font("Helvetica", 10)
      |> Pdf.set_fill_color({0.4, 0.4, 0.4})
      |> Pdf.text_at({85, 415}, "Works with any PNG or JPEG — photos, textures, branded templates.")

    # Footer label
    doc =
      doc
      |> Pdf.set_font("Helvetica", 9)
      |> Pdf.set_fill_color({0.5, 0.5, 0.5})
      |> Pdf.text_at({85, 320}, "Tip: use Pdf.on_page(:background, fn doc, _ -> ... end) to auto-apply on every page.")

    # ── Page 2: Gradient background with overlay text ──
    gradient = make_vertical_gradient(595, 842, {30, 60, 120}, {200, 220, 255})

    doc =
      doc
      |> Pdf.add_page(:a4)
      |> Pdf.add_image({0, 0}, {:binary, gradient}, width: 595, height: 842)

    # White text on dark gradient
    doc =
      doc
      |> Pdf.set_font("Helvetica", 32)
      |> Pdf.set_fill_color(white)
      |> Pdf.text_at({80, 500}, "Gradient Background", %{bold: true})
      |> Pdf.set_font("Helvetica", 14)
      |> Pdf.set_fill_color({0.85, 0.9, 1.0})
      |> Pdf.text_at({80, 470}, "A vertical gradient PNG generated in Elixir,")
      |> Pdf.text_at({80, 452}, "rendered as a full-page background image.")

    # Semi-transparent box
    doc =
      doc
      |> Pdf.save_state()
      |> Pdf.set_fill_color(white)
      |> Pdf.set_fill_opacity(0.15)
      |> Pdf.rectangle({60, 200}, {475, 200})
      |> Pdf.fill()
      |> Pdf.restore_state()

    doc =
      doc
      |> Pdf.set_font("Courier", 10)
      |> Pdf.set_fill_color(white)
      |> Pdf.text_at({80, 375}, "# Gradient background on every page:")
      |> Pdf.text_at({80, 358}, "gradient = make_gradient(595, 842)")
      |> Pdf.text_at({80, 341}, "")
      |> Pdf.text_at({80, 324}, "Pdf.on_page(:background, fn doc, _info ->")
      |> Pdf.text_at({80, 307}, "  Pdf.add_image(doc, {0, 0}, {:binary, gradient},")
      |> Pdf.text_at({80, 290}, "                width: 595, height: 842)")
      |> Pdf.text_at({80, 273}, "end)")

    doc
  end

  # ---------------------------------------------------------------------------
  # PNG generators
  # ---------------------------------------------------------------------------

  defp make_dot_pattern(w, h, spacing) do
    rows =
      for y <- 0..(h - 1), into: <<>> do
        row =
          for x <- 0..(w - 1), into: <<>> do
            dx = rem(x, spacing) - div(spacing, 2)
            dy = rem(y, spacing) - div(spacing, 2)
            dist = :math.sqrt(dx * dx + dy * dy)

            if dist < 2.5 do
              <<190, 200, 210>>
            else
              <<240, 242, 245>>
            end
          end
        <<0, row::binary>>
      end

    encode_png(w, h, rows)
  end

  defp make_vertical_gradient(w, h, {r1, g1, b1}, {r2, g2, b2}) do
    rows =
      for y <- 0..(h - 1), into: <<>> do
        t = y / max(h - 1, 1)
        r = trunc(r1 + (r2 - r1) * t)
        g = trunc(g1 + (g2 - g1) * t)
        b = trunc(b1 + (b2 - b1) * t)
        pixel = <<r, g, b>>
        <<0, :binary.copy(pixel, w)::binary>>
      end

    encode_png(w, h, rows)
  end

  defp encode_png(w, h, raw_pixels) do
    signature = <<137, 80, 78, 71, 13, 10, 26, 10>>
    ihdr = chunk("IHDR", <<w::32, h::32, 8, 2, 0, 0, 0>>)
    idat = chunk("IDAT", zlib_deflate(raw_pixels))
    iend = chunk("IEND", <<>>)
    signature <> ihdr <> idat <> iend
  end

  defp chunk(type, data) do
    payload = <<type::binary, data::binary>>
    <<byte_size(data)::32, payload::binary, :erlang.crc32(payload)::32>>
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
