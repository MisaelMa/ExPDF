# `Pdf.Dimension`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.1/lib/pdf/dimension.ex#L1)

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

# `needs_resolution?`

```elixir
@spec needs_resolution?({any(), any()}) :: boolean()
```

Returns `true` if either dimension in the size tuple is relative.

# `relative?`

```elixir
@spec relative?(any()) :: boolean()
```

Returns `true` if the value is a relative dimension (`:full` or `"N%"`).

# `resolve`

```elixir
@spec resolve(value :: number() | :full | String.t(), parent_dim :: number()) ::
  number()
```

Resolve a single dimension value against a parent dimension.

# `resolve_size`

```elixir
@spec resolve_size(
  {any(), any()},
  %{width: number(), height: number()}
) :: {number(), number()}
```

Resolve a `{w, h}` size tuple against a parent area `%{width:, height:}`.

Returns `{resolved_w, resolved_h}`.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
