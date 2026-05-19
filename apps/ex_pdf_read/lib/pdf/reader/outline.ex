defmodule Pdf.Reader.Outline do
  @moduledoc """
  Represents a single node in a PDF document outline (bookmark tree).

  The outline tree is a linked-list structure where each node may have
  sibling nodes (via `/Next`) and child nodes (via `/First`). This struct
  captures the resolved, tree-shaped representation after the walker has
  followed those links.

  ## Spec references

  - PDF 1.7 (ISO 32000-1) § 12.3.3 — Document Outline:
    https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
  """

  @type t :: %__MODULE__{
          title: String.t() | nil,
          level: non_neg_integer(),
          dest_page: pos_integer() | nil,
          children: [t()]
        }

  defstruct title: nil,
            level: 0,
            dest_page: nil,
            children: []
end
