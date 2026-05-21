defmodule Pdf.DevServer.ReceiptController do
  @moduledoc false

  import Plug.Conn

  @remote_node Application.compile_env(:ex_pdf_dev, :receipt_remote_node)

  def show(conn, order_id) do
    with :ok <- ensure_connected(),
         data when is_map(data) <- fetch_data(String.to_integer(order_id)) do
      binary =
        data
        |> Pdf.DevServer.Examples.Map.Receipt.render_with_data()
        |> Pdf.export()

      conn
      |> put_resp_content_type("application/pdf")
      |> put_resp_header("content-disposition", "inline; filename=\"receipt_#{order_id}.pdf\"")
      |> send_resp(200, binary)
    else
      {:error, reason} ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(500, "Error: #{inspect(reason)}")
    end
  end

  defp ensure_connected do
    if @remote_node in Node.list() do
      :ok
    else
      case Node.connect(@remote_node) do
        true -> :ok
        _ ->
          {:error,
           "Could not connect to #{@remote_node}. Start the remote node with the same cookie."}
      end
    end
  end

  defp fetch_data(order_id) do
    case :rpc.call(@remote_node, Core.PDF.DataBookingReceipt, :build_data_for_remote, [order_id]) do
      {:badrpc, reason} -> {:error, "RPC failed: #{inspect(reason)}"}
      data -> data
    end
  end
end
