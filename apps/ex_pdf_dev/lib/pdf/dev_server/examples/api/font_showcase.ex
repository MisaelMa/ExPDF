defmodule Pdf.DevServer.Examples.Api.FontShowcase do
  @moduledoc false

  def render do
    dark = {0.1, 0.1, 0.1}
    gray = {0.45, 0.45, 0.45}
    accent = {0.0, 0.45, 0.75}
    light_bg = {0.96, 0.96, 0.98}

    doc =
      Pdf.new(size: :a4, margin: 40)
      |> Pdf.set_info(title: "Font Showcase")

    # Title
    doc =
      doc
      |> Pdf.set_font("Helvetica", 24)
      |> Pdf.set_fill_color(dark)
      |> Pdf.text_at({40, 780}, "Built-in Font Families", %{bold: true})
      |> Pdf.set_font("Helvetica", 10)
      |> Pdf.set_fill_color(gray)
      |> Pdf.text_at({40, 764}, "PDF spec provides 14 standard fonts — no embedding required.")

    # ── Helvetica Family ──
    doc = render_family(doc, 720, "Helvetica", accent, dark, light_bg)

    # ── Courier Family ──
    doc = render_family(doc, 560, "Courier", accent, dark, light_bg)

    # ── Times Family ──
    doc = render_family(doc, 400, "Times", accent, dark, light_bg)

    # ── Symbol & ZapfDingbats ──
    y = 270
    doc =
      doc
      |> Pdf.set_font("Helvetica", 14)
      |> Pdf.set_fill_color(accent)
      |> Pdf.text_at({40, y}, "Special Fonts", %{bold: true})

    # Symbol
    doc =
      doc
      |> Pdf.save_state()
      |> Pdf.set_fill_color(light_bg)
      |> Pdf.rectangle({40, y - 55}, {515, 40})
      |> Pdf.fill()
      |> Pdf.restore_state()
      |> Pdf.set_font("Helvetica", 10)
      |> Pdf.set_fill_color(gray)
      |> Pdf.text_at({50, y - 28}, "Symbol:")
      |> Pdf.set_font("Symbol", 14)
      |> Pdf.set_fill_color(dark)
      |> Pdf.text_at({110, y - 28}, "abgdezhqiklmnxoprstufcyw ABGDEZHQ")
      |> Pdf.set_font("Helvetica", 8)
      |> Pdf.set_fill_color(gray)
      |> Pdf.text_at({50, y - 44}, "Greek letters mapped from ASCII: a=alpha, b=beta, g=gamma, d=delta ...")

    # ZapfDingbats
    doc =
      doc
      |> Pdf.save_state()
      |> Pdf.set_fill_color(light_bg)
      |> Pdf.rectangle({40, y - 105}, {515, 40})
      |> Pdf.fill()
      |> Pdf.restore_state()
      |> Pdf.set_font("Helvetica", 10)
      |> Pdf.set_fill_color(gray)
      |> Pdf.text_at({50, y - 78}, "ZapfDingbats:")
      |> Pdf.set_font("ZapfDingbats", 14)
      |> Pdf.set_fill_color(dark)
      |> Pdf.text_at({140, y - 78}, "#$%&()*+,-./0123456789")
      |> Pdf.set_font("Helvetica", 8)
      |> Pdf.set_fill_color(gray)
      |> Pdf.text_at({50, y - 94}, "Decorative symbols via ASCII codes: scissors, stars, crosses, circles")

    # ── Font Sizes Comparison ──
    y2 = 130
    doc =
      doc
      |> Pdf.set_font("Helvetica", 14)
      |> Pdf.set_fill_color(accent)
      |> Pdf.text_at({40, y2}, "Size Comparison", %{bold: true})

    sizes = [8, 10, 12, 14, 18, 24]
    Enum.reduce(sizes, {doc, 50}, fn size, {d, x} ->
      label = "#{size}pt"
      d =
        d
        |> Pdf.set_font("Helvetica", size)
        |> Pdf.set_fill_color(dark)
        |> Pdf.text_at({x, y2 - 30}, label)
      {d, x + size * 3.5 + 10}
    end)
    |> elem(0)
  end

  defp render_family(doc, y, family_name, accent, dark, light_bg) do
    doc =
      doc
      |> Pdf.set_font("Helvetica", 14)
      |> Pdf.set_fill_color(accent)
      |> Pdf.text_at({40, y}, "#{family_name} Family", %{bold: true})

    variants = [
      {"Regular", []},
      {"Bold", [bold: true]},
      {"Italic", [italic: true]},
      {"Bold Italic", [bold: true, italic: true]}
    ]

    # Use the correct family name for Times
    font_name = if family_name == "Times", do: "Times", else: family_name

    Enum.with_index(variants)
    |> Enum.reduce(doc, fn {{label, opts}, i}, d ->
      row_y = y - 30 - i * 34

      d
      |> Pdf.save_state()
      |> Pdf.set_fill_color(if(rem(i, 2) == 0, do: light_bg, else: {1.0, 1.0, 1.0}))
      |> Pdf.rectangle({40, row_y - 10}, {515, 30})
      |> Pdf.fill()
      |> Pdf.restore_state()
      |> Pdf.set_font("Helvetica", 9)
      |> Pdf.set_fill_color({0.55, 0.55, 0.55})
      |> Pdf.text_at({50, row_y + 4}, label)
      |> Pdf.set_font(font_name, 16, opts)
      |> Pdf.set_fill_color(dark)
      |> Pdf.text_at({160, row_y + 4}, "The quick brown fox jumps over the lazy dog")
    end)
  end
end
