defmodule Pdf.Dimension do
  @moduledoc """
  Resolves relative dimensions against a parent reference.

  Supports:
  - `:full` — 100% of the parent dimension
  - `"N%"` — percentage of the parent dimension (e.g. `"50%"`)
  - `number` — absolute value (pass-through)

  ## Examples

      iex> Pdf.Dimension.resolve(:full, 400)
      400

      iex> Pdf.Dimension.resolve("50%", 400)
      200.0

      iex> Pdf.Dimension.resolve(200, 400)
      200
  """

  @doc """
  Resolve a single dimension value against a parent dimension.
  """
  @spec resolve(value :: number | :full | String.t(), parent_dim :: number) :: number
  def resolve(:full, parent_dim), do: parent_dim

  def resolve(value, _parent_dim) when value in [:auto, "auto"], do: :auto

  def resolve(pct, parent_dim) when is_binary(pct) do
    case Float.parse(String.trim_trailing(pct, "%")) do
      {n, ""} -> parent_dim * (n / 100)
      _ -> raise ArgumentError, "invalid percentage: #{inspect(pct)}"
    end
  end

  def resolve(value, _parent_dim) when is_number(value), do: value

  @doc """
  Resolve a `{w, h}` size tuple against a parent area `%{width:, height:}`.

  Returns `{resolved_w, resolved_h}`.
  """
  @spec resolve_size({any, any}, %{width: number, height: number}) :: {number, number}
  def resolve_size({w, h}, %{width: pw, height: ph}) do
    {resolve(w, pw), resolve(h, ph)}
  end

  @doc """
  Returns `true` if the value is a relative dimension (`:full` or `"N%"`).
  """
  @spec relative?(any) :: boolean
  def relative?(:full), do: true
  def relative?(:auto), do: true
  def relative?(v) when is_binary(v), do: String.ends_with?(v, "%") or v == "auto"
  def relative?(_), do: false

  @doc """
  Returns `true` if either dimension in the size tuple is relative.
  """
  @spec needs_resolution?({any, any}) :: boolean
  def needs_resolution?({w, h}), do: relative?(w) or relative?(h)
end
