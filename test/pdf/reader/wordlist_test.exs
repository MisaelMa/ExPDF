defmodule Pdf.Reader.WordlistTest do
  @moduledoc """
  Unit tests for the bundled compile-time dictionaries.
  """
  use ExUnit.Case, async: true

  alias Pdf.Reader.Wordlist

  describe "spanish/0" do
    test "returns a MapSet of ~50k lowercase strings" do
      ms = Wordlist.spanish()
      assert is_struct(ms, MapSet)
      # Source: hermitdave/FrequencyWords es_50k.txt (MIT, derived
      # from OpenSubtitles 2018).
      assert MapSet.size(ms) >= 45_000
      assert MapSet.size(ms) <= 51_000
    end

    test "contains common Spanish words used in CSF text" do
      ms = Wordlist.spanish()

      for word <- ~w(el la de del que es y a en con por para sin sus
                      inicio fin tiene presenta delito autoridad fiscal
                      datos personas extranjero) do
        assert Wordlist.member?(word, ms),
               "expected #{inspect(word)} in Spanish wordlist"
      end
    end
  end

  describe "resolve/1" do
    test ":es returns the bundled Spanish wordlist" do
      assert Wordlist.resolve(:es) == Wordlist.spanish()
    end

    test "a MapSet is returned as-is" do
      ms = MapSet.new(["uno", "dos"])
      assert Wordlist.resolve(ms) == ms
    end

    test "nil returns nil" do
      assert Wordlist.resolve(nil) == nil
    end
  end

  describe "member?/2" do
    test "case-insensitive lookup" do
      ms = MapSet.new(["hola", "mundo"])
      assert Wordlist.member?("hola", ms)
      assert Wordlist.member?("HOLA", ms)
      assert Wordlist.member?("Hola", ms)
      refute Wordlist.member?("adios", ms)
    end

    test "nil dictionary always returns false" do
      refute Wordlist.member?("hola", nil)
    end
  end
end
