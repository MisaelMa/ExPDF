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

  - `:es` — 50,000 most-common Spanish words (~428 KB on disk).
    Sourced from
    [hermitdave/FrequencyWords](https://github.com/hermitdave/FrequencyWords)
    (MIT License), derived from the OpenSubtitles 2018 corpus.
    Covers everyday Spanish, technical, and legal vocabulary; some
    regional / specialised terms (e.g. Mexican-tax-specific words
    like `padrón`, `tributarios`, `federativa`, `asimilados`) are
    still missing — supplement with a custom MapSet for those.

  ## Custom dictionaries

  Callers can supply any `MapSet.t()` of lowercase strings as the
  dictionary opt — e.g. a Hunspell `.dic` file loaded into a MapSet,
  or a frequency list specific to the user's domain.

  ## Spec references

  Wordlist licensing follows the upstream MIT license — attribution is
  preserved in the project README and LICENSE.md.
  """

  @es_path Path.join([:code.priv_dir(:ex_pdf), "wordlists", "spanish.txt"])
  @es_extras_path Path.join([:code.priv_dir(:ex_pdf), "wordlists", "spanish_mx_extras.txt"])

  @external_resource @es_path
  @external_resource @es_extras_path

  # Colloquial/slang merges that show up in subtitle frequency lists
  # but should NOT be treated as single words during partition. E.g.
  # "dela" is colloquial for "de la"; if we leave it in the dict, the
  # member?(whole_token) guard in `Pdf.Reader.dictionary_split/2`
  # prevents the correct "de"+"la" split. Filter them out at compile
  # time so the partition algorithm can reach the correct decomposition.
  @es_blacklist MapSet.new(~w(dela pal))

  @es_words (
              [@es_path, @es_extras_path]
              |> Enum.flat_map(fn p ->
                p |> File.read!() |> String.split("\n", trim: true)
              end)
              |> Enum.map(&String.downcase/1)
              |> Enum.reject(&MapSet.member?(@es_blacklist, &1))
              |> MapSet.new()
            )

  @doc """
  Returns the bundled Spanish wordlist as a `MapSet` of lowercase strings.
  Loaded once at compile time via `@external_resource`.
  """
  @spec spanish() :: MapSet.t(String.t())
  def spanish, do: @es_words

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
