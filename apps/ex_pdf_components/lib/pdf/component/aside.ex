defmodule Pdf.Component.Aside do
  @moduledoc """
  Panel `<aside>` promocional con ilustración, textos y QR.

  ## Builder

      %{type: :aside, props: %{
        qr_payload: "https://example.com",
        style: %{position: {x, y}, size: {200, 79}}
      }}
  """

  alias Pdf.Component.Draw

  def measure(style) do
    case Map.get(style, :size) do
      {_, h} when is_number(h) -> h
      {_, :auto} -> 79
      _ -> Map.get(style, :height, 79)
    end
  end

  def render(doc, {x, y_top}, style) do
    w =
      case Map.get(style, :size) do
        {ww, _} when is_number(ww) -> ww
        _ -> Map.get(style, :width, 200)
      end

    h = measure(style)
    pad = 4
    qr = 48

    doc =
      doc
      |> Draw.fill_rounded_rect(x, y_top, w, h, 3, Draw.gray_light())
      |> Draw.stroke_rounded_rect(x, y_top, w, h, 3, 0.35, Draw.line())

    doc =
      doc
      |> draw_technician(x + pad, y_top - pad - 2)
      |> Draw.text_at(x + pad + 38, y_top - 10, "Obtén tu aviso recibo", font_size: 5.5, bold: true)
      |> Draw.text_at(x + pad + 38, y_top - 17, "más fácil y rápido", font_size: 5.5, bold: true)
      |> Draw.text_at(x + pad + 38, y_top - 25, "Actualiza tus datos", font_size: 5, color: Draw.gray_mid())
      |> Draw.text_at(x + pad + 38, y_top - 31, "mediante el QR...", font_size: 5, color: Draw.gray_mid())
      |> Draw.text_at(x + pad + 38, y_top - h + 9, "¡Escanea el código y listo!",
        font_size: 5.2,
        bold: true,
        color: Draw.green()
      )

    qr_x = x + w - qr - pad

    Pdf.Component.QrCode.render(doc, {qr_x, y_top - pad}, %{
      data: Map.get(style, :qr_payload, ""),
      size: qr,
      ec_level: :m,
      padding: 1,
      background: Draw.white(),
      color: Draw.black()
    })
  end

  defp draw_technician(doc, x, y) do
    skin = {0.96, 0.84, 0.70}

    doc
    |> Draw.fill_rect(x + 8, y - 7, 9, 9, skin)
    |> Draw.fill_rect(x + 5, y - 20, 15, 13, Draw.green())
    |> Draw.fill_rect(x + 2, y - 32, 7, 12, Draw.green())
    |> Draw.fill_rect(x + 16, y - 32, 7, 12, Draw.green())
    |> Draw.fill_rect(x + 6, y - 34, 13, 3, skin)
    |> Draw.fill_rect(x + 4, y - 36, 17, 2, Draw.green_dark())
  end
end
