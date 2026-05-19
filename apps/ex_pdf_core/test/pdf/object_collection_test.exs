defmodule Pdf.ObjectCollectionTest do
  use ExUnit.Case, async: true

  alias Pdf.{Dictionary, ObjectCollection}

  test "adding an object to the collection" do
    collection = ObjectCollection.new()
    dictionary = Dictionary.new()
    {object, _collection} = ObjectCollection.create_object(collection, dictionary)
    assert object == {:object, 1, 0}
  end
end
