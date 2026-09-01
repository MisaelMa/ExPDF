# `Pdf.Layout.AbsoluteMeasure`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.5/lib/pdf/layout/absolute_measure.ex#L1)

Measures the minimum inner height for a box with absolutely-positioned children.

Like CSS `height: auto` on a positioned container: walk children, find the
lowest bottom edge (relative to the inner area top), and return that height.

# `measure`

```elixir
@spec measure(list(), number(), any()) :: number()
```

Returns the minimum inner content height in points.

# `row_height`

```elixir
@spec row_height(list(), number(), number(), any()) :: number()
```

Height of a weighted row's tallest column.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
