# `Pdf.Layout.ContainingBlock`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.5/lib/pdf/layout/containing_block.ex#L1)

CSS-like containing block — resolves relative sizes against a parent area.

Use inside boxes, rows, and columns so children can declare `width: :full`
or `"50%"` and inherit the parent's available space (similar to HTML width: 100%).

# `area`

```elixir
@type area() :: %{
  :width =&gt; number(),
  optional(:height) =&gt; number(),
  optional(:x) =&gt; number(),
  optional(:y) =&gt; number()
}
```

# `resolve_height`

```elixir
@spec resolve_height(any(), area() | number()) :: number()
```

Resolve a height value against the parent area height.

# `resolve_size`

```elixir
@spec resolve_size(
  {any(), any()},
  area()
) :: {number(), number()}
```

Resolve `{w, h}` against a parent area.

# `resolve_style`

```elixir
@spec resolve_style(map(), area()) :: map()
```

Apply width/height resolution to a style map using the parent area.
Resolves `:width`, `:height`, and `:wrap_width` when present.

# `resolve_width`

```elixir
@spec resolve_width(any(), area() | number()) :: number()
```

Resolve a width value against the parent area width.

# `text_width`

```elixir
@spec text_width(area(), number()) :: number()
```

Text wrap width for a child at horizontal offset `x` inside the area.
Like CSS: `width: calc(100% - x)`.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
