defmodule Pdf.Reader.ObjectStreamTest do
  use ExUnit.Case, async: true

  alias Pdf.Reader.ObjectStream

  # ---------------------------------------------------------------------------
  # Helpers for building ObjStm body fixtures.
  #
  # Per PDF 1.7 § 7.5.7 "Object Streams":
  #   - /N — number of compressed objects.
  #   - /First — byte offset from the start of the decoded body to the first
  #              object's data.
  #   - The decoded body has two parts:
  #     1. Header: N pairs "obj_num offset" (whitespace-separated, offsets
  #        are RELATIVE to /First).
  #     2. Starting at /First: concatenated raw object bodies (PDF values, not
  #        full indirect objects — no "N G obj...endobj" wrapper).
  #   - Compressed objects MUST NOT be streams; generation is always 0.
  # ---------------------------------------------------------------------------

  # Build a decoded ObjStm body for given objects.
  # `objects` is [{obj_num, serialized_value_string}].
  # Returns {header_pairs, body_binary} where header encodes offsets relative to /First.
  defp build_objstm_body(objects) do
    # Serialize all object values concatenated
    values_binary =
      Enum.map_join(objects, "", fn {_num, val} -> val <> " " end)

    # Compute offsets for each object
    {header_pairs, _} =
      Enum.reduce(objects, {[], 0}, fn {num, val}, {pairs, offset} ->
        {pairs ++ [{num, offset}], offset + byte_size(val) + 1}
      end)

    # Build the header string: "num1 off1 num2 off2 ..."
    header_str =
      Enum.map_join(header_pairs, " ", fn {num, off} -> "#{num} #{off}" end) <> " "

    header_str <> values_binary
  end

  # ---------------------------------------------------------------------------
  # Task 5.2.1 — fetch/2 decodes and returns the value at a given index
  #
  # Per PDF 1.7 § 7.5.7:
  # fetch/2 accepts:
  #   - first: the /First offset (byte where object data starts)
  #   - body:  the decoded stream body binary
  #   - index: 0-based index of the desired object
  # Returns {:ok, value} or {:error, reason}.
  # ---------------------------------------------------------------------------

  describe "fetch/3 — basic ObjStm decoding" do
    test "fetches the first object from an ObjStm body" do
      # Body has two objects:
      #   obj 10: integer 42
      #   obj 11: boolean true
      body = build_objstm_body([{10, "42"}, {11, "true"}])

      # /First is the byte offset where obj values start.
      # Header is "10 0 11 3 " (10 chars + space = offset 10+1=11 chars)
      # After header: "42 true "
      first = String.length("10 0 11 3 ")

      assert {:ok, 42} = ObjectStream.fetch(first, body, 0)
    end

    test "fetches the second object from an ObjStm body" do
      body = build_objstm_body([{10, "42"}, {11, "true"}])
      first = String.length("10 0 11 3 ")

      assert {:ok, true} = ObjectStream.fetch(first, body, 1)
    end

    test "fetches a name object" do
      body = build_objstm_body([{5, "/FlateDecode"}])
      first = String.length("5 0 ")

      assert {:ok, {:name, "FlateDecode"}} = ObjectStream.fetch(first, body, 0)
    end

    test "fetches a dictionary object" do
      body = build_objstm_body([{20, "<</Type /Page /Parent 1 0 R>>"}, {21, "100"}])
      # Header: "20 0 21 N " where N = length of the dict string + 1 (space)
      dict_len = byte_size("<</Type /Page /Parent 1 0 R>>") + 1
      first = String.length("20 0 21 #{dict_len} ")

      assert {:ok, dict} = ObjectStream.fetch(first, body, 0)
      assert is_map(dict)
      assert dict["Type"] == {:name, "Page"}
    end

    test "fetches multiple objects from a 3-object ObjStm" do
      body = build_objstm_body([{5, "100"}, {6, "200"}, {7, "300"}])
      # header: "5 0 6 4 7 8 " → 12 chars
      first = String.length("5 0 6 4 7 8 ")

      assert {:ok, 100} = ObjectStream.fetch(first, body, 0)
      assert {:ok, 200} = ObjectStream.fetch(first, body, 1)
      assert {:ok, 300} = ObjectStream.fetch(first, body, 2)
    end
  end

  describe "fetch/3 — error cases" do
    test "returns error when index is out of range (no objects)" do
      # Empty body with header indicating 0 objects.
      # No entries in header, /First = 0.
      body = ""
      assert {:error, :objstm_index_out_of_range} = ObjectStream.fetch(0, body, 0)
    end

    test "returns error when index exceeds the number of objects" do
      body = build_objstm_body([{10, "42"}])
      first = String.length("10 0 ")

      # Only 1 object; requesting index 1 is out of range.
      assert {:error, :objstm_index_out_of_range} = ObjectStream.fetch(first, body, 1)
    end
  end
end
