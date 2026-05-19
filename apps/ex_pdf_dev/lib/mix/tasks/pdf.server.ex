defmodule Mix.Tasks.Pdf.Server do
  @moduledoc """
  Starts a development server for previewing PDF examples.

      $ mix pdf.server

  Options:
    --port PORT  Port to listen on (default: 4200)

  The server is only available in the :dev environment.
  """
  @shortdoc "Start the PDF preview dev server"

  use Mix.Task

  @default_port 4200

  @impl true
  def run(args) do
    Application.ensure_all_started(:plug_cowboy)

    {opts, _, _} = OptionParser.parse(args, strict: [port: :integer])
    port = Keyword.get(opts, :port, @default_port)

    {:ok, _} = Plug.Cowboy.http(Pdf.DevServer, [], port: port)
    print_banner(port)
    Process.sleep(:infinity)
  end

  defp print_banner(port) do
    Mix.shell().info("""

    ┌─────────────────────────────────────────┐
    │  📄 Pdf Dev Server running!             │
    │                                         │
    │  → http://localhost:#{String.pad_trailing(to_string(port), 5)}               │
    │                                         │
    │  Press Ctrl+C to stop                   │
    └─────────────────────────────────────────┘
    """)
  end
end
