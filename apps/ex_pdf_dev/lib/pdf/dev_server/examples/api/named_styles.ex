defmodule Pdf.DevServer.Examples.Api.NamedStyles do
  @moduledoc false

  def render do
    Pdf.new(size: :a4, margin: 50)
    |> Pdf.set_info(title: "Named Styles")
    |> Pdf.register_styles(%{
      title: %{font_size: 28, bold: true, color: :navy},
      subtitle: %{font_size: 16, italic: true, color: :gray},
      heading: %{font_size: 18, bold: true, color: {0.15, 0.23, 0.38}},
      body: %{font_size: 12, color: :black},
      accent: %{font_size: 12, color: {0.2, 0.6, 0.4}},
      code: %{font: "Courier", font_size: 11, color: {0.6, 0.2, 0.2}},
      mono: %{font: "Courier", font_size: 12, color: :black},
      serif: %{font: "Times-Roman", font_size: 13, color: :black},
      serif_bold: %{font: "Times-Roman", font_size: 13, bold: true, color: :black},
      small: %{font_size: 9, color: :gray},
      divider: %{stroke_color: {0.8, 0.8, 0.8}, line_width: 0.5}
    })
    |> Pdf.set_font("Helvetica", 12)
    |> Pdf.text("Named Styles Demo", :title)
    |> Pdf.spacer(5)
    |> Pdf.text("Define once, use everywhere — like CSS classes", :subtitle)
    |> Pdf.spacer(15)
    |> Pdf.horizontal_line(:divider)
    |> Pdf.spacer(10)
    |> Pdf.text("How it works", :heading)
    |> Pdf.spacer(8)
    |> Pdf.text("Register styles by name, then reference them by atom:", :body)
    |> Pdf.spacer(5)
    |> Pdf.text("Pdf.register_style(:heading, %{font_size: 18, bold: true})", :code)
    |> Pdf.text("Pdf.text(doc, \"My Title\", :heading)", :code)
    |> Pdf.spacer(10)
    |> Pdf.text("Or register multiple at once:", :body)
    |> Pdf.spacer(5)
    |> Pdf.text("Pdf.register_styles(doc, %{heading: ..., body: ..., accent: ...})", :code)
    |> Pdf.spacer(15)
    |> Pdf.horizontal_line(:divider)
    |> Pdf.spacer(10)
    |> Pdf.text("Styles in action", :heading)
    |> Pdf.spacer(8)
    |> Pdf.text("This line uses :body style — clean and readable.", :body)
    |> Pdf.spacer(3)
    |> Pdf.text("This line uses :accent style — great for highlights.", :accent)
    |> Pdf.spacer(3)
    |> Pdf.text("This line uses :code style — for code snippets.", :code)
    |> Pdf.spacer(3)
    |> Pdf.text("This line uses :small style — for fine print.", :small)
    |> Pdf.spacer(15)
    |> Pdf.horizontal_line(:divider)
    |> Pdf.spacer(10)
    |> Pdf.text("Font support in styles", :heading)
    |> Pdf.spacer(8)
    |> Pdf.text("Each style can specify its own font family:", :body)
    |> Pdf.spacer(5)
    |> Pdf.text("This is Helvetica (default sans-serif)", :body)
    |> Pdf.spacer(3)
    |> Pdf.text("This is Courier (monospace) — great for code", :mono)
    |> Pdf.spacer(3)
    |> Pdf.text("This is Times-Roman (serif) — classic and elegant", :serif)
    |> Pdf.spacer(3)
    |> Pdf.text("This is Times-Roman Bold", :serif_bold)
    |> Pdf.spacer(3)
    |> Pdf.text("def render(doc), do: Pdf.text(doc, \"hello\", :mono)", :code)
    |> Pdf.spacer(15)
    |> Pdf.horizontal_line(:divider)
    |> Pdf.spacer(10)
    |> Pdf.text("Builder + Named Styles", :heading)
    |> Pdf.spacer(8)
    |> Pdf.text("Named styles also work in Builder templates:", :body)
    |> Pdf.spacer(5)
    |> Pdf.text("{:text, \"Title\", :heading}  instead of  {:text, \"Title\", %{font_size: 18, bold: true}}", :code)
    |> Pdf.spacer(15)
    |> Pdf.text("Styles can be passed in Builder config: %{styles: %{heading: ..., body: ...}}", :small)
  end
end
