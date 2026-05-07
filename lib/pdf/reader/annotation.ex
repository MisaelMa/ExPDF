defmodule Pdf.Reader.Annotation do
  @moduledoc """
  Represents a single annotation extracted from a PDF page.

  Annotations are page-attached objects that can represent comments, links,
  highlights, file attachments, and many other interactive or markup elements.

  This struct captures the common fields shared by all annotation subtypes plus
  a `:kind_specific` map for subtype-specific data (e.g. `:quad_points` for
  highlight/underline annotations).

  ## Spec references

  - PDF 1.7 (ISO 32000-1) § 12.5 — Annotations:
    https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
  - PDF 1.7 § 12.5.6.x — Annotation types (Link, Text, Highlight, Underline,
    StrikeOut, Squiggly, Square, Circle, FreeText, FileAttachment)
  """

  @type type ::
          :link
          | :text
          | :highlight
          | :underline
          | :strikeout
          | :squiggly
          | :square
          | :circle
          | :freetext
          | :file_attachment
          | :unknown

  @type t :: %__MODULE__{
          type: type(),
          page: pos_integer() | nil,
          rect: {number(), number(), number(), number()} | nil,
          contents: String.t() | nil,
          title: String.t() | nil,
          subject: String.t() | nil,
          created: String.t() | nil,
          modified: String.t() | nil,
          dest_page: pos_integer() | nil,
          url: String.t() | nil,
          embedded_file_ref: {pos_integer(), non_neg_integer()} | nil,
          kind_specific: map()
        }

  defstruct type: :unknown,
            page: nil,
            rect: nil,
            contents: nil,
            title: nil,
            subject: nil,
            created: nil,
            modified: nil,
            dest_page: nil,
            url: nil,
            embedded_file_ref: nil,
            kind_specific: %{}
end
