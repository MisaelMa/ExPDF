defmodule Pdf.DevServer.Examples.Api.ComponentsShowcase do
  @moduledoc false

  alias Pdf.Component.{Avatar, Badge, Card, Chip, Divider, Progress}

  def render do
    blue = {0.23, 0.53, 0.88}
    red = {0.85, 0.26, 0.33}
    green = {0.18, 0.72, 0.45}
    purple = {0.56, 0.27, 0.78}
    orange = {0.95, 0.55, 0.0}
    gray = {0.5, 0.5, 0.5}
    light_gray = {0.85, 0.85, 0.85}

    doc = Pdf.new(size: :a4, margin: 50, compress: false)
    |> Pdf.set_info(title: "Components Showcase")
    |> Pdf.set_font("Helvetica", 12)

    # ── Title ──
    doc = doc
    |> Pdf.set_font("Helvetica", 22, bold: true)
    |> Pdf.text_at({50, 780}, "Components Showcase")
    |> Pdf.set_font("Helvetica", 9)
    |> Pdf.set_fill_color(gray)
    |> Pdf.text_at({50, 766}, "Divider \u2022 Badge \u2022 Chip \u2022 Progress \u2022 Card")
    |> Pdf.set_fill_color(:black)

    # ═══════════════════════════════════════════════════════════
    # DIVIDER
    # ═══════════════════════════════════════════════════════════
    doc = doc
    |> Pdf.set_font("Helvetica", 14, bold: true)
    |> Pdf.text_at({50, 735}, "Divider")
    |> Pdf.set_font("Helvetica", 9)
    |> Pdf.set_fill_color(gray)
    |> Pdf.text_at({50, 722}, "Horizontal and vertical separators with solid/dashed styles")
    |> Pdf.set_fill_color(:black)

    # Solid dividers with different colors
    doc = doc
    |> Divider.render({50, 710}, %{width: 450, color: light_gray})
    |> Divider.render({50, 700}, %{width: 450, color: blue, thickness: 1})
    |> Divider.render({50, 690}, %{width: 450, color: red, thickness: 1.5})

    # Dashed
    doc = doc
    |> Pdf.set_font("Helvetica", 8)
    |> Pdf.text_at({50, 678}, "dashed:")
    |> Divider.render({90, 678}, %{width: 410, style: :dashed, color: gray})

    doc = doc
    |> Pdf.text_at({50, 666}, "custom dash:")
    |> Divider.render({110, 666}, %{width: 390, style: :dashed, dash: {8, 3}, color: blue, thickness: 1})

    # Vertical
    doc = doc
    |> Pdf.text_at({50, 654}, "vertical:")
    |> Divider.render({110, 654}, %{height: 30, orientation: :vertical, color: red, thickness: 1})
    |> Divider.render({120, 654}, %{height: 30, orientation: :vertical, style: :dashed, color: green})
    |> Divider.render({130, 654}, %{height: 30, orientation: :vertical, color: purple, thickness: 2})

    # ═══════════════════════════════════════════════════════════
    # BADGE
    # ═══════════════════════════════════════════════════════════
    doc = doc
    |> Pdf.set_font("Helvetica", 14, bold: true)
    |> Pdf.text_at({50, 605}, "Badge")
    |> Pdf.set_font("Helvetica", 9)
    |> Pdf.set_fill_color(gray)
    |> Pdf.text_at({50, 592}, "Dot, standard (circle), and pill variants")
    |> Pdf.set_fill_color(:black)

    # Dot badges
    doc = doc
    |> Pdf.set_font("Helvetica", 8)
    |> Pdf.text_at({50, 575}, "dot:")
    |> Badge.render({90, 575}, %{variant: :dot, size: 10})
    |> Badge.render({110, 575}, %{variant: :dot, size: 10, background: green})
    |> Badge.render({130, 575}, %{variant: :dot, size: 10, background: orange})

    # Standard (circle) badges
    doc = doc
    |> Pdf.text_at({50, 555}, "standard:")
    |> Badge.render({110, 555}, %{content: "3", size: 20})
    |> Badge.render({140, 555}, %{content: "42", size: 20, background: blue})
    |> Badge.render({175, 555}, %{content: "99+", size: 24, background: purple})

    # Pill badges
    doc = doc
    |> Pdf.text_at({50, 530}, "pill:")
    |> Badge.render({105, 530}, %{content: "NEW", variant: :pill, size: 18, background: green})
    |> Badge.render({165, 530}, %{content: "SALE", variant: :pill, size: 18, background: red})
    |> Badge.render({230, 530}, %{content: "PRO", variant: :pill, size: 18, background: blue})

    # With border
    doc = doc
    |> Pdf.text_at({50, 508}, "border:")
    |> Badge.render({110, 508}, %{content: "5", size: 22, border: 2, border_color: :white})
    |> Badge.render({145, 508}, %{content: "OK", variant: :pill, size: 20, background: green, border: 1.5, border_color: :white})

    # ═══════════════════════════════════════════════════════════
    # CHIP
    # ═══════════════════════════════════════════════════════════
    doc = doc
    |> Pdf.set_font("Helvetica", 14, bold: true)
    |> Pdf.text_at({50, 478}, "Chip")
    |> Pdf.set_font("Helvetica", 9)
    |> Pdf.set_fill_color(gray)
    |> Pdf.text_at({50, 465}, "Filled and outlined tag labels")
    |> Pdf.set_fill_color(:black)

    # Filled chips
    {doc, w1} = Chip.render(doc, {50, 452}, %{label: "Elixir", background: purple, color: :white})
    {doc, w2} = Chip.render(doc, {50 + w1 + 8, 452}, %{label: "Phoenix", background: orange, color: :white})
    {doc, w3} = Chip.render(doc, {50 + w1 + w2 + 16, 452}, %{label: "LiveView", background: green, color: :white})
    {doc, _} = Chip.render(doc, {50 + w1 + w2 + w3 + 24, 452}, %{label: "OTP", background: blue, color: :white})

    # Outlined chips
    {doc, w1} = Chip.render(doc, {50, 424}, %{label: "Active", variant: :outlined, color: green})
    {doc, w2} = Chip.render(doc, {50 + w1 + 8, 424}, %{label: "Pending", variant: :outlined, color: orange})
    {doc, w3} = Chip.render(doc, {50 + w1 + w2 + 16, 424}, %{label: "Error", variant: :outlined, color: red})
    {doc, _} = Chip.render(doc, {50 + w1 + w2 + w3 + 24, 424}, %{label: "Info", variant: :outlined, color: blue})

    # Different sizes
    {doc, w1} = Chip.render(doc, {50, 398}, %{label: "Small", height: 18, font_size: 8, background: light_gray})
    {doc, w2} = Chip.render(doc, {50 + w1 + 8, 398}, %{label: "Default", background: light_gray})
    {doc, _} = Chip.render(doc, {50 + w1 + w2 + 16, 398}, %{label: "Large", height: 30, font_size: 13, background: light_gray})

    # ═══════════════════════════════════════════════════════════
    # PROGRESS
    # ═══════════════════════════════════════════════════════════
    doc = doc
    |> Pdf.set_font("Helvetica", 14, bold: true)
    |> Pdf.text_at({50, 360}, "Progress")
    |> Pdf.set_font("Helvetica", 9)
    |> Pdf.set_fill_color(gray)
    |> Pdf.text_at({50, 347}, "Horizontal progress bars with labels")
    |> Pdf.set_fill_color(:black)

    # Different values
    doc = doc
    |> Pdf.set_font("Helvetica", 8)
    |> Pdf.text_at({50, 332}, "25%")
    |> Progress.render({80, 335}, %{width: 200, value: 25, height: 8})
    |> Pdf.text_at({50, 318}, "50%")
    |> Progress.render({80, 321}, %{width: 200, value: 50, height: 8, color: orange})
    |> Pdf.text_at({50, 304}, "75%")
    |> Progress.render({80, 307}, %{width: 200, value: 75, height: 8, color: green})
    |> Pdf.text_at({50, 290}, "100%")
    |> Progress.render({80, 293}, %{width: 200, value: 100, height: 8, color: purple})

    # With labels
    doc = doc
    |> Progress.render({310, 335}, %{width: 150, value: 42, show_label: true, color: blue})
    |> Progress.render({310, 321}, %{width: 150, value: 88, show_label: true, color: green})

    # Tall bar
    doc = doc
    |> Progress.render({310, 300}, %{width: 150, value: 65, height: 16, color: red, show_label: true})

    # Square corners
    doc = doc
    |> Pdf.text_at({50, 270}, "square:")
    |> Progress.render({90, 273}, %{width: 200, value: 60, height: 10, border_radius: :square, color: blue})

    # ═══════════════════════════════════════════════════════════
    # CARD
    # ═══════════════════════════════════════════════════════════
    doc = doc
    |> Pdf.set_font("Helvetica", 14, bold: true)
    |> Pdf.text_at({50, 245}, "Card")
    |> Pdf.set_font("Helvetica", 9)
    |> Pdf.set_fill_color(gray)
    |> Pdf.text_at({50, 232}, "Card containers with header, elevation, and content callback")
    |> Pdf.set_fill_color(:black)

    # Simple card
    doc = Card.render(doc, {50, 220}, {220, 100}, %{
      elevation: 2,
      border_radius: 8,
      padding: 10
    }, fn doc, area ->
      doc
      |> Pdf.set_font("Helvetica", 11, bold: true)
      |> Pdf.text_at({area.x, area.y - 14}, "Simple Card")
      |> Pdf.set_font("Helvetica", 9)
      |> Pdf.set_fill_color(gray)
      |> Pdf.text_at({area.x, area.y - 28}, "A basic card with elevation")
      |> Pdf.text_at({area.x, area.y - 40}, "and rounded corners.")
      |> Pdf.set_fill_color(:black)
    end)

    # Card with header
    doc = Card.render(doc, {290, 220}, {220, 100}, %{
      elevation: 3,
      border_radius: 8,
      header: %{title: "User Profile", subtitle: "Senior Developer"},
      padding: 10
    }, fn doc, area ->
      doc
      |> Avatar.render({area.x, area.y}, %{size: 30, initials: "AM", background: blue, elevation: 1})
      |> Pdf.set_font("Helvetica", 9)
      |> Pdf.set_fill_color(gray)
      |> Pdf.text_at({area.x + 38, area.y - 12}, "Elixir \u2022 Phoenix \u2022 OTP")
      |> Pdf.set_fill_color(:black)
    end)

    # Card with border, no elevation
    doc = Card.render(doc, {50, 108}, {220, 70}, %{
      elevation: 0,
      border: 1,
      border_color: light_gray,
      border_radius: 6,
      padding: 10
    }, fn doc, area ->
      doc
      |> Pdf.set_font("Helvetica", 10, bold: true)
      |> Pdf.text_at({area.x, area.y - 12}, "Bordered Card")
      |> Pdf.set_font("Helvetica", 9)
      |> Pdf.set_fill_color(gray)
      |> Pdf.text_at({area.x, area.y - 26}, "No shadow, just a border.")
      |> Pdf.set_fill_color(:black)
    end)

    # Card with footer
    Card.render(doc, {290, 108}, {220, 70}, %{
      elevation: 1,
      border_radius: 6,
      footer: %{text: "Updated 2 hours ago"},
      padding: 8
    }, fn doc, area ->
      doc
      |> Pdf.set_font("Helvetica", 10, bold: true)
      |> Pdf.text_at({area.x, area.y - 12}, "With Footer")
      |> Pdf.set_fill_color(:black)
    end)
  end
end
