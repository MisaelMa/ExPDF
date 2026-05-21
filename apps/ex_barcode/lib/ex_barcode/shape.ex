defmodule ExBarcode.Shape do
  @moduledoc """
  Shape barcode engine — transforms a standard Code 128 barcode into a
  shaped barcode with two rendering styles:

  ## Styles

  ### `:silhouette` (animals, objects)
  Solid filled silhouette (head, ears, tail, legs) with barcode bars placed
  inside a rectangular region within the body. Like a cookie-cutter: the
  animal is solid, the barcode is the "window" inside it.

  ### `:contour` (geometric, abstract)
  Bars with variable heights following a top/bottom contour, with optional
  decorations (circles, polygons, lines).

  ## Output

  All coordinates are **normalized** to a 0.0–1.0 bounding box so
  any renderer (PDF, SVG, Canvas) can scale to the desired size.

      %ExBarcode.Shape.Result{
        style: :silhouette,
        bars: [%{x: 0.20, y: 0.10, w: 0.005, h: 0.50}, ...],
        silhouette: [[{0.05, 0.40}, {0.10, 0.55}, ...]],
        barcode_region: {0.20, 0.08, 0.60, 0.52},
        cutouts: [{:circle_bg, {0.12, 0.52, 0.02}}],
        decorations: [{:circle, {0.11, 0.52, 0.006}}],
        text: "BUNNY",
        aspect_ratio: 1.8
      }
  """

  defmodule Result do
    @moduledoc "Shaped barcode result — bars + shape data in normalized coords."
    defstruct [
      style: :contour,
      bars: [],
      silhouette: [],
      barcode_region: nil,
      decorations: [],
      cutouts: [],
      text: "",
      aspect_ratio: 2.5
    ]
  end

  @doc """
  Encode text as a shaped barcode.

  ## Options

    - `:shape` — predefined shape atom (see `available_shapes/0`)
    - `:contour_top` — custom top contour `[{x_pct, y_pct}, ...]`
    - `:contour_bottom` — custom bottom contour
    - `:quiet_zone` — modules of padding per side (default `2`)
    - `:bar_min` — minimum bar height fraction (default `0.0`)
  """
  def encode(text, opts \\ []) do
    shape = Keyword.get(opts, :shape)
    c_top = Keyword.get(opts, :contour_top)
    c_bot = Keyword.get(opts, :contour_bottom)
    quiet = Keyword.get(opts, :quiet_zone, 2)
    bar_min = Keyword.get(opts, :bar_min, 0.0)

    case ExBarcode.encode(text) do
      {:ok, modules} ->
        result = resolve_and_build(shape, modules, c_top, c_bot, quiet, bar_min, text)
        {:ok, result}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc "Same as `encode/2` but raises on error."
  def encode!(text, opts \\ []) do
    case encode(text, opts) do
      {:ok, result} -> result
      {:error, reason} -> raise "ExBarcode.Shape encode error: #{inspect(reason)}"
    end
  end

  # ── Dispatch ──────────────────────────────────────────────────

  defp resolve_and_build(shape, modules, c_top, c_bot, quiet, bar_min, text) do
    case resolve_shape(shape, c_top, c_bot) do
      {:silhouette, silhouette, barcode_region, decorations, cutouts, aspect} ->
        bars = build_bars_in_region(modules, barcode_region, quiet)

        %Result{
          style: :silhouette,
          bars: bars,
          silhouette: silhouette,
          barcode_region: barcode_region,
          decorations: decorations,
          cutouts: cutouts,
          text: text,
          aspect_ratio: aspect
        }

      {:contour, top, bottom, decorations, aspect} ->
        bars = build_contour_bars(modules, top, bottom, quiet, bar_min)

        %Result{
          style: :contour,
          bars: bars,
          decorations: decorations,
          text: text,
          aspect_ratio: aspect
        }
    end
  end

  # ── Silhouette bars — placed inside a region ──────────────────

  defp build_bars_in_region(modules, {rx, ry, rw, rh}, quiet) do
    total_modules = Enum.sum(modules) + quiet * 2
    module_w = rw / total_modules
    start_x = rx + quiet * module_w

    modules
    |> Enum.with_index()
    |> Enum.reduce({[], start_x}, fn {mod_count, i}, {acc, offset} ->
      bar_w = mod_count * module_w

      bars =
        if rem(i, 2) == 0 do
          [%{x: offset, y: ry, w: bar_w, h: rh} | acc]
        else
          acc
        end

      {bars, offset + bar_w}
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  # ── Contour bars — variable heights ─────────────────────────

  defp build_contour_bars(modules, contour_top, contour_bottom, quiet, bar_min) do
    total_modules = Enum.sum(modules) + quiet * 2
    module_w = 1.0 / total_modules
    start_x = quiet * module_w

    modules
    |> Enum.with_index()
    |> Enum.reduce({[], start_x}, fn {mod_count, i}, {acc, offset} ->
      bar_w = mod_count * module_w

      bars =
        if rem(i, 2) == 0 do
          x_center = offset + bar_w / 2

          top_y =
            if contour_top,
              do: max(interpolate(contour_top, x_center), bar_min),
              else: 1.0

          bot_y =
            if contour_bottom,
              do: interpolate(contour_bottom, x_center),
              else: 0.0

          bar_h = max(top_y - bot_y, 0.0)

          if bar_h > 0 do
            [%{x: offset, y: bot_y, w: bar_w, h: bar_h} | acc]
          else
            acc
          end
        else
          acc
        end

      {bars, offset + bar_w}
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  # ── Contour interpolation ──────────────────────────────────────

  defp interpolate(points, x) do
    x = max(0.0, min(1.0, x))

    case points do
      [] -> 1.0
      [{_, y}] -> y
      _ ->
        sorted = Enum.sort_by(points, &elem(&1, 0))

        left =
          sorted
          |> Enum.filter(fn {px, _} -> px <= x end)
          |> List.last()

        right =
          sorted
          |> Enum.filter(fn {px, _} -> px >= x end)
          |> List.first()

        case {left, right} do
          {nil, {_, y}} -> y
          {{_, y}, nil} -> y
          {{x1, _y1}, {x2, _y2}} when x1 == x2 -> elem(left, 1)
          {{x1, y1}, {x2, y2}} ->
            t = (x - x1) / (x2 - x1)
            y1 + t * (y2 - y1)
        end
    end
  end

  # ════════════════════════════════════════════════════════════════
  # SILHOUETTE SHAPES — solid animal/object + barcode inside body
  # ════════════════════════════════════════════════════════════════
  # Returns {:silhouette, silhouette_polygons, barcode_region, decorations, cutouts, aspect}
  #
  # - silhouette: list of polygon point lists (filled solid)
  # - barcode_region: {x, y, w, h} normalized rect where bars go
  # - decorations: shapes drawn in barcode color ON TOP of everything
  # - cutouts: shapes drawn in background color ON TOP of silhouette

  defp resolve_shape(:rabbit, _, _) do
    # Sitting rabbit facing left — head on left, rump on right
    body = [
      # Nose
      {0.05, 0.35},
      # Under chin
      {0.08, 0.30}, {0.12, 0.25},
      # Front leg
      {0.14, 0.10}, {0.12, 0.03}, {0.20, 0.03}, {0.22, 0.10},
      # Belly
      {0.25, 0.12}, {0.35, 0.08}, {0.50, 0.06},
      # Rear foot
      {0.55, 0.03}, {0.72, 0.03}, {0.75, 0.06},
      # Rump
      {0.80, 0.15}, {0.85, 0.30},
      # Tail
      {0.90, 0.38}, {0.95, 0.45}, {0.92, 0.50}, {0.88, 0.48},
      # Back
      {0.82, 0.55}, {0.75, 0.62}, {0.65, 0.68},
      {0.55, 0.72}, {0.45, 0.72}, {0.35, 0.70},
      # Neck
      {0.28, 0.65}, {0.22, 0.60},
      # Head top
      {0.18, 0.62}, {0.15, 0.58}, {0.12, 0.55},
      {0.08, 0.50}, {0.06, 0.45},
      # Back to nose
      {0.05, 0.40}
    ]

    # Left ear (front ear, more visible)
    left_ear = [
      {0.16, 0.60}, {0.11, 0.78}, {0.08, 0.92}, {0.10, 0.95},
      {0.13, 0.92}, {0.15, 0.80}, {0.19, 0.64}
    ]

    # Right ear (back ear, slightly behind)
    right_ear = [
      {0.20, 0.62}, {0.17, 0.82}, {0.16, 0.94}, {0.18, 0.98},
      {0.21, 0.94}, {0.22, 0.80}, {0.24, 0.65}
    ]

    barcode_region = {0.18, 0.08, 0.60, 0.55}

    cutouts = [
      # Eye (white)
      {:circle_bg, {0.10, 0.48, 0.018}},
      # Inner ear highlights
      {:polygon_bg, [{0.12, 0.75}, {0.10, 0.88}, {0.12, 0.88}, {0.14, 0.75}]},
      {:polygon_bg, [{0.18, 0.78}, {0.17, 0.90}, {0.19, 0.90}, {0.21, 0.78}]}
    ]

    decorations = [
      # Pupil
      {:circle, {0.10, 0.48, 0.007}},
      # Nose dot
      {:circle, {0.06, 0.38, 0.008}}
    ]

    {:silhouette, [body, left_ear, right_ear], barcode_region, decorations, cutouts, 1.6}
  end

  defp resolve_shape(:cat, _, _) do
    # Sitting cat facing left
    body = [
      # Nose
      {0.06, 0.32},
      # Under chin
      {0.10, 0.24}, {0.14, 0.18},
      # Front paws
      {0.15, 0.06}, {0.13, 0.02}, {0.22, 0.02}, {0.24, 0.06},
      # Belly
      {0.28, 0.08}, {0.40, 0.06}, {0.55, 0.04},
      # Rear paws
      {0.58, 0.02}, {0.70, 0.02}, {0.72, 0.05},
      # Haunch
      {0.78, 0.18}, {0.82, 0.35},
      # Back rises
      {0.80, 0.50}, {0.72, 0.62}, {0.60, 0.68},
      {0.48, 0.70}, {0.38, 0.68},
      # Neck
      {0.30, 0.62}, {0.24, 0.58},
      # Head (round)
      {0.20, 0.56}, {0.16, 0.52}, {0.12, 0.50},
      {0.08, 0.46}, {0.06, 0.40}
    ]

    # Left ear (triangular, pointy)
    left_ear = [
      {0.13, 0.54}, {0.08, 0.72}, {0.06, 0.78},
      {0.10, 0.74}, {0.16, 0.58}
    ]

    # Right ear
    right_ear = [
      {0.20, 0.56}, {0.18, 0.74}, {0.17, 0.80},
      {0.22, 0.72}, {0.25, 0.58}
    ]

    # Tail (curves up from rump)
    tail = [
      {0.80, 0.42}, {0.84, 0.55}, {0.88, 0.68},
      {0.92, 0.78}, {0.96, 0.85}, {0.98, 0.82},
      {0.94, 0.74}, {0.90, 0.62}, {0.86, 0.48}, {0.82, 0.38}
    ]

    barcode_region = {0.20, 0.06, 0.55, 0.55}

    cutouts = [
      {:circle_bg, {0.10, 0.46, 0.016}},
      # Inner ear
      {:polygon_bg, [{0.10, 0.58}, {0.08, 0.70}, {0.12, 0.70}, {0.14, 0.58}]},
      {:polygon_bg, [{0.20, 0.60}, {0.19, 0.70}, {0.22, 0.68}, {0.23, 0.60}]}
    ]

    decorations = [
      {:circle, {0.10, 0.46, 0.006}},
      {:circle, {0.07, 0.36, 0.006}},
      # Whiskers
      {:line, {0.07, 0.35, 0.00, 0.38}},
      {:line, {0.07, 0.34, 0.00, 0.32}},
      {:line, {0.07, 0.33, 0.01, 0.28}}
    ]

    {:silhouette, [body, left_ear, right_ear, tail], barcode_region, decorations, cutouts, 1.6}
  end

  defp resolve_shape(:dog, _, _) do
    # Standing dog facing left
    body = [
      # Nose/snout
      {0.04, 0.48},
      # Under jaw
      {0.06, 0.42}, {0.10, 0.38},
      # Chest
      {0.14, 0.32}, {0.16, 0.22},
      # Front leg 1
      {0.15, 0.08}, {0.14, 0.02}, {0.20, 0.02}, {0.21, 0.08},
      # Gap
      {0.22, 0.18},
      # Front leg 2
      {0.23, 0.08}, {0.22, 0.02}, {0.28, 0.02}, {0.29, 0.08},
      {0.30, 0.20},
      # Belly
      {0.38, 0.16}, {0.50, 0.14}, {0.60, 0.16},
      # Rear leg 1
      {0.62, 0.08}, {0.61, 0.02}, {0.67, 0.02}, {0.68, 0.08},
      {0.69, 0.18},
      # Rear leg 2
      {0.70, 0.08}, {0.69, 0.02}, {0.75, 0.02}, {0.76, 0.10},
      # Rump
      {0.78, 0.28}, {0.80, 0.42},
      # Tail (up!)
      {0.82, 0.55}, {0.85, 0.68}, {0.88, 0.78},
      {0.90, 0.82}, {0.92, 0.78}, {0.90, 0.70},
      {0.86, 0.58}, {0.82, 0.48},
      # Back
      {0.78, 0.56}, {0.68, 0.62}, {0.55, 0.65},
      {0.42, 0.66}, {0.32, 0.64},
      # Neck
      {0.24, 0.60}, {0.18, 0.58},
      # Head top
      {0.14, 0.60}, {0.10, 0.62},
      {0.06, 0.60}, {0.04, 0.55}
    ]

    # Ear (floppy, hanging)
    ear = [
      {0.10, 0.60}, {0.07, 0.56}, {0.05, 0.50},
      {0.06, 0.44}, {0.08, 0.42},
      {0.12, 0.48}, {0.14, 0.56}, {0.13, 0.60}
    ]

    barcode_region = {0.22, 0.14, 0.52, 0.46}

    cutouts = [
      {:circle_bg, {0.08, 0.56, 0.014}}
    ]

    decorations = [
      {:circle, {0.08, 0.56, 0.005}},
      {:circle, {0.05, 0.50, 0.006}},
      {:line, {0.05, 0.46, 0.04, 0.42}}
    ]

    {:silhouette, [body, ear], barcode_region, decorations, cutouts, 1.5}
  end

  defp resolve_shape(:bird, _, _) do
    # Bird facing left — standing
    body = [
      # Beak tip
      {0.02, 0.58},
      # Under beak
      {0.06, 0.54}, {0.10, 0.50},
      # Chest
      {0.15, 0.40}, {0.18, 0.30},
      # Leg 1
      {0.22, 0.15}, {0.20, 0.04}, {0.18, 0.02},
      {0.24, 0.02}, {0.26, 0.04}, {0.25, 0.15},
      # Leg 2
      {0.28, 0.04}, {0.26, 0.02}, {0.32, 0.02},
      {0.34, 0.04}, {0.32, 0.18},
      # Belly
      {0.40, 0.22}, {0.50, 0.25}, {0.58, 0.30},
      # Tail feathers (spread)
      {0.65, 0.35}, {0.72, 0.42}, {0.80, 0.52},
      {0.86, 0.62}, {0.90, 0.70},
      {0.92, 0.75}, {0.94, 0.72},
      {0.90, 0.65}, {0.85, 0.58},
      # Back
      {0.75, 0.60}, {0.62, 0.65}, {0.50, 0.68},
      {0.40, 0.70}, {0.30, 0.68},
      # Neck
      {0.22, 0.66}, {0.16, 0.68},
      # Head
      {0.12, 0.72}, {0.08, 0.72},
      {0.04, 0.68}, {0.02, 0.64}
    ]

    # Crest
    crest = [
      {0.08, 0.72}, {0.04, 0.82}, {0.02, 0.88},
      {0.06, 0.84}, {0.10, 0.76}, {0.12, 0.72}
    ]

    # Wing (overlaid on body)
    wing = [
      {0.28, 0.58}, {0.35, 0.48}, {0.45, 0.40},
      {0.55, 0.38}, {0.62, 0.42}, {0.58, 0.52},
      {0.50, 0.60}, {0.40, 0.64}, {0.32, 0.62}
    ]

    barcode_region = {0.22, 0.18, 0.50, 0.42}

    cutouts = [
      {:circle_bg, {0.07, 0.66, 0.014}},
      # Wing detail lines
      {:polygon_bg, [{0.32, 0.54}, {0.42, 0.46}, {0.50, 0.44}, {0.48, 0.50}, {0.38, 0.56}]}
    ]

    decorations = [
      {:circle, {0.07, 0.66, 0.005}},
      # Beak
      {:polygon, [{0.02, 0.62}, {0.00, 0.58}, {0.04, 0.56}, {0.06, 0.58}]}
    ]

    {:silhouette, [body, crest, wing], barcode_region, decorations, cutouts, 1.5}
  end

  defp resolve_shape(:fish, _, _) do
    # Fish facing left — horizontal
    body = [
      # Mouth
      {0.03, 0.50},
      # Bottom jaw
      {0.06, 0.44}, {0.12, 0.36},
      # Belly
      {0.20, 0.28}, {0.30, 0.22}, {0.40, 0.18},
      {0.50, 0.16}, {0.60, 0.18},
      # Tail narrows
      {0.70, 0.24}, {0.76, 0.30},
      # Tail fin bottom
      {0.80, 0.20}, {0.86, 0.10}, {0.90, 0.05},
      # Tail fin tip
      {0.94, 0.12}, {0.96, 0.30},
      # Tail center
      {0.92, 0.42}, {0.90, 0.50},
      # Tail fin top
      {0.96, 0.70}, {0.94, 0.88},
      {0.90, 0.95}, {0.86, 0.90}, {0.80, 0.80},
      # Back (top)
      {0.76, 0.70}, {0.70, 0.76},
      {0.60, 0.82}, {0.50, 0.84},
      {0.40, 0.82}, {0.30, 0.78},
      {0.20, 0.72},
      # Forehead
      {0.12, 0.64}, {0.06, 0.56}
    ]

    # Dorsal fin
    dorsal_fin = [
      {0.30, 0.78}, {0.35, 0.90}, {0.40, 0.96},
      {0.45, 0.94}, {0.48, 0.86}, {0.45, 0.82}, {0.38, 0.80}
    ]

    # Pectoral fin
    pectoral_fin = [
      {0.22, 0.42}, {0.28, 0.30}, {0.34, 0.26},
      {0.32, 0.34}, {0.28, 0.40}, {0.24, 0.44}
    ]

    barcode_region = {0.12, 0.22, 0.58, 0.52}

    cutouts = [
      # Eye
      {:circle_bg, {0.10, 0.56, 0.022}},
      # Gill line
      {:polygon_bg, [{0.16, 0.62}, {0.18, 0.38}, {0.19, 0.38}, {0.17, 0.62}]}
    ]

    decorations = [
      # Pupil
      {:circle, {0.10, 0.56, 0.009}},
      # Tail detail
      {:line, {0.82, 0.50, 0.90, 0.50}}
    ]

    {:silhouette, [body, dorsal_fin, pectoral_fin], barcode_region, decorations, cutouts, 2.0}
  end

  defp resolve_shape(:horse, _, _) do
    body = [
      # Nose
      {0.04, 0.55},
      # Under jaw
      {0.06, 0.48}, {0.10, 0.42},
      # Chest
      {0.14, 0.35}, {0.16, 0.25},
      # Front leg 1
      {0.17, 0.12}, {0.16, 0.02}, {0.21, 0.02}, {0.22, 0.12},
      {0.23, 0.22},
      # Front leg 2
      {0.24, 0.12}, {0.23, 0.02}, {0.28, 0.02}, {0.29, 0.12},
      {0.30, 0.24},
      # Belly
      {0.40, 0.20}, {0.52, 0.18}, {0.62, 0.20},
      # Rear leg 1
      {0.64, 0.12}, {0.63, 0.02}, {0.68, 0.02}, {0.69, 0.12},
      {0.70, 0.22},
      # Rear leg 2
      {0.71, 0.12}, {0.70, 0.02}, {0.75, 0.02}, {0.76, 0.14},
      # Rump
      {0.78, 0.32}, {0.80, 0.48},
      # Tail
      {0.82, 0.52}, {0.86, 0.48}, {0.90, 0.42},
      {0.94, 0.36}, {0.96, 0.30},
      {0.94, 0.34}, {0.90, 0.40},
      {0.86, 0.46}, {0.82, 0.50},
      # Back
      {0.78, 0.58}, {0.68, 0.64}, {0.55, 0.68},
      {0.42, 0.70}, {0.30, 0.68},
      # Neck (long, arched)
      {0.22, 0.66}, {0.16, 0.68}, {0.12, 0.72},
      # Head
      {0.08, 0.70}, {0.06, 0.66},
      {0.04, 0.62}
    ]

    # Mane
    mane = [
      {0.14, 0.70}, {0.12, 0.76}, {0.14, 0.80},
      {0.18, 0.78}, {0.20, 0.74}, {0.22, 0.70},
      {0.24, 0.68}, {0.22, 0.66}, {0.18, 0.68}
    ]

    # Ear
    ear = [
      {0.07, 0.70}, {0.05, 0.80}, {0.04, 0.84},
      {0.07, 0.82}, {0.09, 0.74}, {0.10, 0.72}
    ]

    barcode_region = {0.22, 0.18, 0.50, 0.44}

    cutouts = [
      {:circle_bg, {0.07, 0.64, 0.012}}
    ]

    decorations = [
      {:circle, {0.07, 0.64, 0.004}},
      {:circle, {0.05, 0.56, 0.004}}
    ]

    {:silhouette, [body, mane, ear], barcode_region, decorations, cutouts, 1.6}
  end

  defp resolve_shape(:elephant, _, _) do
    body = [
      # Trunk tip
      {0.04, 0.15},
      # Trunk
      {0.06, 0.10}, {0.08, 0.08}, {0.10, 0.12},
      {0.11, 0.20}, {0.10, 0.28}, {0.08, 0.32},
      # Front legs
      {0.12, 0.18}, {0.14, 0.06}, {0.13, 0.02},
      {0.20, 0.02}, {0.21, 0.06}, {0.22, 0.14},
      {0.24, 0.06}, {0.23, 0.02}, {0.30, 0.02},
      {0.31, 0.10}, {0.32, 0.18},
      # Belly
      {0.40, 0.14}, {0.52, 0.12}, {0.62, 0.14},
      # Rear legs
      {0.64, 0.06}, {0.63, 0.02}, {0.70, 0.02},
      {0.71, 0.08}, {0.72, 0.16},
      {0.73, 0.08}, {0.72, 0.02}, {0.79, 0.02},
      {0.80, 0.10},
      # Rump
      {0.82, 0.30}, {0.84, 0.48},
      # Tail
      {0.86, 0.50}, {0.90, 0.46}, {0.92, 0.42},
      {0.90, 0.44}, {0.86, 0.48},
      # Back
      {0.82, 0.60}, {0.72, 0.68}, {0.60, 0.72},
      {0.48, 0.74}, {0.36, 0.72}, {0.26, 0.68},
      # Head
      {0.18, 0.64}, {0.14, 0.62}, {0.10, 0.60},
      {0.06, 0.55}, {0.04, 0.48},
      # Trunk start
      {0.06, 0.40}, {0.08, 0.35}
    ]

    # Ear (large!)
    ear = [
      {0.12, 0.58}, {0.08, 0.52}, {0.04, 0.44},
      {0.02, 0.38}, {0.04, 0.32}, {0.08, 0.36},
      {0.12, 0.42}, {0.16, 0.52}, {0.15, 0.58}
    ]

    barcode_region = {0.22, 0.12, 0.52, 0.52}

    cutouts = [
      {:circle_bg, {0.09, 0.56, 0.012}},
      # Ear inner
      {:polygon_bg, [{0.08, 0.50}, {0.05, 0.42}, {0.06, 0.36}, {0.10, 0.44}, {0.12, 0.50}]}
    ]

    decorations = [
      {:circle, {0.09, 0.56, 0.004}},
      # Tusk
      {:line, {0.09, 0.35, 0.06, 0.25}}
    ]

    {:silhouette, [body, ear], barcode_region, decorations, cutouts, 1.6}
  end

  # ════════════════════════════════════════════════════════════════
  # CONTOUR SHAPES — bars with variable heights
  # ════════════════════════════════════════════════════════════════
  # Returns {:contour, contour_top, contour_bottom, decorations, aspect}

  defp resolve_shape(nil, nil, _), do: {:contour, nil, nil, [], 3.0}
  defp resolve_shape(nil, top, bot), do: {:contour, top, bot, [], 3.0}

  defp resolve_shape(:rv, _, _) do
    top = [
      {0.00, 0.08}, {0.02, 0.08},
      {0.04, 0.48}, {0.06, 0.58},
      {0.08, 0.60}, {0.14, 0.60},
      {0.15, 0.68}, {0.21, 0.68}, {0.22, 0.60},
      {0.24, 0.60}, {0.52, 0.60},
      {0.54, 0.66}, {0.57, 0.78}, {0.60, 0.90},
      {0.62, 1.00}, {0.70, 1.00},
      {0.73, 0.88}, {0.76, 0.68}, {0.79, 0.48},
      {0.82, 0.33}, {0.88, 0.28},
      {0.92, 0.18}, {0.96, 0.08}, {1.00, 0.08}
    ]

    bottom = [
      {0.00, 0.00}, {0.06, 0.00},
      {0.09, 0.00}, {0.11, 0.10}, {0.14, 0.18}, {0.18, 0.18},
      {0.21, 0.10}, {0.23, 0.00},
      {0.26, 0.00}, {0.54, 0.00},
      {0.58, 0.00}, {0.60, 0.10}, {0.63, 0.18}, {0.67, 0.18},
      {0.70, 0.10}, {0.72, 0.00},
      {0.75, 0.00}, {1.00, 0.00}
    ]

    decorations = [
      {:circle, {0.16, 0.08, 0.055}},
      {:circle, {0.65, 0.08, 0.055}},
      {:circle_stroke, {0.16, 0.08, 0.025}},
      {:circle_stroke, {0.65, 0.08, 0.025}},
      {:polygon, [{0.71, 0.92}, {0.71, 0.62}, {0.80, 0.42}, {0.80, 0.62}]},
      {:polygon, [{0.62, 0.92}, {0.62, 0.65}, {0.69, 0.65}, {0.69, 0.92}]},
      {:polygon, [{0.26, 0.55}, {0.26, 0.42}, {0.34, 0.42}, {0.34, 0.55}]},
      {:polygon, [{0.36, 0.55}, {0.36, 0.42}, {0.44, 0.42}, {0.44, 0.55}]},
      {:polygon, [{0.46, 0.55}, {0.46, 0.42}, {0.52, 0.42}, {0.52, 0.55}]}
    ]

    {:contour, top, bottom, decorations, 3.0}
  end

  defp resolve_shape(:camper, _, _) do
    top = [
      {0.00, 0.05},
      {0.03, 0.28}, {0.05, 0.68},
      {0.08, 0.83}, {0.15, 0.88}, {0.30, 0.93}, {0.50, 1.0},
      {0.65, 0.93}, {0.75, 0.88},
      {0.85, 0.78}, {0.90, 0.58},
      {0.95, 0.28}, {0.97, 0.13}, {1.00, 0.05}
    ]

    bottom = [
      {0.00, 0.00}, {0.10, 0.00},
      {0.13, 0.00}, {0.15, 0.12}, {0.18, 0.19}, {0.22, 0.19},
      {0.25, 0.12}, {0.27, 0.00},
      {0.30, 0.00}, {0.70, 0.00},
      {0.73, 0.00}, {0.75, 0.12}, {0.78, 0.19}, {0.82, 0.19},
      {0.85, 0.12}, {0.87, 0.00},
      {0.90, 0.00}, {1.00, 0.00}
    ]

    decorations = [
      {:circle, {0.20, 0.07, 0.05}},
      {:circle, {0.80, 0.07, 0.05}},
      {:circle_stroke, {0.20, 0.07, 0.02}},
      {:circle_stroke, {0.80, 0.07, 0.02}},
      {:polygon, [{0.42, 0.70}, {0.42, 0.25}, {0.58, 0.25}, {0.58, 0.70}]},
      {:polygon, [{0.44, 0.68}, {0.44, 0.50}, {0.56, 0.50}, {0.56, 0.68}]},
      {:polygon, [{0.12, 0.65}, {0.12, 0.48}, {0.25, 0.48}, {0.25, 0.65}]},
      {:polygon, [{0.75, 0.65}, {0.75, 0.48}, {0.88, 0.48}, {0.88, 0.65}]},
      {:line, {0.00, 0.05, -0.04, 0.05}}
    ]

    {:contour, top, bottom, decorations, 2.5}
  end

  defp resolve_shape(:wave, _, _) do
    top =
      for i <- 0..40 do
        x = i / 40
        y = 0.35 + 0.65 * :math.sin(x * :math.pi() * 2)
        {x, max(y, 0.03)}
      end

    {:contour, top, nil, [], 3.5}
  end

  defp resolve_shape(:diamond, _, _) do
    top = [
      {0.0, 0.05}, {0.10, 0.20}, {0.20, 0.40}, {0.30, 0.60},
      {0.40, 0.80}, {0.50, 1.0},
      {0.60, 0.80}, {0.70, 0.60}, {0.80, 0.40}, {0.90, 0.20}, {1.0, 0.05}
    ]

    {:contour, top, nil, [], 2.5}
  end

  defp resolve_shape(:hill, _, _) do
    top =
      for i <- 0..40 do
        x = i / 40
        y = :math.sin(x * :math.pi())
        {x, max(y, 0.03)}
      end

    {:contour, top, nil, [], 3.0}
  end

  defp resolve_shape(:city, _, _) do
    top = [
      {0.00, 0.30}, {0.05, 0.30}, {0.05, 0.70}, {0.10, 0.70},
      {0.10, 0.40}, {0.15, 0.40}, {0.15, 1.0}, {0.22, 1.0},
      {0.22, 0.50}, {0.28, 0.50}, {0.28, 0.85}, {0.35, 0.85},
      {0.35, 0.35}, {0.40, 0.35}, {0.40, 0.65}, {0.48, 0.65},
      {0.48, 0.90}, {0.55, 0.90}, {0.55, 0.45}, {0.60, 0.45},
      {0.60, 0.75}, {0.68, 0.75}, {0.68, 0.55}, {0.72, 0.55},
      {0.72, 0.95}, {0.80, 0.95}, {0.80, 0.40}, {0.85, 0.40},
      {0.85, 0.60}, {0.92, 0.60}, {0.92, 0.30}, {1.00, 0.30}
    ]

    decorations = [
      {:line, {0.185, 1.0, 0.185, 1.12}},
      {:polygon, [{0.16, 0.90}, {0.16, 0.85}, {0.18, 0.85}, {0.18, 0.90}]},
      {:polygon, [{0.19, 0.90}, {0.19, 0.85}, {0.21, 0.85}, {0.21, 0.90}]},
      {:polygon, [{0.16, 0.78}, {0.16, 0.73}, {0.18, 0.73}, {0.18, 0.78}]},
      {:polygon, [{0.19, 0.78}, {0.19, 0.73}, {0.21, 0.73}, {0.21, 0.78}]}
    ]

    {:contour, top, nil, decorations, 3.5}
  end

  defp resolve_shape(_unknown, _, _), do: {:contour, nil, nil, [], 3.0}

  @doc """
  List all available predefined shapes.
  """
  def available_shapes do
    [
      # Animals (silhouette style — solid shape + barcode inside body)
      :rabbit, :cat, :dog, :bird, :fish, :horse, :elephant,
      # Vehicles (contour style — bar heights follow outline)
      :rv, :camper,
      # Geometric (contour style)
      :city, :wave, :diamond, :hill
    ]
  end
end
