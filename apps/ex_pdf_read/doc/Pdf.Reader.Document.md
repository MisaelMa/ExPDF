# `Pdf.Reader.Document`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.1/lib/pdf/reader/document.ex#L1)

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

## Recovery mode

When opened with `recover: true`, the struct carries two additional fields:

- `:recover_mode` — `true` when recovery is active; `false` (default) for strict mode.
- `:recovery_log` — a reverse-prepend accumulator of structured recovery event tuples.
  Exposed in chronological (oldest-first) order via `Pdf.Reader.recovery_log/1`.

Closed set of recovery event tuples (PDF 1.7 § 7.5, § 7.5.4, § 7.5.5, § 7.5.8):

| Tuple | Meaning |
|---|---|
| `{:xref_recovered, n}` | Linear scan recovered `n` object entries (§ 7.5.4, § 7.5.8) |
| `{:eof_marker_missing, :linear_scan_used}` | `%%EOF` absent; linear scan was invoked (§ 7.5.5) |
| `{:page_failed, page_n_or_ref, reason}` | A page was skipped. `page_n_or_ref` is either a `non_neg_integer()` page index OR a `{n, g}` ref-key tuple (used when iteration happens by `/Kids` ref before pages are indexed); `reason` is an atom or term |
| `{:font_skipped, page_n, font_name, reason}` | Font replaced with U+FFFD fallback |
| `{:page_tree_recovered, n}` | Catalog/Pages fallback found `n` page objects |

## Spec references

- PDF 1.7 § 7.5 — PDF file structure
- PDF 1.7 § 7.5.4 — Cross-reference table
- PDF 1.7 § 7.5.5 — File trailer
- PDF 1.7 § 7.5.8 — Cross-reference streams

# `encryption_context`

```elixir
@type encryption_context() :: %Pdf.Reader.Encryption.StandardHandler{
  cf: term(),
  encrypt_metadata: term(),
  file_key: term(),
  filter: term(),
  id: term(),
  length: term(),
  o: term(),
  oe: term(),
  p: term(),
  perms: term(),
  revision: term(),
  stm_filter: term(),
  str_filter: term(),
  u: term(),
  ue: term(),
  version: term()
}
```

# `recovery_event`

```elixir
@type recovery_event() ::
  {:eof_marker_missing, atom()}
  | {:xref_recovered, non_neg_integer()}
  | {:page_tree_recovered, non_neg_integer()}
  | {:page_failed, non_neg_integer() | {pos_integer(), non_neg_integer()},
     term()}
  | {:font_skipped, non_neg_integer(), binary(), term()}
```

# `ref`

```elixir
@type ref() :: {pos_integer(), non_neg_integer()}
```

# `t`

```elixir
@type t() :: %Pdf.Reader.Document{
  binary: binary(),
  cache: %{required(ref()) =&gt; term()},
  encryption: encryption_context() | nil,
  page_refs: [ref()] | nil,
  recover_mode: boolean(),
  recovery_log: [recovery_event()],
  trailer: map(),
  version: String.t(),
  xref: %{required(ref()) =&gt; xref_entry()}
}
```

# `xref_entry`

```elixir
@type xref_entry() ::
  {:in_use, offset :: non_neg_integer(), gen :: non_neg_integer()}
  | {:compressed, objstm_obj :: pos_integer(), index :: non_neg_integer()}
  | :free
```

# `log_recovery`

```elixir
@spec log_recovery(t(), recovery_event()) :: t()
```

Appends a recovery event to the document's internal log (reverse-prepend).

This is the single chokepoint for all recovery event recording.
Callers retrieve events in chronological order via `Pdf.Reader.recovery_log/1`,
which calls `Enum.reverse/1` on the internal accumulator.

## Spec reference

PDF 1.7 § 7.5 — PDF file structure (recovery model).

---

*Consult [api-reference.md](api-reference.md) for complete listing*
