defmodule Pdf.DevServer.Examples.Component.CodeBlockDemo do
  @moduledoc false

  def render do
    dark = {0.1, 0.1, 0.1}
    accent = {0.0, 0.45, 0.75}
    gray = {0.45, 0.45, 0.45}

    doc =
      Pdf.new(size: :a4, margin: 40)
      |> Pdf.set_font("Helvetica", 24)
      |> Pdf.set_fill_color(dark)
      |> Pdf.text_at({40, 780}, "CodeBlock Component", %{bold: true})
      |> Pdf.set_font("Helvetica", 10)
      |> Pdf.set_fill_color(gray)
      |> Pdf.text_at({40, 764}, "Monospaced code with background, line numbers, and title bar")

    # ── Simple code block ──
    doc =
      doc
      |> Pdf.set_font("Helvetica", 12)
      |> Pdf.set_fill_color(accent)
      |> Pdf.text_at({40, 730}, "Simple Code Block", %{bold: true})
      |> Pdf.Component.CodeBlock.render({40, 715}, %{width: 500},
        "defmodule Hello do\n  def world do\n    IO.puts(\"Hello, world!\")\n  end\nend")

    # ── With line numbers ──
    doc =
      doc
      |> Pdf.set_font("Helvetica", 12)
      |> Pdf.set_fill_color(accent)
      |> Pdf.text_at({40, 620}, "With Line Numbers", %{bold: true})
      |> Pdf.Component.CodeBlock.render({40, 605}, %{
        width: 500,
        line_numbers: true
      }, "defmodule MyApp.Router do\n  use Plug.Router\n\n  plug :match\n  plug :dispatch\n\n  get \"/\" do\n    send_resp(conn, 200, \"OK\")\n  end\nend")

    # ── With title bar ──
    doc =
      doc
      |> Pdf.set_font("Helvetica", 12)
      |> Pdf.set_fill_color(accent)
      |> Pdf.text_at({40, 460}, "With Title Bar", %{bold: true})
      |> Pdf.Component.CodeBlock.render({40, 445}, %{
        width: 500,
        line_numbers: true,
        title: "config/runtime.exs"
      }, "import Config\n\nconfig :my_app, MyApp.Repo,\n  url: System.get_env(\"DATABASE_URL\"),\n  pool_size: 10")

    # ── Dark theme ──
    doc
    |> Pdf.set_font("Helvetica", 12)
    |> Pdf.set_fill_color(accent)
    |> Pdf.text_at({40, 310}, "Dark Theme", %{bold: true})
    |> Pdf.Component.CodeBlock.render({40, 295}, %{
      width: 500,
      line_numbers: true,
      title: "terminal",
      background: {0.15, 0.16, 0.18},
      color: {0.85, 0.88, 0.82},
      border_color: {0.3, 0.3, 0.35},
      line_number_color: {0.4, 0.42, 0.45}
    }, "$ mix deps.get\nResolving Hex dependencies...\nDependency resolution completed:\n  ex_pdf 2.0.0\n  plug_cowboy 2.7.0\n$ mix compile\nCompiling 42 files (.ex)\nGenerated ex_pdf app")
  end
end
