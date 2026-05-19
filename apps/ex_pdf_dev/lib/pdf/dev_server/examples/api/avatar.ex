defmodule Pdf.DevServer.Examples.Api.Avatar do
  @moduledoc false
  alias Pdf.Component.Avatar

  def render do
    doc = Pdf.new(size: :a4, margin: 50, compress: false)
    |> Pdf.set_info(title: "Avatar Component")
    |> Pdf.set_font("Helvetica", 12)

    # ── Title ──
    doc = doc
    |> Pdf.set_font("Helvetica", 24)
    |> Pdf.text_at({50, 780}, "Avatar Component")
    |> Pdf.set_font("Helvetica", 11)
    |> Pdf.set_fill_color({0.4, 0.4, 0.4})
    |> Pdf.text_at({50, 762}, "Circular avatars with initials, border, and elevation (box-shadow)")
    |> Pdf.set_fill_color(:black)

    # ── Section 1: Basic Avatars ──
    doc = doc
    |> Pdf.set_font("Helvetica", 14)
    |> Pdf.text_at({50, 720}, "Basic Avatars")
    |> Pdf.set_font("Helvetica", 9)
    |> Pdf.set_fill_color({0.5, 0.5, 0.5})
    |> Pdf.text_at({50, 706}, "Default circular shape with initials and custom backgrounds")
    |> Pdf.set_fill_color(:black)

    doc = doc
    |> Avatar.render({60, 695}, %{size: 48, initials: "AM", background: {0.23, 0.53, 0.88}})
    |> Avatar.render({120, 695}, %{size: 48, initials: "JS", background: {0.85, 0.26, 0.33}})
    |> Avatar.render({180, 695}, %{size: 48, initials: "RG", background: {0.18, 0.72, 0.45}})
    |> Avatar.render({240, 695}, %{size: 48, initials: "K", background: {0.56, 0.27, 0.78}})
    |> Avatar.render({300, 695}, %{size: 48, initials: "TW", background: {0.95, 0.55, 0.0}})

    # Labels
    doc = doc
    |> Pdf.set_font("Helvetica", 7)
    |> Pdf.set_fill_color({0.5, 0.5, 0.5})
    |> Pdf.text_at({68, 640}, "AM")
    |> Pdf.text_at({130, 640}, "JS")
    |> Pdf.text_at({189, 640}, "RG")
    |> Pdf.text_at({253, 640}, "K")
    |> Pdf.text_at({310, 640}, "TW")
    |> Pdf.set_fill_color(:black)

    # ── Section 2: Sizes ──
    doc = doc
    |> Pdf.set_font("Helvetica", 14)
    |> Pdf.text_at({50, 615}, "Sizes")
    |> Pdf.set_font("Helvetica", 9)
    |> Pdf.set_fill_color({0.5, 0.5, 0.5})
    |> Pdf.text_at({50, 601}, "size: 24, 32, 40, 48, 64, 80")
    |> Pdf.set_fill_color(:black)

    sizes = [24, 32, 40, 48, 64, 80]
    bg = {0.23, 0.53, 0.88}
    y_sizes = 590

    {doc, _x} = Enum.reduce(sizes, {doc, 60}, fn s, {d, x} ->
      d = Avatar.render(d, {x, y_sizes}, %{size: s, initials: "#{s}", background: bg, color: :white})
      {d, x + s + 15}
    end)

    # ── Section 3: Border Radius Variants ──
    doc = doc
    |> Pdf.set_font("Helvetica", 14)
    |> Pdf.text_at({50, 490}, "Border Radius")
    |> Pdf.set_font("Helvetica", 9)
    |> Pdf.set_fill_color({0.5, 0.5, 0.5})
    |> Pdf.text_at({50, 476}, ":circle (default)  |  :rounded  |  numeric (8)")
    |> Pdf.set_fill_color(:black)

    doc = doc
    |> Avatar.render({60, 465}, %{size: 56, initials: "CI", background: {0.85, 0.26, 0.33}, border_radius: :circle})
    |> Avatar.render({130, 465}, %{size: 56, initials: "RD", background: {0.18, 0.72, 0.45}, border_radius: :rounded})
    |> Avatar.render({200, 465}, %{size: 56, initials: "N8", background: {0.56, 0.27, 0.78}, border_radius: 8})

    doc = doc
    |> Pdf.set_font("Helvetica", 8)
    |> Pdf.set_fill_color({0.5, 0.5, 0.5})
    |> Pdf.text_at({65, 400}, ":circle")
    |> Pdf.text_at({130, 400}, ":rounded")
    |> Pdf.text_at({208, 400}, "8")
    |> Pdf.set_fill_color(:black)

    # ── Section 4: Borders ──
    doc = doc
    |> Pdf.set_font("Helvetica", 14)
    |> Pdf.text_at({50, 375}, "Borders")
    |> Pdf.set_font("Helvetica", 9)
    |> Pdf.set_fill_color({0.5, 0.5, 0.5})
    |> Pdf.text_at({50, 361}, "border: 2 with different border_color values")
    |> Pdf.set_fill_color(:black)

    doc = doc
    |> Avatar.render({60, 350}, %{size: 56, initials: "WH", background: {0.23, 0.53, 0.88}, border: 2, border_color: :white})
    |> Avatar.render({130, 350}, %{size: 56, initials: "BK", background: {0.95, 0.55, 0.0}, border: 2, border_color: :black})
    |> Avatar.render({200, 350}, %{size: 56, initials: "RD", background: {0.18, 0.72, 0.45}, border: 3, border_color: {0.85, 0.26, 0.33}})
    |> Avatar.render({270, 350}, %{size: 56, initials: "TK", background: {0.12, 0.12, 0.12}, border: 2, border_color: {0.95, 0.75, 0.0}})

    # ── Section 5: Elevation / Box Shadow ──
    doc = doc
    |> Pdf.set_font("Helvetica", 14)
    |> Pdf.text_at({50, 270}, "Elevation (Box Shadow)")
    |> Pdf.set_font("Helvetica", 9)
    |> Pdf.set_fill_color({0.5, 0.5, 0.5})
    |> Pdf.text_at({50, 256}, "elevation: 0 through 5 — Material UI-style shadow depth")
    |> Pdf.set_fill_color(:black)

    {doc, _x} = Enum.reduce(0..5, {doc, 60}, fn elev, {d, x} ->
      d = Avatar.render(d, {x, 245}, %{
        size: 56,
        initials: "E#{elev}",
        background: {0.96, 0.96, 0.96},
        color: {0.2, 0.2, 0.2},
        elevation: elev,
        border: 1,
        border_color: {0.88, 0.88, 0.88}
      })
      {d, x + 75}
    end)

    doc = doc
    |> Pdf.set_font("Helvetica", 7)
    |> Pdf.set_fill_color({0.5, 0.5, 0.5})

    {doc, _x} = Enum.reduce(0..5, {doc, 60}, fn elev, {d, x} ->
      d = Pdf.text_at(d, {x + 15, 182}, "elev: #{elev}")
      {d, x + 75}
    end)

    # ── Section 6: Group / Row ──
    doc = doc
    |> Pdf.set_fill_color(:black)
    |> Pdf.set_font("Helvetica", 14)
    |> Pdf.text_at({50, 155}, "Avatar Group")
    |> Pdf.set_font("Helvetica", 9)
    |> Pdf.set_fill_color({0.5, 0.5, 0.5})
    |> Pdf.text_at({50, 141}, "Overlapping avatars with white border (like team member lists)")
    |> Pdf.set_fill_color(:black)

    colors = [
      {0.23, 0.53, 0.88},
      {0.85, 0.26, 0.33},
      {0.18, 0.72, 0.45},
      {0.56, 0.27, 0.78},
      {0.95, 0.55, 0.0}
    ]
    names = ["AM", "JS", "RG", "KP", "+3"]

    {doc, _x} = Enum.zip(names, colors) |> Enum.reduce({doc, 60}, fn {name, bg}, {d, x} ->
      d = Avatar.render(d, {x, 130}, %{
        size: 40,
        initials: name,
        background: bg,
        border: 2,
        border_color: :white,
        elevation: 1
      })
      {d, x + 30}
    end)

    doc
  end
end
