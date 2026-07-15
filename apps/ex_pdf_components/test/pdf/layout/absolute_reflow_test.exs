defmodule Pdf.Layout.AbsoluteReflowTest do
  use ExUnit.Case, async: true

  alias Pdf.Layout.AbsoluteReflow

  describe "prepare/4" do
    test "long header name pushes city text down" do
      children = [
        %{
          type: :text,
          props: %{
            content: "Very Long Resort Name That Wraps Over Multiple Lines Here",
            style: %{position: {85, -8}, font_size: 10, bold: true}
          }
        },
        %{
          type: :text,
          props: %{
            content: "Tampa, FL",
            style: %{position: {85, -20}, font_size: 9}
          }
        }
      ]

      prepared = AbsoluteReflow.prepare(children, 180, %{reflow_anchor: 65})

      {_x, name_y} = hd(prepared).props.style.position
      {_x, city_y} = Enum.at(prepared, 1).props.style.position

      assert name_y == -8
      assert city_y < -20
    end
  end
end
