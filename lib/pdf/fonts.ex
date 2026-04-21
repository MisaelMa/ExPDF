defmodule Pdf.Fonts do
  @moduledoc false
  import Pdf.Utils

  alias Pdf.{Font, ExternalFont, ObjectCollection}
  alias Pdf.Font.Metrics

  defstruct last_id: 0, fonts: %{}

  defmodule FontReference do
    @moduledoc false
    defstruct name: nil, module: nil, object: nil
  end

  def new, do: %__MODULE__{}

  def get_font(%__MODULE__{} = fonts_state, %ObjectCollection{} = objects, name, opts) do
    {fonts_state, objects, ref} = lookup_font(fonts_state, objects, name, opts)
    {ref, fonts_state, objects}
  end

  def get_fonts(%__MODULE__{fonts: fonts}), do: fonts

  def add_external_font(%__MODULE__{} = fonts_state, %ObjectCollection{} = objects, path) do
    %{last_id: last_id, fonts: fonts} = fonts_state
    font_module = ExternalFont.load(path)

    unless fonts[font_module.name] do
      id = last_id + 1
      {font_object, objects} = ObjectCollection.create_object(objects, nil)
      {descriptor_object, objects} = ObjectCollection.create_object(objects, nil)
      {font_file, objects} = ObjectCollection.create_object(objects, font_module)

      font_dict = ExternalFont.font_dictionary(font_module, id, descriptor_object)
      font_descriptor_dict = ExternalFont.font_descriptor_dictionary(font_module, font_file)

      objects = ObjectCollection.update_object(objects, descriptor_object, font_descriptor_dict)
      objects = ObjectCollection.update_object(objects, font_object, font_dict)

      reference = %FontReference{
        name: n("F#{id}"),
        module: font_module,
        object: font_object
      }

      fonts = Map.put(fonts, font_module.name, reference)
      {reference, %{fonts_state | last_id: id, fonts: fonts}, objects}
    else
      {:already_exists, fonts_state, objects}
    end
  end

  font_metrics =
    Path.join(__DIR__, "../../fonts/*.afm")
    |> Path.wildcard()
    |> Enum.map(fn afm_file ->
      afm_file
      |> File.stream!()
      |> Enum.reduce(%Pdf.Font.Metrics{}, fn line, metrics ->
        Pdf.Font.Metrics.process_line(String.replace_suffix(line, "\n", ""), metrics)
      end)
    end)

  @internal_fonts font_metrics
                  |> Enum.map(fn metrics ->
                    {metrics.name,
                     %Pdf.Font{
                       name: metrics.name,
                       full_name: metrics.full_name,
                       family_name: metrics.family_name,
                       weight: metrics.weight,
                       italic_angle: metrics.italic_angle,
                       encoding: metrics.encoding,
                       first_char: metrics.first_char,
                       last_char: metrics.last_char,
                       ascender: metrics.ascender,
                       descender: metrics.descender,
                       cap_height: metrics.cap_height,
                       x_height: metrics.x_height,
                       bbox: metrics.bbox,
                       widths: Metrics.widths(metrics),
                       glyph_widths: Metrics.map_widths(metrics),
                       glyphs: metrics.glyphs,
                       kern_pairs: metrics.kern_pairs
                     }}
                  end)
                  |> Map.new()
  def get_internal_font(name, opts \\ []) do
    @internal_fonts
    |> Enum.map(fn {_, font} -> font end)
    |> Enum.find(fn font ->
      (font.family_name == name || font.name == name) && Font.matches_attributes(font, opts)
    end)
  end

  defp lookup_font(fonts_state, objects, name, opts) when is_binary(name) do
    case get_internal_font(name, opts) do
      nil -> lookup_font(fonts_state, objects, name)
      font -> lookup_font(fonts_state, objects, font)
    end
  end

  defp lookup_font(fonts_state, objects, %Font{family_name: family_name}, opts) do
    case get_internal_font(family_name, opts) do
      nil -> lookup_font(fonts_state, objects, family_name)
      font -> lookup_font(fonts_state, objects, font)
    end
  end

  defp lookup_font(%{fonts: fonts} = fonts_state, objects, %ExternalFont{family_name: family_name}, opts) do
    Enum.find(fonts, fn {_, %{module: font}} ->
      font.family_name == family_name && Font.matches_attributes(font, opts)
    end)
    |> case do
      nil -> {fonts_state, objects, nil}
      {_, f} -> {fonts_state, objects, f}
    end
  end

  defp lookup_font(%{fonts: fonts} = fonts_state, objects, name) when is_binary(name) do
    {fonts_state, objects, fonts[name]}
  end

  defp lookup_font(%{fonts: fonts} = fonts_state, objects, font_module) do
    case fonts[font_module.name] do
      nil -> load_font(fonts_state, objects, font_module)
      font -> {fonts_state, objects, font}
    end
  end

  defp load_font(%{fonts: fonts, last_id: last_id} = fonts_state, objects, font_module) do
    id = last_id + 1
    {font_object, objects} = ObjectCollection.create_object(objects, Font.to_dictionary(font_module, id))

    reference = %FontReference{
      name: n("F#{id}"),
      module: font_module,
      object: font_object
    }

    fonts = Map.put(fonts, font_module.name, reference)
    {%{fonts_state | last_id: id, fonts: fonts}, objects, reference}
  end
end
