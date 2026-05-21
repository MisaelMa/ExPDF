defmodule ExQR.GaloisField do
  @moduledoc """
  GF(256) arithmetic for QR Code Reed-Solomon error correction.

  Uses the primitive polynomial x^8 + x^4 + x^3 + x^2 + 1 (0x11D)
  with generator α = 2. Exp and log tables are precomputed at compile time.
  """

  import Bitwise

  @primitive 0x11D

  {exp_table, log_table} =
    Enum.reduce(0..254, {%{}, %{}, 1}, fn i, {exp, log, val} ->
      exp = Map.put(exp, i, val)
      log = Map.put(log, val, i)
      next = val <<< 1
      next = if next >= 256, do: bxor(next, @primitive), else: next
      {exp, log, next}
    end)
    |> then(fn {exp, log, _} ->
      exp = Map.put(exp, 255, Map.fetch!(exp, 0))
      {exp, log}
    end)

  @exp_table exp_table
  @log_table log_table

  @doc "Returns α^n in GF(256)."
  def exp(n), do: Map.fetch!(@exp_table, rem(n, 255))

  @doc "Returns log_α(n) in GF(256). n must be > 0."
  def log(0), do: raise(ArgumentError, "log(0) is undefined in GF(256)")
  def log(n), do: Map.fetch!(@log_table, n)

  @doc "Multiply two values in GF(256)."
  def multiply(0, _), do: 0
  def multiply(_, 0), do: 0
  def multiply(a, b) do
    exp(Map.fetch!(@log_table, a) + Map.fetch!(@log_table, b))
  end

  @doc "Generate a Reed-Solomon generator polynomial of given degree."
  def generator_polynomial(degree) do
    Enum.reduce(0..(degree - 1), [1], fn i, poly ->
      multiply_polynomials(poly, [1, exp(i)])
    end)
  end

  @doc "Multiply two polynomials over GF(256)."
  def multiply_polynomials(p1, p2) do
    result = List.duplicate(0, length(p1) + length(p2) - 1)

    p1
    |> Enum.with_index()
    |> Enum.reduce(result, fn {coeff1, i}, result ->
      p2
      |> Enum.with_index()
      |> Enum.reduce(result, fn {coeff2, j}, result ->
        idx = i + j
        current = Enum.at(result, idx)
        List.replace_at(result, idx, bxor(current, multiply(coeff1, coeff2)))
      end)
    end)
  end
end
