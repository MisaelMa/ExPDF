defmodule Pdf.Reader.DestinationTest do
  use ExUnit.Case, async: true

  alias Pdf.Reader.Destination

  # ---------------------------------------------------------------------------
  # Helper — build a minimal Document from hand-crafted PDF binary
  # Mirrors the build_pdf/4 + pad_offset/1 pattern from acroform_test.exs
  # ---------------------------------------------------------------------------

  defp build_pdf(objects, header, size, root_ref) do
    offsets =
      Enum.reduce(objects, {byte_size(header), []}, fn obj, {offset, acc} ->
        {offset + byte_size(obj), [offset | acc]}
      end)
      |> then(fn {_final, reversed} -> Enum.reverse(reversed) end)

    body = Enum.join(objects)
    xref_offset = byte_size(header) + byte_size(body)

    xref_count = length(objects) + 1

    xref_entries =
      Enum.map_join(Enum.zip(1..length(objects), offsets), fn {_n, offset} ->
        pad_offset(offset) <> " 00000 n\r\n"
      end)

    xref =
      "xref\n" <>
        "0 #{xref_count}\n" <>
        "0000000000 65535 f\r\n" <>
        xref_entries

    trailer =
      "trailer\n" <>
        "<</Size #{size} /Root #{root_ref}>>\n" <>
        "startxref\n" <>
        "#{xref_offset}\n" <>
        "%%EOF\n"

    header <> body <> xref <> trailer
  end

  defp pad_offset(n) do
    n |> Integer.to_string() |> String.pad_leading(10, "0")
  end

  # ---------------------------------------------------------------------------
  # Build a PDF with 2 pages and a named dest tree.
  #
  # Object layout:
  #  1 0 R — Catalog (with /Names /Dests and /Pages)
  #  2 0 R — Pages root (2 kids)
  #  3 0 R — Page 1
  #  4 0 R — Page 2
  #  5 0 R — Name tree node (leaf) with single entry: "intro" -> [3 0 R /XYZ 0 0 0]
  #  6 0 R — Names dict with /Dests -> 5 0 R
  # ---------------------------------------------------------------------------

  defp craft_two_page_named_dest_pdf do
    header = "%PDF-1.4\n"

    obj1 =
      "1 0 obj\n" <>
        "<</Type /Catalog /Pages 2 0 R /Names 6 0 R>>\n" <>
        "endobj\n"

    obj2 =
      "2 0 obj\n" <>
        "<</Type /Pages /Kids [3 0 R 4 0 R] /Count 2>>\n" <>
        "endobj\n"

    obj3 =
      "3 0 obj\n" <>
        "<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]>>\n" <>
        "endobj\n"

    obj4 =
      "4 0 obj\n" <>
        "<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]>>\n" <>
        "endobj\n"

    # Leaf name tree node: /Names [<name> <dest_array>]
    # "intro" -> [3 0 R /XYZ 0 0 0]  (page 1, obj 3)
    obj5 =
      "5 0 obj\n" <>
        "<</Names [(intro) [3 0 R /XYZ 0 0 0]]\n" <>
        "  /Limits [(intro) (intro)]>>\n" <>
        "endobj\n"

    obj6 =
      "6 0 obj\n" <>
        "<</Dests 5 0 R>>\n" <>
        "endobj\n"

    build_pdf([obj1, obj2, obj3, obj4, obj5, obj6], header, 7, "1 0 R")
  end

  # A PDF with a name tree that has /Kids (intermediate nodes)
  defp craft_named_dest_with_kids_pdf do
    header = "%PDF-1.4\n"

    obj1 =
      "1 0 obj\n" <>
        "<</Type /Catalog /Pages 2 0 R /Names 7 0 R>>\n" <>
        "endobj\n"

    obj2 =
      "2 0 obj\n" <>
        "<</Type /Pages /Kids [3 0 R 4 0 R] /Count 2>>\n" <>
        "endobj\n"

    obj3 =
      "3 0 obj\n" <>
        "<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]>>\n" <>
        "endobj\n"

    obj4 =
      "4 0 obj\n" <>
        "<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]>>\n" <>
        "endobj\n"

    # Leaf node
    obj5 =
      "5 0 obj\n" <>
        "<</Names [(chapter1) [3 0 R /XYZ 0 0 0]]\n" <>
        "  /Limits [(chapter1) (chapter1)]>>\n" <>
        "endobj\n"

    obj6 =
      "6 0 obj\n" <>
        "<</Names [(chapter2) [4 0 R /XYZ 0 0 0]]\n" <>
        "  /Limits [(chapter2) (chapter2)]>>\n" <>
        "endobj\n"

    # Intermediate node with /Kids
    obj7 =
      "7 0 obj\n" <>
        "<</Dests 8 0 R>>\n" <>
        "endobj\n"

    # Root name tree with /Kids
    obj8 =
      "8 0 obj\n" <>
        "<</Kids [5 0 R 6 0 R]\n" <>
        "  /Limits [(chapter1) (chapter2)]>>\n" <>
        "endobj\n"

    build_pdf([obj1, obj2, obj3, obj4, obj5, obj6, obj7, obj8], header, 9, "1 0 R")
  end

  # A PDF with only a single page (for unresolvable dest tests)
  defp craft_single_page_pdf do
    header = "%PDF-1.4\n"

    obj1 =
      "1 0 obj\n" <>
        "<</Type /Catalog /Pages 2 0 R>>\n" <>
        "endobj\n"

    obj2 =
      "2 0 obj\n" <>
        "<</Type /Pages /Kids [3 0 R] /Count 1>>\n" <>
        "endobj\n"

    obj3 =
      "3 0 obj\n" <>
        "<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]>>\n" <>
        "endobj\n"

    build_pdf([obj1, obj2, obj3], header, 4, "1 0 R")
  end

  # A PDF with 21 levels of /Kids nesting (depth cap test)
  defp craft_deep_name_tree_pdf(depth) do
    header = "%PDF-1.4\n"

    obj2 =
      "2 0 obj\n" <>
        "<</Type /Pages /Kids [3 0 R] /Count 1>>\n" <>
        "endobj\n"

    obj3 =
      "3 0 obj\n" <>
        "<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]>>\n" <>
        "endobj\n"

    # obj 4 = names dict, obj 5 = root of name tree, obj 6..6+depth-1 = chain of intermediate nodes
    # leaf is the deepest node

    # Leaf node at object (5 + depth)
    leaf_obj_n = 5 + depth

    leaf_obj =
      "#{leaf_obj_n} 0 obj\n" <>
        "<</Names [(deep) [3 0 R /XYZ 0 0 0]]>>\n" <>
        "endobj\n"

    # Chain: each intermediate node (from 5+depth-1 down to 5) has one kid
    # Node at obj n+1 is the kid of node at obj n
    intermediate_objects =
      Enum.map((depth - 1)..0//-1, fn level ->
        this_obj = 5 + level
        child_ref = "#{this_obj + 1} 0 R"
        "#{this_obj} 0 obj\n<</Kids [#{child_ref}]>>\nendobj\n"
      end)

    # Names dict at obj 4 — /Dests -> 5 0 R (root)
    names_dict = "4 0 obj\n<</Dests 5 0 R>>\nendobj\n"

    # Rebuild catalog obj1 to point to /Names -> 4 0 R
    obj1_fixed =
      "1 0 obj\n" <>
        "<</Type /Catalog /Pages 2 0 R /Names 4 0 R>>\n" <>
        "endobj\n"

    all_objects = [obj1_fixed, obj2, obj3, names_dict] ++ intermediate_objects ++ [leaf_obj]
    total = length(all_objects) + 1

    build_pdf(all_objects, header, total, "1 0 R")
  end

  # A PDF where the name tree has a cycle (obj 5 kid -> obj 5)
  defp craft_cyclic_name_tree_pdf do
    header = "%PDF-1.4\n"

    obj1 =
      "1 0 obj\n" <>
        "<</Type /Catalog /Pages 2 0 R /Names 4 0 R>>\n" <>
        "endobj\n"

    obj2 =
      "2 0 obj\n" <>
        "<</Type /Pages /Kids [3 0 R] /Count 1>>\n" <>
        "endobj\n"

    obj3 =
      "3 0 obj\n" <>
        "<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]>>\n" <>
        "endobj\n"

    # /Dests -> 5 0 R
    obj4 = "4 0 obj\n<</Dests 5 0 R>>\nendobj\n"

    # Node 5 points to itself via /Kids (cycle!)
    obj5 = "5 0 obj\n<</Kids [5 0 R]>>\nendobj\n"

    build_pdf([obj1, obj2, obj3, obj4, obj5], header, 6, "1 0 R")
  end

  # A PDF with a name tree that has corrupt /Limits (out-of-order, should not matter)
  defp craft_corrupt_limits_pdf do
    header = "%PDF-1.4\n"

    obj1 =
      "1 0 obj\n" <>
        "<</Type /Catalog /Pages 2 0 R /Names 6 0 R>>\n" <>
        "endobj\n"

    obj2 =
      "2 0 obj\n" <>
        "<</Type /Pages /Kids [3 0 R 4 0 R] /Count 2>>\n" <>
        "endobj\n"

    obj3 =
      "3 0 obj\n" <>
        "<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]>>\n" <>
        "endobj\n"

    obj4 =
      "4 0 obj\n" <>
        "<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]>>\n" <>
        "endobj\n"

    # Leaf with corrupt /Limits (reversed order — "zzz" to "aaa")
    obj5 =
      "5 0 obj\n" <>
        "<</Names [(pagedest) [3 0 R /XYZ 0 0 0]]\n" <>
        "  /Limits [(zzz) (aaa)]>>\n" <>
        "endobj\n"

    obj6 =
      "6 0 obj\n" <>
        "<</Dests 5 0 R>>\n" <>
        "endobj\n"

    build_pdf([obj1, obj2, obj3, obj4, obj5, obj6], header, 7, "1 0 R")
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp open_doc(bin) do
    {:ok, doc} = Pdf.Reader.open(bin)
    doc
  end

  # ---------------------------------------------------------------------------
  # Task 3.1 — resolve/3 with array dest [{:ref, n, g} | _rest]
  # Spec: R-AO11, S-AO6
  # ---------------------------------------------------------------------------

  describe "resolve/3 — direct array dest" do
    @tag :unit
    test "3.1a: array dest with known page ref returns 1-indexed page number" do
      doc = open_doc(craft_single_page_pdf())
      # Page 1 is at ref {3, 0} in our single-page PDF
      page_index = %{{3, 0} => 1}
      dest = [{:ref, 3, 0}, {:name, "XYZ"}, 0, 0, 0]

      assert {:ok, 1, ^doc} = Destination.resolve(dest, doc, page_index)
    end

    @tag :unit
    test "3.1b: array dest with second page ref returns page 2" do
      doc = open_doc(craft_two_page_named_dest_pdf())
      page_index = %{{3, 0} => 1, {4, 0} => 2}
      dest = [{:ref, 4, 0}, {:name, "XYZ"}, 0, 0, 0]

      assert {:ok, 2, ^doc} = Destination.resolve(dest, doc, page_index)
    end

    @tag :unit
    test "3.1c: array dest with unknown ref returns nil" do
      doc = open_doc(craft_single_page_pdf())
      page_index = %{{3, 0} => 1}
      dest = [{:ref, 99, 0}, {:name, "XYZ"}, 0, 0, 0]

      assert {:ok, nil, ^doc} = Destination.resolve(dest, doc, page_index)
    end
  end

  # ---------------------------------------------------------------------------
  # Task 3.2 — resolve/3 with named string dest (name tree lookup)
  # Spec: R-AO11, R-AO12, S-AO7
  # ---------------------------------------------------------------------------

  describe "resolve/3 — named string dest" do
    @tag :integration
    test "3.2a: {:string, name} looks up name tree and returns correct page number" do
      bin = craft_two_page_named_dest_pdf()
      doc = open_doc(bin)
      {:ok, page_index, doc} = Destination.ensure_page_index(doc)

      # "intro" -> page 1 (obj 3)
      assert {:ok, 1, _doc} = Destination.resolve({:string, "intro"}, doc, page_index)
    end

    @tag :integration
    test "3.2b: {:string, unknown_name} returns nil (no crash)" do
      bin = craft_two_page_named_dest_pdf()
      doc = open_doc(bin)
      {:ok, page_index, doc} = Destination.ensure_page_index(doc)

      assert {:ok, nil, _doc} = Destination.resolve({:string, "nonexistent"}, doc, page_index)
    end

    @tag :integration
    test "3.2c: {:hex_string, name} also looks up name tree" do
      bin = craft_two_page_named_dest_pdf()
      doc = open_doc(bin)
      {:ok, page_index, doc} = Destination.ensure_page_index(doc)

      # hex_string variant uses same lookup path
      assert {:ok, 1, _doc} = Destination.resolve({:hex_string, "intro"}, doc, page_index)
    end
  end

  # ---------------------------------------------------------------------------
  # Task 3.3 — resolve/3 with /A /S /GoTo /D <array> (action dict, array dest)
  # Spec: R-AO11, S-AO8
  # ---------------------------------------------------------------------------

  describe "resolve/3 — action dict with array dest (GoTo)" do
    @tag :unit
    test "3.3a: action dict %{S: GoTo, D: [ref | rest]} resolves to page number" do
      doc = open_doc(craft_single_page_pdf())
      page_index = %{{3, 0} => 1}

      action_dict = %{
        "S" => {:name, "GoTo"},
        "D" => [{:ref, 3, 0}, {:name, "XYZ"}, 0, 0, 0]
      }

      assert {:ok, 1, ^doc} = Destination.resolve(action_dict, doc, page_index)
    end

    @tag :unit
    test "3.3b: action dict with GoTo and unknown page ref returns nil" do
      doc = open_doc(craft_single_page_pdf())
      page_index = %{{3, 0} => 1}

      action_dict = %{
        "S" => {:name, "GoTo"},
        "D" => [{:ref, 99, 0}, {:name, "XYZ"}, 0, 0, 0]
      }

      assert {:ok, nil, ^doc} = Destination.resolve(action_dict, doc, page_index)
    end
  end

  # ---------------------------------------------------------------------------
  # Task 3.4 — resolve/3 with /A /S /GoTo /D <name> (action dict + name)
  # Spec: R-AO11, S-AO9
  # ---------------------------------------------------------------------------

  describe "resolve/3 — action dict with named dest (GoTo + name)" do
    @tag :integration
    test "3.4a: action dict %{S: GoTo, D: {:string, name}} resolves via name tree" do
      bin = craft_two_page_named_dest_pdf()
      doc = open_doc(bin)
      {:ok, page_index, doc} = Destination.ensure_page_index(doc)

      action_dict = %{
        "S" => {:name, "GoTo"},
        "D" => {:string, "intro"}
      }

      assert {:ok, 1, _doc} = Destination.resolve(action_dict, doc, page_index)
    end

    @tag :unit
    test "3.4b: URI action dict returns {:ok, nil, doc} — not a page dest" do
      doc = open_doc(craft_single_page_pdf())
      page_index = %{{3, 0} => 1}

      action_dict = %{
        "S" => {:name, "URI"},
        "URI" => {:string, "https://example.com"}
      }

      assert {:ok, nil, ^doc} = Destination.resolve(action_dict, doc, page_index)
    end
  end

  # ---------------------------------------------------------------------------
  # Task 3.5 — resolve/3 with unresolvable dest → {:ok, nil, doc}
  # Spec: R-AO13, S-AO10
  # ---------------------------------------------------------------------------

  describe "resolve/3 — unresolvable dest" do
    @tag :unit
    test "3.5a: nil dest returns {:ok, nil, doc}" do
      doc = open_doc(craft_single_page_pdf())
      page_index = %{}

      assert {:ok, nil, ^doc} = Destination.resolve(nil, doc, page_index)
    end

    @tag :unit
    test "3.5b: integer dest (unsupported type) returns {:ok, nil, doc}" do
      doc = open_doc(craft_single_page_pdf())
      page_index = %{}

      assert {:ok, nil, ^doc} = Destination.resolve(42, doc, page_index)
    end

    @tag :unit
    test "3.5c: empty list dest returns {:ok, nil, doc}" do
      doc = open_doc(craft_single_page_pdf())
      page_index = %{}

      assert {:ok, nil, ^doc} = Destination.resolve([], doc, page_index)
    end

    @tag :unit
    test "3.5d: non-GoTo action dict returns {:ok, nil, doc}" do
      doc = open_doc(craft_single_page_pdf())
      page_index = %{}
      action = %{"S" => {:name, "Launch"}, "F" => {:string, "file.pdf"}}

      assert {:ok, nil, ^doc} = Destination.resolve(action, doc, page_index)
    end
  end

  # ---------------------------------------------------------------------------
  # Task 3.7 — ensure_page_index/1 builds index once and caches it
  # Spec: R-AO24
  # ---------------------------------------------------------------------------

  describe "ensure_page_index/1" do
    @tag :integration
    test "3.7a: returns page ref index with correct 1-indexed mapping for single page" do
      doc = open_doc(craft_single_page_pdf())
      {:ok, index, _doc} = Destination.ensure_page_index(doc)

      # Single page PDF — page 1 is at ref {3, 0}
      assert Map.get(index, {3, 0}) == 1
    end

    @tag :integration
    test "3.7b: returns page ref index for two pages in order" do
      doc = open_doc(craft_two_page_named_dest_pdf())
      {:ok, index, _doc} = Destination.ensure_page_index(doc)

      assert Map.get(index, {3, 0}) == 1
      assert Map.get(index, {4, 0}) == 2
    end

    @tag :integration
    test "3.7c: second call hits cache (doc.cache[:page_ref_index] already set)" do
      doc = open_doc(craft_single_page_pdf())
      {:ok, index1, doc_with_cache} = Destination.ensure_page_index(doc)

      # Verify cache was set
      assert Map.has_key?(doc_with_cache.cache, :page_ref_index)

      # Second call returns cached index (same result, no re-computation)
      {:ok, index2, _doc2} = Destination.ensure_page_index(doc_with_cache)

      assert index1 == index2
    end

    @tag :integration
    test "3.7d: returns doc with :page_ref_index in cache after first call" do
      doc = open_doc(craft_single_page_pdf())

      # Cache starts empty for :page_ref_index
      refute Map.has_key?(doc.cache, :page_ref_index)

      {:ok, _index, updated_doc} = Destination.ensure_page_index(doc)

      assert Map.has_key?(updated_doc.cache, :page_ref_index)
    end
  end

  # ---------------------------------------------------------------------------
  # Task 3.9 — build_named_dest_index/1 walks catalog /Names /Dests name tree
  # Spec: R-AO12
  # ---------------------------------------------------------------------------

  describe "build_named_dest_index/1" do
    @tag :integration
    test "3.9a: returns flat map of name -> dest array from simple leaf node" do
      doc = open_doc(craft_two_page_named_dest_pdf())
      {:ok, index, _doc} = Destination.build_named_dest_index(doc)

      assert Map.has_key?(index, "intro")
      # The value should be a list (dest array)
      assert is_list(Map.get(index, "intro"))
    end

    @tag :integration
    test "3.9b: walks /Kids intermediate nodes and collects all leaf entries" do
      doc = open_doc(craft_named_dest_with_kids_pdf())
      {:ok, index, _doc} = Destination.build_named_dest_index(doc)

      assert Map.has_key?(index, "chapter1")
      assert Map.has_key?(index, "chapter2")
    end

    @tag :integration
    test "3.9c: caches result in doc.cache under :named_dest_index" do
      doc = open_doc(craft_two_page_named_dest_pdf())
      {:ok, _index, updated_doc} = Destination.build_named_dest_index(doc)

      assert Map.has_key?(updated_doc.cache, :named_dest_index)
    end

    @tag :integration
    test "3.9d: second call hits cache — returns same map" do
      doc = open_doc(craft_two_page_named_dest_pdf())
      {:ok, index1, doc2} = Destination.build_named_dest_index(doc)
      {:ok, index2, _doc3} = Destination.build_named_dest_index(doc2)

      assert index1 == index2
    end

    @tag :integration
    test "3.9e: returns empty map when catalog has no /Names entry" do
      doc = open_doc(craft_single_page_pdf())
      {:ok, index, _doc} = Destination.build_named_dest_index(doc)

      assert index == %{}
    end

    @tag :integration
    test "3.9f: corrupt /Limits (out-of-order) — still walks the node, no crash" do
      doc = open_doc(craft_corrupt_limits_pdf())
      {:ok, index, _doc} = Destination.build_named_dest_index(doc)

      # Should still find the entry despite corrupt Limits
      assert Map.has_key?(index, "pagedest")
    end

    @tag :integration
    test "3.9g: depth cap 20 — node at depth 21 is skipped, no crash" do
      # depth=21 means 21 levels of /Kids before the leaf
      doc = open_doc(craft_deep_name_tree_pdf(21))
      # Should not crash, should return empty or partial index (leaf skipped)
      assert {:ok, _index, _doc} = Destination.build_named_dest_index(doc)
    end

    @tag :integration
    test "3.9h: depth 19 — leaf at depth 19 is included" do
      doc = open_doc(craft_deep_name_tree_pdf(19))
      {:ok, index, _doc} = Destination.build_named_dest_index(doc)

      # leaf IS within depth 20, so it should be found
      assert Map.has_key?(index, "deep")
    end

    @tag :integration
    test "3.9i: cycle detection — MapSet prevents infinite loop" do
      doc = open_doc(craft_cyclic_name_tree_pdf())
      # Should terminate without hanging
      assert {:ok, _index, _doc} = Destination.build_named_dest_index(doc)
    end
  end
end
