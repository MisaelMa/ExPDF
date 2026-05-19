defmodule Pdf.Reader.PageTest do
  use ExUnit.Case, async: true

  alias Pdf.Reader.Page
  alias Pdf.Reader.Document

  # ---------------------------------------------------------------------------
  # 9.1.1 Page tree walker — list_refs/1
  #
  # Spec reference: PDF 1.7 § 7.7.3 (Page Tree)
  # A Pages node has /Type /Pages, /Kids [refs], /Count integer.
  # A Page leaf has /Type /Page.
  # We walk /Kids recursively, collecting leaf pages in order.
  # ---------------------------------------------------------------------------

  describe "Page.list_refs/1" do
    # 9.1.1 — single-page flat tree
    test "returns single page ref from a flat 1-page tree" do
      doc = build_one_page_doc()
      assert {:ok, refs, _updated_doc} = Page.list_refs(doc)
      assert length(refs) == 1
      assert [{12, 0}] = refs
    end

    # 9.1.1 — multi-page flat tree
    test "returns page refs in order for a flat 3-page tree" do
      doc = build_three_page_doc()
      assert {:ok, refs, _updated_doc} = Page.list_refs(doc)
      assert length(refs) == 3
      # page refs in document order
      assert [{2, 0}, {3, 0}, {4, 0}] = refs
    end

    # 9.1.2 — nested Pages tree
    test "walks nested /Pages nodes recursively" do
      doc = build_nested_pages_doc()
      assert {:ok, refs, _updated_doc} = Page.list_refs(doc)
      assert length(refs) == 2
      assert [{3, 0}, {4, 0}] = refs
    end

    # error case: missing /Root
    test "returns error when trailer has no /Root" do
      doc = %Document{
        binary: "",
        version: "1.4",
        xref: %{},
        trailer: %{},
        cache: %{}
      }

      assert {:error, _reason} = Page.list_refs(doc)
    end

    # threads doc — cache populated after call
    test "updated doc has cached objects from traversal" do
      doc = build_one_page_doc()
      {:ok, _refs, updated_doc} = Page.list_refs(doc)
      # Cache should have the catalog, pages, and page objects
      assert map_size(updated_doc.cache) > 0
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers — build in-memory documents without a full PDF binary
  # ---------------------------------------------------------------------------

  # We embed resolved values directly in the cache so ObjectResolver
  # can return them without touching the binary (empty binary is fine).

  defp build_one_page_doc do
    # Catalog → {1,0}: %{"Type" => {:name, "Catalog"}, "Pages" => {:ref, 1, 0}}
    # wait — let's use distinct object numbers:
    # {10,0} = Catalog, {11,0} = Pages node, {12,0} = Page leaf
    # trailer.Root = {:ref, 10, 0}

    xref = %{
      {10, 0} => {:in_use, 9999, 0},
      {11, 0} => {:in_use, 9998, 0},
      {12, 0} => {:in_use, 9997, 0}
    }

    cache = %{
      {10, 0} => %{"Type" => {:name, "Catalog"}, "Pages" => {:ref, 11, 0}},
      {11, 0} => %{
        "Type" => {:name, "Pages"},
        "Kids" => [{:ref, 12, 0}],
        "Count" => 1
      },
      {12, 0} => %{"Type" => {:name, "Page"}}
    }

    %Document{
      binary: "",
      version: "1.4",
      xref: xref,
      trailer: %{"Root" => {:ref, 10, 0}},
      cache: cache
    }
  end

  defp build_three_page_doc do
    xref = %{
      {10, 0} => {:in_use, 9999, 0},
      {11, 0} => {:in_use, 9998, 0},
      {1, 0} => {:in_use, 9997, 0},
      {2, 0} => {:in_use, 9996, 0},
      {3, 0} => {:in_use, 9995, 0},
      {4, 0} => {:in_use, 9994, 0}
    }

    cache = %{
      {10, 0} => %{"Type" => {:name, "Catalog"}, "Pages" => {:ref, 11, 0}},
      {11, 0} => %{
        "Type" => {:name, "Pages"},
        "Kids" => [{:ref, 2, 0}, {:ref, 3, 0}, {:ref, 4, 0}],
        "Count" => 3
      },
      {2, 0} => %{"Type" => {:name, "Page"}},
      {3, 0} => %{"Type" => {:name, "Page"}},
      {4, 0} => %{"Type" => {:name, "Page"}}
    }

    %Document{
      binary: "",
      version: "1.4",
      xref: xref,
      trailer: %{"Root" => {:ref, 10, 0}},
      cache: cache
    }
  end

  defp build_nested_pages_doc do
    # Root catalog → Pages root → Kids: [intermediate Pages node]
    # intermediate → Kids: [Page, Page]
    xref = %{
      {10, 0} => {:in_use, 9999, 0},
      {11, 0} => {:in_use, 9998, 0},
      {2, 0} => {:in_use, 9997, 0},
      {3, 0} => {:in_use, 9996, 0},
      {4, 0} => {:in_use, 9995, 0}
    }

    cache = %{
      {10, 0} => %{"Type" => {:name, "Catalog"}, "Pages" => {:ref, 11, 0}},
      {11, 0} => %{
        "Type" => {:name, "Pages"},
        "Kids" => [{:ref, 2, 0}],
        "Count" => 2
      },
      {2, 0} => %{
        "Type" => {:name, "Pages"},
        "Kids" => [{:ref, 3, 0}, {:ref, 4, 0}],
        "Count" => 2
      },
      {3, 0} => %{"Type" => {:name, "Page"}},
      {4, 0} => %{"Type" => {:name, "Page"}}
    }

    %Document{
      binary: "",
      version: "1.4",
      xref: xref,
      trailer: %{"Root" => {:ref, 10, 0}},
      cache: cache
    }
  end
end
