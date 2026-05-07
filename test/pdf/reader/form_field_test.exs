defmodule Pdf.Reader.FormFieldTest do
  use ExUnit.Case, async: true

  alias Pdf.Reader.FormField

  describe "FormField struct defaults" do
    test "1.1: bare %FormField{} has all fields with correct defaults" do
      f = %FormField{}

      assert f.name == nil
      assert f.partial_name == nil
      assert f.type == :unknown
      assert f.value == nil
      assert f.default == nil
      assert f.tooltip == nil
      assert f.flags == %{}
      assert f.rect == nil
    end

    test "1.1: struct has all expected keys" do
      f = %FormField{}
      keys = Map.keys(f) -- [:__struct__]
      expected = [:name, :partial_name, :type, :value, :default, :tooltip, :flags, :rect]
      assert Enum.sort(keys) == Enum.sort(expected)
    end

    test "1.1: struct fields can be set individually" do
      f = %FormField{
        name: "Address.Street",
        partial_name: "Street",
        type: :text,
        value: "Main St",
        default: "",
        tooltip: "Street address",
        flags: %{required: true},
        rect: {0.0, 0.0, 100.0, 20.0}
      }

      assert f.name == "Address.Street"
      assert f.partial_name == "Street"
      assert f.type == :text
      assert f.value == "Main St"
      assert f.default == ""
      assert f.tooltip == "Street address"
      assert f.flags == %{required: true}
      assert f.rect == {0.0, 0.0, 100.0, 20.0}
    end
  end
end
