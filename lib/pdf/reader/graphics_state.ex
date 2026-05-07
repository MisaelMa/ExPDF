defmodule Pdf.Reader.GraphicsState do
  @moduledoc """
  Struct and operations for the PDF graphics state during content stream interpretation.

  CTM (current transformation matrix) and text matrices are stored as 6-float
  tuples `{a, b, c, d, e, f}` — the affine subset used by PDF (§8.3.3 of the
  PDF spec). Full 4×4 matrices are NOT used; PDF only needs the 2D affine form.

  The `:stack` holds snapshots pushed by the `q` operator and restored by `Q`.

  ## Matrix convention

  PDF uses the row-vector convention (§ 8.3.3):

      | a b 0 |
      | c d 0 |
      | e f 1 |

  Multiplication: M3 = M1 × M2 with formulas:

      a3 = a1*a2 + b1*c2
      b3 = a1*b2 + b1*d2
      c3 = c1*a2 + d1*c2
      d3 = c1*b2 + d1*d2
      e3 = e1*a2 + f1*c2 + e2
      f3 = e1*b2 + f1*d2 + f2
  """

  @type matrix :: {float(), float(), float(), float(), float(), float()}

  @identity {1.0, 0.0, 0.0, 1.0, 0.0, 0.0}

  @type t :: %__MODULE__{
          ctm: matrix(),
          tm: matrix(),
          tlm: matrix(),
          font: nil | binary(),
          font_size: float(),
          leading: float(),
          char_spacing: float(),
          word_spacing: float(),
          horizontal_scaling: float(),
          rise: float(),
          stack: [t()]
        }

  defstruct ctm: @identity,
            tm: @identity,
            tlm: @identity,
            font: nil,
            font_size: 0.0,
            leading: 0.0,
            char_spacing: 0.0,
            word_spacing: 0.0,
            horizontal_scaling: 1.0,
            rise: 0.0,
            stack: []

  # ---------------------------------------------------------------------------
  # Constructor
  # ---------------------------------------------------------------------------

  @doc "Returns a fresh GraphicsState with identity matrices and zeroed text state."
  @spec new() :: t()
  def new, do: %__MODULE__{}

  # ---------------------------------------------------------------------------
  # Matrix operations
  # ---------------------------------------------------------------------------

  @doc """
  Multiplies two affine matrices under the PDF row-vector convention.

  `multiply(m1, m2)` returns `M3 = M1 × M2`.
  Both arguments and the result are 6-element `{a, b, c, d, e, f}` tuples.

  Spec reference: PDF 1.7 § 8.3.4.
  """
  @spec multiply(matrix(), matrix()) :: matrix()
  def multiply(
        {a1, b1, c1, d1, e1, f1},
        {a2, b2, c2, d2, e2, f2}
      ) do
    {
      a1 * a2 + b1 * c2,
      a1 * b2 + b1 * d2,
      c1 * a2 + d1 * c2,
      c1 * b2 + d1 * d2,
      e1 * a2 + f1 * c2 + e2,
      e1 * b2 + f1 * d2 + f2
    }
  end

  # ---------------------------------------------------------------------------
  # Stack operations — `q` and `Q`
  # ---------------------------------------------------------------------------

  @doc """
  Pushes the current graphics state onto `:stack` (implements PDF `q` operator).

  The full state struct is saved. No fields are excluded — this keeps semantics
  consistent with the writer's `q`/`Q` discipline.
  """
  @spec push(t()) :: t()
  def push(%__MODULE__{stack: stack} = state) do
    %{state | stack: [state | stack]}
  end

  @doc """
  Pops the most-recently-pushed graphics state from `:stack` (implements PDF `Q` operator).

  If the stack is empty (malformed stream), this is a silent no-op — the interpreter
  remains in the current state rather than crashing. Spec allows senders to have
  unbalanced `q`/`Q` in practice (e.g. content streams generated without strict nesting).
  """
  @spec pop(t()) :: t()
  def pop(%__MODULE__{stack: []} = state), do: state

  def pop(%__MODULE__{stack: [saved | rest]}) do
    %{saved | stack: rest}
  end
end
