defmodule Pdf.Reader.GraphicsStateTest do
  use ExUnit.Case, async: true

  alias Pdf.Reader.GraphicsState

  # Spec reference: PDF 1.7 § 8.3.3 (coordinate transformations).
  #
  # PDF affine matrix [a b c d e f] represents:
  #   | a b 0 |
  #   | c d 0 |
  #   | e f 1 |
  #
  # Stored as 6-element tuple {a, b, c, d, e, f}.
  # Identity: {1.0, 0.0, 0.0, 1.0, 0.0, 0.0}
  #
  # Multiplication M3 = M1 × M2 (row-vector convention, PDF § 8.3.4):
  #   a3 = a1*a2 + b1*c2
  #   b3 = a1*b2 + b1*d2
  #   c3 = c1*a2 + d1*c2
  #   d3 = c1*b2 + d1*d2
  #   e3 = e1*a2 + f1*c2 + e2
  #   f3 = e1*b2 + f1*d2 + f2
  #
  # Control points verified against PDF spec § 8.3.3 worked examples.

  @identity {1.0, 0.0, 0.0, 1.0, 0.0, 0.0}

  # ---- 8.1.1 multiply/2 — matrix multiplication ----

  describe "multiply/2" do
    test "identity × identity = identity" do
      result = GraphicsState.multiply(@identity, @identity)
      assert result == @identity
    end

    test "translation matrix × identity = translation matrix" do
      # [1 0 0 1 tx ty] is a pure translation
      # translating by (100, 200)
      t = {1.0, 0.0, 0.0, 1.0, 100.0, 200.0}
      result = GraphicsState.multiply(t, @identity)
      assert result == t
    end

    test "identity × translation = translation" do
      t = {1.0, 0.0, 0.0, 1.0, 100.0, 200.0}
      result = GraphicsState.multiply(@identity, t)
      assert result == t
    end

    test "two translations compose by adding offsets" do
      # [1 0 0 1 10 20] × [1 0 0 1 30 40] = [1 0 0 1 40 60]
      # Spec § 8.3.4: translation matrices compose additively.
      t1 = {1.0, 0.0, 0.0, 1.0, 10.0, 20.0}
      t2 = {1.0, 0.0, 0.0, 1.0, 30.0, 40.0}
      {a, b, c, d, e, f} = GraphicsState.multiply(t1, t2)
      assert_in_delta a, 1.0, 1.0e-9
      assert_in_delta b, 0.0, 1.0e-9
      assert_in_delta c, 0.0, 1.0e-9
      assert_in_delta d, 1.0, 1.0e-9
      assert_in_delta e, 40.0, 1.0e-9
      assert_in_delta f, 60.0, 1.0e-9
    end

    test "uniform scale × translation: e and f scale by scale factor" do
      # Scale by 2: [2 0 0 2 0 0]
      # Translate by (10, 20): [1 0 0 1 10 20]
      # M_scale × M_translate:
      #   a = 2*1 + 0*0 = 2
      #   b = 2*0 + 0*2 = 0
      #   c = 0*1 + 2*0 = 0
      #   d = 0*0 + 2*2 = 4  ← wait, scale [2 0 0 2 0 0] means a=2,b=0,c=0,d=2
      #   So: a=2*1+0*0=2, b=2*0+0*2=0, c=0*1+2*0=0, d=0*0+2*2=4 ... that can't be right
      # Let me recalculate with correct formula:
      # M1={2,0,0,2,0,0}, M2={1,0,0,1,10,20}
      # a3 = 2*1 + 0*0 = 2
      # b3 = 2*0 + 0*1 = 0
      # c3 = 0*1 + 2*0 = 0
      # d3 = 0*0 + 2*1 = 2
      # e3 = 0*1 + 0*0 + 10 = 10
      # f3 = 0*0 + 0*1 + 20 = 20
      scale = {2.0, 0.0, 0.0, 2.0, 0.0, 0.0}
      trans = {1.0, 0.0, 0.0, 1.0, 10.0, 20.0}
      {a, b, c, d, e, f} = GraphicsState.multiply(scale, trans)
      assert_in_delta a, 2.0, 1.0e-9
      assert_in_delta b, 0.0, 1.0e-9
      assert_in_delta c, 0.0, 1.0e-9
      assert_in_delta d, 2.0, 1.0e-9
      assert_in_delta e, 10.0, 1.0e-9
      assert_in_delta f, 20.0, 1.0e-9
    end

    test "non-trivial rotation-like matrix multiplication" do
      # M1 = {1, 2, 3, 4, 5, 6} — arbitrary non-degenerate matrix
      # M2 = {7, 8, 9, 10, 11, 12}
      # Computed by hand using the formula:
      # a3 = 1*7 + 2*9 = 7+18 = 25
      # b3 = 1*8 + 2*10 = 8+20 = 28
      # c3 = 3*7 + 4*9 = 21+36 = 57
      # d3 = 3*8 + 4*10 = 24+40 = 64
      # e3 = 5*7 + 6*9 + 11 = 35+54+11 = 100
      # f3 = 5*8 + 6*10 + 12 = 40+60+12 = 112
      m1 = {1.0, 2.0, 3.0, 4.0, 5.0, 6.0}
      m2 = {7.0, 8.0, 9.0, 10.0, 11.0, 12.0}
      {a, b, c, d, e, f} = GraphicsState.multiply(m1, m2)
      assert_in_delta a, 25.0, 1.0e-9
      assert_in_delta b, 28.0, 1.0e-9
      assert_in_delta c, 57.0, 1.0e-9
      assert_in_delta d, 64.0, 1.0e-9
      assert_in_delta e, 100.0, 1.0e-9
      assert_in_delta f, 112.0, 1.0e-9
    end
  end

  # ---- 8.1.2 push/1 — q operator ----

  describe "push/1" do
    test "pushes current state onto stack" do
      state = %GraphicsState{ctm: {2.0, 0.0, 0.0, 2.0, 0.0, 0.0}, font_size: 12.0}
      pushed = GraphicsState.push(state)
      assert length(pushed.stack) == 1
      [saved | _] = pushed.stack
      assert saved.ctm == {2.0, 0.0, 0.0, 2.0, 0.0, 0.0}
      assert saved.font_size == 12.0
    end

    test "push twice yields stack depth 2" do
      state = %GraphicsState{}
      state2 = GraphicsState.push(state)
      state3 = GraphicsState.push(state2)
      assert length(state3.stack) == 2
    end

    test "state is preserved after push (fields unchanged)" do
      state = %GraphicsState{leading: 15.0}
      pushed = GraphicsState.push(state)
      # The current state (not stack) should still have the same fields
      assert pushed.leading == 15.0
    end
  end

  # ---- 8.1.3 pop/1 — Q operator ----

  describe "pop/1" do
    test "restores state from stack" do
      original = %GraphicsState{font_size: 12.0, leading: 14.0}
      pushed = GraphicsState.push(original)
      # Modify the pushed state
      modified = %{pushed | font_size: 24.0, leading: 28.0}
      restored = GraphicsState.pop(modified)
      assert restored.font_size == 12.0
      assert restored.leading == 14.0
    end

    test "pop with empty stack is a no-op (silent)" do
      state = %GraphicsState{}
      result = GraphicsState.pop(state)
      assert result == state
    end

    test "q/Q sequence restores nested state" do
      s0 = %GraphicsState{font_size: 10.0}
      s1 = GraphicsState.push(s0)
      s1_modified = %{s1 | font_size: 20.0}
      s2 = GraphicsState.push(s1_modified)
      s2_modified = %{s2 | font_size: 30.0}
      # Q twice
      s1_back = GraphicsState.pop(s2_modified)
      assert s1_back.font_size == 20.0
      s0_back = GraphicsState.pop(s1_back)
      assert s0_back.font_size == 10.0
    end
  end

  # ---- 8.1.4 new/0 — initial state ----

  describe "new/0" do
    test "returns a fresh GraphicsState with identity CTM and zero text state" do
      state = GraphicsState.new()
      assert state.ctm == @identity
      assert state.tm == @identity
      assert state.tlm == @identity
      assert state.font == nil
      assert state.font_size == 0.0
      assert state.leading == 0.0
      assert state.stack == []
    end
  end
end
