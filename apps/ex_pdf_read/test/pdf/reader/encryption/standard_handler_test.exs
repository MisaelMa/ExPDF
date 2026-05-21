defmodule Pdf.Reader.Encryption.StandardHandlerTest do
  use ExUnit.Case, async: true

  alias Pdf.Reader.Encryption.StandardHandler

  # ---------------------------------------------------------------------------
  # Test inputs use plain Elixir maps that mirror Pdf.Reader.Parser tagged output:
  #   integers         → bare integer
  #   names (/Name)    → {:name, "Name"}
  #   literal strings  → {:string, binary}
  #   hex strings      → {:hex_string, binary}
  #   booleans         → bare boolean (true / false)
  #   dicts            → plain %{} map
  #
  # doc_id is the /ID[0] binary (first element of the /ID array in the trailer).
  # It is passed as a raw binary to StandardHandler.parse/2.
  # ---------------------------------------------------------------------------

  # Standard 32-byte /O and /U values used for V1–V4 tests
  @o32 :binary.copy(<<0xAA>>, 32)
  @u32 :binary.copy(<<0xBB>>, 32)
  @doc_id :binary.copy(<<0x01>>, 16)

  # 48-byte /O and /U for V5
  @o48 :binary.copy(<<0xCC>>, 48)
  @u48 :binary.copy(<<0xDD>>, 48)
  @oe32 :binary.copy(<<0xEE>>, 32)
  @ue32 :binary.copy(<<0xFF>>, 32)
  @perms16 :binary.copy(<<0x11>>, 16)

  # ---------------------------------------------------------------------------
  # Helper to build minimal encrypt dicts
  # ---------------------------------------------------------------------------

  defp minimal_v1_r2 do
    %{
      "Filter" => {:name, "Standard"},
      "V" => 1,
      "R" => 2,
      "Length" => 40,
      "O" => {:string, @o32},
      "U" => {:string, @u32},
      "P" => -4
    }
  end

  defp minimal_v2_r3 do
    %{
      "Filter" => {:name, "Standard"},
      "V" => 2,
      "R" => 3,
      "Length" => 128,
      "O" => {:string, @o32},
      "U" => {:string, @u32},
      "P" => -3904
    }
  end

  defp v4_r4_dict do
    %{
      "Filter" => {:name, "Standard"},
      "V" => 4,
      "R" => 4,
      "Length" => 128,
      "O" => {:hex_string, @o32},
      "U" => {:hex_string, @u32},
      "P" => -3904,
      "StmF" => {:name, "StdCF"},
      "StrF" => {:name, "StdCF"},
      "CF" => %{
        "StdCF" => %{
          "AuthEvent" => {:name, "DocOpen"},
          "CFM" => {:name, "AESV2"},
          "Length" => 16
        }
      }
    }
  end

  defp v5_r6_dict do
    %{
      "Filter" => {:name, "Standard"},
      "V" => 5,
      "R" => 6,
      "Length" => 256,
      "O" => {:hex_string, @o48},
      "U" => {:hex_string, @u48},
      "OE" => {:hex_string, @oe32},
      "UE" => {:hex_string, @ue32},
      "Perms" => {:hex_string, @perms16},
      "P" => -3904
    }
  end

  # ---------------------------------------------------------------------------
  # Test 1: Minimal V1/R2 — basic field extraction (→ R-ENC1, R-ENC2, R-ENC3)
  # ---------------------------------------------------------------------------
  describe "parse/2 — V1/R2 minimal dict" do
    test "extracts all standard fields into a SecurityHandler struct" do
      {:ok, sh} = StandardHandler.parse(minimal_v1_r2(), @doc_id)

      assert sh.version == 1
      assert sh.revision == 2
      assert sh.length == 40
      assert sh.o == @o32
      assert sh.u == @u32
      assert sh.p == -4
      assert sh.id == @doc_id
      assert sh.encrypt_metadata == true
      assert sh.filter == "Standard"
    end

    test "file_key is nil before authentication" do
      {:ok, sh} = StandardHandler.parse(minimal_v1_r2(), @doc_id)
      assert is_nil(sh.file_key)
    end
  end

  # ---------------------------------------------------------------------------
  # Test 2: V2/R3 with explicit /Length 128 (→ R-ENC1, R-ENC2)
  # ---------------------------------------------------------------------------
  describe "parse/2 — V2/R3 with Length 128" do
    test "extracts length correctly" do
      {:ok, sh} = StandardHandler.parse(minimal_v2_r3(), @doc_id)

      assert sh.version == 2
      assert sh.revision == 3
      assert sh.length == 128
      assert sh.o == @o32
      assert sh.u == @u32
      assert sh.p == -3904
    end

    test "no CF/StmF/StrF fields" do
      {:ok, sh} = StandardHandler.parse(minimal_v2_r3(), @doc_id)

      assert sh.cf == %{}
      assert is_nil(sh.stm_filter)
      assert is_nil(sh.str_filter)
    end
  end

  # ---------------------------------------------------------------------------
  # Test 3: V4/R4 with /CF, /StmF, /StrF (→ R-ENC18)
  # ---------------------------------------------------------------------------
  describe "parse/2 — V4/R4 with Crypt Filters" do
    test "extracts stm_filter and str_filter from /StmF and /StrF" do
      {:ok, sh} = StandardHandler.parse(v4_r4_dict(), @doc_id)

      assert sh.version == 4
      assert sh.revision == 4
      assert sh.stm_filter == "StdCF"
      assert sh.str_filter == "StdCF"
    end

    test "preserves the /CF sub-dict" do
      {:ok, sh} = StandardHandler.parse(v4_r4_dict(), @doc_id)

      assert is_map(sh.cf)
      assert Map.has_key?(sh.cf, "StdCF")
    end

    test "extracts o and u as binaries (hex_string unwrapped)" do
      {:ok, sh} = StandardHandler.parse(v4_r4_dict(), @doc_id)

      assert sh.o == @o32
      assert sh.u == @u32
    end
  end

  # ---------------------------------------------------------------------------
  # Test 4: V5/R6 with /OE, /UE, /Perms (→ R-ENC23, R-ENC25)
  # ---------------------------------------------------------------------------
  describe "parse/2 — V5/R6 with OE/UE/Perms" do
    test "extracts oe, ue, perms fields" do
      {:ok, sh} = StandardHandler.parse(v5_r6_dict(), @doc_id)

      assert sh.version == 5
      assert sh.revision == 6
      assert sh.oe == @oe32
      assert sh.ue == @ue32
      assert sh.perms == @perms16
      assert sh.length == 256
    end

    test "extracts o and u as 48-byte binaries for V5" do
      {:ok, sh} = StandardHandler.parse(v5_r6_dict(), @doc_id)

      assert sh.o == @o48
      assert sh.u == @u48
      assert byte_size(sh.o) == 48
      assert byte_size(sh.u) == 48
    end
  end

  # ---------------------------------------------------------------------------
  # Test 5: /Filter != /Standard returns unsupported error (→ R-ENC2)
  # ---------------------------------------------------------------------------
  describe "parse/2 — unsupported /Filter" do
    test "non-Standard /Filter returns {:error, :encrypted_unsupported_handler}" do
      dict = Map.put(minimal_v2_r3(), "Filter", {:name, "Adobe.PubSec"})

      assert {:error, :encrypted_unsupported_handler} = StandardHandler.parse(dict, @doc_id)
    end

    test "missing /Filter also returns {:error, :encrypted_unsupported_handler}" do
      dict = Map.delete(minimal_v2_r3(), "Filter")

      assert {:error, :encrypted_unsupported_handler} = StandardHandler.parse(dict, @doc_id)
    end
  end

  # ---------------------------------------------------------------------------
  # Test 6: /EncryptMetadata false (→ R-ENC21, R-ENC22)
  # ---------------------------------------------------------------------------
  describe "parse/2 — /EncryptMetadata" do
    test "false overrides the default of true" do
      dict = Map.put(v4_r4_dict(), "EncryptMetadata", false)

      {:ok, sh} = StandardHandler.parse(dict, @doc_id)

      assert sh.encrypt_metadata == false
    end

    test "true is the default when key is absent" do
      {:ok, sh} = StandardHandler.parse(minimal_v1_r2(), @doc_id)

      assert sh.encrypt_metadata == true
    end

    test "explicit true is accepted" do
      dict = Map.put(v4_r4_dict(), "EncryptMetadata", true)

      {:ok, sh} = StandardHandler.parse(dict, @doc_id)

      assert sh.encrypt_metadata == true
    end
  end
end
