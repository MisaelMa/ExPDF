defmodule Pdf.Component.KeyValueTest do
  use Pdf.Case, async: true

  alias Pdf.Builder
  alias Pdf.Component.KeyValue

  test "content_width resolves :full against container minus x offset" do
    style = %{width: :full}
    assert KeyValue.content_width(style, 200, 0) == 200
    assert KeyValue.content_width(style, 200, 10) == 190
  end

  test "measure_height grows when value text wraps" do
    style = %{width: :full, font_size: 10, line_height: 18, label_width: 0.35}
    long_value = Enum.join(List.duplicate("word", 20), " ")

    short_h =
      KeyValue.measure_height(style, [{"Label:", "short"}], 120, x_offset: 2)

    long_h =
      KeyValue.measure_height(style, [{"Label:", long_value}], 120, x_offset: 2)

    assert long_h > short_h
  end

  test "box key_value with width :full wraps inside inner area" do
    long_value = String.duplicate("Payment detail ", 8)

    template = [
      %{type: :box, props: %{
        style: %{position: {50, 700}, size: {160, :auto}, padding: 5, border: 1, clip: false},
        children: [
          %{type: :key_value, props: %{
            pairs: [{"Concept:", long_value}, {"Total:", "$99.00"}],
            style: %{
              position: {2, -8},
              width: :full,
              font_size: 10,
              line_height: 14,
              label_width: 0.35,
              value_align: :right
            }
          }}
        ]
      }}
    ]

    inner_w = 160 - 5 * 2 - 1 * 2
    style = %{width: :full, font_size: 10, line_height: 14, label_width: 0.35}

    height =
      KeyValue.measure_height(
        style,
        [{"Concept:", long_value}, {"Total:", "$99.00"}],
        inner_w,
        x_offset: 2
      )

    assert height > 30

    box_h =
      Builder.measure_box_height_absolute(
        %{padding: 5, border: 1},
        Enum.at(template, 0) |> get_in([Access.key!(:props), Access.key!(:children)]),
        160
      )

    assert box_h > 30

    doc = Builder.render(template, %{compress: false})
    output = export(doc.current)
    assert output =~ "Concept:"
    assert output =~ "$99.00"
  end
end
