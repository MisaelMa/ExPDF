defmodule Pdf.DevServer.Supervisor do
  @moduledoc false

  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      {Pdf.DevServer.Server, port: Pdf.DevServer.Boot.default_port()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
