# ExPDF

[![Hex.pm](https://img.shields.io/hexpm/v/ex_pdf.svg)](https://hex.pm/packages/ex_pdf)
[![Documentation](https://img.shields.io/badge/docs-hexdocs-blue)](https://hexdocs.pm/ex_pdf)
[![License](https://img.shields.io/hexpm/l/ex_pdf.svg)](LICENSE.md)

Native Elixir PDF **reader** and **writer** — writes PDFs from declarative
page descriptions and reads PDFs (text with positions, layout, links,
images, metadata, encryption, AcroForm fields, outlines, annotations)
using the Erlang/OTP standard library only. **No Hex runtime
dependencies, no system tools.**

## Origin

ExPDF is a fork of [`andrewtimberlake/elixir-pdf`](https://github.com/andrewtimberlake/elixir-pdf)
(Hex package `:pdf`, ©Andrew Timberlake, MIT). The original library is
a writer-only PDF generator. This fork keeps the full writer API
unchanged and **adds a native PDF reader** plus several quality-of-life
improvements. See `CHANGELOG.md` for the complete list. Original
authorship is preserved in the contributors list.

## Installation

Add `ex_pdf` to your `mix.exs`:

```elixir
def deps do
  [
    {:ex_pdf, "~> 1.0"}
  ]
end
```

## Reading PDFs

```elixir
{:ok, doc} = Pdf.Reader.open("invoice.pdf")
{:ok, %Pdf.Reader.Result{} = result, _doc} = Pdf.Reader.read(doc)

# Document-level metadata (PDF 1.7 § 14.3)
result.meta.title           # "Invoice 042"
result.meta.author          # "Acme Corp"
result.meta.producer        # "LibreOffice 7.5"
result.meta.page_count      # 3
result.meta.version         # "1.7"
result.meta.encrypted       # false
result.meta.recovery_log    # []
result.meta.raw             # full Info-dict + XMP merge

# Per-page lines with kind-tagged tokens
for page <- result.pages do
  for line <- page.lines, token <- line.tokens do
    case token.kind do
      :text  -> IO.puts(token.text)
      :link  -> IO.puts("LINK → #{token.shape.target}")
      :email -> IO.puts("EMAIL → #{token.shape.target}")
      :image -> IO.puts("IMG #{inspect(token.shape.rect)}")
    end
  end
end
```

### Convenience shapes

```elixir
{:ok, pages, _} = Pdf.Reader.read(doc, shape: :text)    # [String.t()] per page
{:ok, shapes, _} = Pdf.Reader.read(doc, shape: :shapes) # [%Shape{}] flat
```

### Token enrichment

Every token in `result.pages[*].lines[*].tokens` carries:

| Field | Type | Description |
|-------|------|-------------|
| `:x` | `float` | Absolute X in PDF user space |
| `:text` | `String.t()` | Token text |
| `:width` | `float` | Render width |
| `:kind` | `:text \| :link \| :email \| :image` | Discriminator |
| `:shape` | `%Pdf.Reader.Shape{} \| nil` | Type-specific payload |

Link/email tokens get a populated `:shape` whose `:target` carries the
URI/email. Image tokens get a `:shape` with `meta.data_uri` (a
`data:image/png;base64,…` or `data:image/jpeg;base64,…` string ready
for HTML embedding) and `meta.format`, `meta.width`, `meta.height`,
`meta.byte_size`. The raw `:bytes` are off by default — pass
`image_bytes: true` to include them.

### Error recovery

```elixir
# Lenient mode for malformed PDFs (PDF 1.7 § 7.5)
{:ok, doc} = Pdf.Reader.open(broken_bin, recover: true)
{:ok, _result, doc} = Pdf.Reader.read(doc)
Pdf.Reader.recovery_log(doc)
# => [{:xref_recovered, 42}, {:page_failed, 3, _reason}, ...]
```

The reader can recover from corrupted xref tables (linear scan), missing
`%%EOF` markers, broken page-tree links, dangling font refs, and
truncated streams. Fatal errors (`:not_a_pdf`, encryption-without-password)
remain hard errors.

### Dictionary-based word split

Some PDFs emit consecutive words with no whitespace glyph and no case
transition (e.g. `iniciode` instead of `inicio de`). With a wordlist
the reader can recover those boundaries:

```elixir
# Bundled top-10k Spanish frequency list (MIT, ~80KB)
{:ok, result, _} = Pdf.Reader.read(doc, dictionary: :es)

# Or a custom wordlist
my_words = MapSet.new(File.stream!("my_dict.txt") |> Enum.map(&String.trim/1))
{:ok, result, _} = Pdf.Reader.read(doc, dictionary: my_words)

# Combine the bundled dict with project-specific terms
my_dict =
  Pdf.Reader.Wordlist.spanish()
  |> MapSet.union(MapSet.new(["padrón", "fiscales", "tributarios"]))

{:ok, result, _} = Pdf.Reader.read(doc, dictionary: my_dict)
```

The split is conservative: a token is split only when (a) BOTH halves
are dictionary words AND (b) the whole token is NOT itself a dictionary
word — so `personales`, `desea`, `desde`, `queja` stay intact. URLs,
emails, identifiers, and base64 hashes are exempted.

The bundled `:es` dictionary is built from two wordlists merged at
compile time:

1. **`priv/wordlists/spanish.txt`** — 50,000 entries (~428 KB) from
   [hermitdave/FrequencyWords](https://github.com/hermitdave/FrequencyWords)
   (MIT License, © Hermit Dave), derived from OpenSubtitles 2018.
   Covers conversational, technical, and legal Spanish.
2. **`priv/wordlists/spanish_mx_extras.txt`** — ~700 Mexican
   tax/legal/government terms curated for this project (MIT). Includes
   `padrón`, `tributarios`, `federativa`, `asimilados`, `lineamientos`,
   `contribuyente`, `recaudación`, etc. — terms missing from the
   subtitle-derived corpus.

A small blacklist (`dela`, `pal`) removes slang merges that would
prevent correct splitting (e.g. "de la" → "dela" then back to
"de la"). Final size: ~50,500 unique entries loaded into a `MapSet`
at compile time.

### Tokenization rules

The dict-split applies four passes (in order):

1. **Label-colon split**: `Postal:77710` → `Postal:` + `77710` (URLs/emails exempted).
2. **Letter↔digit boundary**: `1Asalariado` → `1` + `Asalariado` (RFC/CURP shapes and base64 exempted).
3. **CamelCase split**: `delMunicipio` → `del Municipio` (acronyms and digits exempted).
4. **Dictionary partition** (when `:dictionary` set): full decomposition
   into dict words. Validity rules:
   - Every piece is ≥ 4 chars OR in the closed connector list
     (`de el la en si son del las los una uno con por sus que fin
     mes año día`) plus 1-char connectors (`y o a e u`).
   - At least one piece must be ≥ 4 chars (anchor) — unless every
     piece is a short connector (catches `dela` → `de`+`la`).
   - 2-piece partitions starting with a capitalized 2-3 char piece
     are rejected (avoids `Demarcación` → `De`+`marcación`).

When multiple valid partitions exist, the algorithm picks the one
with the longest first piece for long tokens (≥ 15 chars) or the
fewest 1-char pieces for short tokens. Recursion processes embedded
punctuation: `¡denúnciala!Si...` → `¡denúnciala!` + `Si conoces ...`.

### Encryption

```elixir
{:ok, doc} = Pdf.Reader.open("encrypted.pdf", password: "secret")
```

Standard Security Handler V1/V2/V4 (RC4-40, RC4-128, AES-128) and
V5/R6 (AES-256) per PDF 1.7 § 7.6 / PDF 2.0 § 7.6. Empty password is
auto-tried first.

### CID fonts

Forty predefined CMaps from the Adobe `cmap-resources` collection are
bundled in `priv/cmap/` (Identity-H/V, UniJIS, GB, KSC, GBK, ETen, …).
Combined with the Adobe Japan1/CNS1/Korea1/GB1 collections, the reader
decodes the vast majority of multi-byte CID fonts found in real-world
PDFs. ToUnicode CMaps are parsed for the remainder.

## Writing PDFs

The writer API from the upstream `elixir-pdf` is preserved unchanged:

```elixir
Pdf.build([size: :a4, compress: true], fn pdf ->
  pdf
  |> Pdf.set_font("Helvetica", 12)
  |> Pdf.text_at({200, 200}, "Hello, world!")
  |> Pdf.add_image({100, 100}, "logo.png")
end)
|> Pdf.export()
```

See [`extra_doc/Tables.md`](extra_doc/Tables.md) for the styled-table
DSL and additional layout helpers.

## Specifications followed

The reader cites the relevant section in every module's `@moduledoc`:

- **PDF 1.7 (ISO 32000-1)**: structure (§7), graphics (§8), text (§9),
  fonts (§9.6 / §9.7), images (§8.9), encryption (§7.6), page tree
  (§7.7), annotations (§12.5), outlines (§12.3), forms (§12.7),
  metadata (§14.3).
- **PDF 2.0 (ISO 32000-2)**: V5/R6 standard security handler.
- **RFC 3986** — URI generic syntax (inferred URLs).
- **RFC 5321 § 4.1.2** — SMTP mailbox/domain (inferred emails).
- **RFC 2397** — `data:` URI scheme (image embedding).
- **PNG 1.2** — chunk format for re-encoding decompressed pixel data.
- **Adobe Glyph List** — bundled at compile time for encoding cascade.

## Documented gaps

The reader is intentionally pragmatic. The following items are not
implemented and surface as best-effort defaults or no-ops:

- Standard 14 hardcoded font metrics — width fallback is 500 units
  (~0.5 em); exact column alignment requires AFM bundling.
- Vertical writing mode (`/W2`, `/DW2`) — horizontal layout assumed.
- Non-default `/FontMatrix` scaling on CIDType2 fonts.
- OCR for scanned PDFs — empty text output for image-only pages.
- CCITTFaxDecode / JBIG2Decode / JPXDecode image filters — surface as
  `{:error, {:unsupported_filter, name}}`.
- Encrypted-AND-corrupted PDFs — recovery cannot synthesise `/Encrypt`.

## Releasing

This project uses [`releaser`](https://hexdocs.pm/releaser/0.0.7) for
version bumping, changelog generation, and Hex publishing.

```bash
mix releaser.bump ex_pdf patch     # 1.0.1 → 1.0.2
mix releaser.bump ex_pdf minor     # 1.0.1 → 1.1.0
mix releaser.bump ex_pdf major     # 1.0.1 → 2.0.0
mix releaser.publish               # publish to Hex
```

## License

MIT. See `LICENSE.md`. Original code © Andrew Timberlake; reader and
post-fork additions © Misael Sánchez. Both portions remain MIT.
