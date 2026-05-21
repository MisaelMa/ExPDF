# `Pdf`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.0/lib/pdf.ex#L1)

The missing PDF library for Elixir.

## Usage

```elixir
Pdf.build([size: :a4, compress: true], fn pdf ->
  pdf
  |> Pdf.set_info(title: "Demo PDF")
  |> Pdf.set_font("Helvetica", 10)
  |> Pdf.text_at({200,200}, "Welcome to Pdf")
  |> Pdf.write_to("test.pdf")
end)
```
## Page sizes

The available page sizes are:

 - `:a0` - `:a9`
 - `:b0` - `:b9`
 - `:c5e`
 - `:comm10e`
 - `:dle`
 - `:executive`
 - `:folio`
 - `:ledger`
 - `:legal`
 - `:letter`
 - `:tabloid`
 - a custom size `[width, height]` in Pdf points.

or you can also specify a tuple `{size, :landscape}`.

# `cap_style`

```elixir
@type cap_style() :: :butt | :round | :projecting_square | :square | integer()
```

A code specifying the shape of the endpoints for an open path that is stroked.

- :butt (default)

  The stroke shall be squared of at the endpoint of the path.

- :round

  A small semicircular arc with a diameter equal to the line width shall be drawn around the endpoint and shall be filled in.

- :square | :projecting_square

  The stroke shall continue beyond the endpoint of the path for a distance equal to half the line width and shall be squared of.

# `cmyk`

```elixir
@type cmyk() :: {float(), float(), float(), float()}
```

Specify a color by it's CMYK make-up.

# `color_name`

```elixir
@type color_name() :: atom()
```

Use one of the colors in the `Pdf.Color` module.

# `coords`

```elixir
@type coords() :: {x(), y()}
```

Most functions take a coordinates tuple, `{x, y}`.
In Pdf these start from the bottom-left of the page.

# `dimension`

```elixir
@type dimension() :: {width(), height()}
```

Width and height expressed in Pdf points

# `height`

```elixir
@type height() :: number()
```

The height in points

# `join_style`

```elixir
@type join_style() :: :miter | :round | :bevel | integer()
```

The line join style shall specify the shape to be used at the corners of paths that are stroked.

- :miter

  The outer edges of the strokes for the two segments shall be extended until they meet at an angle. If the segments meet at too sharp an angle (as defined in section 8.4.3.5 of the PDF specs), a bevel join shall be used instead.

- :round

  An arc of a circle with a diameter equal to the line width shall be drawn around the point where the two segments meet, connecting the outer edges of the strokes for the two segments.  This pieslice-shae figure shall be filled in, producing a rounded corner.

- :bevel

  The two segments shall be finished with butt caps (see `t:cap_style/0`) and the resulting notch beyond the ends of the segments shall be filled with a triangle.

# `rgb`

```elixir
@type rgb() :: {byte(), byte(), byte()}
```

Specify a color by it's RGB make-up.

# `width`

```elixir
@type width() :: number()
```

The width in points

# `x`

```elixir
@type x() :: number()
```

The x-coordinate

# `y`

```elixir
@type y() :: number()
```

The y-coordinate

# `add_font`

Add a font to the list of available fonts.

Currently only _Type 1_ AFM/PFB fonts are supported.

```elixir

fonts_dir = Application.app_dir(:my_app) |> Path.join("priv", "fonts")

pdf
|> Pdf.add_font(Path.join(fonts_dir, "DejavuSans.afm")
|> Pdf.add_font(Path.join(fonts_dir, "DejavuSans-Bold.afm")
```

The font can then be set with `set_font/3`.

You have to `add_font/2` all variants you want to use, bold, italic, ...

# `add_image`

Add an images (PNG, or JPEG only) at the given coordinates.

# `add_image`

Add an images (PNG, or JPEG only) at the given coordinates.

You can specify a `:width` and `:height` in the options, the image will then be scaled.

# `add_page`

Add a new page to the Pdf with the given page size.

