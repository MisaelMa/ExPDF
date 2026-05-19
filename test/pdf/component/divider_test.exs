defmodule Pdf.Component.DividerTest do
  use Pdf.Case, async: true

  describe "render/3" do
    test "renders a horizontal divider (default)" do
      doc = new_test_doc()
      doc = Pdf.Component.Divider.render(doc, {50, 400}, %{width: 200})
      output = export(doc)
      # Should contain line drawing operations
      assert output =~ "50"
      assert output =~ "400"
    end

    test "renders with custom color" do
      doc = new_test_doc()
      doc = Pdf.Component.Divider.render(doc, {50, 400}, %{width: 200, color: {0.5, 0.5, 0.5}})
      output = export(doc)
      assert output =~ "0.5 0.5 0.5 RG"
    end

    test "renders with custom thickness" do
      doc = new_test_doc()
      doc = Pdf.Component.Divider.render(doc, {50, 400}, %{width: 200, thickness: 2})
      output = export(doc)
      assert output =~ "2 w"
    end

    test "renders a vertical divider" do
      doc = new_test_doc()
      doc = Pdf.Component.Divider.render(doc, {100, 500}, %{height: 100, orientation: :vertical})
      output = export(doc)
      assert output =~ "100"
      assert output =~ "500"
    end

    test "renders a dashed divider" do
      doc = new_test_doc()
      doc = Pdf.Component.Divider.render(doc, {50, 400}, %{width: 200, style: :dashed})
      output = export(doc)
      assert output =~ "[3 3] 0 d"
    end

    test "renders with custom dash pattern" do
      doc = new_test_doc()
      doc = Pdf.Component.Divider.render(doc, {50, 400}, %{width: 200, style: :dashed, dash: {6, 2}})
      output = export(doc)
      assert output =~ "[6 2] 0 d"
    end

    test "defaults render without errors" do
      doc = new_test_doc()
      doc = Pdf.Component.Divider.render(doc, {50, 400})
      assert export(doc)
    end

    test "renders via Builder" do
      template = [
        %{divider: {50, 400}, width: 300, color: {0.8, 0.8, 0.8}}
      ]
      doc = Pdf.Builder.render(template, %{size: :a4, font: "Helvetica", font_size: 12, compress: false})
      output = export(doc)
      assert output =~ "0.8 0.8 0.8 RG"
    end
  end
end
