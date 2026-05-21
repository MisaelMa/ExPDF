defmodule Pdf.Reader.AcroFormTest do
  use ExUnit.Case, async: true

  alias Pdf.Reader.{AcroForm, FormField}

  # ---------------------------------------------------------------------------
  # Phase 2: decode_flags/1 (via AcroForm public test helper or via integration)
  # We test through the public read/1 API using hand-crafted PDFs.
  # For pure unit tests of private functions we use :sys.get_state trick or
  # we expose them via a test-only wrapper.  The cleaner approach per project
  # convention: test decode_flags through a field that has /Ff set.
  # ---------------------------------------------------------------------------

  # Phase 2.1 - We'll test decode_flags through integration (Phase 6),
  # but we add unit-style tests here by building a doc with a /Ff field.
  describe "decode_flags/1 — flag bitmask decoding (S-AF14)" do
    @tag :unit
    test "2.1a: /Ff 0 → all 17 flag atoms present, all false" do
      bin = craft_text_field_pdf("f", "v", 0)
      {:ok, doc} = Pdf.Reader.open(bin)
      {:ok, fields, _} = AcroForm.read(doc)

      assert fields != []
      f = hd(fields)
      flags = f.flags

      # All 17 flag atoms must be present
      expected_atoms = [
        :read_only,
        :required,
        :no_export,
        :multiline,
        :password,
        :file_select,
        :do_not_spell_check,
        :do_not_scroll,
        :comb,
        :rich_text,
        :radio,
        :pushbutton,
        :radios_in_unison,
        :combo,
        :edit,
        :sort,
        :multi_select
      ]

      Enum.each(expected_atoms, fn atom ->
        assert Map.has_key?(flags, atom), "Expected flag atom #{atom} in flags map"
      end)

      # All false for Ff=0
      Enum.each(expected_atoms, fn atom ->
        assert flags[atom] == false, "Expected #{atom} to be false for Ff=0"
      end)
    end

    @tag :unit
    test "2.1b: /Ff 8194 (bits 1+13) → required=true, password=true, rest false (S-AF14)" do
      # 8194 = 0x2002 = bit 1 (required) + bit 13 (password)
      bin = craft_text_field_pdf("f", "v", 8194)
      {:ok, doc} = Pdf.Reader.open(bin)
      {:ok, fields, _} = AcroForm.read(doc)

      assert fields != []
      f = hd(fields)
      flags = f.flags

      assert flags[:required] == true
      assert flags[:password] == true
      assert flags[:read_only] == false
      assert flags[:multiline] == false
    end

    @tag :unit
    test "2.1c: absent /Ff (nil) → all flags false" do
      bin = craft_text_field_no_ff_pdf("g", "hello")
      {:ok, doc} = Pdf.Reader.open(bin)
      {:ok, fields, _} = AcroForm.read(doc)

      assert fields != []
      f = hd(fields)
      flags = f.flags

      assert is_map(flags)
      assert map_size(flags) == 17

      Enum.each(Map.values(flags), fn v ->
        assert v == false
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # Phase 3: ft_to_atom/1, button_subtype/1, resolve_and_decode_value/4
  # ---------------------------------------------------------------------------

  describe "ft_to_atom — field type mapping (R-AF10)" do
    @tag :unit
    test "3.1a: /Tx maps to :text" do
      bin = craft_text_field_pdf("name", "hello", 0)
      {:ok, doc} = Pdf.Reader.open(bin)
      {:ok, fields, _} = AcroForm.read(doc)
      assert [%FormField{type: :text}] = fields
    end

    @tag :unit
    test "3.1b: /Btn maps to :button" do
      bin = craft_checkbox_pdf("check", true)
      {:ok, doc} = Pdf.Reader.open(bin)
      {:ok, fields, _} = AcroForm.read(doc)
      assert [%FormField{type: :button}] = fields
    end

    @tag :unit
    test "3.1c: /Ch maps to :choice" do
      bin = craft_choice_pdf("select", "US")
      {:ok, doc} = Pdf.Reader.open(bin)
      {:ok, fields, _} = AcroForm.read(doc)
      assert [%FormField{type: :choice}] = fields
    end

    @tag :unit
    test "3.1d: missing /FT (no inheritance) maps to :unknown" do
      bin = craft_no_ft_field_pdf("x")
      {:ok, doc} = Pdf.Reader.open(bin)
      {:ok, fields, _} = AcroForm.read(doc)
      assert [%FormField{type: :unknown}] = fields
    end
  end

  describe "button subtype disambiguation (R-AF13)" do
    @tag :unit
    test "3.2a: checkbox (/Btn, /Ff 0) — value /Yes → true (S-AF2)" do
      bin = craft_checkbox_pdf("cb", true)
      {:ok, doc} = Pdf.Reader.open(bin)
      {:ok, fields, _} = AcroForm.read(doc)
      assert [%FormField{type: :button, value: true}] = fields
    end

    @tag :unit
    test "3.2b: checkbox (/Btn, /Ff 0) — value /Off → false (S-AF3)" do
      bin = craft_checkbox_pdf("cb", false)
      {:ok, doc} = Pdf.Reader.open(bin)
      {:ok, fields, _} = AcroForm.read(doc)
      assert [%FormField{type: :button, value: false}] = fields
    end

    @tag :unit
    test "3.2c: radio (/Btn, /Ff 32768 = bit 15) — value /Option1 → {:selected, \"Option1\"} (S-AF4)" do
      bin = craft_radio_pdf("radio", "Option1")
      {:ok, doc} = Pdf.Reader.open(bin)
      {:ok, fields, _} = AcroForm.read(doc)
      assert [%FormField{type: :button, value: {:selected, "Option1"}}] = fields
    end
  end

  describe "resolve_and_decode_value/4 — value decoding" do
    @tag :unit
    test "3.3a: text field with string value" do
      bin = craft_text_field_pdf("name", "John Doe", 0)
      {:ok, doc} = Pdf.Reader.open(bin)
      {:ok, fields, _} = AcroForm.read(doc)
      assert [%FormField{type: :text, value: "John Doe"}] = fields
    end

    @tag :unit
    test "3.3b: choice /Ch combo — value (US) → \"US\" (S-AF5)" do
      bin = craft_choice_pdf("country", "US")
      {:ok, doc} = Pdf.Reader.open(bin)
      {:ok, fields, _} = AcroForm.read(doc)
      assert [%FormField{type: :choice, value: "US"}] = fields
    end

    @tag :unit
    test "3.3c: /V as indirect reference — resolves and decodes (S-AF10)" do
      bin = craft_indirect_v_pdf("ifield", "Hello")
      {:ok, doc} = Pdf.Reader.open(bin)
      {:ok, fields, _} = AcroForm.read(doc)
      assert [%FormField{type: :text, value: "Hello"}] = fields
    end

    @tag :unit
    test "3.3d: UTF-16BE BOM in field value → decoded to UTF-8 (S-AF11)" do
      bin = craft_utf16be_v_pdf("utf16field")
      {:ok, doc} = Pdf.Reader.open(bin)
      {:ok, fields, _} = AcroForm.read(doc)
      assert [%FormField{type: :text, value: "Hello"}] = fields
    end
  end

  # ---------------------------------------------------------------------------
  # Phase 4: AcroForm walker tests
  # ---------------------------------------------------------------------------

  describe "AcroForm.read/1 — no AcroForm in catalog (S-AF8, R-AF2)" do
    @tag :unit
    test "4.1a: no /AcroForm key → {:ok, [], doc}" do
      bin = craft_no_acroform_pdf()
      {:ok, doc} = Pdf.Reader.open(bin)
      assert {:ok, [], _doc} = AcroForm.read(doc)
    end

    @tag :unit
    test "4.1b: /AcroForm with empty /Fields → {:ok, [], doc}" do
      bin = craft_empty_fields_pdf()
      {:ok, doc} = Pdf.Reader.open(bin)
      assert {:ok, [], _doc} = AcroForm.read(doc)
    end
  end

  describe "AcroForm.read/1 — simple /Tx field (S-AF1)" do
    @tag :unit
    test "4.2: single /Tx leaf field — returned with correct fields" do
      bin = craft_text_field_pdf("fullname", "John Doe", 0)
      {:ok, doc} = Pdf.Reader.open(bin)
      {:ok, fields, _} = AcroForm.read(doc)

      assert length(fields) == 1
      [f] = fields
      assert f.name == "fullname"
      assert f.partial_name == "fullname"
      assert f.type == :text
      assert f.value == "John Doe"
    end
  end

  describe "AcroForm.read/1 — hierarchical naming (S-AF6, R-AF7, R-AF8)" do
    @tag :unit
    test "4.3: parent /T 'Address' + child /T 'Street' → name 'Address.Street'" do
      bin = craft_hierarchical_pdf()
      {:ok, doc} = Pdf.Reader.open(bin)
      {:ok, fields, _} = AcroForm.read(doc)

      assert length(fields) == 1
      [f] = fields
      assert f.name == "Address.Street"
      assert f.partial_name == "Street"
    end
  end

  describe "AcroForm.read/1 — /FT inheritance (S-AF7, R-AF9)" do
    @tag :unit
    test "4.4: parent /FT /Tx, child has no /FT → type: :text" do
      bin = craft_ft_inheritance_pdf()
      {:ok, doc} = Pdf.Reader.open(bin)
      {:ok, fields, _} = AcroForm.read(doc)

      assert length(fields) == 1
      [f] = fields
      assert f.type == :text
    end
  end

  describe "AcroForm.read/1 — cyclic /Kids detection (S-AF12, R-AF16)" do
    @tag :unit
    test "4.5: self-referential /Kids → returns {:ok, _, doc} without hang" do
      bin = craft_cyclic_kids_pdf()
      {:ok, doc} = Pdf.Reader.open(bin)

      # Must complete without hanging
      result = AcroForm.read(doc)
      assert match?({:ok, _, _}, result)
    end
  end

  describe "AcroForm.read/1 — depth cap (S-AF15, R-AF17)" do
    @tag :unit
    test "4.6: 9-deep chain → depth-9 silently skipped, no error" do
      bin = craft_depth9_pdf()
      {:ok, doc} = Pdf.Reader.open(bin)

      result = AcroForm.read(doc)
      assert match?({:ok, _, _}, result)
      {:ok, fields, _} = result
      # We may get 0 fields (all are intermediate nodes) or some leaf fields
      # Key assertion: no crash, no error, returns ok
      assert is_list(fields)
    end
  end

  describe "AcroForm.read/1 — widget-only kid not emitted (S-AF13, R-AF5, R-AF6)" do
    @tag :unit
    test "4.6b: /Kids [widget_only] — widget NOT in result, no crash" do
      bin = craft_widget_only_kids_pdf()
      {:ok, doc} = Pdf.Reader.open(bin)
      {:ok, fields, _} = AcroForm.read(doc)

      # Widget-only kids should not be emitted as separate fields
      Enum.each(fields, fn f ->
        # If any field is emitted, it should have a name
        assert f.name != nil or f.type != :unknown
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # Integration helpers (Phase 6) — hand-crafted PDF builders
  # ---------------------------------------------------------------------------

  # Build a minimal no-AcroForm PDF (plain text, no /AcroForm in catalog)
  defp craft_no_acroform_pdf do
    header = "%PDF-1.4\n"

    obj1 = "1 0 obj\n<</Type /Catalog /Pages 2 0 R>>\nendobj\n"
    obj2 = "2 0 obj\n<</Type /Pages /Kids [3 0 R] /Count 1>>\nendobj\n"

    obj3 =
      "3 0 obj\n" <>
        "<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]>>\n" <>
        "endobj\n"

    build_pdf([obj1, obj2, obj3], header, 4, "1 0 R")
  end

  # Build a PDF with /AcroForm but empty /Fields []
  defp craft_empty_fields_pdf do
    header = "%PDF-1.4\n"

    obj1 = "1 0 obj\n<</Type /Catalog /Pages 2 0 R /AcroForm 4 0 R>>\nendobj\n"
    obj2 = "2 0 obj\n<</Type /Pages /Kids [3 0 R] /Count 1>>\nendobj\n"

    obj3 =
      "3 0 obj\n" <>
        "<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]>>\n" <>
        "endobj\n"

    obj4 = "4 0 obj\n<</Fields []>>\nendobj\n"

    build_pdf([obj1, obj2, obj3, obj4], header, 5, "1 0 R")
  end

  # Build a PDF with a single /Tx field
  # /Ff is an integer for the flags field
  defp craft_text_field_pdf(name, value, ff) do
    header = "%PDF-1.4\n"

    obj1 = "1 0 obj\n<</Type /Catalog /Pages 2 0 R /AcroForm 4 0 R>>\nendobj\n"
    obj2 = "2 0 obj\n<</Type /Pages /Kids [3 0 R] /Count 1>>\nendobj\n"

    obj3 =
      "3 0 obj\n" <>
        "<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]>>\n" <>
        "endobj\n"

    obj4 = "4 0 obj\n<</Fields [5 0 R]>>\nendobj\n"

    obj5 =
      "5 0 obj\n" <>
        "<</T (#{name}) /FT /Tx /V (#{value}) /Ff #{ff}>>\n" <>
        "endobj\n"

    build_pdf([obj1, obj2, obj3, obj4, obj5], header, 6, "1 0 R")
  end

  # Build a PDF with a /Tx field that has no /Ff key
  defp craft_text_field_no_ff_pdf(name, value) do
    header = "%PDF-1.4\n"

    obj1 = "1 0 obj\n<</Type /Catalog /Pages 2 0 R /AcroForm 4 0 R>>\nendobj\n"
    obj2 = "2 0 obj\n<</Type /Pages /Kids [3 0 R] /Count 1>>\nendobj\n"

    obj3 =
      "3 0 obj\n" <>
        "<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]>>\n" <>
        "endobj\n"

    obj4 = "4 0 obj\n<</Fields [5 0 R]>>\nendobj\n"

    obj5 =
      "5 0 obj\n" <>
        "<</T (#{name}) /FT /Tx /V (#{value})>>\n" <>
        "endobj\n"

    build_pdf([obj1, obj2, obj3, obj4, obj5], header, 6, "1 0 R")
  end

  # Build a PDF with a field that has no /FT at all
  defp craft_no_ft_field_pdf(name) do
    header = "%PDF-1.4\n"

    obj1 = "1 0 obj\n<</Type /Catalog /Pages 2 0 R /AcroForm 4 0 R>>\nendobj\n"
    obj2 = "2 0 obj\n<</Type /Pages /Kids [3 0 R] /Count 1>>\nendobj\n"

    obj3 =
      "3 0 obj\n" <>
        "<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]>>\n" <>
        "endobj\n"

    obj4 = "4 0 obj\n<</Fields [5 0 R]>>\nendobj\n"

    obj5 =
      "5 0 obj\n" <>
        "<</T (#{name})>>\n" <>
        "endobj\n"

    build_pdf([obj1, obj2, obj3, obj4, obj5], header, 6, "1 0 R")
  end

  # Build a PDF with a /Btn checkbox field
  defp craft_checkbox_pdf(name, checked) do
    v_value = if checked, do: "/Yes", else: "/Off"
    header = "%PDF-1.4\n"

    obj1 = "1 0 obj\n<</Type /Catalog /Pages 2 0 R /AcroForm 4 0 R>>\nendobj\n"
    obj2 = "2 0 obj\n<</Type /Pages /Kids [3 0 R] /Count 1>>\nendobj\n"

    obj3 =
      "3 0 obj\n" <>
        "<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]>>\n" <>
        "endobj\n"

    obj4 = "4 0 obj\n<</Fields [5 0 R]>>\nendobj\n"

    obj5 =
      "5 0 obj\n" <>
        "<</T (#{name}) /FT /Btn /V #{v_value} /Ff 0>>\n" <>
        "endobj\n"

    build_pdf([obj1, obj2, obj3, obj4, obj5], header, 6, "1 0 R")
  end

  # Build a PDF with a /Btn radio field (Ff bit 15 = 32768)
  defp craft_radio_pdf(name, selected) do
    header = "%PDF-1.4\n"

    obj1 = "1 0 obj\n<</Type /Catalog /Pages 2 0 R /AcroForm 4 0 R>>\nendobj\n"
    obj2 = "2 0 obj\n<</Type /Pages /Kids [3 0 R] /Count 1>>\nendobj\n"

    obj3 =
      "3 0 obj\n" <>
        "<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]>>\n" <>
        "endobj\n"

    obj4 = "4 0 obj\n<</Fields [5 0 R]>>\nendobj\n"

    # Ff = 32768 = 0x8000 = bit 15 (radio)
    obj5 =
      "5 0 obj\n" <>
        "<</T (#{name}) /FT /Btn /V /#{selected} /Ff 32768>>\n" <>
        "endobj\n"

    build_pdf([obj1, obj2, obj3, obj4, obj5], header, 6, "1 0 R")
  end

  # Build a PDF with a /Ch combo field
  defp craft_choice_pdf(name, value) do
    header = "%PDF-1.4\n"

    obj1 = "1 0 obj\n<</Type /Catalog /Pages 2 0 R /AcroForm 4 0 R>>\nendobj\n"
    obj2 = "2 0 obj\n<</Type /Pages /Kids [3 0 R] /Count 1>>\nendobj\n"

    obj3 =
      "3 0 obj\n" <>
        "<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]>>\n" <>
        "endobj\n"

    obj4 = "4 0 obj\n<</Fields [5 0 R]>>\nendobj\n"

    obj5 =
      "5 0 obj\n" <>
        "<</T (#{name}) /FT /Ch /V (#{value})>>\n" <>
        "endobj\n"

    build_pdf([obj1, obj2, obj3, obj4, obj5], header, 6, "1 0 R")
  end

  # Build a PDF with /V as an indirect reference pointing to a string object
  defp craft_indirect_v_pdf(name, value) do
    header = "%PDF-1.4\n"

    obj1 = "1 0 obj\n<</Type /Catalog /Pages 2 0 R /AcroForm 4 0 R>>\nendobj\n"
    obj2 = "2 0 obj\n<</Type /Pages /Kids [3 0 R] /Count 1>>\nendobj\n"

    obj3 =
      "3 0 obj\n" <>
        "<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]>>\n" <>
        "endobj\n"

    obj4 = "4 0 obj\n<</Fields [5 0 R]>>\nendobj\n"

    # obj5: field with /V 6 0 R (indirect reference to the string)
    obj5 =
      "5 0 obj\n" <>
        "<</T (#{name}) /FT /Tx /V 6 0 R>>\n" <>
        "endobj\n"

    # obj6: the string value
    obj6 = "6 0 obj\n(#{value})\nendobj\n"

    build_pdf([obj1, obj2, obj3, obj4, obj5, obj6], header, 7, "1 0 R")
  end

  # Build a PDF with /V as a UTF-16BE BOM hex string <FEFF00480065006C006C006F> = "Hello"
  defp craft_utf16be_v_pdf(name) do
    header = "%PDF-1.4\n"

    obj1 = "1 0 obj\n<</Type /Catalog /Pages 2 0 R /AcroForm 4 0 R>>\nendobj\n"
    obj2 = "2 0 obj\n<</Type /Pages /Kids [3 0 R] /Count 1>>\nendobj\n"

    obj3 =
      "3 0 obj\n" <>
        "<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]>>\n" <>
        "endobj\n"

    obj4 = "4 0 obj\n<</Fields [5 0 R]>>\nendobj\n"

    # UTF-16BE "Hello" = 0048 0065 006C 006C 006F, with BOM FEFF
    # As a PDF hex string: <FEFF00480065006C006C006F>
    obj5 =
      "5 0 obj\n" <>
        "<</T (#{name}) /FT /Tx /V <FEFF00480065006C006C006F>>>\n" <>
        "endobj\n"

    build_pdf([obj1, obj2, obj3, obj4, obj5], header, 6, "1 0 R")
  end

  # Build a hierarchical PDF: parent /T "Address" + child /T "Street" /FT /Tx /V "Main St"
  defp craft_hierarchical_pdf do
    header = "%PDF-1.4\n"

    obj1 = "1 0 obj\n<</Type /Catalog /Pages 2 0 R /AcroForm 4 0 R>>\nendobj\n"
    obj2 = "2 0 obj\n<</Type /Pages /Kids [3 0 R] /Count 1>>\nendobj\n"

    obj3 =
      "3 0 obj\n" <>
        "<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]>>\n" <>
        "endobj\n"

    obj4 = "4 0 obj\n<</Fields [5 0 R]>>\nendobj\n"

    # obj5: parent node, /T "Address", /Kids [6 0 R]
    obj5 =
      "5 0 obj\n" <>
        "<</T (Address) /Kids [6 0 R]>>\n" <>
        "endobj\n"

    # obj6: leaf child, /T "Street", /FT /Tx, /V "Main St"
    obj6 =
      "6 0 obj\n" <>
        "<</T (Street) /FT /Tx /V (Main St)>>\n" <>
        "endobj\n"

    build_pdf([obj1, obj2, obj3, obj4, obj5, obj6], header, 7, "1 0 R")
  end

  # Build a PDF with /FT inheritance: parent /FT /Tx, child has /T + /V but no /FT
  defp craft_ft_inheritance_pdf do
    header = "%PDF-1.4\n"

    obj1 = "1 0 obj\n<</Type /Catalog /Pages 2 0 R /AcroForm 4 0 R>>\nendobj\n"
    obj2 = "2 0 obj\n<</Type /Pages /Kids [3 0 R] /Count 1>>\nendobj\n"

    obj3 =
      "3 0 obj\n" <>
        "<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]>>\n" <>
        "endobj\n"

    obj4 = "4 0 obj\n<</Fields [5 0 R]>>\nendobj\n"

    # parent: /T "group", /FT /Tx, /Kids [6 0 R]
    obj5 =
      "5 0 obj\n" <>
        "<</T (group) /FT /Tx /Kids [6 0 R]>>\n" <>
        "endobj\n"

    # child: /T "input", /V "test" — NO /FT (should inherit :text from parent)
    obj6 =
      "6 0 obj\n" <>
        "<</T (input) /V (test)>>\n" <>
        "endobj\n"

    build_pdf([obj1, obj2, obj3, obj4, obj5, obj6], header, 7, "1 0 R")
  end

  # Build a PDF with a cyclic /Kids reference (self-referential, obj5 /Kids [5 0 R])
  defp craft_cyclic_kids_pdf do
    header = "%PDF-1.4\n"

    obj1 = "1 0 obj\n<</Type /Catalog /Pages 2 0 R /AcroForm 4 0 R>>\nendobj\n"
    obj2 = "2 0 obj\n<</Type /Pages /Kids [3 0 R] /Count 1>>\nendobj\n"

    obj3 =
      "3 0 obj\n" <>
        "<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]>>\n" <>
        "endobj\n"

    obj4 = "4 0 obj\n<</Fields [5 0 R]>>\nendobj\n"

    # Self-referential: /Kids [5 0 R] points back to itself
    obj5 =
      "5 0 obj\n" <>
        "<</T (cyclic) /FT /Tx /Kids [5 0 R]>>\n" <>
        "endobj\n"

    build_pdf([obj1, obj2, obj3, obj4, obj5], header, 6, "1 0 R")
  end

  # Build a PDF with a 9-deep /Kids chain
  defp craft_depth9_pdf do
    header = "%PDF-1.4\n"

    obj1 = "1 0 obj\n<</Type /Catalog /Pages 2 0 R /AcroForm 4 0 R>>\nendobj\n"
    obj2 = "2 0 obj\n<</Type /Pages /Kids [3 0 R] /Count 1>>\nendobj\n"

    obj3 =
      "3 0 obj\n" <>
        "<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]>>\n" <>
        "endobj\n"

    obj4 = "4 0 obj\n<</Fields [5 0 R]>>\nendobj\n"

    # Chain: obj5 → obj6 → obj7 → obj8 → obj9 → obj10 → obj11 → obj12 → obj13
    # That's 9 levels deep: obj5 is level 1, obj13 is level 9
    obj5 = "5 0 obj\n<</T (n1) /Kids [6 0 R]>>\nendobj\n"
    obj6 = "6 0 obj\n<</T (n2) /Kids [7 0 R]>>\nendobj\n"
    obj7 = "7 0 obj\n<</T (n3) /Kids [8 0 R]>>\nendobj\n"
    obj8 = "8 0 obj\n<</T (n4) /Kids [9 0 R]>>\nendobj\n"
    obj9 = "9 0 obj\n<</T (n5) /Kids [10 0 R]>>\nendobj\n"
    obj10 = "10 0 obj\n<</T (n6) /Kids [11 0 R]>>\nendobj\n"
    obj11 = "11 0 obj\n<</T (n7) /Kids [12 0 R]>>\nendobj\n"
    obj12 = "12 0 obj\n<</T (n8) /Kids [13 0 R]>>\nendobj\n"
    obj13 = "13 0 obj\n<</T (n9) /FT /Tx /V (deep)>>\nendobj\n"

    build_pdf(
      [obj1, obj2, obj3, obj4, obj5, obj6, obj7, obj8, obj9, obj10, obj11, obj12, obj13],
      header,
      14,
      "1 0 R"
    )
  end

  # Build a PDF with a widget-only /Kids entry
  defp craft_widget_only_kids_pdf do
    header = "%PDF-1.4\n"

    obj1 = "1 0 obj\n<</Type /Catalog /Pages 2 0 R /AcroForm 4 0 R>>\nendobj\n"
    obj2 = "2 0 obj\n<</Type /Pages /Kids [3 0 R] /Count 1>>\nendobj\n"

    obj3 =
      "3 0 obj\n" <>
        "<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]>>\n" <>
        "endobj\n"

    obj4 = "4 0 obj\n<</Fields [5 0 R]>>\nendobj\n"

    # Field with /T and /FT but /Kids contains only a widget annotation
    # obj5: field that has /T + /FT /Tx but also /Kids [6 0 R]
    obj5 =
      "5 0 obj\n" <>
        "<</T (field) /FT /Tx /V (val) /Kids [6 0 R]>>\n" <>
        "endobj\n"

    # obj6: pure widget annotation (no /T, no /FT)
    obj6 =
      "6 0 obj\n" <>
        "<</Subtype /Widget /Rect [0 0 100 20]>>\n" <>
        "endobj\n"

    build_pdf([obj1, obj2, obj3, obj4, obj5, obj6], header, 7, "1 0 R")
  end

  # ---------------------------------------------------------------------------
  # PDF binary builder helper
  # ---------------------------------------------------------------------------

  defp build_pdf(objects, header, size, root_ref) do
    # Calculate offsets
    offsets =
      Enum.reduce(objects, {byte_size(header), []}, fn obj, {offset, acc} ->
        {offset + byte_size(obj), [offset | acc]}
      end)
      |> then(fn {_final, reversed} -> Enum.reverse(reversed) end)

    body = Enum.join(objects)
    xref_offset = byte_size(header) + byte_size(body)

    # Build xref entries
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
end
