defmodule Pdf.Reader.ShapeTest do
  @moduledoc """
  Unit tests for inferred-shape detection (URL / email regex matching
  on token text). Annotation-sourced shapes are exercised separately
  in the annotation/integration tests.
  """
  use ExUnit.Case, async: true

  alias Pdf.Reader.Shape

  describe "Pdf.Reader.shapes_from_lines/1 — inference from token text" do
    test "detects an http URL token as a :uri shape" do
      lines = [
        line(1, 700, 30, [{"http://sat.gob.mx", 30, 60}])
      ]

      assert [%Shape{type: :uri, target: "http://sat.gob.mx", source: :inferred} = shape] =
               Pdf.Reader.shapes_from_lines(lines)

      assert shape.text == "http://sat.gob.mx"
      assert shape.rect == {30.0, 700.0, 90.0, 700.0}
    end

    test "detects an https URL" do
      lines = [line(2, 500, 0, [{"https://example.com/path?q=1", 50, 100}])]

      assert [%Shape{type: :uri, target: "https://example.com/path?q=1"}] =
               Pdf.Reader.shapes_from_lines(lines)
    end

    test "detects www.* URL without scheme" do
      lines = [line(1, 600, 0, [{"www.gob.mx/sfp", 70, 50}])]

      assert [%Shape{type: :uri, target: "www.gob.mx/sfp"}] =
               Pdf.Reader.shapes_from_lines(lines)
    end

    test "detects an email as :email shape" do
      lines = [line(1, 400, 0, [{"denuncias@sat.gob.mx", 100, 80}])]

      assert [%Shape{type: :email, target: "denuncias@sat.gob.mx"}] =
               Pdf.Reader.shapes_from_lines(lines)
    end

    test "extracts URL from a token with leading punctuation" do
      lines = [line(1, 300, 0, [{",http://sat.gob.mx", 50, 70}])]

      # The leading "," should not be part of the URI.
      assert [%Shape{type: :uri, target: "http://sat.gob.mx"}] =
               Pdf.Reader.shapes_from_lines(lines)
    end

    test "extracts URL from a token with trailing comma or period" do
      lines = [
        line(1, 300, 0, [{"http://sat.gob.mx.", 50, 70}]),
        line(2, 300, 0, [{"https://example.com,", 50, 70}])
      ]

      shapes = Pdf.Reader.shapes_from_lines(lines)
      assert length(shapes) == 2
      assert Enum.all?(shapes, &(not String.ends_with?(&1.target, ".")))
      assert Enum.all?(shapes, &(not String.ends_with?(&1.target, ",")))
    end

    test "ignores plain text tokens that are not URLs/emails" do
      lines = [line(1, 700, 0, [{"OMAR ALEXIS", 50, 80}, {"Asalariado", 200, 50}])]

      assert [] = Pdf.Reader.shapes_from_lines(lines)
    end

    test "produces multiple shapes when a single line has both URL and email" do
      lines = [
        line(2, 500, 0, [
          {"www.sat.gob.mx", 30, 60},
          {"denuncias@sat.gob.mx", 100, 80}
        ])
      ]

      shapes = Pdf.Reader.shapes_from_lines(lines)

      assert length(shapes) == 2
      assert Enum.any?(shapes, &(&1.type == :uri))
      assert Enum.any?(shapes, &(&1.type == :email))
    end

    test "extracts URL embedded inside a longer token (concatenated text)" do
      # Real-world: CSF emits "móvilowww.gob.mx/sfp" as one token
      lines = [line(2, 480, 0, [{"móvilowww.gob.mx/sfp", 478, 82}])]

      assert [%Shape{type: :uri, target: "www.gob.mx/sfp"}] =
               Pdf.Reader.shapes_from_lines(lines)
    end

    test "page and source are populated from the line" do
      lines = [line(7, 100, 0, [{"https://x.example", 0, 30}])]

      assert [%Shape{page: 7, source: :inferred}] = Pdf.Reader.shapes_from_lines(lines)
    end
  end

  # Helpers

  defp line(page, y, x, tokens) do
    token_maps =
      Enum.map(tokens, fn {text, x_pos, w} ->
        %{x: x_pos * 1.0, text: text, width: w * 1.0}
      end)

    %Pdf.Reader.Line{
      page: page,
      y: y * 1.0,
      x: x * 1.0,
      text: token_maps |> Enum.map(& &1.text) |> Enum.join(" "),
      tokens: token_maps
    }
  end
end
