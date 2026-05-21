defmodule ExQR.Matrix do
  @moduledoc """
  QR Code matrix construction: function patterns, data placement,
  masking, and format information.

  The matrix is represented as a map of `{row, col} => value`
  where value is 0 (white) or 1 (black).
  """

  import Bitwise
  alias ExQR.Tables

  @doc """
  Build the final QR matrix for a given version, EC level, and codewords.

  Returns a `size × size` matrix as a map of `{row, col} => 0 | 1`.
  """
  def build(version, level, codewords) do
    size = Tables.size(version)

    matrix = %{}
    reserved = %{}

    {matrix, reserved} = place_finder_patterns(matrix, reserved, size)
    {matrix, reserved} = place_timing_patterns(matrix, reserved, size)
    {matrix, reserved} = place_alignment_patterns(matrix, reserved, version)
    {matrix, reserved} = reserve_format_areas(matrix, reserved, size)
    {matrix, reserved} = place_dark_module(matrix, reserved, version)
    {matrix, reserved} = maybe_reserve_version_areas(matrix, reserved, version, size)

    matrix = place_data(matrix, reserved, codewords, size)

    {best_mask, best_matrix} = select_best_mask(matrix, reserved, size)

    apply_format_info(best_matrix, size, level, best_mask)
  end

  # ── Finder patterns (3 corners) ────────────────────────────────

  defp place_finder_patterns(matrix, reserved, size) do
    positions = [{0, 0}, {0, size - 7}, {size - 7, 0}]

    Enum.reduce(positions, {matrix, reserved}, fn {sr, sc}, {m, r} ->
      place_finder_pattern(m, r, sr, sc, size)
    end)
  end

  defp place_finder_pattern(matrix, reserved, start_row, start_col, size) do
    finder = [
      [1, 1, 1, 1, 1, 1, 1],
      [1, 0, 0, 0, 0, 0, 1],
      [1, 0, 1, 1, 1, 0, 1],
      [1, 0, 1, 1, 1, 0, 1],
      [1, 0, 1, 1, 1, 0, 1],
      [1, 0, 0, 0, 0, 0, 1],
      [1, 1, 1, 1, 1, 1, 1]
    ]

    {m, r} =
      finder
      |> Enum.with_index()
      |> Enum.reduce({matrix, reserved}, fn {row_vals, ri}, {m, r} ->
        row_vals
        |> Enum.with_index()
        |> Enum.reduce({m, r}, fn {val, ci}, {m, r} ->
          pos = {start_row + ri, start_col + ci}
          {Map.put(m, pos, val), Map.put(r, pos, true)}
        end)
      end)

    sep_positions = separator_positions(start_row, start_col, size)
    Enum.reduce(sep_positions, {m, r}, fn pos, {m, r} ->
      {Map.put(m, pos, 0), Map.put(r, pos, true)}
    end)
  end

  defp separator_positions(sr, sc, size) do
    for r <- (sr - 1)..(sr + 7),
        c <- (sc - 1)..(sc + 7),
        r >= 0 and r < size and c >= 0 and c < size,
        (r < sr or r > sr + 6 or c < sc or c > sc + 6),
        do: {r, c}
  end

  # ── Timing patterns ────────────────────────────────────────────

  defp place_timing_patterns(matrix, reserved, size) do
    Enum.reduce(8..(size - 9), {matrix, reserved}, fn i, {m, r} ->
      val = if rem(i, 2) == 0, do: 1, else: 0
      m = if not Map.has_key?(r, {6, i}), do: Map.put(m, {6, i}, val), else: m
      r = Map.put(r, {6, i}, true)
      m = if not Map.has_key?(r, {i, 6}), do: Map.put(m, {i, 6}, val), else: m
      r = Map.put(r, {i, 6}, true)
      {m, r}
    end)
  end

  # ── Alignment patterns ─────────────────────────────────────────

  defp place_alignment_patterns(matrix, reserved, version) do
    positions = Tables.alignment_positions(version)

    if positions == [] do
      {matrix, reserved}
    else
      centers =
        for r <- positions, c <- positions,
            not overlaps_finder?(r, c, Tables.size(version)),
            do: {r, c}

      Enum.reduce(centers, {matrix, reserved}, fn {cr, cc}, {m, r} ->
        place_alignment_pattern(m, r, cr, cc)
      end)
    end
  end

  defp overlaps_finder?(r, c, size) do
    (r <= 8 and c <= 8) or
    (r <= 8 and c >= size - 9) or
    (r >= size - 9 and c <= 8)
  end

  defp place_alignment_pattern(matrix, reserved, cr, cc) do
    pattern = [
      [1, 1, 1, 1, 1],
      [1, 0, 0, 0, 1],
      [1, 0, 1, 0, 1],
      [1, 0, 0, 0, 1],
      [1, 1, 1, 1, 1]
    ]

    pattern
    |> Enum.with_index(-2)
    |> Enum.reduce({matrix, reserved}, fn {row_vals, ri}, {m, r} ->
      row_vals
      |> Enum.with_index(-2)
      |> Enum.reduce({m, r}, fn {val, ci}, {m, r} ->
        pos = {cr + ri, cc + ci}
        {Map.put(m, pos, val), Map.put(r, pos, true)}
      end)
    end)
  end

  # ── Format and version reserved areas ──────────────────────────

  defp reserve_format_areas(matrix, reserved, size) do
    positions =
      (for c <- 0..8, do: {8, c}) ++
      (for r <- 0..8, r != 8, do: {r, 8}) ++
      (for c <- (size - 8)..(size - 1), do: {8, c}) ++
      (for r <- (size - 7)..(size - 1), do: {r, 8})

    Enum.reduce(positions, {matrix, reserved}, fn pos, {m, r} ->
      {m, Map.put(r, pos, true)}
    end)
  end

  defp place_dark_module(matrix, reserved, version) do
    pos = {4 * version + 9, 8}
    {Map.put(matrix, pos, 1), Map.put(reserved, pos, true)}
  end

  defp maybe_reserve_version_areas(matrix, reserved, version, size) when version >= 7 do
    positions =
      (for r <- 0..5, c <- (size - 11)..(size - 9), do: {r, c}) ++
      (for r <- (size - 11)..(size - 9), c <- 0..5, do: {r, c})

    Enum.reduce(positions, {matrix, reserved}, fn pos, {m, r} ->
      {m, Map.put(r, pos, true)}
    end)
  end

  defp maybe_reserve_version_areas(matrix, reserved, _version, _size), do: {matrix, reserved}

  # ── Data placement ─────────────────────────────────────────────

  defp place_data(matrix, reserved, codewords, size) do
    bits = codewords_to_bits(codewords)

    columns = data_columns(size)

    {matrix, _bit_idx} =
      Enum.reduce(columns, {matrix, 0}, fn {col, direction}, {m, idx} ->
        rows = if direction == :up, do: (size - 1)..0//-1, else: 0..(size - 1)

        Enum.reduce(rows, {m, idx}, fn row, {m, idx} ->
          Enum.reduce([col, col - 1], {m, idx}, fn c, {m, idx} ->
            if Map.get(reserved, {row, c}) do
              {m, idx}
            else
              bit = if idx < length(bits), do: Enum.at(bits, idx), else: 0
              {Map.put(m, {row, c}, bit), idx + 1}
            end
          end)
        end)
      end)

    matrix
  end

  defp data_columns(size) do
    cols =
      (size - 1)..1//-2
      |> Enum.to_list()
      |> Enum.map(fn c -> if c <= 6, do: c - 1, else: c end)

    cols
    |> Enum.with_index()
    |> Enum.map(fn {c, i} ->
      direction = if rem(i, 2) == 0, do: :up, else: :down
      {c, direction}
    end)
  end

  defp codewords_to_bits(codewords) do
    Enum.flat_map(codewords, fn cw ->
      for i <- 7..0//-1, do: (cw >>> i) &&& 1
    end)
  end

  # ── Masking ────────────────────────────────────────────────────

  defp select_best_mask(matrix, reserved, size) do
    0..7
    |> Enum.map(fn mask ->
      masked = apply_mask(matrix, reserved, size, mask)
      penalty = compute_penalty(masked, size)
      {mask, masked, penalty}
    end)
    |> Enum.min_by(fn {_mask, _m, penalty} -> penalty end)
    |> then(fn {mask, m, _} -> {mask, m} end)
  end

  defp apply_mask(matrix, reserved, size, mask_num) do
    for r <- 0..(size - 1),
        c <- 0..(size - 1),
        reduce: matrix do
      m ->
        if Map.get(reserved, {r, c}) do
          m
        else
          val = Map.get(m, {r, c}, 0)
          if mask_condition?(mask_num, r, c) do
            Map.put(m, {r, c}, bxor(val, 1))
          else
            m
          end
        end
    end
  end

  defp mask_condition?(0, r, c), do: rem(r + c, 2) == 0
  defp mask_condition?(1, r, _c), do: rem(r, 2) == 0
  defp mask_condition?(2, _r, c), do: rem(c, 3) == 0
  defp mask_condition?(3, r, c), do: rem(r + c, 3) == 0
  defp mask_condition?(4, r, c), do: rem(div(r, 2) + div(c, 3), 2) == 0
  defp mask_condition?(5, r, c), do: rem(r * c, 2) + rem(r * c, 3) == 0
  defp mask_condition?(6, r, c), do: rem(rem(r * c, 2) + rem(r * c, 3), 2) == 0
  defp mask_condition?(7, r, c), do: rem(rem(r + c, 2) + rem(r * c, 3), 2) == 0

  # ── Penalty scoring ────────────────────────────────────────────

  defp compute_penalty(matrix, size) do
    penalty_rule1(matrix, size) +
    penalty_rule2(matrix, size) +
    penalty_rule3(matrix, size) +
    penalty_rule4(matrix, size)
  end

  defp penalty_rule1(matrix, size) do
    rows_penalty =
      Enum.sum(for r <- 0..(size - 1) do
        vals = for c <- 0..(size - 1), do: Map.get(matrix, {r, c}, 0)
        count_runs(vals)
      end)

    cols_penalty =
      Enum.sum(for c <- 0..(size - 1) do
        vals = for r <- 0..(size - 1), do: Map.get(matrix, {r, c}, 0)
        count_runs(vals)
      end)

    rows_penalty + cols_penalty
  end

  defp count_runs(vals) do
    {penalty, _, _count} =
      Enum.reduce(vals, {0, -1, 0}, fn val, {pen, prev, cnt} ->
        if val == prev do
          cnt = cnt + 1
          pen = if cnt == 5, do: pen + 3, else: if(cnt > 5, do: pen + 1, else: pen)
          {pen, val, cnt}
        else
          {pen, val, 1}
        end
      end)

    penalty
  end

  defp penalty_rule2(matrix, size) do
    Enum.sum(
      for r <- 0..(size - 2), c <- 0..(size - 2) do
        v = Map.get(matrix, {r, c}, 0)
        if v == Map.get(matrix, {r, c + 1}, 0) and
           v == Map.get(matrix, {r + 1, c}, 0) and
           v == Map.get(matrix, {r + 1, c + 1}, 0) do
          3
        else
          0
        end
      end
    )
  end

  defp penalty_rule3(matrix, size) do
    pattern_a = [1, 0, 1, 1, 1, 0, 1, 0, 0, 0, 0]
    pattern_b = [0, 0, 0, 0, 1, 0, 1, 1, 1, 0, 1]

    rows =
      Enum.sum(for r <- 0..(size - 1), c <- 0..(size - 11) do
        segment = for i <- 0..10, do: Map.get(matrix, {r, c + i}, 0)
        cond do
          segment == pattern_a -> 40
          segment == pattern_b -> 40
          true -> 0
        end
      end)

    cols =
      Enum.sum(for c <- 0..(size - 1), r <- 0..(size - 11) do
        segment = for i <- 0..10, do: Map.get(matrix, {r + i, c}, 0)
        cond do
          segment == pattern_a -> 40
          segment == pattern_b -> 40
          true -> 0
        end
      end)

    rows + cols
  end

  defp penalty_rule4(matrix, size) do
    total = size * size
    all_modules = for r <- 0..(size - 1), c <- 0..(size - 1), do: Map.get(matrix, {r, c}, 0)
    dark = Enum.count(all_modules, &(&1 == 1))
    pct = dark * 100 / total
    prev5 = trunc(pct / 5) * 5
    next5 = prev5 + 5
    min(abs(prev5 - 50), abs(next5 - 50)) * 2
  end

  # ── Format information ─────────────────────────────────────────

  defp apply_format_info(matrix, size, level, mask) do
    format = Tables.format_info(level, mask)
    bits = for i <- 14..0//-1, do: (format >>> i) &&& 1

    h_positions = [
      {8, 0}, {8, 1}, {8, 2}, {8, 3}, {8, 4}, {8, 5},
      {8, 7}, {8, 8},
      {7, 8}, {5, 8}, {4, 8}, {3, 8}, {2, 8}, {1, 8}, {0, 8}
    ]

    matrix =
      h_positions
      |> Enum.zip(bits)
      |> Enum.reduce(matrix, fn {{r, c}, bit}, m -> Map.put(m, {r, c}, bit) end)

    v_positions = [
      {size - 1, 8}, {size - 2, 8}, {size - 3, 8}, {size - 4, 8},
      {size - 5, 8}, {size - 6, 8}, {size - 7, 8},
      {8, size - 8}, {8, size - 7}, {8, size - 6}, {8, size - 5},
      {8, size - 4}, {8, size - 3}, {8, size - 2}, {8, size - 1}
    ]

    v_positions
    |> Enum.zip(bits)
    |> Enum.reduce(matrix, fn {{r, c}, bit}, m -> Map.put(m, {r, c}, bit) end)
  end
end
