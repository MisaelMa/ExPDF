defmodule ExQR.ReedSolomon do
  @moduledoc """
  Reed-Solomon error correction encoding for QR codes.

  Computes error correction codewords for a given data block
  using polynomial division over GF(256).
  """

  import Bitwise
  alias ExQR.GaloisField, as: GF

  @doc """
  Compute error correction codewords for a data block.

  ## Parameters
    - `data` — list of data codeword integers (0–255)
    - `ec_count` — number of error correction codewords to generate

  ## Returns
    List of `ec_count` error correction codeword integers.
  """
  def encode(data, ec_count) do
    generator = GF.generator_polynomial(ec_count)

    padded = data ++ List.duplicate(0, ec_count)

    result =
      Enum.reduce(0..(length(data) - 1), padded, fn i, message ->
        coeff = Enum.at(message, i)

        if coeff == 0 do
          message
        else
          log_coeff = GF.log(coeff)

          generator
          |> Enum.with_index()
          |> Enum.reduce(message, fn {gen_coeff, j}, msg ->
            idx = i + j
            current = Enum.at(msg, idx)
            xor_val = GF.exp(log_coeff + GF.log(gen_coeff))
            List.replace_at(msg, idx, bxor(current, xor_val))
          end)
        end
      end)

    Enum.drop(result, length(data))
  end
end
