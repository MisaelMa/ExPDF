defmodule Pdf.Reader.XRef.StreamTest do
  use ExUnit.Case, async: true

  alias Pdf.Reader.XRef.Stream, as: XRefStream

  # ---------------------------------------------------------------------------
  # Helpers for building minimal xref stream bodies in tests.
  #
  # Per PDF 1.7 § 7.5.8:
  #   - /W [w1 w2 w3] — byte widths of the three fields per entry.
  #   - /Index [first count ...] — subsections; default [0 Size].
  #   - /Size — total number of objects.
  #   - Each entry is exactly w1+w2+w3 bytes.
  #   - Type 0: free entry  (w2 = next free obj, w3 = gen)
  #   - Type 1: in-use      (w2 = byte offset,   w3 = gen)
  #   - Type 2: compressed  (w2 = ObjStm obj num, w3 = index in ObjStm)
  #
  # Note on /Filter:
  #   Most tests below pass the raw (uncompressed) body directly by omitting
  #   /Filter from the dict. One dedicated test verifies FlateDecode integration.
  # ---------------------------------------------------------------------------

  # Build a stream body binary from a list of entries, each {type, f2, f3}
  # where f2/f3 are encoded with given byte widths.
  # Uses :binary.encode_unsigned to handle values wider than 1 byte correctly.
  defp build_body(entries, {w1, w2, w3}) do
    Enum.reduce(entries, <<>>, fn {t, f2, f3}, acc ->
      type_bytes =
        if w1 > 0,
          do: encode_uint(t, w1),
          else: <<>>

      f2_bytes = encode_uint(f2, w2)
      f3_bytes = if w3 > 0, do: encode_uint(f3, w3), else: <<>>
      acc <> type_bytes <> f2_bytes <> f3_bytes
    end)
  end

  # Encode an unsigned integer as exactly `n` bytes (big-endian, zero-padded).
  defp encode_uint(value, n) do
    raw = :binary.encode_unsigned(value, :big)
    pad = n - byte_size(raw)

    if pad >= 0 do
      :binary.copy(<<0>>, pad) <> raw
    else
      # Truncate to n bytes (take the least significant n bytes)
      binary_part(raw, byte_size(raw) - n, n)
    end
  end

  # Zlib-deflate a binary.
  defp deflate(data) do
    z = :zlib.open()
    :zlib.deflateInit(z, :default)
    chunks = :zlib.deflate(z, data, :finish)
    :zlib.deflateEnd(z)
    :zlib.close(z)
    IO.iodata_to_binary(chunks)
  end

  # ---------------------------------------------------------------------------
  # Task 5.1.1 — parse a /Type /XRef stream into the entries map
  #
  # Per PDF 1.7 § 7.5.8:
  #   W=[1 2 1] → 4 bytes per entry. Type 0=free, 1=in_use, 2=compressed.
  #   Gen field width w3=1 → max gen = 255.
  #   Classic xref uses gen=65535 for the free-list head (5 ASCII digits);
  #   xref streams encode gen in w3 bytes, so gen=0 is the typical free-list head.
  # ---------------------------------------------------------------------------

  describe "parse/1 — basic /Type /XRef stream (raw body, no filter)" do
    test "W [1 2 1] single subsection — type 1 (in_use) and type 0 (free)" do
      # Per PDF 1.7 § 7.5.8 Table 18:
      # Entry [0]: type 0 (free), next_free_obj=0, gen=0
      # Entry [1]: type 1 (in_use), offset=9, gen=0
      # Entry [2]: type 1 (in_use), offset=100, gen=0
      # No /Filter → raw body passed directly.
      entries_raw = [
        {0, 0, 0},
        {1, 9, 0},
        {1, 100, 0}
      ]

      body = build_body(entries_raw, {1, 2, 1})

      dict = %{
        "Type" => {:name, "XRef"},
        "Size" => 3,
        "W" => [1, 2, 1],
        "Length" => byte_size(body)
      }

      assert {:ok, entries} = XRefStream.parse({:stream, dict, body})

      # Object 0 gen 0 → free
      assert entries[{0, 0}] == :free

      # Object 1 gen 0 → in_use at offset 9
      assert entries[{1, 0}] == {:in_use, 9, 0}

      # Object 2 gen 0 → in_use at offset 100
      assert entries[{2, 0}] == {:in_use, 100, 0}
    end

    test "W [1 4 2] — type 2 (compressed) entry — points to ObjStm" do
      # Type 2: w2 = ObjStm obj_num, w3 = index within ObjStm
      # W = [1 4 2] → entry size = 7 bytes. w3=2 → gen field can hold up to 65535.
      entries_raw = [
        # type 0 (free): next_free=0, gen=0
        {0, 0, 0},
        # type 2 (compressed): ObjStm obj_num=5, index=0
        {2, 5, 0},
        # type 2 (compressed): ObjStm obj_num=5, index=1
        {2, 5, 1}
      ]

      body = build_body(entries_raw, {1, 4, 2})

      dict = %{
        "Type" => {:name, "XRef"},
        "Size" => 3,
        "W" => [1, 4, 2],
        "Length" => byte_size(body)
      }

      assert {:ok, entries} = XRefStream.parse({:stream, dict, body})

      # obj 0 gen 0 → free
      assert entries[{0, 0}] == :free

      # obj 1 gen 0 → compressed in ObjStm obj 5, index 0
      assert entries[{1, 0}] == {:compressed, 5, 0}

      # obj 2 gen 0 → compressed in ObjStm obj 5, index 1
      assert entries[{2, 0}] == {:compressed, 5, 1}
    end

    test "W with a zero field (w1=0) — all entries treated as type 1 (in_use)" do
      # Per PDF 1.7 § 7.5.8: if w1 is 0, field is absent and every entry is type 1.
      # W = [0 4 1] → entry size = 5 bytes (no type field)
      # Objects 0, 1, 2 all implicitly type 1 (in_use).
      # Build without type byte: just f2 (4 bytes) + f3 (1 byte).
      body =
        <<0::integer-size(4)-unit(8), 0::integer-size(1)-unit(8)>> <>
          <<9::integer-size(4)-unit(8), 0::integer-size(1)-unit(8)>> <>
          <<200::integer-size(4)-unit(8), 1::integer-size(1)-unit(8)>>

      dict = %{
        "Type" => {:name, "XRef"},
        "Size" => 3,
        "W" => [0, 4, 1],
        "Length" => byte_size(body)
      }

      assert {:ok, entries} = XRefStream.parse({:stream, dict, body})

      # All entries should be in_use (type 1 default when w1=0)
      assert entries[{0, 0}] == {:in_use, 0, 0}
      assert entries[{1, 0}] == {:in_use, 9, 0}
      assert entries[{2, 1}] == {:in_use, 200, 1}
    end

    test "W [1 4 2] with large offset values" do
      # Verify big-endian multi-byte field decoding.
      # offset 0xABCD12 in 4 bytes, index 255 in 2 bytes.
      body = build_body([{1, 0x00AB_CD12, 0}], {1, 4, 2})

      dict = %{
        "Type" => {:name, "XRef"},
        "Size" => 1,
        "W" => [1, 4, 2],
        "Length" => byte_size(body)
      }

      assert {:ok, entries} = XRefStream.parse({:stream, dict, body})
      assert entries[{0, 0}] == {:in_use, 0x00AB_CD12, 0}
    end

    test "returns error for non-XRef stream" do
      dict = %{
        "Type" => {:name, "ObjStm"},
        "Size" => 0,
        "W" => [1, 2, 1],
        "Length" => 0
      }

      assert {:error, :not_an_xref_stream} = XRefStream.parse({:stream, dict, <<>>})
    end
  end

  # ---------------------------------------------------------------------------
  # Task 5.1.1 (FlateDecode integration) — verify filter chain is applied
  # ---------------------------------------------------------------------------

  describe "parse/1 — FlateDecode-compressed xref stream" do
    test "decodes a FlateDecode-compressed body and parses entries correctly" do
      # This test validates the filter integration path:
      # Stream body is zlib-compressed; dict has /Filter /FlateDecode.
      entries_raw = [
        {0, 0, 0},
        {1, 9, 0},
        {1, 100, 0}
      ]

      body = build_body(entries_raw, {1, 2, 1})
      compressed = deflate(body)

      dict = %{
        "Type" => {:name, "XRef"},
        "Size" => 3,
        "W" => [1, 2, 1],
        # Explicitly specify the filter — this is the normal real-world case.
        "Filter" => {:name, "FlateDecode"},
        "Length" => byte_size(compressed)
      }

      assert {:ok, entries} = XRefStream.parse({:stream, dict, compressed})

      assert entries[{0, 0}] == :free
      assert entries[{1, 0}] == {:in_use, 9, 0}
      assert entries[{2, 0}] == {:in_use, 100, 0}
    end
  end

  # ---------------------------------------------------------------------------
  # Task 5.1.3 — /Index subsections + multi-subsection
  # ---------------------------------------------------------------------------

  describe "parse/1 — /Index subsections" do
    test "explicit /Index with two subsections" do
      # /Index [0 2 10 1] — two subsections:
      #   subsection 1: objects 0..1 (2 entries)
      #   subsection 2: object 10 (1 entry)
      # W = [1 2 1]; no /Filter (raw body).
      entries_raw = [
        # subsection 1: obj 0 free, obj 1 in_use
        {0, 0, 0},
        {1, 9, 0},
        # subsection 2: obj 10 in_use at offset 500
        {1, 500, 0}
      ]

      body = build_body(entries_raw, {1, 2, 1})

      dict = %{
        "Type" => {:name, "XRef"},
        "Size" => 11,
        "W" => [1, 2, 1],
        "Index" => [0, 2, 10, 1],
        "Length" => byte_size(body)
      }

      assert {:ok, entries} = XRefStream.parse({:stream, dict, body})

      assert entries[{0, 0}] == :free
      assert entries[{1, 0}] == {:in_use, 9, 0}
      assert entries[{10, 0}] == {:in_use, 500, 0}

      # Objects not in index should not be present
      refute Map.has_key?(entries, {2, 0})
      refute Map.has_key?(entries, {9, 0})
    end
  end

  # ---------------------------------------------------------------------------
  # Task 5.1.3 — /Prev chain metadata
  # ---------------------------------------------------------------------------

  describe "parse/1 — /Prev chain" do
    test "parse/1 succeeds and entries are correct when /Prev is set" do
      # /Prev is a metadata field in the dict — parse/1 returns the entries.
      # The /Prev value is exposed via the dict for XRef.load to follow.
      body = build_body([{1, 9, 0}], {1, 2, 1})

      dict = %{
        "Type" => {:name, "XRef"},
        "Size" => 1,
        "W" => [1, 2, 1],
        "Prev" => 42,
        "Length" => byte_size(body)
      }

      assert {:ok, entries} = XRefStream.parse({:stream, dict, body})
      assert entries[{0, 0}] == {:in_use, 9, 0}
      # The /Prev value (42) is in dict["Prev"] — XRef.load reads it from the dict.
      assert dict["Prev"] == 42
    end
  end
end
