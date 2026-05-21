defmodule ExQR do
  @moduledoc """
  Pure Elixir QR code encoding library.

  Supports versions 1–20, error correction levels L/M/Q/H,
  and byte mode encoding. No external dependencies.

  ## Usage

      {:ok, matrix, size} = ExQR.encode("https://example.com")
      {:ok, matrix, size} = ExQR.encode("Hello", :h)

  The matrix is a map of `{row, col} => 0 | 1` where 1 = black module.

  ## Converting to rows

      rows = ExQR.matrix_to_rows(matrix, size)
      # => [[0, 1, 1, ...], [1, 0, 0, ...], ...]
  """

  alias ExQR.{Encode, Matrix, Tables}

  @doc """
  Encode text into a QR code matrix.

  ## Parameters
    - `text` — the string to encode
    - `level` — error correction level: `:l`, `:m` (default), `:q`, or `:h`

  ## Returns
    `{:ok, matrix, size}` or `{:error, reason}`.
  """
  @spec encode(String.t(), atom()) :: {:ok, map(), pos_integer()} | {:error, atom()}
  def encode(text, level \\ :m) when is_binary(text) and level in [:l, :m, :q, :h] do
    case Encode.encode(text, level) do
      {:ok, version, codewords} ->
        size = Tables.size(version)
        matrix = Matrix.build(version, level, codewords)
        {:ok, matrix, size}

      {:error, _} = err ->
        err
    end
  end

  @doc "Same as `encode/2` but raises on error."
  def encode!(text, level \\ :m) do
    case encode(text, level) do
      {:ok, matrix, size} -> {matrix, size}
      {:error, reason} -> raise ArgumentError, "QR encode error: #{reason}"
    end
  end

  @doc """
  Convert a QR matrix to a list of lists (row-major).

  Returns `size` rows, each with `size` values (0 or 1).
  """
  def matrix_to_rows(matrix, size) do
    for r <- 0..(size - 1) do
      for c <- 0..(size - 1) do
        Map.get(matrix, {r, c}, 0)
      end
    end
  end
end
