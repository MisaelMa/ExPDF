defmodule Pdf.Reader.MetadataTest do
  use ExUnit.Case, async: true

  # ---------------------------------------------------------------------------
  # 9.2.x — read_metadata/1
  #
  # Spec reference: PDF 1.7 § 14.3.3 (Document Information Dictionary)
  # - /Info entry in trailer → Info dict with string keys
  # - Common keys: Title, Author, Subject, Keywords, Creator, Producer,
  #                CreationDate, ModDate
  # - Missing /Info → {:ok, %{}}
  # ---------------------------------------------------------------------------

  describe "Pdf.Reader.read_metadata/1" do
    # 9.2.1 — extracts Title + Author from a writer-generated PDF
    test "extracts Title and Author from writer-generated PDF" do
      bin =
        Pdf.build([size: :a4, compress: false], fn pdf ->
          Pdf.set_info(pdf, title: "Test Doc", author: "Alice")
        end)
        |> Pdf.export()

      {:ok, doc} = Pdf.Reader.open(bin)
      assert {:ok, meta, _updated_doc} = Pdf.Reader.read_metadata(doc)
      assert meta["Title"] == "Test Doc"
      assert meta["Author"] == "Alice"
    end

    # 9.2.2 — no /Info → returns empty map
    test "returns empty map when /Info is absent" do
      # Build a PDF without set_info
      bin =
        Pdf.build([size: :a4, compress: false], fn pdf ->
          Pdf.set_font(pdf, "Helvetica", 12)
          |> Pdf.text_at({72, 720}, "Hello")
        end)
        |> Pdf.export()

      {:ok, doc} = Pdf.Reader.open(bin)
      # Remove /Info from trailer to simulate absent Info dict
      doc_no_info = %{doc | trailer: Map.delete(doc.trailer, "Info")}
      assert {:ok, meta, _updated_doc} = Pdf.Reader.read_metadata(doc_no_info)
      assert meta == %{}
    end

    # threads updated doc
    test "returns an updated doc with cached objects" do
      bin =
        Pdf.build([size: :a4, compress: false], fn pdf ->
          Pdf.set_info(pdf, title: "Cache Test")
        end)
        |> Pdf.export()

      {:ok, doc} = Pdf.Reader.open(bin)
      {:ok, _meta, updated_doc} = Pdf.Reader.read_metadata(doc)
      assert map_size(updated_doc.cache) > 0
    end
  end
end
