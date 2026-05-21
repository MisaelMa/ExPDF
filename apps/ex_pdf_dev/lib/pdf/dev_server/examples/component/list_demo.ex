defmodule Pdf.DevServer.Examples.Component.ListDemo do
  @moduledoc false

  def render do
    dark = {0.1, 0.1, 0.1}
    accent = {0.0, 0.45, 0.75}
    gray = {0.45, 0.45, 0.45}

    doc =
      Pdf.new(size: :a4, margin: 40)
      |> Pdf.set_font("Helvetica", 24)
      |> Pdf.set_fill_color(dark)
      |> Pdf.text_at({40, 780}, "List Component", %{bold: true})
      |> Pdf.set_font("Helvetica", 10)
      |> Pdf.set_fill_color(gray)
      |> Pdf.text_at({40, 764}, "Bulleted and numbered lists with nesting support")

    # ── Bullet list ──
    doc =
      doc
      |> Pdf.set_font("Helvetica", 12)
      |> Pdf.set_fill_color(accent)
      |> Pdf.text_at({40, 730}, "Bullet List", %{bold: true})
      |> Pdf.Component.List.render({50, 710}, %{}, [
        "First item in the list",
        "Second item with more detail",
        {:nested, [
          "Nested sub-item A",
          "Nested sub-item B",
          {:nested, ["Deeply nested item"]}
        ]},
        "Third item back at root level",
        "Fourth and final item"
      ])

    # ── Numbered list ──
    doc =
      doc
      |> Pdf.set_font("Helvetica", 12)
      |> Pdf.set_fill_color(accent)
      |> Pdf.text_at({40, 580}, "Numbered List", %{bold: true})
      |> Pdf.Component.List.render({50, 560}, %{type: :numbered}, [
        "Preheat oven to 350°F",
        "Mix dry ingredients",
        {:nested, [
          "2 cups flour",
          "1 tsp baking soda",
          "1/2 tsp salt"
        ]},
        "Combine wet ingredients",
        "Fold together and pour into pan",
        "Bake for 25 minutes"
      ])

    # ── Styled list ──
    doc
    |> Pdf.set_font("Helvetica", 12)
    |> Pdf.set_fill_color(accent)
    |> Pdf.text_at({40, 410}, "Custom Styled", %{bold: true})
    |> Pdf.Component.List.render({50, 390}, %{
      color: {0.2, 0.2, 0.5},
      marker_color: accent,
      font_size: 11,
      line_height: 18
    }, [
      "Custom colored markers",
      "Larger font size and spacing",
      {:nested, ["Nested items inherit styling"]},
      "Clean and professional look"
    ])
  end
end
