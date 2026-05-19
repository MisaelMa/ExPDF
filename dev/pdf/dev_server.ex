defmodule Pdf.DevServer do
  @moduledoc false
  use Plug.Router

  alias Pdf.DevServer.{PageController, PdfController, ApiController}

  plug(:recompile)
  plug(Plug.Logger, log: :debug)
  plug(:match)
  plug(:dispatch)

  defp recompile(conn, _opts) do
    Code.compiler_options(ignore_module_conflict: true)
    IEx.Helpers.recompile()
    conn
  end

  get "/",                       do: PageController.index(conn)
  get "/api/examples",           do: ApiController.examples(conn)

  # View routes — serve the index page with the example pre-selected
  get "/view/component/map/:id", do: PageController.index(conn, "component/map", id)
  get "/view/:category/:id",     do: PageController.index(conn, category, id)

  # PDF binary routes — return the generated PDF
  get "/pdf/component/map/:id",  do: PdfController.show(conn, "component/map", id)
  get "/pdf/:category/:id",      do: PdfController.show(conn, category, id)
  get "/pdf/:id",                do: PdfController.show(conn, id)

  match _, do: send_resp(conn, 404, "Not found")
end
