defmodule Pdf.ObjectCollection do
  @moduledoc false

  alias Pdf.Object

  defstruct size: 0, objects: %{}

  def new, do: %__MODULE__{}

  def create_object(%__MODULE__{size: size, objects: objects} = collection, object) do
    new_size = size + 1
    key = {:object, new_size, 0}
    {key, %{collection | size: new_size, objects: Map.put(objects, key, object)}}
  end

  def get_object(%__MODULE__{objects: objects}, key) do
    Map.get(objects, key)
  end

  def update_object(%__MODULE__{objects: objects} = collection, key, value) do
    %{collection | objects: Map.put(objects, key, value)}
  end

  def call(%__MODULE__{objects: objects} = collection, object_key, method, args) do
    object = Map.get(objects, object_key)
    result = Kernel.apply(object.__struct__, method, [object | args])
    {object_key, %{collection | objects: Map.put(objects, object_key, result)}}
  end

  def all(%__MODULE__{objects: objects}) do
    objects
    |> Enum.map(fn {{:object, number, _generation}, object} ->
      Object.new(number, object)
    end)
  end
end
