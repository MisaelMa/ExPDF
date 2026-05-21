defmodule Pdf.Reader.TextRun do
  @moduledoc """
  Struct representing a single text run extracted from a PDF page.

  A text run corresponds to one `Tj` or `TJ` operator in the page's content
  stream. Coordinates `(x, y)` are absolute user-space points computed by
  multiplying the current text matrix by the current transformation matrix.

  `:text` is always a valid UTF-8 `String.t()`. Glyphs that could not be
  resolved to a Unicode codepoint are substituted with `U+FFFD` (REPLACEMENT
  CHARACTER) and their original glyph information is recorded in `:unresolved`.

  `:unresolved` is empty (`[]`) on the happy path. Each entry is a
  `{codepoint_index, glyph_name}` pair locating the substitution within
  `:text`.
  """

  @type t :: %__MODULE__{
          text: String.t(),
          unresolved: [{non_neg_integer(), binary()}],
          x: float(),
          y: float(),
          font: nil | binary(),
          size: float(),
          page: pos_integer()
        }

  defstruct text: "",
            unresolved: [],
            x: 0.0,
            y: 0.0,
            font: nil,
            size: 0.0,
            page: 1
end
