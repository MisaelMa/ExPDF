defmodule Pdf.Reader.XRefTest do
  use ExUnit.Case, async: true

  alias Pdf.Reader.XRef

  # ---------------------------------------------------------------------------
  # Helpers for building hand-crafted minimal PDF binary fixtures.
  #
  # These fixtures are binary-level, not text-level, because xref streams
  # embed binary-encoded entries (not ASCII) and the parser reads raw bytes.
  # ---------------------------------------------------------------------------

  # Build a raw xref stream body for given entries and widths.
  defp build_xref_stream_body(entries, {w1, w2, w3}) do
    Enum.reduce(entries, <<>>, fn {t, f2, f3}, acc ->
      type_bytes =
        if w1 > 0, do: encode_uint(t, w1), else: <<>>

      f2_bytes = encode_uint(f2, w2)
      f3_bytes = if w3 > 0, do: encode_uint(f3, w3), else: <<>>
      acc <> type_bytes <> f2_bytes <> f3_bytes
    end)
  end

  defp encode_uint(value, n) do
    raw = :binary.encode_unsigned(value, :big)
    pad = n - byte_size(raw)

    if pad >= 0,
      do: :binary.copy(<<0>>, pad) <> raw,
      else: binary_part(raw, byte_size(raw) - n, n)
  end

  # ---------------------------------------------------------------------------
  # Task 5.1.5 — XRef.load/2 dispatches to classic xref
  # ---------------------------------------------------------------------------

  describe "load/2 — classic xref dispatch" do
    test "correctly dispatches to Classic parser when xref keyword is at offset" do
      # Hand-crafted minimal PDF with classic xref at startxref offset 0.
      # xref has 2 objects: 0 (free) + 1 (in-use at offset 200).
      binary = """
      xref
      0 2
      0000000000 65535 f\r
      0000000200 00000 n\r
      trailer
      <</Size 2/Root 1 0 R>>
      startxref
      0
      %%EOF
      """

      # The binary starts with "xref" at offset 0.
      assert {:ok, entries, trailer} = XRef.load(binary, 0)
      assert entries[{0, 65_535}] == :free
      assert entries[{1, 0}] == {:in_use, 200, 0}
      assert trailer.root == {:ref, 1, 0}
    end
  end

  # ---------------------------------------------------------------------------
  # Task 5.1.4 + 5.1.5 — XRef.load/2 dispatches to stream parser
  # ---------------------------------------------------------------------------

  describe "load/2 — xref stream dispatch" do
    test "correctly dispatches to Stream parser when object header is at offset" do
      # Build an inline xref stream: the stream body has 2 entries.
      # Entry 0: free. Entry 1: in_use at offset 200.
      # W = [1 2 1], Size = 2.
      stream_body = build_xref_stream_body([{0, 0, 0}, {1, 200, 0}], {1, 2, 1})

      # Build the stream dict (serialized as PDF object).
      # We construct a minimal xref stream object at byte offset 0.
      # The dict is embedded directly as inline ASCII for this fixture.
      body_len = byte_size(stream_body)

      # PDF object format: "N G obj\n<< /Type /XRef /W [1 2 1] /Size 2 /Length N >>\nstream\n...body...\nendstream\nendobj"
      dict_str =
        "<< /Type /XRef /W [1 2 1] /Size 2 /Root 1 0 R /Length #{body_len} >>"

      object_binary =
        "1 0 obj\n" <>
          dict_str <>
          "\nstream\n" <>
          stream_body <>
          "\nendstream\nendobj\n"

      # load/2 at offset 0 should detect "N G obj" and dispatch to Stream parser.
      assert {:ok, entries, trailer} = XRef.load(object_binary, 0)
      assert entries[{0, 0}] == :free
      assert entries[{1, 0}] == {:in_use, 200, 0}
      assert trailer.root == {:ref, 1, 0}
    end
  end

  # ---------------------------------------------------------------------------
  # Task 5.1.3 + 5.1.4 — /Prev chain across two xref streams
  # ---------------------------------------------------------------------------

  describe "load/2 — /Prev chain across xref streams" do
    test "/Prev chain: newer xref stream overrides older xref stream entries" do
      # PDF with two xref stream revisions:
      #   Revision 1 (older, at offset 0): obj 1 at offset 100, obj 2 at offset 200
      #   Revision 2 (newer, at offset X): obj 2 updated to offset 300
      # After chain merge: obj 1 → 100, obj 2 → 300 (newer wins)

      # Build revision 1 stream body: obj 0 free, obj 1 in_use@100, obj 2 in_use@200
      rev1_body = build_xref_stream_body([{0, 0, 0}, {1, 100, 0}, {1, 200, 0}], {1, 2, 1})
      rev1_len = byte_size(rev1_body)

      rev1_dict = "<< /Type /XRef /W [1 2 1] /Size 3 /Root 1 0 R /Length #{rev1_len} >>"

      rev1_object =
        "1 0 obj\n" <> rev1_dict <> "\nstream\n" <> rev1_body <> "\nendstream\nendobj\n"

      rev1_offset = 0
      rev1_size = byte_size(rev1_object)

      # Build revision 2 stream body: only obj 2 updated to offset 300
      # /Index [2 1] — one subsection covering only obj 2
      rev2_body = build_xref_stream_body([{1, 300, 0}], {1, 2, 1})
      rev2_len = byte_size(rev2_body)

      rev2_dict =
        "<< /Type /XRef /W [1 2 1] /Size 3 /Index [2 1] /Root 1 0 R /Prev #{rev1_offset} /Length #{rev2_len} >>"

      rev2_object =
        "2 0 obj\n" <> rev2_dict <> "\nstream\n" <> rev2_body <> "\nendstream\nendobj\n"

      _rev2_offset = rev1_size

      # Concatenate into one binary (rev1 then rev2)
      binary = rev1_object <> rev2_object

      # Load from rev2's offset (the "newer" xref stream)
      assert {:ok, entries, _trailer} = XRef.load(binary, rev1_size)

      # obj 1 from rev1 (not overridden): in_use at 100
      assert entries[{1, 0}] == {:in_use, 100, 0}

      # obj 2 from rev2 (newer wins): in_use at 300
      assert entries[{2, 0}] == {:in_use, 300, 0}
    end
  end

  # ---------------------------------------------------------------------------
  # Task 5.1.5 — hybrid /Prev chain (classic + stream xrefs)
  # ---------------------------------------------------------------------------

  describe "load/2 — hybrid /Prev chain (classic + stream)" do
    test "stream xref with /Prev pointing to classic xref merges correctly" do
      # Revision 1 (older): classic xref with obj 1 at offset 100
      classic_binary = """
      xref
      0 2
      0000000000 65535 f\r
      0000000100 00000 n\r
      trailer
      <</Size 2/Root 1 0 R>>
      startxref
      0
      %%EOF
      """

      classic_size = byte_size(classic_binary)

      # Revision 2 (newer): xref stream adding obj 2, referencing classic via /Prev
      rev2_body = build_xref_stream_body([{1, 200, 0}], {1, 2, 1})
      rev2_len = byte_size(rev2_body)

      rev2_dict =
        "<< /Type /XRef /W [1 2 1] /Size 3 /Index [2 1] /Root 1 0 R /Prev 0 /Length #{rev2_len} >>"

      rev2_object =
        "3 0 obj\n" <> rev2_dict <> "\nstream\n" <> rev2_body <> "\nendstream\nendobj\n"

      binary = classic_binary <> rev2_object

      # Load from rev2's offset
      assert {:ok, entries, _trailer} = XRef.load(binary, classic_size)

      # obj 1 from classic (rev1)
      assert entries[{1, 0}] == {:in_use, 100, 0}

      # obj 2 from stream (rev2)
      assert entries[{2, 0}] == {:in_use, 200, 0}
    end
  end

  # ---------------------------------------------------------------------------
  # Error cases
  # ---------------------------------------------------------------------------

  describe "load/2 — error cases" do
    test "returns error when offset is out of bounds" do
      assert {:error, :xref_offset_out_of_range} = XRef.load(<<"short">>, 9999)
    end

    test "returns error when content at offset is neither classic nor stream xref" do
      assert {:error, :xref_not_found} = XRef.load(<<"garbage bytes here">>, 0)
    end
  end
end
