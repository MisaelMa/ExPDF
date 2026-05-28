# `Pdf.Style`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.2/lib/pdf/style.ex#L1)

CSS-like styling system for PDF elements.

Styles are maps with atom keys that can be created, merged, and resolved.
Supports shorthand notation for padding, margin, and border (similar to CSS).

## Examples

    Style.new(%{font_size: 14, color: :red, padding: 10})
    Style.new(%{font: "Helvetica", bold: true, opacity: 0.5})
    Style.merge(parent_style, child_style)

# `t`

```elixir
@type t() :: %Pdf.Style{
  align: term(),
  background: term(),
  bold: term(),
  border: term(),
  border_color: term(),
  border_radius: term(),
  color: term(),
  fill_opacity: term(),
  font: term(),
  font_size: term(),
  height: term(),
  italic: term(),
  leading: term(),
  line_width: term(),
  margin: term(),
  opacity: term(),
  padding: term(),
  rotate: term(),
  stroke_color: term(),
  stroke_opacity: term(),
  underline: term(),
  width: term(),
  x: term(),
  y: term()
}
```

# `expand_shorthand`

```elixir
@spec expand_shorthand(number() | tuple()) :: {number(), number(), number(), number()}
```

Normalize a shorthand value into a {top, right, bottom, left} tuple.

Supports CSS-like shorthand:
- `10` → `{10, 10, 10, 10}`
- `{5, 10}` → `{5, 10, 5, 10}`
- `{5, 10, 15}` → `{5, 10, 15, 10}`
- `{5, 10, 15, 20}` → `{5, 10, 15, 20}`

# `merge`

```elixir
@spec merge(t(), t() | map() | keyword()) :: t()
```

Merge two styles. The child style overrides the parent for any non-nil fields
explicitly set in the child.

## Examples

    iex> parent = Pdf.Style.new(%{font_size: 12, color: :black})
    iex> child = Pdf.Style.new(%{color: :red, bold: true})
    iex> merged = Pdf.Style.merge(parent, child)
    iex> merged.font_size
    12
    iex> merged.color
    :red
    iex> merged.bold
    true

# `new`

```elixir
@spec new(map() | keyword()) :: t()
```

Create a new Style from a map or keyword list.

## Examples

    iex> Pdf.Style.new(%{font_size: 14, color: :red})
    %Pdf.Style{font_size: 14, color: :red}

    iex> Pdf.Style.new(font_size: 14, padding: 10)
    %Pdf.Style{font_size: 14, padding: {10, 10, 10, 10}}

# `to_opts`

```elixir
@spec to_opts(t()) :: keyword()
```

Convert a Style struct to a keyword list suitable for passing to
existing Page/Document functions.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
