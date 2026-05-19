defmodule Pdf.Reader.ParserTest do
  use ExUnit.Case, async: true

  alias Pdf.Reader.Parser

  # ---------------------------------------------------------------------------
  # 3.2.1 — Scalar values
  # ---------------------------------------------------------------------------

  describe "parse_value/1 — scalars" do
    test "integer" do
      assert {42, ""} = Parser.parse_value(<<"42">>)
    end

    test "negative integer" do
      assert {-7, ""} = Parser.parse_value(<<"-7">>)
    end

    test "float" do
      assert {3.14, ""} = Parser.parse_value(<<"3.14">>)
    end

    test "boolean true" do
      assert {true, ""} = Parser.parse_value(<<"true">>)
    end

    test "boolean false" do
      assert {false, ""} = Parser.parse_value(<<"false">>)
    end

    test "null" do
      assert {:null, ""} = Parser.parse_value(<<"null">>)
    end

    test "name" do
      assert {{:name, "Type"}, ""} = Parser.parse_value(<<"/Type">>)
    end

    test "literal string" do
      assert {{:string, "Hello"}, ""} = Parser.parse_value(<<"(Hello)">>)
    end

    test "hex string" do
      assert {{:hex_string, "Hi"}, ""} = Parser.parse_value(<<"<4869>">>)
    end

    test "leading whitespace is stripped" do
      assert {99, ""} = Parser.parse_value(<<"  99">>)
    end

    test "returns rest binary unparsed" do
      assert {1, " 2 3"} = Parser.parse_value(<<"1 2 3">>)
    end
  end

  # ---------------------------------------------------------------------------
  # 3.2.3 — Arrays
  # ---------------------------------------------------------------------------

  describe "parse_value/1 — arrays" do
    test "empty array" do
      assert {[], ""} = Parser.parse_value(<<"[]">>)
    end

    test "simple flat array" do
      assert {[1, 2, 3], ""} = Parser.parse_value(<<"[1 2 3]">>)
    end

    test "array of mixed types" do
      assert {[{:name, "Foo"}, 42, true], ""} =
               Parser.parse_value(<<"[/Foo 42 true]">>)
    end

    test "nested array" do
      assert {[[1, 2], 3], ""} = Parser.parse_value(<<"[[1 2] 3]">>)
    end

    test "array with string" do
      assert {[{:string, "hi"}], ""} = Parser.parse_value(<<"[(hi)]">>)
    end
  end

  # ---------------------------------------------------------------------------
  # 3.2.5 — Dictionaries
  # ---------------------------------------------------------------------------

  describe "parse_value/1 — dictionaries" do
    test "empty dict" do
      assert {%{}, ""} = Parser.parse_value(<<"<<>>">>)
    end

    test "single key-value" do
      assert {%{"Type" => {:name, "Page"}}, ""} =
               Parser.parse_value(<<"<</Type /Page>>">>)
    end

    test "multiple key-value pairs" do
      assert {%{"A" => 1, "B" => 2}, ""} = Parser.parse_value(<<"<</A 1 /B 2>>">>)
    end

    test "nested dict" do
      assert {%{"Inner" => %{"X" => 1}}, ""} =
               Parser.parse_value(<<"<</Inner <</X 1>>>>">>)
    end

    test "dict with array value" do
      assert {%{"Kids" => [1, 2]}, ""} = Parser.parse_value(<<"<</Kids [1 2]>>">>)
    end
  end

  # ---------------------------------------------------------------------------
  # 3.2.7 — Indirect references
  # ---------------------------------------------------------------------------

  describe "parse_value/1 — indirect references" do
    test "parses N G R as {:ref, n, g}" do
      assert {{:ref, 5, 0}, ""} = Parser.parse_value(<<"5 0 R">>)
    end

    test "indirect ref with generation > 0" do
      assert {{:ref, 12, 3}, ""} = Parser.parse_value(<<"12 3 R">>)
    end

    test "ref inside dict value" do
      assert {%{"Root" => {:ref, 1, 0}}, ""} =
               Parser.parse_value(<<"<</Root 1 0 R>>">>)
    end

    test "ref inside array" do
      assert {[{:ref, 3, 0}, {:ref, 4, 0}], ""} =
               Parser.parse_value(<<"[3 0 R 4 0 R]">>)
    end
  end

  # ---------------------------------------------------------------------------
  # 3.2.9 — Full object parsing (N G obj ... endobj)
  # ---------------------------------------------------------------------------

  describe "parse_object/1" do
    test "integer object" do
      assert {:ok, {1, 0}, 42, _rest} = Parser.parse_object(<<"1 0 obj\n42\nendobj">>)
    end

    test "dict object" do
      input = <<"2 0 obj\n<</Type /Page>>\nendobj">>
      assert {:ok, {2, 0}, %{"Type" => {:name, "Page"}}, _rest} = Parser.parse_object(input)
    end

    test "stream object" do
      # 5 bytes: "Hello"
      input = <<"3 0 obj\n<</Length 5>>\nstream\nHello\nendstream\nendobj">>
      assert {:ok, {3, 0}, {:stream, %{"Length" => 5}, raw}, _rest} = Parser.parse_object(input)
      assert raw == "Hello"
    end

    test "stream object with CRLF after stream keyword" do
      input = <<"4 0 obj\n<</Length 3>>\nstream\r\nfoo\nendstream\nendobj">>
      assert {:ok, {4, 0}, {:stream, _, raw}, _rest} = Parser.parse_object(input)
      assert raw == "foo"
    end

    test "returns rest binary after endobj" do
      input = <<"5 0 obj\n1\nendobj\nmore content">>
      assert {:ok, {5, 0}, 1, rest} = Parser.parse_object(input)
      assert rest == "\nmore content"
    end

    test "malformed input returns error" do
      assert {:error, _} = Parser.parse_object(<<"not an object">>)
    end
  end
end
