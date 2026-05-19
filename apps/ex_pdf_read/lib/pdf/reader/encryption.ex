defmodule Pdf.Reader.Encryption do
  @moduledoc """
  Facade module for PDF Standard Security Handler authentication and decryption.

  Dispatches to the appropriate version-specific module (`V1V2`, `V4`, `V5`)
  based on the `/V` field of the parsed `%StandardHandler{}` struct.

  This module does NOT parse the Encrypt dict — that is handled by
  `Pdf.Reader.Encryption.StandardHandler.parse/2`. This module only:

  1. Dispatches `unlock/3` to the correct version module.
  2. Returns the handler with `:file_key` populated on success.

  ## Authentication flow

  1. Try user password via `authenticate_user/2` for the detected version.
  2. If that fails (`:error`), try owner password via `authenticate_owner/2`.
  3. Return `{:ok, %StandardHandler{file_key: key}}` or `:error`.

  ## Supported versions

  | `/V` | Module      | Revision |
  |------|-------------|----------|
  |  1   | `V1V2`      | R=2      |
  |  2   | `V1V2`      | R=3/4    |
  |  4   | `V4`        | R=4      |
  |  5   | `V5`        | R=6 only |

  V5/R5 (deprecated Acrobat X beta) is rejected by `V5.authenticate_user/2`
  with `{:error, :encrypted_unsupported_handler}` per R-ENC25.

  ## Spec references

  - PDF 1.7 (ISO 32000-1) § 7.6 — Standard Security Handler (V1/V2/V4):
    https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
  - PDF 2.0 (ISO 32000-2) § 7.6 — Standard Security Handler (V5/R6):
    https://www.pdfa.org/wp-content/uploads/2023/04/ISO_32000_2_2020_PDF_2.0_FDIS.pdf
  - Mozilla pdf.js src/core/crypto.js (Apache-2.0 reference implementation):
    https://github.com/mozilla/pdf.js/blob/master/src/core/crypto.js
  """

  alias Pdf.Reader.Encryption.{StandardHandler, V1V2, V4, V5}

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Attempts to unlock an encrypted PDF handler with the given password.

  Tries the password as user, then as owner. Returns the handler with
  `:file_key` populated on success.

  ## Parameters

  - `password` — the plaintext password string.
  - `handler` — a `%StandardHandler{}` parsed from the Encrypt dict (`:file_key` is nil).
  - `_doc` — reserved for future use (e.g., doc reference); ignored for now.

  ## Returns

  - `{:ok, %StandardHandler{file_key: key}}` — authenticated; key is populated.
  - `:error` — wrong password (tried as both user and owner).
  - `{:error, :encrypted_unsupported_handler}` — version unsupported or RC4 unavailable.
  """
  @spec unlock(binary(), StandardHandler.t(), map()) ::
          {:ok, StandardHandler.t()} | :error | {:error, :encrypted_unsupported_handler}
  def unlock(password, %StandardHandler{} = handler, _doc) when is_binary(password) do
    case dispatch_user(password, handler) do
      {:ok, file_key} ->
        {:ok, %{handler | file_key: file_key}}

      :error ->
        # Try as owner password
        case dispatch_owner(password, handler) do
          {:ok, file_key} ->
            {:ok, %{handler | file_key: file_key}}

          other ->
            other
        end

      {:error, _} = err ->
        err
    end
  end

  # ---------------------------------------------------------------------------
  # Private — version dispatch
  # ---------------------------------------------------------------------------

  defp dispatch_user(password, %StandardHandler{version: v} = handler) when v in [1, 2] do
    V1V2.authenticate_user(password, handler)
  end

  defp dispatch_user(password, %StandardHandler{version: 4} = handler) do
    V4.authenticate_user(password, handler)
  end

  defp dispatch_user(password, %StandardHandler{version: 5} = handler) do
    V5.authenticate_user(password, handler)
  end

  defp dispatch_user(_password, _handler) do
    {:error, :encrypted_unsupported_handler}
  end

  defp dispatch_owner(password, %StandardHandler{version: v} = handler) when v in [1, 2] do
    V1V2.authenticate_owner(password, handler)
  end

  defp dispatch_owner(password, %StandardHandler{version: 4} = handler) do
    V4.authenticate_owner(password, handler)
  end

  defp dispatch_owner(password, %StandardHandler{version: 5} = handler) do
    V5.authenticate_owner(password, handler)
  end

  defp dispatch_owner(_password, _handler) do
    {:error, :encrypted_unsupported_handler}
  end
end
