defmodule Pdf.DevServer.Examples.Component.StepIndicatorDemo do
  @moduledoc false

  def render do
    dark = {0.1, 0.1, 0.1}
    accent = {0.0, 0.45, 0.75}
    gray = {0.45, 0.45, 0.45}

    doc =
      Pdf.new(size: :a4, margin: 40)
      |> Pdf.set_font("Helvetica", 24)
      |> Pdf.set_fill_color(dark)
      |> Pdf.text_at({40, 780}, "StepIndicator Component", %{bold: true})
      |> Pdf.set_font("Helvetica", 10)
      |> Pdf.set_fill_color(gray)
      |> Pdf.text_at({40, 764}, "Numbered steps with connecting line showing progress")

    # ── 4-step wizard ──
    doc =
      doc
      |> Pdf.set_font("Helvetica", 12)
      |> Pdf.set_fill_color(accent)
      |> Pdf.text_at({40, 720}, "Checkout Flow", %{bold: true})
      |> Pdf.Component.StepIndicator.render({50, 700}, %{width: 450}, [
        %{label: "Cart", status: :completed},
        %{label: "Shipping", status: :completed},
        %{label: "Payment", status: :active},
        %{label: "Confirm", status: :pending}
      ])

    # ── 5-step onboarding ──
    doc =
      doc
      |> Pdf.set_font("Helvetica", 12)
      |> Pdf.set_fill_color(accent)
      |> Pdf.text_at({40, 630}, "Onboarding Process", %{bold: true})
      |> Pdf.Component.StepIndicator.render({50, 610}, %{width: 480}, [
        %{label: "Account", status: :completed},
        %{label: "Profile", status: :completed},
        %{label: "Team", status: :completed},
        %{label: "Settings", status: :active},
        %{label: "Done", status: :pending}
      ])

    # ── Custom colors ──
    doc =
      doc
      |> Pdf.set_font("Helvetica", 12)
      |> Pdf.set_fill_color(accent)
      |> Pdf.text_at({40, 540}, "Custom Colors", %{bold: true})
      |> Pdf.Component.StepIndicator.render({50, 520}, %{
        width: 400,
        step_size: 28,
        completed_color: {0.5, 0.2, 0.8},
        active_color: {0.9, 0.4, 0.1},
        pending_color: {0.85, 0.85, 0.85}
      }, [
        %{label: "Draft", status: :completed},
        %{label: "Review", status: :active},
        %{label: "Approve", status: :pending},
        %{label: "Publish", status: :pending}
      ])

    # ── All completed ──
    doc
    |> Pdf.set_font("Helvetica", 12)
    |> Pdf.set_fill_color(accent)
    |> Pdf.text_at({40, 440}, "All Completed", %{bold: true})
    |> Pdf.Component.StepIndicator.render({50, 420}, %{width: 300}, [
      %{label: "Start", status: :completed},
      %{label: "Process", status: :completed},
      %{label: "Done", status: :completed}
    ])
  end
end
