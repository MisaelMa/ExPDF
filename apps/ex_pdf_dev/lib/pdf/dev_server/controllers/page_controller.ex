defmodule Pdf.DevServer.PageController do
  @moduledoc false

  import Plug.Conn

  def index(conn) do
    categories = Pdf.DevServer.Examples.categories()
    html = Pdf.DevServer.Templates.render_index(categories, nil)

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, html)
  end

  def index(conn, category, id) do
    categories = Pdf.DevServer.Examples.categories()
    html = Pdf.DevServer.Templates.render_index(categories, "#{category}/#{id}")

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, html)
  end
end