# `autoprint`

Adds an autoprint action to the Pdf.

This is can be useful for generating a PDF that will automatically open the print dialog in a browser

# `background`

Fill the current page background with a color.

## Example

    pdf |> Pdf.background(%{color: {0.95, 0.95, 1.0}})

# `box`

Render a box container at `{x, y}` with size `{w, h}`.

Supports padding, margin, border, border_radius, and background.
The callback receives `(doc, %{x, y, width, height})` with the inner area.

Size supports relative dimensions:
- `:full` — 100% of the document's content area
- `"50%"` — percentage of the content area
- `number` — absolute points (default)

## Example

    doc
    |> Pdf.box({50, 700}, {:full, 200}, %{padding: 10, border: 1}, fn doc, area ->
      Pdf.text_at(doc, {area.x + 5, area.y - 14}, "Inside the box")
    end)

# `build`

Builds a PDF document.

```elixir
Pdf.build([size: :a3], fn pdf ->
  pdf
  |> Pdf.set_font("Helvetica", 12)
  |> Pdf.text_at({100, 100}, "Open")
  |> Pdf.write_to("test.pdf")
end)
```
is equivalent to
```elixir
pdf = Pdf.new(size: :a3)
pdf
|> Pdf.set_font("Helvetica", 12)
|> Pdf.text_at({100, 100}, "Open")
|> Pdf.write_to("test.pdf")
```

# `cleanup`

No-op. Kept for backwards compatibility.

# `clip`

Set the current path as a clipping boundary.

# `close_path`

```elixir
@spec close_path(Pdf.Document.t()) :: Pdf.Document.t()
```

Close the current path by drawing a straight line back to the starting point.

# `cm`

```elixir
@spec cm(number()) :: integer()
```

Convert the given value from cm to Pdf points

# `column`

Stack content vertically with fixed heights.

`rows` is a list of `{height, callback}` tuples.
Size supports relative dimensions (`:full`, `"50%"`).

## Example

    doc
    |> Pdf.column({50, 700}, {:full, 400}, [
      {50, fn doc, area -> Pdf.text_at(doc, {area.x, area.y - 14}, "Row 1") end},
      {80, fn doc, area -> Pdf.text_at(doc, {area.x, area.y - 14}, "Row 2") end}
    ], gap: 5)

# `content_area`

Returns the content area `%{x, y, width, height}` based on margins.

# `cursor`

```elixir
@spec cursor(Pdf.Document.t()) :: number()
```

Gets the current cursor Y position (vertical).

# `cursor_xy`

```elixir
@spec cursor_xy(Pdf.Document.t()) :: %{x: number(), y: number()}
```

Gets the current cursor position as `%{x: x, y: y}`.

# `curve_to`

```elixir
@spec curve_to(Pdf.Document.t(), coords(), coords(), coords()) :: Pdf.Document.t()
```

Draw a Bézier curve from the current point through control points to the end point.

```elixir
pdf
|> Pdf.move_to({100, 100})
|> Pdf.curve_to({120, 150}, {180, 150}, {200, 100})
|> Pdf.stroke()
```

# `debug_grid`

Draw a debug grid overlay on the current page.

## Options

  - `:grid` — `:horizontal`, `:vertical`, or `:both` (default `:both`)
  - `:area` — where to draw the grid:
    - `:content` — inside margins only (default)
    - `:page` — entire page (0,0 to page width/height)
    - `:margins` — only in the margin zones (outside content area)
  - `:spacing` — distance between grid lines in points (default `10`)
  - `:color` — grid line color (default `{0.85, 0.85, 0.85}`)
  - `:line_width` — grid line width (default `0.25`)
  - `:labels` — show coordinate labels (default `true`)
  - `:label_every` — show a coordinate label every N points (default `50`)
  - `:info` — show page/margin info text (default `true`)
  - `:margin_border` — draw the margin boundary rectangle (default `true`)
  - `:cursor_line` — draw cursor Y position line (default `true`)

