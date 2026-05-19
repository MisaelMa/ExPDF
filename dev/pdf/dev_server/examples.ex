defmodule Pdf.DevServer.Examples do
  @moduledoc false

  @doc """
  Returns examples grouped by category: [{category_id, category_name, examples}].
  Each example is {id, name, description, render_fun}.
  """
  def categories do
    [
      {"api", "Pure API", Pdf.DevServer.Examples.Api.list()},
      {"map", "Builder API", Pdf.DevServer.Examples.Map.list()},
      {"component", "Components", Pdf.DevServer.Examples.Component.list()},
      {"component/map", "Components (Builder)", Pdf.DevServer.Examples.ComponentMap.list()}
    ]
  end

  @doc """
  Flat list of all examples (backward compat). Returns [{id, name, desc, fun}].
  """
  def list do
    categories()
    |> Enum.flat_map(fn {_cat_id, _cat_name, examples} -> examples end)
  end

  @doc """
  Render an example by id. Returns {:ok, binary} or {:error, reason}.
  """
  def render(category, id) do
    examples =
      case Enum.find(categories(), fn {cat_id, _, _} -> cat_id == category end) do
        {_, _, exs} -> exs
        nil -> []
      end

    case Enum.find(examples, fn {eid, _, _, _} -> eid == id end) do
      {_, _, _, fun} ->
        try do
          doc = fun.()
          {:ok, Pdf.export(doc)}
        rescue
          e -> {:error, Exception.message(e)}
        end

      nil ->
        {:error, "Example '#{id}' not found in category '#{category}'"}
    end
  end

  def render(id) do
    case Enum.find(list(), fn {eid, _, _, _} -> eid == id end) do
      {_, _, _, fun} ->
        try do
          doc = fun.()
          {:ok, Pdf.export(doc)}
        rescue
          e -> {:error, Exception.message(e)}
        end

      nil ->
        {:error, "Example '#{id}' not found"}
    end
  end
end
