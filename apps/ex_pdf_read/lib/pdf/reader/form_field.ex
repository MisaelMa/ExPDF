defmodule Pdf.Reader.FormField do
  @moduledoc """
  Represents a single interactive form field extracted from a PDF AcroForm.

  ## Spec references

  - PDF 1.7 (ISO 32000-1) § 12.7.4 — Field Types:
    https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
  - § 12.7.3.1 — Field Flags
  """

  @type field_type :: :text | :button | :choice | :signature | :unknown

  @type t :: %__MODULE__{
          name: String.t() | nil,
          partial_name: String.t() | nil,
          type: field_type(),
          value: term(),
          default: term(),
          tooltip: String.t() | nil,
          flags: %{atom() => boolean()},
          rect: {number(), number(), number(), number()} | nil
        }

  defstruct name: nil,
            partial_name: nil,
            type: :unknown,
            value: nil,
            default: nil,
            tooltip: nil,
            flags: %{},
            rect: nil
end
