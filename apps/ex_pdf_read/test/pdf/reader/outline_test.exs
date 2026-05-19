defmodule Pdf.Reader.OutlineTest do
  use ExUnit.Case, async: true

  alias Pdf.Reader.Outline

  # ---------------------------------------------------------------------------
  # Task 2.1 — Outline struct — field presence, default values, typespec shape
  # Spec: R-AO9, R-AO10
  # PDF 1.7 § 12.3.3 — Document Outline
  # ---------------------------------------------------------------------------

  describe "%Pdf.Reader.Outline{} defaults" do
    @tag :unit
    test ":title defaults to nil" do
      assert %Outline{}.title == nil
    end

    @tag :unit
    test ":level defaults to 0" do
      assert %Outline{}.level == 0
    end

    @tag :unit
    test ":dest_page defaults to nil" do
      assert %Outline{}.dest_page == nil
    end

    @tag :unit
    test ":children defaults to empty list" do
      assert %Outline{}.children == []
    end

    @tag :unit
    test "struct has exactly the four specified fields" do
      fields = %Outline{} |> Map.from_struct() |> Map.keys() |> Enum.sort()
      assert fields == [:children, :dest_page, :level, :title]
    end
  end

  describe "%Pdf.Reader.Outline{} field assignment" do
    @tag :unit
    test ":title accepts a string" do
      assert %Outline{title: "Chapter 1"}.title == "Chapter 1"
    end

    @tag :unit
    test ":level accepts a non-negative integer" do
      assert %Outline{level: 2}.level == 2
    end

    @tag :unit
    test ":dest_page accepts a positive integer" do
      assert %Outline{dest_page: 5}.dest_page == 5
    end

    @tag :unit
    test ":children accepts a list of Outline structs" do
      child = %Outline{title: "Section 1.1", level: 1}
      parent = %Outline{title: "Chapter 1", level: 0, children: [child]}
      assert [%Outline{title: "Section 1.1", level: 1}] = parent.children
    end

    @tag :unit
    test "nested children can themselves have children (recursive)" do
      grandchild = %Outline{title: "Sub-section", level: 2}
      child = %Outline{title: "Section", level: 1, children: [grandchild]}
      parent = %Outline{title: "Chapter", level: 0, children: [child]}
      assert [%Outline{children: [%Outline{level: 2}]}] = parent.children
    end
  end
end
