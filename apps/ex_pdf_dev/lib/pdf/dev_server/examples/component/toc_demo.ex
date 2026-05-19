defmodule Pdf.DevServer.Examples.Component.TOCDemo do
  @moduledoc false

  def render do
    dark = {0.1, 0.1, 0.1}
    accent = {0.0, 0.45, 0.75}
    gray = {0.45, 0.45, 0.45}

    doc =
      Pdf.new(size: :a4, margin: 40)
      |> Pdf.set_font("Helvetica", 24)
      |> Pdf.set_fill_color(dark)
      |> Pdf.text_at({40, 780}, "TOC Component", %{bold: true})
      |> Pdf.set_font("Helvetica", 10)
      |> Pdf.set_fill_color(gray)
      |> Pdf.text_at({40, 764}, "Table of Contents with dot leaders and page numbers")

    # ── Standard TOC ──
    doc =
      doc
      |> Pdf.set_font("Helvetica", 12)
      |> Pdf.set_fill_color(accent)
      |> Pdf.text_at({40, 730}, "Standard TOC", %{bold: true})
      |> Pdf.Component.TOC.render({50, 710}, %{width: 450}, [
        %{title: "Introduction", page: 1, level: 0},
        %{title: "Getting Started", page: 3, level: 1},
        %{title: "Installation", page: 3, level: 2},
        %{title: "Configuration", page: 5, level: 2},
        %{title: "Quick Start Guide", page: 7, level: 2},
        %{title: "Core Concepts", page: 10, level: 0},
        %{title: "Document Model", page: 10, level: 1},
        %{title: "Page Layout", page: 14, level: 1},
        %{title: "Font System", page: 18, level: 1},
        %{title: "Components", page: 22, level: 0},
        %{title: "Layout Components", page: 22, level: 1},
        %{title: "Data Display", page: 28, level: 1},
        %{title: "Feedback", page: 34, level: 1},
        %{title: "API Reference", page: 40, level: 0},
        %{title: "Appendix", page: 55, level: 0}
      ])

    # ── Without dots ──
    doc
    |> Pdf.set_font("Helvetica", 12)
    |> Pdf.set_fill_color(accent)
    |> Pdf.text_at({40, 420}, "Without Dot Leaders", %{bold: true})
    |> Pdf.Component.TOC.render({50, 400}, %{
      width: 400,
      dots: false,
      font_size: 11
    }, [
      %{title: "Chapter 1: Foundations", page: 1, level: 0},
      %{title: "Variables and Types", page: 2, level: 1},
      %{title: "Pattern Matching", page: 8, level: 1},
      %{title: "Chapter 2: OTP", page: 15, level: 0},
      %{title: "GenServer", page: 16, level: 1},
      %{title: "Supervisor", page: 22, level: 1},
      %{title: "Chapter 3: Testing", page: 30, level: 0}
    ])
  end
end
