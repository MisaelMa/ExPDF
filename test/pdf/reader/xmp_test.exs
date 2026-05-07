defmodule Pdf.Reader.XMPTest do
  use ExUnit.Case, async: true

  alias Pdf.Reader.XMP

  # Spec references:
  # - PDF 1.7 (ISO 32000-1) § 14.3.2 — Metadata Streams
  # - XMP Specification Part 1: https://github.com/adobe/xmp-docs/raw/master/XMPSpecificationPart1.pdf
  # - W3C RDF/XML Syntax: https://www.w3.org/TR/rdf-syntax-grammar/
  #
  # Control points: namespace URIs are sourced from the above specs directly.
  # Values in tests are asserted against known Unicode strings, not implementation output.

  # ---------------------------------------------------------------------------
  # Test helpers
  # ---------------------------------------------------------------------------

  defp wrap_xmp(inner_rdf) do
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <x:xmpmeta xmlns:x="adobe:ns:meta/">
      <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
               xmlns:dc="http://purl.org/dc/elements/1.1/"
               xmlns:xmp="http://ns.adobe.com/xap/1.0/"
               xmlns:pdf="http://ns.adobe.com/pdf/1.3/">
        #{inner_rdf}
      </rdf:RDF>
    </x:xmpmeta>
    """
  end

  # ---------------------------------------------------------------------------
  # 6.1 — dc:title in rdf:Alt → "Title" key
  # → R-XMP7, R-XMP8, S-CW6
  # ---------------------------------------------------------------------------

  describe "parse/1 — dc:title rdf:Alt (task 6.1)" do
    test "returns Title key from dc:title rdf:Alt with x-default lang" do
      xml =
        wrap_xmp("""
        <rdf:Description>
          <dc:title>
            <rdf:Alt>
              <rdf:li xml:lang="x-default">Hello</rdf:li>
            </rdf:Alt>
          </dc:title>
        </rdf:Description>
        """)

      assert {:ok, %{"Title" => "Hello"}} = XMP.parse(xml)
    end

    test "returns empty map when no known properties are present" do
      xml =
        wrap_xmp("""
        <rdf:Description>
        </rdf:Description>
        """)

      assert {:ok, %{}} = XMP.parse(xml)
    end
  end

  # ---------------------------------------------------------------------------
  # 6.2 — dc:creator rdf:Bag with two elements — only first → "Author"
  # → R-XMP4, R-XMP7, S-CW9
  # ---------------------------------------------------------------------------

  describe "parse/1 — dc:creator rdf:Bag first-only (task 6.2)" do
    test "maps dc:creator Bag to Author key using only first element" do
      xml =
        wrap_xmp("""
        <rdf:Description>
          <dc:creator>
            <rdf:Bag>
              <rdf:li>Alice</rdf:li>
              <rdf:li>Bob</rdf:li>
            </rdf:Bag>
          </dc:creator>
        </rdf:Description>
        """)

      assert {:ok, result} = XMP.parse(xml)
      assert result["Author"] == "Alice"
      refute Map.has_key?(result, "Bob")
    end
  end

  # ---------------------------------------------------------------------------
  # 6.3 — dc:description rdf:Alt → "Description" key (distinct from "Subject")
  # → R-XMP5, R-XMP7, S-CW10
  # ---------------------------------------------------------------------------

  describe "parse/1 — dc:description rdf:Alt → Description key (task 6.3)" do
    test "maps dc:description to Description key, not Subject" do
      xml =
        wrap_xmp("""
        <rdf:Description>
          <dc:description>
            <rdf:Alt>
              <rdf:li xml:lang="x-default">An abstract.</rdf:li>
            </rdf:Alt>
          </dc:description>
        </rdf:Description>
        """)

      assert {:ok, result} = XMP.parse(xml)
      assert result["Description"] == "An abstract."
      refute Map.has_key?(result, "Subject")
    end
  end

  # ---------------------------------------------------------------------------
  # 6.4 — dc:subject rdf:Bag → "Subject" key
  # → R-XMP7, S-CW10
  # ---------------------------------------------------------------------------

  describe "parse/1 — dc:subject rdf:Bag → Subject key (task 6.4)" do
    test "maps dc:subject Bag first element to Subject key" do
      xml =
        wrap_xmp("""
        <rdf:Description>
          <dc:subject>
            <rdf:Bag>
              <rdf:li>keyword1</rdf:li>
              <rdf:li>keyword2</rdf:li>
            </rdf:Bag>
          </dc:subject>
        </rdf:Description>
        """)

      assert {:ok, result} = XMP.parse(xml)
      assert result["Subject"] == "keyword1"
    end

    test "both Description and Subject keys are distinct when both present" do
      xml =
        wrap_xmp("""
        <rdf:Description>
          <dc:description>
            <rdf:Alt>
              <rdf:li xml:lang="x-default">An abstract.</rdf:li>
            </rdf:Alt>
          </dc:description>
          <dc:subject>
            <rdf:Bag>
              <rdf:li>keyword1</rdf:li>
            </rdf:Bag>
          </dc:subject>
        </rdf:Description>
        """)

      assert {:ok, result} = XMP.parse(xml)
      assert result["Description"] == "An abstract."
      assert result["Subject"] == "keyword1"
    end
  end

  # ---------------------------------------------------------------------------
  # 6.5 — xmp:CreateDate simple text → "CreationDate" key
  # → R-XMP7
  # ---------------------------------------------------------------------------

  describe "parse/1 — xmp:CreateDate simple text (task 6.5)" do
    test "maps xmp:CreateDate to CreationDate key" do
      xml =
        wrap_xmp("""
        <rdf:Description>
          <xmp:CreateDate>2024-01-15T10:30:00</xmp:CreateDate>
        </rdf:Description>
        """)

      assert {:ok, result} = XMP.parse(xml)
      assert result["CreationDate"] == "2024-01-15T10:30:00"
    end
  end

  # ---------------------------------------------------------------------------
  # 6.6 — pdf:Producer simple text → "Producer" key
  # → R-XMP7
  # ---------------------------------------------------------------------------

  describe "parse/1 — pdf:Producer simple text (task 6.6)" do
    test "maps pdf:Producer to Producer key" do
      xml =
        wrap_xmp("""
        <rdf:Description>
          <pdf:Producer>Adobe Acrobat 11.0</pdf:Producer>
        </rdf:Description>
        """)

      assert {:ok, result} = XMP.parse(xml)
      assert result["Producer"] == "Adobe Acrobat 11.0"
    end
  end

  # ---------------------------------------------------------------------------
  # 6.7 — custom namespace prefix (URI matching, not prefix string)
  # → R-XMP6, R-XMP7
  # ---------------------------------------------------------------------------

  describe "parse/1 — custom namespace prefix URI matching (task 6.7)" do
    test "returns Title when dc namespace is declared with custom prefix" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <x:xmpmeta xmlns:x="adobe:ns:meta/">
        <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                 xmlns:dublincore="http://purl.org/dc/elements/1.1/">
          <rdf:Description>
            <dublincore:title>
              <rdf:Alt>
                <rdf:li xml:lang="x-default">Custom Prefix Title</rdf:li>
              </rdf:Alt>
            </dublincore:title>
          </rdf:Description>
        </rdf:RDF>
      </x:xmpmeta>
      """

      assert {:ok, result} = XMP.parse(xml)
      assert result["Title"] == "Custom Prefix Title"
    end
  end

  # ---------------------------------------------------------------------------
  # 6.8 — malformed XML → {:error, :malformed_xmp} without raising
  # → R-XMP3, S-CW8
  # ---------------------------------------------------------------------------

  describe "parse/1 — malformed XML (task 6.8)" do
    test "returns error tuple for non-XML input without raising" do
      result = XMP.parse("this is not xml")
      assert result == {:error, :malformed_xmp}
    end

    test "returns error tuple for unclosed tag without raising" do
      result = XMP.parse("<unclosed")
      assert result == {:error, :malformed_xmp}
    end

    test "returns error tuple for empty binary without raising" do
      result = XMP.parse("")
      assert result == {:error, :malformed_xmp}
    end
  end

  # ---------------------------------------------------------------------------
  # 6.9 — empty rdf:RDF document → {:ok, %{}}
  # → R-XMP8
  # ---------------------------------------------------------------------------

  describe "parse/1 — empty rdf:RDF (task 6.9)" do
    test "returns ok with empty map for empty rdf:RDF self-closing element" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <x:xmpmeta xmlns:x="adobe:ns:meta/">
        <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" />
      </x:xmpmeta>
      """

      assert {:ok, %{}} = XMP.parse(xml)
    end

    test "returns ok with empty map for rdf:RDF with empty Description" do
      xml =
        wrap_xmp("""
        <rdf:Description rdf:about="">
        </rdf:Description>
        """)

      assert {:ok, %{}} = XMP.parse(xml)
    end
  end
end
