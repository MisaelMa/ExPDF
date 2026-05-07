defmodule Pdf.Reader.CID.PredefinedCMap do
  @moduledoc """
  Lazy loader and lookup for Adobe predefined CMaps bundled in `priv/cmap/`.

  Parses on first use via `Pdf.Reader.CID.CMapParser`, caches the result in
  `Document.cache` keyed `{:predefined_cmap, name}`. Handles `usecmap` chains
  recursively with a visited MapSet to prevent cycles. Missing or non-bundled
  parents fall back to an empty CMap per discovery #182 (the UCS2 abstract parent
  files do not exist in the upstream repo).

  ## Merge semantics

  Child mappings override parent mappings:
  - `cidchar` — `Map.merge(parent, child)` (child wins on collision)
  - `cidrange` — child list prepended to parent list (child scanned first)
  - `codespaces` — unioned; child entries prepended per byte-length

  ## Spec references

  - PDF 1.7 (ISO 32000-1) § 9.7.5 — Predefined CMaps:
    https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
  - PDF 1.7 § 9.7.6 — Codespace ranges and tokenization:
    https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
  - Adobe Tech Note #5099 — CMap and CIDFont Files Specification:
    https://adobe-type-tools.github.io/font-tech-notes/pdfs/5099.CMapResources.pdf
  - Adobe Tech Note #5014 — CID-Keyed Font Technology Overview:
    https://adobe-type-tools.github.io/font-tech-notes/pdfs/5014.CIDFont_Spec.pdf
  """

  alias Pdf.Reader.CID.CMapParser
  alias Pdf.Reader.Document

  # 40 bundled file names from priv/cmap/
  @bundled MapSet.new(~w[
    UniJIS-UTF16-H UniJIS-UTF16-V UniJIS-UCS2-H UniJIS-UCS2-V
    UniCNS-UTF16-H UniCNS-UTF16-V UniCNS-UCS2-H UniCNS-UCS2-V
    UniGB-UTF16-H UniGB-UTF16-V UniGB-UCS2-H UniGB-UCS2-V
    UniKS-UTF16-H UniKS-UTF16-V UniKS-UCS2-H UniKS-UCS2-V
    GBK-EUC-H GBK-EUC-V GBKp-EUC-H GBKp-EUC-V GBK2K-H GBK2K-V
    ETen-B5-H ETen-B5-V
    KSCms-UHC-H KSCms-UHC-V
    90ms-RKSJ-H 90ms-RKSJ-V 90msp-RKSJ-H 90msp-RKSJ-V
    EUC-H EUC-V
    B5-H B5-V
    GB-H GB-V
    ETenms-B5-H ETenms-B5-V
    KSCms-UHC-HW-H KSCms-UHC-HW-V
  ])

  @doc """
  Returns `true` if `name` is one of the 40 bundled predefined CMap names.
  This is an O(1) MapSet lookup — no I/O at call time.
  """
  @spec bundled?(String.t()) :: boolean()
  def bundled?(name), do: MapSet.member?(@bundled, name)

  @doc """
  Load a predefined CMap by name, using `doc.cache` as a parse cache.

  On the first call for a given name, reads `priv/cmap/<name>`, parses it via
  `CMapParser.parse/1`, resolves the `usecmap` parent chain (if any), merges
  parent + child (child overrides), and stores the merged result in
  `doc.cache[{:predefined_cmap, name}]`.

  Subsequent calls for the same name with a doc that already holds the cached
  result return immediately without re-parsing.

  Returns:
  - `{:ok, cmap_map, updated_doc}` on success
  - `{:error, {:not_bundled, name}}` if `name` is not in the bundle
  - `{:error, :cycle}` if a cyclic `usecmap` chain is detected
  """
  @spec load_by_name(String.t(), Document.t()) ::
          {:ok, map(), Document.t()} | {:error, term()}
  def load_by_name(name, doc) do
    case Map.get(doc.cache, {:predefined_cmap, name}) do
      nil -> parse_and_cache(name, doc, MapSet.new())
      cached -> {:ok, cached, doc}
    end
  end

  # ---------------------------------------------------------------------------
  # Internal — recursive parse with cycle detection
  # ---------------------------------------------------------------------------

  defp parse_and_cache(name, doc, visited) do
    if MapSet.member?(visited, name) do
      {:error, :cycle}
    else
      with {:ok, text} <- read_priv_file(name),
           {:ok, parsed} <- CMapParser.parse(text),
           {:ok, base, doc1} <- maybe_load_parent(parsed, doc, MapSet.put(visited, name)) do
        merged = merge(base, parsed)
        doc2 = %{doc1 | cache: Map.put(doc1.cache, {:predefined_cmap, name}, merged)}
        {:ok, merged, doc2}
      end
    end
  end

  defp read_priv_file(name) do
    if bundled?(name) do
      path = Path.join([:code.priv_dir(:ex_pdf), "cmap", name])

      case File.read(path) do
        {:ok, text} -> {:ok, text}
        {:error, _} -> {:error, {:not_found, name}}
      end
    else
      {:error, {:not_bundled, name}}
    end
  end

  defp maybe_load_parent(%{parent: nil}, doc, _visited), do: {:ok, empty_cmap(), doc}

  defp maybe_load_parent(%{parent: parent_name}, doc, visited) do
    case parse_and_cache(parent_name, doc, visited) do
      {:ok, parent, doc1} ->
        {:ok, parent, doc1}

      # Missing parent (e.g. Adobe-Japan1-UCS2) → fall back to empty (discovery #182)
      {:error, {:not_bundled, _}} ->
        {:ok, empty_cmap(), doc}

      {:error, {:not_found, _}} ->
        {:ok, empty_cmap(), doc}

      {:error, :cycle} = err ->
        err
    end
  end

  defp empty_cmap do
    %{
      cidchar: %{},
      cidrange: [],
      notdef_chars: %{},
      notdef_ranges: [],
      codespaces: %{},
      parent: nil
    }
  end

  # Merge parent + child; child overrides parent
  defp merge(parent, child) do
    %{
      # child wins on key collision
      cidchar: Map.merge(parent.cidchar, child.cidchar),
      # child list first → child wins on range scan
      cidrange: child.cidrange ++ parent.cidrange,
      notdef_chars: Map.merge(parent.notdef_chars, child.notdef_chars),
      notdef_ranges: child.notdef_ranges ++ parent.notdef_ranges,
      codespaces: merge_codespaces(parent.codespaces, child.codespaces),
      # already merged; clear parent reference
      parent: nil
    }
  end

  defp merge_codespaces(parent, child) do
    Map.merge(parent, child, fn _k, p, c -> c ++ p end)
  end

  # ---------------------------------------------------------------------------
  # Lookup
  # ---------------------------------------------------------------------------

  @doc """
  Look up `code` in a merged predefined CMap (as returned by `load_by_name/2`).

  Resolution order (per PDF 1.7 § 9.7.5):
  1. `cidchar` exact match
  2. `cidrange` list scan (first matching range wins)
  3. `notdef_chars` exact match
  4. `notdef_ranges` list scan
  5. `:error` — code not in any mapping

  Returns `{:ok, cid}` or `:error`.
  """
  @spec lookup(map(), non_neg_integer()) :: {:ok, non_neg_integer()} | :error
  def lookup(cmap, code) do
    cond do
      Map.has_key?(cmap.cidchar, code) ->
        {:ok, Map.fetch!(cmap.cidchar, code)}

      (cid = match_range(cmap.cidrange, code)) != nil ->
        {:ok, cid}

      Map.has_key?(cmap.notdef_chars, code) ->
        {:ok, Map.fetch!(cmap.notdef_chars, code)}

      (cid = match_range(cmap.notdef_ranges, code)) != nil ->
        {:ok, cid}

      true ->
        :error
    end
  end

  defp match_range([], _code), do: nil

  defp match_range([{lo, hi, base} | rest], code) do
    if code >= lo and code <= hi do
      base + (code - lo)
    else
      match_range(rest, code)
    end
  end
end
