# `Pdf.Reader.ContentStream`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.1/lib/pdf/reader/content_stream.ex#L1)

PDF content stream interpreter for text and image extraction.

Spec reference: PDF 1.7 § 9.4 (text operators), § 8.4 (general graphics state),
§ 8.8 (XObjects), § 9.4.5 (Tf — set text font and size).

## Phase 1.1 additions

- **`font_decoders:` opt** — `%{font_name => decoder_fn}`. When provided, the
  active decoder is swapped on every `Tf` operator. After `Tf /F1 12` the
  decoder for `"F1"` is activated; subsequent `Tj`/`TJ`/`'`/`"` calls use it.
  When a font name is not in the map, the `default_decoder` (the second argument
  to `interpret/3`) is used instead.
  Spec reference: PDF 1.7 § 9.4.5 (Tf operator).

- **`Do` image event shape change** — event is now
  `{:image, %{name: name, ctm: {a, b, c, d, e, f}}}` (full 6-tuple of the CTM
  at `Do` time). The `:x` and `:y` fields (formerly present directly) are derived
  from `ctm.e` and `ctm.f` by the caller (`Pdf.Reader.extract_page_images/3`).

## Phase 1 scope

Interprets 15 operators sufficient for text and image extraction:
`BT`, `ET`, `Tf`, `Tj`, `TJ`, `'`, `"`, `Td`, `TD`, `Tm`, `T*`,
`cm`, `q`, `Q`, `Do`.

All other operators (path construction, painting, color, shading, inline images,
marked content, compatibility) are **silently consumed** — their operands are
cleared from the operand stack and execution continues. This keeps the interpreter
robust to real-world content streams without crashing.

## API

    interpret(content_binary, decoder) :: {:ok, [event]} | {:error, term}
    interpret(content_binary, decoder, opts) :: {:ok, [event]} | {:error, term}

Where `decoder :: (bytes :: binary) -> {text :: String.t(), unresolved :: list()}`.

### Options

- `:xobjects` — `%{name :: binary => {:ref, n, g} | inline_dict | :image | :form}`.
  Phase 3 (Form recursion): the recommended shape is `%{name => raw_ref}` — the
  interpreter classifies on demand by resolving the XObject and inspecting
  `/Subtype`. The legacy `:image | :form` atoms remain accepted by the public
  `interpret/3` path (which does NOT recurse into Forms) for backward-compat.
- `:font_decoders` — `%{font_name :: binary => decoder_fn}` — per-font decoder map.
  See Phase 1.1 additions above. Default: `%{}`.

## Events

- `{:text, %{text: String.t(), unresolved: list(), x: float, y: float, font: binary, size: float}}`
- `{:image, %{name: binary, ctm: {float, float, float, float, float, float}}}` — Phase 1.1
- `{:deferred, :form_xobject, name :: binary}` — emitted only on the legacy `interpret/3`
  path (no doc threaded). The recursive path in `do_interpret_with_doc/5` REPLACES
  deferred events with the actual recursed Form content.
- `{:cycle_detected, {n, g}}` — Phase 3: emitted when a Form XObject self-references
  or transitively cycles. Dropped by the reader facade's `events_to_text_runs/2`.
- `{:max_depth_exceeded, {n, g}}` — Phase 3: emitted when recursion would exceed
  `@max_form_depth` (8). Dropped by the reader facade.

## Position math

Absolute position of a glyph run start:

    M_render = Tm × CTM
    x = M_render.e, y = M_render.f

Spec: PDF 1.7 § 8.3.3 (row-vector convention), § 9.4.4 (text advance).

## Glyph advance (§ 9.4.4)

Text-matrix advance uses the full PDF § 9.4.4 formula per glyph:

    tx = ((w/1000 - Tj_kern) * Tfs + Tc + Tw_if_space) * Th

Where `w` comes from the active font's `widths_fn` closure (set by `Tf`).
Fonts without embedded `/Widths` produce `w=0`; advance is then driven
only by `Tc`/`Tw`/`Tj_kern` (documented gap for Standard-14 fonts).

Position of the START of each run is exact (derived from Tm at call time).

## Unknown operator strategy

When an unrecognized operator is encountered, the entire operand stack is cleared
(per PDF spec § 7.8.2 which states conforming readers should process what they can).
This is the same strategy used by most major PDF parsers (e.g. pdfminer-six, pdf.js).

## Spec references

- PDF 1.7 (ISO 32000-1) — Adobe free mirror:
  https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
  - § 7.8.2 — Content streams (unknown operator strategy)
  - § 8.3.3 — Coordinate Systems / Matrix Math
  - § 8.4 — General Graphics State (`q`, `Q`, `cm`)
  - § 8.8 — External Objects (`Do` operator)
  - § 8.10 — Form XObjects (recursion target)
  - § 8.10.2 — Form Dictionaries (`/Matrix`, `/BBox`, `/Resources`)
  - § 9.4 — Text Operators (BT/ET/Tf/Tj/TJ/'/"/Td/TD/Tm/T*)
  - § 9.4.4 — Text advance and Tm update
  - § 9.4.5 — Text State (Tf operator)
- Mozilla pdf.js `src/core/evaluator.js` (Apache-2.0 reference impl):
  https://github.com/mozilla/pdf.js/blob/master/src/core/evaluator.js
- pdfminer-six `pdfminer/pdfinterp.py` (MIT reference impl):
  https://github.com/pdfminer/pdfminer.six/blob/master/pdfminer/pdfinterp.py

# `decoder`

```elixir
@type decoder() :: (binary() -&gt; {String.t(), list()})
```

# `deferred_event`

```elixir
@type deferred_event() :: {:deferred, :form_xobject, binary()}
```

# `event`

```elixir
@type event() :: text_event() | image_event() | deferred_event() | guard_event()
```

# `guard_event`

```elixir
@type guard_event() ::
  {:cycle_detected, {pos_integer(), non_neg_integer()}}
  | {:max_depth_exceeded, {pos_integer(), non_neg_integer()}}
```

# `image_event`

```elixir
@type image_event() ::
  {:image,
   %{
     name: binary(),
     ctm: {float(), float(), float(), float(), float(), float()}
   }}
```

# `text_event`

```elixir
@type text_event() ::
  {:text,
   %{
     text: String.t(),
     unresolved: list(),
     x: float(),
     y: float(),
     font: nil | binary(),
     size: float()
   }}
```

# `interpret`

```elixir
@spec interpret(binary(), decoder(), keyword()) :: {:ok, [event()]} | {:error, term()}
```

Interprets a PDF content stream binary, emitting text and image events.

`decoder` is called for every string operand (Tj, TJ, etc.) and must
return `{decoded_utf8_text, unresolved_list}`.

Options:
- `:xobjects` — `%{name => :image | :form}` for `Do` operator dispatch.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
