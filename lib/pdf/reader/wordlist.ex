defmodule Pdf.Reader.Wordlist do
  @moduledoc """
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
  """

  @es_filename "spanish.txt"
  @es_extras_filename "spanish_mx_extras.txt"

  # Colloquial/slang merges that show up in subtitle frequency lists
  # but should NOT be treated as single words during partition. E.g.
  # "dela" is colloquial for "de la"; if we leave it in the dict, the
  # member?(whole_token) guard in `Pdf.Reader.dictionary_split/2`
  # prevents the correct "de"+"la" split. Filter them out before
  # building the MapSet so the partition algorithm can reach the
  # correct decomposition.
  @es_blacklist MapSet.new(~w(dela pal))

  @doc """
  Returns the bundled Spanish wordlist as a `MapSet` of lowercase
  strings.

  **Lazy-loaded** — the wordlist files are only read from `priv/` the
  first time this function is called. Result is cached in
  `:persistent_term` so subsequent calls are O(1). Callers who never
  pass `dictionary: :es` to `Pdf.Reader.read/2` never touch the disk
  and don't pay the ~50 ms one-time load cost.
  """
  @spec spanish() :: MapSet.t(String.t())
  def spanish do
    case :persistent_term.get({__MODULE__, :spanish}, nil) do
      nil ->
        ms = load_spanish()
        :persistent_term.put({__MODULE__, :spanish}, ms)
        ms

      cached ->
        cached
    end
  end

  defp load_spanish do
    priv = :code.priv_dir(:ex_pdf)

    [Path.join([priv, "wordlists", @es_filename]), Path.join([priv, "wordlists", @es_extras_filename])]
    |> Enum.flat_map(&load_lines/1)
    |> Enum.map(&String.downcase/1)
    |> Enum.reject(&MapSet.member?(@es_blacklist, &1))
    |> MapSet.new()
  end

  defp load_lines(path) do
    case File.read(path) do
      {:ok, content} -> String.split(content, "\n", trim: true)
      {:error, _} -> []
    end
  end

  @doc """
  Resolves a dictionary specifier to a `MapSet`.

  - `:es` → bundled Spanish wordlist
  - `%MapSet{}` → returned as-is
  - `nil` → returned as-is (caller should treat as "no dictionary")
  """
  @spec resolve(:es | MapSet.t() | nil) :: MapSet.t() | nil
  def resolve(:es), do: spanish()
  def resolve(%MapSet{} = ms), do: ms
  def resolve(nil), do: nil

  @doc """
  Case-insensitive membership check.
  """
  @spec member?(String.t(), MapSet.t() | nil) :: boolean()
  def member?(_word, nil), do: false
  def member?(word, %MapSet{} = ms), do: MapSet.member?(ms, String.downcase(word))
end
