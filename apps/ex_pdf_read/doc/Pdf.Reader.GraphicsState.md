# `Pdf.Reader.GraphicsState`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.1/lib/pdf/reader/graphics_state.ex#L1)

Struct and operations for the PDF graphics state during content stream interpretation.

CTM (current transformation matrix) and text matrices are stored as 6-float
tuples `{a, b, c, d, e, f}` — the affine subset used by PDF (§8.3.3 of the
PDF spec). Full 4×4 matrices are NOT used; PDF only needs the 2D affine form.

The `:stack` holds snapshots pushed by the `q` operator and restored by `Q`.

## Text state additions (§ 9.4.4)

The `:widths_fn` field holds the per-glyph width closure for the active font.
It is set by the `Tf` operator handler and used by `advance_tm/2` to compute
exact horizontal text advance per the full § 9.4.4 formula. When `nil`, advance
defaults to 0 per glyph (only `Tc`, `Tw`, and `Tfs` terms contribute).

## Matrix convention

PDF uses the row-vector convention (§ 8.3.3):

    | a b 0 |
    | c d 0 |
    | e f 1 |

Multiplication: M3 = M1 × M2 with formulas:

    a3 = a1*a2 + b1*c2
    b3 = a1*b2 + b1*d2
    c3 = c1*a2 + d1*c2
    d3 = c1*b2 + d1*d2
    e3 = e1*a2 + f1*c2 + e2
    f3 = e1*b2 + f1*d2 + f2

# `matrix`

```elixir
@type matrix() :: {float(), float(), float(), float(), float(), float()}
```

# `t`

```elixir
@type t() :: %Pdf.Reader.GraphicsState{
  char_spacing: float(),
  ctm: matrix(),
  font: nil | binary(),
  font_size: float(),
  horizontal_scaling: float(),
  leading: float(),
  rise: float(),
  stack: [t()],
  tlm: matrix(),
  tm: matrix(),
  widths_fn: nil | (binary() -&gt; [non_neg_integer()]),
  word_spacing: float()
}
```

# `multiply`

```elixir
@spec multiply(matrix(), matrix()) :: matrix()
```

Multiplies two affine matrices under the PDF row-vector convention.

`multiply(m1, m2)` returns `M3 = M1 × M2`.
Both arguments and the result are 6-element `{a, b, c, d, e, f}` tuples.

Spec reference: PDF 1.7 § 8.3.4.

# `new`

```elixir
@spec new() :: t()
```

Returns a fresh GraphicsState with identity matrices and zeroed text state.

# `pop`

```elixir
@spec pop(t()) :: t()
```

Pops the most-recently-pushed graphics state from `:stack` (implements PDF `Q` operator).

If the stack is empty (malformed stream), this is a silent no-op — the interpreter
remains in the current state rather than crashing. Spec allows senders to have
unbalanced `q`/`Q` in practice (e.g. content streams generated without strict nesting).

# `push`

```elixir
@spec push(t()) :: t()
```

Pushes the current graphics state onto `:stack` (implements PDF `q` operator).

The full state struct is saved. No fields are excluded — this keeps semantics
consistent with the writer's `q`/`Q` discipline.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
