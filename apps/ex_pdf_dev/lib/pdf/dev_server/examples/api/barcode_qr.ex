defmodule Pdf.DevServer.Examples.Api.BarcodeQr do
  @moduledoc false

  @logo_url "https://media.gettyimages.com/id/175413610/es/foto/cami%C3%B3n-de-conversi%C3%B3n-de-veh%C3%ADculos-recreativos.jpg?s=612x612&w=gi&k=20&c=r3_cge3isSTnjTcOrnfiRTvxLLe2h_JFOy1QJFqdRuU="

  def render do
    dark = {0.1, 0.1, 0.1}
    gray = {0.5, 0.5, 0.5}
    teal = {0.0, 0.65, 0.63}
    purple = {0.44, 0.2, 0.66}
    red = {0.7, 0.15, 0.15}

    Pdf.new(size: :a4, margin: %{top: 40, bottom: 40, left: 50, right: 50})
    |> Pdf.set_info(title: "Barcode & QR Code Demo")

    # ══════════════════════════════════════════════════════════════
    # PAGE 1 — Standard barcodes + Vehicle shapes
    # ══════════════════════════════════════════════════════════════
    |> Pdf.set_font("Helvetica", 20, bold: true)
    |> Pdf.set_fill_color(dark)
    |> Pdf.text_at({50, 780}, "Barcode & QR Code Demo")
    |> Pdf.set_font("Helvetica", 10)
    |> Pdf.set_fill_color(gray)
    |> Pdf.text_at({50, 762}, "Generated with ex_barcode and ex_qr — pure Elixir, zero dependencies")

    # Standard barcodes
    |> Pdf.set_font("Helvetica", 14, bold: true)
    |> Pdf.set_fill_color(dark)
    |> Pdf.text_at({50, 730}, "Standard Barcodes")
    |> Pdf.Component.Barcode.render({50, 710}, %{
      data: "RESERVATION-38111",
      width: 200, height: 50, color: dark,
      show_text: true, font_size: 9,
      image: @logo_url, image_size: {50, 50},
      image_position: :left, image_border_radius: 6
    })
    |> Pdf.Component.Barcode.render({320, 710}, %{
      data: "INV-2026-0042",
      width: 180, height: 50, color: teal,
      show_text: true, font_size: 9,
      label: "Invoice Barcode", label_color: dark
    })

    # ── Contour shape barcodes ──
    |> Pdf.set_font("Helvetica", 14, bold: true)
    |> Pdf.set_fill_color(dark)
    |> Pdf.text_at({50, 620}, "Shape Barcodes")
    |> Pdf.set_font("Helvetica", 9)
    |> Pdf.set_fill_color(gray)
    |> Pdf.text_at({50, 606}, "Bar heights follow an outline contour with decorations")

    |> Pdf.Component.Barcode.render({50, 590}, %{
      data: "RESERVATION-38111", width: 260, height: 90,
      color: dark, shape: :rv, show_text: true, font_size: 8
    })
    |> Pdf.Component.Barcode.render({330, 590}, %{
      data: "CAMPER-2026", width: 200, height: 85,
      color: teal, shape: :camper, show_text: true, font_size: 8
    })

    |> Pdf.Component.Barcode.render({50, 470}, %{
      data: "CITY-SKYLINE", width: 200, height: 80,
      color: dark, shape: :city, show_text: true, font_size: 7
    })
    |> Pdf.Component.Barcode.render({270, 470}, %{
      data: "WAVE-2026", width: 160, height: 60,
      color: teal, shape: :wave, show_text: true, font_size: 7
    })
    |> Pdf.Component.Barcode.render({450, 470}, %{
      data: "DIAMOND", width: 100, height: 70,
      color: purple, shape: :diamond, show_text: true, font_size: 7
    })
    |> Pdf.Component.Barcode.render({50, 360}, %{
      data: "HILL-42", width: 150, height: 60,
      color: {0.3, 0.5, 0.3}, shape: :hill, show_text: true, font_size: 7
    })

    # ══════════════════════════════════════════════════════════════
    # PAGE 2 — QR Codes
    # ══════════════════════════════════════════════════════════════
    |> Pdf.add_page(:a4)
    |> Pdf.set_font("Helvetica", 20, bold: true)
    |> Pdf.set_fill_color(dark)
    |> Pdf.text_at({50, 780}, "QR Codes")
    |> Pdf.set_font("Helvetica", 10)
    |> Pdf.set_fill_color(gray)
    |> Pdf.text_at({50, 762}, "Logo overlay, card styling, labels, and color customization")

    |> Pdf.set_font("Helvetica", 13, bold: true)
    |> Pdf.set_fill_color(dark)
    |> Pdf.text_at({50, 730}, "With Logo & Card Styling")
    |> Pdf.Component.QrCode.render({50, 710}, %{
      data: "https://github.com/MisaelMa/ExPDF",
      size: 130, ec_level: :h, color: dark,
      logo: @logo_url, logo_size: 30, logo_border_radius: 6,
      label: "GitHub Repo", label_bold: true,
      border: 1, border_color: {0.85, 0.85, 0.85},
      border_radius: 8, border_fill: {0.98, 0.98, 0.98}, padding: 6
    })
    |> Pdf.Component.QrCode.render({220, 710}, %{
      data: "https://example.com/reservation/38111",
      size: 130, ec_level: :h, color: teal,
      background: {1, 1, 1},
      logo: @logo_url, logo_size: 28,
      logo_background: {1, 1, 1}, logo_border_radius: 14,
      label: "Reservation #38111", label_color: teal,
      border: 1.5, border_color: teal, border_radius: 10, padding: 8
    })
    |> Pdf.Component.QrCode.render({390, 710}, %{
      data: "WIFI:T:WPA;S:Campground-Guest;P:welcome2026;;",
      size: 130, ec_level: :h,
      color: {0.15, 0.15, 0.4}, background: {0.96, 0.96, 1.0},
      border: 0.5, border_color: {0.7, 0.7, 0.85}, border_radius: 6,
      label: "WiFi Access", label_color: {0.15, 0.15, 0.4}
    })

    |> Pdf.set_font("Helvetica", 13, bold: true)
    |> Pdf.set_fill_color(dark)
    |> Pdf.text_at({50, 530}, "Small QR Codes with Labels")
    |> Pdf.Component.QrCode.render({50, 510}, %{
      data: "Hello!", size: 80, ec_level: :l, color: dark,
      label: "Hello", label_font_size: 8
    })
    |> Pdf.Component.QrCode.render({150, 510}, %{
      data: "ExPDF", size: 80, ec_level: :m, color: teal,
      label: "ExPDF", label_color: teal, label_font_size: 8
    })
    |> Pdf.Component.QrCode.render({250, 510}, %{
      data: "https://elixir-lang.org", size: 80, ec_level: :q,
      color: purple, label: "Elixir", label_color: purple,
      label_font_size: 8, border: 0.5, border_color: purple,
      border_radius: 4, padding: 3
    })
    |> Pdf.Component.QrCode.render({360, 510}, %{
      data: "12345", size: 80, ec_level: :h,
      color: red, label: "ID: 12345", label_color: red,
      label_bold: true, label_font_size: 8
    })
  end
end
