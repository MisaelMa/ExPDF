# `Pdf.Layout.AbsoluteReflow`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.5/lib/pdf/layout/absolute_reflow.ex#L1)

HTML-like reflow for absolutely-positioned box children.

- Text wraps within the parent width (`break_text` applied automatically)
- Vertical stacks (same x column) push siblings below down
- Content at/after `reflow_anchor` shifts down when the header grows
- Box height grows via `measure/4`

# `measure`

```elixir
@spec measure(list(), number(), map(), any()) :: number()
```

Measure inner height after reflow.

# `prepare`

```elixir
@spec prepare(list(), number(), map(), any()) :: list()
```

Returns children with updated positions/styles after reflow.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
