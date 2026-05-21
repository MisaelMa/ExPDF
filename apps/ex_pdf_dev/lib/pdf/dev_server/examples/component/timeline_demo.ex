defmodule Pdf.DevServer.Examples.Component.TimelineDemo do
  @moduledoc false

  def render do
    dark = {0.1, 0.1, 0.1}
    accent = {0.0, 0.45, 0.75}
    gray = {0.45, 0.45, 0.45}

    doc =
      Pdf.new(size: :a4, margin: 40)
      |> Pdf.set_font("Helvetica", 24)
      |> Pdf.set_fill_color(dark)
      |> Pdf.text_at({40, 780}, "Timeline Component", %{bold: true})
      |> Pdf.set_font("Helvetica", 10)
      |> Pdf.set_fill_color(gray)
      |> Pdf.text_at({40, 764}, "Vertical timeline with dots, connecting line, and event entries")

    # ── Project history ──
    doc =
      doc
      |> Pdf.set_font("Helvetica", 12)
      |> Pdf.set_fill_color(accent)
      |> Pdf.text_at({40, 730}, "Project History", %{bold: true})
      |> Pdf.Component.Timeline.render({50, 710}, %{}, [
        %{date: "2026", title: "v2.0 Release", description: "Umbrella restructure, component system"},
        %{date: "2025 Q4", title: "Component Library", description: "Added Avatar, Badge, Card, Chip, Progress"},
        %{date: "2025 Q2", title: "Builder API", description: "Declarative PDF builder with maps"},
        %{date: "2025 Q1", title: "StyledTable", description: "Full-featured table component"},
        %{date: "2024", title: "Initial Release", description: "Core PDF generation with text, images, fonts"}
      ])

    # ── Custom styled ──
    doc
    |> Pdf.set_font("Helvetica", 12)
    |> Pdf.set_fill_color(accent)
    |> Pdf.text_at({40, 440}, "Custom Colors", %{bold: true})
    |> Pdf.Component.Timeline.render({50, 420}, %{
      dot_color: {0.8, 0.2, 0.4},
      line_color: {0.9, 0.85, 0.85},
      date_color: {0.6, 0.3, 0.3},
      row_height: 55
    }, [
      %{date: "May 19", title: "Components Added", description: "List, Blockquote, CodeBlock, Signature, StatCard, Alert"},
      %{date: "May 18", title: "Dev Server", description: "Interactive PDF preview with hot reload"},
      %{date: "May 17", title: "Umbrella Split", description: "Monolith split into 5 apps"},
      %{date: "May 16", title: "Planning", description: "Architecture design and dependency graph"}
    ])
  end
end
