defmodule ExBarcode do
  @moduledoc """
  Pure Elixir barcode encoding library.

  Supports Code 128 (full ASCII). Returns bar patterns as lists of
  module widths suitable for any renderer (PDF, SVG, Canvas, etc.).

  ## Standard encoding

      {:ok, bars} = ExBarcode.encode("Hello-123")

  Returns alternating bar/space module widths.

  ## Shaped encoding (creative barcodes)

      {:ok, result} = ExBarcode.encode_shaped("DEMOCAMP", shape: :rv)
      result.bars          # positioned bars with individual heights
      result.decorations   # solid shapes (wheels, windows, etc.)

  Returns an `ExBarcode.Shape.Result` with normalized 0.0–1.0 coordinates.
  Any renderer scales to desired size.

  Available shapes: `:rv`, `:camper`, `:city`, `:wave`, `:diamond`, `:hill`
  """

  defdelegate encode(text), to: ExBarcode.Code128
  defdelegate encode!(text), to: ExBarcode.Code128
  defdelegate total_modules(text), to: ExBarcode.Code128

  defdelegate encode_shaped(text, opts), to: ExBarcode.Shape, as: :encode
  defdelegate encode_shaped!(text, opts), to: ExBarcode.Shape, as: :encode!
  defdelegate available_shapes(), to: ExBarcode.Shape
end