## Examples

    pdf |> Pdf.debug_grid()
    pdf |> Pdf.debug_grid(%{grid: :horizontal, area: :page})
    pdf |> Pdf.debug_grid(%{grid: :vertical, area: :content, spacing: 20})
    pdf |> Pdf.debug_grid(%{area: :margins, color: {1.0, 0.9, 0.9}})

# `delete`

> This function is deprecated. Use cleanup/1 instead.

# `export`

Export the Pdf to a binary representation.

This is can be used in eg Phoenix to send a PDF to the browser.

```elixir
  report =
    pdf
    |> ...
    |> Pdf.export()

 conn
  |> put_resp_content_type("application/pdf")
  |> put_resp_header(
    "content-disposition",
    "attachment; filename="document.pdf""
  )
  |> send_resp(200, report)
```

# `fill`

```elixir
@spec fill(Pdf.Document.t()) :: Pdf.Document.t()
```

Fill the current drawing with the previously set color.

# `fill_and_stroke`

Fill and stroke the current path.

# `horizontal_line`

Draw a horizontal line at the current cursor position across the content width.

## Example

    pdf |> Pdf.horizontal_line()
    pdf |> Pdf.horizontal_line(%{color: :gray, line_width: 0.5})

# `inches`

```elixir
@spec inches(number()) :: integer()
```

Convert the given value from inches to Pdf points

# `line`

```elixir
@spec line(Pdf.Document.t(), coords(), coords()) :: Pdf.Document.t()
```

Draw a line between 2 points.

# `line_append`

```elixir
@spec line_append(Pdf.Document.t(), coords()) :: Pdf.Document.t()
```

Draw a line from the last position to the given coordinates.
```elixir
  pdf
  |> Pdf.move_to({100, 100})
  |> Pdf.line_append({200, 200})
```

# `mm`

```elixir
@spec mm(number()) :: integer()
```

Convert the given value from mm to Pdf points

# `move_down`

```elixir
@spec move_down(Pdf.Document.t(), number()) :: Pdf.Document.t()
```

Move the cursor `amount` points down.

# `move_right`

```elixir
@spec move_right(Pdf.Document.t(), number()) :: Pdf.Document.t()
```

Move the cursor `amount` points to the right.

# `move_to`

```elixir
@spec move_to(Pdf.Document.t(), coords()) :: Pdf.Document.t()
```

Move the cursor to the given coordinates.

# `new`

```elixir
@spec new(any()) :: Pdf.Document.t()
```

Create a new Pdf document.

The following options can be given:

:size      |  Page size, defaults to `:a4`
:compress  |  Compress the Pdf, default: `true`

There is no standard font selected when creating a new PDF, so set one with `set_font/3` before adding text.

# `on_page`

Register a page template that runs on every new page.

Supported template names: `:header`, `:footer`, `:watermark`, `:background`.

The function receives `(document, page_info)` where `page_info` is `%{number: n}`.

## Example

    pdf
    |> Pdf.on_page(:header, fn doc, _info ->
      Pdf.text_at(doc, {40, 820}, "My Header")
    end)

# `open`

> This function is deprecated. Use build/2 instead.

# `page_break`

Insert a page break. Executes footer template on the current page
and header/watermark templates on the new page.

## Example

    pdf |> Pdf.page_break()
    pdf |> Pdf.page_break(:letter)

# `page_number`

Returns the current page number.

# `picas`

```elixir
@spec picas(number()) :: number()
```

Convert the given value from picas to Pdf points

# `pixels_to_points`

```elixir
@spec pixels_to_points(pixels :: number(), dpi :: number()) :: integer()
```

Convert the given value from pixels to Pdf points

# `points`

The unit of measurement in a Pdf are points, where *1 point = 1/72 inch*.
This means that a standard A4 page, 8.27 inch, translates to 595 points.

# `rectangle`

```elixir
@spec rectangle(Pdf.Document.t(), coords(), dimension()) :: Pdf.Document.t()
```

