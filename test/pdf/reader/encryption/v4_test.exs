defmodule Pdf.Reader.Encryption.V4Test do
  use ExUnit.Case, async: true

  alias Pdf.Reader.Encryption.V4
  alias Pdf.Reader.Encryption.{StandardHandler, ObjectKey}

  # ---------------------------------------------------------------------------
  # Test vectors sourced from Mozilla pdf.js test/unit/crypto_spec.js
  # (Apache-2.0, https://github.com/mozilla/pdf.js/blob/master/test/unit/crypto_spec.js)
  #
  # dict2 definition (lines ~641-655 of crypto_spec.js):
  #   fileId2 = unescape("%3CL_%3AD%96%AF@%9A%9D%B3%3Cx%1Cv%AC")
  #   Filter: Standard, V: 4, Length: 128, R: 4, P: -1084
  #   O: unescape("sF%14v.y5%27%DB%97%0A5%22%B3%E1%D4%AD%BD%9B%3C%B4%A5%89u%15%B2Y%F1h%D9%E9%F4")
  #   U: unescape("%93%04%89%A9%BF%8AE%A6%88%A2%DB%C2%A0%A8gn%00%00...")
  #   Blank/empty password: ensurePasswordCorrect(dict2, fileId2)  [no password arg]
  #
  # Algorithm 2 expected result (computed via mix run --no-start + Node.js cross-check):
  #   Initial MD5:  4FFA901D4D727C502CFC21A5E708F8A9
  #   After 50 MD5 iterations on first 16 bytes:
  #   file_key_v4 = FEB1D25DE91B86BB0A95EB43D5A7F341
  #
  # Algorithm 5 verification (R=4, empty password):
  #   MD5(pad_const + ID[0]) = 9BBD5DA6133D3D6CCB094E608BCB6B2C
  #   After RC4 iterations 0..19: 930489A9BF8A45A688A2DBC2A0A8676E
  #   U[0..15] = 930489A9BF8A45A688A2DBC2A0A8676E  → MATCH ✓
  #
  # Per-object key vectors (all verified via :crypto round-trips in this project):
  #   ObjectKey.derive(file_key_v4, 5, 0, :aes_128)
  #   = MD5(file_key_v4 + <<5::little-24>> + <<0::little-16>> + "sAlT")
  #   = 23190D628560B0B8EA9F5F68E5ECAB30  (16 bytes)
  #
  #   ObjectKey.derive(file_key_v4, 5, 0, :rc4)
  #   = MD5(file_key_v4 + <<5::little-24>> + <<0::little-16>>)
  #   = 66305984A146A8051359114D3D413EAE  (16 bytes)
  # ---------------------------------------------------------------------------

  # ---------- dict2 raw bytes ----------

  @dict2_o Base.decode16!("734614762E793527DB970A3522B3E1D4ADBD9B3CB4A5897515B259F168D9E9F4")
  @dict2_u Base.decode16!("930489A9BF8A45A688A2DBC2A0A8676E00000000000000000000000000000000")
  @dict2_id Base.decode16!("3C4C5F3A4496AF409A9DB33C781C76AC")

  # File encryption key for blank password + dict2 (V=4, R=4, Length=128, P=-1084)
  @dict2_file_key Base.decode16!("FEB1D25DE91B86BB0A95EB43D5A7F341")

  # Per-object key for obj_num=5, gen_num=0, :aes_128 cipher
  @obj5_aes_key Base.decode16!("23190D628560B0B8EA9F5F68E5ECAB30")

  # Per-object key for obj_num=5, gen_num=0, :rc4 cipher = 66305984A146A8051359114D3D413EAE
  # (documented here for traceability; @rc4_ciphertext was produced with this key)

  # Fixed IV for all AES test vectors (deterministic — no randomness in tests)
  @fixed_iv Base.decode16!("000102030405060708090A0B0C0D0E0F")

  # AES-128-CBC vector #1:
  #   plaintext = "Hello, PDF world!" (17 bytes)
  #   PKCS7-padded (15-byte pad) = 48656C6C6F2C2050444620776F726C64210F0F0F0F0F0F0F0F0F0F0F0F0F0F0F
  #   ciphertext = 81A987D5EB94C71EDF8F869C0A63F10DE6FB09DBBDA7EF71BF57D6D579293392
  #   stream (IV + ciphertext) = IV || ciphertext
  @aes_plaintext_1 "Hello, PDF world!"
  @aes_stream_1 Base.decode16!(
                  "000102030405060708090A0B0C0D0E0F" <>
                    "81A987D5EB94C71EDF8F869C0A63F10DE6FB09DBBDA7EF71BF57D6D579293392"
                )

  # AES-128-CBC vector #2 (exact 16-byte block → PKCS7 adds full 16-byte padding block):
  #   plaintext = "TestBlock16Bytes" (16 bytes)
  #   PKCS7-padded: 54657374426C6F636B3136427974657310101010101010101010101010101010
  #   ciphertext = D9C0CE1EBADA618E5F42BB5FA080B13AEF5067F743A3AC19D19AAF886E01703A
  @aes_plaintext_2 "TestBlock16Bytes"
  @aes_stream_2 Base.decode16!(
                  "000102030405060708090A0B0C0D0E0F" <>
                    "D9C0CE1EBADA618E5F42BB5FA080B13AEF5067F743A3AC19D19AAF886E01703A"
                )

  # RC4 vector: plaintext="RC4 test string!", ciphertext=73C0D0C631A803CFA63AB2E525EB91BE
  @rc4_plaintext "RC4 test string!"
  @rc4_ciphertext Base.decode16!("73C0D0C631A803CFA63AB2E525EB91BE")

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp rc4_available?, do: :rc4 in :crypto.supports(:ciphers)

  # Minimal V4/R4 StandardHandler with StdCF → AESV2 (AES-128)
  defp dict2_handler(cf \\ nil) do
    cf_map =
      cf ||
        %{
          "StdCF" => %{"CFM" => {:name, "AESV2"}, "Length" => 16},
          "Identity" => %{"CFM" => {:name, "None"}}
        }

    %StandardHandler{
      version: 4,
      revision: 4,
      length: 128,
      o: @dict2_o,
      u: @dict2_u,
      p: -1084,
      id: @dict2_id,
      encrypt_metadata: true,
      stm_filter: "StdCF",
      str_filter: "StdCF",
      cf: cf_map,
      file_key: @dict2_file_key
    }
  end

  # Handler with RC4 (V2) crypt filter
  defp dict2_handler_rc4 do
    cf_map = %{
      "StdCF" => %{"CFM" => {:name, "V2"}, "Length" => 16},
      "Identity" => %{"CFM" => {:name, "None"}}
    }

    %StandardHandler{
      version: 4,
      revision: 4,
      length: 128,
      o: @dict2_o,
      u: @dict2_u,
      p: -1084,
      id: @dict2_id,
      encrypt_metadata: true,
      stm_filter: "StdCF",
      str_filter: "StdCF",
      cf: cf_map,
      file_key: @dict2_file_key
    }
  end

  # ---------------------------------------------------------------------------
  # authenticate_user/2 — Algorithm 6 (delegates to V1V2)
  # ---------------------------------------------------------------------------

  describe "authenticate_user/2 (Algorithm 6 — R=4)" do
    @tag :rc4_required
    test "blank password authenticates and returns file key (pdf.js dict2)" do
      # Source: pdf.js ensurePasswordCorrect(dict2, fileId2) — blank password
      # Algorithm 5 (same as V1V2, R=4):
      #   file_key = FEB1D25DE91B86BB0A95EB43D5A7F341
      #   Algorithm 5 result matches dict2 U[0..15] = 930489A9BF8A45A688A2DBC2A0A8676E
      handler = dict2_handler()
      assert {:ok, file_key} = V4.authenticate_user("", handler)
      assert file_key == @dict2_file_key
    end

    @tag :rc4_required
    test "wrong password returns :error" do
      handler = dict2_handler()
      assert :error = V4.authenticate_user("wrongpassword", handler)
    end

    test "returns {:error, :encrypted_unsupported_handler} when RC4 unavailable" do
      # S-ENC14 path for V4 — same guard as V1V2
      if rc4_available?() do
        :ok
      else
        handler = dict2_handler()
        assert {:error, :encrypted_unsupported_handler} = V4.authenticate_user("", handler)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # authenticate_owner/2 — Algorithm 7 (delegates to V1V2)
  # ---------------------------------------------------------------------------

  describe "authenticate_owner/2 (Algorithm 7 — R=4)" do
    @tag :rc4_required
    test "wrong owner password returns :error" do
      # dict2's owner password is not published in the pdf.js fixture;
      # verifying that an incorrect owner password produces :error is sufficient.
      handler = dict2_handler()
      assert :error = V4.authenticate_owner("wrongowner", handler)
    end

    @tag :rc4_required
    test "wrong owner password 'wrongblank' also returns :error (triangulation)" do
      handler = dict2_handler()
      assert :error = V4.authenticate_owner("wrongblank", handler)
    end

    test "returns {:error, :encrypted_unsupported_handler} when RC4 unavailable" do
      if rc4_available?() do
        :ok
      else
        handler = dict2_handler()

        assert {:error, :encrypted_unsupported_handler} =
                 V4.authenticate_owner("", handler)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # select_crypt_filter/3 — Crypt Filter dispatch
  # ---------------------------------------------------------------------------

  describe "select_crypt_filter/3 — dispatch logic" do
    test "document-level :stream uses stm_filter to resolve AESV2 → :aes_128" do
      # StdCF → AESV2 → :aes_128; no per-stream override
      handler = dict2_handler()
      stream_dict = %{}
      assert :aes_128 = V4.select_crypt_filter(stream_dict, handler, :stream)
    end

    test "document-level :string uses str_filter to resolve AESV2 → :aes_128" do
      handler = dict2_handler()
      stream_dict = %{}
      assert :aes_128 = V4.select_crypt_filter(stream_dict, handler, :string)
    end

    test "document-level stm_filter V2 → :rc4" do
      handler = dict2_handler_rc4()
      stream_dict = %{}
      assert :rc4 = V4.select_crypt_filter(stream_dict, handler, :stream)
    end

    test "/Identity filter name in CF returns :identity" do
      # handler has Identity → None (CFM); stm_filter overridden to Identity
      handler = %{dict2_handler() | stm_filter: "Identity"}
      stream_dict = %{}
      assert :identity = V4.select_crypt_filter(stream_dict, handler, :stream)
    end

    test "per-stream /Filter array override: [/Crypt /StdCF] selects StdCF → :aes_128" do
      # PDF 1.7 § 7.6.5.4: per-stream crypt filter name overrides document-level /StmF
      # The stream dict has Filter: [{:name, "Crypt"}, {:name, "StdCF"}]
      # Last element /StdCF → look up in handler.cf → AESV2 → :aes_128
      handler = dict2_handler()
      # stm_filter is "StdCF" here already, but let's set it to something different
      # to prove the override is coming from the stream dict, not stm_filter
      handler_diff = %{handler | stm_filter: "Identity"}

      stream_dict = %{"Filter" => [{:name, "Crypt"}, {:name, "StdCF"}]}
      assert :aes_128 = V4.select_crypt_filter(stream_dict, handler_diff, :stream)
    end

    test "per-stream /Filter [/Identity] overrides stm_filter → :identity passthrough" do
      # S-ENC7 / R-ENC20: /Identity crypt filter in stream dict → passthrough
      handler = dict2_handler()
      stream_dict = %{"Filter" => [{:name, "Crypt"}, {:name, "Identity"}]}
      assert :identity = V4.select_crypt_filter(stream_dict, handler, :stream)
    end

    test "per-stream /Filter as single name atom: {:name, 'Identity'} → :identity" do
      handler = dict2_handler()
      stream_dict = %{"Filter" => {:name, "Identity"}}
      assert :identity = V4.select_crypt_filter(stream_dict, handler, :stream)
    end

    test "unknown filter name not in CF falls back to :identity" do
      # If per-stream filter name not found in /CF, treat as Identity (no decryption)
      handler = dict2_handler()
      stream_dict = %{"Filter" => [{:name, "Crypt"}, {:name, "UnknownFilter"}]}
      assert :identity = V4.select_crypt_filter(stream_dict, handler, :stream)
    end
  end

  # ---------------------------------------------------------------------------
  # decrypt_stream/5 — AES-128-CBC
  # ---------------------------------------------------------------------------

  describe "decrypt_stream/5 — AES-128-CBC (AESV2)" do
    test "decrypts valid AES-128-CBC stream (vector #1: 17-byte plaintext)" do
      # Verified vector: IV || ciphertext → "Hello, PDF world!"
      # Per-object key for obj=5, gen=0, :aes_128 = 23190D628560B0B8EA9F5F68E5ECAB30
      # stream = IV(16) + ciphertext(32) = 48 bytes total
      handler = dict2_handler()
      stream_dict = %{}

      assert {:ok, plaintext} = V4.decrypt_stream(@aes_stream_1, stream_dict, 5, 0, handler)
      assert plaintext == @aes_plaintext_1
    end

    test "decrypts valid AES-128-CBC stream (vector #2: exact 16-byte block)" do
      # "TestBlock16Bytes" → PKCS7 with full 16-byte padding block
      handler = dict2_handler()
      stream_dict = %{}

      assert {:ok, plaintext} = V4.decrypt_stream(@aes_stream_2, stream_dict, 5, 0, handler)
      assert plaintext == @aes_plaintext_2
    end

    test "returns {:ok, bytes} unchanged for :identity filter (R-ENC15, R-ENC20)" do
      # /Identity means NO decryption — bytes pass through
      handler = dict2_handler()
      stream_dict = %{"Filter" => [{:name, "Crypt"}, {:name, "Identity"}]}
      raw_bytes = "some raw unencrypted bytes"

      assert {:ok, ^raw_bytes} = V4.decrypt_stream(raw_bytes, stream_dict, 5, 0, handler)
    end

    test "returns :error for invalid PKCS7 padding (S-ENC13 — wrong key scenario)" do
      # Simulate decryption with wrong key producing invalid padding.
      # We build a ciphertext encrypted with @obj5_aes_key but attempt to decrypt
      # with a handler that uses a DIFFERENT file_key → different per-object key →
      # almost certain PKCS7 violation.
      wrong_file_key = :binary.copy(<<0x00>>, 16)
      handler_wrong = %{dict2_handler() | file_key: wrong_file_key}
      stream_dict = %{}

      # @aes_stream_1 is valid under the correct key; it will produce garbage under wrong key
      # The last byte of the garbage will almost certainly not be in 1..16, so :error
      # We verify the behavior rather than the exact error path
      result = V4.decrypt_stream(@aes_stream_1, stream_dict, 5, 0, handler_wrong)
      assert result == :error
    end

    test "returns :error when ciphertext is too short (no IV)" do
      # AES stream requires at least 16 bytes for the IV
      handler = dict2_handler()
      stream_dict = %{}
      assert :error = V4.decrypt_stream(<<1, 2, 3>>, stream_dict, 5, 0, handler)
    end
  end

  # ---------------------------------------------------------------------------
  # decrypt_stream/5 — RC4 via V2 crypt filter
  # ---------------------------------------------------------------------------

  describe "decrypt_stream/5 — RC4 (V2 crypt filter)" do
    @tag :rc4_required
    test "decrypts valid RC4 stream" do
      # Vector: per-object key for obj=5, gen=0, :rc4 = 66305984A146A8051359114D3D413EAE
      # RC4("RC4 test string!") = 73C0D0C631A803CFA63AB2E525EB91BE
      handler = dict2_handler_rc4()
      stream_dict = %{}

      assert {:ok, plaintext} = V4.decrypt_stream(@rc4_ciphertext, stream_dict, 5, 0, handler)
      assert plaintext == @rc4_plaintext
    end

    @tag :rc4_required
    test "RC4 decrypt is symmetric (encrypt and decrypt produce same output)" do
      # RC4 is a stream cipher: encryption == decryption
      handler = dict2_handler_rc4()
      stream_dict = %{}
      plaintext = "symmetric stream!"

      # Encrypt first using ObjectKey + :crypto directly
      rc4_key = ObjectKey.derive(@dict2_file_key, 7, 0, :rc4)
      ciphertext = :crypto.crypto_one_time(:rc4, rc4_key, plaintext, true)

      assert {:ok, ^plaintext} = V4.decrypt_stream(ciphertext, stream_dict, 7, 0, handler)
    end
  end

  # ---------------------------------------------------------------------------
  # decrypt_string/4 — string decryption (AES and RC4)
  # ---------------------------------------------------------------------------

  describe "decrypt_string/4 — AES-128" do
    test "decrypts a string ciphertext using str_filter (AES-128)" do
      # Strings use str_filter (StdCF → AESV2); same algorithm as streams
      # Use the same AES vector as decrypt_stream (same key derivation path)
      handler = dict2_handler()

      assert {:ok, plaintext} = V4.decrypt_string(@aes_stream_1, 5, 0, handler)
      assert plaintext == @aes_plaintext_1
    end

    test "identity str_filter returns bytes unchanged" do
      handler = %{dict2_handler() | str_filter: "Identity"}
      raw = "clear string data"
      assert {:ok, ^raw} = V4.decrypt_string(raw, 5, 0, handler)
    end
  end

  describe "decrypt_string/4 — RC4" do
    @tag :rc4_required
    test "decrypts a string using RC4 str_filter" do
      handler = dict2_handler_rc4()
      assert {:ok, plaintext} = V4.decrypt_string(@rc4_ciphertext, 5, 0, handler)
      assert plaintext == @rc4_plaintext
    end
  end

  # ---------------------------------------------------------------------------
  # PKCS7 unpadding edge cases (exercised via decrypt_stream internals)
  # ---------------------------------------------------------------------------

  describe "PKCS7 unpadding edge cases" do
    test "valid pad byte N=1 is stripped correctly" do
      # Construct: 15 plaintext bytes + 0x01 padding = exactly one block
      # Encrypt and decrypt round-trip; expect 15 bytes back
      plain_15 = "fifteen-chars!!"
      assert byte_size(plain_15) == 15
      pad_n = 1
      pkcs7 = plain_15 <> <<pad_n>>
      iv = @fixed_iv
      cipher = :crypto.crypto_one_time(:aes_128_cbc, @obj5_aes_key, iv, pkcs7, true)

      handler = dict2_handler()
      stream_dict = %{}
      assert {:ok, result} = V4.decrypt_stream(iv <> cipher, stream_dict, 5, 0, handler)
      assert result == plain_15
    end

    test "padding byte N=0 is rejected → :error (R-ENC14)" do
      # Build a 16-byte block whose last byte is 0x00 — invalid PKCS7 (N must be 1..16)
      bad_padded = :binary.copy(<<0xAA>>, 15) <> <<0x00>>
      iv = @fixed_iv
      cipher = :crypto.crypto_one_time(:aes_128_cbc, @obj5_aes_key, iv, bad_padded, true)

      handler = dict2_handler()
      stream_dict = %{}
      assert :error = V4.decrypt_stream(iv <> cipher, stream_dict, 5, 0, handler)
    end

    test "padding byte N=17 is rejected → :error (N > 16, R-ENC14)" do
      # Last byte = 17 → > 16 → invalid
      bad_padded = :binary.copy(<<0xBB>>, 15) <> <<17>>
      iv = @fixed_iv
      cipher = :crypto.crypto_one_time(:aes_128_cbc, @obj5_aes_key, iv, bad_padded, true)

      handler = dict2_handler()
      stream_dict = %{}
      assert :error = V4.decrypt_stream(iv <> cipher, stream_dict, 5, 0, handler)
    end
  end
end
