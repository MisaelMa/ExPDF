defmodule Pdf do
  alias Pdf.Document

  @moduledoc """
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
  """

  @typedoc """
  Most functions take a coordinates tuple, `{x, y}`.
  In Pdf these start from the bottom-left of the page.
  """
  @type coords :: {x, y}
  @typedoc "Width and height expressed in Pdf points"
  @type dimension :: {width, height}
  @typedoc "The x-coordinate"
  @type x :: number
  @typedoc "The y-coordinate"
  @type y :: number
  @typedoc "The width in points"
  @type width :: number
  @typedoc "The height in points"
  @type height :: number
  @typedoc """
  Use one of the colors in the `Pdf.Color` module.
  """
  @type color_name :: atom
  @typedoc """
  Specify a color by it's RGB make-up.
  """
  @type rgb :: {byte, byte, byte}
  @typedoc """
  Specify a color by it's CMYK make-up.
  """
  @type cmyk :: {float, float, float, float}
  @typedoc """
  A code specifying the shape of the endpoints for an open path that is stroked.

  - :butt (default)

    The stroke shall be squared of at the endpoint of the path.

  - :round

    A small semicircular arc with a diameter equal to the line width shall be drawn around the endpoint and shall be filled in.

  - :square | :projecting_square

    The stroke shall continue beyond the endpoint of the path for a distance equal to half the line width and shall be squared of.
  """
  @type cap_style :: :butt | :round | :projecting_square | :square | integer()
  @typedoc """
  The line join style shall specify the shape to be used at the corners of paths that are stroked.

  - :miter

    The outer edges of the strokes for the two segments shall be extended until they meet at an angle. If the segments meet at too sharp an angle (as defined in section 8.4.3.5 of the PDF specs), a bevel join shall be used instead.

  - :round

    An arc of a circle with a diameter equal to the line width shall be drawn around the point where the two segments meet, connecting the outer edges of the strokes for the two segments.  This pieslice-shae figure shall be filled in, producing a rounded corner.

  - :bevel

    The two segments shall be finished with butt caps (see `t:cap_style/0`) and the resulting notch beyond the ends of the segments shall be filled with a triangle.
  """
  @type join_style :: :miter | :round | :bevel | integer()

  @doc """
  Create a new Pdf document.

  The following options can be given:

  :size      |  Page size, defaults to `:a4`
  :compress  |  Compress the Pdf, default: `true`

  There is no standard font selected when creating a new PDF, so set one with `set_font/3` before adding text.
  """
  @spec new(any) :: Document.t()
  def new(opts \\ []), do: Document.new(opts)

  @doc """
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
  """
  def build(opts \\ [], func) do
    pdf = new(opts)
    func.(pdf)
  end

  @deprecated "Use build/2 instead"
  def open(opts \\ [], func) do
    build(opts, func)
  end

  @doc """
  No-op. Kept for backwards compatibility.
  """
  def cleanup(_document), do: :ok

  @deprecated "Use cleanup/1 instead"
  def delete(document), do: cleanup(document)

  @doc """
  The unit of measurement in a Pdf are points, where *1 point = 1/72 inch*.
  This means that a standard A4 page, 8.27 inch, translates to 595 points.
  """
  def points(x), do: x

  @doc "Convert the given value from picas to Pdf points"
  @spec picas(number()) :: number()
  def picas(x), do: x * 6

  @doc "Convert the given value from inches to Pdf points"
  @spec inches(number()) :: integer()
  def inches(x), do: round(x * 72)

  @doc "Convert the given value from cm to Pdf points"
  @spec cm(number()) :: integer()
  def cm(x), do: round(x * 72 / 2.54)

  @doc "Convert the given value from mm to Pdf points"
  @spec mm(number()) :: integer()
  def mm(x), do: round(x * 72 / 2.54 / 10)

  @spec pixels_to_points(pixels :: number(), dpi :: number()) :: integer()
  @doc "Convert the given value from pixels to Pdf points"
  def pixels_to_points(pixels, dpi \\ 300), do: round(pixels / dpi * 72)

  @doc "Write the PDF to the given path"
  def write_to(document, path) do
    File.write!(path, Document.to_iolist(document))
    document
  end

  @doc """
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
      "attachment; filename=\"document.pdf\""
    )
    |> send_resp(200, report)
  ```
  """
  def export(document) do
    :binary.list_to_bin(Document.to_iolist(document))
  end

  @doc """
  Add a new page to the Pdf with the given page size.
  """
  def add_page(document, size) do
    Document.add_page(document, size: size)
  end

  @doc """
  Adds an autoprint action to the Pdf.

  This is can be useful for generating a PDF that will automatically open the print dialog in a browser
  """
  def autoprint(document) do
    Document.autoprint(document)
  end

  @doc "Returns the current page number."
  def page_number(document) do
    Document.page_number(document)
  end

  @doc """
  Set the color to use when filling.

  This takes either a `Pdf.Color.color/1` atom, an RGB tuple or a CMYK tuple.
  """
  @spec set_fill_color(Document.t(), color_name | rgb | cmyk) :: Document.t()
  def set_fill_color(document, color), do: Document.set_fill_color(document, color)

  @doc """
  Set the color to use when drawing lines.

  This takes either a `Pdf.Color.color/1` atom, an RGB tuple or a CMYK tuple.
  """
  @spec set_stroke_color(Document.t(), color_name | rgb | cmyk) :: Document.t()
  def set_stroke_color(document, color), do: Document.set_stroke_color(document, color)

  @doc """
  The width to use when drawing lines.
  """
  @spec set_line_width(Document.t(), number) :: Document.t()
  def set_line_width(document, width), do: Document.set_line_width(document, width)

  @doc """
  The line endings to draw, see `t:cap_style/0`.
  """
  @spec set_line_cap(Document.t(), cap_style) :: Document.t()
  def set_line_cap(document, style), do: Document.set_line_cap(document, style)

  @doc """
  The join style to use where lines meet, see `t:join_style/0`.
  """
  @spec set_line_join(Document.t(), join_style) :: Document.t()
  def set_line_join(document, style), do: Document.set_line_join(document, style)

  @doc """
  Draw a rectangle from coordinates x,y (lower left corner) for a given width and height.
  """
  @spec rectangle(Document.t(), coords, dimension) :: Document.t()
  def rectangle(document, coords, dimensions),
    do: Document.rectangle(document, coords, dimensions)

  @doc """
  Draw a line between 2 points.
  """
  @spec line(Document.t(), coords, coords) :: Document.t()
  def line(document, coords, coords_to), do: Document.line(document, coords, coords_to)

  @doc """
  Move the cursor to the given coordinates.
  """
  @spec move_to(Document.t(), coords) :: Document.t()
  def move_to(document, coords), do: Document.move_to(document, coords)

  @doc """
  Draw a line from the last position to the given coordinates.
  ```elixir
    pdf
    |> Pdf.move_to({100, 100})
    |> Pdf.line_append({200, 200})
  ```
  """
  @spec line_append(Document.t(), coords) :: Document.t()
  def line_append(document, coords), do: Document.line_append(document, coords)

  @doc """
  Perform all the previous graphic commands.
  """
  @spec stroke(Document.t()) :: Document.t()
  def stroke(document), do: Document.stroke(document)

  @doc """
  Fill the current drawing with the previously set color.
  """
  @spec fill(Document.t()) :: Document.t()
  def fill(document), do: Document.fill(document)

  @doc """
  Set the fill opacity (0.0 fully transparent, 1.0 fully opaque).
  """
  @spec set_fill_opacity(Document.t(), number) :: Document.t()
  def set_fill_opacity(document, opacity), do: Document.set_fill_opacity(document, opacity)

  @doc """
  Set the stroke opacity (0.0 fully transparent, 1.0 fully opaque).
  """
  @spec set_stroke_opacity(Document.t(), number) :: Document.t()
  def set_stroke_opacity(document, opacity), do: Document.set_stroke_opacity(document, opacity)

  @doc """
  Set both fill and stroke opacity (0.0 fully transparent, 1.0 fully opaque).
  """
  @spec set_opacity(Document.t(), number) :: Document.t()
  def set_opacity(document, opacity), do: Document.set_opacity(document, opacity)

  @doc """
  Rotate the coordinate system by the given angle in degrees.
  Must be used within `save_state/restore_state`.
  """
  @spec rotate(Document.t(), number) :: Document.t()
  def rotate(document, angle), do: Document.rotate(document, angle)

  @doc """
  Translate (move) the coordinate origin by {tx, ty}.
  Must be used within `save_state/restore_state`.
  """
  @spec translate(Document.t(), {number, number}) :: Document.t()
  def translate(document, coords), do: Document.translate(document, coords)

  @doc """
  Scale the coordinate system by {sx, sy}.
  Must be used within `save_state/restore_state`.
  """
  @spec scale(Document.t(), {number, number}) :: Document.t()
  def scale(document, factors), do: Document.scale(document, factors)

  @doc """
  Apply an arbitrary transformation matrix {a, b, c, d, e, f}.
  Must be used within `save_state/restore_state`.
  """
  @spec transform(Document.t(), {number, number, number, number, number, number}) :: Document.t()
  def transform(document, matrix), do: Document.transform(document, matrix)

  @doc """
  Save the current graphics state. Use with `restore_state/1` to isolate
  transformations like rotation, translation, scaling, and opacity changes.
  """
  @spec save_state(Document.t()) :: Document.t()
  def save_state(%Document{current: page} = document) do
    %{document | current: Pdf.Page.save_state(page)}
  end

  @doc """
  Restore a previously saved graphics state.
  """
  @spec restore_state(Document.t()) :: Document.t()
  def restore_state(%Document{current: page} = document) do
    %{document | current: Pdf.Page.restore_state(page)}
  end

  @doc """
  Sets the font that will be used for all text from here on.
  You can either specify the font size, or a list of options:

  Option  |  Value  | Default
  :------ | :------ | :------
  `:size`   | integer | 10
  `:bold`   | boolean | false
  `:italic` | boolean | false
  """
  @spec set_font(Document.t(), binary, integer | list) :: Document.t()
  def set_font(document, font_name, opts) when is_list(opts) do
    font_size = Keyword.get(opts, :size, 16)
    set_font(document, font_name, font_size, Keyword.delete(opts, :size))
  end

  def set_font(document, font_name, font_size) when is_number(font_size) do
    set_font(document, font_name, font_size, [])
  end

  @doc false
  def set_font(document, font_name, font_size, opts) do
    Document.set_font(document, font_name, font_size, opts)
  end

  @doc """
  Sets the font size.

  The font has to have been previously set!
  """
  def set_font_size(document, size) do
    Document.set_font_size(document, size)
  end

  @doc """
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
  """
  def add_font(document, path) do
    Document.add_external_font(document, path)
  end

  @doc """
  Leading is a typography term that describes the distance between each line of text. The name comes from a time when typesetting was done by hand and pieces of lead were used to separate the lines.

  Today, leading is often used synonymously with "line height" or "line spacing."
  """
  def set_text_leading(document, leading) do
    Document.set_text_leading(document, leading)
  end

  @doc """
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
  """
  def text_at(document, coords, text) do
    text_at(document, coords, text, [])
  end

  @doc """
  Writes the text at the given coordinates.
  The coordinates are the bottom left of the text.

  Accepts either a keyword list of options or a style map/atom:

      pdf |> Pdf.text_at({300, 730}, "BILL TO", %{bold: true, color: :gray})
      pdf |> Pdf.text_at({300, 730}, "BILL TO", :label)
      pdf |> Pdf.text_at({300, 730}, "BILL TO", kerning: true)
  """
  def text_at(document, coords, text, style_or_opts)
      when is_map(style_or_opts) or is_atom(style_or_opts) do
    style = document |> resolve_style(style_or_opts) |> Pdf.Style.new()

    document
    |> set_font(style.font, style.font_size, bold: style.bold, italic: style.italic)
    |> set_fill_color(style.color)
    |> Document.text_at(coords, text, Pdf.Style.to_opts(style))
  end

  def text_at(document, coords, text, opts) when is_list(opts) do
    Document.text_at(document, coords, text, opts)
  end

  @doc """
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
  """
  @spec text_wrap(Document.t(), coords(), dimension(), binary | list) ::
          {Document.t(), :complete | term()}
  def text_wrap(document, coords, dimensions, text) do
    text_wrap(document, coords, dimensions, text, [])
  end

  @doc """
  This function has the same options as `text_wrap/4`, but also supports additional options that will be applied to the complete text.

  Option  |  Value  | Default
  :------ | :------ | :------
  `:align` | :left , :center , :right | :left
  `:kerning` | `boolean` | false
  """
  @spec text_wrap(Document.t(), coords(), dimension(), binary | list, keyword) ::
          {Document.t(), :complete | term()}
  def text_wrap(document, coords, dimensions, text, opts) do
    Document.text_wrap(document, coords, dimensions, text, opts)
  end

  @doc """
  This function has the same options as `text_wrap/4`, but if the text is too large for the box, a `RuntimeError` will be raised.
  """
  @spec text_wrap!(Document.t(), coords(), dimension(), binary | list) :: Document.t()
  def text_wrap!(document, coords, dimensions, text) do
    text_wrap!(document, coords, dimensions, text, [])
  end

  @doc """
  This function has the same options as `text_wrap/5`, but if the text is too large for the box, a `RuntimeError` will be raised.
  """
  @spec text_wrap!(Document.t(), coords(), dimension(), binary | list, keyword) :: Document.t()
  def text_wrap!(document, coords, dimensions, text, opts) do
    Document.text_wrap!(document, coords, dimensions, text, opts)
  end

  @doc """
  This function draws a number of text lines starting at the given coordinates.
  The list can overrun the page, no errors or wrapping will occur.

  Kerning can be set, see `text_at/4` for more information.
  """
  @spec text_lines(Document.t(), coords(), list, keyword) :: Document.t()
  def text_lines(document, coords, lines, opts \\ []) do
    Document.text_lines(document, coords, lines, opts)
  end

  @doc """
  Add a table in the document at the given coordinates.

  See [Tables](tables.html) for more information on how to use tables.
  """
  def table(document, coords, dimensions, data, opts \\ []) do
    Document.table(document, coords, dimensions, data, opts)
  end

  @doc """
  Add a table in the document at the given coordinates.
  Raises an exception if the table does not fit the dimensions.

  See [Tables](tables.html) for more information on how to use tables.
  """
  def table!(document, coords, dimensions, data, opts \\ []) do
    Document.table!(document, coords, dimensions, data, opts)
  end

  @doc """
  Add an images (PNG, or JPEG only) at the given coordinates.
  """
  def add_image(document, coords, image_path), do: add_image(document, coords, image_path, [])

  @doc """
  Add an images (PNG, or JPEG only) at the given coordinates.

  You can specify a `:width` and `:height` in the options, the image will then be scaled.
  """
  def add_image(document, coords, image_path, opts) do
    Document.add_image(document, coords, image_path, opts)
  end

  @doc """
  Register a page template that runs on every new page.

  Supported template names: `:header`, `:footer`, `:watermark`, `:background`.

  The function receives `(document, page_info)` where `page_info` is `%{number: n}`.

  ## Example

      pdf
      |> Pdf.on_page(:header, fn doc, _info ->
        Pdf.text_at(doc, {40, 820}, "My Header")
      end)
  """
  def on_page(document, name, func) do
    Document.on_page(document, name, func)
  end

  @doc """
  Returns the content area `%{x, y, width, height}` based on margins.
  """
  def content_area(document) do
    Document.content_area(document)
  end

  @doc """
  Returns a `{width, height}` for the current page.
  """
  def size(document) do
    Document.size(document)
  end

  @doc """
  Gets the current cursor Y position (vertical).
  """
  @spec cursor(Document.t()) :: number
  def cursor(document) do
    Document.cursor(document)
  end

  @doc """
  Gets the current cursor position as `%{x: x, y: y}`.
  """
  @spec cursor_xy(Document.t()) :: %{x: number, y: number}
  def cursor_xy(document) do
    Document.cursor_xy(document)
  end

  @doc """
  Set the cursor Y position.
  """
  @spec set_cursor(Document.t(), number) :: Document.t()
  def set_cursor(document, y) do
    Document.set_cursor(document, y)
  end

  @doc """
  Set the cursor X position.
  """
  @spec set_cursor_x(Document.t(), number) :: Document.t()
  def set_cursor_x(document, x) do
    Document.set_cursor_x(document, x)
  end

  @doc """
  Move the cursor `amount` points down.
  """
  @spec move_down(Document.t(), number) :: Document.t()
  def move_down(document, amount) do
    Document.move_down(document, amount)
  end

  @doc """
  Move the cursor `amount` points to the right.
  """
  @spec move_right(Document.t(), number) :: Document.t()
  def move_right(document, amount) do
    Document.move_right(document, amount)
  end

  @doc """
  Reset the cursor X position to 0.
  """
  @spec reset_x(Document.t()) :: Document.t()
  def reset_x(document) do
    Document.reset_x(document)
  end

  @doc """
  Register a named style that can be referenced by atom in text/3, horizontal_line/2, etc.

  ## Example

      pdf
      |> Pdf.register_style(:heading, %{font_size: 24, bold: true, color: :navy})
      |> Pdf.register_style(:body, %{font_size: 12, color: :black})
      |> Pdf.register_style(:accent, %{font_size: 12, color: :green})
      |> Pdf.text("My Title", :heading)
      |> Pdf.text("Body text", :body)
  """
  def register_style(document, name, style_attrs) when is_atom(name) and is_map(style_attrs) do
    %{document | styles: Map.put(document.styles, name, style_attrs)}
  end

  @doc """
  Register multiple named styles at once from a map.

  ## Example

      Pdf.register_styles(pdf, %{
        heading: %{font_size: 24, bold: true, color: :navy},
        body: %{font_size: 12},
        footer: %{font_size: 8, color: :gray}
      })
  """
  def register_styles(document, styles) when is_map(styles) do
    %{document | styles: Map.merge(document.styles, styles)}
  end

  @doc false
  def resolve_style(document, name) when is_atom(name) do
    Map.get(document.styles, name, %{})
  end

  def resolve_style(_document, style_attrs) when is_map(style_attrs), do: style_attrs
  def resolve_style(_document, nil), do: %{}

  @doc """
  Draw a rounded rectangle.
  """
  def rounded_rectangle(document, xy, wh, r) do
    Document.rounded_rectangle(document, xy, wh, r)
  end

  @doc """
  Fill and stroke the current path.
  """
  def fill_and_stroke(document) do
    Document.fill_and_stroke(document)
  end

  @doc """
  Set the current path as a clipping boundary.
  """
  def clip(document) do
    Document.clip(document)
  end

  # ── Debug ────────────────────────────────────────────────────────

  @doc """
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
  """
  def debug_grid(document, opts \\ %{}) do
    grid = Map.get(opts, :grid, :both)
    grid_area = Map.get(opts, :area, :content)
    step = Map.get(opts, :spacing, Map.get(opts, :step, 10))
    color = Map.get(opts, :color, {0.85, 0.85, 0.85})
    lw = Map.get(opts, :line_width, 0.25)
    labels = Map.get(opts, :labels, true)
    label_step = Map.get(opts, :label_every, Map.get(opts, :label_step, 50))
    info = Map.get(opts, :info, true)
    margin_border = Map.get(opts, :margin_border, true)
    cursor_line = Map.get(opts, :cursor_line, true)

    page_size = size(document)
    content = content_area(document)
    cur = cursor(document)
    margin = document.margin

    # Content bounds
    cx0 = content.x
    cy0 = margin.bottom
    cx1 = content.x + content.width
    cy1 = page_size.height - margin.top

    # Page bounds
    px0 = 0
    py0 = 0
    px1 = page_size.width
    py1 = page_size.height

    # Draw grid based on area option
    document =
      case grid_area do
        :page ->
          document
          |> draw_debug_lines(grid, step, color, lw, {px0, py0}, {px1, py1})

        :content ->
          document
          |> save_state()
          |> Document.rectangle({cx0, cy0}, {cx1 - cx0, cy1 - cy0})
          |> clip()
          |> draw_debug_lines(grid, step, color, lw, {cx0, cy0}, {cx1, cy1})
          |> restore_state()

        :margins ->
          # Draw grid only in margin areas (clip OUT the content area)
          # Top margin
          document
          |> draw_debug_lines_in_rect(grid, step, color, lw, {px0, cy1}, {px1, py1})
          # Bottom margin
          |> draw_debug_lines_in_rect(grid, step, color, lw, {px0, py0}, {px1, cy0})
          # Left margin
          |> draw_debug_lines_in_rect(grid, step, color, lw, {px0, cy0}, {cx0, cy1})
          # Right margin
          |> draw_debug_lines_in_rect(grid, step, color, lw, {cx1, cy0}, {px1, cy1})
      end

    # Labels
    document =
      if labels do
        {lx0, ly0, lx1, ly1} =
          case grid_area do
            :page -> {px0, py0, px1, py1}
            _ -> {cx0, cy0, cx1, cy1}
          end

        document
        |> save_state()
        |> set_font("Helvetica", 6)
        |> set_fill_color({0.5, 0.5, 0.5})
        |> draw_grid_labels(lx0, lx1, ly0, ly1, label_step, grid)
        |> restore_state()
      else
        document
      end

    # Margin boundary rectangle
    document =
      if margin_border do
        document
        |> save_state()
        |> set_stroke_color({1.0, 0.4, 0.4})
        |> set_line_width(0.5)
        |> Document.rectangle({cx0, cy0}, {cx1 - cx0, cy1 - cy0})
        |> Document.stroke()
        |> restore_state()
      else
        document
      end

    # Cursor Y line
    document =
      if cursor_line do
        document
        |> save_state()
        |> set_stroke_color({0.2, 0.6, 1.0})
        |> set_line_width(0.5)
        |> Document.line({cx0, cur}, {cx1, cur})
        |> Document.stroke()
        |> restore_state()
      else
        document
      end

    # Info text
    if info do
      info_text =
        "margins: T=#{margin.top} R=#{margin.right} B=#{margin.bottom} L=#{margin.left} | " <>
          "page: #{page_size.width}x#{page_size.height} | " <>
          "content: #{content.width}x#{round(cy1 - cy0)} | cursor_y: #{round(cur)}"

      document
      |> save_state()
      |> set_font("Helvetica", 7)
      |> set_fill_color({0.6, 0.3, 0.3})
      |> text_at({cx0, cy1 + 3}, info_text)
      |> restore_state()
    else
      document
    end
  end

  defp draw_debug_lines(document, grid, step, color, lw, {x0, y0}, {x1, y1}) do
    document =
      document
      |> save_state()
      |> set_stroke_color(color)
      |> set_line_width(lw)

    document =
      if grid in [:vertical, :both] do
        Stream.iterate(x0, &(&1 + step))
        |> Enum.take_while(&(&1 <= x1))
        |> Enum.reduce(document, fn x, doc ->
          doc |> Document.line({x, y0}, {x, y1}) |> Document.stroke()
        end)
      else
        document
      end

    document =
      if grid in [:horizontal, :both] do
        Stream.iterate(y0, &(&1 + step))
        |> Enum.take_while(&(&1 <= y1))
        |> Enum.reduce(document, fn y, doc ->
          doc |> Document.line({x0, y}, {x1, y}) |> Document.stroke()
        end)
      else
        document
      end

    restore_state(document)
  end

  defp draw_debug_lines_in_rect(document, grid, step, color, lw, {rx0, ry0}, {rx1, ry1}) do
    w = rx1 - rx0
    h = ry1 - ry0

    if w <= 0 or h <= 0 do
      document
    else
      document
      |> save_state()
      |> Document.rectangle({rx0, ry0}, {w, h})
      |> clip()
      |> draw_debug_lines(grid, step, color, lw, {rx0, ry0}, {rx1, ry1})
      |> restore_state()
    end
  end

  defp draw_grid_labels(document, x0, x1, y0, y1, label_step, grid) do
    document =
      if grid in [:vertical, :both] do
        Stream.iterate(x0, &(&1 + label_step))
        |> Enum.take_while(&(&1 <= x1))
        |> Enum.reduce(document, fn x, doc ->
          text_at(doc, {x + 1, y0 + 2}, "#{round(x)}")
        end)
      else
        document
      end

    if grid in [:horizontal, :both] do
      Stream.iterate(y0, &(&1 + label_step))
      |> Enum.take_while(&(&1 <= y1))
      |> Enum.reduce(document, fn y, doc ->
        text_at(doc, {x0 + 1, y + 1}, "#{round(y)}")
      end)
    else
      document
    end
  end

  # ── High-level styled components ──────────────────────────────────

  @doc """
  Render a styled table at the current cursor position.

  ## Example

      Pdf.styled_table(doc, [
        ["Name", "Qty", "Price"],
        ["Widget", "5", "$10.00"]
      ], %{
        columns: [%{width: 200}, %{width: 80, align: :center}, %{width: 120, align: :right}],
        header: %{bold: true, background: {0.2, 0.3, 0.5}, color: :white, padding: 8},
        row: %{padding: 6, border_bottom: 0.5},
        alt_row: %{background: {0.95, 0.95, 1.0}},
        border: 1,
        border_radius: 6
      })
  """
  def styled_table(document, data, opts \\ %{}) do
    Pdf.StyledTable.render(document, data, opts)
  end

  @doc """
  Write styled text at the current cursor position with auto-wrapping.
  Moves the cursor down after writing.

  ## Example

      pdf |> Pdf.text("Hello world")
      pdf |> Pdf.text("Bold red", %{bold: true, color: :red, font_size: 16})
  """
  def text(document, string, style_or_name \\ %{}) do
    style = document |> resolve_style(style_or_name) |> Pdf.Style.new()

    document =
      document
      |> set_font(style.font, style.font_size, bold: style.bold, italic: style.italic)
      |> set_fill_color(style.color)

    if style.x != nil and style.y != nil do
      # Absolute positioning — render at {x, y} without wrapping or cursor movement
      Document.text_at(document, {style.x, style.y}, string, Pdf.Style.to_opts(style))
    else
      area = content_area(document)
      pos = cursor_xy(document)

      {document, _remaining} =
        Document.text_wrap(
          document,
          {pos.x, pos.y},
          {area.width, pos.y - document.margin.bottom},
          string,
          Pdf.Style.to_opts(style)
        )

      document
    end
  end

  @doc """
  Draw a horizontal line at the current cursor position across the content width.

  ## Example

      pdf |> Pdf.horizontal_line()
      pdf |> Pdf.horizontal_line(%{color: :gray, line_width: 0.5})
  """
  def horizontal_line(document, style_or_name \\ %{}) do
    style = document |> resolve_style(style_or_name) |> Pdf.Style.new()
    area = content_area(document)
    pos = cursor_xy(document)

    document
    |> Document.set_stroke_color(style.stroke_color)
    |> Document.set_line_width(style.line_width)
    |> Document.line({area.x, pos.y}, {area.x + area.width, pos.y})
    |> Document.stroke()
    |> Document.move_down(style.line_width + 2)
  end

  @doc """
  Add vertical space by moving the cursor down.

  ## Example

      pdf |> Pdf.spacer(20)
  """
  def spacer(document, amount) when is_number(amount) do
    Document.move_down(document, amount)
  end

  @doc """
  Insert a page break. Executes footer template on the current page
  and header/watermark templates on the new page.

  ## Example

      pdf |> Pdf.page_break()
      pdf |> Pdf.page_break(:letter)
  """
  def page_break(document, size \\ nil) do
    page_size = size || Keyword.get(document.opts, :size, :a4)
    Document.add_page(document, size: page_size)
  end

  @doc """
  Add a text watermark to the current page with rotation and opacity.

  ## Example

      pdf |> Pdf.watermark("DRAFT", %{opacity: 0.1, rotate: 45, font_size: 60, color: :gray})
  """
  def watermark(document, text, style_or_name \\ %{}) do
    defaults = %{opacity: 0.15, rotate: 45, font_size: 60, color: :gray}
    attrs = document |> resolve_style(style_or_name)
    style = Pdf.Style.new(Map.merge(defaults, attrs))
    %{width: pw, height: ph} = size(document)

    document
    |> save_state()
    |> set_fill_opacity(style.opacity)
    |> set_fill_color(style.color)
    |> set_font(style.font, style.font_size, bold: style.bold, italic: style.italic)
    |> translate({pw / 2, ph / 2})
    |> rotate(style.rotate)
    |> text_at({0, 0}, text)
    |> restore_state()
  end

  @doc """
  Fill the current page background with a color.

  ## Example

      pdf |> Pdf.background(%{color: {0.95, 0.95, 1.0}})
  """
  def background(document, style_or_name \\ %{}) do
    style = document |> resolve_style(style_or_name) |> Pdf.Style.new()
    %{width: pw, height: ph} = size(document)

    case style.background do
      nil ->
        document

      color ->
        document
        |> save_state()
        |> set_fill_color(color)
        |> Document.rectangle({0, 0}, {pw, ph})
        |> fill()
        |> restore_state()
    end
  end

  @doc """
  Sets the author in the PDF information section.
  """
  def set_author(document, author), do: set_info(document, :author, author)

  @doc """
  Sets the creator in the PDF information section.
  """
  def set_creator(document, creator), do: set_info(document, :creator, creator)

  @doc """
  Sets the keywords in the PDF information section.
  """
  def set_keywords(document, keywords), do: set_info(document, :keywords, keywords)

  @doc """
  Sets the producer in the PDF information section.
  """
  def set_producer(document, producer), do: set_info(document, :producer, producer)

  @doc """
  Sets the subject in the PDF information section.
  """
  def set_subject(document, subject), do: set_info(document, :subject, subject)

  @doc """
  Sets the title in the PDF information section.
  """
  def set_title(document, title), do: set_info(document, :title, title)

  @doc """
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
  """
  @typedoc false
  @type info_list :: keyword
  @spec set_info(Document.t(), info_list) :: Document.t()
  def set_info(document, info_list) do
    Document.put_info(document, info_list)
  end

  defp set_info(document, key, value) do
    Document.put_info(document, key, value)
  end
end
