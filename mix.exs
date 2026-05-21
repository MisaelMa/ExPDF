defmodule ExPdf.Umbrella.Mixfile do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "2.0.0",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:releaser, "~> 0.0.7", only: :dev, runtime: false}
    ]
  end

  defp aliases do
    [
      # mix test desde la raíz: soporta apps/<app>/test/... (runner del umbrella).
      # Para forzar tests en cada app por separado: mix test.all
      "test.all": ["cmd mix test"],
      server: ["cmd --app ex_pdf_dev mix pdf.server"]
    ]
  end
end
