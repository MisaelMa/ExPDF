defmodule Pdf.Reader.LineTest do
  @moduledoc """
  Unit tests for line reconstruction from synthetic TextRun lists.
  Real-world end-to-end coverage lives in `csf_test.exs`.
  """
  use ExUnit.Case, async: true

  alias Pdf.Reader.{Line, TextRun}

  # Build a minimal Document that already has page_refs cached, so
  # `read_lines/2` skips the open-time pipeline. We bypass it entirely
  # below by exercising the lower-level grouping function via a runs list.
  defp run(text, x, y, opts \\ []) do
    %TextRun{
      text: text,
      x: x * 1.0,
      y: y * 1.0,
      size: Keyword.get(opts, :size, 10.0),
      font: Keyword.get(opts, :font, "F1"),
      page: Keyword.get(opts, :page, 1),
      unresolved: []
    }
  end

  describe "Pdf.Reader.lines_from_runs/2 — grouping by Y baseline" do
    test "two runs at the same Y collapse into one line, sorted by X" do
      runs = [
        run("World", 100, 700),
        run("Hello", 50, 700)
      ]

      assert [%Line{} = line] = Pdf.Reader.lines_from_runs(runs)
      assert line.text == "Hello World"
      assert line.y == 700.0
      assert line.x == 50.0
      assert length(line.tokens) == 2
    end

    test "runs at different Ys produce separate lines, sorted top-to-bottom" do
      runs = [
        run("bottom", 50, 100),
        run("top", 50, 700),
        run("middle", 50, 400)
      ]

      assert [top, middle, bottom] = Pdf.Reader.lines_from_runs(runs)
      assert top.text == "top"
      assert middle.text == "middle"
      assert bottom.text == "bottom"
    end

    test "runs within the y_tolerance window are merged onto the same line" do
      runs = [
        run("a", 50, 700.0),
        run("b", 70, 700.4),
        run("c", 90, 699.7)
      ]

      assert [line] = Pdf.Reader.lines_from_runs(runs, y_tolerance: 2.0)
      assert line.text =~ "a"
      assert line.text =~ "b"
      assert line.text =~ "c"
    end
  end

  describe "tokenization by X-gap" do
    test "consecutive close runs form a single token" do
      runs = [
        run("H", 50, 700, size: 10.0),
        run("e", 56, 700, size: 10.0),
        run("l", 62, 700, size: 10.0),
        run("l", 67, 700, size: 10.0),
        run("o", 73, 700, size: 10.0)
      ]

      assert [line] = Pdf.Reader.lines_from_runs(runs)
      assert line.text == "Hello"
      assert length(line.tokens) == 1
      assert hd(line.tokens).text == "Hello"
    end

    test "a wide X-gap splits runs into separate tokens" do
      # font size 10 → default gap_factor 0.5 → threshold ~5pt
      # First cluster ends at x=62 ("Hel"), big gap to x=200 ("World")
      runs = [
        run("H", 50, 700),
        run("e", 56, 700),
        run("l", 62, 700),
        run("W", 200, 700),
        run("o", 206, 700),
        run("r", 212, 700),
        run("l", 218, 700),
        run("d", 224, 700)
      ]

      assert [line] = Pdf.Reader.lines_from_runs(runs)
      assert line.text == "Hel World"
      assert length(line.tokens) == 2

      [tok1, tok2] = line.tokens
      assert tok1.text == "Hel"
      assert tok1.x == 50.0
      assert tok2.text == "World"
      assert tok2.x == 200.0
    end

    test "table row produces tokens at column X positions" do
      # Imagine: "Asalariado | 100 | 29/06/2015"
      runs =
        Enum.map(String.graphemes("Asalariado"), fn g ->
          # 6pt advance per char from x=70
          idx = :string.length('Asalariado') - length(String.graphemes(g)) + 0
          {g, idx}
        end)
        |> Enum.with_index()
        |> Enum.map(fn {{g, _}, i} -> run(g, 70 + i * 6, 400) end)

      runs =
        runs ++
          [
            run("1", 250, 400),
            run("0", 256, 400),
            run("0", 262, 400),
            run("2", 350, 400),
            run("9", 356, 400),
            run("/", 362, 400),
            run("0", 368, 400),
            run("6", 374, 400),
            run("/", 380, 400),
            run("2", 386, 400),
            run("0", 392, 400),
            run("1", 398, 400),
            run("5", 404, 400)
          ]

      assert [line] = Pdf.Reader.lines_from_runs(runs)
      assert length(line.tokens) == 3

      [activity, percent, date] = line.tokens
      assert activity.text == "Asalariado"
      assert percent.text == "100"
      assert date.text == "29/06/2015"

      # Column X positions are preserved
      assert activity.x == 70.0
      assert percent.x == 250.0
      assert date.x == 350.0
    end

    test "custom gap_factor overrides the default heuristic" do
      runs = [
        run("a", 50, 700, size: 10.0),
        # gap of 8pt → with factor 0.5 (5pt threshold) splits, with 1.0 (10pt) doesn't
        run("b", 58, 700, size: 10.0)
      ]

      assert [tight] = Pdf.Reader.lines_from_runs(runs, gap_factor: 1.0)
      assert length(tight.tokens) == 1

      assert [loose] = Pdf.Reader.lines_from_runs(runs, gap_factor: 0.5)
      assert length(loose.tokens) == 2
    end
  end

  describe "page boundaries" do
    test "runs on different pages produce lines with the correct :page" do
      runs = [
        run("page1", 50, 700, page: 1),
        run("page2", 50, 700, page: 2)
      ]

      assert [l1, l2] = Pdf.Reader.lines_from_runs(runs)
      assert l1.page == 1
      assert l1.text == "page1"
      assert l2.page == 2
      assert l2.text == "page2"
    end

    test "lines are ordered by page first, then top-to-bottom within page" do
      runs = [
        run("p2 top", 50, 700, page: 2),
        run("p1 bot", 50, 100, page: 1),
        run("p1 top", 50, 700, page: 1),
        run("p2 bot", 50, 100, page: 2)
      ]

      assert [a, b, c, d] = Pdf.Reader.lines_from_runs(runs)
      assert a.text == "p1 top"
      assert b.text == "p1 bot"
      assert c.text == "p2 top"
      assert d.text == "p2 bot"
    end
  end

  describe "edge cases" do
    test "empty runs list returns []" do
      assert Pdf.Reader.lines_from_runs([]) == []
    end

    test "runs with empty :text strings are skipped" do
      runs = [
        run("", 50, 700),
        run("a", 60, 700)
      ]

      assert [line] = Pdf.Reader.lines_from_runs(runs)
      assert line.text == "a"
    end
  end
end
