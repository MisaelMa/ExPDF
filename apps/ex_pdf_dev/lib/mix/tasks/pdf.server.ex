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
    {opts, _, _} = OptionParser.parse(args, strict: [port: :integer])
    port = Keyword.get(opts, :port, @default_port)

    {:ok, _} = Pdf.DevServer.Boot.start(port: port)
    Process.sleep(:infinity)
  end
end
