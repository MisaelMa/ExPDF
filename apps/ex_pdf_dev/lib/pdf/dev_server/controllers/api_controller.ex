defmodule Pdf.DevServer.ApiController do
  @moduledoc false

  import Plug.Conn

  def examples(conn) do
    categories = Pdf.DevServer.Examples.categories()

    json =
      categories
      |> Enum.map(fn {cat_id, cat_name, examples} ->
        %{id: cat_id, name: cat_name,
          examples: Enum.map(examples, fn {id, name, _desc, _fun} -> %{id: id, name: name} end)}
      end)
      |> Jason.encode!()

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, json)
  end
end
