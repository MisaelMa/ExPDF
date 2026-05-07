defmodule Pdf.DocumentTest do
  use ExUnit.Case, async: true

  alias Pdf.{Document, ObjectCollection, Dictionary}

  describe "new/1" do
    test "it creates a default info dictionary" do
      document = Document.new()

      assert get_info(document) == %{"Creator" => "Elixir", "Producer" => "Elixir-PDF"}
    end
  end

  describe "put_info/2" do
    test "it sets info by key" do
      document =
        Document.new()
        |> Document.put_info(title: "Test Title", producer: "Test Producer")

      assert get_info(document) == %{
               "Creator" => "Elixir",
               "Producer" => "Test Producer",
               "Title" => "Test Title"
             }
    end

    test "it handles an invalid key" do
      assert_raise ArgumentError, fn ->
        Document.new()
        |> Document.put_info(title: "Test Title", producers: "Test Producer")
      end
    end

    test "title is preserved after a page mutation (set_font)" do
      # Regression: set_font calls sync_page which replaces document.objects with
      # page.objects — losing any put_info changes made after page creation.
      document =
        Document.new()
        |> Document.put_info(title: "My Title")
        |> Document.set_font("Helvetica", 12, [])

      assert get_info(document)["Title"] == "My Title"
    end

    test "title is preserved after text_at" do
      document =
        Document.new()
        |> Document.put_info(title: "Round-trip Title")
        |> Document.set_font("Helvetica", 12, [])
        |> Document.text_at({100, 720}, "Hello", [])

      assert get_info(document)["Title"] == "Round-trip Title"
    end
  end

  defp get_info(document) do
    document.objects |> ObjectCollection.get_object(document.info) |> Dictionary.to_map()
  end

  test "autoprint/0" do
    document = Document.autoprint(Document.new())
    assert {:object, _, _} = ref = document.action

    assert %Dictionary{
             entries: %{
               {:name, "S"} => {:name, "Named"},
               {:name, "Type"} => {:name, "Action"},
               {:name, "N"} => {:name, "Print"}
             }
           } = Document.get_object(document, ref)
  end
end
