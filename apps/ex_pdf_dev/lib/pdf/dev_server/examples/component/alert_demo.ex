defmodule Pdf.DevServer.Examples.Component.AlertDemo do
  @moduledoc false

  def render do
    dark = {0.1, 0.1, 0.1}
    accent = {0.0, 0.45, 0.75}
    gray = {0.45, 0.45, 0.45}

    doc =
      Pdf.new(size: :a4, margin: 40)
      |> Pdf.set_font("Helvetica", 24)
      |> Pdf.set_fill_color(dark)
      |> Pdf.text_at({40, 780}, "Alert Component", %{bold: true})
      |> Pdf.set_font("Helvetica", 10)
      |> Pdf.set_fill_color(gray)
      |> Pdf.text_at({40, 764}, "Notification boxes with icon, title, message — info, success, warning, error")

    # ── Info ──
    doc =
      doc
      |> Pdf.Component.Alert.render({40, 740}, %{
        type: :info,
        title: "Information",
        message: "Your account has been updated successfully. Changes will take effect within 24 hours.",
        width: 500
      })

    # ── Success ──
    doc =
      doc
      |> Pdf.Component.Alert.render({40, 660}, %{
        type: :success,
        title: "Payment Confirmed",
        message: "Transaction #38111 has been processed. A confirmation email has been sent to your address.",
        width: 500
      })

    # ── Warning ──
    doc =
      doc
      |> Pdf.Component.Alert.render({40, 580}, %{
        type: :warning,
        title: "Approaching Limit",
        message: "You have used 85% of your storage quota. Consider upgrading your plan or removing unused files.",
        width: 500
      })

    # ── Error ──
    doc =
      doc
      |> Pdf.Component.Alert.render({40, 500}, %{
        type: :error,
        title: "Connection Failed",
        message: "Unable to reach the database server. Please check your network settings and try again.",
        width: 500
      })

    # ── Without title ──
    doc =
      doc
      |> Pdf.set_font("Helvetica", 12)
      |> Pdf.set_fill_color(accent)
      |> Pdf.text_at({40, 420}, "Without Title", %{bold: true})
      |> Pdf.Component.Alert.render({40, 400}, %{
        type: :info,
        message: "This is a simple informational alert without a title. Just a clean message box.",
        width: 500
      })

    # ── Side by side ──
    doc
    |> Pdf.set_font("Helvetica", 12)
    |> Pdf.set_fill_color(accent)
    |> Pdf.text_at({40, 330}, "Compact Side-by-Side", %{bold: true})
    |> Pdf.Component.Alert.render({40, 310}, %{
      type: :success,
      title: "Saved",
      message: "Changes saved.",
      width: 240
    })
    |> Pdf.Component.Alert.render({300, 310}, %{
      type: :error,
      title: "Failed",
      message: "Upload failed.",
      width: 240
    })
  end
end
