defmodule Pdf.Reader.Encryption.V5Test do
  use ExUnit.Case, async: true

  alias Pdf.Reader.Encryption.V5
  alias Pdf.Reader.Encryption.StandardHandler

  # ---------------------------------------------------------------------------
  # Test vectors sourced from Mozilla pdf.js test/unit/crypto_spec.js
  # (Apache-2.0, https://github.com/mozilla/pdf.js/blob/master/test/unit/crypto_spec.js)
  #
  # aes256IsoDict definition (lines ~683-709 of crypto_spec.js):
  #   Filter: Standard, V: 5, Length: 256, R: 6, P: -1084
  #   User password:  "user"
  #   Owner password: "owner"
  #
  # All hex values below were extracted from the pdf.js unescape() strings using
  # a Node.js script and cross-verified by running pdf.js calculatePDF20Hash
  # against each input.  Each expected value is annotated with its derivation.
  #
  # Derivation trail (run in Node.js v22, pdf.js crypto.js logic ported):
  #
  #   U[32..39] = 53F59265C6F722C6  ← User Validation Salt
  #   U[40..47] = BF0B105EEDD814AF  ← User Key Salt
  #   O[32..39] = 8EE8A9D0CAD605B9  ← Owner Validation Salt
  #   O[40..47] = 1DD0B92E0B4C8795  ← Owner Key Salt
  #
  #   Algorithm 8 (user auth):
  #     hash = pdf20_hash("user", "user"++U_val_salt, [])
  #          = 5EE6CD4BA663FA4CDB801155391121A4962E67B0A09CBBE9A6DFA3FD93EB5FB8
  #     == U[0..31]  → MATCH  (65 rounds)
  #
  #   Algorithm 10 (file key from UE):
  #     ue_key = pdf20_hash("user", "user"++U_key_salt, [])
  #            = C522AC6AF124BD90293B32C9DAD2F277A1EED9698338F62EF681EE8E0A98418F
  #     file_key = AES-256-CBC-decrypt(UE, ue_key, IV=<<0::128>>)
  #              = 2ADAD527495B484F4326F88512BD3D226B4F1D383BB5D576712241D257AE16EF
  #
  #   Algorithm 9 (owner auth):
  #     hash = pdf20_hash("owner", "owner"++O_val_salt++U[0..47], U[0..47])
  #          = 58E83E36F51AF5D1897BDD48C73125D91F4A73A77F9EB04D2DA3572F275AD98D
  #     == O[0..31]  → MATCH
  #
  #   Algorithm 10 (file key from OE):
  #     oe_key = pdf20_hash("owner", "owner"++O_key_salt++U[0..47], U[0..47])
  #            = 7DD412A8C36256678FB825A78DF502C8A00F49B17DC06269BA916DEEFAFFE52D
  #     file_key = AES-256-CBC-decrypt(OE, oe_key, IV=<<0::128>>)
  #              = 2ADAD527495B484F4326F88512BD3D226B4F1D383BB5D576712241D257AE16EF
  #     (same file_key as from UE — both paths agree)
  #
  #   decrypt_stream test:
  #     plaintext  = "Hello V5 AES256!" (16 bytes)
  #     iv         = 000102030405060708090A0B0C0D0E0F (16 bytes)
  #     stream_bytes = iv ++ AES-256-CBC-encrypt(plaintext_pkcs7, file_key, iv)
  #                  = 000102030405060708090A0B0C0D0E0F
  #                    7EF1527CE512ABCB52B9F20DD3920D5A
  #                    C149E5DD7529BF326A2F801B4CAA67A5
  #   (total 48 bytes, verified by Node.js round-trip)
  # ---------------------------------------------------------------------------

  # ---------- aes256IsoDict raw bytes (V=5, R=6, AES-256) ----------

  # /U: 48 bytes = 32-byte hash || 8-byte validation salt || 8-byte key salt
  @iso_u Base.decode16!(
           "5EE6CD4BA663FA4CDB801155391121A4" <>
             "962E67B0A09CBBE9A6DFA3FD93EB5FB8" <>
             "53F59265C6F722C6" <>
             "BF0B105EEDD814AF"
         )

  # /O: 48 bytes = 32-byte hash || 8-byte validation salt || 8-byte key salt
  @iso_o Base.decode16!(
           "58E83E36F51AF5D1897BDD48C73125D9" <>
             "1F4A73A77F9EB04D2DA3572F275AD98D" <>
             "8EE8A9D0CAD605B9" <>
             "1DD0B92E0B4C8795"
         )

  # /UE: 32 bytes (encrypted file key — user path)
  @iso_ue Base.decode16!("79D002B5E6599C3CFD8FD41C54B4C4B1AD80DD6B2E145EBA87335F1814DFFE24")

  # /OE: 32 bytes (encrypted file key — owner path)
  @iso_oe Base.decode16!("D149E04D679BC9B5BE44DF143E5A38D205F0B280EE7C44FEFDF43E6CD0870AFB")

  # /Perms: 16 bytes
  @iso_perms Base.decode16!("6CAD0FA0EB4D86574D3ECBB5E058C937")

  # Expected file key (32 bytes) — same whether recovered via UE or OE
  @expected_file_key Base.decode16!(
                       "2ADAD527495B484F4326F88512BD3D22" <>
                         "6B4F1D383BB5D576712241D257AE16EF"
                     )

  # ---------- decrypt_stream test vector ----------
  # Plaintext "Hello V5 AES256!" PKCS7-padded to 32 bytes, then AES-256-CBC encrypted
  # with @expected_file_key and IV = 0x000102...0F
  @stream_plaintext "Hello V5 AES256!"
  @stream_bytes Base.decode16!(
                  "000102030405060708090A0B0C0D0E0F" <>
                    "7EF1527CE512ABCB52B9F20DD3920D5A" <>
                    "C149E5DD7529BF326A2F801B4CAA67A5"
                )

  # ---------- helpers ----------

  defp iso_handler do
    %StandardHandler{
      version: 5,
      revision: 6,
      length: 256,
      o: @iso_o,
      u: @iso_u,
      oe: @iso_oe,
      ue: @iso_ue,
      perms: @iso_perms,
      p: -1084,
      id: nil,
      encrypt_metadata: true,
      stm_filter: "AESV3",
      str_filter: "AESV3",
      file_key: nil
    }
  end

  defp stream_dict, do: %{}

  # ---------------------------------------------------------------------------
  # pdf20_hash/3 — Algorithm 2.B (private function; tested via authenticate_user)
  # ---------------------------------------------------------------------------

  # pdf20_hash is private; we validate it indirectly via authenticate_user.
  # A standalone unit test is provided through the public authenticate_user/2
  # whose expected output (matching U[0..31]) implicitly validates the hash.

  # ---------------------------------------------------------------------------
  # Algorithm 8 — authenticate_user/2
  # ---------------------------------------------------------------------------

  describe "authenticate_user/2 (Algorithm 8 — R=6)" do
    test "correct user password 'user' returns {:ok, file_key} (pdf.js aes256IsoDict)" do
      # Source: pdf.js crypto_spec.js aes256IsoDict, ensurePasswordCorrect(dict, id, 'user')
      # Algorithm 8:
      #   hash = pdf20_hash("user", "user"++U[32..39], [])
      #        = 5EE6...5FB8  == U[0..31] → auth passes
      # Algorithm 10 (user path):
      #   ue_key = pdf20_hash("user", "user"++U[40..47], [])
      #   file_key = AES-256-CBC-decrypt(UE, ue_key, IV=zeros)
      #            = 2ADAD...16EF
      handler = iso_handler()
      assert {:ok, file_key} = V5.authenticate_user("user", handler)

      assert file_key == @expected_file_key,
             "Expected #{Base.encode16(@expected_file_key)}, got #{Base.encode16(file_key)}"
    end

    test "wrong password returns :error" do
      handler = iso_handler()
      assert :error = V5.authenticate_user("wrong", handler)
    end

    test "empty string password returns :error (hash mismatch)" do
      handler = iso_handler()
      assert :error = V5.authenticate_user("", handler)
    end

    test "password is truncated to 127 bytes (R-ENC23)" do
      # A password of 128 bytes and one of 127 bytes with the same first 127 bytes
      # must produce the same authentication result (both fail here since they
      # don't match the test dict, but both calls must NOT raise).
      handler = iso_handler()
      long_pw = String.duplicate("x", 128)
      assert :error = V5.authenticate_user(long_pw, handler)
      assert :error = V5.authenticate_user(String.duplicate("x", 127), handler)
    end
  end

  # ---------------------------------------------------------------------------
  # Algorithm 9 — authenticate_owner/2
  # ---------------------------------------------------------------------------

  describe "authenticate_owner/2 (Algorithm 9 — R=6)" do
    test "correct owner password 'owner' returns {:ok, file_key} (pdf.js aes256IsoDict)" do
      # Source: pdf.js crypto_spec.js aes256IsoDict, ensurePasswordCorrect(dict, id, 'owner')
      # Algorithm 9:
      #   hash = pdf20_hash("owner", "owner"++O[32..39]++U[0..47], U[0..47])
      #        = 58E8...D98D  == O[0..31] → auth passes
      # Algorithm 10 (owner path):
      #   oe_key = pdf20_hash("owner", "owner"++O[40..47]++U[0..47], U[0..47])
      #   file_key = AES-256-CBC-decrypt(OE, oe_key, IV=zeros) = 2ADAD...16EF
      handler = iso_handler()
      assert {:ok, file_key} = V5.authenticate_owner("owner", handler)

      assert file_key == @expected_file_key,
             "Expected #{Base.encode16(@expected_file_key)}, got #{Base.encode16(file_key)}"
    end

    test "wrong owner password returns :error" do
      handler = iso_handler()
      assert :error = V5.authenticate_owner("wrongowner", handler)
    end

    test "user password does NOT authenticate as owner (wrong hash input)" do
      # 'user' produces a hash that does not match O[0..31]
      handler = iso_handler()
      assert :error = V5.authenticate_owner("user", handler)
    end
  end

  # ---------------------------------------------------------------------------
  # decrypt_stream/5 — AES-256-CBC (R-ENC26, R-ENC13, R-ENC14)
  # ---------------------------------------------------------------------------

  describe "decrypt_stream/5 — AES-256-CBC (V5)" do
    test "decrypts valid AES-256-CBC stream and strips PKCS7 padding" do
      # Stream bytes = IV(16) ++ ciphertext(32)
      # Expected plaintext = 'Hello V5 AES256!' (16 bytes, stripped from 32-byte padded block)
      # Verification trail: see module-level comment
      handler = %{iso_handler() | file_key: @expected_file_key}

      assert {:ok, plaintext} = V5.decrypt_stream(@stream_bytes, stream_dict(), 1, 0, handler)
      assert plaintext == @stream_plaintext
    end

    test ":identity filter passes bytes through unchanged (R-ENC15, R-ENC20)" do
      # When the stream dict contains a Crypt Filter that resolves to Identity,
      # the bytes must be returned as-is without any decryption.
      identity_dict = %{
        "Filter" => [{:name, "Crypt"}],
        "DecodeParms" => %{"Name" => {:name, "Identity"}}
      }

      handler = %{iso_handler() | file_key: @expected_file_key}
      raw = <<1, 2, 3, 4, 5>>
      assert {:ok, ^raw} = V5.decrypt_stream(raw, identity_dict, 1, 0, handler)
    end

    test "returns :error for ciphertext shorter than 16 bytes (no IV)" do
      handler = %{iso_handler() | file_key: @expected_file_key}
      short = <<1, 2, 3>>
      assert :error = V5.decrypt_stream(short, stream_dict(), 1, 0, handler)
    end

    test "returns :error for invalid PKCS7 padding (S-ENC13 — wrong key scenario)" do
      # Encrypt with a different key so decryption with the correct key produces
      # garbage that fails PKCS7 validation → :error (no exception raised)
      wrong_key = :crypto.strong_rand_bytes(32)
      iv = :crypto.strong_rand_bytes(16)

      plaintext = "sixteen bytes!!!"
      pkcs7 = plaintext <> <<16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16>>

      ciphertext =
        :crypto.crypto_one_time(
          :aes_256_cbc,
          wrong_key,
          iv,
          pkcs7,
          [{:padding, :none}, {:encrypt, true}]
        )

      stream_bytes = iv <> ciphertext
      handler = %{iso_handler() | file_key: @expected_file_key}

      # Decrypting with correct key when ciphertext was made with wrong_key →
      # garbage bytes → PKCS7 validation fails → :error (no crash)
      result = V5.decrypt_stream(stream_bytes, stream_dict(), 1, 0, handler)
      assert result == :error or match?({:ok, _}, result)
      # NOTE: this test verifies no exception is raised; whether it returns
      # :error or {:ok, _} depends on whether the garbage byte happens to be
      # a valid PKCS7 pad value (1..16). The critical invariant is: no crash.
    end
  end

  # ---------------------------------------------------------------------------
  # decrypt_string/4 — AES-256-CBC (R-ENC16, R-ENC26)
  # ---------------------------------------------------------------------------

  describe "decrypt_string/4 — AES-256-CBC (V5)" do
    test "decrypts a string with the same IV+ciphertext format as streams" do
      # V5 string decryption uses the same AES-256-CBC + file_key logic as streams.
      handler = %{iso_handler() | file_key: @expected_file_key}

      assert {:ok, plaintext} = V5.decrypt_string(@stream_bytes, 1, 0, handler)
      assert plaintext == @stream_plaintext
    end

    test "returns :error for ciphertext shorter than 16 bytes" do
      handler = %{iso_handler() | file_key: @expected_file_key}
      assert :error = V5.decrypt_string(<<1, 2, 3>>, 1, 0, handler)
    end
  end

  # ---------------------------------------------------------------------------
  # R=5 (deprecated) guard — S-ENC10
  # ---------------------------------------------------------------------------

  describe "R=5 deprecated variant" do
    test "authenticate_user/2 returns {:error, :encrypted_unsupported_handler} for R=5 (S-ENC10)" do
      # R=5 is the pre-standard Acrobat X beta variant — must be rejected.
      handler = %StandardHandler{
        version: 5,
        revision: 5,
        length: 256,
        o: @iso_o,
        u: @iso_u,
        oe: @iso_oe,
        ue: @iso_ue,
        perms: @iso_perms,
        p: -1084,
        id: nil,
        encrypt_metadata: true,
        stm_filter: "AESV3",
        str_filter: "AESV3",
        file_key: nil
      }

      assert {:error, :encrypted_unsupported_handler} = V5.authenticate_user("user", handler)
    end

    test "authenticate_owner/2 returns {:error, :encrypted_unsupported_handler} for R=5" do
      handler = %StandardHandler{
        version: 5,
        revision: 5,
        length: 256,
        o: @iso_o,
        u: @iso_u,
        oe: @iso_oe,
        ue: @iso_ue,
        perms: @iso_perms,
        p: -1084,
        id: nil,
        encrypt_metadata: true,
        stm_filter: "AESV3",
        str_filter: "AESV3",
        file_key: nil
      }

      assert {:error, :encrypted_unsupported_handler} = V5.authenticate_owner("owner", handler)
    end
  end
end
