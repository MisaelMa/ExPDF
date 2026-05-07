defmodule Pdf.Reader.Document do
  @moduledoc """
  Struct representing an open PDF document in the reader.

  Holds the full PDF binary, the merged cross-reference table, the most-recent
  trailer dictionary, a lazy object-resolution cache, and memoized page refs.

  The struct is immutable — every `Pdf.Reader.*` function that resolves objects
  returns an updated copy with a warmer cache. Dropping the updated copy is safe
  (correctness is preserved) but re-resolving the same object will incur a
  re-parse. Thread the returned doc forward for performance.

  Callers do not construct `Document` directly; obtain one via `Pdf.Reader.open/1`.

  ## Cache key conventions

  The `:cache` field is a plain `%{}` map. Keys used by reader subsystems:

  - `{n, g}` — resolved object with xref ref `(n, g)` (used by `ObjectResolver`)
  - `{:font_decoder, {n, g}}` — cached decoder closure for the font at ref `(n, g)`,
    built by `Pdf.Reader.Font.build_decoder/2`. Present only for fonts accessed via
    an indirect reference. Inline font dicts (embedded literally in a resources dict)
    are NOT cached — they are rebuilt on every call.
  - `{:page_resources, {n, g}}` — resolved `/Resources` map for the leaf page at
    ref `(n, g)`. Written by `Pdf.Reader.resolve_page_resources/4` after the first
    `/Parent`-chain walk for a given page. Subsequent calls for the same page ref
    short-circuit the walk and return the cached map directly. Intermediate ancestor
    nodes are NOT cached — only the leaf page ref is used as the key.
  """

  @type ref :: {pos_integer(), non_neg_integer()}

  @type xref_entry ::
          {:in_use, offset :: non_neg_integer(), gen :: non_neg_integer()}
          | {:compressed, objstm_obj :: pos_integer(), index :: non_neg_integer()}
          | :free

  @type encryption_context :: %Pdf.Reader.Encryption.StandardHandler{}

  @type t :: %__MODULE__{
          binary: binary(),
          version: String.t(),
          xref: %{ref() => xref_entry()},
          trailer: map(),
          cache: %{ref() => term()},
          page_refs: [ref()] | nil,
          encryption: encryption_context() | nil
        }

  defstruct binary: <<>>,
            version: "1.0",
            xref: %{},
            trailer: %{},
            cache: %{},
            page_refs: nil,
            encryption: nil
end