Draw a rectangle from coordinates x,y (lower left corner) for a given width and height.

# `register_style`

Register a named style that can be referenced by atom in text/3, horizontal_line/2, etc.

## Example

    pdf
    |> Pdf.register_style(:heading, %{font_size: 24, bold: true, color: :navy})
    |> Pdf.register_style(:body, %{font_size: 12, color: :black})
    |> Pdf.register_style(:accent, %{font_size: 12, color: :green})
    |> Pdf.text("My Title", :heading)
    |> Pdf.text("Body text", :body)

# `register_styles`

Register multiple named styles at once from a map.

## Example

    Pdf.register_styles(pdf, %{
      heading: %{font_size: 24, bold: true, color: :navy},
      body: %{font_size: 12},
      footer: %{font_size: 8, color: :gray}
    })

# `reset_x`

```elixir
@spec reset_x(Pdf.Document.t()) :: Pdf.Document.t()
```

Reset the cursor X position to 0.

# `restore_state`

```elixir
@spec restore_state(Pdf.Document.t()) :: Pdf.Document.t()
```

Restore a previously saved graphics state.

# `rotate`

```elixir
@spec rotate(Pdf.Document.t(), number()) :: Pdf.Document.t()
```

Rotate the coordinate system by the given angle in degrees.
Must be used within `save_state/restore_state`.

# `rounded_rectangle`

Draw a rounded rectangle.

# `row`

Distribute content horizontally in columns by weight.

`columns` is a list of `{weight, callback}` tuples.
Size supports relative dimensions (`:full`, `"50%"`).

## Example

    doc
    |> Pdf.row({50, 700}, {:full, 80}, [
      {1, fn doc, area -> Pdf.text_at(doc, {area.x, area.y - 14}, "Left") end},
      {2, fn doc, area -> Pdf.text_at(doc, {area.x, area.y - 14}, "Center") end}
    ], gap: 10)

# `save_state`

```elixir
@spec save_state(Pdf.Document.t()) :: Pdf.Document.t()
```

Save the current graphics state. Use with `restore_state/1` to isolate
transformations like rotation, translation, scaling, and opacity changes.

# `scale`

```elixir
@spec scale(
  Pdf.Document.t(),
  {number(), number()}
) :: Pdf.Document.t()
```

Scale the coordinate system by {sx, sy}.
Must be used within `save_state/restore_state`.

# `set_author`

Sets the author in the PDF information section.

# `set_creator`

Sets the creator in the PDF information section.

# `set_cursor`

```elixir
@spec set_cursor(Pdf.Document.t(), number()) :: Pdf.Document.t()
```

Set the cursor Y position.

# `set_cursor_x`

```elixir
@spec set_cursor_x(Pdf.Document.t(), number()) :: Pdf.Document.t()
```

Set the cursor X position.

# `set_dash`

Set the dash pattern for stroking operations.

- `set_dash(doc, [3, 3], 0)` — dashed line (3 on, 3 off)
- `set_dash(doc, [6, 2], 0)` — long dash
- `set_dash(doc, [], 0)` — reset to solid

# `set_fill_color`

```elixir
@spec set_fill_color(Pdf.Document.t(), color_name() | rgb() | cmyk()) ::
  Pdf.Document.t()
```

Set the color to use when filling.

This takes either a `Pdf.Color.color/1` atom, an RGB tuple or a CMYK tuple.

# `set_fill_opacity`

```elixir
@spec set_fill_opacity(Pdf.Document.t(), number()) :: Pdf.Document.t()
```

Set the fill opacity (0.0 fully transparent, 1.0 fully opaque).

# `set_font`

```elixir
@spec set_font(Pdf.Document.t(), binary(), integer() | list()) :: Pdf.Document.t()
```

Sets the font that will be used for all text from here on.
You can either specify the font size, or a list of options:

