defmodule ExPdfDev.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      if Application.get_env(:ex_pdf_dev, :auto_start_server, false) do
        [{Pdf.DevServer.Supervisor, []}]
      else
        []
      end

    Supervisor.start_link(children, strategy: :one_for_one, name: ExPdfDev.Supervisor)
  end
end
