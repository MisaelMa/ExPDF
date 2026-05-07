defmodule Pdf.Page do
  @moduledoc false
  defstruct size: :a4,
            stream: nil,
            fonts: nil,
            objects: nil,
            current_font: nil,
            current_font_size: 0,
            fill_color: :black,
            leading: nil,
            cursor: 0,
            cursor_x: 0,
            in_text: false,
            saved: %{},
            saving_state: false,
            ext_g_states: %{}

  defdelegate table(page, data, xy, wh), to: Pdf.Table
  defdelegate table(page, data, xy, wh, opts), to: Pdf.Table
  defdelegate table!(page, data, xy, wh), to: Pdf.Table
  defdelegate table!(page, data, xy, wh, opts), to: Pdf.Table

  import Pdf.Utils
  alias Pdf.{Image, Fonts, GraphicsState, Stream, Text, Font}

  def new(opts \\ [size: :a4]), do: init(opts, %__MODULE__{stream: Stream.new()})

  defp init([], page), do: page
  defp init([{:fonts, fonts} | tail], page), do: init(tail, %{page | fonts: fonts})
  defp init([{:objects, objects} | tail], page), do: init(tail, %{page | objects: objects})

  defp init([{:size, size} | tail], page) do
    [_bottom, _left, _width, height] = Pdf.Paper.size(size)
    init(tail, %{page | size: size, cursor: height})
  end

  defp init([{:compress, false} | tail], page),
    do: init(tail, %{page | stream: Stream.new(compress: false)})

  defp init([{:compress, true} | tail], page),
    do: init(tail, %{page | stream: Stream.new(compress: 6)})

  defp init([{:compress, level} | tail], page),
    do: init(tail, %{page | stream: Stream.new(compress: level)})

  defp init([_ | tail], page), do: init(tail, page)

  def push(page, command), do: %{page | stream: Stream.push(page.stream, command)}

  def set_fill_color(%{fill_color: color} = page, color), do: page

  def set_fill_color(%{saving_state: true} = page, color) do
    push(page, color_command(color, fill_command(color)))
  end

  def set_fill_color(page, color) do
    push(%{page | fill_color: color}, color_command(color, fill_command(color)))
  end

  def set_stroke_color(page, color) do
    push(page, color_command(color, stroke_command(color)))
  end

  def set_line_width(page, width) do
    push(page, [width, "w"])
  end

  def set_line_cap(page, style) do
    push(page, [line_cap(style), "J"])
  end

  defp line_cap(:butt), do: 0
  defp line_cap(:round), do: 1
  defp line_cap(:projecting_square), do: 2
  defp line_cap(:square), do: 2
  defp line_cap(style), do: style

  def set_line_join(page, style) do
    push(page, [line_join(style), "j"])
  end

  defp line_join(:miter), do: 0
  defp line_join(:round), do: 1
  defp line_join(:bevel), do: 2
  defp line_join(style), do: style

  def rectangle(page, {x, y}, {w, h}) do
    push(page, [x, y, w, h, "re"])
  end

  def curve_to(page, {x1, y1}, {x2, y2}, {x3, y3}) do
    push(page, [x1, y1, x2, y2, x3, y3, "c"])
  end

  @kappa 0.5522847498
  def rounded_rectangle(page, {x, y}, {w, h}, r) when r <= 0 do
    rectangle(page, {x, y}, {w, h})
  end

  def rounded_rectangle(page, {x, y}, {w, h}, r) do
    r = min(r, min(w / 2, h / 2))
    k = r * @kappa

    page
    |> move_to({x + r, y})
    |> line_append({x + w - r, y})
    |> curve_to({x + w - r + k, y}, {x + w, y + r - k}, {x + w, y + r})
    |> line_append({x + w, y + h - r})
    |> curve_to({x + w, y + h - r + k}, {x + w - r + k, y + h}, {x + w - r, y + h})
    |> line_append({x + r, y + h})
    |> curve_to({x + r - k, y + h}, {x, y + h - r + k}, {x, y + h - r})
    |> line_append({x, y + r})
    |> curve_to({x, y + r - k}, {x + r - k, y}, {x + r, y})
    |> close_path()
  end

  def close_path(page) do
    push(page, ["h"])
  end

  def fill_and_stroke(page) do
    push(page, ["B"])
  end

  def clip(page) do
    push(page, ["W", "n"])
  end

  def line(page, {x, y}, {x2, y2}) do
    page
    |> move_to({x, y})
    |> line_append({x2, y2})
  end

  def move_to(page, {x, y}) do
    push(page, [x, y, "m"])
  end

  def line_append(page, {x, y}) do
    push(page, [x, y, "l"])
  end

  def stroke(page) do
    push(page, ["S"])
  end

  def fill(page) do
    push(page, ["f"])
  end

  def set_fill_opacity(page, opacity) when is_number(opacity) do
    register_and_apply_gs(page, fill_opacity: opacity)
  end

  def set_stroke_opacity(page, opacity) when is_number(opacity) do
    register_and_apply_gs(page, stroke_opacity: opacity)
  end

  def set_opacity(page, opacity) when is_number(opacity) do
    register_and_apply_gs(page, fill_opacity: opacity, stroke_opacity: opacity)
  end

  defp register_and_apply_gs(page, opts) do
    gs_key = GraphicsState.key(opts)

    {gs_name, page} =
      case Map.get(page.ext_g_states, gs_key) do
        nil ->
          id = map_size(page.ext_g_states) + 1
          gs_name = n("GS#{id}")
          gs_dict = GraphicsState.new(opts)

          page = %{
            page
            | ext_g_states: Map.put(page.ext_g_states, gs_key, %{name: gs_name, dict: gs_dict})
          }

          {gs_name, page}

        %{name: gs_name} ->
          {gs_name, page}
      end

    push(page, [gs_name, "gs"])
  end

  def rotate(page, angle_degrees) do
    rad = angle_degrees * :math.pi() / 180
    cos = :math.cos(rad)
    sin = :math.sin(rad)
    push(page, [cos, sin, -sin, cos, 0, 0, "cm"])
  end

  def translate(page, {tx, ty}) do
    push(page, [1, 0, 0, 1, tx, ty, "cm"])
  end

  def scale(page, {sx, sy}) do
    push(page, [sx, 0, 0, sy, 0, 0, "cm"])
  end

  def transform(page, {a, b, c, d, e, f}) do
    push(page, [a, b, c, d, e, f, "cm"])
  end

  def set_font(%{fonts: fonts, objects: objects} = page, name, size, opts \\ []) do
    {font, fonts, objects} = Fonts.get_font(fonts, objects, name, opts)
    page = %{page | fonts: fonts, objects: objects}
    push_font(page, font, size)
  end

  defp push_font(%{current_font: font, current_font_size: size} = page, font, size), do: page

  defp push_font(%{in_text: true} = page, font, size) do
    push(%{page | current_font: font, current_font_size: size}, [font.name, size, "Tf"])
  end

  defp push_font(page, font, size) do
    %{page | current_font: font, current_font_size: size}
  end

  def set_font_size(page, size) do
    push_font_size(page, size)
  end

  defp push_font_size(%{current_font_size: size} = page, size), do: page

  defp push_font_size(%{in_text: true, current_font: font} = page, size) do
    push(%{page | current_font_size: size}, [font.name, size, "Tf"])
  end

  defp push_font_size(page, size) do
    %{page | current_font_size: size}
  end

  def set_text_leading(page, leading) do
    %{page | leading: leading}
  end

  defp begin_text(page) do
    %{current_font: font, current_font_size: size, leading: leading, fill_color: fill_color} =
      page

    %{
      page
      | in_text: true,
        saved: %{
          current_font: font,
          current_font_size: size,
          leading: leading,
          fill_color: fill_color
        }
    }
    |> push(["BT"])
    |> push([font.name, size, "Tf"])
  end

  defp end_text(%{in_text: true, saved: saved} = page) do
    page =
      page
      |> set_text_leading(Map.get(saved, :leading))
      |> set_fill_color(Map.get(saved, :fill_color))

    push(
      %{
        page
        | in_text: false,
          current_font: Map.get(saved, :current_font),
          current_font_size: Map.get(saved, :current_font_size),
          saved: %{}
      },
      ["ET"]
    )
  end

  def text_at(page, xy, text, opts \\ [])

  def text_at(page, {x, y}, attributed_text, opts) when is_list(attributed_text) do
    {attributed_text, page} = annotate_attributed_text(attributed_text, page, opts)

    page
    |> begin_text()
    |> push([x, y, "Td"])
    |> print_attributed_line(attributed_text)
    |> end_text()
    |> set_cursor(y - line_height(page, attributed_text))
  end

  def text_at(page, xy, text, opts) do
    text_at(page, xy, [text], opts)
  end

  defp merge_same_opts([]), do: []

  defp merge_same_opts([{text, width, opts}, {text2, width2, opts} | tail]) do
    merge_same_opts([{text <> text2, width + width2, opts} | tail])
  end

  defp merge_same_opts([chunk | tail]) do
    [chunk | merge_same_opts(tail)]
  end

  def annotate_attributed_text(nil, page, opts) do
    annotate_attributed_text([""], page, opts)
  end

  def annotate_attributed_text(text, page, opts) when is_binary(text) do
    annotate_attributed_text([text], page, opts)
  end

  def annotate_attributed_text({:continue, _} = continue, page, _opts) do
    {continue, page}
  end

  def annotate_attributed_text(
        attributed_text,
        %{fonts: fonts, objects: objects, current_font: %{module: font}} = page,
        overall_opts
      )
      when is_list(attributed_text) do
    {result, fonts, objects} =
      attributed_text
      |> Enum.map(fn
        str when is_binary(str) -> {str, []}
        {str} -> {str, []}
        {str, opts} -> {str, opts}
        annotated -> annotated
      end)
      |> Enum.reduce({[], fonts, objects}, fn item, {acc, fonts, objects} ->
        case item do
          {text, width, opts} ->
            {[{text, width, opts} | acc], fonts, objects}

          {text, opts} ->
            opts = Keyword.merge(overall_opts, opts)

            {font_ref, fonts, objects} =
              if Enum.any?([:bold, :italic], &Keyword.has_key?(opts, &1)) do
                Fonts.get_font(fonts, objects, font, Keyword.take(opts, [:bold, :italic]))
              else
                Fonts.get_font(fonts, objects, font.name, [])
              end

            font_size = Keyword.get(opts, :font_size, page.current_font_size)
            leading = Keyword.get(opts, :leading, page.leading || page.current_font_size)
            color = Keyword.get(opts, :color, page.fill_color)

            height = Enum.max([leading, font_size])
            ascender = font_ref.module.ascender * font_size / 1000
            descender = -(font_ref.module.descender * font_size / 1000)
            cap_height = (font_ref.module.cap_height || 0) * font_size / 1000
            x_height = (font_ref.module.x_height || 0) * font_size / 1000
            line_gap = (font_size - (ascender + descender)) / 2

            width = Font.text_width(font_ref.module, text, font_size, opts)

            annotated =
              {text, width,
               Keyword.merge(
                 overall_opts,
                 Keyword.merge(opts,
                   ascender: ascender,
                   cap_height: cap_height,
                   color: color,
                   descender: descender,
                   font: font_ref,
                   height: height,
                   line_gap: line_gap,
                   font_size: font_size,
                   leading: leading,
                   x_height: x_height
                 )
               )}

            {[annotated | acc], fonts, objects}
        end
      end)

    {Enum.reverse(result), %{page | fonts: fonts, objects: objects}}
  end

  def annotate_attributed_text(attributed_text, %{current_font: nil} = _page, _overall_opts)
      when is_list(attributed_text) do
    raise RuntimeError, "No font selected"
  end

  def annotate_attributed_text(non_string, page, overall_opts) do
    annotate_attributed_text(to_string(non_string), page, overall_opts)
  end

  def text_wrap!(page, xy, wh, text, opts \\ []) do
    case text_wrap(page, xy, wh, text, opts) do
      {page, :complete} -> page
      _ -> raise(RuntimeError, "The supplied text did not fit within the supplied boundary")
    end
  end

  def text_wrap(page, xy, wh, text, opts \\ [])

  def text_wrap(page, {x, :cursor}, wh, text, opts) do
    y = cursor(page)
    text_wrap(page, {x, y}, wh, text, opts)
  end

  def text_wrap(page, {x, y}, {w, h}, text, opts)
      when is_binary(text) do
    text_wrap(page, {x, y}, {w, h}, [text], opts)
  end

  def text_wrap(page, {x, y}, {w, h}, {:continue, [{:line, _line} | _] = lines}, opts) do
    text_wrap(page, {x, y}, {w, h}, lines, opts)
  end

  def text_wrap(page, {x, y}, {w, h}, [{:line, _line} | _] = lines, opts) do
    page
    |> begin_text()
    |> set_cursor(y)
    |> print_attributed_lines(lines, x, y, w, h, opts)
    |> complete_wrapping()
  end

  def text_wrap(page, {x, y}, {w, h}, {:continue, chunks}, opts) do
    page
    |> begin_text()
    |> set_cursor(y)
    |> print_attributed_chunks(chunks, x, y, w, h, opts)
    |> complete_wrapping()
  end

  def text_wrap(page, {x, y}, {w, h}, attributed_text, opts) when is_list(attributed_text) do
    {attributed_text, page} = annotate_attributed_text(attributed_text, page, opts)

    chunks = Text.chunk_attributed_text(attributed_text, opts)

    page
    |> begin_text()
    |> set_cursor(y)
    |> print_attributed_chunks(chunks, x, y, w, h, opts)
    |> complete_wrapping()
  end

  def complete_wrapping({page, []}) do
    {end_text(page), :complete}
  end

  def complete_wrapping({page, [_ | _] = remaining}) do
    {end_text(page), {:continue, remaining}}
  end

  defp line_height(page, attributed_text) do
    line_height = attributed_text |> Enum.map(&Keyword.get(elem(&1, 2), :height)) |> Enum.max()
    Enum.max(Enum.filter([page.leading, line_height], & &1))
  end

  defp print_attributed_chunks(page, chunks, x, y, width, height, opts, prev_line_height \\ 0)

  defp print_attributed_chunks(page, [], _, _, _, _, _, _), do: {page, []}

  defp print_attributed_chunks(page, chunks, x, y, width, height, opts, prev_line_height) do
    {line, tail} =
      case Text.wrap_chunks(chunks, width) do
        {[], [line | tail]} ->
          {[line], tail}

        other ->
          other
      end

    line_width = Enum.reduce(line, 0, fn {_, width, _}, acc -> width + acc end)

    line_height =
      page.leading || line |> Enum.map(&Keyword.get(elem(&1, 2), :height)) |> Enum.max()

    if line_height > height do
      # No available vertical space to print the line so return remaining lines
      {page, chunks}
    else
      x_offset =
        case Keyword.get(opts, :align, :left) do
          :left -> x
          :center -> x + (width - line_width) / 2
          :right -> x + (width - line_width)
        end

      ascender =
        line
        |> Enum.map(&Keyword.get(elem(&1, 2), :ascender))
        |> Enum.max()

      line_gap =
        line
        |> Enum.map(&Keyword.get(elem(&1, 2), :line_gap))
        |> Enum.max()

      y_offset = if prev_line_height == 0, do: y - (ascender + line_gap), else: -prev_line_height

      page
      |> push([x_offset, y_offset, "Td"])
      |> print_attributed_line(line)
      |> move_down(line_height)
      |> print_attributed_chunks(
        tail,
        x - x_offset,
        y - line_height,
        width,
        height - line_height,
        opts,
        line_height
      )
    end
  end

  defp print_attributed_lines(page, lines, x, y, width, height, opts, prev_line_height \\ 0)

  defp print_attributed_lines(page, [], _x, _y, _width, _height, _opts, _prev_line_height),
    do: {page, []}

  defp print_attributed_lines(
         page,
         [{:line, line} | lines],
         x,
         y,
         width,
         height,
         opts,
         prev_line_height
       ) do
    line_width = Enum.reduce(line, 0, fn {_, width, _}, acc -> width + acc end)

    line_height =
      page.leading || line |> Enum.map(&Keyword.get(elem(&1, 2), :height)) |> Enum.max()

    if line_height > height do
      # No available vertical space to print the line so return remaining lines
      {page, [line | lines]}
    else
      x_offset =
        case Keyword.get(opts, :align, :left) do
          :left -> x
          :center -> x + (width - line_width) / 2
          :right -> x + (width - line_width)
        end

      ascender =
        line
        |> Enum.map(&Keyword.get(elem(&1, 2), :ascender))
        |> Enum.max()

      line_gap =
        line
        |> Enum.map(&Keyword.get(elem(&1, 2), :line_gap))
        |> Enum.max()

      y_offset = if prev_line_height == 0, do: y - (ascender + line_gap), else: -prev_line_height

      page
      |> push([x_offset, y_offset, "Td"])
      |> print_attributed_line(line)
      |> move_down(line_height)
      |> print_attributed_lines(
        lines,
        x - x_offset,
        y - line_height,
        width,
        height - line_height,
        opts,
        line_height
      )
    end
  end

  defp print_attributed_line(page, attributed_text) do
    attributed_text
    |> merge_same_opts
    |> Enum.reduce(page, fn {text, _width, opts}, page ->
      page
      |> push_font(opts[:font], opts[:font_size])
      |> set_text_leading(opts[:leading])
      |> set_fill_color(opts[:color])
      |> push(kerned_text(opts[:font].module, text, opts))
    end)
  end

  def text_lines(page, xy, lines, opts \\ [])

  def text_lines(page, _xy, [], _opts), do: page

  def text_lines(page, {x, y}, lines, opts) do
    leading = page.leading || page.current_font_size

    page
    |> begin_text()
    |> push([x, y, "Td"])
    |> push([leading, "TL"])
    |> draw_lines(lines, opts)
    |> end_text()
  end

  def add_image(page, {x, y}, image, opts \\ []) do
    %{name: image_name, image: %Image{width: width, height: height}} = image
    scaled_width = Keyword.get(opts, :width, width) / width
    scaled_height = Keyword.get(opts, :height, height) / height
    width = Keyword.get(opts, :width, width * scaled_height)
    height = Keyword.get(opts, :height, height * scaled_width)

    page
    |> save_state()
    |> push([width, 0, 0, height, x, y, "cm"])
    |> push([image_name, "Do"])
    |> restore_state()
  end

  def save_state(page) do
    push(%{page | saving_state: true}, "q")
  end

  def restore_state(page) do
    push(%{page | saving_state: false}, "Q")
  end

  def size(%{size: size}) do
    [_bottom, _left, width, height] = Pdf.Paper.size(size)
    %{width: width, height: height}
  end

  def set_cursor(page, y) do
    %{page | cursor: y}
  end

  def set_cursor_x(page, x) do
    %{page | cursor_x: x}
  end

  def move_down(%{cursor: y} = page, amount) do
    %{page | cursor: y - amount}
  end

  def move_right(%{cursor_x: x} = page, amount) do
    %{page | cursor_x: x + amount}
  end

  def reset_x(page) do
    %{page | cursor_x: 0}
  end

  def cursor(%{cursor: cursor}) do
    cursor
  end

  def cursor_xy(%{cursor_x: x, cursor: y}) do
    %{x: x, y: y}
  end

  defp kerned_text(font, text, opts) when is_list(opts) do
    text
    |> Text.normalize_string(Keyword.get(opts, :encoding_replacement_character, :raise))
    |> kern_text(font, Keyword.get(opts, :kerning, false))
  end

  defp kern_text(text, _font, false) do
    [s(Text.escape(text)), "Tj"]
  end

  defp kern_text(text, font, true) do
    text =
      font
      |> Font.kern_text(text)
      |> Text.escape()
      |> Enum.map(fn
        str when is_binary(str) -> s(str)
        num -> num
      end)

    [Pdf.Array.new(text), "TJ"]
  end

  defp draw_lines(%{current_font: %{module: font}} = page, [line], opts) do
    push(page, kerned_text(font, line, opts))
  end

  defp draw_lines(%{current_font: %{module: font}} = page, [line | tail], opts) do
    text = kerned_text(font, line, opts)
    draw_lines(push(page, text ++ ["T*"]), tail, opts)
  end

  defp color_command(color_name, command) when is_atom(color_name) do
    color = Pdf.Color.color(color_name)
    color_command(color, command)
  end

  defp color_command(<<"#", hex::binary>>, command) do
    color_command(parse_hex(hex), command)
  end

  defp color_command({r, g, b}, command) when is_integer(r) and is_integer(g) and is_integer(b) do
    [r / 255.0, g / 255.0, b / 255.0, command]
  end

  defp color_command({r, g, b}, command) when is_number(r) and is_number(g) and is_number(b) do
    [r / 1, g / 1, b / 1, command]
  end

  defp color_command({c, m, y, k}, command)
       when is_number(c) and is_number(m) and is_number(y) and is_number(k) do
    [c / 1, m / 1, y / 1, k / 1, command]
  end

  defp parse_hex(<<r::binary-size(1), g::binary-size(1), b::binary-size(1)>>) do
    {String.to_integer(r <> r, 16), String.to_integer(g <> g, 16), String.to_integer(b <> b, 16)}
  end

  defp parse_hex(<<r::binary-size(2), g::binary-size(2), b::binary-size(2)>>) do
    {String.to_integer(r, 16), String.to_integer(g, 16), String.to_integer(b, 16)}
  end

  defp fill_command(color_name) when is_atom(color_name), do: "rg"
  defp fill_command(<<"#", _::binary>>), do: "rg"
  defp fill_command({_r, _g, _b}), do: "rg"
  defp fill_command({_c, _m, _y, _k}), do: "k"

  defp stroke_command(color_name) when is_atom(color_name), do: "RG"
  defp stroke_command(<<"#", _::binary>>), do: "RG"
  defp stroke_command({_r, _g, _b}), do: "RG"
  defp stroke_command({_c, _m, _y, _k}), do: "K"

  defimpl Pdf.Size do
    def size_of(%Pdf.Page{} = page), do: Pdf.Size.size_of(page.stream)
  end

  defimpl Pdf.Export do
    def to_iolist(%Pdf.Page{} = page), do: Pdf.Export.to_iolist(page.stream)
  end

  defimpl Inspect do
    def inspect(%Pdf.Page{size: size}, _opts), do: "#Page<size: #{inspect(size)}>"
  end
end
