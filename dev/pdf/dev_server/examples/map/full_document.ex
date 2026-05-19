defmodule Pdf.DevServer.Examples.Map.FullDocument do
  @moduledoc false

  def render do
    template = [
      {:background, %{background: {0.98, 0.98, 1.0}}},
      {:text, "Full Document Example", %{font_size: 28, bold: true, color: :navy}},
      {:spacer, 8},
      {:text, "Demonstrating all features of elixir-pdf", %{font_size: 14, color: :gray}},
      {:spacer, 15},
      {:line, %{color: :navy}},
      {:spacer, 15},
      {:text, "1. Styled Text", %{font_size: 16, bold: true}},
      {:spacer, 5},
      {:text, "Regular text with automatic word-wrapping within the content area defined by margins. This text will flow naturally within the page boundaries."},
      {:spacer, 5},
      {:text, "Bold red text", %{bold: true, color: :red}},
      {:text, "Italic blue text", %{italic: true, color: :blue}},
      {:spacer, 15},
      {:text, "2. Opacity & Watermark", %{font_size: 16, bold: true}},
      {:spacer, 5},
      {:text, "This document has a light blue background and a watermark on page 2."},
      {:spacer, 15},
      {:text, "3. Builder API", %{font_size: 16, bold: true}},
      {:spacer, 5},
      {:text, "This entire document is generated from a declarative template list using Pdf.Builder.render/2."},
      {:spacer, 15},
      {:line, %{color: :gray}},
      {:spacer, 10},
      {:text, "End of page 1", %{font_size: 10, color: :gray}},
      {:page_break},
      {:watermark, "CONFIDENTIAL", %{opacity: 0.05, rotate: 45, font_size: 60, color: :red}},
      {:text, "Page 2 - More Features", %{font_size: 22, bold: true, color: :navy}},
      {:spacer, 15},
      {:text, "Page templates (header/footer) can be configured in the Builder config."},
      {:spacer, 10},
      {:text, "The watermark on this page was added with a single tuple in the template."},
      {:spacer, 15},
      {:line, %{color: :navy}},
      {:spacer, 10},
      {:text, "Built with elixir-pdf", %{font_size: 10, color: :gray}}
    ]

    config = %{
      size: :a4,
      margin: %{top: 70, bottom: 60, left: 50, right: 50},
      debug: true,
      font: "Helvetica",
      font_size: 12,
      header: fn doc, info ->
        doc
        |> Pdf.set_font("Helvetica", 8)
        |> Pdf.set_fill_color(:gray)
        |> Pdf.text_at({50, 820}, "elixir-pdf Full Document Example")
        |> Pdf.text_at({490, 820}, "Page #{info.number}")
        |> Pdf.set_fill_color(:black)
      end,
      footer: fn doc, _info ->
        doc
        |> Pdf.set_font("Helvetica", 7)
        |> Pdf.set_fill_color(:gray)
        |> Pdf.text_at({200, 30}, "Generated with elixir-pdf | github.com/andrewtimberlake/elixir-pdf")
        |> Pdf.set_fill_color(:black)
      end
    }

    Pdf.Builder.render(template, config)
  end
end
