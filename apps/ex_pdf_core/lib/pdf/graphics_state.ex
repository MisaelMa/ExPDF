defmodule Pdf.GraphicsState do
  @moduledoc false

  alias Pdf.Dictionary

  import Pdf.Utils

  def new(opts) do
    dict = %{"Type" => n("ExtGState")}

    dict =
      case Keyword.get(opts, :fill_opacity) do
        nil -> dict
        val -> Map.put(dict, "ca", val)
      end

    dict =
      case Keyword.get(opts, :stroke_opacity) do
        nil -> dict
        val -> Map.put(dict, "CA", val)
      end

    Dictionary.new(dict)
  end

  def key(opts) do
    fill = Keyword.get(opts, :fill_opacity, 1.0)
    stroke = Keyword.get(opts, :stroke_opacity, 1.0)
    {fill, stroke}
  end
end
