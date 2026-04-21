defmodule Pdf.StyleTest do
  use ExUnit.Case, async: true

  alias Pdf.Style

  describe "new/1" do
    test "creates style with defaults" do
      style = Style.new()
      assert style.font == "Helvetica"
      assert style.font_size == 12
      assert style.color == :black
      assert style.padding == {0, 0, 0, 0}
      assert style.opacity == 1.0
    end

    test "creates style from map" do
      style = Style.new(%{font_size: 14, color: :red, bold: true})
      assert style.font_size == 14
      assert style.color == :red
      assert style.bold == true
      assert style.font == "Helvetica"
    end

    test "creates style from keyword list" do
      style = Style.new(font_size: 16, italic: true)
      assert style.font_size == 16
      assert style.italic == true
    end
  end

  describe "expand_shorthand/1" do
    test "single number expands to all four sides" do
      assert Style.expand_shorthand(10) == {10, 10, 10, 10}
    end

    test "two-tuple expands to vertical/horizontal" do
      assert Style.expand_shorthand({5, 10}) == {5, 10, 5, 10}
    end

    test "three-tuple expands with shared horizontal" do
      assert Style.expand_shorthand({5, 10, 15}) == {5, 10, 15, 10}
    end

    test "four-tuple passes through" do
      assert Style.expand_shorthand({1, 2, 3, 4}) == {1, 2, 3, 4}
    end
  end

  describe "new/1 shorthand normalization" do
    test "normalizes padding shorthand" do
      style = Style.new(%{padding: 10})
      assert style.padding == {10, 10, 10, 10}
    end

    test "normalizes margin shorthand" do
      style = Style.new(%{margin: {5, 10}})
      assert style.margin == {5, 10, 5, 10}
    end

    test "normalizes border shorthand" do
      style = Style.new(%{border: {1, 2, 3}})
      assert style.border == {1, 2, 3, 2}
    end

    test "passes through four-tuples" do
      style = Style.new(%{padding: {1, 2, 3, 4}})
      assert style.padding == {1, 2, 3, 4}
    end
  end

  describe "merge/2" do
    test "child overrides parent fields" do
      parent = Style.new(%{font_size: 12, color: :black})
      child = Style.new(%{color: :red, bold: true})
      merged = Style.merge(parent, child)

      assert merged.font_size == 12
      assert merged.color == :red
      assert merged.bold == true
    end

    test "merge with map" do
      parent = Style.new(%{font_size: 12})
      merged = Style.merge(parent, %{font_size: 16})
      assert merged.font_size == 16
    end

    test "merge with keyword list" do
      parent = Style.new(%{font_size: 12})
      merged = Style.merge(parent, font_size: 16, bold: true)
      assert merged.font_size == 16
      assert merged.bold == true
    end

    test "nil child values in maps don't override parent" do
      parent = Style.new(%{font_size: 12, color: :red})
      merged = Style.merge(parent, %{leading: nil, bold: true})

      assert merged.font_size == 12
      assert merged.color == :red
      assert merged.bold == true
      assert merged.leading == nil
    end
  end

  describe "to_opts/1" do
    test "converts style to keyword list" do
      style = Style.new(%{bold: true, font_size: 14, color: :red})
      opts = Style.to_opts(style)

      assert Keyword.get(opts, :bold) == true
      assert Keyword.get(opts, :font_size) == 14
      assert Keyword.get(opts, :color) == :red
    end

    test "excludes default values" do
      style = Style.new()
      opts = Style.to_opts(style)

      refute Keyword.has_key?(opts, :bold)
      refute Keyword.has_key?(opts, :italic)
    end
  end
end
