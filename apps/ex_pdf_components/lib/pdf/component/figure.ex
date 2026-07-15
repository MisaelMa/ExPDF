defmodule Pdf.Component.Figure do
  @moduledoc """
  `<figure>` de pago: QR, código de barras y total.

  ## Builder

      %{type: :figure, props: %{
        qr_payload: "...",
        barcode_data: "...",
        barcode_top: "...",
        barcode_bottom: "...",
        total_display: "$2,679",
        total_words: "dos mil seiscientos setenta y nueve pesos",
        style: %{position: :cursor, width: :full}
      }}
  """

  alias Pdf.Component.Draw

  @height 54

  def measure(_style), do: @height

  def render(doc, {x, y}, style) do
    w = Map.get(style, :width, 575)

    doc =
      doc
      |> Draw.hline(x, y, x + w, Draw.line())
      |> Draw.hline(x, y - @height, x + w, Draw.line())
      |> Draw.vline(x + 52, y, y - @height, Draw.line_faint())

    doc =
      Pdf.Component.QrCode.render(doc, {x + 5, y - 5}, %{
        data: Map.get(style, :qr_payload, ""),
        size: 40,
        ec_level: :m,
        padding: 1,
        background: Draw.white(),
        color: Draw.black()
      })

    doc =
      doc
      |> Draw.text_at(x + w / 2, y - 8, Map.get(style, :barcode_top, ""),
        font_size: 5,
        align: :center,
        box_w: 190
      )

    doc =
      Pdf.Component.Barcode.render(doc, {x + w / 2 - 92, y - 34}, %{
        data: Map.get(style, :barcode_data, ""),
        width: 184,
        height: 24,
        show_text: false
      })

    doc
    |> Draw.text_at(x + w / 2, y - @height + 7, Map.get(style, :barcode_bottom, ""),
      font_size: 5,
      color: Draw.black(),
      align: :center,
      box_w: 200
    )
    |> Draw.text_at(x + w - 6, y - 12, "TOTAL A PAGAR:",
      font_size: 6.2,
      bold: true,
      align: :right,
      box_w: 105
    )
    |> Draw.text_at(x + w - 6, y - 27, Map.get(style, :total_display, ""),
      font_size: 19,
      bold: true,
      align: :right,
      box_w: 105
    )
    |> Draw.text_at(x + w - 6, y - 38, "(#{Map.get(style, :total_words, "")})",
      font_size: 4.3,
      color: Draw.gray(),
      align: :right,
      box_w: 105
    )
  end
end
