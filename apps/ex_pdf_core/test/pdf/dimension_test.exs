defmodule Pdf.DimensionTest do
  use ExUnit.Case, async: true

  alias Pdf.Dimension

  describe "resolve/2" do
    test ":full returns parent dimension" do
      assert Dimension.resolve(:full, 400) == 400
    end

    test "percentage string returns fraction of parent" do
      assert Dimension.resolve("50%", 400) == 200.0
      assert Dimension.resolve("100%", 300) == 300.0
      assert Dimension.resolve("25%", 800) == 200.0
    end

    test "absolute number passes through" do
      assert Dimension.resolve(200, 400) == 200
      assert Dimension.resolve(0, 400) == 0
    end

    test "invalid percentage raises" do
      assert_raise ArgumentError, fn ->
        Dimension.resolve("abc", 400)
      end
    end
  end

  describe "resolve_size/2" do
    test "resolves both dimensions" do
      assert Dimension.resolve_size({:full, "50%"}, %{width: 400, height: 300}) == {400, 150.0}
    end

    test "mixed absolute and relative" do
      assert Dimension.resolve_size({200, :full}, %{width: 400, height: 300}) == {200, 300}
    end

    test "all absolute passes through" do
      assert Dimension.resolve_size({200, 100}, %{width: 400, height: 300}) == {200, 100}
    end
  end

  describe "relative?/1" do
    test ":full is relative" do
      assert Dimension.relative?(:full)
    end

    test "percentage string is relative" do
      assert Dimension.relative?("50%")
    end

    test "number is not relative" do
      refute Dimension.relative?(200)
    end
  end

  describe "needs_resolution?/1" do
    test "returns true when width is relative" do
      assert Dimension.needs_resolution?({:full, 100})
    end

    test "returns true when height is relative" do
      assert Dimension.needs_resolution?({100, "50%"})
    end

    test "returns false when both absolute" do
      refute Dimension.needs_resolution?({200, 100})
    end
  end
end
