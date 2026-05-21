import Config

config :ex_pdf_dev,
  auto_start_server: true,
  server_port: String.to_integer(System.get_env("PDF_DEV_SERVER_PORT") || "4200"),
  receipt_remote_node: :"server@127.0.0.1",
  spot2nite_fonts_dir: Path.expand("apps/ex_pdf_dev/priv/pdf_assets/fonts", File.cwd!())
