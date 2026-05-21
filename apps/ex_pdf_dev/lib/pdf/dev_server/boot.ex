defmodule Pdf.DevServer.Boot do
  @moduledoc false

  @default_port 4200

  @doc """
  Starts the Plug/Cowboy PDF preview server on `port`.
  Returns `{:ok, cowboy_pid}`.
  """
  @spec start(keyword()) :: {:ok, pid()}
  def start(opts \\ []) do
    port = Keyword.get(opts, :port, default_port())

    Application.ensure_all_started(:plug_cowboy)

    case Plug.Cowboy.http(Pdf.DevServer, [], port: port) do
      {:ok, pid} ->
        print_banner(port)
        {:ok, pid}

      {:error, reason} = error ->
        error
    end
  end

  @doc false
  def default_port do
    Application.get_env(:ex_pdf_dev, :server_port, @default_port)
  end

  defp print_banner(port) do
    IO.puts("""

    ┌─────────────────────────────────────────┐
    │  📄 Pdf Dev Server running!             │
    │                                         │
    │  → http://localhost:#{String.pad_trailing(to_string(port), 5)}               │
    │                                         │
    │  Press Ctrl+C twice to stop (IEx)       │
    └─────────────────────────────────────────┘
    """)
  end
end
