defmodule Pdf.DevServer.Server do
  @moduledoc false

  use GenServer

  def start_link(opts) do
    case Pdf.DevServer.Boot.start(opts) do
      {:ok, cowboy_pid} ->
        GenServer.start_link(__MODULE__, cowboy_pid, name: __MODULE__)

      {:error, :eaddrinuse} ->
        port = Keyword.get(opts, :port, Pdf.DevServer.Boot.default_port())

        IO.warn("""
        PDF Dev Server not started: port #{port} is already in use.
        Stop the other process or set PDF_DEV_SERVER_PORT to another port.
        """)

        :ignore

      {:error, reason} ->
        IO.warn("PDF Dev Server not started: #{inspect(reason)}")
        :ignore
    end
  end

  @impl true
  def init(cowboy_pid), do: {:ok, cowboy_pid}
end