Option  |  Value  | Default
:------ | :------ | :------
`:size`   | integer | 10
`:bold`   | boolean | false
`:italic` | boolean | false

# `set_font_size`

Sets the font size.

The font has to have been previously set!

# `set_info`

```elixir
@spec set_info(Pdf.Document.t(), info_list()) :: Pdf.Document.t()
```

Set multiple keys in the PDF information section.

Valid keys
  - `:author`
  - `:created`
  - `:creator`
  - `:keywords`
  - `:modified`
  - `:producer`
  - `:subject`
  - `:title`

# `set_keywords`

Sets the keywords in the PDF information section.

# `set_line_cap`

```elixir
@spec set_line_cap(Pdf.Document.t(), cap_style()) :: Pdf.Document.t()
```

The line endings to draw, see `t:cap_style/0`.

# `set_line_join`

```elixir
@spec set_line_join(Pdf.Document.t(), join_style()) :: Pdf.Document.t()
```

The join style to use where lines meet, see `t:join_style/0`.

# `set_line_width`

```elixir
@spec set_line_width(Pdf.Document.t(), number()) :: Pdf.Document.t()
```

The width to use when drawing lines.

# `set_opacity`

```elixir
@spec set_opacity(Pdf.Document.t(), number()) :: Pdf.Document.t()
```

Set both fill and stroke opacity (0.0 fully transparent, 1.0 fully opaque).

# `set_producer`

Sets the producer in the PDF information section.

# `set_stroke_color`

```elixir
@spec set_stroke_color(Pdf.Document.t(), color_name() | rgb() | cmyk()) ::
  Pdf.Document.t()
```

Set the color to use when drawing lines.

This takes either a `Pdf.Color.color/1` atom, an RGB tuple or a CMYK tuple.

# `set_stroke_opacity`

```elixir
@spec set_stroke_opacity(Pdf.Document.t(), number()) :: Pdf.Document.t()
```

Set the stroke opacity (0.0 fully transparent, 1.0 fully opaque).

# `set_subject`

Sets the subject in the PDF information section.

# `set_text_leading`

Leading is a typography term that describes the distance between each line of text. The name comes from a time when typesetting was done by hand and pieces of lead were used to separate the lines.

Today, leading is often used synonymously with "line height" or "line spacing."

# `set_title`

Sets the title in the PDF information section.

# `size`

Returns a `{width, height}` for the current page.

# `spacer`

Add vertical space by moving the cursor down.

## Example

    pdf |> Pdf.spacer(20)

# `stroke`

```elixir
@spec stroke(Pdf.Document.t()) :: Pdf.Document.t()
```

Perform all the previous graphic commands.

# `table`

Add a table in the document at the given coordinates.

See [Tables](tables.html) for more information on how to use tables.

# `table!`

Add a table in the document at the given coordinates.
Raises an exception if the table does not fit the dimensions.

See [Tables](tables.html) for more information on how to use tables.

# `text`

Write styled text at the current cursor position with auto-wrapping.
Moves the cursor down after writing.

## Example

    pdf |> Pdf.text("Hello world")
    pdf |> Pdf.text("Bold red", %{bold: true, color: :red, font_size: 16})

# `text_at`

Writes the text at the given coordinates.
The coordinates are the bottom left of the text.

The _text_ can be either a binary or a list of binaries or annotated binaries.
All text will be drawn on the same line, no wrapping will occur, it may overrun the page.

When given a list, you can supply a mix of binaries and annotated binaries.
An annotated binary is a tuple `{binary, options}`, with the options being:

Option  |  Value  | Default
:------ | :------ | :------
`:font_size`   | integer | current
`:bold`   | boolean | false
`:italic` | boolean | false
`:leading` | integer | current
`:color` | :atom | current

When setting `bold: true` or `italic: true`, make sure that your current font supports these or an error will occur.
If using an external font, you have to `add_font/2` all variants you want to use.

# `text_at`

Writes the text at the given coordinates.
The coordinates are the bottom left of the text.

