# `Pdf.Layout.Stack`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.5/lib/pdf/layout/stack.ex#L1)

Vertical stack layout — children flow top-to-bottom without individual `y` positions.

Like HTML block elements: only the stack origin uses `position`, children stack
automatically with wrap.

# `extent`

```elixir
@spec extent(map(), list(), number(), any()) :: number()
```

Bottom edge relative to stack origin top (position y is negative down from box top).

# `measure`

```elixir
@spec measure(list(), number(), map(), any()) :: number()
```

Measure total height of stacked children in points.

# `render`

```elixir
@spec render(any(), {number(), number()}, map(), list(), (any(), any(), map() -&gt;
                                                      any())) :: any()
```

Render stacked children starting at absolute `{x, y}` on the document.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
