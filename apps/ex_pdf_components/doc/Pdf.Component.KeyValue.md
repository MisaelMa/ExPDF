# `Pdf.Component.KeyValue`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.5/lib/pdf/component/key_value.ex#L1)

Key-value pair component for PDF documents.

Renders aligned label-value rows, like invoice details or profile info.

## Examples

    doc |> Pdf.Component.KeyValue.render({50, 700}, %{width: 300}, [
      {"Name:", "John Doe"},
      {"Email:", "john@example.com"},
      {"Role:", "Admin"}
    ])

# `content_width`

```elixir
@spec content_width(map(), number() | nil, number()) :: number()
```

Resolve the content width for a key-value block inside a containing block.

`container_width` is the inner width of the parent. `x_offset` is the
component's horizontal inset from that edge (same semantics as `width: :full`
on text inside a box).

# `measure_height`

Calculate the total height this key-value list will occupy,
accounting for word-wrap on long values.

Takes the same `style` map as `render/4` plus the `pairs` list.
Returns the height in points.

# `render`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
