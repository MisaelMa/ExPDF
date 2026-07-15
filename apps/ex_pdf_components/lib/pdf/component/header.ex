defmodule Pdf.Component.Header do
  @moduledoc """
  Banda `<header>` de sección: barra verde con texto (periodo, referencia, etc.).

  ## Builder

      %{type: :header, props: %{
        text: "PERIODO FACTURADO: 25 ENE 23 - 27 MAR 23",
        align: :center,
        style: %{position: :cursor, width: :full}
      }}
  """

  alias Pdf.Component.Draw

  @default_height 9

  def measure(style), do: Map.get(style, :height, @default_height)

  def render(doc, {x, y}, style) do
    w = Map.get(style, :width, 575)
    h = measure(style)
    text = Map.get(style, :text, "")
    align = Map.get(style, :align, :center)

    doc = Draw.fill_rect(doc, x, y, w, h, Draw.green_hdr())

    case align do
      :left ->
        Draw.text_at(doc, x + 3, y - 2, text, font_size: 6.2, bold: true, color: Draw.white())

      _ ->
        Draw.text_at(doc, x + w / 2, y - 3, text,
          font_size: 6,
          bold: true,
          color: Draw.white(),
          align: :center,
          box_w: w
        )
    end
  end
end
