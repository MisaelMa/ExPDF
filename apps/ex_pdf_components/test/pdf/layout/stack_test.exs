defmodule Pdf.Layout.StackTest do
  use ExUnit.Case, async: true

  alias Pdf.Layout.Stack

  describe "measure/4" do
    test "long name increases stack height and children have no y position" do
      children = [
        %{
          type: :text,
          props: %{
            content: "Very Long Resort Name That Wraps Over Multiple Lines Here",
            style: %{font_size: 10, bold: true}
          }
        },
        %{type: :text, props: %{content: "Tampa, FL", style: %{font_size: 9}}}
      ]

      short =
        Stack.measure(
          [
            %{type: :text, props: %{content: "Short", style: %{font_size: 10}}}
          ],
          180,
          %{position: {85, -8}}
        )

      tall = Stack.measure(children, 180, %{position: {85, -8}})

      assert tall > short
      refute Map.has_key?(hd(children).props.style, :position)
    end
  end
end
