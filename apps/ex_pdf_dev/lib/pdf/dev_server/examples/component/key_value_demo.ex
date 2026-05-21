defmodule Pdf.DevServer.Examples.Component.KeyValueDemo do
  @moduledoc false

  def render do
    dark = {0.1, 0.1, 0.1}
    accent = {0.0, 0.45, 0.75}
    gray = {0.45, 0.45, 0.45}

    doc =
      Pdf.new(size: :a4, margin: 40)
      |> Pdf.set_font("Helvetica", 24)
      |> Pdf.set_fill_color(dark)
      |> Pdf.text_at({40, 780}, "KeyValue Component", %{bold: true})
      |> Pdf.set_font("Helvetica", 10)
      |> Pdf.set_fill_color(gray)
      |> Pdf.text_at({40, 764}, "Aligned label-value pairs for invoices, profiles, and data sheets")

    # ── Simple ──
    doc =
      doc
      |> Pdf.set_font("Helvetica", 12)
      |> Pdf.set_fill_color(accent)
      |> Pdf.text_at({40, 730}, "Simple Key-Value", %{bold: true})
      |> Pdf.Component.KeyValue.render({50, 710}, %{width: 300}, [
        {"Name:", "John Doe"},
        {"Email:", "john@example.com"},
        {"Phone:", "+1 (555) 123-4567"},
        {"Role:", "Administrator"}
      ])

    # ── With dividers ──
    doc =
      doc
      |> Pdf.set_font("Helvetica", 12)
      |> Pdf.set_fill_color(accent)
      |> Pdf.text_at({40, 620}, "With Dividers", %{bold: true})
      |> Pdf.Component.KeyValue.render({50, 600}, %{
        width: 350,
        divider: true,
        divider_color: {0.85, 0.85, 0.85}
      }, [
        {"Order #:", "ORD-2026-0519"},
        {"Date:", "May 19, 2026"},
        {"Status:", "Delivered"},
        {"Amount:", "$1,234.50"},
        {"Payment:", "Credit Card ****4242"}
      ])

    # ── Striped ──
    doc =
      doc
      |> Pdf.set_font("Helvetica", 12)
      |> Pdf.set_fill_color(accent)
      |> Pdf.text_at({40, 490}, "Striped Background", %{bold: true})
      |> Pdf.Component.KeyValue.render({50, 470}, %{
        width: 350,
        striped: true,
        stripe_color: {0.95, 0.97, 1.0}
      }, [
        {"CPU:", "Apple M2 Pro"},
        {"Memory:", "32 GB"},
        {"Storage:", "1 TB SSD"},
        {"OS:", "macOS Sequoia 15.4"},
        {"Elixir:", "1.17.3"},
        {"OTP:", "27"}
      ])

    # ── Wide labels ──
    doc
    |> Pdf.set_font("Helvetica", 12)
    |> Pdf.set_fill_color(accent)
    |> Pdf.text_at({40, 350}, "Custom Label Width", %{bold: true})
    |> Pdf.Component.KeyValue.render({50, 330}, %{
      width: 400,
      label_width: 0.45,
      divider: true
    }, [
      {"Company Name:", "Acme Corporation"},
      {"Tax ID:", "RFC-ACM-260519"},
      {"Registered Address:", "123 Main St, Suite 100"},
      {"Contact Person:", "Jane Smith, CFO"}
    ])
  end
end
