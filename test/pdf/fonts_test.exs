defmodule Pdf.FontsTest do
  use ExUnit.Case

  alias Pdf.Document
  alias Pdf.Fonts
  alias Pdf.ExternalFont

  test "looking up an internal font by name" do
    document = Document.new()

    assert {%Fonts.FontReference{module: %Pdf.Font{name: "Helvetica"}}, _fonts, _objects} =
             Fonts.get_font(document.fonts, document.objects, "Helvetica", [])
  end

  test "looking up an internal font by name, bold" do
    document = Document.new()

    assert {%Fonts.FontReference{module: %Pdf.Font{name: "Helvetica-Bold"}}, _fonts, _objects} =
             Fonts.get_font(document.fonts, document.objects, "Helvetica", bold: true)
  end

  test "looking up an internal font by name, italic" do
    document = Document.new()

    assert {%Fonts.FontReference{module: %Pdf.Font{name: "Helvetica-Oblique"}}, _fonts, _objects} =
             Fonts.get_font(document.fonts, document.objects, "Helvetica", italic: true)
  end

  test "looking up an internal font by name, bold, italic" do
    document = Document.new()

    assert {%Fonts.FontReference{module: %Pdf.Font{name: "Helvetica-BoldOblique"}}, _fonts, _objects} =
             Fonts.get_font(document.fonts, document.objects, "Helvetica", italic: true, bold: true)
  end

  test "cannot look up an internal font by name, that has no variants" do
    document = Document.new()

    {ref, _fonts, _objects} = Fonts.get_font(document.fonts, document.objects, "Symbol", bold: true)
    refute ref
  end

  test "Looking up an external font by name" do
    document =
      Document.new()
      |> Document.add_external_font("test/fonts/Verdana.afm")

    assert {%Fonts.FontReference{module: %ExternalFont{name: "Verdana"}}, _fonts, _objects} =
             Fonts.get_font(document.fonts, document.objects, "Verdana", [])
  end

  test "Looking up an external font by font, and variant" do
    document =
      Document.new()
      |> Document.add_external_font("test/fonts/Verdana.afm")
      |> Document.add_external_font("test/fonts/Verdana-Bold.afm")

    assert {%Fonts.FontReference{module: %ExternalFont{name: "Verdana-Bold"}}, _fonts, _objects} =
             Fonts.get_font(document.fonts, document.objects, %ExternalFont{family_name: "Verdana"}, bold: true)
  end

  test "Looking up an external font by name, and non-existing variant" do
    document =
      Document.new()
      |> Document.add_external_font("test/fonts/Verdana.afm")

    {ref, _fonts, _objects} = Fonts.get_font(document.fonts, document.objects, %ExternalFont{family_name: "Verdana"}, bold: true)
    refute ref
  end
end
