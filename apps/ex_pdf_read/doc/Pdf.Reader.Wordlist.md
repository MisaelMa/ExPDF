# `Pdf.Reader.Wordlist`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.2/lib/pdf/reader/wordlist.ex#L1)

Compile-time dictionaries used by `Pdf.Reader.read/2` to recover word
boundaries that the PDF producer collapsed (e.g. `iniciode` →
`inicio` + `de`).

Lookup is performed against a `MapSet` of lowercase words. Membership
checks are case-insensitive — the input is downcased before the
`MapSet` query, so `"De"`, `"DE"`, and `"de"` all match a stored
`"de"` entry.

## Bundled dictionaries

The `:es` dictionary is built from TWO bundled wordlists merged at
compile time:

### 1. `priv/wordlists/spanish.txt` (50,000 entries, ~428 KB)
The 50,000 most-frequent Spanish words from the
[hermitdave/FrequencyWords](https://github.com/hermitdave/FrequencyWords)
project (MIT License, © Hermit Dave), derived from the
OpenSubtitles 2018 corpus. Covers conversational, technical, and
legal Spanish vocabulary. Format: one lowercase word per line (the
upstream repo also includes per-word frequencies; we strip those
and keep the words only).

### 2. `priv/wordlists/spanish_mx_extras.txt` (~700 entries)
Mexican tax/legal/government vocabulary curated specifically for
this project, covering terms that are missing from the
subtitle-derived 50k list. This includes:

- SAT (Servicio de Administración Tributaria) terminology:
  `padrón`, `tributario`/`tributarios`, `federativa`, `asimilado`,
  `lineamientos`, `contribuyente`, `recaudación`, `fiscalización`,
  `gravable`, `deducible`, etc.
- Common labour / employment terms: `asalariado`, `honorario`,
  `arrendamiento`, `prestación`, `salario`/`sueldo` variants.
- Document/process terms: `constancia`, `cédula`, `expedición`,
  `notarial`, `apoderado`, `domiciliado`, etc.
- Adverbs and verb conjugations not in the base list:
  `inmediatamente`, `posteriormente`, `denúnciala`, `conferidas`,
  `corresponda`, etc.
- Common periodicity words: `mensual`, `trimestral`, `bimestral`,
  `quincenal`, etc.

Released under the same MIT License as the rest of the project.

### Filtering

A small `@es_blacklist` removes colloquial/slang merges that show
up in subtitle frequency lists but harm partition splitting (e.g.
`dela` is colloquial for "de la"; if left in the dict the
whole-token guard would prevent the correct "de" + "la" split).
Currently blacklisted: `dela`, `pal`.

### Final size
~50,500 unique entries after merge and blacklist filter. Loaded
into a `MapSet` at compile time via `@external_resource` so there
is zero IO cost at runtime.

## Custom dictionaries

Callers can supply any `MapSet.t()` of lowercase strings as the
dictionary opt — e.g. a Hunspell `.dic` file loaded into a MapSet,
or a frequency list specific to the user's domain.

## Spec references

Wordlist licensing follows the upstream MIT license — attribution is
preserved in the project README and LICENSE.md.

# `member?`

```elixir
@spec member?(String.t(), MapSet.t() | nil) :: boolean()
```

Case-insensitive membership check.

# `resolve`

```elixir
@spec resolve(:es | MapSet.t() | nil) :: MapSet.t() | nil
```

Resolves a dictionary specifier to a `MapSet`.

- `:es` → bundled Spanish wordlist
- `%MapSet{}` → returned as-is
- `nil` → returned as-is (caller should treat as "no dictionary")

# `spanish`

```elixir
@spec spanish() :: MapSet.t(String.t())
```

Returns the bundled Spanish wordlist as a `MapSet` of lowercase
strings.

**Lazy-loaded** — the wordlist files are only read from `priv/` the
first time this function is called. Result is cached in
`:persistent_term` so subsequent calls are O(1). Callers who never
pass `dictionary: :es` to `Pdf.Reader.read/2` never touch the disk
and don't pay the ~50 ms one-time load cost.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
