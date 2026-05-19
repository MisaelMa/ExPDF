defmodule Pdf.DevServer.PdfController do
  @moduledoc false

  import Plug.Conn

  def show(conn, category, id) do
    case Pdf.DevServer.Examples.render(category, id) do
      {:ok, binary} ->
        conn
        |> put_resp_content_type("application/pdf")
        |> put_resp_header("content-disposition", "inline; filename=\"#{id}.pdf\"")
        |> send_resp(200, binary)

      {:error, reason} ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(500, "Error generating PDF: #{inspect(reason)}")
    end
  end

  def show(conn, id) do
    case Pdf.DevServer.Examples.render(id) do
      {:ok, binary} ->
        conn
        |> put_resp_content_type("application/pdf")
        |> put_resp_header("content-disposition", "inline; filename=\"#{id}.pdf\"")
        |> send_resp(200, binary)

      {:error, reason} ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(500, "Error generating PDF: #{inspect(reason)}")
    end
  end
end
