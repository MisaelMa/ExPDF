defmodule Pdf.Component.Meter do
  @moduledoc """
  Indicador `<meter>` con icono y barra de gradiente.

  ## Builder

      %{type: :meter, props: %{
        percent: 50,
        label: "Tu consumo está en el rango medio",
        style: %{position: :cursor, width: :full}
      }}
  """

  alias Pdf.Component.Draw

  @height 22

  def measure(_style), do: @height

  def render(doc, {x, y}, style) do
    w = Map.get(style, :width, 575)
    pct = Map.get(style, :percent, 50)
    label = Map.get(style, :label, "")

    bar_x = x + 28
    bar_w = w - 32
    bar_h = 5

    colors = [
      {0.10, 0.52, 0.24},
      {0.52, 0.76, 0.14},
      {0.90, 0.80, 0.08},
      {0.94, 0.46, 0.06},
      {0.76, 0.08, 0.08}
    ]

    doc = draw_house(doc, x, y)

    doc =
      Enum.reduce(0..54, doc, fn i, d ->
        t = i / 54
        seg = bar_w / 55
        Draw.fill_rect(d, bar_x + i * seg, y - bar_h, seg + 0.15, bar_h, Draw.lerp_colors(colors, t))
      end)

    mx = bar_x + bar_w * pct / 100

    doc
    |> Draw.fill_rect(mx - 0.8, y - bar_h - 2, 1.6, bar_h + 4, Draw.black())
    |> Draw.stroke_rect(bar_x, y - bar_h, bar_w, bar_h, 0.25, Draw.line())
    |> Draw.text_at(bar_x, y - bar_h - 8, label, font_size: 5.2, color: Draw.gray_mid())
  end

  defp draw_house(doc, x, y) do
    doc
    |> Draw.fill_rect(x + 5, y - 7, 12, 8, Draw.gray_light())
    |> Draw.fill_rect(x + 3, y - 1, 16, 1.5, Draw.green())
    |> Draw.fill_rect(x + 9, y - 5, 3, 3, Draw.white())
  end
end
