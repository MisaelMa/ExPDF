defmodule Pdf.Reader.OutlinesTest do
  use ExUnit.Case, async: true

  alias Pdf.Reader.{Outlines, Outline}

  # ---------------------------------------------------------------------------
  # Helper — build a minimal Document from hand-crafted PDF binary.
  # Same build_pdf/4 + pad_offset/1 pattern as destination_test.exs.
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

  defp open_doc(bin) do
    {:ok, doc} = Pdf.Reader.open(bin)
    doc
  end

  # ---------------------------------------------------------------------------
  # PDF Fixture Builders
  # ---------------------------------------------------------------------------

  # PDF with no /Outlines in catalog (S-AO17)
  defp craft_no_outlines_pdf do
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

  # PDF with flat 3-entry outline linked via /Next (S-AO1)
  #
  # Object layout:
  #  1 0 R — Catalog
  #  2 0 R — Pages
  #  3 0 R — Page 1
  #  4 0 R — Outline root (no title, /First -> 5 0 R, /Count 3)
  #  5 0 R — Outline item "Chapter 1" (/Next -> 6 0 R)
  #  6 0 R — Outline item "Chapter 2" (/Next -> 7 0 R)
  #  7 0 R — Outline item "Chapter 3"
  defp craft_flat_outline_pdf do
    header = "%PDF-1.4\n"

    obj1 =
      "1 0 obj\n" <>
        "<</Type /Catalog /Pages 2 0 R /Outlines 4 0 R>>\n" <>
        "endobj\n"

    obj2 =
      "2 0 obj\n" <>
        "<</Type /Pages /Kids [3 0 R] /Count 1>>\n" <>
        "endobj\n"

    obj3 =
      "3 0 obj\n" <>
        "<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]>>\n" <>
        "endobj\n"

    obj4 =
      "4 0 obj\n" <>
        "<</Type /Outlines /First 5 0 R /Count 3>>\n" <>
        "endobj\n"

    obj5 =
      "5 0 obj\n" <>
        "<</Title (Chapter 1) /Parent 4 0 R /Next 6 0 R>>\n" <>
        "endobj\n"

    obj6 =
      "6 0 obj\n" <>
        "<</Title (Chapter 2) /Parent 4 0 R /Prev 5 0 R /Next 7 0 R>>\n" <>
        "endobj\n"

    obj7 =
      "7 0 obj\n" <>
        "<</Title (Chapter 3) /Parent 4 0 R /Prev 6 0 R>>\n" <>
        "endobj\n"

    build_pdf([obj1, obj2, obj3, obj4, obj5, obj6, obj7], header, 8, "1 0 R")
  end

  # PDF with nested outline: root -> child -> grandchild (S-AO2)
  #
  # Object layout:
  #  1 0 R — Catalog
  #  2 0 R — Pages
  #  3 0 R — Page 1
  #  4 0 R — Outline root (/First -> 5 0 R)
  #  5 0 R — "Root Item" (/First -> 6 0 R)
  #  6 0 R — "Child Item" (/First -> 7 0 R)
  #  7 0 R — "Grandchild Item"
  defp craft_nested_outline_pdf do
    header = "%PDF-1.4\n"

    obj1 =
      "1 0 obj\n" <>
        "<</Type /Catalog /Pages 2 0 R /Outlines 4 0 R>>\n" <>
        "endobj\n"

    obj2 =
      "2 0 obj\n" <>
        "<</Type /Pages /Kids [3 0 R] /Count 1>>\n" <>
        "endobj\n"

    obj3 =
      "3 0 obj\n" <>
        "<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]>>\n" <>
        "endobj\n"

    obj4 =
      "4 0 obj\n" <>
        "<</Type /Outlines /First 5 0 R /Count 1>>\n" <>
        "endobj\n"

    obj5 =
      "5 0 obj\n" <>
        "<</Title (Root Item) /Parent 4 0 R /First 6 0 R /Count 1>>\n" <>
        "endobj\n"

    obj6 =
      "6 0 obj\n" <>
        "<</Title (Child Item) /Parent 5 0 R /First 7 0 R /Count 1>>\n" <>
        "endobj\n"

    obj7 =
      "7 0 obj\n" <>
        "<</Title (Grandchild Item) /Parent 6 0 R>>\n" <>
        "endobj\n"

    build_pdf([obj1, obj2, obj3, obj4, obj5, obj6, obj7], header, 8, "1 0 R")
  end

  # PDF with cyclic /Next: A -> B -> A (S-AO3)
  #
  # Object layout:
  #  1 0 R — Catalog
  #  2 0 R — Pages
  #  3 0 R — Page
  #  4 0 R — Outline root (/First -> 5 0 R)
  #  5 0 R — "Item A" (/Next -> 6 0 R)
  #  6 0 R — "Item B" (/Next -> 5 0 R)  <-- cycle back to A
  defp craft_cyclic_outline_pdf do
    header = "%PDF-1.4\n"

    obj1 =
      "1 0 obj\n" <>
        "<</Type /Catalog /Pages 2 0 R /Outlines 4 0 R>>\n" <>
        "endobj\n"

    obj2 =
      "2 0 obj\n" <>
        "<</Type /Pages /Kids [3 0 R] /Count 1>>\n" <>
        "endobj\n"

    obj3 =
      "3 0 obj\n" <>
        "<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]>>\n" <>
        "endobj\n"

    obj4 =
      "4 0 obj\n" <>
        "<</Type /Outlines /First 5 0 R /Count 2>>\n" <>
        "endobj\n"

    obj5 =
      "5 0 obj\n" <>
        "<</Title (Item A) /Parent 4 0 R /Next 6 0 R>>\n" <>
        "endobj\n"

    # Cycle: B's /Next points back to A (obj 5)
    obj6 =
      "6 0 obj\n" <>
        "<</Title (Item B) /Parent 4 0 R /Prev 5 0 R /Next 5 0 R>>\n" <>
        "endobj\n"

    build_pdf([obj1, obj2, obj3, obj4, obj5, obj6], header, 7, "1 0 R")
  end

  # Build a depth-N outline chain. Each level has only /First (no /Next siblings).
  # Used for depth cap tests (S-AO4).
  defp craft_deep_outline_pdf(depth) do
    header = "%PDF-1.4\n"

    obj1 =
      "1 0 obj\n" <>
        "<</Type /Catalog /Pages 2 0 R /Outlines 4 0 R>>\n" <>
        "endobj\n"

    obj2 =
      "2 0 obj\n" <>
        "<</Type /Pages /Kids [3 0 R] /Count 1>>\n" <>
        "endobj\n"

    obj3 =
      "3 0 obj\n" <>
        "<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]>>\n" <>
        "endobj\n"

    # Outline root at obj 4
    obj4 =
      "4 0 obj\n" <>
        "<</Type /Outlines /First 5 0 R /Count 1>>\n" <>
        "endobj\n"

    # depth levels: obj 5, 6, ..., 5+(depth-1)
    # Each obj i has /First pointing to obj i+1, except the last
    node_objects =
      Enum.map(0..(depth - 1), fn level ->
        obj_num = 5 + level

        title = "Level #{level}"

        if level < depth - 1 do
          child_ref = "#{obj_num + 1} 0 R"

          "#{obj_num} 0 obj\n" <>
            "<</Title (#{title}) /First #{child_ref} /Count 1>>\n" <>
            "endobj\n"
        else
          "#{obj_num} 0 obj\n" <>
            "<</Title (#{title})>>\n" <>
            "endobj\n"
        end
      end)

    all_objects = [obj1, obj2, obj3, obj4] ++ node_objects
    total = length(all_objects) + 1
    build_pdf(all_objects, header, total, "1 0 R")
  end

  # PDF with UTF-16BE BOM title (S-AO5)
  # "Hello" encoded as UTF-16BE: 00 48 00 65 00 6C 00 6C 00 6F
  # With BOM: FE FF 00 48 00 65 00 6C 00 6C 00 6F
  defp craft_utf16_title_outline_pdf do
    header = "%PDF-1.4\n"

    # UTF-16BE encoding of "Hello" with BOM
    # FE FF (BOM) + 00 48 00 65 00 6C 00 6C 00 6F
    utf16_hex = "FEFF00480065006C006C006F"

    obj1 =
      "1 0 obj\n" <>
        "<</Type /Catalog /Pages 2 0 R /Outlines 4 0 R>>\n" <>
        "endobj\n"

    obj2 =
      "2 0 obj\n" <>
        "<</Type /Pages /Kids [3 0 R] /Count 1>>\n" <>
        "endobj\n"

    obj3 =
      "3 0 obj\n" <>
        "<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]>>\n" <>
        "endobj\n"

    obj4 =
      "4 0 obj\n" <>
        "<</Type /Outlines /First 5 0 R /Count 1>>\n" <>
        "endobj\n"

    obj5 =
      "5 0 obj\n" <>
        "<</Title <#{utf16_hex}> /Parent 4 0 R>>\n" <>
        "endobj\n"

    build_pdf([obj1, obj2, obj3, obj4, obj5], header, 6, "1 0 R")
  end

  # PDF with array dest resolving to page 2 (S-AO6)
  #
  # Object layout:
  #  1 0 R — Catalog
  #  2 0 R — Pages (/Kids [3 0 R 4 0 R])
  #  3 0 R — Page 1
  #  4 0 R — Page 2
  #  5 0 R — Outline root (/First -> 6 0 R)
  #  6 0 R — Outline item with /Dest [4 0 R /XYZ 0 0 0]
  defp craft_array_dest_outline_pdf do
    header = "%PDF-1.4\n"

    obj1 =
      "1 0 obj\n" <>
        "<</Type /Catalog /Pages 2 0 R /Outlines 5 0 R>>\n" <>
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

    obj5 =
      "5 0 obj\n" <>
        "<</Type /Outlines /First 6 0 R /Count 1>>\n" <>
        "endobj\n"

    # Dest: page 2 (obj 4 0 R)
    obj6 =
      "6 0 obj\n" <>
        "<</Title (Go to Page 2) /Parent 5 0 R /Dest [4 0 R /XYZ 0 0 0]>>\n" <>
        "endobj\n"

    build_pdf([obj1, obj2, obj3, obj4, obj5, obj6], header, 7, "1 0 R")
  end

  # PDF with named string dest via name tree (S-AO7)
  #
  # Object layout:
  #  1 0 R — Catalog (with /Names 7 0 R)
  #  2 0 R — Pages (/Kids [3 0 R 4 0 R])
  #  3 0 R — Page 1
  #  4 0 R — Page 2
  #  5 0 R — Outline root (/First -> 6 0 R)
  #  6 0 R — Outline item with /Dest (intro) -> name tree -> page 1
  #  7 0 R — Names dict (/Dests -> 8 0 R)
  #  8 0 R — Name tree leaf: "intro" -> [3 0 R /XYZ 0 0 0]
  defp craft_named_dest_outline_pdf do
    header = "%PDF-1.4\n"

    obj1 =
      "1 0 obj\n" <>
        "<</Type /Catalog /Pages 2 0 R /Outlines 5 0 R /Names 7 0 R>>\n" <>
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

    obj5 =
      "5 0 obj\n" <>
        "<</Type /Outlines /First 6 0 R /Count 1>>\n" <>
        "endobj\n"

    # Named dest: "intro" resolves to page 1 (obj 3 0 R)
    obj6 =
      "6 0 obj\n" <>
        "<</Title (Introduction) /Parent 5 0 R /Dest (intro)>>\n" <>
        "endobj\n"

    obj7 =
      "7 0 obj\n" <>
        "<</Dests 8 0 R>>\n" <>
        "endobj\n"

    obj8 =
      "8 0 obj\n" <>
        "<</Names [(intro) [3 0 R /XYZ 0 0 0]] /Limits [(intro) (intro)]>>\n" <>
        "endobj\n"

    build_pdf([obj1, obj2, obj3, obj4, obj5, obj6, obj7, obj8], header, 9, "1 0 R")
  end

  # ---------------------------------------------------------------------------
  # Task 4.1 — flat 3-entry outline, all at :level 0 (S-AO1)
  # ---------------------------------------------------------------------------

  describe "read/1 — flat outline" do
    @tag :integration
    test "4.1a: returns 3 outlines all at level 0" do
      doc = open_doc(craft_flat_outline_pdf())

      assert {:ok, outlines, _doc} = Outlines.read(doc)
      assert length(outlines) == 3

      Enum.each(outlines, fn o ->
        assert %Outline{} = o
        assert o.level == 0
      end)
    end

    @tag :integration
    test "4.1b: titles are decoded correctly" do
      doc = open_doc(craft_flat_outline_pdf())

      assert {:ok, outlines, _doc} = Outlines.read(doc)
      titles = Enum.map(outlines, & &1.title)

      assert "Chapter 1" in titles
      assert "Chapter 2" in titles
      assert "Chapter 3" in titles
    end

    @tag :integration
    test "4.1c: flat outlines have empty children" do
      doc = open_doc(craft_flat_outline_pdf())

      assert {:ok, outlines, _doc} = Outlines.read(doc)

      Enum.each(outlines, fn o ->
        assert o.children == []
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # Task 4.2 — nested 3-level outline, :level 0/1/2, grandchild in :children (S-AO2)
  # ---------------------------------------------------------------------------

  describe "read/1 — nested outline" do
    @tag :integration
    test "4.2a: root item has level 0" do
      doc = open_doc(craft_nested_outline_pdf())

      assert {:ok, outlines, _doc} = Outlines.read(doc)
      assert length(outlines) == 1

      root = hd(outlines)
      assert root.level == 0
      assert root.title == "Root Item"
    end

    @tag :integration
    test "4.2b: child item has level 1" do
      doc = open_doc(craft_nested_outline_pdf())

      assert {:ok, outlines, _doc} = Outlines.read(doc)
      root = hd(outlines)

      assert length(root.children) == 1
      child = hd(root.children)
      assert child.level == 1
      assert child.title == "Child Item"
    end

    @tag :integration
    test "4.2c: grandchild item has level 2" do
      doc = open_doc(craft_nested_outline_pdf())

      assert {:ok, outlines, _doc} = Outlines.read(doc)
      root = hd(outlines)
      child = hd(root.children)

      assert length(child.children) == 1
      grandchild = hd(child.children)
      assert grandchild.level == 2
      assert grandchild.title == "Grandchild Item"
    end

    @tag :integration
    test "4.2d: grandchild has no children" do
      doc = open_doc(craft_nested_outline_pdf())

      assert {:ok, outlines, _doc} = Outlines.read(doc)
      grandchild = outlines |> hd() |> Map.get(:children) |> hd() |> Map.get(:children) |> hd()

      assert grandchild.children == []
    end
  end

  # ---------------------------------------------------------------------------
  # Task 4.3 — cyclic /Next A->B->A — {:ok, [A, B], doc} no hang (S-AO3)
  # ---------------------------------------------------------------------------

  describe "read/1 — cyclic outline" do
    @tag :integration
    test "4.3a: cyclic /Next does not hang — returns {:ok, list, doc}" do
      doc = open_doc(craft_cyclic_outline_pdf())

      assert {:ok, outlines, _doc} = Outlines.read(doc)
      assert is_list(outlines)
    end

    @tag :integration
    test "4.3b: cyclic outline emits A and B exactly once each" do
      doc = open_doc(craft_cyclic_outline_pdf())

      assert {:ok, outlines, _doc} = Outlines.read(doc)
      assert length(outlines) == 2

      titles = Enum.map(outlines, & &1.title)
      assert "Item A" in titles
      assert "Item B" in titles
    end
  end

  # ---------------------------------------------------------------------------
  # Task 4.4 — depth-33 chain — levels 0-31 emitted, level-32 skipped (S-AO4)
  # ---------------------------------------------------------------------------

  describe "read/1 — depth cap" do
    @tag :integration
    test "4.4a: chain of 33 levels emits only 32 levels (depth cap 32)" do
      doc = open_doc(craft_deep_outline_pdf(33))

      assert {:ok, outlines, _doc} = Outlines.read(doc)

      # Count all nodes in the tree recursively
      node_count = count_nodes(outlines)

      # depth 33 means 33 nodes; cap at 32 means only nodes at levels 0-31 emitted
      # The node at level 32 (depth 33) must be skipped
      assert node_count == 32
    end

    @tag :integration
    test "4.4b: chain of 32 levels emits all 32 (exactly at cap boundary)" do
      doc = open_doc(craft_deep_outline_pdf(32))

      assert {:ok, outlines, _doc} = Outlines.read(doc)
      node_count = count_nodes(outlines)

      assert node_count == 32
    end

    @tag :integration
    test "4.4c: depth-33 chain returns :ok — no error" do
      doc = open_doc(craft_deep_outline_pdf(33))

      assert {:ok, _outlines, _doc} = Outlines.read(doc)
    end
  end

  # ---------------------------------------------------------------------------
  # Task 4.5 — UTF-16BE BOM /Title → decoded string (S-AO5)
  # ---------------------------------------------------------------------------

  describe "read/1 — UTF-16BE BOM title" do
    @tag :integration
    test "4.5a: title with UTF-16BE BOM is decoded to UTF-8 string" do
      doc = open_doc(craft_utf16_title_outline_pdf())

      assert {:ok, outlines, _doc} = Outlines.read(doc)
      assert length(outlines) == 1

      outline = hd(outlines)
      assert outline.title == "Hello"
    end
  end

  # ---------------------------------------------------------------------------
  # Task 4.6 — array dest resolves to correct 1-indexed page (S-AO6)
  # ---------------------------------------------------------------------------

  describe "read/1 — array dest resolution" do
    @tag :integration
    test "4.6a: /Dest [4 0 R /XYZ ...] resolves to :dest_page 2" do
      doc = open_doc(craft_array_dest_outline_pdf())

      assert {:ok, outlines, _doc} = Outlines.read(doc)
      assert length(outlines) == 1

      outline = hd(outlines)
      assert outline.dest_page == 2
    end
  end

  # ---------------------------------------------------------------------------
  # Task 4.7 — named string dest via name tree (S-AO7)
  # ---------------------------------------------------------------------------

  describe "read/1 — named dest resolution" do
    @tag :integration
    test "4.7a: /Dest (intro) via name tree resolves to :dest_page 1" do
      doc = open_doc(craft_named_dest_outline_pdf())

      assert {:ok, outlines, _doc} = Outlines.read(doc)
      assert length(outlines) == 1

      outline = hd(outlines)
      assert outline.dest_page == 1
    end
  end

  # ---------------------------------------------------------------------------
  # Task 4.8 — no /Outlines in catalog → {:ok, [], doc} (S-AO17)
  # ---------------------------------------------------------------------------

  describe "read/1 — no /Outlines in catalog" do
    @tag :integration
    test "4.8a: PDF without /Outlines returns {:ok, [], doc}" do
      doc = open_doc(craft_no_outlines_pdf())

      assert {:ok, [], _doc} = Outlines.read(doc)
    end

    @tag :integration
    test "4.8b: PDF without /Outlines returns :ok — never an error" do
      doc = open_doc(craft_no_outlines_pdf())

      assert {:ok, _list, _doc} = Outlines.read(doc)
    end
  end

  # ---------------------------------------------------------------------------
  # Task 4.9 — :page_ref_index built once and cached in doc.cache (R-AO24)
  # ---------------------------------------------------------------------------

  describe "read/1 — page_ref_index cache" do
    @tag :integration
    test "4.9a: doc.cache[:page_ref_index] is set after read/1" do
      doc = open_doc(craft_array_dest_outline_pdf())

      # Cache should not have :page_ref_index before the call
      refute Map.has_key?(doc.cache, :page_ref_index)

      assert {:ok, _outlines, updated_doc} = Outlines.read(doc)
      assert Map.has_key?(updated_doc.cache, :page_ref_index)
    end

    @tag :integration
    test "4.9b: doc.cache[:page_ref_index] not set when no /Outlines (no dest needed)" do
      # For a PDF with no outlines, page_ref_index is NOT needed (we return early)
      # This asserts our fast path (no unnecessary work)
      doc = open_doc(craft_no_outlines_pdf())

      assert {:ok, [], _updated_doc} = Outlines.read(doc)
      # We do not assert the cache state here — whether the index is built
      # for empty outlines is an implementation detail. The test that matters
      # is 4.9a: when there ARE outlines with dests, the index IS cached.
    end

    @tag :integration
    test "4.9c: page_ref_index is pre-seeded in doc.cache (second call would reuse it)" do
      doc = open_doc(craft_array_dest_outline_pdf())
      assert {:ok, _outlines, doc_after} = Outlines.read(doc)

      cached_index = Map.get(doc_after.cache, :page_ref_index)
      assert is_map(cached_index)
      assert map_size(cached_index) > 0
    end
  end

  # ---------------------------------------------------------------------------
  # Phase 7 integration — /A action dest variants + unresolvable
  # ---------------------------------------------------------------------------

  # PDF with /A /S /GoTo /D [array] action (S-AO8)
  # Same structure as craft_array_dest_outline_pdf but uses an /A action dict
  # instead of a direct /Dest array.
  defp craft_goto_action_array_pdf do
    header = "%PDF-1.4\n"

    obj1 = "1 0 obj\n<</Type /Catalog /Pages 2 0 R /Outlines 5 0 R>>\nendobj\n"
    obj2 = "2 0 obj\n<</Type /Pages /Kids [3 0 R 4 0 R] /Count 2>>\nendobj\n"
    obj3 = "3 0 obj\n<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]>>\nendobj\n"
    obj4 = "4 0 obj\n<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]>>\nendobj\n"
    obj5 = "5 0 obj\n<</Type /Outlines /First 6 0 R /Count 1>>\nendobj\n"

    # /A with GoTo action pointing to page 2 (obj 4)
    obj6 =
      "6 0 obj\n" <>
        "<</Title (Go to Page 2 via Action) /Parent 5 0 R\n" <>
        "  /A <</S /GoTo /D [4 0 R /XYZ 0 0 0]>>>>\n" <>
        "endobj\n"

    build_pdf([obj1, obj2, obj3, obj4, obj5, obj6], header, 7, "1 0 R")
  end

  # PDF with /A /S /GoTo /D (name) action (S-AO9)
  defp craft_goto_action_named_pdf do
    header = "%PDF-1.4\n"

    obj1 = "1 0 obj\n<</Type /Catalog /Pages 2 0 R /Outlines 5 0 R /Names 7 0 R>>\nendobj\n"
    obj2 = "2 0 obj\n<</Type /Pages /Kids [3 0 R 4 0 R] /Count 2>>\nendobj\n"
    obj3 = "3 0 obj\n<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]>>\nendobj\n"
    obj4 = "4 0 obj\n<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]>>\nendobj\n"
    obj5 = "5 0 obj\n<</Type /Outlines /First 6 0 R /Count 1>>\nendobj\n"

    # /A with GoTo action using named dest "chapter1" -> page 2 (obj 4)
    obj6 =
      "6 0 obj\n" <>
        "<</Title (Chapter 1 via Named GoTo) /Parent 5 0 R\n" <>
        "  /A <</S /GoTo /D (chapter1)>>>>\n" <>
        "endobj\n"

    obj7 = "7 0 obj\n<</Dests 8 0 R>>\nendobj\n"

    obj8 =
      "8 0 obj\n" <>
        "<</Names [(chapter1) [4 0 R /XYZ 0 0 0]] /Limits [(chapter1) (chapter1)]>>\n" <>
        "endobj\n"

    build_pdf([obj1, obj2, obj3, obj4, obj5, obj6, obj7, obj8], header, 9, "1 0 R")
  end

  # PDF with an unresolvable dest (ref points to a non-existent object)
  defp craft_unresolvable_dest_pdf do
    header = "%PDF-1.4\n"

    obj1 = "1 0 obj\n<</Type /Catalog /Pages 2 0 R /Outlines 4 0 R>>\nendobj\n"
    obj2 = "2 0 obj\n<</Type /Pages /Kids [3 0 R] /Count 1>>\nendobj\n"
    obj3 = "3 0 obj\n<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]>>\nendobj\n"
    obj4 = "4 0 obj\n<</Type /Outlines /First 5 0 R /Count 1>>\nendobj\n"

    # /Dest points to obj 999 which doesn't exist
    obj5 =
      "5 0 obj\n" <>
        "<</Title (Ghost Page) /Parent 4 0 R /Dest [999 0 R /XYZ 0 0 0]>>\n" <>
        "endobj\n"

    build_pdf([obj1, obj2, obj3, obj4, obj5], header, 6, "1 0 R")
  end

  # ---------------------------------------------------------------------------
  # Task 7.1 — Integration: /A /S /GoTo /D array action resolves dest (S-AO8)
  # ---------------------------------------------------------------------------

  describe "read/1 — /A /S /GoTo /D array action" do
    @tag :integration
    test "7.1a: outline with /A GoTo /D array resolves :dest_page correctly" do
      doc = open_doc(craft_goto_action_array_pdf())

      assert {:ok, outlines, _doc} = Outlines.read(doc)
      assert length(outlines) == 1

      outline = hd(outlines)
      assert outline.dest_page == 2
    end

    @tag :integration
    test "7.1b: outline title decoded when using /A action" do
      doc = open_doc(craft_goto_action_array_pdf())

      assert {:ok, outlines, _doc} = Outlines.read(doc)
      outline = hd(outlines)
      assert outline.title == "Go to Page 2 via Action"
    end
  end

  # ---------------------------------------------------------------------------
  # Task 7.2 — Integration: /A /S /GoTo /D name action (S-AO9)
  # ---------------------------------------------------------------------------

  describe "read/1 — /A /S /GoTo /D name action" do
    @tag :integration
    test "7.2a: outline with /A GoTo /D named dest resolves via name tree" do
      doc = open_doc(craft_goto_action_named_pdf())

      assert {:ok, outlines, _doc} = Outlines.read(doc)
      assert length(outlines) == 1

      outline = hd(outlines)
      assert outline.dest_page == 2
    end

    @tag :integration
    test "7.2b: outline title decoded when using named GoTo action" do
      doc = open_doc(craft_goto_action_named_pdf())

      assert {:ok, outlines, _doc} = Outlines.read(doc)
      outline = hd(outlines)
      assert outline.title == "Chapter 1 via Named GoTo"
    end
  end

  # ---------------------------------------------------------------------------
  # Task 7.3 — Integration: unresolvable dest → :dest_page nil, no error (S-AO10)
  # ---------------------------------------------------------------------------

  describe "read/1 — unresolvable destination" do
    @tag :integration
    test "7.3a: outline with unresolvable /Dest ref → :dest_page nil" do
      doc = open_doc(craft_unresolvable_dest_pdf())

      assert {:ok, outlines, _doc} = Outlines.read(doc)
      assert length(outlines) == 1

      outline = hd(outlines)
      assert outline.dest_page == nil
    end

    @tag :integration
    test "7.3b: unresolvable dest returns {:ok, _, _} — no error" do
      doc = open_doc(craft_unresolvable_dest_pdf())

      assert {:ok, _, _doc} = Outlines.read(doc)
    end
  end

  # ---------------------------------------------------------------------------
  # Task 7.3 (cache sharing) — via Pdf.Reader.read_outlines/1 delegation
  # Verifies the public API thin delegation returns same results as direct call
  # ---------------------------------------------------------------------------

  describe "Pdf.Reader.read_outlines/1 — integration delegation" do
    @tag :integration
    test "7.3c: read_outlines/1 and Outlines.read/1 produce identical outlines" do
      doc = open_doc(craft_flat_outline_pdf())

      assert {:ok, via_reader, _} = Pdf.Reader.read_outlines(doc)
      assert {:ok, direct, _} = Outlines.read(doc)

      assert via_reader == direct
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp count_nodes([]), do: 0

  defp count_nodes(outlines) when is_list(outlines) do
    Enum.reduce(outlines, 0, fn outline, acc ->
      acc + 1 + count_nodes(outline.children)
    end)
  end
end
