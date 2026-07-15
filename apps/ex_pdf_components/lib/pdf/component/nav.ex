defmodule Pdf.Component.Nav do
  @moduledoc """
  Barra `<nav>` de contacto / redes en el pie del documento.

  ## Builder

      %{type: :nav, props: %{
        brand: "CFE-contigo",
        phone: "071",
        links: "@CFEmx    cfe.mx    Facebook    Instagram",
        style: %{position: :cursor, width: :full}
      }}
  """

  alias Pdf.Component.Draw

  @height 10

  def measure(_style), do: @height

  def render(doc, {x, y}, style) do
    w = Map.get(style, :width, 575)
    brand = Map.get(style, :brand, "")
    phone = Map.get(style, :phone, "")
    links = Map.get(style, :links, "")

    doc
    |> Draw.fill_rect(x, y, w, @height, Draw.green_hdr())
    |> Draw.text_at(x + 5, y - 2, brand, font_size: 6.2, bold: true, color: Draw.white())
    |> Draw.text_at(x + 62, y - 2, phone, font_size: 6.8, bold: true, color: Draw.white())
    |> Draw.text_at(x + 95, y - 2, links, font_size: 5.2, color: Draw.white())
  end
end
