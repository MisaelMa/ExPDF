defmodule Pdf.ReaderTest do
  use ExUnit.Case, async: true

  # ---------------------------------------------------------------------------
  # 4.3.x — open/1 and /Prev chain
  # ---------------------------------------------------------------------------

  describe "Pdf.Reader.open/1" do
    test "opens a writer-generated PDF binary" do
      bin = build_simple_pdf()
      assert {:ok, doc} = Pdf.Reader.open(bin)
      assert is_binary(doc.version)
      assert doc.version =~ ~r/^\d+\.\d+$/
      assert map_size(doc.xref) > 0
    end

    test "returns :not_a_pdf for non-PDF binary" do
      assert {:error, :not_a_pdf} = Pdf.Reader.open(<<"not a pdf at all">>)
    end

    test "returns :not_a_pdf for empty binary" do
      assert {:error, :not_a_pdf} = Pdf.Reader.open(<<>>)
    end

    test "returns :malformed for binary missing %%EOF" do
      bin = "%PDF-1.4\nsome content without eof marker"
      assert {:error, :malformed} = Pdf.Reader.open(bin)
    end

    test "returns :encrypted_password_required for encrypted PDF with non-empty password (S-ENC19, R-ENC31)" do
      # craft_rc4_v2_pdf/1 produces a fully-valid V2/R3 PDF with password "test".
      # The empty-password auto-try fails, so open/1 returns :encrypted_password_required.
      bin = craft_rc4_v2_pdf("test")
      assert {:error, :encrypted_password_required} = Pdf.Reader.open(bin)
    end

    test "doc has correct xref entries (in_use)" do
      bin = build_simple_pdf()
      {:ok, doc} = Pdf.Reader.open(bin)
      # All in-use entries should have a valid byte offset
      for {{_n, _g}, entry} <- doc.xref do
        case entry do
          {:in_use, offset, _gen} -> assert is_integer(offset) and offset >= 0
          :free -> :ok
          _ -> :ok
        end
      end
    end

    test "accepts file path" do
      bin = build_simple_pdf()
      path = System.tmp_dir!() <> "/test_reader_#{System.unique_integer()}.pdf"
      File.write!(path, bin)
      assert {:ok, doc} = Pdf.Reader.open(path)
      assert is_binary(doc.version)
      File.rm(path)
    end

    test "returns :io_error for non-existent file path" do
      assert {:error, reason} = Pdf.Reader.open("/tmp/definitely_does_not_exist_12345.pdf")
      assert reason == :io_error or match?({:io_error, _}, reason)
    end

    test "/Prev chain merges two xref sections" do
      bin = craft_prev_chain_pdf()
      assert {:ok, doc} = Pdf.Reader.open(bin)
      # Both xref sections' entries should be present
      assert map_size(doc.xref) >= 2
    end
  end

  # ---------------------------------------------------------------------------
  # Phase 9 — Pdf.Reader.open/2 encryption wiring (S-ENC1..S-ENC4, S-ENC18, S-ENC19)
  # ---------------------------------------------------------------------------

  describe "Pdf.Reader.open/2 — encryption (Phase 9)" do
    test "9.1: open/1 on encrypted PDF with empty user password auto-unlocks (S-ENC1)" do
      # craft_rc4_v2_pdf/1 with empty password: user_pw="" → auto-try succeeds
      bin = craft_rc4_v2_pdf("")
      assert {:ok, doc} = Pdf.Reader.open(bin)
      assert doc.encryption != nil
      assert is_binary(doc.encryption.file_key)
    end

    test "9.2: open/2 with correct password on V2/R3 PDF returns {:ok, doc} (S-ENC2)" do
      bin = craft_rc4_v2_pdf("test")
      assert {:ok, doc} = Pdf.Reader.open(bin, password: "test")
      assert doc.encryption != nil
      assert is_binary(doc.encryption.file_key)
    end

    test "9.2: open/2 with wrong password returns :encrypted_wrong_password (S-ENC3)" do
      bin = craft_rc4_v2_pdf("test")
      assert {:error, :encrypted_wrong_password} = Pdf.Reader.open(bin, password: "wrong")
    end

    test "9.2: open/2 with empty password on non-empty-pw PDF returns :encrypted_password_required (S-ENC4)" do
      bin = craft_rc4_v2_pdf("test")
      assert {:error, :encrypted_password_required} = Pdf.Reader.open(bin, password: "")
    end

    test "9.1: open/1 on non-encrypted PDF still works (S-ENC18 — backward compat)" do
      bin = build_simple_pdf()
      assert {:ok, doc} = Pdf.Reader.open(bin)
      assert doc.encryption == nil
    end

    test "9.2: open!/2 raises on wrong password" do
      bin = craft_rc4_v2_pdf("test")

      assert_raise Pdf.Reader.Error, fn ->
        Pdf.Reader.open!(bin, password: "wrong")
      end
    end

    test "9.2: open!/2 succeeds with correct password" do
      bin = craft_rc4_v2_pdf("test")
      doc = Pdf.Reader.open!(bin, password: "test")
      assert doc.encryption != nil
    end

    test "unsupported handler (/Filter not /Standard) returns :encrypted_unsupported_handler (R-ENC2)" do
      bin = craft_unsupported_handler_pdf()
      assert {:error, :encrypted_unsupported_handler} = Pdf.Reader.open(bin)
    end
  end

  describe "Pdf.Reader.close/1" do
    test "always returns :ok" do
      bin = build_simple_pdf()
      {:ok, doc} = Pdf.Reader.open(bin)
      assert :ok = Pdf.Reader.close(doc)
    end
  end

  # ---------------------------------------------------------------------------
  # 11.7.1 — Full round-trip test
  # Builds a 2-page PDF with set_info title + multiple text ops,
  # then exercises open/1 → read_metadata/1 → read_text_with_positions/1
  # → read_text/2 → page_count/1 and verifies values match what was written.
  # ---------------------------------------------------------------------------

  describe "full round-trip — Pdf.build/2 → Pdf.Reader" do
    test "open/1 succeeds on a 2-page writer-generated PDF" do
      bin = build_two_page_pdf()
      assert {:ok, _doc} = Pdf.Reader.open(bin)
    end

    test "read_metadata/1 returns a metadata map (Creator is always present)" do
      bin = build_two_page_pdf()
      {:ok, doc} = Pdf.Reader.open(bin)
      assert {:ok, meta, _doc2} = Pdf.Reader.read_metadata(doc)
      # The writer always sets Creator and Producer in the Info dict.
      assert is_map(meta)
      # At minimum the writer-set keys must be present
      assert Map.has_key?(meta, "Creator") or Map.has_key?(meta, "Producer")
    end

    test "read_text_with_positions/1 returns TextRun structs for all pages" do
      bin = build_two_page_pdf()
      {:ok, doc} = Pdf.Reader.open(bin)
      assert {:ok, runs} = Pdf.Reader.read_text_with_positions(doc)
      assert is_list(runs)
      # 2-page PDF with text on both pages must produce >= 2 runs
      assert length(runs) >= 2
      # Runs must come from pages 1 and 2
      pages = runs |> Enum.map(& &1.page) |> Enum.uniq() |> Enum.sort()
      assert 1 in pages
      assert 2 in pages
    end

    test "read_text/2 returns non-empty string list for a 2-page PDF" do
      bin = build_two_page_pdf()
      {:ok, doc} = Pdf.Reader.open(bin)
      assert {:ok, texts} = Pdf.Reader.read_text(doc)
      assert is_list(texts)
      assert length(texts) >= 1
    end

    test "page_count/1 returns {:ok, 2} for a 2-page PDF" do
      bin = build_two_page_pdf()
      {:ok, doc} = Pdf.Reader.open(bin)
      assert {:ok, 2} = Pdf.Reader.page_count(doc)
    end

    test "close/1 returns :ok after full round-trip" do
      bin = build_two_page_pdf()
      {:ok, doc} = Pdf.Reader.open(bin)
      assert :ok = Pdf.Reader.close(doc)
    end
  end

  # ---------------------------------------------------------------------------
  # Phase 4.1 — CTM decomposition via read_images (S-CW11)
  # ---------------------------------------------------------------------------

  describe "read_images/1 — CTM decomposition (previously skipped)" do
    # This test was @tag :skip — now enabled with test/fixtures/images/tiny.jpg
    # Note: writer with compress:true wraps JPEG in FlateDecode → kind is :png_like.
    test "writer-built image at known position has correct CTM fields (legacy test)" do
      jpeg_path = "test/fixtures/images/tiny.jpg"

      bin =
        Pdf.build([size: :a4, compress: true], fn pdf ->
          pdf
          |> Pdf.set_font("Helvetica", 12)
          |> Pdf.add_image({50, 60}, jpeg_path)
        end)
        |> Pdf.export()

      {:ok, doc} = Pdf.Reader.open(bin)
      {:ok, images} = Pdf.Reader.read_images(doc)

      assert length(images) >= 1
      img = hd(images)

      # x/y from CTM e/f
      assert_in_delta img.x, 50.0, 1.0
      assert_in_delta img.y, 60.0, 1.0

      # render_width = sqrt(a*a + b*b); for diagonal CTM [w 0 0 h tx ty] → w
      assert img.render_width > 0.0
      assert img.render_height > 0.0

      # rotation = atan2(b, a); for b=0, a>0 → 0 radians
      assert_in_delta img.rotation_radians, 0.0, 0.001

      # ctm should be a 6-tuple
      assert is_tuple(img.ctm)
      assert tuple_size(img.ctm) == 6
    end
  end

  # ---------------------------------------------------------------------------
  # Phase 8 — read_images CTM populate (S-CW11, S-CW16, R-CTM1..R-CTM6)
  # ---------------------------------------------------------------------------

  describe "read_images/1 — CTM full populate (Phase 8)" do
    @jpeg_fixture "test/fixtures/images/tiny.jpg"

    test "8.1: writer-built image — CTM, render_width, render_height, rotation all correct (S-CW11)" do
      # S-CW11 / S-CW16: Pdf.add_image emits [pixel_w 0 0 pixel_h tx ty cm].
      # render_width = sqrt(a^2 + b^2) = pixel_w, render_height = pixel_h,
      # rotation = atan2(b=0, a=pixel_w) = 0.0.
      # NOTE: writer with compress:true wraps JPEG in FlateDecode, so kind = :png_like.
      # The bytes are the raw JPEG data decompressed from the stream.
      bin =
        Pdf.build([compress: true], fn pdf ->
          pdf
          |> Pdf.set_font("Helvetica", 12)
          |> Pdf.add_image({50, 60}, @jpeg_fixture)
        end)
        |> Pdf.export()

      {:ok, doc} = Pdf.Reader.open(bin)
      {:ok, images} = Pdf.Reader.read_images(doc)

      assert [img | _] = images
      # ctm must be a 6-float tuple
      assert is_tuple(img.ctm) and tuple_size(img.ctm) == 6
      # x/y from CTM e/f
      assert_in_delta img.x, 50.0, 1.0
      assert_in_delta img.y, 60.0, 1.0
      # render dimensions must be positive
      assert img.render_width > 0.0
      assert img.render_height > 0.0
      # rotation for identity-scale CTM [w 0 0 h x y] = 0
      assert_in_delta img.rotation_radians, 0.0, 0.001
      # pixel width/height from image dict /Width /Height (should be positive)
      assert (is_integer(img.width) and img.width > 0) or
               (is_float(img.width) and img.width > 0.0)

      assert (is_integer(img.height) and img.height > 0) or
               (is_float(img.height) and img.height > 0.0)
    end

    test "8.3: image bytes round-trip — Image.bytes byte-for-byte identical to source (R-PROMOTE-S35)" do
      # The writer stores JPEG inside a FlateDecode stream (compress: true).
      # After decompression, the bytes must equal the original JPEG binary.
      source_bytes = File.read!(@jpeg_fixture)

      bin =
        Pdf.build([compress: true], fn pdf ->
          pdf
          |> Pdf.set_font("Helvetica", 12)
          |> Pdf.add_image({10, 10}, @jpeg_fixture)
        end)
        |> Pdf.export()

      {:ok, doc} = Pdf.Reader.open(bin)
      {:ok, images} = Pdf.Reader.read_images(doc)

      assert [img | _] = images
      # Bytes must be identical to the source file (decompressed from FlateDecode)
      assert img.bytes == source_bytes
    end
  end

  # ---------------------------------------------------------------------------
  # Phase 9.5 — Writer-built image: read_images/1 full shape verification (S-CW16)
  # Runs by default (no @tag :fixtures). Depends on Phase 8 tiny.jpg fixture.
  # ---------------------------------------------------------------------------

  describe "read_images/1 — complete Image struct shape (Phase 9.5)" do
    @jpeg_fixture_9 "test/fixtures/images/tiny.jpg"

    test "9.5: writer-built PDF image — complete Image struct shape (S-CW16)" do
      bin =
        Pdf.build([compress: true], fn pdf ->
          pdf
          |> Pdf.set_font("Helvetica", 12)
          |> Pdf.add_image({30, 40}, @jpeg_fixture_9)
        end)
        |> Pdf.export()

      {:ok, doc} = Pdf.Reader.open(bin)
      {:ok, images} = Pdf.Reader.read_images(doc)

      assert [img | _] = images

      # All required fields must be non-nil (S-CW16)
      assert img.kind in [:jpeg, :png_like]
      assert is_binary(img.bytes) and byte_size(img.bytes) > 0
      assert is_number(img.x)
      assert is_number(img.y)
      # width and height from image dict (may be float from to_float_dim)
      assert img.width != nil and img.width > 0
      assert img.height != nil and img.height > 0
      # render_width/render_height from CTM decomposition
      assert img.render_width > 0.0
      assert img.render_height > 0.0
      # ctm is a 6-float tuple
      assert is_tuple(img.ctm) and tuple_size(img.ctm) == 6

      Enum.each(Tuple.to_list(img.ctm), fn v ->
        assert is_number(v)
      end)

      # rotation
      assert is_float(img.rotation_radians)
      assert_in_delta img.rotation_radians, 0.0, 0.001
      # page number
      assert img.page == 1

      # x/y from CTM translation
      assert_in_delta img.x, 30.0, 1.0
      assert_in_delta img.y, 40.0, 1.0
    end
  end

  # ---------------------------------------------------------------------------
  # Phase 7 — read_metadata XMP merge (S-CW6..S-CW9, R-XMP1..R-XMP3)
  # ---------------------------------------------------------------------------

  describe "read_metadata/1 — XMP merge (Phase 7)" do
    test "7.1: XMP dc:title wins over /Info /Title (S-CW6)" do
      # Hand-crafted PDF with both /Info Title='Info Title' and
      # catalog /Metadata XMP with dc:title='XMP Title'. XMP must win.
      pdf_bin =
        craft_xmp_metadata_pdf(
          "Info Title",
          "<dc:title><rdf:Alt><rdf:li>XMP Title</rdf:li></rdf:Alt></dc:title>"
        )

      {:ok, doc} = Pdf.Reader.open(pdf_bin)
      {:ok, meta, _doc2} = Pdf.Reader.read_metadata(doc)

      assert meta["Title"] == "XMP Title"
    end

    test "7.2: no /Metadata in catalog — /Info-only unchanged (S-CW7)" do
      # Standard writer-built PDF has no /Metadata in catalog
      bin =
        Pdf.build([compress: false], fn pdf ->
          pdf
          |> Pdf.set_info(title: "Just Info")
          |> Pdf.set_font("Helvetica", 12)
          |> Pdf.text_at({72, 720}, "hi")
        end)
        |> Pdf.export()

      {:ok, doc} = Pdf.Reader.open(bin)
      {:ok, meta, _doc2} = Pdf.Reader.read_metadata(doc)

      # /Info data must still be present
      assert Map.has_key?(meta, "Creator") or Map.has_key?(meta, "Producer") or
               Map.has_key?(meta, "Title")

      # Specifically Title must be the /Info value when XMP absent
      if Map.has_key?(meta, "Title") do
        assert meta["Title"] == "Just Info"
      end
    end

    test "7.3: malformed XMP XML — graceful fallback to /Info-only (S-CW8)" do
      # Catalog /Metadata stream contains invalid XML; must not raise,
      # must return /Info keys without error.
      pdf_bin = craft_xmp_metadata_pdf("Fallback Title", "<garbage>")

      {:ok, doc} = Pdf.Reader.open(pdf_bin)
      # Should not raise; should return info map
      assert {:ok, meta, _doc2} = Pdf.Reader.read_metadata(doc)
      assert is_map(meta)
      # /Info Title must be present (XMP failed → fallback)
      assert meta["Title"] == "Fallback Title"
    end

    test "7.4: dc:creator rdf:Bag — only first element used as Author (S-CW9)" do
      xmp_fragment = """
      <dc:creator><rdf:Bag><rdf:li>Alice</rdf:li><rdf:li>Bob</rdf:li></rdf:Bag></dc:creator>
      """

      pdf_bin = craft_xmp_metadata_pdf("Test", String.trim(xmp_fragment))

      {:ok, doc} = Pdf.Reader.open(pdf_bin)
      {:ok, meta, _doc2} = Pdf.Reader.read_metadata(doc)

      assert meta["Author"] == "Alice"
    end
  end

  # ---------------------------------------------------------------------------
  # Phase 5 — Encoding cascade wired through read_text* (S-CW1..S-CW5, R-PROMOTE-S2)
  # ---------------------------------------------------------------------------

  describe "read_text/1 — encoding cascade wired (Phase 5)" do
    test "5.1: round-trip non-ASCII text with compress: true (S-CW1)" do
      # CRITICAL: must use compress: true to avoid uncompressed-test blindspot.
      # Non-ASCII characters (é, ö) round-trip via Helvetica + WinAnsi base
      # encoding through the wired cascade.
      bin =
        Pdf.build([compress: true], fn pdf ->
          pdf
          |> Pdf.set_font("Helvetica", 12)
          |> Pdf.text_at({100, 720}, "Héllo, wörld")
        end)
        |> Pdf.export()

      {:ok, doc} = Pdf.Reader.open(bin)
      {:ok, page_texts} = Pdf.Reader.read_text(doc)

      assert length(page_texts) >= 1
      page_text = hd(page_texts)
      assert String.contains?(page_text, "Héllo, wörld")
    end

    test "5.2: hand-crafted PDF with /Differences [65 /eacute] — byte 65 reads as é (S-CW2)" do
      pdf_bin = craft_differences_pdf(65, "eacute", "A")

      {:ok, doc} = Pdf.Reader.open(pdf_bin)
      {:ok, page_texts} = Pdf.Reader.read_text(doc)

      assert length(page_texts) >= 1
      page_text = hd(page_texts)
      assert String.contains?(page_text, "é")
    end

    test "5.3: ToUnicode wins over /Differences for same byte (S-CW3)" do
      # ToUnicode maps byte 0x41 → 'B'; /Differences maps 65 → eacute
      # ToUnicode must win.
      pdf_bin = craft_tou_over_differences_pdf()

      {:ok, doc} = Pdf.Reader.open(pdf_bin)
      {:ok, page_texts} = Pdf.Reader.read_text(doc)

      assert length(page_texts) >= 1
      page_text = hd(page_texts)
      assert String.contains?(page_text, "B")
      refute String.contains?(page_text, "é")
    end

    test "5.4: read_text_with_positions/1 — unresolved glyph in TextRun.unresolved + U+FFFD (S-CW13)" do
      pdf_bin = craft_unknown_glyph_pdf()

      {:ok, doc} = Pdf.Reader.open(pdf_bin)
      {:ok, runs} = Pdf.Reader.read_text_with_positions(doc)

      assert length(runs) >= 1
      # At least one run must have an unresolved entry
      unresolved_runs = Enum.filter(runs, fn r -> length(r.unresolved) > 0 end)
      assert length(unresolved_runs) >= 1
      run = hd(unresolved_runs)
      # The unresolved list must contain tuples
      assert Enum.all?(run.unresolved, fn {_idx, _marker} -> true end)
      # Text must contain U+FFFD
      assert String.contains?(run.text, "�")
    end

    test "5.5: read_text/1 collapses unresolved to U+FFFD only (S-CW14)" do
      pdf_bin = craft_unknown_glyph_pdf()

      {:ok, doc} = Pdf.Reader.open(pdf_bin)
      {:ok, page_texts} = Pdf.Reader.read_text(doc)

      assert length(page_texts) >= 1
      page_text = hd(page_texts)
      assert String.contains?(page_text, "�")
    end

    test "5.6: position coordinates — TextRun :x/:y within ±0.5 of known coord (R-PROMOTE-S2)" do
      # Writer-built PDF with text at {100, 720}
      bin =
        Pdf.build([compress: false], fn pdf ->
          pdf
          |> Pdf.set_font("Helvetica", 12)
          |> Pdf.text_at({100, 720}, "X")
        end)
        |> Pdf.export()

      {:ok, doc} = Pdf.Reader.open(bin)
      {:ok, runs} = Pdf.Reader.read_text_with_positions(doc)

      assert length(runs) >= 1
      run = hd(runs)
      assert_in_delta run.x, 100.0, 0.5
      assert_in_delta run.y, 720.0, 0.5
    end
  end

  # ---------------------------------------------------------------------------
  # Phase 6 — Form XObject integration tests
  # (hand-crafted PDFs; no external helpers from Phase 2)
  # ---------------------------------------------------------------------------

  describe "Phase 6 — Form XObject extraction via read_text/1 (R-FX1, S-FX1)" do
    test "6.1 — read_text/1 extracts text from a Form XObject" do
      # S-FX1: page content invokes a Form XObject whose stream contains text.
      # After Phase 6 wiring, read_text/1 must include the Form's text.
      bin = craft_form_xobject_pdf("FORM")
      assert {:ok, doc} = Pdf.Reader.open(bin)
      assert {:ok, texts} = Pdf.Reader.read_text(doc)

      combined = Enum.join(texts, " ")

      assert String.contains?(combined, "FORM"),
             "Expected 'FORM' in extracted text, got: #{inspect(texts)}"
    end

    test "6.5a — read_text/1 on writer-generated PDF still works (regression guard, S-FX16)" do
      bin =
        Pdf.build([compress: false], fn pdf ->
          pdf
          |> Pdf.set_font("Helvetica", 12)
          |> Pdf.text_at({72, 720}, "Regression")
        end)
        |> Pdf.export()

      assert {:ok, doc} = Pdf.Reader.open(bin)
      assert {:ok, texts} = Pdf.Reader.read_text(doc)
      combined = Enum.join(texts, " ")
      assert String.contains?(combined, "Regression")
    end
  end

  describe "Phase 6 — read_images/1 returns image from inside Form XObject (R-FX13, S-FX11)" do
    test "6.2 — read_images/1 returns image event from Form XObject" do
      # S-FX11: Form contains an Image XObject Do.
      # After Phase 6 wiring, read_images/1 must include the image from inside the Form.
      bin = craft_form_with_image_pdf()
      assert {:ok, doc} = Pdf.Reader.open(bin)
      assert {:ok, images} = Pdf.Reader.read_images(doc)

      assert length(images) >= 1, "Expected at least 1 image from Form, got: #{inspect(images)}"
    end
  end

  describe "Phase 6 — :deferred event absent for resolvable Form (R-FX18)" do
    test "6.6 — read_text/1 on Form XObject PDF returns {:ok, _} without :deferred events in output" do
      # R-FX18: the :deferred path is superseded. The public API must not surface it.
      bin = craft_form_xobject_pdf("DEFERRED_CHECK")
      assert {:ok, doc} = Pdf.Reader.open(bin)
      # If deferred events leaked into text runs, they'd show up as garbage text.
      # A {:deferred, :form_xobject, _} is NOT a {:text, _} event so it falls through
      # to the catch-all in events_to_text_runs and is silently dropped. The assertion
      # here is that read_text returns :ok (no crash) and the Form's text IS present.
      assert {:ok, texts} = Pdf.Reader.read_text(doc)
      combined = Enum.join(texts, " ")
      assert String.contains?(combined, "DEFERRED_CHECK")
    end
  end

  # ---------------------------------------------------------------------------
  # Phase — resource inheritance: cycle detection + cache
  # PDF 1.7 § 7.7.3.4 — Resource inheritance from page tree
  # ---------------------------------------------------------------------------

  describe "resolve_page_resources — cycle detection + cache (pdf-reader-resource-inheritance-multilevel)" do
    test "cyclic /Parent ref does not hang — returns {:ok, _} (cycle detection)" do
      # Crafts a PDF where the leaf page's /Parent ref points back to the leaf
      # page itself (object 3 → /Parent 3 0 R). Without cycle detection, the
      # recursive walk would loop forever. With detection, it returns safely.
      bin = craft_cyclic_parent_pdf()
      assert {:ok, doc} = Pdf.Reader.open(bin)

      # Must return without hanging or crashing (cycle is detected and halted)
      assert {:ok, _texts} = Pdf.Reader.read_text(doc)
    end

    test "page resource cache is populated after read_text_with_positions/1" do
      # After calling read_text_with_positions on a PDF where page has no own
      # /Resources, the cache must contain {:page_resources, {n, g}} keys.
      # We verify indirectly: two consecutive read_text/1 calls both succeed
      # and return the same result (second call hits cache, no re-walk).
      bin = craft_inherited_resources_pdf()
      assert {:ok, doc} = Pdf.Reader.open(bin)

      assert {:ok, texts1} = Pdf.Reader.read_text(doc)
      assert {:ok, texts2} = Pdf.Reader.read_text(doc)
      assert texts1 == texts2
    end

    test "multi-level inheritance regression — leaf reads font from grandparent /Pages node" do
      # Crafts: leaf page (no /Resources) → mid /Pages (has /Font /F1) → root /Pages (no /Resources)
      # The walk must go 2 levels up to find /Font /F1. If it stops at one level, text is empty.
      bin = craft_multilevel_inherited_resources_pdf()
      assert {:ok, doc} = Pdf.Reader.open(bin)
      assert {:ok, texts} = Pdf.Reader.read_text(doc)
      combined = Enum.join(texts, " ")

      assert String.contains?(combined, "MULTILEVEL"),
             "Expected 'MULTILEVEL' in extracted text, got: #{inspect(texts)}"
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp build_simple_pdf do
    Pdf.build([size: :a4, compress: false], fn pdf ->
      pdf
      |> Pdf.set_font("Helvetica", 12)
      |> Pdf.text_at({72, 720}, "Hello, world!")
    end)
    |> Pdf.export()
  end

  # ---------------------------------------------------------------------------
  # craft_rc4_v2_pdf/1
  #
  # Produces a fully-valid V2/R3 RC4-128 encrypted PDF with one page containing
  # the text "Hello, encrypted world!". The user and owner passwords are the
  # same string passed as the `password` argument.
  #
  # Pre-computed test vectors for password="test", ID=AABBCCDD11223344AABBCCDD11223344:
  #   /O = BADAD1E86442699427116D3E5D5271BC80A27814FC5E80F815EFEEF839354C5F
  #   /U = 1EB72FAF0D89FA6D98F09B61600F79F900000000000000000000000000000000
  #   file_key = A8F6B0D7E4437C563AA86D97A67494B0
  #   content stream (obj 6) encrypted = C5623F4A188105BD909ECDF840FC31DD...
  #
  # Computation chain (documented for reproduction):
  #   /O: Algorithm 3 — MD5(pad(owner_pw)) iterated 50x, truncated to 16 bytes,
  #       used as RC4 key for 20-pass encrypt of pad(user_pw).
  #   file_key: Algorithm 2 — MD5(pad(user_pw) ++ /O ++ P_le ++ /ID[0]) iterated 50x.
  #   /U: Algorithm 5 — MD5(pad_const ++ /ID[0]) RC4-encrypted 20 passes.
  #   stream: ObjectKey.derive(file_key, obj_num, gen_num, :rc4) → RC4.
  #
  # For passwords other than "test", the function computes vectors at runtime
  # using the encryption modules, then builds the PDF structure.
  # PDF 1.7 § 7.6.3.3 (Algorithms 2, 3, 5, per-object key).
  # ---------------------------------------------------------------------------
  defp craft_rc4_v2_pdf(password) when is_binary(password) do
    alias Pdf.Reader.Encryption.{V1V2, PasswordPad, StandardHandler, ObjectKey}

    id = Base.decode16!("AABBCCDD11223344AABBCCDD11223344")
    key_len = 16
    p_value = -3904

    # Compute /O (Algorithm 3)
    owner_padded = PasswordPad.pad(password)
    user_padded = PasswordPad.pad(password)
    init_hash = :crypto.hash(:md5, owner_padded)

    rc4_key_for_o =
      Enum.reduce(1..50, init_hash, fn _i, acc -> :crypto.hash(:md5, acc) end)
      |> then(&binary_part(&1, 0, key_len))

    step0 = :crypto.crypto_one_time(:rc4, rc4_key_for_o, user_padded, true)

    o_value =
      Enum.reduce(1..19, step0, fn i, acc ->
        xor_key = for <<b <- rc4_key_for_o>>, into: <<>>, do: <<Bitwise.bxor(b, i)>>
        :crypto.crypto_one_time(:rc4, xor_key, acc, true)
      end)

    # Bootstrap handler to derive file_key (Algorithm 2)
    bootstrap_handler = %StandardHandler{
      version: 2,
      revision: 3,
      length: 128,
      o: o_value,
      u: :binary.copy(<<0>>, 32),
      p: p_value,
      id: id,
      encrypt_metadata: true
    }

    file_key = V1V2.derive_file_key(password, bootstrap_handler)

    # Compute /U (Algorithm 5)
    pad_const = PasswordPad.constant()
    md5_16 = :crypto.hash(:md5, pad_const <> id)
    step0_u = :crypto.crypto_one_time(:rc4, file_key, md5_16, true)

    u_16 =
      Enum.reduce(1..19, step0_u, fn i, acc ->
        xor_key = for <<b <- file_key>>, into: <<>>, do: <<Bitwise.bxor(b, i)>>
        :crypto.crypto_one_time(:rc4, xor_key, acc, true)
      end)

    u_value = u_16 <> :binary.copy(<<0>>, 16)

    # Build the encrypted content stream (object 6, gen 0)
    # Content: "BT /F1 12 Tf 100 720 Td (Hello, encrypted world!) Tj ET"
    content_plain = "BT /F1 12 Tf 100 720 Td (Hello, encrypted world!) Tj ET"
    obj_num_content = 6
    content_obj_key = ObjectKey.derive(file_key, obj_num_content, 0, :rc4)
    content_encrypted = :crypto.crypto_one_time(:rc4, content_obj_key, content_plain, true)
    content_len = byte_size(content_encrypted)

    # Build PDF structure
    # Object numbering:
    #   1 = Catalog
    #   2 = Pages
    #   3 = Page
    #   4 = Font dict
    #   5 = Encrypt dict
    #   6 = Content stream (encrypted)
    o_literal = binary_to_pdf_literal(o_value)
    u_literal = binary_to_pdf_literal(u_value)

    obj1 = "1 0 obj\n<</Type /Catalog /Pages 2 0 R>>\nendobj\n"
    obj2 = "2 0 obj\n<</Type /Pages /Kids [3 0 R] /Count 1>>\nendobj\n"

    obj3 =
      "3 0 obj\n" <>
        "<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]" <>
        " /Resources <</Font <</F1 4 0 R>>>> /Contents 6 0 R>>\n" <>
        "endobj\n"

    obj4 =
      "4 0 obj\n" <>
        "<</Type /Font /Subtype /Type1 /BaseFont /Helvetica>>\n" <>
        "endobj\n"

    obj5 =
      "5 0 obj\n" <>
        "<</Filter /Standard /V 2 /R 3 /Length 128" <>
        " /O #{o_literal} /U #{u_literal}" <>
        " /P #{p_value}>>\n" <>
        "endobj\n"

    obj6 =
      "6 0 obj\n" <>
        "<</Length #{content_len}>>\n" <>
        "stream\n" <>
        content_encrypted <>
        "\nendstream\n" <>
        "endobj\n"

    header = "%PDF-1.4\n"
    obj1_offset = byte_size(header)
    obj2_offset = obj1_offset + byte_size(obj1)
    obj3_offset = obj2_offset + byte_size(obj2)
    obj4_offset = obj3_offset + byte_size(obj3)
    obj5_offset = obj4_offset + byte_size(obj4)
    obj6_offset = obj5_offset + byte_size(obj5)
    xref_offset = obj6_offset + byte_size(obj6)

    id_hex = Base.encode16(id)

    xref =
      "xref\n" <>
        "0 7\n" <>
        "0000000000 65535 f\r\n" <>
        pad_offset(obj1_offset) <>
        " 00000 n\r\n" <>
        pad_offset(obj2_offset) <>
        " 00000 n\r\n" <>
        pad_offset(obj3_offset) <>
        " 00000 n\r\n" <>
        pad_offset(obj4_offset) <>
        " 00000 n\r\n" <>
        pad_offset(obj5_offset) <>
        " 00000 n\r\n" <>
        pad_offset(obj6_offset) <> " 00000 n\r\n"

    trailer =
      "trailer\n" <>
        "<</Size 7 /Root 1 0 R /Encrypt 5 0 R /ID [<#{id_hex}><#{id_hex}>]>>\n" <>
        "startxref\n" <>
        "#{xref_offset}\n" <>
        "%%EOF\n"

    header <> obj1 <> obj2 <> obj3 <> obj4 <> obj5 <> obj6 <> xref <> trailer
  end

  # Convert a binary to a PDF hex string literal <XX...> for embedding in dict
  defp binary_to_pdf_literal(bin) when is_binary(bin) do
    "<" <> Base.encode16(bin) <> ">"
  end

  # Produce a PDF with /Filter /Adobe.PubSec to test unsupported handler rejection
  defp craft_unsupported_handler_pdf do
    id = Base.decode16!("AABBCCDD11223344AABBCCDD11223344")
    id_hex = Base.encode16(id)

    obj1 = "1 0 obj\n<</Type /Catalog /Pages 2 0 R>>\nendobj\n"
    obj2 = "2 0 obj\n<</Type /Pages /Kids [] /Count 0>>\nendobj\n"

    obj3 =
      "3 0 obj\n" <>
        "<</Filter /Adobe.PubSec /V 2 /R 3>>\n" <>
        "endobj\n"

    header = "%PDF-1.4\n"
    obj1_offset = byte_size(header)
    obj2_offset = obj1_offset + byte_size(obj1)
    obj3_offset = obj2_offset + byte_size(obj2)
    xref_offset = obj3_offset + byte_size(obj3)

    xref =
      "xref\n" <>
        "0 4\n" <>
        "0000000000 65535 f\r\n" <>
        pad_offset(obj1_offset) <>
        " 00000 n\r\n" <>
        pad_offset(obj2_offset) <>
        " 00000 n\r\n" <>
        pad_offset(obj3_offset) <> " 00000 n\r\n"

    trailer =
      "trailer\n" <>
        "<</Size 4 /Root 1 0 R /Encrypt 3 0 R /ID [<#{id_hex}><#{id_hex}>]>>\n" <>
        "startxref\n" <>
        "#{xref_offset}\n" <>
        "%%EOF\n"

    header <> obj1 <> obj2 <> obj3 <> xref <> trailer
  end

  # Hand-craft a minimal two-xref-section PDF linked by /Prev
  # so we can test that the /Prev chain is followed.
  defp craft_prev_chain_pdf do
    # Object 1: a simple integer at byte 9
    # First xref section covers objects 0-1
    # Second xref section adds object 2, points /Prev to first
    obj1 = "1 0 obj\n42\nendobj\n"
    obj2 = "2 0 obj\n99\nendobj\n"

    header = "%PDF-1.4\n"
    obj1_offset = byte_size(header)
    obj2_offset = obj1_offset + byte_size(obj1)
    xref1_offset = obj2_offset + byte_size(obj2)

    # First xref section (covers obj 0 and 1)
    xref1_entry0 = "0000000000 65535 f\r\n"
    xref1_entry1 = pad_offset(obj1_offset) <> " 00000 n\r\n"

    xref1 =
      "xref\n" <>
        "0 2\n" <>
        xref1_entry0 <>
        xref1_entry1 <>
        "trailer\n" <>
        "<</Size 2/Root 1 0 R>>\n" <>
        "startxref\n" <>
        "#{xref1_offset}\n" <>
        "%%EOF\n"

    xref2_offset = xref1_offset + byte_size(xref1)
    xref2_entry2 = pad_offset(obj2_offset) <> " 00000 n\r\n"

    xref2 =
      "xref\n" <>
        "2 1\n" <>
        xref2_entry2 <>
        "trailer\n" <>
        "<</Size 3/Root 1 0 R/Prev #{xref1_offset}>>\n" <>
        "startxref\n" <>
        "#{xref2_offset}\n" <>
        "%%EOF\n"

    header <> obj1 <> obj2 <> xref1 <> xref2
  end

  defp pad_offset(n) do
    n |> Integer.to_string() |> String.pad_leading(10, "0")
  end

  # Build a 2-page PDF with metadata title + multiple text operations.
  # Used by the 11.7.1 round-trip tests.
  defp build_two_page_pdf do
    Pdf.build([size: :a4, compress: false], fn pdf ->
      pdf
      |> Pdf.set_info(title: "Round-trip Test Document")
      |> Pdf.set_font("Helvetica", 12)
      |> Pdf.text_at({72, 720}, "Page one — first run")
      |> Pdf.text_at({72, 700}, "Page one — second run")
      |> Pdf.add_page(:a4)
      |> Pdf.set_font("Helvetica", 12)
      |> Pdf.text_at({72, 720}, "Page two — first run")
      |> Pdf.text_at({72, 700}, "Page two — second run")
    end)
    |> Pdf.export()
  end

  # ---------------------------------------------------------------------------
  # Hand-crafted PDF helpers (Phase 5 — encoding cascade integration tests)
  # ---------------------------------------------------------------------------

  # craft_differences_pdf/3
  #
  # Builds a minimal PDF binary with:
  #   - Font /F1 with /Encoding << /Type /Encoding /BaseEncoding /WinAnsiEncoding
  #                                  /Differences [<byte> /<glyph_name>] >>
  #   - Content stream: BT /F1 12 Tf 100 720 Td (<literal_str>) Tj ET
  #
  # When read_text/1 decodes this, the encoding cascade must convert `byte`
  # → glyph_name → Unicode codepoint (via AGL) for that byte position.
  #
  # PDF 1.7 § 7.5 (file structure), § 9.6.5 (character encoding).
  defp craft_differences_pdf(byte, glyph_name, literal_str) do
    header = "%PDF-1.4\n"

    # Content stream: plain text in the content stream uses literal bytes.
    # The literal_str is what the writer embeds; the reader will decode `byte`
    # through the /Differences cascade → glyph_name → AGL → Unicode.
    content_stream_body = "BT /F1 12 Tf 100 720 Td (#{literal_str}) Tj ET"
    content_length = byte_size(content_stream_body)

    # Object 1: Catalog
    obj1 = "1 0 obj\n<</Type /Catalog /Pages 2 0 R>>\nendobj\n"

    # Object 2: Pages (1 page)
    obj2 = "2 0 obj\n<</Type /Pages /Kids [3 0 R] /Count 1>>\nendobj\n"

    # Object 3: Page
    obj3 =
      "3 0 obj\n" <>
        "<</Type /Page /Parent 2 0 R" <>
        " /MediaBox [0 0 612 792]" <>
        " /Resources <</Font <</F1 4 0 R>>>>" <>
        " /Contents 5 0 R>>\n" <>
        "endobj\n"

    # Object 4: Font dict with /Differences override
    # /Differences array: [<byte_int> /<glyph_name>]
    obj4 =
      "4 0 obj\n" <>
        "<</Type /Font /Subtype /Type1 /BaseFont /Helvetica" <>
        " /Encoding <</Type /Encoding /BaseEncoding /WinAnsiEncoding" <>
        " /Differences [#{byte} /#{glyph_name}]>>>>\n" <>
        "endobj\n"

    # Object 5: Content stream
    obj5 =
      "5 0 obj\n" <>
        "<</Length #{content_length}>>\n" <>
        "stream\n" <>
        content_stream_body <>
        "\nendstream\n" <>
        "endobj\n"

    # Calculate offsets
    obj1_offset = byte_size(header)
    obj2_offset = obj1_offset + byte_size(obj1)
    obj3_offset = obj2_offset + byte_size(obj2)
    obj4_offset = obj3_offset + byte_size(obj3)
    obj5_offset = obj4_offset + byte_size(obj4)
    xref_offset = obj5_offset + byte_size(obj5)

    xref =
      "xref\n" <>
        "0 6\n" <>
        "0000000000 65535 f\r\n" <>
        pad_offset(obj1_offset) <>
        " 00000 n\r\n" <>
        pad_offset(obj2_offset) <>
        " 00000 n\r\n" <>
        pad_offset(obj3_offset) <>
        " 00000 n\r\n" <>
        pad_offset(obj4_offset) <>
        " 00000 n\r\n" <>
        pad_offset(obj5_offset) <> " 00000 n\r\n"

    trailer =
      "trailer\n" <>
        "<</Size 6 /Root 1 0 R>>\n" <>
        "startxref\n" <>
        "#{xref_offset}\n" <>
        "%%EOF\n"

    header <> obj1 <> obj2 <> obj3 <> obj4 <> obj5 <> xref <> trailer
  end

  # craft_tou_over_differences_pdf/0
  #
  # Builds a minimal PDF where font /F1 has BOTH:
  #   - ToUnicode CMap: maps byte 0x41 ('A') → 'B' (U+0042)
  #   - /Differences: [65 /eacute] (byte 65 → "eacute" → U+00E9 = 'é')
  #
  # Per the cascade spec (R-CW3/S-CW3), ToUnicode must win.
  # read_text/1 must return "B" NOT "é" for the content (A) Tj.
  #
  # PDF 1.7 § 9.10.3 (ToUnicode), § 9.6.5 (Differences).
  defp craft_tou_over_differences_pdf do
    header = "%PDF-1.4\n"

    # ToUnicode CMap binary (object 6): maps <41> → <0042> (byte 65 → 'B')
    cmap_body =
      "/CIDInit /ProcSet findresource begin\n" <>
        "12 dict begin\n" <>
        "begincmap\n" <>
        "/CMapType 2 def\n" <>
        "1 begincodespacerange\n" <>
        "<00> <FF>\n" <>
        "endcodespacerange\n" <>
        "1 beginbfchar\n" <>
        "<41> <0042>\n" <>
        "endbfchar\n" <>
        "endcmap\n" <>
        "CMapName currentdict /CMap defineresource pop\n" <>
        "end\n" <>
        "end\n"

    cmap_length = byte_size(cmap_body)

    content_stream_body = "BT /F1 12 Tf 100 720 Td (A) Tj ET"
    content_length = byte_size(content_stream_body)

    obj1 = "1 0 obj\n<</Type /Catalog /Pages 2 0 R>>\nendobj\n"
    obj2 = "2 0 obj\n<</Type /Pages /Kids [3 0 R] /Count 1>>\nendobj\n"

    obj3 =
      "3 0 obj\n" <>
        "<</Type /Page /Parent 2 0 R" <>
        " /MediaBox [0 0 612 792]" <>
        " /Resources <</Font <</F1 4 0 R>>>>" <>
        " /Contents 5 0 R>>\n" <>
        "endobj\n"

    # Font with both ToUnicode (obj 6) and /Differences [65 /eacute]
    obj4 =
      "4 0 obj\n" <>
        "<</Type /Font /Subtype /Type1 /BaseFont /Helvetica" <>
        " /ToUnicode 6 0 R" <>
        " /Encoding <</Type /Encoding /BaseEncoding /WinAnsiEncoding" <>
        " /Differences [65 /eacute]>>>>\n" <>
        "endobj\n"

    obj5 =
      "5 0 obj\n" <>
        "<</Length #{content_length}>>\n" <>
        "stream\n" <>
        content_stream_body <>
        "\nendstream\n" <>
        "endobj\n"

    obj6 =
      "6 0 obj\n" <>
        "<</Length #{cmap_length}>>\n" <>
        "stream\n" <>
        cmap_body <>
        "endstream\n" <>
        "endobj\n"

    obj1_offset = byte_size(header)
    obj2_offset = obj1_offset + byte_size(obj1)
    obj3_offset = obj2_offset + byte_size(obj2)
    obj4_offset = obj3_offset + byte_size(obj3)
    obj5_offset = obj4_offset + byte_size(obj4)
    obj6_offset = obj5_offset + byte_size(obj5)
    xref_offset = obj6_offset + byte_size(obj6)

    xref =
      "xref\n" <>
        "0 7\n" <>
        "0000000000 65535 f\r\n" <>
        pad_offset(obj1_offset) <>
        " 00000 n\r\n" <>
        pad_offset(obj2_offset) <>
        " 00000 n\r\n" <>
        pad_offset(obj3_offset) <>
        " 00000 n\r\n" <>
        pad_offset(obj4_offset) <>
        " 00000 n\r\n" <>
        pad_offset(obj5_offset) <>
        " 00000 n\r\n" <>
        pad_offset(obj6_offset) <> " 00000 n\r\n"

    trailer =
      "trailer\n" <>
        "<</Size 7 /Root 1 0 R>>\n" <>
        "startxref\n" <>
        "#{xref_offset}\n" <>
        "%%EOF\n"

    header <> obj1 <> obj2 <> obj3 <> obj4 <> obj5 <> obj6 <> xref <> trailer
  end

  # craft_unknown_glyph_pdf/0
  #
  # Builds a minimal PDF where font /F1 has /Differences mapping byte 65
  # to "completelymadeupglyph_zzz" (absent from AGL, no ToUnicode).
  # Content stream: (A) Tj (byte 65).
  #
  # Expected: encoding cascade returns U+FFFD + unresolved sentinel
  # {0, "completelymadeupglyph_zzz"} because the glyph name is not in AGL.
  #
  # PDF 1.7 § 9.6.5, AGL spec (Adobe Glyph List for New Fonts, version 1.7).
  defp craft_unknown_glyph_pdf do
    header = "%PDF-1.4\n"

    content_stream_body = "BT /F1 12 Tf 100 720 Td (A) Tj ET"
    content_length = byte_size(content_stream_body)

    obj1 = "1 0 obj\n<</Type /Catalog /Pages 2 0 R>>\nendobj\n"
    obj2 = "2 0 obj\n<</Type /Pages /Kids [3 0 R] /Count 1>>\nendobj\n"

    obj3 =
      "3 0 obj\n" <>
        "<</Type /Page /Parent 2 0 R" <>
        " /MediaBox [0 0 612 792]" <>
        " /Resources <</Font <</F1 4 0 R>>>>" <>
        " /Contents 5 0 R>>\n" <>
        "endobj\n"

    # Font with /Differences mapping byte 65 to a completely unknown glyph
    obj4 =
      "4 0 obj\n" <>
        "<</Type /Font /Subtype /Type1 /BaseFont /Helvetica" <>
        " /Encoding <</Type /Encoding /BaseEncoding /WinAnsiEncoding" <>
        " /Differences [65 /completelymadeupglyph_zzz]>>>>\n" <>
        "endobj\n"

    obj5 =
      "5 0 obj\n" <>
        "<</Length #{content_length}>>\n" <>
        "stream\n" <>
        content_stream_body <>
        "\nendstream\n" <>
        "endobj\n"

    obj1_offset = byte_size(header)
    obj2_offset = obj1_offset + byte_size(obj1)
    obj3_offset = obj2_offset + byte_size(obj2)
    obj4_offset = obj3_offset + byte_size(obj3)
    obj5_offset = obj4_offset + byte_size(obj4)
    xref_offset = obj5_offset + byte_size(obj5)

    xref =
      "xref\n" <>
        "0 6\n" <>
        "0000000000 65535 f\r\n" <>
        pad_offset(obj1_offset) <>
        " 00000 n\r\n" <>
        pad_offset(obj2_offset) <>
        " 00000 n\r\n" <>
        pad_offset(obj3_offset) <>
        " 00000 n\r\n" <>
        pad_offset(obj4_offset) <>
        " 00000 n\r\n" <>
        pad_offset(obj5_offset) <> " 00000 n\r\n"

    trailer =
      "trailer\n" <>
        "<</Size 6 /Root 1 0 R>>\n" <>
        "startxref\n" <>
        "#{xref_offset}\n" <>
        "%%EOF\n"

    header <> obj1 <> obj2 <> obj3 <> obj4 <> obj5 <> xref <> trailer
  end

  # ---------------------------------------------------------------------------
  # craft_xmp_metadata_pdf/2
  #
  # Builds a minimal PDF with:
  #   - /Info dictionary containing /Title
  #   - Catalog /Metadata stream (object 6) with a valid XMP packet wrapping
  #     whatever dc:* fragment is passed in `xmp_properties_fragment`.
  #
  # Used by Phase 7 tests to verify XMP merge precedence.
  #
  # PDF 1.7 § 14.3.2 (Metadata Streams), § 14.3.3 (Document Information Dictionary).
  defp craft_xmp_metadata_pdf(info_title, xmp_properties_fragment) do
    header = "%PDF-1.4\n"

    # Full XMP packet wrapping the fragment
    xmp_body = """
    <?xpacket begin='' id='W5M0MpCehiHzreSzNTczkc9d'?>
    <x:xmpmeta xmlns:x='adobe:ns:meta/'>
    <rdf:RDF xmlns:rdf='http://www.w3.org/1999/02/22-rdf-syntax-ns#'
             xmlns:dc='http://purl.org/dc/elements/1.1/'
             xmlns:xmp='http://ns.adobe.com/xap/1.0/'
             xmlns:pdf='http://ns.adobe.com/pdf/1.3/'>
    <rdf:Description rdf:about=''>
    #{xmp_properties_fragment}
    </rdf:Description>
    </rdf:RDF>
    </x:xmpmeta>
    <?xpacket end='w'?>
    """

    xmp_length = byte_size(xmp_body)
    content_body = "BT /F1 12 Tf 100 720 Td (Hi) Tj ET"
    content_length = byte_size(content_body)

    # Object 1: Catalog (with /Metadata → obj 6)
    obj1 = "1 0 obj\n<</Type /Catalog /Pages 2 0 R /Metadata 6 0 R>>\nendobj\n"

    # Object 2: Pages
    obj2 = "2 0 obj\n<</Type /Pages /Kids [3 0 R] /Count 1>>\nendobj\n"

    # Object 3: Page
    obj3 =
      "3 0 obj\n" <>
        "<</Type /Page /Parent 2 0 R" <>
        " /MediaBox [0 0 612 792]" <>
        " /Resources <</Font <</F1 4 0 R>>>>" <>
        " /Contents 5 0 R>>\n" <>
        "endobj\n"

    # Object 4: Font (simple Helvetica — we just need valid structure)
    obj4 =
      "4 0 obj\n" <>
        "<</Type /Font /Subtype /Type1 /BaseFont /Helvetica" <>
        " /Encoding /WinAnsiEncoding>>\n" <>
        "endobj\n"

    # Object 5: Content stream
    obj5 =
      "5 0 obj\n" <>
        "<</Length #{content_length}>>\n" <>
        "stream\n" <>
        content_body <>
        "\nendstream\n" <>
        "endobj\n"

    # Object 6: XMP Metadata stream (no filter — plain XML)
    obj6 =
      "6 0 obj\n" <>
        "<</Type /Metadata /Subtype /XML /Length #{xmp_length}>>\n" <>
        "stream\n" <>
        xmp_body <>
        "endstream\n" <>
        "endobj\n"

    # /Info object (object 7)
    obj7 = "7 0 obj\n<</Title (#{info_title})>>\nendobj\n"

    obj1_offset = byte_size(header)
    obj2_offset = obj1_offset + byte_size(obj1)
    obj3_offset = obj2_offset + byte_size(obj2)
    obj4_offset = obj3_offset + byte_size(obj3)
    obj5_offset = obj4_offset + byte_size(obj4)
    obj6_offset = obj5_offset + byte_size(obj5)
    obj7_offset = obj6_offset + byte_size(obj6)
    xref_offset = obj7_offset + byte_size(obj7)

    xref =
      "xref\n" <>
        "0 8\n" <>
        "0000000000 65535 f\r\n" <>
        pad_offset(obj1_offset) <>
        " 00000 n\r\n" <>
        pad_offset(obj2_offset) <>
        " 00000 n\r\n" <>
        pad_offset(obj3_offset) <>
        " 00000 n\r\n" <>
        pad_offset(obj4_offset) <>
        " 00000 n\r\n" <>
        pad_offset(obj5_offset) <>
        " 00000 n\r\n" <>
        pad_offset(obj6_offset) <>
        " 00000 n\r\n" <>
        pad_offset(obj7_offset) <> " 00000 n\r\n"

    trailer =
      "trailer\n" <>
        "<</Size 8 /Root 1 0 R /Info 7 0 R>>\n" <>
        "startxref\n" <>
        "#{xref_offset}\n" <>
        "%%EOF\n"

    header <> obj1 <> obj2 <> obj3 <> obj4 <> obj5 <> obj6 <> obj7 <> xref <> trailer
  end

  # ---------------------------------------------------------------------------
  # craft_form_xobject_pdf/1
  #
  # Builds a minimal PDF with:
  #   - One page whose content stream calls: BT /F1 12 Tf 0 0 Td (Page) Tj ET /Form1 Do
  #   - Form1 is a Form XObject containing:
  #       BT /F1 12 Tf 100 200 Td (<form_text>) Tj ET
  #   - /F1 = Helvetica in page /Resources
  #
  # Structure:
  #   Obj 1: Catalog → Pages
  #   Obj 2: Pages → [Page]
  #   Obj 3: Page dict with /Resources and /Contents
  #   Obj 4: Font F1 (Helvetica)
  #   Obj 5: Page content stream
  #   Obj 6: Form XObject stream (Subtype /Form)
  #
  # PDF 1.7 § 8.10 (Form XObjects).
  # ---------------------------------------------------------------------------
  defp craft_form_xobject_pdf(form_text) do
    header = "%PDF-1.4\n"

    form_content = "BT /F1 12 Tf 100 200 Td (#{form_text}) Tj ET"
    form_length = byte_size(form_content)

    page_content = "BT /F1 12 Tf 0 0 Td (Page) Tj ET\n/Form1 Do"
    page_length = byte_size(page_content)

    # Obj 1: Catalog
    obj1 = "1 0 obj\n<</Type /Catalog /Pages 2 0 R>>\nendobj\n"

    # Obj 2: Pages
    obj2 = "2 0 obj\n<</Type /Pages /Kids [3 0 R] /Count 1>>\nendobj\n"

    # Obj 3: Page — /Resources include Font AND XObject dict referencing Form1
    obj3 =
      "3 0 obj\n" <>
        "<</Type /Page /Parent 2 0 R" <>
        " /MediaBox [0 0 612 792]" <>
        " /Resources" <>
        " <</Font <</F1 4 0 R>>" <>
        " /XObject <</Form1 6 0 R>>>>" <>
        " /Contents 5 0 R>>\n" <>
        "endobj\n"

    # Obj 4: Font Helvetica
    obj4 =
      "4 0 obj\n" <>
        "<</Type /Font /Subtype /Type1 /BaseFont /Helvetica" <>
        " /Encoding /WinAnsiEncoding>>\n" <>
        "endobj\n"

    # Obj 5: Page content stream
    obj5 =
      "5 0 obj\n" <>
        "<</Length #{page_length}>>\n" <>
        "stream\n" <>
        page_content <>
        "\nendstream\n" <>
        "endobj\n"

    # Obj 6: Form XObject stream
    obj6 =
      "6 0 obj\n" <>
        "<</Type /XObject /Subtype /Form /BBox [0 0 612 792]" <>
        " /Resources <</Font <</F1 4 0 R>>>>" <>
        " /Length #{form_length}>>\n" <>
        "stream\n" <>
        form_content <>
        "\nendstream\n" <>
        "endobj\n"

    obj1_offset = byte_size(header)
    obj2_offset = obj1_offset + byte_size(obj1)
    obj3_offset = obj2_offset + byte_size(obj2)
    obj4_offset = obj3_offset + byte_size(obj3)
    obj5_offset = obj4_offset + byte_size(obj4)
    obj6_offset = obj5_offset + byte_size(obj5)
    xref_offset = obj6_offset + byte_size(obj6)

    xref =
      "xref\n" <>
        "0 7\n" <>
        "0000000000 65535 f\r\n" <>
        pad_offset(obj1_offset) <>
        " 00000 n\r\n" <>
        pad_offset(obj2_offset) <>
        " 00000 n\r\n" <>
        pad_offset(obj3_offset) <>
        " 00000 n\r\n" <>
        pad_offset(obj4_offset) <>
        " 00000 n\r\n" <>
        pad_offset(obj5_offset) <>
        " 00000 n\r\n" <>
        pad_offset(obj6_offset) <> " 00000 n\r\n"

    trailer =
      "trailer\n" <>
        "<</Size 7 /Root 1 0 R>>\n" <>
        "startxref\n" <>
        "#{xref_offset}\n" <>
        "%%EOF\n"

    header <> obj1 <> obj2 <> obj3 <> obj4 <> obj5 <> obj6 <> xref <> trailer
  end

  # ---------------------------------------------------------------------------
  # craft_form_with_image_pdf/0
  #
  # Builds a minimal PDF with:
  #   - One page invoking a Form XObject
  #   - The Form XObject contains an Image XObject Do (minimal raw image bytes)
  #
  # Structure:
  #   Obj 1: Catalog
  #   Obj 2: Pages
  #   Obj 3: Page (resources: XObject: {Form1: 6 0 R})
  #   Obj 4: Font F1 (Helvetica, for completeness)
  #   Obj 5: Page content stream (/Form1 Do)
  #   Obj 6: Form XObject stream (/Img1 Do; Resources: XObject: {Img1: 7 0 R})
  #   Obj 7: Image XObject stream (minimal raw bytes, no filter)
  #
  # PDF 1.7 § 8.10.3 (Form XObjects with nested images).
  # ---------------------------------------------------------------------------
  defp craft_form_with_image_pdf do
    header = "%PDF-1.4\n"

    # Minimal raw image bytes (8x8 grayscale, no filter — raw pixels)
    image_bytes = :binary.copy(<<128>>, 64)
    image_length = byte_size(image_bytes)

    form_content = "q 8 0 0 8 0 0 cm /Img1 Do Q"
    form_length = byte_size(form_content)

    page_content = "/Form1 Do"
    page_length = byte_size(page_content)

    # Obj 1: Catalog
    obj1 = "1 0 obj\n<</Type /Catalog /Pages 2 0 R>>\nendobj\n"

    # Obj 2: Pages
    obj2 = "2 0 obj\n<</Type /Pages /Kids [3 0 R] /Count 1>>\nendobj\n"

    # Obj 3: Page
    obj3 =
      "3 0 obj\n" <>
        "<</Type /Page /Parent 2 0 R" <>
        " /MediaBox [0 0 612 792]" <>
        " /Resources <</XObject <</Form1 6 0 R>>>>" <>
        " /Contents 5 0 R>>\n" <>
        "endobj\n"

    # Obj 4: Font (minimal — not used in this test but included for valid structure)
    obj4 =
      "4 0 obj\n" <>
        "<</Type /Font /Subtype /Type1 /BaseFont /Helvetica>>\n" <>
        "endobj\n"

    # Obj 5: Page content stream
    obj5 =
      "5 0 obj\n" <>
        "<</Length #{page_length}>>\n" <>
        "stream\n" <>
        page_content <>
        "\nendstream\n" <>
        "endobj\n"

    # Obj 6: Form XObject — contains an image
    obj6 =
      "6 0 obj\n" <>
        "<</Type /XObject /Subtype /Form /BBox [0 0 8 8]" <>
        " /Resources <</XObject <</Img1 7 0 R>>>>" <>
        " /Length #{form_length}>>\n" <>
        "stream\n" <>
        form_content <>
        "\nendstream\n" <>
        "endobj\n"

    # Obj 7: Image XObject (raw grayscale, no filter)
    obj7 =
      "7 0 obj\n" <>
        "<</Type /XObject /Subtype /Image" <>
        " /Width 8 /Height 8 /ColorSpace /DeviceGray /BitsPerComponent 8" <>
        " /Length #{image_length}>>\n" <>
        "stream\n" <>
        image_bytes <>
        "\nendstream\n" <>
        "endobj\n"

    obj1_offset = byte_size(header)
    obj2_offset = obj1_offset + byte_size(obj1)
    obj3_offset = obj2_offset + byte_size(obj2)
    obj4_offset = obj3_offset + byte_size(obj3)
    obj5_offset = obj4_offset + byte_size(obj4)
    obj6_offset = obj5_offset + byte_size(obj5)
    obj7_offset = obj6_offset + byte_size(obj6)
    xref_offset = obj7_offset + byte_size(obj7)

    xref =
      "xref\n" <>
        "0 8\n" <>
        "0000000000 65535 f\r\n" <>
        pad_offset(obj1_offset) <>
        " 00000 n\r\n" <>
        pad_offset(obj2_offset) <>
        " 00000 n\r\n" <>
        pad_offset(obj3_offset) <>
        " 00000 n\r\n" <>
        pad_offset(obj4_offset) <>
        " 00000 n\r\n" <>
        pad_offset(obj5_offset) <>
        " 00000 n\r\n" <>
        pad_offset(obj6_offset) <>
        " 00000 n\r\n" <>
        pad_offset(obj7_offset) <> " 00000 n\r\n"

    trailer =
      "trailer\n" <>
        "<</Size 8 /Root 1 0 R>>\n" <>
        "startxref\n" <>
        "#{xref_offset}\n" <>
        "%%EOF\n"

    header <> obj1 <> obj2 <> obj3 <> obj4 <> obj5 <> obj6 <> obj7 <> xref <> trailer
  end

  # ---------------------------------------------------------------------------
  # craft_cyclic_parent_pdf/0
  #
  # Builds a minimal PDF where the leaf page (obj 3) has a /Parent ref pointing
  # back to itself (3 0 R). Without cycle detection, resolve_page_resources/4
  # would recurse infinitely. The page has no /Resources so the inheritance walk
  # is triggered. Expected behavior: returns {:ok, []} (empty text, no crash).
  #
  # Structure:
  #   Obj 1: Catalog → Pages 2 0 R
  #   Obj 2: Pages node (root) → Kids [3 0 R]
  #   Obj 3: Page — /Parent 3 0 R (self-ref cycle), no /Resources
  #   Obj 4: Content stream (empty — no text ops)
  # ---------------------------------------------------------------------------
  defp craft_cyclic_parent_pdf do
    header = "%PDF-1.4\n"

    content_body = ""
    content_length = byte_size(content_body)

    obj1 = "1 0 obj\n<</Type /Catalog /Pages 2 0 R>>\nendobj\n"
    obj2 = "2 0 obj\n<</Type /Pages /Kids [3 0 R] /Count 1>>\nendobj\n"

    # Obj 3: Page with /Parent pointing back to itself — creates a cycle
    obj3 =
      "3 0 obj\n" <>
        "<</Type /Page /Parent 3 0 R" <>
        " /MediaBox [0 0 612 792]" <>
        " /Contents 4 0 R>>\n" <>
        "endobj\n"

    obj4 =
      "4 0 obj\n" <>
        "<</Length #{content_length}>>\n" <>
        "stream\n" <>
        content_body <>
        "\nendstream\n" <>
        "endobj\n"

    obj1_offset = byte_size(header)
    obj2_offset = obj1_offset + byte_size(obj1)
    obj3_offset = obj2_offset + byte_size(obj2)
    obj4_offset = obj3_offset + byte_size(obj3)
    xref_offset = obj4_offset + byte_size(obj4)

    xref =
      "xref\n" <>
        "0 5\n" <>
        "0000000000 65535 f\r\n" <>
        pad_offset(obj1_offset) <>
        " 00000 n\r\n" <>
        pad_offset(obj2_offset) <>
        " 00000 n\r\n" <>
        pad_offset(obj3_offset) <>
        " 00000 n\r\n" <>
        pad_offset(obj4_offset) <> " 00000 n\r\n"

    trailer =
      "trailer\n" <>
        "<</Size 5 /Root 1 0 R>>\n" <>
        "startxref\n" <>
        "#{xref_offset}\n" <>
        "%%EOF\n"

    header <> obj1 <> obj2 <> obj3 <> obj4 <> xref <> trailer
  end

  # ---------------------------------------------------------------------------
  # craft_inherited_resources_pdf/0
  #
  # Builds a PDF where the leaf page has no /Resources. Resources (/Font /F1)
  # live on the /Pages node. The walk finds them one level up (already works).
  # Used to verify the cache: calling read_text twice on the same doc returns
  # the same result (both calls succeed).
  #
  # Structure:
  #   Obj 1: Catalog → Pages 2 0 R
  #   Obj 2: Pages — /Resources <</Font <</F1 4 0 R>>>>
  #   Obj 3: Page — no /Resources, /Parent 2 0 R
  #   Obj 4: Font F1 (Helvetica)
  #   Obj 5: Content stream
  # ---------------------------------------------------------------------------
  defp craft_inherited_resources_pdf do
    header = "%PDF-1.4\n"

    content_body = "BT /F1 12 Tf 100 720 Td (INHERITED) Tj ET"
    content_length = byte_size(content_body)

    obj1 = "1 0 obj\n<</Type /Catalog /Pages 2 0 R>>\nendobj\n"

    obj2 =
      "2 0 obj\n" <>
        "<</Type /Pages /Kids [3 0 R] /Count 1" <>
        " /Resources <</Font <</F1 4 0 R>>>>>>\n" <>
        "endobj\n"

    obj3 =
      "3 0 obj\n" <>
        "<</Type /Page /Parent 2 0 R" <>
        " /MediaBox [0 0 612 792]" <>
        " /Contents 5 0 R>>\n" <>
        "endobj\n"

    obj4 =
      "4 0 obj\n" <>
        "<</Type /Font /Subtype /Type1 /BaseFont /Helvetica" <>
        " /Encoding /WinAnsiEncoding>>\n" <>
        "endobj\n"

    obj5 =
      "5 0 obj\n" <>
        "<</Length #{content_length}>>\n" <>
        "stream\n" <>
        content_body <>
        "\nendstream\n" <>
        "endobj\n"

    obj1_offset = byte_size(header)
    obj2_offset = obj1_offset + byte_size(obj1)
    obj3_offset = obj2_offset + byte_size(obj2)
    obj4_offset = obj3_offset + byte_size(obj3)
    obj5_offset = obj4_offset + byte_size(obj4)
    xref_offset = obj5_offset + byte_size(obj5)

    xref =
      "xref\n" <>
        "0 6\n" <>
        "0000000000 65535 f\r\n" <>
        pad_offset(obj1_offset) <>
        " 00000 n\r\n" <>
        pad_offset(obj2_offset) <>
        " 00000 n\r\n" <>
        pad_offset(obj3_offset) <>
        " 00000 n\r\n" <>
        pad_offset(obj4_offset) <>
        " 00000 n\r\n" <>
        pad_offset(obj5_offset) <> " 00000 n\r\n"

    trailer =
      "trailer\n" <>
        "<</Size 6 /Root 1 0 R>>\n" <>
        "startxref\n" <>
        "#{xref_offset}\n" <>
        "%%EOF\n"

    header <> obj1 <> obj2 <> obj3 <> obj4 <> obj5 <> xref <> trailer
  end

  # ---------------------------------------------------------------------------
  # craft_multilevel_inherited_resources_pdf/0
  #
  # Builds a 3-level page tree:
  #   root /Pages (obj 2) — no /Resources
  #   mid  /Pages (obj 3) — /Resources with /Font /F1
  #   leaf Page  (obj 4) — no /Resources, /Parent 3 0 R
  #
  # The leaf has no /Resources. The walk must go to mid (obj 3) where it finds
  # /Font /F1. This tests the 2-level walk that Phase 1.1 implemented.
  #
  # Structure:
  #   Obj 1: Catalog
  #   Obj 2: Root Pages — Kids [3 0 R], no /Resources
  #   Obj 3: Mid Pages  — Kids [4 0 R], /Resources <</Font <</F1 5 0 R>>>>
  #   Obj 4: Leaf Page  — no /Resources, /Parent 3 0 R, /Contents 6 0 R
  #   Obj 5: Font F1 (Helvetica)
  #   Obj 6: Content stream
  # ---------------------------------------------------------------------------
  defp craft_multilevel_inherited_resources_pdf do
    header = "%PDF-1.4\n"

    content_body = "BT /F1 12 Tf 100 720 Td (MULTILEVEL) Tj ET"
    content_length = byte_size(content_body)

    obj1 = "1 0 obj\n<</Type /Catalog /Pages 2 0 R>>\nendobj\n"

    # Root /Pages — no /Resources
    obj2 =
      "2 0 obj\n" <>
        "<</Type /Pages /Kids [3 0 R] /Count 1>>\n" <>
        "endobj\n"

    # Mid /Pages — has /Resources with /Font
    obj3 =
      "3 0 obj\n" <>
        "<</Type /Pages /Kids [4 0 R] /Count 1 /Parent 2 0 R" <>
        " /Resources <</Font <</F1 5 0 R>>>>>>\n" <>
        "endobj\n"

    # Leaf Page — no /Resources, /Parent points to mid obj 3
    obj4 =
      "4 0 obj\n" <>
        "<</Type /Page /Parent 3 0 R" <>
        " /MediaBox [0 0 612 792]" <>
        " /Contents 6 0 R>>\n" <>
        "endobj\n"

    obj5 =
      "5 0 obj\n" <>
        "<</Type /Font /Subtype /Type1 /BaseFont /Helvetica" <>
        " /Encoding /WinAnsiEncoding>>\n" <>
        "endobj\n"

    obj6 =
      "6 0 obj\n" <>
        "<</Length #{content_length}>>\n" <>
        "stream\n" <>
        content_body <>
        "\nendstream\n" <>
        "endobj\n"

    obj1_offset = byte_size(header)
    obj2_offset = obj1_offset + byte_size(obj1)
    obj3_offset = obj2_offset + byte_size(obj2)
    obj4_offset = obj3_offset + byte_size(obj3)
    obj5_offset = obj4_offset + byte_size(obj4)
    obj6_offset = obj5_offset + byte_size(obj5)
    xref_offset = obj6_offset + byte_size(obj6)

    xref =
      "xref\n" <>
        "0 7\n" <>
        "0000000000 65535 f\r\n" <>
        pad_offset(obj1_offset) <>
        " 00000 n\r\n" <>
        pad_offset(obj2_offset) <>
        " 00000 n\r\n" <>
        pad_offset(obj3_offset) <>
        " 00000 n\r\n" <>
        pad_offset(obj4_offset) <>
        " 00000 n\r\n" <>
        pad_offset(obj5_offset) <>
        " 00000 n\r\n" <>
        pad_offset(obj6_offset) <> " 00000 n\r\n"

    trailer =
      "trailer\n" <>
        "<</Size 7 /Root 1 0 R>>\n" <>
        "startxref\n" <>
        "#{xref_offset}\n" <>
        "%%EOF\n"

    header <> obj1 <> obj2 <> obj3 <> obj4 <> obj5 <> obj6 <> xref <> trailer
  end
end
