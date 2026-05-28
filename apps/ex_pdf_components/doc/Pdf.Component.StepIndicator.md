# `Pdf.Component.StepIndicator`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.2/lib/pdf/component/step_indicator.ex#L1)

Step indicator component for PDF documents.

Renders numbered steps with a connecting line, showing progress
through a multi-step process (wizard-style).

## Examples

    doc |> Pdf.Component.StepIndicator.render({50, 700}, %{width: 450}, [
      %{label: "Account", status: :completed},
      %{label: "Profile", status: :active},
      %{label: "Review", status: :pending},
      %{label: "Done", status: :pending}
    ])

# `render`

Render a step indicator at `{x, y}`.

## Style options

- `:width` — total width (default `400`)
- `:step_size` — circle diameter (default `24`)
- `:completed_color` — completed step color
- `:active_color` — active step color
- `:pending_color` — pending step color
- `:font` — font name

## Steps format

List of maps: `%{label: "Step name", status: :completed | :active | :pending}`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
