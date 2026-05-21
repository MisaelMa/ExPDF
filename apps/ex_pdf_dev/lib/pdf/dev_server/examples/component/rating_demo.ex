defmodule Pdf.DevServer.Examples.Component.RatingDemo do
  @moduledoc false

  def render do
    dark = {0.1, 0.1, 0.1}
    accent = {0.0, 0.45, 0.75}
    gray = {0.45, 0.45, 0.45}

    doc =
      Pdf.new(size: :a4, margin: 40)
      |> Pdf.set_font("Helvetica", 24)
      |> Pdf.set_fill_color(dark)
      |> Pdf.text_at({40, 780}, "Rating Component", %{bold: true})
      |> Pdf.set_font("Helvetica", 10)
      |> Pdf.set_fill_color(gray)
      |> Pdf.text_at({40, 764}, "Star/score ratings with filled and empty indicators")

    # ── Different values ──
    doc =
      doc
      |> Pdf.set_font("Helvetica", 12)
      |> Pdf.set_fill_color(accent)
      |> Pdf.text_at({40, 730}, "Different Values", %{bold: true})
      |> Pdf.set_font("Helvetica", 10)
      |> Pdf.set_fill_color(gray)
      |> Pdf.text_at({50, 710}, "1/5:")
      |> Pdf.Component.Rating.render({90, 712}, %{value: 1, max: 5})
      |> Pdf.text_at({50, 690}, "2/5:")
      |> Pdf.Component.Rating.render({90, 692}, %{value: 2, max: 5})
      |> Pdf.text_at({50, 670}, "3/5:")
      |> Pdf.Component.Rating.render({90, 672}, %{value: 3, max: 5})
      |> Pdf.text_at({50, 650}, "4/5:")
      |> Pdf.Component.Rating.render({90, 652}, %{value: 4, max: 5})
      |> Pdf.text_at({50, 630}, "5/5:")
      |> Pdf.Component.Rating.render({90, 632}, %{value: 5, max: 5})

    # ── With labels ──
    doc =
      doc
      |> Pdf.set_font("Helvetica", 12)
      |> Pdf.set_fill_color(accent)
      |> Pdf.text_at({40, 600}, "With Labels", %{bold: true})
      |> Pdf.Component.Rating.render({50, 580}, %{value: 4, max: 5, show_label: true})
      |> Pdf.Component.Rating.render({50, 556}, %{value: 3.5, max: 5, show_label: true})

    # ── Different sizes ──
    doc =
      doc
      |> Pdf.set_font("Helvetica", 12)
      |> Pdf.set_fill_color(accent)
      |> Pdf.text_at({40, 520}, "Sizes", %{bold: true})
      |> Pdf.Component.Rating.render({50, 500}, %{value: 4, max: 5, size: 10, show_label: true})
      |> Pdf.Component.Rating.render({50, 476}, %{value: 4, max: 5, size: 16, show_label: true})
      |> Pdf.Component.Rating.render({50, 448}, %{value: 4, max: 5, size: 22, show_label: true})

    # ── Custom colors ──
    doc =
      doc
      |> Pdf.set_font("Helvetica", 12)
      |> Pdf.set_fill_color(accent)
      |> Pdf.text_at({40, 400}, "Custom Colors", %{bold: true})
      |> Pdf.Component.Rating.render({50, 380}, %{
        value: 4, max: 5,
        filled_color: {0.85, 0.2, 0.2},
        show_label: true
      })
      |> Pdf.Component.Rating.render({50, 356}, %{
        value: 3, max: 5,
        filled_color: {0.2, 0.6, 0.8},
        show_label: true
      })
      |> Pdf.Component.Rating.render({50, 332}, %{
        value: 5, max: 5,
        filled_color: {0.2, 0.7, 0.3},
        show_label: true
      })

    # ── 10-point scale ──
    doc
    |> Pdf.set_font("Helvetica", 12)
    |> Pdf.set_fill_color(accent)
    |> Pdf.text_at({40, 290}, "10-Point Scale", %{bold: true})
    |> Pdf.Component.Rating.render({50, 270}, %{
      value: 7, max: 10, size: 12, show_label: true
    })
  end
end
