defmodule Pdf.Reader.ObjectResolverTest do
  use ExUnit.Case, async: true

  alias Pdf.Reader.{ObjectResolver, Document}

  # ---------------------------------------------------------------------------
  # Helpers for building minimal test documents.
  #
  # We construct %Document{} structs with hand-crafted xref entries and
  # binary content rather than parsing real PDFs. This keeps tests fast and
  # deterministic, and matches the spec-data-from-source mandate.
  #
  # The binary content embedded in docs follows "N G obj <value> endobj" format,
  # which matches Pdf.Reader.Parser.parse_object/1 expectations.
  # ---------------------------------------------------------------------------

  # Build a document whose binary has one in-use object at a given offset.
  # The object is "obj_num 0 obj <value_str> endobj".
  defp doc_with_object(obj_num, value_str, opts \\ []) do
    prefix = Keyword.get(opts, :prefix, "")
    suffix = Keyword.get(opts, :suffix, "")
    offset = byte_size(prefix)

    object_binary = "#{obj_num} 0 obj\n#{value_str}\nendobj\n"
    full_binary = prefix <> object_binary <> suffix

    xref = %{{obj_num, 0} => {:in_use, offset, 0}}

    %Document{
      binary: full_binary,
      xref: xref,
      cache: %{}
    }
  end

  # ---------------------------------------------------------------------------
  # Task 6.1 — resolve/2 resolves a {:ref, n, g} from cache (cache hit)
  # ---------------------------------------------------------------------------

  describe "resolve/2 — cache hit" do
    test "returns cached value without parsing binary" do
      # Document with a pre-populated cache and no valid binary for the ref.
      # resolve/2 must return the cached value, NOT attempt to read from binary.
      doc = %Document{
        binary: <<"garbage">>,
        xref: %{{1, 0} => {:in_use, 0, 0}},
        cache: %{{1, 0} => 42}
      }

      assert {:ok, 42, ^doc} = ObjectResolver.resolve(doc, {:ref, 1, 0})
    end

    test "returns same doc when value is from cache (no cache mutation)" do
      doc = %Document{
        binary: <<>>,
        xref: %{{5, 0} => {:in_use, 0, 0}},
        cache: %{{5, 0} => {:name, "XObject"}}
      }

      assert {:ok, {:name, "XObject"}, returned_doc} = ObjectResolver.resolve(doc, {:ref, 5, 0})
      # Doc is unchanged — no new entries added, cache was already populated.
      assert returned_doc.cache == doc.cache
    end
  end

  # ---------------------------------------------------------------------------
  # Task 6.2 — resolve/2 parses from binary on cache miss (type 1, in_use)
  # ---------------------------------------------------------------------------

  describe "resolve/2 — cache miss, in_use entry" do
    test "parses integer object from binary" do
      doc = doc_with_object(1, "42")

      assert {:ok, 42, updated_doc} = ObjectResolver.resolve(doc, {:ref, 1, 0})
      # Value is cached for subsequent calls
      assert updated_doc.cache[{1, 0}] == 42
    end

    test "parses boolean object from binary" do
      doc = doc_with_object(2, "true")

      assert {:ok, true, updated_doc} = ObjectResolver.resolve(doc, {:ref, 2, 0})
      assert updated_doc.cache[{2, 0}] == true
    end

    test "parses name object from binary" do
      doc = doc_with_object(3, "/FlateDecode")

      assert {:ok, {:name, "FlateDecode"}, updated_doc} =
               ObjectResolver.resolve(doc, {:ref, 3, 0})

      assert updated_doc.cache[{3, 0}] == {:name, "FlateDecode"}
    end

    test "parses dictionary object from binary" do
      doc = doc_with_object(4, "<</Type /Page /MediaBox [0 0 612 792]>>")

      assert {:ok, dict, updated_doc} = ObjectResolver.resolve(doc, {:ref, 4, 0})
      assert is_map(dict)
      assert dict["Type"] == {:name, "Page"}
      assert updated_doc.cache[{4, 0}] == dict
    end

    test "second call hits cache (same value, same doc structure)" do
      doc = doc_with_object(1, "99")

      {:ok, 99, doc2} = ObjectResolver.resolve(doc, {:ref, 1, 0})
      # Second call on doc2 — should be a cache hit
      assert {:ok, 99, ^doc2} = ObjectResolver.resolve(doc2, {:ref, 1, 0})
    end

    test "parses stream object — returns {:stream, dict, raw_bytes}" do
      # A stream object: dict + raw stream body.
      # Parser.parse_object/1 returns {:stream, dict, raw_bytes} for stream objects.
      stream_content = "Hello stream"
      len = byte_size(stream_content)

      doc =
        doc_with_object(
          7,
          "<</Filter /FlateDecode /Length #{len}>>\nstream\n#{stream_content}\nendstream"
        )

      assert {:ok, {:stream, dict, body}, _updated_doc} =
               ObjectResolver.resolve(doc, {:ref, 7, 0})

      assert dict["Filter"] == {:name, "FlateDecode"}
      assert body == stream_content
    end
  end

  # ---------------------------------------------------------------------------
  # Task 6.2 — Error cases for in_use resolution
  # ---------------------------------------------------------------------------

  describe "resolve/2 — errors" do
    test "returns error for ref not in xref table" do
      doc = %Document{binary: <<>>, xref: %{}, cache: %{}}

      assert {:error, {:unresolved_ref, {99, 0}}} =
               ObjectResolver.resolve(doc, {:ref, 99, 0})
    end

    test "returns error for free entry" do
      doc = %Document{
        binary: <<"anything">>,
        xref: %{{0, 0} => :free},
        cache: %{}
      }

      assert {:error, {:unresolved_ref, {0, 0}}} =
               ObjectResolver.resolve(doc, {:ref, 0, 0})
    end

    test "returns error when binary at offset is not a valid object" do
      doc = %Document{
        binary: <<"garbage not an object">>,
        xref: %{{1, 0} => {:in_use, 0, 0}},
        cache: %{}
      }

      assert {:error, :malformed} = ObjectResolver.resolve(doc, {:ref, 1, 0})
    end
  end

  # ---------------------------------------------------------------------------
  # Task 6.3 + 6.4 — ObjStm resolution path (compressed entries)
  # ---------------------------------------------------------------------------

  describe "resolve/2 — compressed objects (ObjStm path)" do
    test "resolves a {:compressed, objstm_obj_num, index} entry" do
      # Build a minimal ObjStm binary.
      # ObjStm body contains two objects: obj 10 (value 42), obj 11 (value true).
      # /First = length of header "10 0 11 3 " = 10 bytes.
      # Body: "10 0 11 3 42 true "
      objstm_body = "10 0 11 3 42 true "
      objstm_first = 10
      objstm_len = byte_size(objstm_body)

      # The ObjStm itself is object 5 in the document.
      # It's a stream with /Type /ObjStm, /N 2, /First 10.
      # We store it as an in_use object at some offset.
      objstm_obj_str =
        "<</Type /ObjStm /N 2 /First #{objstm_first} /Length #{objstm_len}>>" <>
          "\nstream\n" <>
          objstm_body <>
          "\nendstream"

      doc =
        doc_with_object(5, objstm_obj_str)
        |> then(fn doc ->
          # Add xref entries for the compressed objects:
          # obj 10 is at index 0 in ObjStm 5; obj 11 at index 1.
          new_xref =
            doc.xref
            |> Map.put({10, 0}, {:compressed, 5, 0})
            |> Map.put({11, 0}, {:compressed, 5, 1})

          %{doc | xref: new_xref}
        end)

      # Resolve obj 10 (index 0 in ObjStm 5)
      assert {:ok, 42, doc2} = ObjectResolver.resolve(doc, {:ref, 10, 0})
      assert doc2.cache[{10, 0}] == 42

      # Resolve obj 11 (index 1 in ObjStm 5)
      assert {:ok, true, doc3} = ObjectResolver.resolve(doc, {:ref, 11, 0})
      assert doc3.cache[{11, 0}] == true
    end

    test "ObjStm itself is cached after first resolution" do
      objstm_body = "20 0 99 "
      objstm_first = 5
      objstm_len = byte_size(objstm_body)

      objstm_obj_str =
        "<</Type /ObjStm /N 1 /First #{objstm_first} /Length #{objstm_len}>>" <>
          "\nstream\n" <>
          objstm_body <>
          "\nendstream"

      doc =
        doc_with_object(8, objstm_obj_str)
        |> then(fn doc ->
          new_xref = Map.put(doc.xref, {20, 0}, {:compressed, 8, 0})
          %{doc | xref: new_xref}
        end)

      # First resolution — parses ObjStm and resolves obj 20
      {:ok, 99, doc2} = ObjectResolver.resolve(doc, {:ref, 20, 0})

      # ObjStm (obj 8) should also be cached now
      assert Map.has_key?(doc2.cache, {8, 0})
      assert doc2.cache[{20, 0}] == 99
    end
  end

  # ---------------------------------------------------------------------------
  # Task 6.5 — resolve/2 does NOT auto-follow nested refs
  # ---------------------------------------------------------------------------

  describe "resolve/2 — ref chasing is the caller's responsibility" do
    test "resolve/2 returns {:ref, n, g} as-is if a value contains a ref" do
      # Object 1 is a dict whose /Pages value is a ref to obj 2.
      # resolve/2 returns the ref without following it.
      doc = doc_with_object(1, "<</Pages 2 0 R>>")

      assert {:ok, dict, _doc} = ObjectResolver.resolve(doc, {:ref, 1, 0})
      # The /Pages value is a raw ref, not resolved
      assert dict["Pages"] == {:ref, 2, 0}
    end

    test "resolve/2 returning a ref does not error — caller decides whether to chase" do
      doc = doc_with_object(1, "2 0 R")

      # Object 1's value IS a ref (unusual but legal in some indirect chains).
      # resolve/2 returns it as-is.
      assert {:ok, {:ref, 2, 0}, _doc} = ObjectResolver.resolve(doc, {:ref, 1, 0})
    end
  end

  # ---------------------------------------------------------------------------
  # Task 6.6 — cache threading (doc is returned with updated cache)
  # ---------------------------------------------------------------------------

  describe "resolve/2 — cache threading" do
    test "resolved values are accumulated in returned doc across calls" do
      # Build a doc with two objects
      obj1_binary = "1 0 obj\n100\nendobj\n"
      obj2_binary = "2 0 obj\n200\nendobj\n"
      full_binary = obj1_binary <> obj2_binary

      doc = %Document{
        binary: full_binary,
        xref: %{
          {1, 0} => {:in_use, 0, 0},
          {2, 0} => {:in_use, byte_size(obj1_binary), 0}
        },
        cache: %{}
      }

      # Thread the doc through two resolutions
      {:ok, 100, doc2} = ObjectResolver.resolve(doc, {:ref, 1, 0})
      {:ok, 200, doc3} = ObjectResolver.resolve(doc2, {:ref, 2, 0})

      # Both are in the cache of the final doc
      assert doc3.cache[{1, 0}] == 100
      assert doc3.cache[{2, 0}] == 200
    end
  end

  # ---------------------------------------------------------------------------
  # Task 8.1 — Encryption decryption hook in resolve_in_use/3
  # ---------------------------------------------------------------------------
  #
  # When doc.encryption is set, resolve/2 must decrypt strings and streams
  # after parsing. When doc.encryption is nil, raw values pass through unchanged.
  # R-ENC9, R-ENC10, R-ENC11, R-ENC16
  # ---------------------------------------------------------------------------

  describe "resolve/2 — encryption hook (Task 8.1)" do
    alias Pdf.Reader.Encryption.{ObjectKey, StandardHandler}

    # Build a V2/R3 handler with a known file_key for deterministic test vectors.
    # We use a simple 16-byte all-zeros key for easy manual verification.
    @test_file_key <<0::128>>

    defp test_handler_v2 do
      %StandardHandler{
        version: 2,
        revision: 3,
        length: 128,
        file_key: @test_file_key,
        stm_filter: nil,
        str_filter: nil,
        encrypt_metadata: true
      }
    end

    # RC4-encrypt a plaintext with the per-object key (used to craft test data)
    defp rc4_encrypt(plaintext, obj_num, gen_num) do
      key = ObjectKey.derive(@test_file_key, obj_num, gen_num, :rc4)
      :crypto.crypto_one_time(:rc4, key, plaintext, true)
    end

    test "when doc.encryption is nil, string values pass through unchanged" do
      # Object contains a string {:string, "Hello"} — no decryption
      # Inject the value directly into cache to avoid building actual encrypted binary
      plaintext = "Hello"

      doc = %Document{
        binary: <<>>,
        xref: %{{5, 0} => {:in_use, 0, 0}},
        cache: %{{5, 0} => {:string, plaintext}},
        encryption: nil
      }

      assert {:ok, {:string, ^plaintext}, _doc} = ObjectResolver.resolve(doc, {:ref, 5, 0})
    end

    test "when doc.encryption is set, {:string, bytes} value is decrypted" do
      # Prepare: encrypt "Hello" with per-object key for obj 3, gen 0
      obj_num = 3
      gen_num = 0
      plaintext = "Hello"
      ciphertext = rc4_encrypt(plaintext, obj_num, gen_num)

      # Build a document with the encrypted string as a raw binary in the PDF
      # We embed it in the PDF binary so the parser returns it as a {:string, bytes} value
      obj_body = "<<>>"
      # We'll pre-populate cache with the encrypted form and verify it gets decrypted
      # (testing the walker behavior directly via a doc with encryption set)
      _unused = {obj_num, gen_num, ciphertext, obj_body}

      # Use in-memory approach: doc with encryption and cache pre-populated
      # The cache hit path returns the value without decryption (already decrypted on first resolve)
      # So we need to test via the in-use parse path.
      # Build an object binary with an encrypted string literal
      # We'll test via a doc where the binary has the encrypted string
      header = "%PDF-1.4\n"
      # Build a string object: 3 0 obj (encrypted_bytes) endobj
      # PDF literal string representation of the ciphertext
      literal =
        for <<b <- ciphertext>>,
          into: "(",
          do: if(b == ?\( or b == ?\) or b == ?\\, do: "\\#{<<b>>}", else: <<b>>)

      literal_str = literal <> ")"
      obj_binary = "3 0 obj\n#{literal_str}\nendobj\n"
      full_binary = header <> obj_binary
      obj_offset = byte_size(header)

      handler = test_handler_v2()

      doc = %Document{
        binary: full_binary,
        xref: %{{obj_num, gen_num} => {:in_use, obj_offset, 0}},
        cache: %{},
        encryption: handler
      }

      assert {:ok, {:string, decrypted}, _doc2} =
               ObjectResolver.resolve(doc, {:ref, obj_num, gen_num})

      assert decrypted == plaintext
    end

    test "when doc.encryption is nil, stream bytes pass through unchanged (R-ENC11)" do
      # Build a document with a plain stream object and no encryption
      stream_content = "raw stream bytes"
      len = byte_size(stream_content)

      doc =
        doc_with_object(
          9,
          "<</Length #{len}>>\nstream\n#{stream_content}\nendstream"
        )

      doc = %{doc | encryption: nil}

      assert {:ok, {:stream, _dict, body}, _doc2} = ObjectResolver.resolve(doc, {:ref, 9, 0})
      assert body == stream_content
    end

    test "when doc.encryption is set (V2), stream bytes are RC4-decrypted (R-ENC12)" do
      # Encrypt the stream content with per-object key
      obj_num = 6
      gen_num = 0
      plaintext = "Hello encrypted stream"
      ciphertext = rc4_encrypt(plaintext, obj_num, gen_num)
      len = byte_size(ciphertext)

      # Embed the encrypted bytes in the PDF binary as a stream
      header = "%PDF-1.4\n"
      # Use binary string representation — need to be careful with raw bytes
      # Build object binary with the encrypted stream bytes
      obj_str_prefix = "6 0 obj\n<</Length #{len}>>\nstream\n"
      obj_str_suffix = "\nendstream\nendobj\n"
      obj_offset = byte_size(header)

      full_binary = header <> obj_str_prefix <> ciphertext <> obj_str_suffix

      handler = test_handler_v2()

      doc = %Document{
        binary: full_binary,
        xref: %{{obj_num, gen_num} => {:in_use, obj_offset, 0}},
        cache: %{},
        encryption: handler
      }

      assert {:ok, {:stream, _dict, body}, _doc2} =
               ObjectResolver.resolve(doc, {:ref, obj_num, gen_num})

      assert body == plaintext
    end

    test "compressed path (ObjStm) is NOT decrypted by resolve_compressed (R-ENC10, invariant)" do
      # The ObjStm stream is decrypted during its own resolve_in_use resolution.
      # Objects extracted from the decoded ObjStm body are NOT re-decrypted.
      # This test verifies that plain-text objects inside an ObjStm remain correct
      # when doc.encryption is set — no double-decryption.
      #
      # We encode the ObjStm stream with encryption (stream bytes encrypted) so that
      # after resolve_in_use decrypts the ObjStm stream, the inner objects are plain.
      obj_num_stm = 12
      obj_num_inner = 15

      objstm_plain_body = "15 0 42 "
      objstm_first = 5

      # Encrypt the ObjStm stream body as if it were a regular stream
      encrypted_stm_body = rc4_encrypt(objstm_plain_body, obj_num_stm, 0)
      len = byte_size(encrypted_stm_body)

      header = "%PDF-1.4\n"

      obj_str_prefix =
        "12 0 obj\n<</Type /ObjStm /N 1 /First #{objstm_first} /Length #{len}>>\nstream\n"

      obj_str_suffix = "\nendstream\nendobj\n"
      obj_offset = byte_size(header)

      full_binary = header <> obj_str_prefix <> encrypted_stm_body <> obj_str_suffix

      handler = test_handler_v2()

      doc = %Document{
        binary: full_binary,
        xref: %{
          {obj_num_stm, 0} => {:in_use, obj_offset, 0},
          {obj_num_inner, 0} => {:compressed, obj_num_stm, 0}
        },
        cache: %{},
        encryption: handler
      }

      # Resolve the inner object — the ObjStm gets decrypted once, inner object extracted plain
      assert {:ok, 42, _doc2} = ObjectResolver.resolve(doc, {:ref, obj_num_inner, 0})
    end
  end
end
