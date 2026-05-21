defmodule Pdf.DevServer.Examples.Component.SignatureDemo do
  @moduledoc false

  def render do
    dark = {0.1, 0.1, 0.1}
    accent = {0.0, 0.45, 0.75}
    gray = {0.45, 0.45, 0.45}

    doc =
      Pdf.new(size: :a4, margin: 40)
      |> Pdf.set_font("Helvetica", 24)
      |> Pdf.set_fill_color(dark)
      |> Pdf.text_at({40, 780}, "Signature Component", %{bold: true})
      |> Pdf.set_font("Helvetica", 10)
      |> Pdf.set_fill_color(gray)
      |> Pdf.text_at({40, 764}, "Signature lines with name, title, date, and label")

    # ── Simple signature ──
    doc =
      doc
      |> Pdf.set_font("Helvetica", 12)
      |> Pdf.set_fill_color(accent)
      |> Pdf.text_at({40, 720}, "Simple Signature", %{bold: true})
      |> Pdf.Component.Signature.render({50, 690}, %{
        name: "John Doe",
        title: "CEO, Acme Corp"
      })

    # ── With date ──
    doc =
      doc
      |> Pdf.set_font("Helvetica", 12)
      |> Pdf.set_fill_color(accent)
      |> Pdf.text_at({40, 630}, "With Date", %{bold: true})
      |> Pdf.Component.Signature.render({50, 600}, %{
        name: "Jane Smith",
        title: "Chief Technology Officer",
        date: "May 19, 2026",
        width: 280
      })

    # ── With label ──
    doc =
      doc
      |> Pdf.set_font("Helvetica", 12)
      |> Pdf.set_fill_color(accent)
      |> Pdf.text_at({40, 530}, "Labeled Signatures", %{bold: true})
      |> Pdf.Component.Signature.render({50, 500}, %{
        label: "Authorized by",
        name: "Robert Johnson",
        title: "VP of Operations",
        width: 220
      })
      |> Pdf.Component.Signature.render({310, 500}, %{
        label: "Approved by",
        name: "Maria Garcia",
        title: "Legal Counsel",
        date: "May 19, 2026",
        width: 220
      })

    # ── Contract style ──
    doc =
      doc
      |> Pdf.set_font("Helvetica", 12)
      |> Pdf.set_fill_color(accent)
      |> Pdf.text_at({40, 420}, "Contract Style (Side by Side)", %{bold: true})

    doc =
      doc
      |> Pdf.save_state()
      |> Pdf.set_fill_color({0.97, 0.97, 0.97})
      |> Pdf.rectangle({40, 310}, {500, 90})
      |> Pdf.fill()
      |> Pdf.restore_state()

    doc
    |> Pdf.Component.Signature.render({60, 380}, %{
      label: "PARTY A",
      name: "Global Industries LLC",
      title: "By: Michael Chen, Director",
      date: "May 19, 2026",
      width: 200,
      line_color: {0.2, 0.2, 0.5}
    })
    |> Pdf.Component.Signature.render({320, 380}, %{
      label: "PARTY B",
      name: "Tech Solutions Inc.",
      title: "By: Sarah Williams, CEO",
      date: "May 19, 2026",
      width: 200,
      line_color: {0.2, 0.2, 0.5}
    })
  end
end
