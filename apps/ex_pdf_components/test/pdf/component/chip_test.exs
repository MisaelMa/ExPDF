defmodule Pdf.Component.ChipTest do
  use Pdf.Case, async: true

  describe "render/3" do
    test "renders a filled chip with label" do
      doc = new_test_doc()
      {doc, width} = Pdf.Component.Chip.render(doc, {50, 400}, %{label: "Elixir"})
      output = export(doc)
      assert output =~ "Elixir"
      assert width > 0
    end

    test "renders an outlined chip" do
      doc = new_test_doc()
      {doc, _width} = Pdf.Component.Chip.render(doc, {50, 400}, %{
        label: "Active",
        variant: :outlined,
        color: {0.18, 0.72, 0.45}
      })
      output = export(doc)
      assert output =~ "Active"
      # Outlined uses stroke color
      assert output =~ "0.18 0.72 0.45 RG"
    end

    test "renders with custom background" do
      doc = new_test_doc()
      {doc, _width} = Pdf.Component.Chip.render(doc, {50, 400}, %{
        label: "Priority",
        background: {0.85, 0.26, 0.33},
        color: :white
      })
      output = export(doc)
      assert output =~ "0.85 0.26 0.33 rg"
      assert output =~ "Priority"
    end

    test "returns chip width for layout chaining" do
      doc = new_test_doc()
      {_doc, w1} = Pdf.Component.Chip.render(doc, {50, 400}, %{label: "Hi"})
      {_doc, w2} = Pdf.Component.Chip.render(doc, {50, 400}, %{label: "Hello World"})
      assert w2 > w1
    end

    test "renders via Builder" do
      template = [
        %{chip: {50, 400}, label: "Tag", background: {0.2, 0.6, 0.9}}
      ]
      doc = Pdf.Builder.render(template, %{size: :a4, font: "Helvetica", font_size: 12, compress: false})
      output = export(doc)
      assert output =~ "Tag"
    end
  end
end
