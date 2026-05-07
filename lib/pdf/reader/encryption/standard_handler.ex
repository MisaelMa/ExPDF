defmodule Pdf.Reader.Encryption.StandardHandler do
  @moduledoc """
  Parses the PDF `/Encrypt` dictionary into a `%StandardHandler{}` struct.

  Supports Standard Security Handler revisions R=2 (V=1), R=3 (V=2), R=4 (V=4,
  Crypt Filters + AES-128), and R=6 (V=5, AES-256, PDF 2.0).  Any other
  `/Filter` value returns `{:error, :encrypted_unsupported_handler}`.

  This module is a pure data-extraction layer.  It does NOT:
  - Validate `/O` or `/U` password hashes.
  - Derive the file encryption key.
  - Perform any cryptographic operations.

  Those operations are handled by `Pdf.Reader.Encryption.V1V2`,
  `Pdf.Reader.Encryption.V4`, and `Pdf.Reader.Encryption.V5`.

  ## SecurityHandler struct fields

  | Field              | Source                        | Default      |
  |--------------------|-------------------------------|--------------|
  | `:version`         | `/V`                          | `nil`        |
  | `:revision`        | `/R`                          | `nil`        |
  | `:length`          | `/Length`                     | `nil`        |
  | `:o`               | `/O` (raw bytes, unwrapped)   | `nil`        |
  | `:u`               | `/U` (raw bytes, unwrapped)   | `nil`        |
  | `:oe`              | `/OE` (V5 only)               | `nil`        |
  | `:ue`              | `/UE` (V5 only)               | `nil`        |
  | `:perms`           | `/Perms` (V5 only, 16 bytes)  | `nil`        |
  | `:p`               | `/P` (32-bit signed integer)  | `nil`        |
  | `:cf`              | `/CF` sub-dict (V4/V5)        | `%{}`        |
  | `:stm_filter`      | `/StmF` name (V4/V5)          | `nil`        |
  | `:str_filter`      | `/StrF` name (V4/V5)          | `nil`        |
  | `:encrypt_metadata`| `/EncryptMetadata` (V4+)      | `true`       |
  | `:filter`          | `/Filter` name string         | `nil`        |
  | `:file_key`        | populated after authentication | `nil`        |
  | `:id`              | `/ID[0]` from trailer         | `nil`        |

  ## Spec references
  - PDF 1.7 (ISO 32000-1) § 7.6.3.1 — Standard Security Handler:
    https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
  - PDF 1.7 § 7.6.3.3 — Encryption Key Algorithm (R=2/3/4):
    https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
  - PDF 2.0 (ISO 32000-2) § 7.6.4 — Standard Security Handler (R=6, V=5):
    https://www.pdfa.org/wp-content/uploads/2023/04/ISO_32000_2_2020_PDF_2.0_FDIS.pdf
  - Mozilla pdf.js src/core/crypto.js (Apache-2.0 reference implementation):
    https://github.com/mozilla/pdf.js/blob/master/src/core/crypto.js
  """

  # ---------------------------------------------------------------------------
  # Struct
  # ---------------------------------------------------------------------------

  @type t :: %__MODULE__{
          version: 1 | 2 | 4 | 5 | nil,
          revision: 2 | 3 | 4 | 6 | nil,
          length: non_neg_integer() | nil,
          o: binary() | nil,
          u: binary() | nil,
          oe: binary() | nil,
          ue: binary() | nil,
          perms: binary() | nil,
          p: integer() | nil,
          cf: %{String.t() => map()},
          stm_filter: String.t() | nil,
          str_filter: String.t() | nil,
          encrypt_metadata: boolean(),
          filter: String.t() | nil,
          file_key: binary() | nil,
          id: binary() | nil
        }

  defstruct version: nil,
            revision: nil,
            length: nil,
            o: nil,
            u: nil,
            oe: nil,
            ue: nil,
            perms: nil,
            p: nil,
            cf: %{},
            stm_filter: nil,
            str_filter: nil,
            encrypt_metadata: true,
            filter: nil,
            file_key: nil,
            id: nil

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Parses an Encrypt dict map (as returned by `Pdf.Reader.Parser`) into a
  `%StandardHandler{}` struct.

  ## Parameters

  - `encrypt_dict` — a plain `%{}` map where values follow Parser tagging
    conventions: integers as integers, names as `{:name, string}`, byte strings
    as `{:string, binary}` or `{:hex_string, binary}`, booleans as booleans,
    sub-dicts as plain maps.
  - `doc_id` — the raw binary of `/ID[0]` from the document trailer.  Stored on
    the struct as `:id` for use by key-derivation modules.

  ## Returns

  - `{:ok, %StandardHandler{}}` — for `/Filter /Standard` dicts.
  - `{:error, :encrypted_unsupported_handler}` — for any other `/Filter` value,
    or when `/Filter` is absent.

  Note: the `:file_key` field is always `nil` on return.  Authentication and
  key derivation are handled by V1V2/V4/V5 modules.
  """
  @spec parse(map(), binary()) :: {:ok, t()} | {:error, :encrypted_unsupported_handler}
  def parse(encrypt_dict, doc_id) when is_map(encrypt_dict) and is_binary(doc_id) do
    with :ok <- check_filter(encrypt_dict) do
      sh = %__MODULE__{
        version: get_integer(encrypt_dict, "V"),
        revision: get_integer(encrypt_dict, "R"),
        length: get_integer(encrypt_dict, "Length"),
        o: unwrap_string(Map.get(encrypt_dict, "O")),
        u: unwrap_string(Map.get(encrypt_dict, "U")),
        oe: unwrap_string(Map.get(encrypt_dict, "OE")),
        ue: unwrap_string(Map.get(encrypt_dict, "UE")),
        perms: unwrap_string(Map.get(encrypt_dict, "Perms")),
        p: get_integer(encrypt_dict, "P"),
        cf: get_cf(encrypt_dict),
        stm_filter: get_name(encrypt_dict, "StmF"),
        str_filter: get_name(encrypt_dict, "StrF"),
        encrypt_metadata: get_encrypt_metadata(encrypt_dict),
        filter: get_name(encrypt_dict, "Filter"),
        id: doc_id
      }

      {:ok, sh}
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # Validate /Filter — must be the name "Standard"
  defp check_filter(dict) do
    case Map.get(dict, "Filter") do
      {:name, "Standard"} -> :ok
      _ -> {:error, :encrypted_unsupported_handler}
    end
  end

  # Extract a bare integer from the dict; return nil if absent or wrong type
  defp get_integer(dict, key) do
    case Map.get(dict, key) do
      v when is_integer(v) -> v
      _ -> nil
    end
  end

  # Extract a name string from a {:name, string} entry; nil otherwise
  defp get_name(dict, key) do
    case Map.get(dict, key) do
      {:name, name} when is_binary(name) -> name
      _ -> nil
    end
  end

  # Unwrap {:string, bin} or {:hex_string, bin} → raw binary; nil otherwise
  defp unwrap_string({:string, bin}) when is_binary(bin), do: bin
  defp unwrap_string({:hex_string, bin}) when is_binary(bin), do: bin
  defp unwrap_string(_), do: nil

  # Extract /CF sub-dict; return %{} when absent or not a map
  defp get_cf(dict) do
    case Map.get(dict, "CF") do
      m when is_map(m) -> m
      _ -> %{}
    end
  end

  # /EncryptMetadata defaults to true; explicit false → false; anything else → true
  defp get_encrypt_metadata(dict) do
    case Map.get(dict, "EncryptMetadata") do
      false -> false
      _ -> true
    end
  end
end
