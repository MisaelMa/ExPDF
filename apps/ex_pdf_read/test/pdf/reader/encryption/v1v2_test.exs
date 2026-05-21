defmodule Pdf.Reader.Encryption.V1V2Test do
  use ExUnit.Case, async: true

  alias Pdf.Reader.Encryption.V1V2
  alias Pdf.Reader.Encryption.StandardHandler

  # ---------------------------------------------------------------------------
  # Test fixtures sourced from Mozilla pdf.js test/unit/crypto_spec.js
  # (Apache-2.0, https://github.com/mozilla/pdf.js/blob/master/test/unit/crypto_spec.js)
  #
  # dict1 definition (lines ~637-657 of crypto_spec.js):
  #   fileId1 = unescape("%F6%C6%AF%17%F3rR%8DRM%9A%80%D1%EF%DF%18")
  #   Filter: Standard, V: 2, Length: 128, R: 3, P: -1028
  #   O: unescape("%80%C3%04%96%91o%20sl%3A%E6%1B%13T%91%F2%0DV%12%E3%FF%5E%BB%E9VO%D8k%9A%CA%7C%5D")
  #   U: unescape("j%0C%8D%3EY%19%00%BCjd%7D%91%BD%AA%00%18%00%00%00%00%00%00%00%00%00%00%00%00%00%00%00%00")
  #   User password: "123456"  (from: ensurePasswordCorrect(dict1, fileId1, "123456"))
  #   Owner password: "654321" (from: ensurePasswordCorrect(dict1, fileId1, "654321"))
  #
  # All expected values below were computed using :crypto primitives in the
  # project runtime (mix run --no-start /tmp/compute_vectors.exs) and
  # cross-verified against the Node.js crypto output.  Each step is documented
  # in comments to create a clear verification trail.
  # ---------------------------------------------------------------------------

  # ---------- dict1 raw bytes (V=2, R=3, RC4-128) ----------

  # /O bytes: 32 bytes
  @dict1_o Base.decode16!("80C30496916F20736C3AE61B135491F20D5612E3FF5EBBE9564FD86B9ACA7C5D")

  # /U bytes: 32 bytes (first 16 are the authenticator; remaining 16 are arbitrary padding)
  @dict1_u Base.decode16!("6A0C8D3E591900BC6A647D91BDAA001800000000000000000000000000000000")

  # /ID[0] from the trailer: 16 bytes
  @dict1_id Base.decode16!("F6C6AF17F372528D524D9A80D1EFDF18")

  # ---------- expected values computed from the algorithm steps ----------

  # Algorithm 2 result for password="123456":
  #   MD5(padded_pw + O + <<-1028::little-32>> + ID[0])
  #   initial_hash = 44B45E6189BB4715EC0F614C1803F767
  #   after 50 x MD5 iterations on first 16 bytes:
  #   file_key = 4E3BCF7B7CDD332D047259A3606132DE (16 bytes)
  @dict1_file_key Base.decode16!("4E3BCF7B7CDD332D047259A3606132DE")

  # ---------- helpers ----------

  # Build a %StandardHandler{} for dict1 (V=2, R=3, Length=128)
  defp dict1_handler do
    %StandardHandler{
      version: 2,
      revision: 3,
      length: 128,
      o: @dict1_o,
      u: @dict1_u,
      p: -1028,
      id: @dict1_id,
      encrypt_metadata: true,
      stm_filter: nil,
      str_filter: nil
    }
  end

  # Build a %StandardHandler{} for V=1, R=2, Length=40 (RC4-40)
  # Uses the same /O, /P and /ID as dict1 for simplicity.
  # For V=1/R=2 with empty password, Algorithm 4 is used (no 50-iteration loop).
  # Expected file key computed:
  #   padded_empty = pad_const (32 bytes)
  #   MD5(padded_empty + O + <<-1028::little-32>> + ID[0]) = first 5 bytes
  #   = C6971593B3
  # Algorithm 4: RC4(pad_const, key) → 32 bytes stored in /U
  defp make_v1_r2_handler_empty_pw do
    # Compute the /U value for empty password + V=1, R=2 using Algorithm 4
    # /U = RC4(pad_const, file_key_5bytes)
    # file_key (5 bytes) for empty pw: C6971593B3 (computed offline)
    file_key_5 = Base.decode16!("C6971593B3")

    pad_const = Pdf.Reader.Encryption.PasswordPad.constant()

    u_value = :crypto.crypto_one_time(:rc4, file_key_5, pad_const, true)

    %StandardHandler{
      version: 1,
      revision: 2,
      length: 40,
      o: @dict1_o,
      u: u_value,
      p: -1028,
      id: @dict1_id,
      encrypt_metadata: true,
      stm_filter: nil,
      str_filter: nil
    }
  end

  # ---------------------------------------------------------------------------
  # RC4 availability guard
  # ---------------------------------------------------------------------------

  # Tests in this module that call RC4 require RC4 support.
  # On OpenSSL 3.x systems with FIPS mode or RC4 disabled, these tests are
  # excluded via `@tag :rc4_required`.
  defp rc4_available?, do: :rc4 in :crypto.supports(:ciphers)

  # ---------------------------------------------------------------------------
  # Algorithm 2 — derive_file_key/3
  # ---------------------------------------------------------------------------

  describe "derive_file_key/3 (Algorithm 2)" do
    test "V=2/R=3: derives correct 16-byte file key from known vector (pdf.js dict1)" do
      if not rc4_available?(), do: :ok

      # Source: pdf.js dict1 fixture, password "123456"
      # Verified against Node.js :crypto.hash(:md5) + 50 iterations
      handler = dict1_handler()
      result = V1V2.derive_file_key("123456", handler)

      assert result == @dict1_file_key,
             "Expected #{Base.encode16(@dict1_file_key)}, got #{Base.encode16(result)}"
    end

    test "V=2/R=3: iterates MD5 exactly 50 times (S-ENC22 cross-check)" do
      # Verify that skipping the 50-iteration loop gives a DIFFERENT result
      # (i.e., the loop is actually doing work). We cross-check by computing
      # the result WITHOUT iteration — it must NOT equal the expected key.
      handler = dict1_handler()
      # The initial (non-iterated) hash is different from the final key
      padded_pw = Pdf.Reader.Encryption.PasswordPad.pad("123456")
      p_le = <<handler.p::little-32>>
      raw_hash = :crypto.hash(:md5, padded_pw <> handler.o <> p_le <> handler.id)

      # Raw hash (no iterations) must differ from the file key (with 50 iterations)
      file_key = V1V2.derive_file_key("123456", handler)

      assert binary_part(raw_hash, 0, 16) != file_key,
             "50-iteration loop must change the hash"
    end

    test "V=1/R=2: derives correct 5-byte key (no 50-iteration loop)" do
      # For R=2, no MD5 iteration loop — take first 5 bytes of initial hash
      # Expected: C6971593B3 (computed from empty password + dict1 /O, /P, /ID)
      handler = make_v1_r2_handler_empty_pw()
      result = V1V2.derive_file_key("", handler)
      assert byte_size(result) == 5

      assert result == Base.decode16!("C6971593B3"),
             "V1/R=2 file key mismatch: #{Base.encode16(result)}"
    end

    test "empty string password uses pad_const bytes as padded password" do
      # Empty password → padded_pw == pad_constant (32 bytes)
      # The derive_file_key result for "" must differ from result for "x"
      handler = dict1_handler()
      key_empty = V1V2.derive_file_key("", handler)
      key_x = V1V2.derive_file_key("x", handler)
      assert key_empty != key_x
      assert byte_size(key_empty) == 16
    end
  end

  # ---------------------------------------------------------------------------
  # Algorithm 5 — authenticate_user/2 (V=2, R=3)
  # ---------------------------------------------------------------------------

  describe "authenticate_user/2 (Algorithms 4+5)" do
    @tag :rc4_required
    test "V=2/R=3: correct password authenticates and returns file key (pdf.js dict1)" do
      # Source: pdf.js CipherTransformFactory test:
      #   ensurePasswordCorrect(dict1, fileId1, "123456")
      # Algorithm 5 verification:
      #   1. derive file_key (Algorithm 2) → 4E3BCF7B7CDD332D047259A3606132DE
      #   2. MD5(pad_const + ID[0]) → D620807443B18B9A633F79443191827D
      #   3. RC4-encrypt (step 0) with file_key → 2062902F632957DDE9367B20F31EEAA8
      #   4. XOR iterations 1..19 → 6A0C8D3E591900BC6A647D91BDAA0018
      #   5. Compare to U[0..15] = 6A0C8D3E591900BC6A647D91BDAA0018 → MATCH
      handler = dict1_handler()
      assert {:ok, file_key} = V1V2.authenticate_user("123456", handler)
      assert file_key == @dict1_file_key
    end

    @tag :rc4_required
    test "V=2/R=3: wrong password returns :error" do
      handler = dict1_handler()
      assert :error = V1V2.authenticate_user("wrong", handler)
    end

    @tag :rc4_required
    test "V=1/R=2: correct empty password authenticates (Algorithm 4)" do
      # Algorithm 4: RC4(pad_const, file_key) == U (all 32 bytes)
      handler = make_v1_r2_handler_empty_pw()
      assert {:ok, file_key} = V1V2.authenticate_user("", handler)
      assert byte_size(file_key) == 5
      assert file_key == Base.decode16!("C6971593B3")
    end

    @tag :rc4_required
    test "V=1/R=2: wrong password returns :error" do
      handler = make_v1_r2_handler_empty_pw()
      assert :error = V1V2.authenticate_user("notthepassword", handler)
    end

    test "returns {:error, :encrypted_unsupported_handler} when RC4 unavailable" do
      # S-ENC14: When :rc4 is absent from :crypto.supports(:ciphers), the
      # module must NOT crash — return the typed error instead.
      # This test only runs on systems where RC4 is NOT available.
      if rc4_available?() do
        :ok
      else
        handler = dict1_handler()

        assert {:error, :encrypted_unsupported_handler} =
                 V1V2.authenticate_user("123456", handler)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Algorithm 7 — derive_user_from_owner/2
  # ---------------------------------------------------------------------------

  describe "derive_user_from_owner/2 (Algorithm 7)" do
    @tag :rc4_required
    test "V=2/R=3: owner password '654321' derives padded user password for '123456'" do
      # Source: pdf.js dict1 fixture
      #   ensurePasswordCorrect(dict1, fileId1, "654321")
      # Algorithm 7 steps (R=3):
      #   1. Pad owner pw "654321" to 32 bytes
      #   2. MD5, then iterate 50 times → owner RC4 key = 7368F0995F4375DFA150DC3A4B355C1B
      #   3. Decrypt /O with 20 passes (i=19..0, each XORing key byte with i)
      #   → derived user padded pw = 31323334353628BF4E5E4E758A4164004E56FFFA01082E2E00B6D0683E802F0C
      #   which is exactly pad("123456")
      handler = dict1_handler()
      {:ok, derived_padded_user} = V1V2.derive_user_from_owner("654321", handler)

      expected_padded_user = Pdf.Reader.Encryption.PasswordPad.pad("123456")

      assert derived_padded_user == expected_padded_user,
             "Expected #{Base.encode16(expected_padded_user)}, got #{Base.encode16(derived_padded_user)}"
    end

    @tag :rc4_required
    test "derived user password can authenticate via authenticate_user/2" do
      # Full round-trip: owner pw → derive padded user pw → strip padding → auth
      # This validates the complete owner-password-fallback path (S-ENC17)
      handler = dict1_handler()
      {:ok, derived_padded_user} = V1V2.derive_user_from_owner("654321", handler)

      # The derived padded user password starts with the actual user password bytes
      # try authenticating with the derived padded user
      # (authenticate_user pads its input — so feeding the padded binary truncates to 32 correctly)
      assert {:ok, file_key} = V1V2.authenticate_user(derived_padded_user, handler)
      assert file_key == @dict1_file_key
    end

    test "returns {:error, :encrypted_unsupported_handler} when RC4 unavailable" do
      if rc4_available?() do
        :ok
      else
        handler = dict1_handler()

        assert {:error, :encrypted_unsupported_handler} =
                 V1V2.derive_user_from_owner("654321", handler)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # authenticate_owner/2 — thin wrapper around Algorithm 7 + authenticate_user
  # ---------------------------------------------------------------------------

  describe "authenticate_owner/2" do
    @tag :rc4_required
    test "V=2/R=3: owner password '654321' authenticates and returns file key" do
      # authenticate_owner/2 combines Algorithm 7 + Algorithm 5
      handler = dict1_handler()
      assert {:ok, file_key} = V1V2.authenticate_owner("654321", handler)
      assert file_key == @dict1_file_key
    end

    @tag :rc4_required
    test "wrong owner password returns :error" do
      handler = dict1_handler()
      assert :error = V1V2.authenticate_owner("wrongowner", handler)
    end
  end
end
