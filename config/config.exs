import Config

config :ex_pdf_dev,
  auto_start_server: false,
  server_port: 4200

import_config "#{Mix.env()}.exs"
