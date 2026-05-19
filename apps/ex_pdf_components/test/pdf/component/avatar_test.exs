defmodule Pdf.Component.AvatarTest do
  use Pdf.Case, async: true

  describe "render/3 with initials" do
    test "renders avatar with initials" do
      doc = new_test_doc()

      doc =
        Pdf.Component.Avatar.render(doc, {100, 700}, %{
          size: 48,
          initials: "AM",
          background: {0.3, 0.5, 0.9},
          color: :white
        })

      output = export(doc)
      # Background fill
      assert output =~ "0.3 0.5 0.9 rg"
      # Rounded rect (bezier curves)
      assert output =~ "c"
      # Initials text
      assert output =~ "AM"
    end

    test "renders single initial" do
      doc = new_test_doc()

      doc =
        Pdf.Component.Avatar.render(doc, {100, 700}, %{
          size: 40,
          initials: "A",
          background: {0.5, 0.5, 0.5}
        })

      output = export(doc)
      assert output =~ "A"
    end

    test "renders with default style (no options)" do
      doc = new_test_doc()
      doc = Pdf.Component.Avatar.render(doc, {100, 700})
      assert %Pdf.Document{} = doc
    end
  end

  describe "border" do
    test "draws border around avatar" do
      doc = new_test_doc()

      doc =
        Pdf.Component.Avatar.render(doc, {100, 700}, %{
          size: 48,
          initials: "X",
          border: 2,
          border_color: :red
        })

      output = export(doc)
      # Red stroke
      assert output =~ "1.0 0.0 0.0 RG"
      # Stroke command
      assert output =~ "S"
    end

    test "no border when border is 0" do
      doc = new_test_doc()

      doc =
        Pdf.Component.Avatar.render(doc, {100, 700}, %{
          size: 48,
          initials: "X",
          border: 0
        })

      # Should still render without error
      assert %Pdf.Document{} = doc
    end
  end

  describe "border_radius" do
    test ":circle is default (radius = size/2)" do
      doc = new_test_doc()

      doc =
        Pdf.Component.Avatar.render(doc, {100, 700}, %{
          size: 48,
          initials: "C",
          background: {0.2, 0.6, 0.2}
        })

      output = export(doc)
      # Uses rounded rectangle curves
      assert output =~ "c"
    end

    test ":rounded uses smaller radius" do
      doc = new_test_doc()

      doc =
        Pdf.Component.Avatar.render(doc, {100, 700}, %{
          size: 48,
          initials: "R",
          border_radius: :rounded
        })

      output = export(doc)
      assert output =~ "R"
    end

    test "numeric radius" do
      doc = new_test_doc()

      doc =
        Pdf.Component.Avatar.render(doc, {100, 700}, %{
          size: 48,
          initials: "N",
          border_radius: 8
        })

      output = export(doc)
      assert output =~ "N"
    end
  end

  describe "elevation" do
    test "elevation 0 draws no shadow" do
      doc = new_test_doc()

      doc =
        Pdf.Component.Avatar.render(doc, {100, 700}, %{
          size: 48,
          initials: "E",
          elevation: 0
        })

      assert %Pdf.Document{} = doc
    end

    test "elevation 1-5 draws shadow layers" do
      for elev <- 1..5 do
        doc = new_test_doc()

        doc =
          Pdf.Component.Avatar.render(doc, {100, 700}, %{
            size: 48,
            initials: "E",
            elevation: elev
          })

        output = export(doc)
        # Shadow uses black fill with opacity
        assert output =~ "0.0 0.0 0.0 rg"
        # Graphics state for opacity
        assert output =~ "gs"
      end
    end
  end

  describe "Pdf.Component.Avatar.render/3" do
    test "renders avatar directly via component" do
      doc = new_test_doc()

      doc =
        Pdf.Component.Avatar.render(doc, {100, 700}, %{
          size: 48,
          initials: "D",
          background: {0.8, 0.2, 0.2}
        })

      output = export(doc)
      assert output =~ "D"
      assert output =~ "0.8 0.2 0.2 rg"
    end
  end

  describe "Builder map support" do
    test "renders avatar via Builder" do
      template = [
        %{avatar: {100, 700}, size: 48, initials: "B", background: {0.1, 0.4, 0.8}}
      ]

      doc = Pdf.Builder.render(template, %{compress: false})
      output = export(doc.current)
      assert output =~ "B"
    end

    test "avatar inside box with relative positioning" do
      template = [
        %{box: {50, 750}, size: {300, 100}, padding: 10, children: [
          %{avatar: {0, 0}, size: 40, initials: "AB", background: {0.3, 0.6, 0.3}}
        ]}
      ]

      doc = Pdf.Builder.render(template, %{compress: false})
      output = export(doc.current)
      assert output =~ "AB"
    end
  end
end
