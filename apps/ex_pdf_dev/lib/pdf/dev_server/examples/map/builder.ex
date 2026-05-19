defmodule Pdf.DevServer.Examples.Map.Builder do
  @moduledoc false

  def render do
    template = [
      {:text, "Builder API Demo", %{font_size: 24, bold: true}},
      {:spacer, 15},
      {:text, "This document was built from a declarative template list.", %{font_size: 13}},
      {:spacer, 10},
      {:line, %{color: :gray}},
      {:spacer, 10},
      {:text, "Features used:", %{font_size: 14, bold: true}},
      {:spacer, 5},
      {:text, "  - {:text, string, style} for styled text", %{font_size: 12, color: :green}},
      {:text, "  - {:spacer, amount} for vertical space", %{font_size: 12, color: :green}},
      {:text, "  - {:line, style} for horizontal rules", %{font_size: 12, color: :green}},
      {:text, "  - {:watermark, text, style} for watermarks", %{font_size: 12, color: :green}},
      {:text, "  - {:page_break} for new pages", %{font_size: 12, color: :green}},
      {:spacer, 15},
      {:watermark, "SAMPLE", %{opacity: 0.06, font_size: 80}},
      {:page_break},
      {:text, "Page 2 - via {:page_break}", %{font_size: 18, bold: true, color: :navy}},
      {:spacer, 10},
      {:text, "The builder automatically processes each element in sequence.", %{color: :gray}}
    ]

    config = %{
      size: :a4,
      margin: %{top: 60, bottom: 60, left: 50, right: 50},
      font: "Helvetica",
      font_size: 12
    }

    Pdf.Builder.render(template, config)
  end
end
