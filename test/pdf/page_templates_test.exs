defmodule Pdf.PageTemplatesTest do
  use Pdf.Case, async: true

  describe "margin" do
    test "default margin is 0" do
      pdf = Pdf.new(size: :a4)
      area = Pdf.content_area(pdf)
      %{width: pw, height: ph} = Pdf.size(pdf)

      assert area.x == 0
      assert area.y == ph
      assert area.width == pw
      assert area.height == ph
    end

    test "uniform margin" do
      pdf = Pdf.new(size: :a4, margin: 40)
      area = Pdf.content_area(pdf)
      %{width: pw, height: ph} = Pdf.size(pdf)

      assert area.x == 40
      assert area.y == ph - 40
      assert area.width == pw - 80
      assert area.height == ph - 80
    end

    test "map margin" do
      pdf = Pdf.new(size: :a4, margin: %{top: 60, bottom: 40, left: 30, right: 20})
      area = Pdf.content_area(pdf)
      %{width: pw, height: ph} = Pdf.size(pdf)

      assert area.x == 30
      assert area.y == ph - 60
      assert area.width == pw - 50
      assert area.height == ph - 100
    end

    test "cursor starts at top of content area" do
      pdf = Pdf.new(size: :a4, margin: 50)
      %{height: ph} = Pdf.size(pdf)
      pos = Pdf.cursor_xy(pdf)

      assert pos.x == 50
      assert pos.y == ph - 50
    end
  end

  describe "on_page/3" do
    test "registers a page template" do
      pdf =
        Pdf.new(size: :a4)
        |> Pdf.on_page(:header, fn doc, _info -> doc end)

      assert is_function(pdf.page_templates.header, 2)
    end

    test "header template executes on new page" do
      test_pid = self()

      _pdf =
        Pdf.new(size: :a4, compress: false)
        |> Pdf.on_page(:header, fn doc, info ->
          send(test_pid, {:header_called, info.number})
          Pdf.set_font(doc, "Helvetica", 10)
          |> Pdf.text_at({40, 820}, "Header Text")
        end)
        |> Pdf.add_page(:a4)

      assert_receive {:header_called, 2}
    end

    test "header template executes on new pages" do
      test_pid = self()

      _pdf =
        Pdf.new(size: :a4)
        |> Pdf.on_page(:header, fn doc, info ->
          send(test_pid, {:header, info.number})
          doc
        end)
        |> Pdf.add_page(:a4)

      assert_receive {:header, 2}
    end

    test "footer template executes when adding new page" do
      test_pid = self()

      _pdf =
        Pdf.new(size: :a4)
        |> Pdf.on_page(:footer, fn doc, info ->
          send(test_pid, {:footer, info.number})
          doc
        end)
        |> Pdf.add_page(:a4)

      assert_receive {:footer, 1}
    end

    test "page_info contains page number" do
      test_pid = self()

      _pdf =
        Pdf.new(size: :a4)
        |> Pdf.on_page(:header, fn doc, info ->
          send(test_pid, {:header, info})
          doc
        end)
        |> Pdf.add_page(:a4)
        |> Pdf.add_page(:a4)

      assert_receive {:header, %{number: 2}}
      assert_receive {:header, %{number: 3}}
    end
  end
end
