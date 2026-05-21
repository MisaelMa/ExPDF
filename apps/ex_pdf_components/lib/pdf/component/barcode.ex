defmodule Pdf.Component.Barcode do
  @moduledoc """
  Barcode PDF component — renders Code 128 barcodes onto a PDF.

  This is a **thin renderer**. All encoding logic (standard and shaped)
  lives in `ex_barcode`. This component only scales and draws.

  ## Standard barcode

      Pdf.Component.Barcode.render(doc, {50, 700}, %{data: "ABC-12345", width: 200})

  ## Shape barcode (creative barcode with silhouette + decorations)

      Pdf.Component.Barcode.render(doc, {50, 700}, %{
        data: "SPOT2NITE", width: 250, height: 100, shape: :rv
      })

  ## Style options

  ### Core
    - `:data` — the string to encode (required)
    - `:width` — barcode width in points (default `200`)
    - `:height` — bar height in points (default `50`, or auto from aspect ratio)
    - `:color` — bar color (default `{0, 0, 0}`)
    - `:background` — optional background color (standard barcodes only)
    - `:quiet_zone` — modules of white space (default `10` standard, `2` shaped)

  ### Text
    - `:show_text` — render data below bars (default `true`)
    - `:font` / `:font_size` / `:text_color` — text styling
    - `:label` — optional title above barcode
    - `:label_font_size` / `:label_color` — label styling

  ### Image
    - `:image` — path, URL, or `{:binary, data}`
    - `:image_size` — `{w, h}` (default `{40, 40}`)
    - `:image_position` — `:left`, `:right`, `:top` (default `:left`)
    - `:image_gap` — gap between image and barcode (default `8`)
    - `:image_border_radius` — rounded clip (default `0`)

  ### Shape (delegated to `ExBarcode.Shape`)
    - `:shape` — predefined shape: `:rv`, `:camper`, `:city`, `:wave`, `:diamond`, `:hill`
    - `:contour_top` — custom top contour `[{x_pct, y_pct}, ...]`
    - `:contour_bottom` — custom bottom contour
    - `:bar_min_height` — minimum bar fraction (default `0.0`)
    - `:decoration_color` — color for decorations (default same as `:color`)
    - `:decoration_stroke_color` — stroke color for stroke decorations (default lighter)
  """

  @default_width 200
  @default_height 50
  @default_color {0, 0, 0}
  @default_font "Helvetica"
  @default_font_size 8

  @kappa 0.5522847498

  def render(doc, {x, y}, style \\ %{}) do
    data = Map.get(style, :data, "")
    shape = Map.get(style, :shape)
    contour_top = Map.get(style, :contour_top)

    if shape || contour_top do
      render_shaped(doc, {x, y}, style, data)
    else
      render_standard(doc, {x, y}, style, data)
    end
  end

  # ── Standard barcode ───────────────────────────────────────────

  defp render_standard(doc, {x, y}, style, data) do
    width = Map.get(style, :width, @default_width)
    height = Map.get(style, :height, @default_height)
    color = Map.get(style, :color, @default_color)
    bg = Map.get(style, :background)
    show_text = Map.get(style, :show_text, true)
    font = Map.get(style, :font, @default_font)
    font_size = Map.get(style, :font_size, @default_font_size)
    text_color = Map.get(style, :text_color, color)
    quiet_zone = Map.get(style, :quiet_zone, 10)
    image = Map.get(style, :image)
    {img_w, img_h} = Map.get(style, :image_size, {40, 40})
    img_pos = Map.get(style, :image_position, :left)
    img_gap = Map.get(style, :image_gap, 8)
    img_radius = Map.get(style, :image_border_radius, 0)
    label = Map.get(style, :label)
    label_fs = Map.get(style, :label_font_size, 10)
    label_color = Map.get(style, :label_color, color)

    case ExBarcode.encode(data) do
      {:ok, bars} ->
        {bar_x, bar_y_start, img_x, img_y} =
          compute_layout(x, y, width, image, {img_w, img_h}, img_pos, img_gap, label, label_fs)

        doc = render_label(doc, label, bar_x, y, font, label_fs, label_color)

        baseline = bar_y_start - height
        total_modules = Enum.sum(bars) + quiet_zone * 2
        module_width = width / total_modules

        doc =
          if bg do
            total_h = if show_text, do: height + font_size + 4, else: height
            doc
            |> Pdf.save_state()
            |> Pdf.set_fill_color(bg)
            |> Pdf.rectangle({bar_x, bar_y_start - total_h}, {width, total_h})
            |> Pdf.fill()
            |> Pdf.restore_state()
          else
            doc
          end

        doc = Pdf.save_state(doc) |> Pdf.set_fill_color(color)

        {doc, _} =
          bars
          |> Enum.with_index()
          |> Enum.reduce({doc, bar_x + quiet_zone * module_width}, fn {modules, i}, {d, offset} ->
            bar_w = modules * module_width

            d =
              if rem(i, 2) == 0 do
                d |> Pdf.rectangle({offset, baseline}, {bar_w, height}) |> Pdf.fill()
              else
                d
              end

            {d, offset + bar_w}
          end)

        doc = Pdf.restore_state(doc)

        doc = render_text(doc, show_text, data, bar_x, baseline, width, font, font_size, text_color)

        if image do
          draw_image(doc, image, {img_x, img_y}, {img_w, img_h}, img_radius)
        else
          doc
        end

      {:error, _} ->
        doc
    end
  end

  # ── Shaped barcode ─────────────────────────────────────────────

  defp render_shaped(doc, {x, y}, style, data) do
    width = Map.get(style, :width, @default_width)
    color = Map.get(style, :color, @default_color)
    bg = Map.get(style, :background, {1, 1, 1})
    show_text = Map.get(style, :show_text, true)
    font = Map.get(style, :font, @default_font)
    font_size = Map.get(style, :font_size, @default_font_size)
    text_color = Map.get(style, :text_color, color)
    label = Map.get(style, :label)
    label_fs = Map.get(style, :label_font_size, 10)
    label_color = Map.get(style, :label_color, color)
    deco_color = Map.get(style, :decoration_color, color)
    deco_stroke = Map.get(style, :decoration_stroke_color, lighten(color, 0.3))

    shape_opts = [
      shape: Map.get(style, :shape),
      contour_top: Map.get(style, :contour_top),
      contour_bottom: Map.get(style, :contour_bottom),
      quiet_zone: Map.get(style, :quiet_zone, 2),
      bar_min: Map.get(style, :bar_min_height, 0.0)
    ]

    case ExBarcode.encode_shaped(data, shape_opts) do
      {:ok, result} ->
        height = Map.get(style, :height, width / result.aspect_ratio)
        baseline = y - height

        doc = render_label(doc, label, x, y, font, label_fs, label_color)

        case result.style do
          :silhouette ->
            render_silhouette(doc, result, x, baseline, width, height, color, bg, deco_color, deco_stroke)

          :contour ->
            render_contour(doc, result, x, baseline, width, height, color, deco_color, deco_stroke)
        end
        |> render_text(show_text, data, x, baseline, width, font, font_size, text_color)

      {:error, _} ->
        doc
    end
  end

  # ── Silhouette renderer ──────────────────────────────────────
  # 1. Fill silhouette polygons (barcode color)
  # 2. Fill barcode region (background color = clear)
  # 3. Draw bars inside region (barcode color)
  # 4. Draw cutouts (background color details on solid areas)
  # 5. Draw decorations (barcode color details)

  defp render_silhouette(doc, result, x, baseline, w, h, color, bg, deco_color, deco_stroke) do
    # 1. Draw silhouette polygons
    doc =
      Enum.reduce(result.silhouette, doc, fn polygon, d ->
        scaled = Enum.map(polygon, fn {px, py} -> {x + px * w, baseline + py * h} end)
        render_polygon_fill(d, scaled, color)
      end)

    # 2. Clear barcode region with background
    doc =
      case result.barcode_region do
        {rx, ry, rw, rh} ->
          doc
          |> Pdf.save_state()
          |> Pdf.set_fill_color(bg)
          |> Pdf.rectangle({x + rx * w, baseline + ry * h}, {rw * w, rh * h})
          |> Pdf.fill()
          |> Pdf.restore_state()

        _ ->
          doc
      end

    # 3. Draw bars
    doc = Pdf.save_state(doc) |> Pdf.set_fill_color(color)

    doc =
      Enum.reduce(result.bars, doc, fn bar, d ->
        bx = x + bar.x * w
        by = baseline + bar.y * h
        bw = bar.w * w
        bh = bar.h * h

        if bh > 0.3 do
          d |> Pdf.rectangle({bx, by}, {bw, bh}) |> Pdf.fill()
        else
          d
        end
      end)

    doc = Pdf.restore_state(doc)

    # 4. Draw cutouts (background-colored shapes on solid areas)
    doc = render_cutouts(doc, result.cutouts, x, baseline, w, h, bg)

    # 5. Draw decorations
    render_decorations(doc, result.decorations, x, baseline, w, h, deco_color, deco_stroke)
  end

  # ── Contour renderer (existing behavior) ─────────────────────

  defp render_contour(doc, result, x, baseline, w, h, color, deco_color, deco_stroke) do
    doc = Pdf.save_state(doc) |> Pdf.set_fill_color(color)

    doc =
      Enum.reduce(result.bars, doc, fn bar, d ->
        bx = x + bar.x * w
        by = baseline + bar.y * h
        bw = bar.w * w
        bh = bar.h * h

        if bh > 0.5 do
          d |> Pdf.rectangle({bx, by}, {bw, bh}) |> Pdf.fill()
        else
          d
        end
      end)

    doc = Pdf.restore_state(doc)

    render_decorations(doc, result.decorations, x, baseline, w, h, deco_color, deco_stroke)
  end

  # ── Decoration renderer ────────────────────────────────────────

  defp render_decorations(doc, decorations, x, baseline, w, h, fill_color, stroke_color) do
    Enum.reduce(decorations, doc, fn deco, d ->
      case deco do
        {:circle, {cx, cy, r}} ->
          render_circle(d, x + cx * w, baseline + cy * h, r * min(w, h), fill_color)

        {:circle_stroke, {cx, cy, r}} ->
          render_circle_stroke(d, x + cx * w, baseline + cy * h, r * min(w, h), stroke_color)

        {:polygon, points} ->
          scaled = Enum.map(points, fn {px, py} -> {x + px * w, baseline + py * h} end)
          render_polygon_stroke(d, scaled, stroke_color)

        {:line, {x1, y1, x2, y2}} ->
          d
          |> Pdf.save_state()
          |> Pdf.set_stroke_color(fill_color)
          |> Pdf.set_line_width(0.8)
          |> Pdf.line({x + x1 * w, baseline + y1 * h}, {x + x2 * w, baseline + y2 * h})
          |> Pdf.stroke()
          |> Pdf.restore_state()

        _ ->
          d
      end
    end)
  end

  defp render_circle(doc, cx, cy, r, color) do
    k = r * @kappa

    doc
    |> Pdf.save_state()
    |> Pdf.set_fill_color(color)
    |> Pdf.move_to({cx + r, cy})
    |> Pdf.curve_to({cx + r, cy + k}, {cx + k, cy + r}, {cx, cy + r})
    |> Pdf.curve_to({cx - k, cy + r}, {cx - r, cy + k}, {cx - r, cy})
    |> Pdf.curve_to({cx - r, cy - k}, {cx - k, cy - r}, {cx, cy - r})
    |> Pdf.curve_to({cx + k, cy - r}, {cx + r, cy - k}, {cx + r, cy})
    |> Pdf.close_path()
    |> Pdf.fill()
    |> Pdf.restore_state()
  end

  defp render_circle_stroke(doc, cx, cy, r, color) do
    k = r * @kappa

    doc
    |> Pdf.save_state()
    |> Pdf.set_stroke_color(color)
    |> Pdf.set_line_width(0.5)
    |> Pdf.move_to({cx + r, cy})
    |> Pdf.curve_to({cx + r, cy + k}, {cx + k, cy + r}, {cx, cy + r})
    |> Pdf.curve_to({cx - k, cy + r}, {cx - r, cy + k}, {cx - r, cy})
    |> Pdf.curve_to({cx - r, cy - k}, {cx - k, cy - r}, {cx, cy - r})
    |> Pdf.curve_to({cx + k, cy - r}, {cx + r, cy - k}, {cx + r, cy})
    |> Pdf.close_path()
    |> Pdf.stroke()
    |> Pdf.restore_state()
  end

  defp render_polygon_fill(doc, points, color) do
    case points do
      [first | rest] ->
        doc =
          doc
          |> Pdf.save_state()
          |> Pdf.set_fill_color(color)
          |> Pdf.move_to(first)

        doc = Enum.reduce(rest, doc, fn pt, d -> Pdf.line_append(d, pt) end)

        doc
        |> Pdf.close_path()
        |> Pdf.fill()
        |> Pdf.restore_state()

      _ ->
        doc
    end
  end

  # ── Cutout renderer (background-colored shapes on solid areas) ──

  defp render_cutouts(doc, cutouts, x, baseline, w, h, bg_color) do
    Enum.reduce(cutouts, doc, fn cutout, d ->
      case cutout do
        {:circle_bg, {cx, cy, r}} ->
          render_circle(d, x + cx * w, baseline + cy * h, r * min(w, h), bg_color)

        {:polygon_bg, points} ->
          scaled = Enum.map(points, fn {px, py} -> {x + px * w, baseline + py * h} end)
          render_polygon_fill(d, scaled, bg_color)

        _ ->
          d
      end
    end)
  end

  defp render_polygon_stroke(doc, points, color) do
    case points do
      [first | rest] ->
        doc =
          doc
          |> Pdf.save_state()
          |> Pdf.set_stroke_color(color)
          |> Pdf.set_line_width(0.5)
          |> Pdf.move_to(first)

        doc = Enum.reduce(rest, doc, fn pt, d -> Pdf.line_append(d, pt) end)

        doc
        |> Pdf.close_path()
        |> Pdf.stroke()
        |> Pdf.restore_state()

      _ ->
        doc
    end
  end

  # ── Shared helpers ─────────────────────────────────────────────

  defp render_label(doc, nil, _x, _y, _font, _fs, _color), do: doc

  defp render_label(doc, label, x, y, font, fs, color) do
    doc
    |> Pdf.set_font(font, fs, bold: true)
    |> Pdf.set_fill_color(color)
    |> Pdf.text_at({x, y - fs}, label)
  end

  defp render_text(doc, false, _data, _x, _baseline, _w, _font, _fs, _color), do: doc

  defp render_text(doc, true, data, x, baseline, width, font, font_size, text_color) do
    text_y = baseline - font_size - 2
    text_w = String.length(data) * font_size * 0.6
    text_x = x + (width - text_w) / 2

    doc
    |> Pdf.set_font(font, font_size)
    |> Pdf.set_fill_color(text_color)
    |> Pdf.text_at({text_x, text_y}, data)
  end

  defp compute_layout(x, y, width, image, {img_w, img_h}, img_pos, img_gap, label, label_fs) do
    label_offset = if label, do: label_fs + 4, else: 0

    if image do
      case img_pos do
        :left -> {x + img_w + img_gap, y - label_offset, x, y - label_offset}
        :right -> {x, y - label_offset, x + width + img_gap, y - label_offset}
        :top -> {x, y - img_h - img_gap - label_offset, x + (width - img_w) / 2, y - label_offset}
        _ -> {x + img_w + img_gap, y - label_offset, x, y - label_offset}
      end
    else
      {x, y - label_offset, x, y}
    end
  end

  defp draw_image(doc, image, {ix, iy}, {iw, ih}, radius) do
    img_bottom = iy - ih

    if radius > 0 do
      doc
      |> Pdf.save_state()
      |> Pdf.rounded_rectangle({ix, img_bottom}, {iw, ih}, radius)
      |> Pdf.clip()
      |> Pdf.add_image({ix, img_bottom}, image, width: iw, height: ih)
      |> Pdf.restore_state()
    else
      Pdf.add_image(doc, {ix, img_bottom}, image, width: iw, height: ih)
    end
  end

  defp lighten({r, g, b}, amount) do
    {r + (1 - r) * amount, g + (1 - g) * amount, b + (1 - b) * amount}
  end
end
