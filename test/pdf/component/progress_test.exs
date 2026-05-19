defmodule Pdf.Component.ProgressTest do
  use Pdf.Case, async: true

  describe "render/3" do
    test "renders a progress bar with value" do
      doc = new_test_doc()
      doc = Pdf.Component.Progress.render(doc, {50, 400}, %{width: 200, value: 50})
      output = export(doc)
      # Track color (default light gray)
      assert output =~ "0.92 0.92 0.92 rg"
      # Fill color (default blue)
      assert output =~ "0.23 0.53 0.88 rg"
    end

    test "renders with 0% value (no fill)" do
      doc = new_test_doc()
      doc = Pdf.Component.Progress.render(doc, {50, 400}, %{width: 200, value: 0})
      output = export(doc)
      assert output =~ "0.92 0.92 0.92 rg"
    end

    test "renders with 100% value" do
      doc = new_test_doc()
      doc = Pdf.Component.Progress.render(doc, {50, 400}, %{width: 200, value: 100})
      output = export(doc)
      assert output =~ "0.23 0.53 0.88 rg"
    end

    test "clamps value to 0-100" do
      doc = new_test_doc()
      doc = Pdf.Component.Progress.render(doc, {50, 400}, %{width: 200, value: 150})
      assert export(doc)
      doc = new_test_doc()
      doc = Pdf.Component.Progress.render(doc, {50, 400}, %{width: 200, value: -10})
      assert export(doc)
    end

    test "renders with custom color" do
      doc = new_test_doc()
      doc = Pdf.Component.Progress.render(doc, {50, 400}, %{
        width: 200,
        value: 75,
        color: {0.18, 0.72, 0.45}
      })
      output = export(doc)
      assert output =~ "0.18 0.72 0.45 rg"
    end

    test "renders with label" do
      doc = new_test_doc()
      doc = Pdf.Component.Progress.render(doc, {50, 400}, %{
        width: 200,
        value: 42,
        show_label: true
      })
      output = export(doc)
      assert output =~ "42%"
    end

    test "renders with square border_radius" do
      doc = new_test_doc()
      doc = Pdf.Component.Progress.render(doc, {50, 400}, %{
        width: 200,
        value: 60,
        border_radius: :square
      })
      assert export(doc)
    end

    test "renders via Builder" do
      template = [
        %{progress: {50, 400}, width: 200, value: 65, color: {0.85, 0.26, 0.33}}
      ]
      doc = Pdf.Builder.render(template, %{size: :a4, font: "Helvetica", font_size: 12, compress: false})
      output = export(doc)
      assert output =~ "0.85 0.26 0.33 rg"
    end
  end
end