Accepts either a keyword list of options or a style map/atom:

    pdf |> Pdf.text_at({300, 730}, "BILL TO", %{bold: true, color: :gray})
    pdf |> Pdf.text_at({300, 730}, "BILL TO", :label)
    pdf |> Pdf.text_at({300, 730}, "BILL TO", kerning: true)

# `text_lines`

```elixir
@spec text_lines(Pdf.Document.t(), coords(), list(), keyword()) :: Pdf.Document.t()
```

This function draws a number of text lines starting at the given coordinates.
The list can overrun the page, no errors or wrapping will occur.

Kerning can be set, see `text_at/4` for more information.

# `text_wrap`

```elixir
@spec text_wrap(Pdf.Document.t(), coords(), dimension(), binary() | list()) ::
  {Pdf.Document.t(), :complete | term()}
```

Writes the text wrapped within the confines of the given dimensions.
The `{x,y}` is the top-left of corner of the box, for this reason it is not wise to try to match it up with `text_at` on the same line.

The y-coordinate can also be set to `:cursor`.

The text will break at whitespace, such as, space, soft-hyphen, hyphen, cr, lf,  tab, ...

If the text is too large for the box, it may overrun its boundaries, but only horizontally.

This function will return a tuple `{pid, :complete}` if all text was rendered, or `{pid, remaining}` if not.
It can subsequently be called with the _remaining_ data, after eg starting a new page, until `{pid, :complete}`.

The _text_ can be either a binary or a list of binaries or annotated binaries.
The `:kerning` option if set will apply to all rendered text.

When given a list, you can supply a mix of binaries and annotated binaries.
An annotated binary is a tuple `{binary, options}`, with the options being:

Option  |  Value  | Default
:------ | :------ | :------
`:font_size`   | integer | current
`:bold`   | boolean | false
`:italic` | boolean | false
`:leading` | integer | current
`:color` | :atom | current

When choosing `:bold` or `:italic`, make sure that your current font supports these or an error will occur.
If using an external font, you have to `add_font/2` all variants you want to use.

# `text_wrap`

```elixir
@spec text_wrap(Pdf.Document.t(), coords(), dimension(), binary() | list(), keyword()) ::
  {Pdf.Document.t(), :complete | term()}
```

This function has the same options as `text_wrap/4`, but also supports additional options that will be applied to the complete text.

Option  |  Value  | Default
:------ | :------ | :------
`:align` | :left , :center , :right | :left
`:kerning` | `boolean` | false

# `text_wrap!`

```elixir
@spec text_wrap!(Pdf.Document.t(), coords(), dimension(), binary() | list()) ::
  Pdf.Document.t()
```

This function has the same options as `text_wrap/4`, but if the text is too large for the box, a `RuntimeError` will be raised.

# `text_wrap!`

```elixir
@spec text_wrap!(
  Pdf.Document.t(),
  coords(),
  dimension(),
  binary() | list(),
  keyword()
) ::
  Pdf.Document.t()
```

This function has the same options as `text_wrap/5`, but if the text is too large for the box, a `RuntimeError` will be raised.

# `transform`

```elixir
@spec transform(
  Pdf.Document.t(),
  {number(), number(), number(), number(), number(), number()}
) ::
  Pdf.Document.t()
```

Apply an arbitrary transformation matrix {a, b, c, d, e, f}.
Must be used within `save_state/restore_state`.

# `translate`

```elixir
@spec translate(
  Pdf.Document.t(),
  {number(), number()}
) :: Pdf.Document.t()
```

Translate (move) the coordinate origin by {tx, ty}.
Must be used within `save_state/restore_state`.

# `watermark`

Add a text watermark to the current page with rotation and opacity.

## Example

    pdf |> Pdf.watermark("DRAFT", %{opacity: 0.1, rotate: 45, font_size: 60, color: :gray})

# `write_to`

Write the PDF to the given path

---

*Consult [api-reference.md](api-reference.md) for complete listing*
