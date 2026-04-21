defmodule Pdf.Document do
  @moduledoc false
  defstruct objects: nil,
            info: nil,
            fonts: nil,
            current: nil,
            current_font: nil,
            current_font_size: 0,
            pages: [],
            opts: [],
            action: nil,
            images: %{},
            ext_g_states: %{},
            margin: %{top: 0, right: 0, bottom: 0, left: 0},
            page_templates: %{},
            styles: %{}

  import Pdf.Utils

  alias Pdf.{
    Dictionary,
    Fonts,
    RefTable,
    Trailer,
    Array,
    ObjectCollection,
    Page,
    Paper,
    Image,
    Text
  }

  @version Application.compile_env(:pdf, :version, "1.7")
  # 7.5.2 the header line shall be immediately followed by a comment line containing
  # at least four binary characters-that is, characters whose codes are 128 or greater.
  @header <<"%PDF-#{@version}\n%", 0xE2, 0xE3, 0xCF, 0xD3, "\r\n">>
  @header_size byte_size(@header)

  def new(opts \\ []) do
    collection = ObjectCollection.new()
    fonts = Fonts.new()

    {info, collection} =
      ObjectCollection.create_object(
        collection,
        Dictionary.new(%{"Creator" => "Elixir", "Producer" => "Elixir-PDF"})
      )

    margin = parse_margin(Keyword.get(opts, :margin, 0))
    document = %__MODULE__{objects: collection, fonts: fonts, info: info, opts: opts, margin: margin}
    add_page(document, opts)
  end

  def autoprint(document) do
    {action, objects} =
      ObjectCollection.create_object(
        document.objects,
        Dictionary.new(%{
          "S" => n("Named"),
          "Type" => n("Action"),
          "N" => n("Print")
        })
      )

    %{document | action: action, objects: objects}
  end

  def get_object(document, ref) do
    ObjectCollection.get_object(document.objects, ref)
  end

  @info_map %{
    title: "Title",
    producer: "Producer",
    creator: "Creator",
    created: "CreationDate",
    modified: "ModDate",
    keywords: "Keywords",
    author: "Author",
    subject: "Subject"
  }

  def put_info(document, info_list) when is_list(info_list) do
    info = ObjectCollection.get_object(document.objects, document.info)

    info =
      info_list
      |> Enum.reduce(info, fn {key, value}, info ->
        case @info_map[key] do
          nil ->
            raise ArgumentError, "Invalid info key #{inspect(key)}"

          info_key ->
            Dictionary.put(info, info_key, Text.escape(value))
        end
      end)

    objects = ObjectCollection.update_object(document.objects, document.info, info)
    %{document | objects: objects}
  end

  @info_map
  |> Enum.each(fn {key, _value} ->
    def put_info(document, unquote(key), value), do: put_info(document, [{unquote(key), value}])
  end)

  # Pass-through functions that update the current page
  [
    {:set_fill_color, quote(do: [color])},
    {:set_stroke_color, quote(do: [color])},
    {:set_line_width, quote(do: [width])},
    {:set_line_cap, quote(do: [style])},
    {:set_line_join, quote(do: [style])},
    {:rectangle, quote(do: [{x, y}, {w, h}])},
    {:line, quote(do: [{x, y}, {x2, y2}])},
    {:move_to, quote(do: [{x, y}])},
    {:line_append, quote(do: [{x, y}])},
    {:set_font, quote(do: [name, size, opts])},
    {:set_font_size, quote(do: [size])},
    {:set_text_leading, quote(do: [leading])},
    {:text_at, quote(do: [{x, y}, text, opts])},
    {:text_wrap!, quote(do: [{x, y}, {w, h}, text, opts])},
    {:table!, quote(do: [{x, y}, {w, h}, data, opts])},
    {:text_lines, quote(do: [{x, y}, lines, opts])},
    {:stroke, []},
    {:fill, []},
    {:fill_and_stroke, []},
    {:close_path, []},
    {:clip, []},
    {:curve_to, quote(do: [{x1, y1}, {x2, y2}, {x3, y3}])},
    {:rounded_rectangle, quote(do: [{x, y}, {w, h}, r])},
    {:move_down, quote(do: [amount])},
    {:move_right, quote(do: [amount])},
    {:set_cursor_x, quote(do: [x])},
    {:reset_x, []},
    {:set_fill_opacity, quote(do: [opacity])},
    {:set_stroke_opacity, quote(do: [opacity])},
    {:set_opacity, quote(do: [opacity])},
    {:rotate, quote(do: [angle])},
    {:translate, quote(do: [{tx, ty}])},
    {:scale, quote(do: [{sx, sy}])},
    {:transform, quote(do: [{a, b, c, d, e, f}])}
  ]
  |> Enum.map(fn {func_name, args} ->
    def unquote(func_name)(%__MODULE__{current: page} = document, unquote_splicing(args)) do
      page = Page.unquote(func_name)(page, unquote_splicing(args))
      sync_page(document, page)
    end
  end)

  defp sync_page(document, page) do
    %{document | current: page, fonts: page.fonts, objects: page.objects, ext_g_states: Map.merge(document.ext_g_states, page.ext_g_states)}
  end

  def text_at(document, xy, text), do: text_at(document, xy, text, [])

  def text_wrap!(document, xy, wh, text), do: text_wrap!(document, xy, wh, text, [])

  def text_wrap(document, xy, wh, text), do: text_wrap(document, xy, wh, text, [])

  def text_wrap(%__MODULE__{current: page} = document, xy, wh, text, opts) do
    {page, remaining} = Page.text_wrap(page, xy, wh, text, opts)
    {sync_page(document, page), remaining}
  end

  def table!(document, xy, wh, data), do: table!(document, xy, wh, data, [])

  def table(document, xy, wh, data), do: table(document, xy, wh, data, [])

  def table(%__MODULE__{current: page} = document, xy, wh, data, opts) do
    {page, remaining} = Page.table(page, xy, wh, data, opts)
    {sync_page(document, page), remaining}
  end

  def text_lines(document, xy, lines), do: text_lines(document, xy, lines, [])

  def add_image(document, xy, image, opts \\ [])

  def add_image(document, {x, y}, {:binary, image_data}, opts) do
    md5 = :erlang.md5(image_data)
    add_or_create_image(document, {x, y}, md5, {:binary, image_data}, opts)
  end

  def add_image(document, {x, y}, image_path, opts) do
    add_or_create_image(document, {x, y}, image_path, image_path, opts)
  end

  defp add_or_create_image(%__MODULE__{current: page} = document, {x, y}, image_key, image, opts) do
    {image_ref, document} =
      case Map.get(document.images, image_key) do
        nil ->
          create_image(document, image)

        existing ->
          {existing, document}
      end

    page = %{page | objects: document.objects}
    %{
      document
      | current: Page.add_image(page, {x, y}, image_ref, opts),
        images: Map.put_new(document.images, image_key, image_ref)
    }
  end

  defp create_image(%{objects: objects, images: images} = document, image_path) do
    {image, objects} = Image.new(image_path, objects)
    {object, objects} = ObjectCollection.create_object(objects, image)
    name = n("I#{Kernel.map_size(images) + 1}")
    {%{name: name, object: object, image: image}, %{document | objects: objects}}
  end

  def add_external_font(%{fonts: fonts, objects: objects, current: page} = document, path) do
    {_ref, fonts, objects} = Fonts.add_external_font(fonts, objects, path)
    page = %{page | fonts: fonts, objects: objects}
    %{document | fonts: fonts, objects: objects, current: page}
  end

  def add_page(%__MODULE__{current: nil, fonts: fonts, objects: objects, opts: doc_opts} = document, opts) do
    new_page = Page.new(Keyword.merge(Keyword.merge(doc_opts, opts), fonts: fonts, objects: objects))
    document = %{document | current: new_page}
    document = apply_margin_cursor(document)
    apply_templates(document, [:background, :watermark, :header])
  end

  def add_page(%__MODULE__{current: current_page, pages: pages} = document, opts) do
    document = apply_templates(document, [:footer])
    add_page(%{document | current: nil, pages: [current_page | pages]}, opts)
  end

  def page_number(%__MODULE__{pages: pages}), do: length(pages) + 1

  def size(%__MODULE__{current: current_page}) do
    Page.size(current_page)
  end

  def cursor(%__MODULE__{current: current_page}) do
    Page.cursor(current_page)
  end

  def cursor_xy(%__MODULE__{current: current_page}) do
    Page.cursor_xy(current_page)
  end

  def set_cursor(%__MODULE__{current: current_page} = document, y) do
    %{document | current: Page.set_cursor(current_page, y)}
  end

  def to_iolist(document) do
    objects = document.objects
    pages = Enum.reverse([document.current | document.pages])
    proc_set = [n("PDF"), n("Text")]

    proc_set =
      if Kernel.map_size(document.images) > 0,
        do: [n("ImageB"), n("ImageC"), n("ImageI") | proc_set],
        else: proc_set

    resources =
      Dictionary.new(%{
        "Font" => font_dictionary(document.fonts),
        "ProcSet" => Array.new(proc_set)
      })

    resources =
      if Kernel.map_size(document.images) > 0 do
        Dictionary.put(resources, "XObject", xobject_dictionary(document.images))
      else
        resources
      end

    resources =
      if Kernel.map_size(document.ext_g_states) > 0 do
        Dictionary.put(resources, "ExtGState", ext_g_state_dictionary(document.ext_g_states))
      else
        resources
      end

    page_collection =
      Dictionary.new(%{
        "Type" => n("Pages"),
        "Count" => length(pages),
        "MediaBox" => Array.new(Paper.size(default_page_size(document))),
        "Resources" => resources
      })

    {master_page, objects} = ObjectCollection.create_object(objects, page_collection)
    {page_objects, objects} = pages_to_objects(document, objects, pages, master_page)
    {_master_page, objects} = ObjectCollection.call(objects, master_page, :put, ["Kids", Array.new(page_objects)])

    {catalogue, objects} =
      ObjectCollection.create_object(
        objects,
        Dictionary.new(%{
          "Type" => n("Catalog"),
          "Pages" => master_page,
          "OpenAction" => document.action
        })
      )

    all_objects = Enum.sort_by(ObjectCollection.all(objects), &sort_objects/1)

    {ref_table, offset} = RefTable.to_iolist(all_objects, @header_size)

    Pdf.Export.to_iolist([
      @header,
      all_objects,
      ref_table,
      Trailer.new(all_objects, offset, catalogue, document.info)
    ])
  end

  defp sort_objects(%{generation: g, number: n}) do
    g = String.to_integer(g)
    n = String.to_integer(n)
    {g, n}
  end

  defp pages_to_objects(document, objects, pages, parent) do
    Enum.reduce(pages, {[], objects}, fn page, {acc, objects} ->
      {page_object, objects} = ObjectCollection.create_object(objects, page)

      dictionary =
        Dictionary.new(%{
          "Type" => n("Page"),
          "Parent" => parent,
          "Contents" => page_object
        })

      dictionary =
        if page.size != default_page_size(document) do
          Dictionary.put(dictionary, "MediaBox", Array.new(Paper.size(page.size)))
        else
          dictionary
        end

      {dict_object, objects} = ObjectCollection.create_object(objects, dictionary)
      {acc ++ [dict_object], objects}
    end)
  end

  defp font_dictionary(fonts) do
    fonts
    |> Fonts.get_fonts()
    |> Enum.reduce(%{}, fn {_name, %{name: name, object: reference}}, map ->
      Map.put(map, name, reference)
    end)
    |> Dictionary.new()
  end

  defp xobject_dictionary(images) do
    images
    |> Enum.reduce(%{}, fn {_name, %{name: name, object: reference}}, map ->
      Map.put(map, name, reference)
    end)
    |> Dictionary.new()
  end

  defp ext_g_state_dictionary(ext_g_states) do
    ext_g_states
    |> Enum.reduce(%{}, fn {_key, %{name: name, dict: dict}}, map ->
      Map.put(map, name, dict)
    end)
    |> Dictionary.new()
  end

  def on_page(%__MODULE__{} = document, name, func) when is_atom(name) and is_function(func, 2) do
    %{document | page_templates: Map.put(document.page_templates, name, func)}
  end

  def content_area(%__MODULE__{margin: margin} = document) do
    %{width: pw, height: ph} = size(document)
    %{
      x: margin.left,
      y: ph - margin.top,
      width: pw - margin.left - margin.right,
      height: ph - margin.top - margin.bottom
    }
  end

  defp apply_margin_cursor(%__MODULE__{margin: margin} = document) do
    %{height: ph} = size(document)
    y = ph - margin.top
    x = margin.left
    page = document.current |> Page.set_cursor(y) |> Page.set_cursor_x(x)
    %{document | current: page}
  end

  defp apply_templates(document, template_names) do
    page_info = %{number: page_number(document)}

    Enum.reduce(template_names, document, fn name, doc ->
      case Map.get(doc.page_templates, name) do
        nil -> doc
        func -> func.(doc, page_info)
      end
    end)
  end

  defp parse_margin(margin) when is_number(margin) do
    %{top: margin, right: margin, bottom: margin, left: margin}
  end

  defp parse_margin(%{} = margin) do
    %{
      top: Map.get(margin, :top, 0),
      right: Map.get(margin, :right, 0),
      bottom: Map.get(margin, :bottom, 0),
      left: Map.get(margin, :left, 0)
    }
  end

  defp parse_margin({v, h}) do
    %{top: v, right: h, bottom: v, left: h}
  end

  defp parse_margin({top, h, bottom}) do
    %{top: top, right: h, bottom: bottom, left: h}
  end

  defp parse_margin({top, right, bottom, left}) do
    %{top: top, right: right, bottom: bottom, left: left}
  end

  defp default_page_size(%__MODULE__{opts: opts}), do: Keyword.get(opts, :size, :a4)
end
