defmodule Pdf.Reader.AcroForm do
  @moduledoc """
  AcroForm field walker for `Pdf.Reader`.

  Extracts interactive form fields from a PDF's AcroForm field tree, returning
  a flat list of leaf `%Pdf.Reader.FormField{}` structs with decoded names, types,
  values, flags, and rectangles.

  ## Spec references

  - PDF 1.7 (ISO 32000-1) § 12.7 — Interactive Forms:
    https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
  - § 12.7.3 — Field Dictionaries
  - § 12.7.3.1 — Field Flags
  - § 12.7.4 — Field Types
  """

  alias Pdf.Reader.{Document, FormField, ObjectResolver, Utils}

  @max_field_depth 8

  @doc """
  Reads all AcroForm leaf fields from a document.

  Returns `{:ok, [FormField.t()], Document.t()}` with a flat list of leaf fields.
  When no `/AcroForm` is present, or `/Fields` is empty, returns `{:ok, [], doc}`.
  Never returns `{:error, _}` for absent or empty AcroForms.
  """
  @spec read(Document.t()) ::
          {:ok, [FormField.t()], Document.t()} | {:error, term()}
  def read(doc) do
    with {:ok, catalog, doc2} <- resolve_catalog(doc),
         {:ok, acroform, doc3} <- resolve_acroform_dict(doc2, catalog) do
      case acroform do
        nil ->
          {:ok, [], doc3}

        acroform_dict when is_map(acroform_dict) ->
          fields_array = Map.get(acroform_dict, "Fields", [])

          case fields_array do
            [] ->
              {:ok, [], doc3}

            fields when is_list(fields) ->
              {leaf_fields, doc4} =
                walk_fields(fields, doc3, "", nil, MapSet.new(), 0, [])

              {:ok, Enum.reverse(leaf_fields), doc4}

            _ ->
              {:ok, [], doc3}
          end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Catalog + AcroForm resolution
  # ---------------------------------------------------------------------------

  defp resolve_catalog(%Document{trailer: trailer} = doc) do
    case Map.get(trailer, "Root") do
      nil ->
        {:error, :no_root}

      root_ref ->
        case ObjectResolver.resolve(doc, root_ref) do
          {:ok, catalog, doc2} when is_map(catalog) -> {:ok, catalog, doc2}
          {:ok, _other, _doc2} -> {:error, {:malformed, :catalog, %{not_a_dict: true}}}
          {:error, _} = err -> err
        end
    end
  end

  defp resolve_acroform_dict(doc, catalog) do
    case Map.get(catalog, "AcroForm") do
      nil ->
        {:ok, nil, doc}

      :null ->
        {:ok, nil, doc}

      {:ref, _n, _g} = ref ->
        case ObjectResolver.resolve(doc, ref) do
          {:ok, dict, doc2} when is_map(dict) -> {:ok, dict, doc2}
          {:ok, _other, doc2} -> {:ok, nil, doc2}
          {:error, _} -> {:ok, nil, doc}
        end

      dict when is_map(dict) ->
        {:ok, dict, doc}

      _other ->
        {:ok, nil, doc}
    end
  end

  # ---------------------------------------------------------------------------
  # Field tree walker
  # walk_fields(refs_or_dicts, doc, name_prefix, inherited_ft, visited, depth, acc)
  # Returns {accumulated_leaf_fields, doc}
  # ---------------------------------------------------------------------------

  defp walk_fields([], doc, _prefix, _inherited_ft, _visited, _depth, acc) do
    {acc, doc}
  end

  defp walk_fields([entry | rest], doc, prefix, inherited_ft, visited, depth, acc) do
    # Check depth cap — skip this entry if at or over limit
    if depth >= @max_field_depth do
      walk_fields(rest, doc, prefix, inherited_ft, visited, depth, acc)
    else
      # Cycle detection for indirect references
      case entry do
        {:ref, n, g} ->
          key = {n, g}

          if MapSet.member?(visited, key) do
            # Cycle detected — skip this kid
            walk_fields(rest, doc, prefix, inherited_ft, visited, depth, acc)
          else
            new_visited = MapSet.put(visited, key)

            case ObjectResolver.resolve(doc, {:ref, n, g}) do
              {:ok, field_dict, doc2} when is_map(field_dict) ->
                {new_acc, doc3} =
                  process_field(field_dict, doc2, prefix, inherited_ft, new_visited, depth, acc)

                walk_fields(rest, doc3, prefix, inherited_ft, new_visited, depth, new_acc)

              {:ok, _other, doc2} ->
                walk_fields(rest, doc2, prefix, inherited_ft, new_visited, depth, acc)

              {:error, _} ->
                walk_fields(rest, doc, prefix, inherited_ft, new_visited, depth, acc)
            end
          end

        field_dict when is_map(field_dict) ->
          {new_acc, doc2} =
            process_field(field_dict, doc, prefix, inherited_ft, visited, depth, acc)

          walk_fields(rest, doc2, prefix, inherited_ft, visited, depth, new_acc)

        _other ->
          walk_fields(rest, doc, prefix, inherited_ft, visited, depth, acc)
      end
    end
  end

  # Process a single resolved field dictionary
  defp process_field(field_dict, doc, prefix, inherited_ft, visited, depth, acc) do
    # Skip pure widget annotations that are not field nodes
    if widget_only?(field_dict) do
      {acc, doc}
    else
      # Extract partial name (/T) and build full name
      partial_name = extract_partial_name(field_dict)
      full_name = join_name(prefix, partial_name)

      # Determine effective /FT (own takes precedence over inherited)
      own_ft = Map.get(field_dict, "FT")
      effective_ft = own_ft || inherited_ft

      # Get /Kids array (may be nil or list)
      kids = resolve_kids(field_dict)

      # Determine if this is a leaf: no kids, or all kids are widget-only
      if leaf_node?(kids, doc) do
        # Emit leaf field
        {field, doc2} = emit_leaf(field_dict, full_name, partial_name, effective_ft, doc)
        {[field | acc], doc2}
      else
        # Intermediate node: recurse into kids
        walk_fields(kids, doc, full_name, effective_ft, visited, depth + 1, acc)
      end
    end
  end

  # Get kids array from field dict (normalise to list or [])
  defp resolve_kids(field_dict) do
    case Map.get(field_dict, "Kids") do
      nil -> []
      kids when is_list(kids) -> kids
      _ -> []
    end
  end

  # A node is a leaf if it has no kids, or all kids are widget-only annotations
  defp leaf_node?([], _doc), do: true

  defp leaf_node?(kids, doc) when is_list(kids) do
    only_widgets?(kids, doc)
  end

  # Check if all kids are widget-only annotations (not logical field nodes)
  defp only_widgets?([], _doc), do: true

  defp only_widgets?([kid | rest], doc) do
    dict =
      case kid do
        {:ref, n, g} ->
          case ObjectResolver.resolve(doc, {:ref, n, g}) do
            {:ok, d, _doc2} when is_map(d) -> d
            _ -> nil
          end

        d when is_map(d) ->
          d

        _ ->
          nil
      end

    if dict == nil do
      only_widgets?(rest, doc)
    else
      if widget_only?(dict) do
        only_widgets?(rest, doc)
      else
        false
      end
    end
  end

  # A dict is a widget-only annotation (not a logical field) if:
  # - It has /Subtype /Widget (or name "Widget")
  # - AND has neither /T nor /FT
  defp widget_only?(dict) when is_map(dict) do
    subtype =
      case Map.get(dict, "Subtype") do
        {:name, name} -> name
        name when is_binary(name) -> name
        _ -> nil
      end

    has_t = Map.has_key?(dict, "T")
    has_ft = Map.has_key?(dict, "FT")

    subtype == "Widget" and not has_t and not has_ft
  end

  defp widget_only?(_), do: false

  # Extract partial name from /T
  defp extract_partial_name(field_dict) do
    case Map.get(field_dict, "T") do
      nil -> nil
      {:string, bin} -> Utils.decode_pdf_string(bin)
      {:hex_string, bin} -> bin
      bin when is_binary(bin) -> Utils.decode_pdf_string(bin)
      _ -> nil
    end
  end

  # Join prefix + partial_name with "." separator
  # Rules: nil partial → prefix unchanged; empty prefix → partial only
  defp join_name("", nil), do: nil
  defp join_name("", partial) when is_binary(partial), do: partial
  defp join_name(prefix, nil) when is_binary(prefix), do: prefix
  defp join_name(nil, partial), do: partial

  defp join_name(prefix, partial) when is_binary(prefix) and is_binary(partial) do
    prefix <> "." <> partial
  end

  # ---------------------------------------------------------------------------
  # Leaf emission
  # ---------------------------------------------------------------------------

  defp emit_leaf(field_dict, full_name, partial_name, effective_ft, doc) do
    type = ft_to_atom(effective_ft)
    ff_int = Map.get(field_dict, "Ff")

    flags = decode_flags(ff_int)

    # Decode /V (value)
    {value, doc2} = resolve_and_decode_value(Map.get(field_dict, "V"), type, ff_int, doc)

    # Decode /DV (default value)
    {default_val, doc3} = resolve_and_decode_value(Map.get(field_dict, "DV"), type, ff_int, doc2)

    # Decode /TU (tooltip)
    tooltip =
      case Map.get(field_dict, "TU") do
        nil -> nil
        {:string, bin} -> Utils.decode_pdf_string(bin)
        {:hex_string, bin} -> bin
        bin when is_binary(bin) -> Utils.decode_pdf_string(bin)
        _ -> nil
      end

    # Parse /Rect
    rect = Utils.parse_rect(Map.get(field_dict, "Rect"))

    field = %FormField{
      name: full_name,
      partial_name: partial_name,
      type: type,
      value: value,
      default: default_val,
      tooltip: tooltip,
      flags: flags,
      rect: rect
    }

    {field, doc3}
  end

  # ---------------------------------------------------------------------------
  # ft_to_atom/1 — map /FT name to type atom (R-AF10)
  # ---------------------------------------------------------------------------

  defp ft_to_atom({:name, "Tx"}), do: :text
  defp ft_to_atom({:name, "Btn"}), do: :button
  defp ft_to_atom({:name, "Ch"}), do: :choice
  defp ft_to_atom({:name, "Sig"}), do: :signature
  defp ft_to_atom("Tx"), do: :text
  defp ft_to_atom("Btn"), do: :button
  defp ft_to_atom("Ch"), do: :choice
  defp ft_to_atom("Sig"), do: :signature
  defp ft_to_atom(nil), do: :unknown
  defp ft_to_atom(_), do: :unknown

  # ---------------------------------------------------------------------------
  # button_subtype/1 — disambiguate button subtypes from /Ff bits (R-AF13)
  # bit 17 (0x10000) = pushbutton; bit 16 (0x8000) = radio; else = checkbox
  # Note: bits are 0-indexed from LSB per PDF spec.
  # ---------------------------------------------------------------------------

  defp button_subtype(ff_int) when is_integer(ff_int) do
    cond do
      Bitwise.band(ff_int, 0x10000) != 0 -> :pushbutton
      Bitwise.band(ff_int, 0x8000) != 0 -> :radio
      true -> :checkbox
    end
  end

  defp button_subtype(_), do: :checkbox

  # ---------------------------------------------------------------------------
  # resolve_and_decode_value/4 (R-AF11, R-AF12)
  # ---------------------------------------------------------------------------

  defp resolve_and_decode_value(nil, _type, _ff_int, doc), do: {nil, doc}
  defp resolve_and_decode_value(:null, _type, _ff_int, doc), do: {nil, doc}

  defp resolve_and_decode_value({:ref, _n, _g} = ref, type, ff_int, doc) do
    case ObjectResolver.resolve(doc, ref) do
      {:ok, resolved, doc2} ->
        resolve_and_decode_value(resolved, type, ff_int, doc2)

      {:error, _} ->
        {nil, doc}
    end
  end

  defp resolve_and_decode_value(value, :text, _ff_int, doc) do
    decoded = decode_value_as_string(value)
    {decoded, doc}
  end

  defp resolve_and_decode_value(value, :button, ff_int, doc) do
    subtype = button_subtype(ff_int)

    result =
      case subtype do
        :pushbutton ->
          nil

        :radio ->
          case value do
            {:name, opt} -> {:selected, opt}
            opt when is_binary(opt) -> {:selected, opt}
            _ -> nil
          end

        :checkbox ->
          case value do
            {:name, "Off"} -> false
            {:name, _other} -> true
            "Off" -> false
            _ when is_binary(value) -> true
            _ -> nil
          end
      end

    {result, doc}
  end

  defp resolve_and_decode_value(value, :choice, ff_int, doc) do
    # Multi-select: /Ff bit 22 (0x200000) set → array of strings
    is_multi =
      case ff_int do
        n when is_integer(n) -> Bitwise.band(n, 0x200000) != 0
        _ -> false
      end

    result =
      if is_multi do
        case value do
          list when is_list(list) ->
            Enum.map(list, &decode_value_as_string/1)

          other ->
            [decode_value_as_string(other)]
        end
      else
        case value do
          list when is_list(list) ->
            list |> Enum.map(&decode_value_as_string/1) |> List.first()

          other ->
            decode_value_as_string(other)
        end
      end

    {result, doc}
  end

  defp resolve_and_decode_value(value, :signature, _ff_int, doc) do
    result =
      case value do
        dict when is_map(dict) -> :present
        :null -> nil
        nil -> nil
        _ -> nil
      end

    {result, doc}
  end

  defp resolve_and_decode_value(_value, :unknown, _ff_int, doc) do
    {nil, doc}
  end

  defp resolve_and_decode_value(value, _type, _ff_int, doc) do
    {decode_value_as_string(value), doc}
  end

  # Decode a raw PDF value to a string (for text fields, tooltip, etc.)
  defp decode_value_as_string({:string, bin}) when is_binary(bin),
    do: Utils.decode_pdf_string(bin)

  defp decode_value_as_string({:hex_string, bin}) when is_binary(bin), do: decode_hex_string(bin)
  defp decode_value_as_string(bin) when is_binary(bin), do: Utils.decode_pdf_string(bin)
  defp decode_value_as_string(_), do: nil

  # Decode hex string bytes — may carry UTF-16BE BOM
  defp decode_hex_string(bin) when is_binary(bin), do: Utils.decode_pdf_string(bin)

  # ---------------------------------------------------------------------------
  # decode_flags/1 — /Ff bitmask → %{atom => boolean} (R-AF14)
  # All 17 flag atoms per PDF 1.7 § 12.7.3.1 Table 227
  # Bit positions are 0-indexed from LSB.
  # ---------------------------------------------------------------------------

  @flag_bits [
    {:read_only, 0},
    {:required, 1},
    {:no_export, 2},
    {:multiline, 12},
    {:password, 13},
    {:radio, 15},
    {:pushbutton, 16},
    {:combo, 17},
    {:edit, 18},
    {:sort, 19},
    {:file_select, 20},
    {:multi_select, 21},
    {:do_not_spell_check, 22},
    {:do_not_scroll, 23},
    {:comb, 24},
    {:rich_text, 25},
    {:radios_in_unison, 25}
  ]

  defp decode_flags(nil) do
    Map.new(@flag_bits, fn {atom, _bit} -> {atom, false} end)
  end

  defp decode_flags(ff) when is_integer(ff) do
    Map.new(@flag_bits, fn {atom, bit} ->
      {atom, Bitwise.band(ff, Bitwise.bsl(1, bit)) != 0}
    end)
  end

  defp decode_flags(_), do: decode_flags(nil)
end
