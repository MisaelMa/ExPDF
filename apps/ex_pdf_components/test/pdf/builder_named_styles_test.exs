defmodule Pdf.BuilderNamedStylesTest do
  use Pdf.Case, async: true

  describe "Builder with named styles" do
    test "styles in config are available in template" do
      template = [
        {:text, "Heading Text", :heading},
        {:spacer, 5},
        {:text, "Body text", :body},
        {:spacer, 5},
        {:text, "Green accent", :accent}
      ]

      config = %{
        compress: false,
        styles: %{
          heading: %{font_size: 24, bold: true, color: :navy},
          body: %{font_size: 12, color: :black},
          accent: %{font_size: 12, color: :green}
        }
      }

      doc = Pdf.Builder.render(template, config)
      output = export(doc)
      assert output =~ "Heading Text"
      assert output =~ "Body text"
      assert output =~ "Green accent"
    end
  end
end
