defmodule Pdf.Reader.Line do
  @moduledoc """
  Logical text line reconstructed from individual `TextRun`s.

  Many PDFs (particularly machine-generated ones such as government
  forms and tax documents) place glyphs individually with the `TJ`
  operator and per-glyph kerning, producing one `TextRun` per character.
  Working with that flat run list is awkward — `Line` coalesces those
  runs into the structure a human reader sees: lines and, within each
  line, tokens separated by visible whitespace.

  ## Shape

  - `:page` — 1-indexed page number
  - `:y` — baseline Y of the line (PDF user-space, origin bottom-left)
  - `:x` — leftmost X of the first token on the line
  - `:text` — joined text, tokens separated by single spaces
  - `:tokens` — ordered list of `t:token/0` maps, sorted by X ascending

  Each token carries its own `:x` so callers can detect column layouts
  (e.g. table rows where every line has tokens at the same X positions).

  ## Spec references

  - PDF 1.7 § 9.4 — Text objects:
    https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
  - PDF 1.7 § 9.4.4 — Text-showing operators (Tj, TJ, ', ")
  """

  @type token_kind :: :text | :link | :email | :button | :form_field | :table_cell | atom()

  @type token :: %{
          required(:x) => float(),
          required(:text) => String.t(),
          required(:width) => float(),
          optional(:kind) => token_kind(),
          optional(:shape) => Pdf.Reader.Shape.t() | nil
        }

  @type t :: %__MODULE__{
          page: pos_integer(),
          y: float(),
          x: float(),
          text: String.t(),
          tokens: [token()]
        }

  defstruct page: 1,
            y: 0.0,
            x: 0.0,
            text: "",
            tokens: []
end
