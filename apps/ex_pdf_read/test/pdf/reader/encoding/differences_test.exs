defmodule Pdf.Reader.Encoding.DifferencesTest do
  use ExUnit.Case, async: true

  alias Pdf.Reader.Encoding.Differences

  # Spec reference: PDF 1.7 § 9.6.5.1
  #
  # /Differences is an array that mixes integers and names:
  #   [32 /space 65 /A /B /C 200 /uni0024 ...]
  #
  # - An integer N sets the current code position to N.
  # - Each subsequent name installs that glyph name at the current position,
  #   then increments by 1.
  #
  # apply/2 takes a base map of overrides and merges the /Differences on top.
  # Output: %{integer => glyph_name :: binary}
  #
  # Note: the output is byte → glyph_name. Codepoint resolution (via AGL or
  # ToUnicode) is done later in the encoding facade (Phase 7.3).

  # ---- 7.2.1 apply/2 — basic /Differences parsing ----

  describe "apply/2 basic parsing" do
    test "integer sets position, names fill consecutive slots" do
      # [65 /A /B /C] → {65 → "A", 66 → "B", 67 → "C"}
      differences = [65, {:name, "A"}, {:name, "B"}, {:name, "C"}]

      result = Differences.apply(%{}, differences)

      assert result[65] == "A"
      assert result[66] == "B"
      assert result[67] == "C"
    end

    test "multiple integer resets interleaved with names" do
      # [32 /space 65 /A /B] → {32 → "space", 65 → "A", 66 → "B"}
      differences = [32, {:name, "space"}, 65, {:name, "A"}, {:name, "B"}]

      result = Differences.apply(%{}, differences)

      assert result[32] == "space"
      assert result[65] == "A"
      assert result[66] == "B"
      refute Map.has_key?(result, 33)
      refute Map.has_key?(result, 64)
    end

    test "single name at high position" do
      differences = [200, {:name, "uni0024"}]

      result = Differences.apply(%{}, differences)

      assert result[200] == "uni0024"
      assert map_size(result) == 1
    end

    test "empty differences list returns base unchanged" do
      base = %{65 => "A"}

      result = Differences.apply(base, [])

      assert result == base
    end
  end

  # ---- 7.2.2 apply/2 — merging with base overrides ----

  describe "apply/2 merging with base" do
    test "differences override existing base entries" do
      base = %{65 => "space"}
      differences = [65, {:name, "A"}]

      result = Differences.apply(base, differences)

      # /Differences wins over base
      assert result[65] == "A"
    end

    test "base entries not covered by differences are preserved" do
      base = %{32 => "space"}
      differences = [65, {:name, "A"}]

      result = Differences.apply(base, differences)

      assert result[32] == "space"
      assert result[65] == "A"
    end

    test "differences applied on top of populated base" do
      base = %{32 => "space", 65 => "A", 66 => "B"}
      differences = [66, {:name, "Euro"}]

      result = Differences.apply(base, differences)

      assert result[32] == "space"
      assert result[65] == "A"
      # 66 overridden
      assert result[66] == "Euro"
    end
  end
end
