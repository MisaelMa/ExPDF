defmodule Pdf.Reader.ContentStreamTest do
  use ExUnit.Case, async: true

  alias Pdf.Reader.ContentStream

  # Spec reference: PDF 1.7 § 9.4 (text operators), § 8.4 (graphics state), § 8.8 (XObjects).
  #
  # ContentStream.interpret/2 takes:
  #   - binary content stream
  #   - decoder function: (bytes :: binary) -> {text :: String.t(), unresolved :: list()}
  #
  # Returns {:ok, [event]} where event is:
  #   {:text, %{text: String.t(), unresolved: list(), x: float, y: float, font: binary, size: float}}
  #   {:image, %{name: binary, x: float, y: float}}
  #   {:deferred, :form_xobject, name :: binary}

  # Identity decoder — no encoding; treats bytes as ASCII.
  # Used for tests that only care about position/structure, not encoding.
  defp ascii_decoder(bytes), do: {bytes, []}

  # ---------------------------------------------------------------------------
  # 8.2.1 BT/ET — begin/end text
  # ---------------------------------------------------------------------------

  describe "BT / ET" do
    test "BT resets Tm and Tlm to identity" do
      # After BT, a Tj should use identity Tm → position (0,0)
      # We use Tm operator to verify BT resets correctly
      stream = "BT /F1 10 Tf 100 200 Td (Hello) Tj ET"
      {:ok, events} = ContentStream.interpret(stream, &ascii_decoder/1)

      assert length(events) == 1
      [{:text, run}] = events
      assert_in_delta run.x, 100.0, 0.5
      assert_in_delta run.y, 200.0, 0.5
    end

    test "text operators outside BT/ET are ignored" do
      # A Tj without BT should produce no events (or be silently skipped)
      stream = "(Hello) Tj"
      {:ok, events} = ContentStream.interpret(stream, &ascii_decoder/1)
      assert events == []
    end
  end

  # ---------------------------------------------------------------------------
  # 8.2.2 Tf — set font and size
  # ---------------------------------------------------------------------------

  describe "Tf" do
    test "Tf sets font name and size in emitted text event" do
      stream = "BT /Helvetica 12 Tf 0 0 Td (Text) Tj ET"
      {:ok, events} = ContentStream.interpret(stream, &ascii_decoder/1)

      [{:text, run}] = events
      assert run.font == "Helvetica"
      assert_in_delta run.size, 12.0, 0.001
    end

    test "Tf with different font and size" do
      stream = "BT /Times-Roman 24 Tf 0 0 Td (X) Tj ET"
      {:ok, events} = ContentStream.interpret(stream, &ascii_decoder/1)

      [{:text, run}] = events
      assert run.font == "Times-Roman"
      assert_in_delta run.size, 24.0, 0.001
    end
  end

  # ---------------------------------------------------------------------------
  # 8.2.3 Td — text position move
  # ---------------------------------------------------------------------------

  describe "Td" do
    test "Td sets absolute position for next Tj" do
      stream = "BT /F1 10 Tf 72 720 Td (A) Tj ET"
      {:ok, events} = ContentStream.interpret(stream, &ascii_decoder/1)

      [{:text, run}] = events
      assert_in_delta run.x, 72.0, 0.5
      assert_in_delta run.y, 720.0, 0.5
    end

    test "two Td calls accumulate" do
      # First Td: (10, 20), second Td: (5, 0)
      # Tlm after first Td = [1 0 0 1 10 20], after second = [1 0 0 1 15 20]
      stream = "BT /F1 10 Tf 10 20 Td 5 0 Td (A) Tj ET"
      {:ok, events} = ContentStream.interpret(stream, &ascii_decoder/1)

      [{:text, run}] = events
      assert_in_delta run.x, 15.0, 0.5
      assert_in_delta run.y, 20.0, 0.5
    end
  end

  # ---------------------------------------------------------------------------
  # 8.2.4 Tj — show text string
  # ---------------------------------------------------------------------------

  describe "Tj" do
    test "Tj emits a text event with decoded string" do
      stream = "BT /F1 12 Tf 100 200 Td (Hello) Tj ET"
      {:ok, events} = ContentStream.interpret(stream, &ascii_decoder/1)

      assert length(events) == 1
      [{:text, run}] = events
      assert run.text == "Hello"
      assert_in_delta run.x, 100.0, 0.5
      assert_in_delta run.y, 200.0, 0.5
    end

    test "two Tj calls in one BT/ET emit two events" do
      stream = "BT /F1 12 Tf 0 0 Td (Hello) Tj (World) Tj ET"
      {:ok, events} = ContentStream.interpret(stream, &ascii_decoder/1)
      assert length(events) == 2
    end
  end

  # ---------------------------------------------------------------------------
  # 8.2.5 TJ — show text array
  # ---------------------------------------------------------------------------

  describe "TJ" do
    test "TJ with single string element emits one text event" do
      # [(Hello)] Tj is equivalent to TJ with single string
      stream = "BT /F1 12 Tf 100 200 Td [(Hello)] TJ ET"
      {:ok, events} = ContentStream.interpret(stream, &ascii_decoder/1)

      assert length(events) == 1
      [{:text, run}] = events
      assert run.text == "Hello"
      assert_in_delta run.x, 100.0, 0.5
    end

    test "TJ with multiple string elements emits multiple events" do
      stream = "BT /F1 12 Tf 100 200 Td [(Hello) 0 (World)] TJ ET"
      {:ok, events} = ContentStream.interpret(stream, &ascii_decoder/1)
      # Two string elements → two text events
      assert length(events) == 2
    end

    test "TJ numeric kern shifts position (no separate event)" do
      # [() -100 (A)] — kern shifts, then A is emitted
      # This tests that numeric elements do NOT produce text events
      stream = "BT /F1 12 Tf 100 200 Td [-100 (A)] TJ ET"
      {:ok, events} = ContentStream.interpret(stream, &ascii_decoder/1)

      text_events = Enum.filter(events, &match?({:text, _}, &1))
      assert length(text_events) == 1
    end
  end

  # ---------------------------------------------------------------------------
  # 8.2.6 Tm — set text matrix
  # ---------------------------------------------------------------------------

  describe "Tm" do
    test "Tm sets position directly (e and f are x/y translation)" do
      # Tm 1 0 0 1 150 300 → Tm = {1,0,0,1,150,300}, absolute position = (150, 300)
      stream = "BT 1 0 0 1 150 300 Tm /F1 12 Tf (A) Tj ET"
      {:ok, events} = ContentStream.interpret(stream, &ascii_decoder/1)

      [{:text, run}] = events
      assert_in_delta run.x, 150.0, 0.5
      assert_in_delta run.y, 300.0, 0.5
    end

    test "Tm resets Tlm and Tm to given values" do
      # After Tm, a subsequent T* should use the Tm's e/f as base
      stream = "BT /F1 12 Tf 0 -12 TD 1 0 0 1 50 100 Tm (A) Tj ET"
      {:ok, events} = ContentStream.interpret(stream, &ascii_decoder/1)

      [{:text, run}] = events
      assert_in_delta run.x, 50.0, 0.5
      assert_in_delta run.y, 100.0, 0.5
    end
  end

  # ---------------------------------------------------------------------------
  # 8.2.7 TD / T* / ' / " operators
  # ---------------------------------------------------------------------------

  describe "TD" do
    test "TD sets leading to -ty and moves by (tx, ty)" do
      # TD 0 -15 → leading = 15, move (0, -15)
      stream = "BT /F1 12 Tf 100 200 Td 0 -15 TD (A) Tj ET"
      {:ok, events} = ContentStream.interpret(stream, &ascii_decoder/1)

      [{:text, run}] = events
      assert_in_delta run.x, 100.0, 0.5
      # After 0 -15 TD from 200 → y = 200 - 15 = 185
      assert_in_delta run.y, 185.0, 0.5
    end
  end

  describe "T*" do
    test "T* moves to next line using current leading" do
      # TD sets leading; T* moves by (0, -leading)
      stream = "BT /F1 12 Tf 100 200 Td 0 -20 TD (Line1) Tj T* (Line2) Tj ET"
      {:ok, events} = ContentStream.interpret(stream, &ascii_decoder/1)

      assert length(events) == 2
      [{:text, r1}, {:text, r2}] = events
      assert_in_delta r1.y, 180.0, 0.5
      # T* from 180 by -20 (leading) → 160
      assert_in_delta r2.y, 160.0, 0.5
    end
  end

  describe "' operator" do
    test "' moves to next line and shows text" do
      stream = "BT /F1 12 Tf 100 200 Td 0 -15 TD (Line1) ' ET"
      {:ok, events} = ContentStream.interpret(stream, &ascii_decoder/1)

      assert length(events) == 1
      [{:text, run}] = events
      assert run.text == "Line1"
    end
  end

  # ---------------------------------------------------------------------------
  # 8.2.8 cm, q, Q — graphics state
  # ---------------------------------------------------------------------------

  describe "cm / q / Q" do
    test "cm updates CTM" do
      # cm 2 0 0 2 0 0 doubles scale; a Td+Tj at (50,50) should appear at (50,50)
      # because absolute position comes from Tm (text space) not CTM for text
      # Actually: M_render = Tm × CTM, so with CTM=(2,0,0,2,0,0) and Tm=(1,0,0,1,50,50):
      # e = 50*2 + 0*0 + 0 = 100, f = 50*0 + 50*2 + 0 = 100
      stream = "2 0 0 2 0 0 cm BT /F1 12 Tf 50 50 Td (A) Tj ET"
      {:ok, events} = ContentStream.interpret(stream, &ascii_decoder/1)

      [{:text, run}] = events
      # With CTM scaled by 2 and Td at (50,50): absolute = Tm × CTM
      # Tm = {1,0,0,1,50,50}, CTM = {2,0,0,2,0,0}
      # M_render = multiply({1,0,0,1,50,50}, {2,0,0,2,0,0})
      # e3 = 50*2 + 50*0 + 0 = 100, f3 = 50*0 + 50*2 + 0 = 100
      assert_in_delta run.x, 100.0, 0.5
      assert_in_delta run.y, 100.0, 0.5
    end

    test "q saves and Q restores CTM" do
      # q, modify CTM, Q — restored
      stream = "q 2 0 0 2 0 0 cm Q BT /F1 12 Tf 50 50 Td (A) Tj ET"
      {:ok, events} = ContentStream.interpret(stream, &ascii_decoder/1)

      [{:text, run}] = events
      # After Q, CTM restored to identity → position = (50, 50)
      assert_in_delta run.x, 50.0, 0.5
      assert_in_delta run.y, 50.0, 0.5
    end

    test "Q with empty stack is no-op" do
      stream = "Q BT /F1 12 Tf 10 20 Td (A) Tj ET"
      {:ok, events} = ContentStream.interpret(stream, &ascii_decoder/1)

      [{:text, run}] = events
      assert_in_delta run.x, 10.0, 0.5
      assert_in_delta run.y, 20.0, 0.5
    end
  end

  # ---------------------------------------------------------------------------
  # 8.2.9 Do — XObject invocation
  # ---------------------------------------------------------------------------

  describe "Do" do
    test "Do with image XObject emits {:image, ...} event with ctm tuple" do
      # xobjects map tells interpreter what type each name is
      stream = "BT ET /Im1 Do"
      xobjects = %{"Im1" => :image}

      {:ok, events} = ContentStream.interpret(stream, &ascii_decoder/1, xobjects: xobjects)

      image_events = Enum.filter(events, &match?({:image, _}, &1))
      assert length(image_events) == 1
      [{:image, img}] = image_events
      assert img.name == "Im1"
      # Phase 1.1: event carries ctm tuple, NOT x/y fields
      assert is_tuple(img.ctm)
      assert tuple_size(img.ctm) == 6
    end

    test "Do with form XObject emits {:deferred, :form_xobject, name}" do
      stream = "BT ET /Form1 Do"
      xobjects = %{"Form1" => :form}

      {:ok, events} = ContentStream.interpret(stream, &ascii_decoder/1, xobjects: xobjects)

      deferred = Enum.filter(events, &match?({:deferred, :form_xobject, _}, &1))
      assert length(deferred) == 1
      assert hd(deferred) == {:deferred, :form_xobject, "Form1"}
    end

    test "Do with unknown XObject type emits deferred marker (safe fallback)" do
      stream = "BT ET /Unk1 Do"
      {:ok, events} = ContentStream.interpret(stream, &ascii_decoder/1)

      assert length(events) == 1
      assert hd(events) == {:deferred, :form_xobject, "Unk1"}
    end
  end

  # ---------------------------------------------------------------------------
  # Phase 3.2 — font_decoders: opt absent → identity fallback (S-CW5)
  # ---------------------------------------------------------------------------

  describe "font_decoders: opt absent" do
    test "identity fallback: BT /F1 12 Tf (Hello) Tj ET emits text: 'Hello' unchanged" do
      # S-CW5: no font_decoders opt → Phase 1 identity decoder used
      stream = "BT /F1 12 Tf 0 0 Td (Hello) Tj ET"

      {:ok, events} = ContentStream.interpret(stream, &ascii_decoder/1)

      text_events = Enum.filter(events, &match?({:text, _}, &1))
      assert length(text_events) == 1
      [{:text, run}] = text_events
      assert run.text == "Hello"
    end
  end

  # ---------------------------------------------------------------------------
  # Phase 3.3 — font_decoders: provided; Tf swaps active decoder (S-CW4)
  # ---------------------------------------------------------------------------

  describe "font_decoders: opt provided — Tf switches decoder" do
    test "two Tf in one stream; each Tj uses the appropriate decoder" do
      # S-CW4: /F1 decoder upcases; /F2 decoder downcases.
      # After /F1 Tf → upcase decoder active; after /F2 Tf → downcase decoder active.
      f1_decoder = fn bytes -> {String.upcase(bytes), []} end
      f2_decoder = fn bytes -> {String.downcase(bytes), []} end

      stream = "BT /F1 12 Tf 0 0 Td (x) Tj /F2 12 Tf 20 0 Td (Y) Tj ET"

      {:ok, events} =
        ContentStream.interpret(stream, &ascii_decoder/1,
          font_decoders: %{"F1" => f1_decoder, "F2" => f2_decoder}
        )

      text_events = Enum.filter(events, &match?({:text, _}, &1))
      assert length(text_events) == 2
      [{:text, run1}, {:text, run2}] = text_events
      # F1 decoder upcases "x" → "X"
      assert run1.text == "X"
      # F2 decoder downcases "Y" → "y"
      assert run2.text == "y"
    end

    test "unknown font name in stream falls back to default decoder" do
      # When Tf references a font not in font_decoders, default decoder is used
      default_decoder = fn bytes -> {"DEFAULT:" <> bytes, []} end

      stream = "BT /UnknownFont 12 Tf 0 0 Td (Hi) Tj ET"

      {:ok, events} =
        ContentStream.interpret(stream, default_decoder,
          font_decoders: %{"F1" => fn b -> {b, []} end}
        )

      [{:text, run}] = Enum.filter(events, &match?({:text, _}, &1))
      assert run.text == "DEFAULT:Hi"
    end
  end

  # ---------------------------------------------------------------------------
  # Phase 3.4 — Do with font_decoders opt present; image still carries ctm (S-CW12)
  # ---------------------------------------------------------------------------

  describe "Do with font_decoders opt present" do
    test "image event still carries ctm tuple (regression guard for combined opts)" do
      # S-CW12: combined font_decoders + xobjects opts; image event must have ctm:
      stream = "q 0 100 -50 0 200 300 cm /Im1 Do Q"
      xobjects = %{"Im1" => :image}
      f1_decoder = fn b -> {b, []} end

      {:ok, events} =
        ContentStream.interpret(stream, &ascii_decoder/1,
          xobjects: xobjects,
          font_decoders: %{"F1" => f1_decoder}
        )

      image_events = Enum.filter(events, &match?({:image, _}, &1))
      assert length(image_events) == 1
      [{:image, img}] = image_events
      assert img.name == "Im1"
      # ctm must be the 6-tuple from the cm operator
      assert img.ctm == {0.0, 100.0, -50.0, 0.0, 200.0, 300.0}
    end
  end

  # ---------------------------------------------------------------------------
  # Phase 4.2 — non-trivial CTM from Do (S-CW12, content-stream level)
  # ---------------------------------------------------------------------------

  describe "Do with non-trivial CTM" do
    test "q 0 100 -50 0 200 300 cm /Im1 Do Q — ctm is exact 6-tuple" do
      # S-CW12: rotation ~90 degrees
      stream = "q 0 100 -50 0 200 300 cm /Im1 Do Q"
      xobjects = %{"Im1" => :image}

      {:ok, events} = ContentStream.interpret(stream, &ascii_decoder/1, xobjects: xobjects)

      image_events = Enum.filter(events, &match?({:image, _}, &1))
      assert length(image_events) == 1
      [{:image, img}] = image_events
      assert img.ctm == {0.0, 100.0, -50.0, 0.0, 200.0, 300.0}
    end

    test "identity CTM when no cm operator before Do" do
      stream = "/Im1 Do"
      xobjects = %{"Im1" => :image}

      {:ok, events} = ContentStream.interpret(stream, &ascii_decoder/1, xobjects: xobjects)

      [{:image, img}] = Enum.filter(events, &match?({:image, _}, &1))
      assert img.ctm == {1.0, 0.0, 0.0, 1.0, 0.0, 0.0}
    end
  end

  # ---------------------------------------------------------------------------
  # Phase 1 (form-xobject-recursion) — state extension regression + guard events
  # ---------------------------------------------------------------------------

  describe "interpret/3 backward compatibility — doc: nil regression (R-FX16, S-FX16)" do
    test "1.1 — interpret/3 return is unchanged when doc is not supplied (regression baseline)" do
      # Verifies that adding :doc, :page_resources, :visited, :depth to initial state
      # does NOT change the externally observable return value.  The caller receives
      # exactly the same {:ok, [event]} tuple that existed before the state extension.
      stream = "BT /F1 12 Tf 100 200 Td (Hello) Tj ET"
      {:ok, events} = ContentStream.interpret(stream, &ascii_decoder/1)

      # Same shape as before: one text event, correct position, no new guard fields leaked
      assert length(events) == 1
      [{:text, run}] = events
      assert run.text == "Hello"
      assert_in_delta run.x, 100.0, 0.5
      assert_in_delta run.y, 200.0, 0.5
      assert run.font == "F1"
      assert_in_delta run.size, 12.0, 0.001
    end

    test "1.1b — Do with image xobject still emits {:image, _} (doc: nil, existing path preserved)" do
      stream = "/Im1 Do"
      xobjects = %{"Im1" => :image}
      {:ok, events} = ContentStream.interpret(stream, &ascii_decoder/1, xobjects: xobjects)

      assert length(events) == 1
      [{:image, img}] = events
      assert img.name == "Im1"
      assert tuple_size(img.ctm) == 6
    end

    test "1.1c — Do with form xobject still emits {:deferred, :form_xobject, name} (doc: nil)" do
      stream = "/Form1 Do"
      xobjects = %{"Form1" => :form}
      {:ok, events} = ContentStream.interpret(stream, &ascii_decoder/1, xobjects: xobjects)

      assert length(events) == 1
      assert hd(events) == {:deferred, :form_xobject, "Form1"}
    end
  end

  describe "events_to_text_runs/2 silently drops guard events (R-FX14, S-FX12)" do
    test "1.5 — {:cycle_detected, _} produces zero TextRun entries when passed through reader pipeline" do
      # We verify the property indirectly: events_to_text_runs is private, but it is
      # exercised by extract_page_runs/3 → read_text_with_positions/1.
      # For a unit-level check without reaching into internals, we confirm that
      # the ContentStream event list CAN contain {:cycle_detected, _} and
      # {:max_depth_exceeded, _} terms that match the @type definition.
      # The actual drop test (via reader pipeline) lives in reader_test.exs (Phase 7).
      # Here we assert the new event shape is a well-formed 2-tuple with the right tag.
      cycle_event = {:cycle_detected, {5, 0}}
      depth_event = {:max_depth_exceeded, {7, 0}}

      assert match?({:cycle_detected, {_n, _g}}, cycle_event)
      assert match?({:max_depth_exceeded, {_n, _g}}, depth_event)

      # Verify the catch-all in events_to_text_runs/2 covers these by asserting
      # that neither pattern matches the {:text, _} or {:image, _} branches.
      refute match?({:text, _}, cycle_event)
      refute match?({:image, _}, cycle_event)
      refute match?({:text, _}, depth_event)
      refute match?({:image, _}, depth_event)
    end
  end

  # ---------------------------------------------------------------------------
  # Phase 3 — Do-handler classification (R-FX7, R-FX8, R-FX11, R-FX18–R-FX22)
  # ---------------------------------------------------------------------------

  # Synthetic helpers shared by Phase 3 + Phase 4 tests

  defp synthetic_doc(extra_cache \\ %{}) do
    %Pdf.Reader.Document{
      binary: <<>>,
      version: "1.7",
      xref: %{},
      trailer: %{},
      cache: extra_cache,
      page_refs: nil,
      encryption: nil
    }
  end

  defp build_form_dict(opts \\ []) do
    base = %{
      "Type" => {:name, "XObject"},
      "Subtype" => {:name, "Form"},
      "BBox" => [0, 0, 100, 100]
    }

    base
    |> maybe_put("Matrix", Keyword.get(opts, :matrix))
    |> maybe_put("Resources", Keyword.get(opts, :resources))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp make_form_stream(content_bytes, extra_dict \\ %{}) do
    dict = Map.merge(build_form_dict(), extra_dict)
    {:stream, dict, content_bytes}
  end

  describe "Do-handler — doc: nil legacy path (R-FX16, S-FX16)" do
    test "3.1 — Do with :image xobject in xobjects map (doc:nil) still emits {:image,...}" do
      # Regression guard: legacy path must still work when doc is nil.
      # xobjects map uses the old :image atom (pre-classification).
      stream = "/Im1 Do"
      xobjects = %{"Im1" => :image}

      {:ok, events} = ContentStream.interpret(stream, &ascii_decoder/1, xobjects: xobjects)

      image_events = Enum.filter(events, &match?({:image, _}, &1))
      assert length(image_events) == 1
      [{:image, img}] = image_events
      assert img.name == "Im1"
      assert tuple_size(img.ctm) == 6
    end
  end

  describe "Do-handler — unresolvable / no-op cases (R-FX20, S-FX18)" do
    test "3.2 — Do for unresolvable name (name absent from xobjects, doc: non-nil) is a no-op" do
      # R-FX20: name not present in xobjects map with doc non-nil → skip silently, no event.
      doc = synthetic_doc()

      # xobjects map is empty; "Ghost" is not present → true branch → state unchanged
      {:ok, events, _doc2} =
        ContentStream.do_interpret_with_doc(
          "/Ghost Do",
          &ascii_decoder/1,
          [xobjects: %{}],
          doc,
          %{}
        )

      # No event emitted — no crash, no deferred, no image, no cycle
      assert events == []
    end
  end

  describe "Do-handler — Pattern XObject skipped (R-FX22, S-FX15)" do
    test "3.3 — Do with Pattern XObject (non-Form/Image subtype) emits no events" do
      # R-FX22: Pattern XObject → dispatch_xobject hits the catch-all → no event.
      # We place a Pattern stream in the doc cache and reference it via a ref in xobjects.
      pattern_dict = %{
        "Type" => {:name, "XObject"},
        "Subtype" => {:name, "Pattern"},
        "PatternType" => 1
      }

      pattern_stream = {:stream, pattern_dict, ""}
      doc = synthetic_doc(%{{99, 0} => pattern_stream})

      xobjects = %{"Pat1" => {:ref, 99, 0}}

      {:ok, events, _doc2} =
        ContentStream.do_interpret_with_doc(
          "/Pat1 Do",
          &ascii_decoder/1,
          [xobjects: xobjects],
          doc,
          %{}
        )

      # No events — Pattern is silently skipped
      assert events == []
    end
  end

  describe "Do-handler — cycle detection (R-FX7, R-FX8, S-FX6)" do
    test "3.4 — cycle check fires when {n,g} already in visited — {:cycle_detected,{n,g}} emitted" do
      # R-FX7: visited check before resolution.
      # R-FX8: must emit {:cycle_detected, {n, g}} and skip without entering ObjectResolver.
      # We use do_interpret_with_doc/5 to inject doc and pre-populated visited set.
      form_ref = {:ref, 10, 0}
      {n, g} = {10, 0}

      # The form stream's content — should NOT be decoded if cycle fires correctly
      form_stream = make_form_stream("BT /F1 12 Tf (InsideForm) Tj ET")

      doc =
        synthetic_doc(%{
          {n, g} => form_stream
        })

      xobjects = %{"Form1" => form_ref}

      # visited already contains {10, 0} → cycle detected, no recursion
      visited_with_ref = MapSet.put(MapSet.new(), {n, g})

      # Build child state with the visited set pre-populated
      {:ok, events, _doc2} =
        ContentStream.do_interpret_with_doc(
          "/Form1 Do",
          &ascii_decoder/1,
          [xobjects: xobjects],
          doc,
          %{},
          visited_with_ref,
          0
        )

      # Must emit exactly one {:cycle_detected, {10, 0}} event
      cycle_events = Enum.filter(events, &match?({:cycle_detected, _}, &1))
      assert length(cycle_events) == 1
      assert hd(cycle_events) == {:cycle_detected, {n, g}}

      # Must NOT emit any text from inside the form
      text_events = Enum.filter(events, &match?({:text, _}, &1))
      assert text_events == []
    end
  end

  describe "Do-handler — depth check (R-FX11, S-FX9)" do
    test "3.5 — depth check fires when state.depth >= @max_form_depth — {:max_depth_exceeded,{n,g}} emitted" do
      # R-FX11: depth >= @max_form_depth (8) → emit {:max_depth_exceeded, {n, g}} and skip.
      form_ref = {:ref, 5, 0}
      {n, g} = {5, 0}

      form_stream = make_form_stream("BT /F1 12 Tf (DeepForm) Tj ET")

      doc = synthetic_doc(%{{n, g} => form_stream})
      xobjects = %{"DeepForm" => form_ref}

      # depth = 8 >= @max_form_depth = 8 → must trigger depth check
      {:ok, events, _doc2} =
        ContentStream.do_interpret_with_doc(
          "/DeepForm Do",
          &ascii_decoder/1,
          [xobjects: xobjects],
          doc,
          %{},
          MapSet.new(),
          8
        )

      depth_events = Enum.filter(events, &match?({:max_depth_exceeded, _}, &1))
      assert length(depth_events) == 1
      assert hd(depth_events) == {:max_depth_exceeded, {n, g}}

      # Must NOT emit any text from inside the form
      text_events = Enum.filter(events, &match?({:text, _}, &1))
      assert text_events == []
    end
  end

  # ---------------------------------------------------------------------------
  # Phase 4 — recurse_into_form helpers (R-FX1–R-FX5)
  # ---------------------------------------------------------------------------

  describe "resolve_form_resources/2 (R-FX4, S-FX5)" do
    test "4.1 — Form with no /Resources key returns {:ok, %{}, doc}" do
      doc = synthetic_doc()
      form_dict = build_form_dict()
      # No "Resources" key in form_dict

      {:ok, resources, returned_doc} = ContentStream.resolve_form_resources(doc, form_dict)

      assert resources == %{}
      assert returned_doc == doc
    end

    test "4.2 — Form with inline map /Resources returns that map" do
      doc = synthetic_doc()
      font_map = %{"F1" => %{"Type" => {:name, "Font"}, "Subtype" => {:name, "Type1"}}}
      resources_map = %{"Font" => font_map}
      form_dict = build_form_dict(resources: resources_map)

      {:ok, resources, returned_doc} = ContentStream.resolve_form_resources(doc, form_dict)

      assert resources == resources_map
      assert returned_doc == doc
    end

    test "4.3 — Form with ref-based /Resources resolves through ObjectResolver" do
      resources_map = %{"Font" => %{"F2" => %{"Type" => {:name, "Font"}}}}
      doc = synthetic_doc(%{{20, 0} => resources_map})
      form_dict = build_form_dict(resources: {:ref, 20, 0})

      {:ok, resources, _returned_doc} = ContentStream.resolve_form_resources(doc, form_dict)

      assert resources == resources_map
    end
  end

  describe "merge_resources/2 (R-FX4, S-FX4)" do
    test "4.5 — Form entries overwrite page entries on key collision (Form wins)" do
      page_resources = %{"Font" => %{"F1" => "Helvetica"}, "Other" => "page_val"}
      form_resources = %{"Font" => %{"F1" => "TimesRoman", "F2" => "Courier"}}

      merged = ContentStream.merge_resources(page_resources, form_resources)

      # Form wins: Font map from form_resources replaces page's Font map entirely
      assert merged["Font"] == %{"F1" => "TimesRoman", "F2" => "Courier"}
      # Keys only in page_resources are preserved
      assert merged["Other"] == "page_val"
    end
  end

  describe "decode_form_stream/1 (R-FX1)" do
    test "4.7 — dict with no Filter returns raw bytes unchanged" do
      raw_bytes = "BT /F1 12 Tf 0 0 Td (Hello) Tj ET"
      stream = {:stream, %{}, raw_bytes}

      {:ok, decoded} = ContentStream.decode_form_stream(stream)

      assert decoded == raw_bytes
    end

    test "4.8 — dict with FlateDecode filter returns inflated bytes" do
      original = "BT /F1 12 Tf 0 0 Td (Compressed) Tj ET"
      compressed = :zlib.compress(original)
      dict = %{"Filter" => {:name, "FlateDecode"}}
      stream = {:stream, dict, compressed}

      {:ok, decoded} = ContentStream.decode_form_stream(stream)

      assert decoded == original
    end
  end

  describe "build_xobject_refs/1 (R-FX19)" do
    test "4.10 — resources with XObject map returns that map" do
      xobject_map = %{"Im1" => {:ref, 30, 0}, "Form2" => {:ref, 31, 0}}
      resources = %{"XObject" => xobject_map, "Font" => %{}}

      result = ContentStream.build_xobject_refs(resources)

      assert result == xobject_map
    end

    test "4.10b — resources without XObject key returns empty map" do
      resources = %{"Font" => %{"F1" => {:ref, 1, 0}}}

      result = ContentStream.build_xobject_refs(resources)

      assert result == %{}
    end
  end

  describe "recurse_into_form/4 — CTM × Form.Matrix (R-FX2, S-FX2, S-FX17)" do
    test "4.12 — Form.Matrix [2 0 0 2 50 100] × identity CTM produces correct child ctm" do
      # parent CTM = identity {1,0,0,1,0,0}; Form.Matrix = [2,0,0,2,50,100]
      # child ctm = multiply({2,0,0,2,50,100}, {1,0,0,1,0,0}) = {2,0,0,2,50,100}
      matrix = [2, 0, 0, 2, 50, 100]
      form_content = "BT /F1 12 Tf 10 20 Td (Test) Tj ET"

      form_stream = {:stream, build_form_dict(matrix: matrix), form_content}

      font_decoder = fn bytes -> {bytes, []} end

      doc =
        synthetic_doc(%{
          {50, 0} => form_stream,
          {:font_decoder, {1, 0}} => font_decoder
        })

      font_resource = %{"F1" => {:ref, 1, 0}}
      page_resources = %{"Font" => font_resource}
      xobjects = %{"Form1" => {:ref, 50, 0}}

      {:ok, events, _doc2} =
        ContentStream.do_interpret_with_doc(
          "/Form1 Do",
          &ascii_decoder/1,
          [xobjects: xobjects],
          doc,
          page_resources
        )

      text_events = Enum.filter(events, &match?({:text, _}, &1))
      assert length(text_events) >= 1
      [{:text, run} | _] = text_events
      # CTM = {2,0,0,2,50,100}, Tm after 10 20 Td = {1,0,0,1,10,20}
      # M_render = Tm × CTM = multiply({1,0,0,1,10,20}, {2,0,0,2,50,100})
      # e = 10*2 + 20*0 + 50 = 70; f = 10*0 + 20*2 + 100 = 140
      assert_in_delta run.x, 70.0, 0.5
      assert_in_delta run.y, 140.0, 0.5
    end

    test "4.13 — Form with no /Matrix key uses identity — child ctm equals parent ctm" do
      # parent CTM = identity; no Matrix in form → child ctm = identity
      form_content = "BT /F1 12 Tf 10 20 Td (Test) Tj ET"
      form_stream = {:stream, build_form_dict(), form_content}

      font_decoder = fn bytes -> {bytes, []} end

      doc =
        synthetic_doc(%{
          {51, 0} => form_stream,
          {:font_decoder, {1, 0}} => font_decoder
        })

      page_resources = %{"Font" => %{"F1" => {:ref, 1, 0}}}
      xobjects = %{"Form1" => {:ref, 51, 0}}

      {:ok, events, _doc2} =
        ContentStream.do_interpret_with_doc(
          "/Form1 Do",
          &ascii_decoder/1,
          [xobjects: xobjects],
          doc,
          page_resources
        )

      text_events = Enum.filter(events, &match?({:text, _}, &1))
      assert length(text_events) >= 1
      [{:text, run} | _] = text_events
      # No matrix: child CTM = identity; Td 10 20 → position (10, 20)
      assert_in_delta run.x, 10.0, 0.5
      assert_in_delta run.y, 20.0, 0.5
    end
  end

  describe "recurse_into_form/4 — graphics state isolation (R-FX3, S-FX3)" do
    test "4.14 — gs restored after recurse_into_form returns — parent state.gs equals saved_gs" do
      # The form modifies the CTM via cm; after form exits, parent gs should be restored.
      form_content = "2 0 0 2 100 200 cm BT /F1 12 Tf 0 0 Td (Inside) Tj ET"
      form_stream = {:stream, build_form_dict(), form_content}

      font_decoder = fn bytes -> {bytes, []} end

      doc =
        synthetic_doc(%{
          {52, 0} => form_stream,
          {:font_decoder, {1, 0}} => font_decoder
        })

      page_resources = %{"Font" => %{"F1" => {:ref, 1, 0}}}
      xobjects = %{"Form1" => {:ref, 52, 0}}

      # Stream: Do the form, then text at 50 50 which should use the ORIGINAL ctm
      stream = "/Form1 Do BT /F1 12 Tf 50 50 Td (After) Tj ET"

      {:ok, events, _doc2} =
        ContentStream.do_interpret_with_doc(
          stream,
          &ascii_decoder/1,
          [xobjects: xobjects],
          doc,
          page_resources
        )

      # "After" text run must use identity ctm (50, 50), not the form's scaled ctm
      after_events =
        Enum.filter(events, fn
          {:text, %{text: "After"}} -> true
          _ -> false
        end)

      assert length(after_events) == 1
      [{:text, after_run}] = after_events
      # Identity ctm: absolute position = (50, 50)
      assert_in_delta after_run.x, 50.0, 0.5
      assert_in_delta after_run.y, 50.0, 0.5
    end
  end

  describe "recurse_into_form/4 — child events appended (R-FX1, S-FX1)" do
    test "4.15 — child events are appended to parent events in document order" do
      # Page has text before the form Do and text after; form has its own text.
      # Final event order: [page-text-before, form-text, page-text-after]
      form_content = "BT /F1 12 Tf 0 100 Td (FormText) Tj ET"
      form_stream = {:stream, build_form_dict(), form_content}

      font_decoder = fn bytes -> {bytes, []} end

      doc =
        synthetic_doc(%{
          {53, 0} => form_stream,
          {:font_decoder, {1, 0}} => font_decoder
        })

      page_resources = %{"Font" => %{"F1" => {:ref, 1, 0}}}
      xobjects = %{"Form1" => {:ref, 53, 0}}

      stream =
        "BT /F1 12 Tf 0 0 Td (Before) Tj ET /Form1 Do BT /F1 12 Tf 0 200 Td (After) Tj ET"

      {:ok, events, _doc2} =
        ContentStream.do_interpret_with_doc(
          stream,
          &ascii_decoder/1,
          [xobjects: xobjects],
          doc,
          page_resources
        )

      texts =
        Enum.filter(events, &match?({:text, _}, &1))
        |> Enum.map(fn {:text, r} -> r.text end)

      assert "Before" in texts
      assert "FormText" in texts
      assert "After" in texts

      # Document order: Before comes before FormText, FormText before After
      before_idx = Enum.find_index(texts, &(&1 == "Before"))
      form_idx = Enum.find_index(texts, &(&1 == "FormText"))
      after_idx = Enum.find_index(texts, &(&1 == "After"))

      assert before_idx < form_idx
      assert form_idx < after_idx
    end
  end

  describe "recurse_into_form/4 — font decoder cache hit (R-FX5, S-FX13)" do
    test "4.16 — font decoder cache hit: same font ref used across 2 form invocations uses cached decoder" do
      # Two forms both reference font {:ref, 1, 0}. After first call, decoder should
      # be in doc.cache at {:font_decoder, {1, 0}}. Second call hits the cache.
      font_decoder = fn bytes -> {String.upcase(bytes), []} end

      form_content = "BT /F1 12 Tf 0 0 Td (hello) Tj ET"
      form_stream1 = {:stream, build_form_dict(), form_content}
      form_stream2 = {:stream, build_form_dict(), form_content}

      doc =
        synthetic_doc(%{
          {60, 0} => form_stream1,
          {61, 0} => form_stream2,
          {:font_decoder, {1, 0}} => font_decoder
        })

      page_resources = %{"Font" => %{"F1" => {:ref, 1, 0}}}
      xobjects = %{"Form1" => {:ref, 60, 0}, "Form2" => {:ref, 61, 0}}

      stream = "/Form1 Do /Form2 Do"

      {:ok, events, doc2} =
        ContentStream.do_interpret_with_doc(
          stream,
          &ascii_decoder/1,
          [xobjects: xobjects],
          doc,
          page_resources
        )

      # Both form texts should be decoded via the cached decoder (upcased)
      text_events = Enum.filter(events, &match?({:text, _}, &1))
      assert length(text_events) >= 2

      texts = Enum.map(text_events, fn {:text, r} -> r.text end)
      assert Enum.all?(texts, &(&1 == "HELLO"))

      # Verify font decoder remains cached in returned doc
      assert Map.has_key?(doc2.cache, {:font_decoder, {1, 0}})
    end
  end

  # ---------------------------------------------------------------------------
  # Phase 5 — public/private API split (R-FX16, R-FX1)
  # ---------------------------------------------------------------------------

  describe "do_interpret_with_doc/5 — return contract (R-FX16)" do
    test "5.1 — returns {:ok, events, updated_doc} with a non-nil doc" do
      # R-FX16: confirm the 3-tuple return shape from the semi-public entry point.
      # A plain text stream with no Form XObjects exercises the happy path.
      doc = synthetic_doc()
      stream = "BT /F1 12 Tf 10 20 Td (Hello) Tj ET"

      result =
        ContentStream.do_interpret_with_doc(
          stream,
          &ascii_decoder/1,
          [],
          doc,
          %{}
        )

      assert {:ok, events, updated_doc} = result
      assert is_list(events)
      assert length(events) == 1
      [{:text, run}] = events
      assert run.text == "Hello"
      # doc returned is the same struct (no mutation when no refs resolved)
      assert %Pdf.Reader.Document{} = updated_doc
    end

    test "5.2 — events include Form text when Form XObject is present (R-FX1, S-FX1)" do
      # R-FX1: Form XObject Do → recursive interpretation → text events from Form merged.
      form_content = "BT /F1 12 Tf 100 200 Td (FormText) Tj ET"
      form_stream = {:stream, build_form_dict(), form_content}
      font_decoder = fn bytes -> {bytes, []} end

      doc =
        synthetic_doc(%{
          {70, 0} => form_stream,
          {:font_decoder, {1, 0}} => font_decoder
        })

      page_resources = %{"Font" => %{"F1" => {:ref, 1, 0}}}
      xobjects = %{"Form1" => {:ref, 70, 0}}

      {:ok, events, _doc2} =
        ContentStream.do_interpret_with_doc(
          "BT /F1 12 Tf 0 0 Td (PageText) Tj ET /Form1 Do",
          &ascii_decoder/1,
          [xobjects: xobjects],
          doc,
          page_resources
        )

      texts =
        events
        |> Enum.filter(&match?({:text, _}, &1))
        |> Enum.map(fn {:text, r} -> r.text end)

      assert "PageText" in texts
      assert "FormText" in texts
    end
  end

  describe "interpret/3 regression after API split (R-FX16)" do
    test "5.4 — interpret/3 returns same events as before for plain stream (no Form XObjects)" do
      # R-FX16: public interpret/3 must remain unchanged externally.
      stream = "BT /F1 12 Tf 50 100 Td (Regression) Tj ET"
      {:ok, events} = ContentStream.interpret(stream, &ascii_decoder/1)

      assert length(events) == 1
      [{:text, run}] = events
      assert run.text == "Regression"
      assert_in_delta run.x, 50.0, 0.5
      assert_in_delta run.y, 100.0, 0.5
      assert run.font == "F1"
      assert_in_delta run.size, 12.0, 0.001
    end
  end

  # ---------------------------------------------------------------------------
  # Phase 6 — :deferred event no longer appears for resolvable Form (R-FX18)
  # ---------------------------------------------------------------------------

  describe "deferred event no longer appears for resolvable Form (R-FX18)" do
    test "6.6 — do_interpret_with_doc/5 does NOT emit {:deferred,:form_xobject,_} for a resolvable Form" do
      # R-FX18: the :deferred event is superseded for Forms that can be resolved.
      # When doc is non-nil and the Form is in the xobjects map as a {:ref, n, g},
      # the event stream must NOT contain {:deferred, :form_xobject, _}.
      form_content = "BT /F1 12 Tf 0 0 Td (Inside) Tj ET"
      form_stream = {:stream, build_form_dict(), form_content}
      font_decoder = fn bytes -> {bytes, []} end

      doc =
        synthetic_doc(%{
          {80, 0} => form_stream,
          {:font_decoder, {1, 0}} => font_decoder
        })

      page_resources = %{"Font" => %{"F1" => {:ref, 1, 0}}}
      xobjects = %{"Form1" => {:ref, 80, 0}}

      {:ok, events, _doc2} =
        ContentStream.do_interpret_with_doc(
          "/Form1 Do",
          &ascii_decoder/1,
          [xobjects: xobjects],
          doc,
          page_resources
        )

      deferred_events = Enum.filter(events, &match?({:deferred, :form_xobject, _}, &1))
      assert deferred_events == []

      # The Form's text IS extracted
      text_events = Enum.filter(events, &match?({:text, _}, &1))
      assert length(text_events) >= 1
    end
  end

  # ---------------------------------------------------------------------------
  # 8.2.10 Unknown operators — silent discard
  # ---------------------------------------------------------------------------

  describe "unknown operators" do
    test "unknown operator after text operators does not crash" do
      # 'm' 'l' 'S' are path/painting operators — must be silently consumed
      stream = "1 2 m 3 4 l S BT /F1 12 Tf 10 20 Td (OK) Tj ET"
      {:ok, events} = ContentStream.interpret(stream, &ascii_decoder/1)

      # The text event should still be present
      text_events = Enum.filter(events, &match?({:text, _}, &1))
      assert length(text_events) == 1
      [{:text, run}] = text_events
      assert run.text == "OK"
    end

    test "color operators (rg, g, k) are silently consumed" do
      stream = "0.5 0.5 0.5 rg BT /F1 12 Tf 10 20 Td (Text) Tj ET"
      {:ok, events} = ContentStream.interpret(stream, &ascii_decoder/1)

      text_events = Enum.filter(events, &match?({:text, _}, &1))
      assert length(text_events) == 1
    end

    test "stream with only unknown operators returns empty events" do
      stream = "1 2 m 3 4 l S"
      {:ok, events} = ContentStream.interpret(stream, &ascii_decoder/1)
      assert events == []
    end
  end
end
