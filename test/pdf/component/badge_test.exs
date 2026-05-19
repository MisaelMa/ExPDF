defmodule Pdf.Component.BadgeTest do
  use Pdf.Case, async: true

  describe "render/3" do
    test "renders a standard badge with content" do
      doc = new_test_doc()
      doc = Pdf.Component.Badge.render(doc, {100, 700}, %{content: "5"})
      output = export(doc)
      assert output =~ "5"
      # Default red background
      assert output =~ "0.85 0.26 0.33 rg"
    end

    test "renders a dot badge (no text)" do
      doc = new_test_doc()
      doc = Pdf.Component.Badge.render(doc, {100, 700}, %{variant: :dot})
      output = export(doc)
      # Default red background
      assert output =~ "0.85 0.26 0.33 rg"
    end

    test "renders a pill badge" do
      doc = new_test_doc()
      doc = Pdf.Component.Badge.render(doc, {100, 700}, %{content: "NEW", variant: :pill})
      output = export(doc)
      assert output =~ "NEW"
    end

    test "renders with custom colors" do
      doc = new_test_doc()
      doc = Pdf.Component.Badge.render(doc, {100, 700}, %{
        content: "OK",
        background: {0.18, 0.72, 0.45},
        color: :white
      })
      output = export(doc)
      assert output =~ "0.18 0.72 0.45 rg"
      assert output =~ "OK"
    end

    test "renders with border" do
      doc = new_test_doc()
      doc = Pdf.Component.Badge.render(doc, {100, 700}, %{
        content: "3",
        border: 2,
        border_color: :white
      })
      output = export(doc)
      assert output =~ "1.0 1.0 1.0 RG"
    end

    test "renders via Builder" do
      template = [
        %{badge: {100, 700}, content: "9", background: {0.85, 0.26, 0.33}}
      ]
      doc = Pdf.Builder.render(template, %{size: :a4, font: "Helvetica", font_size: 12, compress: false})
      output = export(doc)
      assert output =~ "9"
    end
  end
end
