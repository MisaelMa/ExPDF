defmodule Pdf.Reader.EncryptionTest do
  use ExUnit.Case, async: true

  alias Pdf.Reader.Encryption
  alias Pdf.Reader.Encryption.StandardHandler

  # ---------------------------------------------------------------------------
  # Test vectors
  # Source: Mozilla pdf.js test/unit/crypto_spec.js — dict1 (V=2, R=3, RC4-128)
  # ---------------------------------------------------------------------------

  # /O bytes: 32 bytes
  @dict1_o Base.decode16!("80C30496916F20736C3AE61B135491F20D5612E3FF5EBBE9564FD86B9ACA7C5D")
  # /U bytes: 32 bytes
  @dict1_u Base.decode16!("6A0C8D3E591900BC6A647D91BDAA001800000000000000000000000000000000")
  # /ID[0]: 16 bytes
  @dict1_id Base.decode16!("F6C6AF17F372528D524D9A80D1EFDF18")

  # V5/R6 test vectors from pdf.js aes256IsoDict
  @v5_u Base.decode16!(
          "5EE6CD4BA663FA4CDB801155391121A4962E67B0A09CBBE9A6DFA3FD93EB5FB8" <>
            "53F59265C6F722C6BF0B105EEDD814AF"
        )
  @v5_o Base.decode16!(
          "58E83E36F51AF5D1897BDD48C73125D91F4A73A77F9EB04D2DA3572F275AD98D" <>
            "8EE8A9D0CAD605B91DD0B92E0B4C8795"
        )
  @v5_ue Base.decode16!("79D002B5E6599C3CFD8FD41C54B4C4B1AD80DD6B2E145EBA87335F1814DFFE24")
  @v5_oe Base.decode16!("D149E04D679BC9B5BE44DF143E5A38D205F0B280EE7C44FEFDF43E6CD0870AFB")
  @v5_file_key Base.decode16!("2ADAD527495B484F4326F88512BD3D226B4F1D383BB5D576712241D257AE16EF")

  # Build a V2/R3 handler for dict1 tests
  defp v2r3_handler do
    %StandardHandler{
      version: 2,
      revision: 3,
      length: 128,
      o: @dict1_o,
      u: @dict1_u,
      p: -1028,
      id: @dict1_id,
      encrypt_metadata: true
    }
  end

  defp v5r6_handler do
    %StandardHandler{
      version: 5,
      revision: 6,
      u: @v5_u,
      o: @v5_o,
      ue: @v5_ue,
      oe: @v5_oe,
      p: -3904
    }
  end

  # ---------------------------------------------------------------------------
  # Task 7.1 — Encryption.unlock/3 dispatch tests
  # ---------------------------------------------------------------------------

  describe "Pdf.Reader.Encryption.unlock/3" do
    test "V2/R3 correct user password returns {:ok, handler} with file_key set" do
      handler = v2r3_handler()
      assert {:ok, unlocked} = Encryption.unlock("123456", handler, %{})
      assert is_binary(unlocked.file_key)
      assert byte_size(unlocked.file_key) == 16
    end

    test "V2/R3 wrong password returns :error" do
      handler = v2r3_handler()
      assert :error = Encryption.unlock("wrong_password", handler, %{})
    end

    test "V2/R3 empty password returns :error when empty password fails" do
      handler = v2r3_handler()
      # dict1 user password is "123456", so empty password fails
      assert :error = Encryption.unlock("", handler, %{})
    end

    test "V2/R3 owner password unlocks and returns file_key" do
      handler = v2r3_handler()
      # owner password for dict1 is "654321"
      assert {:ok, unlocked} = Encryption.unlock("654321", handler, %{})
      assert is_binary(unlocked.file_key)
    end

    test "V5/R6 correct user password dispatches to V5" do
      handler = v5r6_handler()
      assert {:ok, unlocked} = Encryption.unlock("user", handler, %{})
      assert unlocked.file_key == @v5_file_key
    end

    test "V5/R6 correct owner password dispatches to V5" do
      handler = v5r6_handler()
      assert {:ok, unlocked} = Encryption.unlock("owner", handler, %{})
      assert unlocked.file_key == @v5_file_key
    end

    test "V5/R6 wrong password returns :error" do
      handler = v5r6_handler()
      assert :error = Encryption.unlock("badpassword", handler, %{})
    end

    test "unsupported version (V=3) returns {:error, :encrypted_unsupported_handler}" do
      handler = %StandardHandler{version: 3, revision: 3}
      assert {:error, :encrypted_unsupported_handler} = Encryption.unlock("any", handler, %{})
    end

    test "nil version returns {:error, :encrypted_unsupported_handler}" do
      handler = %StandardHandler{version: nil, revision: nil}
      assert {:error, :encrypted_unsupported_handler} = Encryption.unlock("any", handler, %{})
    end

    test "V5/R5 (deprecated) is rejected via V5 module" do
      handler = %StandardHandler{
        version: 5,
        revision: 5,
        u: @v5_u,
        o: @v5_o,
        ue: @v5_ue,
        oe: @v5_oe
      }

      assert {:error, :encrypted_unsupported_handler} = Encryption.unlock("any", handler, %{})
    end
  end

  # ---------------------------------------------------------------------------
  # Task 7.3 — Document.t() accepts :encryption field
  # ---------------------------------------------------------------------------

  describe "Pdf.Reader.Document :encryption field" do
    test "Document struct defaults :encryption to nil" do
      doc = %Pdf.Reader.Document{}
      assert is_nil(doc.encryption)
    end

    test "Document struct accepts a %StandardHandler{} for :encryption" do
      handler = v2r3_handler()
      doc = %Pdf.Reader.Document{encryption: handler}
      assert doc.encryption == handler
    end

    test "Document struct accepts a handler with file_key set" do
      handler = %{v2r3_handler() | file_key: <<1::128>>}
      doc = %Pdf.Reader.Document{encryption: handler}
      assert is_binary(doc.encryption.file_key)
    end
  end
end
