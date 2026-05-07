defmodule Pdf.Reader.LexerTest do
  use ExUnit.Case, async: true

  alias Pdf.Reader.Lexer

  # ---------------------------------------------------------------------------
  # 3.1.1 — Scalars: integers, reals, booleans, null
  # ---------------------------------------------------------------------------

  describe "next_token/1 — integers" do
    test "positive integer" do
      assert {{:integer, 123}, " rest"} = Lexer.next_token(<<"123 rest">>)
    end

    test "negative integer" do
      assert {{:integer, -42}, ""} = Lexer.next_token(<<"-42">>)
    end

    test "zero" do
      assert {{:integer, 0}, ""} = Lexer.next_token(<<"0">>)
    end

    test "integer followed by newline" do
      assert {{:integer, 7}, "\nfoo"} = Lexer.next_token(<<"7\nfoo">>)
    end

    test "leading whitespace is skipped" do
      assert {{:integer, 5}, ""} = Lexer.next_token(<<"   5">>)
    end
  end

  describe "next_token/1 — reals" do
    test "standard float" do
      assert {{:real, -3.14}, ""} = Lexer.next_token(<<"-3.14">>)
    end

    test "positive float with sign" do
      assert {{:real, 42.0}, ""} = Lexer.next_token(<<"+42.0">>)
    end

    test "leading dot" do
      assert {{:real, 0.5}, ""} = Lexer.next_token(<<".5">>)
    end

    test "trailing dot" do
      assert {{:real, 1.0}, ""} = Lexer.next_token(<<"1.">>)
    end
  end

  describe "next_token/1 — booleans" do
    test "true" do
      assert {{:boolean, true}, " x"} = Lexer.next_token(<<"true x">>)
    end

    test "false" do
      assert {{:boolean, false}, ""} = Lexer.next_token(<<"false">>)
    end
  end

  describe "next_token/1 — null" do
    test "null keyword" do
      assert {:null, " rest"} = Lexer.next_token(<<"null rest">>)
    end
  end

  describe "next_token/1 — empty / end" do
    test "empty binary returns :eof" do
      assert :eof = Lexer.next_token(<<>>)
    end

    test "only whitespace returns :eof" do
      assert :eof = Lexer.next_token(<<"   \t\r\n">>)
    end
  end

  # ---------------------------------------------------------------------------
  # 3.1.3 — Names, literal strings, hex strings, comments
  # ---------------------------------------------------------------------------

  describe "next_token/1 — names" do
    test "simple name" do
      assert {{:name, "Type"}, ""} = Lexer.next_token(<<"/Type">>)
    end

    test "name followed by whitespace" do
      assert {{:name, "Filter"}, " "} = Lexer.next_token(<<"/Filter ">>)
    end

    test "name with hash-hex escape (PDF 1.2+)" do
      # /Type#20Name → /Type Name (0x20 = space in the name)
      assert {{:name, "Type Name"}, ""} = Lexer.next_token(<<"/Type#20Name">>)
    end

    test "empty name (just /)" do
      assert {{:name, ""}, " "} = Lexer.next_token(<<"/ ">>)
    end
  end

  describe "next_token/1 — literal strings" do
    test "simple string" do
      assert {{:string, "Hello"}, ""} = Lexer.next_token(<<"(Hello)">>)
    end

    test "string with escape sequences" do
      # \n, \r, \t, \b, \f inside literal strings
      assert {{:string, "\n\r\t\b\f"}, ""} = Lexer.next_token(<<"(\\n\\r\\t\\b\\f)">>)
    end

    test "string with escaped parentheses" do
      assert {{:string, "(nested)"}, ""} = Lexer.next_token(<<"(\\(nested\\))">>)
    end

    test "string with octal escape" do
      # \101 = 'A' (0x41 = 65)
      assert {{:string, "A"}, ""} = Lexer.next_token(<<"(\\101)">>)
    end

    test "string with balanced nested parens (no escape needed)" do
      assert {{:string, "(ok)"}, ""} = Lexer.next_token(<<"((ok))">>)
    end
  end

  describe "next_token/1 — hex strings" do
    test "simple hex string" do
      # <48656C6C6F> = "Hello"
      assert {{:hex_string, "Hello"}, ""} = Lexer.next_token(<<"<48656C6C6F>">>)
    end

    test "hex string with whitespace" do
      assert {{:hex_string, "Hello"}, ""} = Lexer.next_token(<<"<48 65 6C 6C 6F>">>)
    end

    test "hex string with odd nibble count pads with zero" do
      # <9> → 0x90
      assert {{:hex_string, <<0x90>>}, ""} = Lexer.next_token(<<"<9>">>)
    end
  end

  describe "next_token/1 — comments" do
    test "comment is skipped, next token returned" do
      assert {{:integer, 42}, ""} = Lexer.next_token(<<"% this is a comment\n42">>)
    end

    test "comment at end returns eof" do
      assert :eof = Lexer.next_token(<<"% only a comment">>)
    end
  end

  # ---------------------------------------------------------------------------
  # 3.1.5 — Array delimiters, dict delimiters, indirect refs
  # ---------------------------------------------------------------------------

  describe "next_token/1 — array delimiters" do
    test "open bracket" do
      assert {:array_open, " 1]"} = Lexer.next_token(<<"[ 1]">>)
    end

    test "close bracket" do
      assert {:array_close, ""} = Lexer.next_token(<<"]">>)
    end
  end

  describe "next_token/1 — dict delimiters" do
    test "open dict" do
      assert {:dict_open, "/Type"} = Lexer.next_token(<<"<</Type">>)
    end

    test "close dict" do
      assert {:dict_close, ""} = Lexer.next_token(<<">>">>)
    end
  end

  describe "next_token/1 — keywords" do
    test "obj keyword" do
      assert {:obj, " 1"} = Lexer.next_token(<<"obj 1">>)
    end

    test "endobj keyword" do
      assert {:endobj, ""} = Lexer.next_token(<<"endobj">>)
    end

    test "stream keyword" do
      assert {:stream, "\ndata"} = Lexer.next_token(<<"stream\ndata">>)
    end

    test "endstream keyword" do
      assert {:endstream, ""} = Lexer.next_token(<<"endstream">>)
    end

    test "xref keyword" do
      assert {:xref, "\n"} = Lexer.next_token(<<"xref\n">>)
    end

    test "trailer keyword" do
      assert {:trailer, "\n"} = Lexer.next_token(<<"trailer\n">>)
    end

    test "startxref keyword" do
      assert {:startxref, "\n"} = Lexer.next_token(<<"startxref\n">>)
    end

    test "R keyword" do
      assert {:r, ""} = Lexer.next_token(<<"R">>)
    end

    test "f keyword (free xref entry marker)" do
      assert {:f, " "} = Lexer.next_token(<<"f ">>)
    end

    test "n keyword (in-use xref entry marker)" do
      assert {:n, " "} = Lexer.next_token(<<"n ">>)
    end
  end
end
