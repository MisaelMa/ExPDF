defmodule Pdf.DevServer.Examples do
  @moduledoc false

  @doc """
  Returns a list of {id, name, description, render_fun} tuples.
  """
  def list do
    [
      {"hello_world", "Hello World", "Basic text on a page", &hello_world/0},
      {"styles", "Styled Text", "CSS-like styles: bold, colors, sizes", &styles/0},
      {"margins_cursor", "Margins & Cursor", "Margins, cursor tracking, spacers", &margins_cursor/0},
      {"opacity_transforms", "Opacity & Transforms", "Fill/stroke opacity, rotation, scaling", &opacity_transforms/0},
      {"watermark", "Watermark", "Text watermark with opacity and rotation", &watermark_example/0},
      {"background", "Background Color", "Colored page background", &background_example/0},
      {"layout_box", "Layout: Box", "Box container with padding, border, background", &layout_box/0},
      {"layout_row", "Layout: Row", "Horizontal row distribution by weight", &layout_row/0},
      {"layout_column", "Layout: Column", "Vertical column stacking", &layout_column/0},
      {"page_templates", "Page Templates", "Header/footer on every page", &page_templates/0},
      {"named_styles", "Named Styles", "Define reusable styles by name (like CSS classes)", &named_styles/0},
      {"builder", "Builder API", "Declarative PDF from template list", &builder_example/0},
      {"table_simple", "Table: Simple", "Basic styled table with header", &table_simple/0},
      {"table_zebra", "Table: Zebra Stripes", "Alternating row colors with rounded border", &table_zebra/0},
      {"table_receipt", "Table: Receipt", "Point-of-sale receipt style", &table_receipt/0},
      {"table_invoice", "Table: Invoice", "Professional invoice with totals", &table_invoice/0},
      {"cfdi_maps", "CFDI (Style Maps)", "Mexican invoice using style maps %{x:, y:, bold:}", &cfdi_maps/0},
      {"cfdi_invoice", "CFDI (Direct API)", "Mexican invoice using direct API calls", &cfdi_invoice/0},
      {"rv_maps", "RV Receipt (Style Maps)", "Reservation receipt using style maps", &rv_maps/0},
      {"rv_receipt", "RV Receipt (Direct API)", "Reservation receipt using direct API calls", &rv_receipt/0},
      {"debug_grid", "Debug Grid", "Grid overlay with margin outline and cursor position", &debug_grid_example/0},
      {"full_document", "Full Document", "Complete document with all features", &full_document/0}
    ]
  end

  @doc """
  Render an example by id. Returns {:ok, binary} or {:error, reason}.
  """
  def render(id) do
    case Enum.find(list(), fn {eid, _, _, _} -> eid == id end) do
      {_, _, _, fun} ->
        try do
          doc = fun.()
          {:ok, Pdf.export(doc)}
        rescue
          e -> {:error, Exception.message(e)}
        end

      nil ->
        {:error, "Example '#{id}' not found"}
    end
  end

  # ── Examples ────────────────────────────────────────────────────────

  defp hello_world do
    Pdf.new(size: :a4)
    |> Pdf.set_info(title: "Hello World")
    |> Pdf.set_font("Helvetica", 24)
    |> Pdf.text_at({200, 600}, "Hello World!")
    |> Pdf.set_font("Helvetica", 12)
    |> Pdf.text_at({200, 570}, "Generated with elixir-pdf")
  end

  defp styles do
    Pdf.new(size: :a4, margin: 50, compress: false)
    |> Pdf.set_info(title: "Styled Text")
    |> Pdf.text("Normal text (Helvetica 12)", %{})
    |> Pdf.spacer(5)
    |> Pdf.text("Bold text", %{bold: true})
    |> Pdf.spacer(5)
    |> Pdf.text("Large red text", %{font_size: 24, color: :red})
    |> Pdf.spacer(5)
    |> Pdf.text("Blue italic", %{italic: true, color: :blue, font_size: 16})
    |> Pdf.spacer(5)
    |> Pdf.text("Small gray text", %{font_size: 8, color: :gray})
    |> Pdf.spacer(10)
    |> Pdf.horizontal_line(%{color: :gray})
    |> Pdf.spacer(5)
    |> Pdf.text("After a horizontal line", %{font_size: 14})
  end

  defp margins_cursor do
    Pdf.new(size: :a4, margin: %{top: 60, bottom: 60, left: 50, right: 50})
    |> Pdf.set_info(title: "Margins & Cursor")
    |> Pdf.set_font("Helvetica", 14)
    |> Pdf.text("This document has margins: top=60, bottom=60, left=50, right=50")
    |> Pdf.spacer(10)
    |> Pdf.text("The cursor automatically starts inside the content area.")
    |> Pdf.spacer(20)
    |> Pdf.text("After spacer(20)")
    |> Pdf.spacer(10)
    |> Pdf.horizontal_line()
    |> Pdf.spacer(10)
    |> Pdf.text("After a horizontal line and spacer(10)")
    |> Pdf.spacer(30)
    |> Pdf.text("Content wraps within margins when using Pdf.text/2,3")
  end

  defp opacity_transforms do
    Pdf.new(size: :a4)
    |> Pdf.set_info(title: "Opacity & Transforms")
    |> Pdf.set_font("Helvetica", 12)
    |> Pdf.text_at({50, 800}, "Normal text (full opacity)")
    # Semi-transparent rectangles
    |> Pdf.save_state()
    |> Pdf.set_fill_color(:red)
    |> Pdf.set_fill_opacity(1.0)
    |> Pdf.rectangle({50, 650}, {150, 100})
    |> Pdf.fill()
    |> Pdf.restore_state()
    |> Pdf.save_state()
    |> Pdf.set_fill_color(:blue)
    |> Pdf.set_fill_opacity(0.5)
    |> Pdf.rectangle({120, 620}, {150, 100})
    |> Pdf.fill()
    |> Pdf.restore_state()
    |> Pdf.save_state()
    |> Pdf.set_fill_color(:green)
    |> Pdf.set_fill_opacity(0.3)
    |> Pdf.rectangle({190, 590}, {150, 100})
    |> Pdf.fill()
    |> Pdf.restore_state()
    # Rotated text
    |> Pdf.save_state()
    |> Pdf.set_font("Helvetica", 20)
    |> Pdf.translate({300, 400})
    |> Pdf.rotate(30)
    |> Pdf.text_at({0, 0}, "Rotated 30 degrees")
    |> Pdf.restore_state()
    # Scaled text
    |> Pdf.save_state()
    |> Pdf.set_font("Helvetica", 12)
    |> Pdf.translate({50, 300})
    |> Pdf.scale({2.0, 2.0})
    |> Pdf.text_at({0, 0}, "Scaled 2x")
    |> Pdf.restore_state()
  end

  defp watermark_example do
    Pdf.new(size: :a4, margin: 50)
    |> Pdf.set_info(title: "Watermark Example")
    |> Pdf.text("This page has a DRAFT watermark", %{font_size: 18})
    |> Pdf.spacer(15)
    |> Pdf.text("The watermark is rendered behind the content with low opacity.")
    |> Pdf.spacer(10)
    |> Pdf.text("It uses save_state/restore_state, opacity, translate, and rotate.")
    |> Pdf.watermark("DRAFT", %{opacity: 0.08, rotate: 45, font_size: 72, color: :red})
   
  end

  defp background_example do
    Pdf.new(size: :a4, margin: 50)
    |> Pdf.set_info(title: "Background Color")
    |> Pdf.background(%{background: {0.95, 0.95, 1.0}})
    |> Pdf.text("This page has a light blue background", %{font_size: 18})
    |> Pdf.spacer(10)
    |> Pdf.text("The background fills the entire page behind all content.")
  end

  defp layout_box do
    Pdf.new(size: :a4)
    |> Pdf.set_info(title: "Layout Box")
    |> Pdf.set_font("Helvetica", 12)
    |> then(fn doc ->
      page = doc.current

      page =
        Pdf.Layout.box(
          page,
          {50, 750},
          {250, 120},
          [style: %{padding: 15, border: 2, border_color: :navy, background: {0.93, 0.93, 1.0}}],
          fn page, area ->
            page
            |> Pdf.Page.text_at({area.x, area.y - 14}, "Box with padding, border & background", [])
            |> Pdf.Page.text_at({area.x, area.y - 30}, "Inner area: #{area.width}x#{area.height}", [])
          end
        )

      page =
        Pdf.Layout.box(
          page,
          {320, 750},
          {220, 120},
          [style: %{padding: 10, margin: 5, border: 1, border_color: :gray}],
          fn page, area ->
            page
            |> Pdf.Page.text_at({area.x, area.y - 14}, "Box with margin", [])
            |> Pdf.Page.text_at({area.x, area.y - 30}, "margin=5, padding=10", [])
          end
        )

      %{doc | current: page}
    end)
  end

  defp layout_row do
    Pdf.new(size: :a4)
    |> Pdf.set_info(title: "Layout Row")
    |> Pdf.set_font("Helvetica", 11)
    |> then(fn doc ->
      page = doc.current

      page =
        Pdf.Layout.row(page, {50, 750}, {500, 80}, [
          {1, fn page, area ->
            Pdf.Layout.box(page, {area.x, area.y}, {area.width, area.height},
              [style: %{padding: 8, border: 1, background: {1.0, 0.9, 0.9}}],
              fn page, a ->
                Pdf.Page.text_at(page, {a.x, a.y - 12}, "Col 1 (weight 1)", [])
              end)
          end},
          {2, fn page, area ->
            Pdf.Layout.box(page, {area.x, area.y}, {area.width, area.height},
              [style: %{padding: 8, border: 1, background: {0.9, 1.0, 0.9}}],
              fn page, a ->
                Pdf.Page.text_at(page, {a.x, a.y - 12}, "Col 2 (weight 2, double width)", [])
              end)
          end},
          {1, fn page, area ->
            Pdf.Layout.box(page, {area.x, area.y}, {area.width, area.height},
              [style: %{padding: 8, border: 1, background: {0.9, 0.9, 1.0}}],
              fn page, a ->
                Pdf.Page.text_at(page, {a.x, a.y - 12}, "Col 3 (weight 1)", [])
              end)
          end}
        ], gap: 8)

      %{doc | current: page}
    end)
  end

  defp layout_column do
    Pdf.new(size: :a4)
    |> Pdf.set_info(title: "Layout Column")
    |> Pdf.set_font("Helvetica", 11)
    |> then(fn doc ->
      page = doc.current

      page =
        Pdf.Layout.column(page, {50, 750}, {300, 400}, [
          {50, fn page, area ->
            Pdf.Layout.box(page, {area.x, area.y}, {area.width, area.height},
              [style: %{padding: 10, border: 1, background: {1.0, 0.95, 0.9}}],
              fn page, a ->
                Pdf.Page.text_at(page, {a.x, a.y - 14}, "Row 1 - height 50", [])
              end)
          end},
          {80, fn page, area ->
            Pdf.Layout.box(page, {area.x, area.y}, {area.width, area.height},
              [style: %{padding: 10, border: 1, background: {0.9, 0.95, 1.0}}],
              fn page, a ->
                Pdf.Page.text_at(page, {a.x, a.y - 14}, "Row 2 - height 80", [])
              end)
          end},
          {40, fn page, area ->
            Pdf.Layout.box(page, {area.x, area.y}, {area.width, area.height},
              [style: %{padding: 10, border: 1, background: {0.95, 1.0, 0.9}}],
              fn page, a ->
                Pdf.Page.text_at(page, {a.x, a.y - 14}, "Row 3 - height 40", [])
              end)
          end}
        ], gap: 10)

      %{doc | current: page}
    end)
  end

  defp page_templates do
    Pdf.new(size: :a4, margin: %{top: 60, bottom: 50, left: 50, right: 50})
    |> Pdf.set_info(title: "Page Templates")
    |> Pdf.on_page(:header, fn doc, info ->
      doc
      |> Pdf.set_font("Helvetica", 9)
      |> Pdf.set_fill_color(:gray)
      |> Pdf.text_at({50, 810}, "Pdf Dev Server - Page Templates Example")
      |> Pdf.text_at({480, 810}, "Page #{info.number}")
      |> Pdf.save_state()
      |> Pdf.set_stroke_color(:gray)
      |> Pdf.set_line_width(0.5)
      |> Pdf.line({50, 805}, {545, 805})
      |> Pdf.stroke()
      |> Pdf.restore_state()
      |> Pdf.set_fill_color(:black)
    end)
    |> Pdf.on_page(:footer, fn doc, _info ->
      doc
      |> Pdf.save_state()
      |> Pdf.set_stroke_color(:gray)
      |> Pdf.set_line_width(0.5)
      |> Pdf.line({50, 45}, {545, 45})
      |> Pdf.stroke()
      |> Pdf.restore_state()
      |> Pdf.set_font("Helvetica", 8)
      |> Pdf.set_fill_color(:gray)
      |> Pdf.text_at({230, 33}, "Generated with elixir-pdf")
      |> Pdf.set_fill_color(:black)
    end)
    |> Pdf.set_font("Helvetica", 18)
    |> Pdf.text("Page 1 - Header & Footer", %{font_size: 18})
    |> Pdf.spacer(15)
    |> Pdf.text("This page has automatic header and footer templates.")
    |> Pdf.spacer(10)
    |> Pdf.text("When you add a new page, they appear automatically.")
    |> Pdf.page_break()
    |> Pdf.text("Page 2 - Same templates", %{font_size: 18})
    |> Pdf.spacer(15)
    |> Pdf.text("Notice the header and footer are here too!")
    |> Pdf.page_break()
    |> Pdf.text("Page 3 - Still going", %{font_size: 18})
    |> Pdf.spacer(15)
    |> Pdf.text("Templates persist across all pages.")
  end

  defp named_styles do
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

  defp builder_example do
    template = [
      {:text, "Builder API Demo", %{font_size: 24, bold: true}},
      {:spacer, 15},
      {:text, "This document was built from a declarative template list.", %{font_size: 13}},
      {:spacer, 10},
      {:line, %{color: :gray}},
      {:spacer, 10},
      {:text, "Features used:", %{font_size: 14, bold: true}},
      {:spacer, 5},
      {:text, "  - {:text, string, style} for styled text", %{font_size: 12, color: :green}},
      {:text, "  - {:spacer, amount} for vertical space", %{font_size: 12, color: :green}},
      {:text, "  - {:line, style} for horizontal rules", %{font_size: 12, color: :green}},
      {:text, "  - {:watermark, text, style} for watermarks", %{font_size: 12, color: :green}},
      {:text, "  - {:page_break} for new pages", %{font_size: 12, color: :green}},
      {:spacer, 15},
      {:watermark, "SAMPLE", %{opacity: 0.06, font_size: 80}},
      {:page_break},
      {:text, "Page 2 - via {:page_break}", %{font_size: 18, bold: true, color: :navy}},
      {:spacer, 10},
      {:text, "The builder automatically processes each element in sequence.", %{color: :gray}}
    ]

    config = %{
      size: :a4,
      margin: %{top: 60, bottom: 60, left: 50, right: 50},
      font: "Helvetica",
      font_size: 12
    }

    Pdf.Builder.render(template, config)
  end

  defp table_simple do
    Pdf.new(size: :a4, margin: 50)
    |> Pdf.set_info(title: "Simple Table")
    |> Pdf.text("Simple Styled Table", %{font_size: 20, bold: true})
    |> Pdf.spacer(15)
    |> Pdf.styled_table([
      ["Product", "Category", "Price"],
      ["Elixir in Action", "Book", "$44.99"],
      ["Phoenix LiveView", "Book", "$39.99"],
      ["Nerves Project", "Hardware", "$89.00"],
      ["LiveBook Pro", "Software", "$29.00"]
    ], %{
      columns: [
        %{width: 200},
        %{width: 140, align: :center},
        %{width: 100, align: :right}
      ],
      header: %{bold: true, background: {0.15, 0.23, 0.38}, color: :white, padding: 10},
      row: %{padding: 8, border_bottom: 0.5, border_color: {0.85, 0.85, 0.85}},
      border: 1,
      border_color: {0.15, 0.23, 0.38},
      border_radius: 8
    })
    |> Pdf.spacer(20)
    |> Pdf.text("Table with header, borders, and rounded corners.", %{font_size: 10, color: :gray})
  end

  defp table_zebra do
    Pdf.new(size: :a4, margin: 50)
    |> Pdf.set_info(title: "Zebra Stripe Table")
    |> Pdf.text("Zebra Stripe Table", %{font_size: 20, bold: true})
    |> Pdf.spacer(15)
    |> Pdf.styled_table([
      ["#", "Employee", "Department", "Status"],
      ["1", "Alice Johnson", "Engineering", "Active"],
      ["2", "Bob Smith", "Marketing", "Active"],
      ["3", "Carol Williams", "Engineering", "On Leave"],
      ["4", "David Brown", "Sales", "Active"],
      ["5", "Eve Davis", "Engineering", "Active"],
      ["6", "Frank Miller", "Marketing", "Inactive"],
      ["7", "Grace Wilson", "Sales", "Active"],
      ["8", "Henry Taylor", "Engineering", "Active"]
    ], %{
      columns: [
        %{width: 40, align: :center},
        %{width: 170},
        %{width: 130, align: :center},
        %{width: 100, align: :center}
      ],
      header: %{bold: true, background: {0.2, 0.6, 0.4}, color: :white, padding: 10},
      row: %{padding: 8, border_bottom: 0.3, border_color: {0.9, 0.9, 0.9}},
      alt_row: %{background: {0.94, 0.98, 0.95}},
      border: 1.5,
      border_color: {0.2, 0.6, 0.4},
      border_radius: 8
    })
  end

  defp table_receipt do
    Pdf.new(size: [240, 500], margin: %{top: 30, bottom: 20, left: 15, right: 15})
    |> Pdf.set_info(title: "Receipt")
    |> Pdf.set_font("Helvetica", 12)
    |> Pdf.text_at({60, 470}, "COFFEE SHOP")
    |> Pdf.set_font("Helvetica", 8)
    |> Pdf.text_at({55, 455}, "123 Main Street")
    |> Pdf.text_at({60, 445}, "Tel: 555-0123")
    |> Pdf.set_cursor(430)
    |> Pdf.set_cursor_x(15)
    |> Pdf.horizontal_line(%{color: :black})
    |> Pdf.spacer(5)
    |> Pdf.styled_table([
      ["Item", "Qty", "Total"],
      ["Cappuccino", "2", "$9.00"],
      ["Croissant", "1", "$3.50"],
      ["Green Tea", "1", "$2.50"],
      ["Muffin", "2", "$7.00"]
    ], %{
      columns: [
        %{width: 110},
        %{width: 40, align: :center},
        %{width: 60, align: :right}
      ],
      header: %{bold: true, padding: {4, 4, 4, 4}, font_size: 8, border_bottom: 1, border_color: :black},
      row: %{padding: {3, 4, 3, 4}, font_size: 9},
      font_size: 9
    })
    |> Pdf.spacer(3)
    |> Pdf.horizontal_line(%{color: :black})
    |> Pdf.spacer(5)
    |> Pdf.styled_table([
      ["Subtotal", "", "$22.00"],
      ["Tax (8%)", "", "$1.76"],
      ["Total", "", "$23.76"]
    ], %{
      columns: [
        %{width: 110},
        %{width: 40},
        %{width: 60, align: :right}
      ],
      row: %{padding: {2, 4, 2, 4}, font_size: 9},
      font_size: 9
    })
    |> Pdf.spacer(10)
    |> then(fn doc ->
      y = Pdf.cursor(doc)
      doc
      |> Pdf.set_font("Helvetica", 8)
      |> Pdf.text_at({50, y}, "Thank you for your visit!")
    end)
  end

  defp table_invoice do
    Pdf.new(size: :a4, margin: %{top: 50, bottom: 50, left: 50, right: 50})
    |> Pdf.set_info(title: "Invoice")
    # Header
    |> Pdf.set_font("Helvetica", 28)
    |> Pdf.set_fill_color({0.15, 0.23, 0.38})
    |> Pdf.text_at({50, 780}, "INVOICE")
    |> Pdf.set_fill_color(:black)
    |> Pdf.set_font("Helvetica", 10)
    |> Pdf.text_at({400, 785}, "Invoice #: INV-2026-001")
    |> Pdf.text_at({400, 772}, "Date: April 1, 2026")
    |> Pdf.text_at({400, 759}, "Due: April 30, 2026")
    # From / To
    |> Pdf.set_font("Helvetica", 9)
    |> Pdf.set_fill_color(:gray)
    |> Pdf.text_at({50, 730}, "FROM")
    |> Pdf.text_at({300, 730}, "BILL TO", %{bold: true})
    |> Pdf.set_fill_color(:black)
    |> Pdf.set_font("Helvetica", 10)
    |> Pdf.text_at({50, 716}, "Acme Corp")
    |> Pdf.text_at({50, 703}, "456 Business Ave")
    |> Pdf.text_at({50, 690}, "contact@acme.com")
    |> Pdf.text_at({300, 716}, "Client Industries")
    |> Pdf.text_at({300, 703}, "789 Client Blvd")
    |> Pdf.text_at({300, 690}, "billing@client.com")
    # Line separator
    |> Pdf.save_state()
    |> Pdf.set_stroke_color({0.15, 0.23, 0.38})
    |> Pdf.set_line_width(2)
    |> Pdf.line({50, 675}, {545, 675})
    |> Pdf.stroke()
    |> Pdf.restore_state()
    # Items table
    |> Pdf.set_cursor(665)
    |> Pdf.set_cursor_x(50)
    |> Pdf.spacer(5)
    |> Pdf.styled_table([
      ["Description", "Hours", "Rate", "Amount"],
      ["Web Application Development", "40", "$120.00", "$4,800.00"],
      ["API Integration", "16", "$120.00", "$1,920.00"],
      ["Database Design", "8", "$135.00", "$1,080.00"],
      ["Code Review & QA", "12", "$100.00", "$1,200.00"],
      ["Documentation", "6", "$90.00", "$540.00"]
    ], %{
      columns: [
        %{width: 220},
        %{width: 60, align: :center},
        %{width: 90, align: :right},
        %{width: 125, align: :right}
      ],
      header: %{
        bold: true,
        background: {0.15, 0.23, 0.38},
        color: :white,
        padding: 10,
        font_size: 10
      },
      row: %{
        padding: 8,
        border_bottom: 0.5,
        border_color: {0.88, 0.88, 0.88},
        font_size: 10
      },
      alt_row: %{background: {0.96, 0.97, 1.0}},
      border: 1,
      border_color: {0.15, 0.23, 0.38},
      border_radius: 4
    })
    # Totals
    |> Pdf.spacer(15)
    |> Pdf.styled_table([
      ["Subtotal", "$9,540.00"],
      ["Tax (10%)", "$954.00"],
      ["Total Due", "$10,494.00"]
    ], %{
      columns: [
        %{width: 365, align: :right},
        %{width: 130, align: :right}
      ],
      row: %{padding: 6, font_size: 10, border_bottom: 0.3, border_color: {0.85, 0.85, 0.85}},
      font_size: 10
    })
    # Footer note
    |> Pdf.spacer(30)
    |> Pdf.set_font("Helvetica", 9)
    |> Pdf.set_fill_color(:gray)
    |> (fn doc ->
      pos = Pdf.cursor_xy(doc)
      doc
      |> Pdf.text_at({50, pos.y}, "Payment Terms: Net 30 days")
      |> Pdf.text_at({50, pos.y - 14}, "Please make checks payable to Acme Corp")
      |> Pdf.text_at({50, pos.y - 28}, "Thank you for your business!")
    end).()
    # Page 2: same invoice with debug grid
    |> Pdf.page_break()
    |> Pdf.debug_grid(%{area: :page, spacing: 10, color: {0.9, 0.9, 0.9}})
    |> Pdf.set_font("Helvetica", 28)
    |> Pdf.set_fill_color({0.15, 0.23, 0.38})
    |> Pdf.text_at({50, 780}, "INVOICE")
    |> Pdf.set_fill_color(:black)
    |> Pdf.set_font("Helvetica", 10)
    |> Pdf.text_at({400, 785}, "Invoice #: INV-2026-001")
    |> Pdf.text_at({400, 772}, "Date: April 1, 2026")
    |> Pdf.text_at({400, 759}, "Due: April 30, 2026")
    |> Pdf.set_font("Helvetica", 9)
    |> Pdf.set_fill_color(:gray)
    |> Pdf.text_at({50, 730}, "FROM")
    |> Pdf.text_at({300, 730}, "BILL TO")
    |> Pdf.set_fill_color(:black)
    |> Pdf.set_font("Helvetica", 10)
    |> Pdf.text_at({50, 716}, "Acme Corp")
    |> Pdf.text_at({50, 703}, "456 Business Ave")
    |> Pdf.text_at({50, 690}, "contact@acme.com")
    |> Pdf.text_at({300, 716}, "Client Industries")
    |> Pdf.text_at({300, 703}, "789 Client Blvd")
    |> Pdf.text_at({300, 690}, "billing@client.com")
    |> Pdf.save_state()
    |> Pdf.set_stroke_color({0.15, 0.23, 0.38})
    |> Pdf.set_line_width(2)
    |> Pdf.line({50, 675}, {545, 675})
    |> Pdf.stroke()
    |> Pdf.restore_state()
    |> Pdf.set_cursor(665)
    |> Pdf.set_cursor_x(50)
    |> Pdf.spacer(5)
    |> Pdf.styled_table([
      ["Description", "Hours", "Rate", "Amount"],
      ["Web Application Development", "40", "$120.00", "$4,800.00"],
      ["API Integration", "16", "$120.00", "$1,920.00"],
      ["Database Design", "8", "$135.00", "$1,080.00"],
      ["Code Review & QA", "12", "$100.00", "$1,200.00"],
      ["Documentation", "6", "$90.00", "$540.00"]
    ], %{
      columns: [
        %{width: 220},
        %{width: 60, align: :center},
        %{width: 90, align: :right},
        %{width: 125, align: :right}
      ],
      header: %{bold: true, background: {0.15, 0.23, 0.38}, color: :white, padding: 10, font_size: 10},
      row: %{padding: 8, border_bottom: 0.5, border_color: {0.88, 0.88, 0.88}, font_size: 10},
      alt_row: %{background: {0.96, 0.97, 1.0}},
      border: 1,
      border_color: {0.15, 0.23, 0.38},
      border_radius: 4
    })
    |> Pdf.spacer(15)
    |> Pdf.styled_table([
      ["Subtotal", "$9,540.00"],
      ["Tax (10%)", "$954.00"],
      ["Total Due", "$10,494.00"]
    ], %{
      columns: [
        %{width: 365, align: :right},
        %{width: 130, align: :right}
      ],
      row: %{padding: 6, font_size: 10, border_bottom: 0.3, border_color: {0.85, 0.85, 0.85}},
      font_size: 10
    })
    |> Pdf.spacer(30)
    |> Pdf.set_font("Helvetica", 9)
    |> Pdf.set_fill_color(:gray)
    |> (fn doc ->
      pos = Pdf.cursor_xy(doc)
      doc
      |> Pdf.text_at({50, pos.y}, "Payment Terms: Net 30 days")
      |> Pdf.text_at({50, pos.y - 14}, "Please make checks payable to Acme Corp")
      |> Pdf.text_at({50, pos.y - 28}, "Thank you for your business!")
    end).()
     # Page 3: same invoice with debug grid
    |> Pdf.page_break()
    |> Pdf.debug_grid(%{area: :content, spacing: 10, color: {0.9, 0.9, 0.9}})
    |> Pdf.set_font("Helvetica", 28)
    |> Pdf.set_fill_color({0.15, 0.23, 0.38})
    |> Pdf.text_at({50, 780}, "INVOICE")
    |> Pdf.set_fill_color(:black)
    |> Pdf.set_font("Helvetica", 10)
    |> Pdf.text_at({400, 785}, "Invoice #: INV-2026-001")
    |> Pdf.text_at({400, 772}, "Date: April 1, 2026")
    |> Pdf.text_at({400, 759}, "Due: April 30, 2026")
    |> Pdf.set_font("Helvetica", 9)
    |> Pdf.set_fill_color(:gray)
    |> Pdf.text_at({50, 730}, "FROM")
    |> Pdf.text_at({300, 730}, "BILL TO")
    |> Pdf.set_fill_color(:black)
    |> Pdf.set_font("Helvetica", 10)
    |> Pdf.text_at({50, 716}, "Acme Corp")
    |> Pdf.text_at({50, 703}, "456 Business Ave")
    |> Pdf.text_at({50, 690}, "contact@acme.com")
    |> Pdf.text_at({300, 716}, "Client Industries")
    |> Pdf.text_at({300, 703}, "789 Client Blvd")
    |> Pdf.text_at({300, 690}, "billing@client.com")
    |> Pdf.save_state()
    |> Pdf.set_stroke_color({0.15, 0.23, 0.38})
    |> Pdf.set_line_width(2)
    |> Pdf.line({50, 675}, {545, 675})
    |> Pdf.stroke()
    |> Pdf.restore_state()
    |> Pdf.set_cursor(665)
    |> Pdf.set_cursor_x(50)
    |> Pdf.spacer(5)
    |> Pdf.styled_table([
      ["Description", "Hours", "Rate", "Amount"],
      ["Web Application Development", "40", "$120.00", "$4,800.00"],
      ["API Integration", "16", "$120.00", "$1,920.00"],
      ["Database Design", "8", "$135.00", "$1,080.00"],
      ["Code Review & QA", "12", "$100.00", "$1,200.00"],
      ["Documentation", "6", "$90.00", "$540.00"]
    ], %{
      columns: [
        %{width: 220},
        %{width: 60, align: :center},
        %{width: 90, align: :right},
        %{width: 125, align: :right}
      ],
      header: %{bold: true, background: {0.15, 0.23, 0.38}, color: :white, padding: 10, font_size: 10},
      row: %{padding: 8, border_bottom: 0.5, border_color: {0.88, 0.88, 0.88}, font_size: 10},
      alt_row: %{background: {0.96, 0.97, 1.0}},
      border: 1,
      border_color: {0.15, 0.23, 0.38},
      border_radius: 4
    })
    |> Pdf.spacer(15)
    |> Pdf.styled_table([
      ["Subtotal", "$9,540.00"],
      ["Tax (10%)", "$954.00"],
      ["Total Due", "$10,494.00"]
    ], %{
      columns: [
        %{width: 365, align: :right},
        %{width: 130, align: :right}
      ],
      row: %{padding: 6, font_size: 10, border_bottom: 0.3, border_color: {0.85, 0.85, 0.85}},
      font_size: 10
    })
    |> Pdf.spacer(30)
    |> Pdf.set_font("Helvetica", 9)
    |> Pdf.set_fill_color(:gray)
    |> (fn doc ->
      pos = Pdf.cursor_xy(doc)
      doc
      |> Pdf.text_at({50, pos.y}, "Payment Terms: Net 30 days")
      |> Pdf.text_at({50, pos.y - 14}, "Please make checks payable to Acme Corp")
      |> Pdf.text_at({50, pos.y - 28}, "Thank you for your business!")
    end).()
  end

  defp cfdi_maps do
    # Colors
    dark = {0.2, 0.2, 0.2}
    orange = {0.9, 0.55, 0.0}
    header_bg = {0.95, 0.95, 0.95}
    border_c = {0.4, 0.4, 0.4}
    light_border = {0.7, 0.7, 0.7}

    # Reusable text styles
    company = %{font_size: 9, bold: true, color: dark}
    company_sm = %{font_size: 8, bold: true, color: dark}
    lbl = %{font_size: 9, italic: true, color: dark}
    val = %{font_size: 9, bold: true, color: dark}
    seal_font = %{font: "Courier", font_size: 5, color: {0.3, 0.3, 0.3}}
    seal_label = %{font_size: 7, bold: true, color: dark}
    cert_font = %{font_size: 7, color: dark}
    cert_bold = %{font_size: 7, bold: true, color: dark}
    pay = %{font_size: 8, color: dark}
    pay_b = %{font_size: 8, bold: true, color: dark}

    # Layout constants
    x0 = 30
    pw = 535
    x1 = x0 + pw
    cx = x0 + 120
    fx = x1 - 140
    yt = 652
    col_w = [55, 65, 195, 45, 60, 60, 55]
    rh = 70
    yrs = yt - 14
    y_tot = yrs - 4 * rh
    tx = x0 + pw * 0.65
    tw = pw * 0.35
    yp = y_tot - 55
    ycc = yp - 45
    cm = x0 + pw / 2
    hw = pw / 2
    ys = ycc - 62
    sx = x0 + 95

    config = %{
      size: :a4,
      margin: %{top: 30, bottom: 30, left: 30, right: 30},
      font: "Helvetica",
      font_size: 9
    }

    rows = [
      {"1", "86121601", ["Mensualidad - octubre", "ALUMNO: PUBLICO GENERAL", "CURP: MACA961017HQRRHM06", "NIVEL EDUCATIVO: PRIMARIA", "CLAVE: C1", "RFC: MODC980924HK1"], "E48", "$232.26", "$232.26", "$232.26"},
      {"1", "86121601", ["Mensualidad - noviembre", "ALUMNO: PUBLICO GENERAL", "CURP: MACA961017HQRRHM06", "NIVEL EDUCATIVO: PRIMARIA", "CLAVE: C1", "RFC: MODC980924HK1"], "E48", "$232.26", "$0.00", "$232.26"},
      {"1", "86121601", ["Mensualidad - diciembre", "ALUMNO: PUBLICO GENERAL", "CURP: MACA961017HQRRHM06", "NIVEL EDUCATIVO: PRIMARIA", "CLAVE: C1", "RFC: MODC980924HK1"], "E48", "$255.49", "$0.00", "$255.49"},
      {"1", "86121601", ["Mensualidad - enero", "ALUMNO: PUBLICO GENERAL", "CURP: MACA961017HQRRHM06", "NIVEL EDUCATIVO: PRIMARIA", "CLAVE: C1", "RFC: MODC980924HK1"], "E48", "$232.26", "$0.00", "$232.26"}
    ]

    cell = %{font_size: 8, color: dark}
    hdr = %{font_size: 7, bold: true, color: dark}
    col_xs = Enum.scan([x0 | col_w], &(&1 + &2)) |> List.insert_at(0, x0)

    template = [
      # ── Outer border ──
      %{rect: {x0, 30}, size: {pw, 782}, stroke: dark, line_width: 1.5},

      # ── Logo placeholder ──
      %{rect: {x0 + 10, 745}, size: {100, 60}, stroke: orange, line_width: 2},
      %{text: "signati", font_size: 14, bold: true, color: orange, x: x0 + 30, y: 770},

      # ── Company info ──
      Map.merge(company, %{text: "MARIA WATEMBER TORRES", x: cx, y: 800}),
      Map.merge(company, %{text: "R.F.C: WATM640917J45", x: cx, y: 789}),
      Map.merge(company, %{text: "REGIMEN: 612 - PERSONAS FISICAS CON", x: cx, y: 778}),
      Map.merge(company, %{text: "ACTIVIDADES EMPRESARIALES Y", x: cx, y: 767}),
      Map.merge(company, %{text: "PROFESIONALES", x: cx, y: 756}),
      Map.merge(company_sm, %{text: "LUGAR DE EXPEDICION: CONSTITUYENTES y 115", x: cx, y: 743}),
      Map.merge(company_sm, %{text: "AV MZA.25 LT.2 Y 3, EJIDO NORTE, 77714 PLAYA", x: cx, y: 733}),
      Map.merge(company_sm, %{text: "DEL CARMEN, Q.R.", x: cx, y: 723}),

      # ── FACTURA box (right side) ──
      %{rect: {fx, 795}, size: {130, 16}, fill: header_bg, stroke: border_c},
      %{rect: {fx, 779}, size: {130, 16}, fill: header_bg, stroke: border_c},
      %{rect: {fx, 763}, size: {130, 16}, stroke: border_c},
      %{rect: {fx, 747}, size: {130, 16}, fill: header_bg, stroke: border_c},
      %{rect: {fx, 731}, size: {130, 16}, stroke: orange, line_width: 1},
      %{text: "FACTURA", font_size: 10, bold: true, color: dark, x: fx + 40, y: 799},
      %{text: "FOLIO", font_size: 8, color: dark, x: fx + 50, y: 783},
      %{text: "A - MYLF-24", font_size: 9, bold: true, color: orange, x: fx + 25, y: 767},
      %{text: "FECHA", font_size: 8, color: dark, x: fx + 50, y: 751},
      %{text: "2022-05-07T04:33:52", font_size: 8, bold: true, color: orange, x: fx + 10, y: 735},

      # ── DATOS DEL CLIENTE ──
      %{line_from: {x0, 713}, line_to: {x1, 713}, stroke: light_border},
      %{text: "Datos del Cliente", font_size: 10, italic: true, color: orange, x: x0 + 5, y: 703},
      Map.merge(lbl, %{text: "Razon Social: ", x: x0 + 5, y: 690}),
      Map.merge(val, %{text: "CALEB ISAAC MORA DIAZ", x: x0 + 75, y: 690}),
      Map.merge(lbl, %{text: "R.F.C.: ", x: x0 + 5, y: 678}),
      Map.merge(val, %{text: "MODC980924HK1", x: x0 + 42, y: 678}),
      Map.merge(lbl, %{text: "Uso CFDI: ", x: x0 + 5, y: 666}),
      Map.merge(val, %{text: "G03", x: x0 + 52, y: 666}),

      # ── ITEMS TABLE header ──
      %{rect: {x0, yt - 14}, size: {pw, 16}, fill: header_bg, stroke: border_c},
      Enum.zip(["CANTIDAD", "CLAVE SAT", "CONCEPTO/DESCRIPCION", "UNIDAD", "P.UNITARIO", "DESCUENTO", "IMPORTE"], col_xs)
      |> Enum.map(fn {h, cxx} -> Map.merge(hdr, %{text: h, x: cxx + 3, y: yt - 10}) end),

      # ── Table rows ──
      Enum.with_index(rows) |> Enum.flat_map(fn {{cant, clave, descs, unidad, precio, desc, importe}, idx} ->
        ry = yrs - (idx + 1) * rh
        ty = ry + rh - 12
        [
          %{rect: {x0, ry}, size: {pw, rh}, stroke: light_border, line_width: 0.3},
          Map.merge(cell, %{text: cant, x: Enum.at(col_xs, 0) + 20, y: ty}),
          Map.merge(cell, %{text: clave, x: Enum.at(col_xs, 1) + 5, y: ty}),
          Enum.with_index(descs) |> Enum.map(fn {line, li} ->
            s = if(li == 0, do: %{bold: true}, else: %{})
            Map.merge(cell, Map.merge(s, %{text: line, x: Enum.at(col_xs, 2) + 3, y: ty - li * 10}))
          end),
          Map.merge(cell, %{text: unidad, x: Enum.at(col_xs, 3) + 10, y: ty}),
          Map.merge(cell, %{text: precio, x: Enum.at(col_xs, 4) + 5, y: ty}),
          Map.merge(cell, %{text: desc, x: Enum.at(col_xs, 5) + 10, y: ty}),
          Map.merge(cell, %{text: importe, x: Enum.at(col_xs, 6) + 5, y: ty})
        ]
      end),

      # ── TOTALS ──
      %{rect: {x0, y_tot - 30}, size: {pw * 0.65, 30}, stroke: border_c},
      %{text: "CANTIDAD CON LETRA", font_size: 8, bold: true, color: dark, x: x0 + 5, y: y_tot - 10},
      %{text: "SETECIENTOS VEINTE PESOS 01/100 M.N", font_size: 8, color: dark, x: x0 + 5, y: y_tot - 22},
      Enum.with_index([{"SUBTOTAL:", "$952.27"}, {"DESCUENTO:", "$232.26"}, {"IMPUESTOS:", "$"}, {"TOTAL:", "$720.01"}])
      |> Enum.flat_map(fn {{l, v}, i} ->
        ty = y_tot - 2 - i * 11
        is_t = i == 3
        c = if(is_t, do: orange, else: dark)
        highlight = if(is_t, do: [%{rect: {tx, ty - 4}, size: {tw, 13}, fill: {1.0, 0.97, 0.9}}], else: [])
        highlight ++ [
          %{text: l, font_size: 8, bold: is_t, color: c, x: tx + 5, y: ty},
          %{text: v, font_size: 8, bold: is_t, color: c, x: tx + tw - 55, y: ty}
        ]
      end),

      # ── PAYMENT INFO ──
      %{line_from: {x0, yp + 8}, line_to: {x1, yp + 8}, stroke: light_border, line_width: 0.3},
      Map.merge(pay, %{text: "Forma de pago: ", x: x0 + 5, y: yp - 5}),
      Map.merge(pay_b, %{text: "01 - Efectivo", x: x0 + 80, y: yp - 5}),
      Map.merge(pay, %{text: "Moneda: ", x: x0 + 270, y: yp - 5}),
      Map.merge(pay_b, %{text: "MXN", x: x0 + 310, y: yp - 5}),
      Map.merge(pay, %{text: "Metodo de pago: ", x: x0 + 5, y: yp - 16}),
      Map.merge(pay_b, %{text: "PUE - Pago en una sola exhibicion", x: x0 + 85, y: yp - 16}),
      Map.merge(pay, %{text: "Tipo de comprobante: ", x: x0 + 270, y: yp - 16}),
      Map.merge(pay_b, %{text: "I - Ingreso", x: x0 + 375, y: yp - 16}),
      Map.merge(pay, %{text: "No. de cuenta:", x: x0 + 5, y: yp - 27}),

      # ── CERTIFICATION ──
      %{rect: {x0, ycc}, size: {hw, 14}, fill: header_bg, stroke: border_c},
      %{rect: {cm, ycc}, size: {hw, 14}, fill: header_bg, stroke: border_c},
      %{rect: {x0, ycc - 14}, size: {hw, 14}, stroke: border_c},
      %{rect: {cm, ycc - 14}, size: {hw, 14}, stroke: border_c},
      %{rect: {x0, ycc - 28}, size: {hw, 14}, fill: header_bg, stroke: border_c},
      %{rect: {cm, ycc - 28}, size: {hw, 14}, fill: header_bg, stroke: border_c},
      %{rect: {x0, ycc - 42}, size: {hw, 14}, stroke: border_c},
      %{rect: {cm, ycc - 42}, size: {hw, 14}, stroke: border_c},
      Map.merge(cert_bold, %{text: "No. CSD del Emisor", x: x0 + 50, y: ycc + 3}),
      Map.merge(cert_bold, %{text: "Fecha y hora de certificacion", x: cm + 30, y: ycc + 3}),
      Map.merge(cert_font, %{text: "30001000000400002333", x: x0 + 20, y: ycc - 11}),
      Map.merge(cert_font, %{text: "2022-05-07T16:32:00", x: cm + 40, y: ycc - 11}),
      Map.merge(cert_bold, %{text: "Folio Fiscal", x: x0 + 60, y: ycc - 25}),
      Map.merge(cert_bold, %{text: "No. CSD del SAT", x: cm + 50, y: ycc - 25}),
      %{text: "6CE88083-E455-458D-BE8D-2A292BC6DEEE", font: "Courier", font_size: 6, color: dark, x: x0 + 5, y: ycc - 39},
      %{text: "30001000000400002495", font: "Courier", font_size: 6, color: dark, x: cm + 15, y: ycc - 39},

      # ── DIGITAL SEALS ──
      %{line_from: {x0, ys + 5}, line_to: {x1, ys + 5}, stroke: light_border, line_width: 0.3},
      %{rect: {x0 + 5, ys - 95}, size: {80, 80}, stroke: border_c},
      %{text: "[QR Code]", font_size: 7, color: :gray, x: x0 + 25, y: ys - 55},
      Map.merge(seal_label, %{text: "SELLO DIGITAL DEL EMISOR", x: sx, y: ys - 5}),
      Map.merge(seal_font, %{text: "gieMqNUlmQPBElJY3bmZHyFU3mtUh+Qk5V2yUBRa83y/AmcBnwrtDo9hb9qLY...", x: sx + 10, y: ys - 14}),
      Map.merge(seal_label, %{text: "SELLO DEL SAT", x: sx, y: ys - 30}),
      Map.merge(seal_font, %{text: "pXWM0nAQ8+d31f/SVRqZwfb6XHQOndGQyNQ8hqySoqRevKZ/6bp5NN...", x: sx + 10, y: ys - 39}),
      Map.merge(seal_label, %{text: "CADENA ORIGINAL DEL COMPLEMENTO DE CERTIFICACION DIGITAL DEL SAT", x: sx, y: ys - 55}),
      Map.merge(seal_font, %{text: "||1.1|6ce88b0b3-e455-458d-be8d-2a292bc6deee|2022-05-07T16:32:00|SPR190631i3S2...", x: sx + 10, y: ys - 64}),

      # ── Footer ──
      %{line_from: {x0, 42}, line_to: {x1, 42}, stroke: light_border, line_width: 0.3},
      %{text: "by Signati", font_size: 7, color: :gray, x: x0 + 30, y: 34}
    ]

    Pdf.Builder.render(template, config)
  end

  defp rv_maps do
    # Colors
    dark = {0.1, 0.1, 0.1}
    teal = {0.0, 0.65, 0.63}
    gray = {0.5, 0.5, 0.5}
    light_border = {0.82, 0.82, 0.82}

    # Reusable text styles
    title_s = %{font_size: 22, bold: true, color: dark}
    brand_s = %{font_size: 20, bold: true, color: teal}
    heading = %{font_size: 16, bold: true, color: dark}
    normal = %{font_size: 9, color: dark}
    normal10 = %{font_size: 10, color: dark}
    bold10 = %{font_size: 10, bold: true, color: dark}
    small_gray = %{font_size: 8, color: gray}
    info_bold = %{font_size: 10, bold: true, color: dark}
    info_gray = %{font_size: 9, color: gray}

    # Layout constants
    x0 = 50
    pw = 495
    x1 = x0 + pw
    lw = 230
    rx = x0 + lw + 15
    rw = pw - lw - 15
    by = 750
    py = 750
    d1y = py - 90
    d2y = d1y - 52
    pay_y = py - 170 - 15
    ay = pay_y - 65
    ix = x0 + 95

    config = %{
      size: :a4,
      margin: %{top: 0, bottom: 0, left: 0, right: 0},
      font: "Helvetica",
      font_size: 10
    }

    details = [
      {"Reservation ID:", "38111"},
      {"Site Location:", "Spot: 059"},
      {"Check-in:", "June 7, 2026"},
      {"Check-out:", "June 10, 2026"},
      {"Guest:", "2 adults, 1 pet"},
      {"RV Profile:", "Fifth Wheel, 45 feet"}
    ]

    prices = [{"3rd Party Calculated Tax", "$16.61"}, {"Klamath Falls RV Resort ($60.50 x 3)", "$181.49"}]
    subs = [{"Subtotal", "$198.10"}, {"Service Fee", "$17.48"}]

    template = [
      # ── Background ──
      %{rect: {0, 0}, size: {595, 842}, fill: {0.97, 0.97, 0.97}},
      %{rect: {x0 - 15, 40}, size: {pw + 30, 770}, fill: {1.0, 1.0, 1.0}},

      # ── Title row ──
      Map.merge(title_s, %{text: "Your receipt from Spot2Nite", x: x0, y: 785}),
      Map.merge(brand_s, %{text: "SPOT2NITE", x: x1 - 115, y: 785}),

      # ── Left box border + image placeholder ──
      %{rect: {x0, by - 260}, size: {lw, 260}, stroke: light_border, line_width: 0.8},
      %{rect: {x0 + 8, by - 75}, size: {80, 65}, fill: {0.88, 0.91, 0.88}},
      %{text: "[Photo]", font_size: 6, color: gray, x: x0 + 25, y: by - 45},

      # ── Resort info ──
      Map.merge(info_bold, %{text: "Klamath Falls RV Resort", x: ix, y: by - 18}),
      Map.merge(info_gray, %{text: "Klamath Falls", x: ix, y: by - 30}),
      Map.merge(info_gray, %{text: "(541) 414-6657", x: ix, y: by - 41}),
      Map.merge(info_gray, %{text: "Klamath@rjourney.com", x: ix, y: by - 52}),

      # ── Reservation details ──
      Enum.with_index(details) |> Enum.flat_map(fn {{l, v}, i} ->
        ly = by - 95 - i * 22
        [
          Map.merge(bold10, %{text: l, x: x0 + 10, y: ly}),
          Map.merge(normal10, %{text: v, x: x0 + lw - 10 - estimate_width(v, 10), y: ly})
        ]
      end),

      # ── Price breakdown box ──
      %{rect: {rx, py - 170}, size: {rw, 170}, stroke: light_border, line_width: 0.8},
      Map.merge(heading, %{text: "Price breakdown", x: rx + 12, y: py - 22}),

      # Price items
      Enum.with_index(prices) |> Enum.flat_map(fn {{l, v}, i} ->
        y = py - 48 - i * 18
        [
          Map.merge(normal, %{text: l, x: rx + 12, y: y}),
          Map.merge(normal, %{text: v, x: rx + rw - 12 - estimate_width(v, 9), y: y})
        ]
      end),

      # Divider
      %{line_from: {rx + 10, d1y}, line_to: {rx + rw - 10, d1y}, stroke: light_border},

      # Subtotal / Service Fee
      Enum.with_index(subs) |> Enum.flat_map(fn {{l, v}, i} ->
        y = d1y - 16 - i * 16
        [
          Map.merge(normal, %{text: l, x: rx + 12, y: y}),
          Map.merge(normal, %{text: v, x: rx + rw - 12 - estimate_width(v, 9), y: y})
        ]
      end),

      # Divider + Total
      %{line_from: {rx + 10, d2y}, line_to: {rx + rw - 10, d2y}, stroke: light_border},
      Map.merge(bold10, %{text: "Total (USD)", x: rx + 12, y: d2y - 16}),
      Map.merge(bold10, %{text: "$215.58", x: rx + rw - 12 - estimate_width("$215.58", 10), y: d2y - 16}),

      # ── Payment box ──
      %{rect: {rx, pay_y - 95}, size: {rw, 95}, stroke: light_border, line_width: 0.8},
      Map.merge(heading, %{text: "Payment", x: rx + 12, y: pay_y - 22}),
      Map.merge(normal10, %{text: "VISA... 2060", x: rx + 12, y: pay_y - 44}),
      Map.merge(bold10, %{text: "$215.58", x: rx + rw - 12 - estimate_width("$215.58", 10), y: pay_y - 44}),
      Map.merge(small_gray, %{text: "Mar 30, 2026 - 8:47:59 PM", x: rx + 12, y: pay_y - 56}),

      # Divider + Amount paid
      %{line_from: {rx + 10, ay}, line_to: {rx + rw - 10, ay}, stroke: light_border},
      Map.merge(bold10, %{text: "Amount paid (USD)", x: rx + 12, y: ay - 16}),
      Map.merge(bold10, %{text: "$215.58", x: rx + rw - 12 - estimate_width("$215.58", 10), y: ay - 16})
    ]

    Pdf.Builder.render(template, config)
  end

  defp rv_receipt do
    dark = {0.1, 0.1, 0.1}
    teal = {0.0, 0.65, 0.63}
    gray = {0.5, 0.5, 0.5}
    light_border = {0.82, 0.82, 0.82}
    bg_white = {1.0, 1.0, 1.0}

    doc = Pdf.new(size: :a4, margin: %{top: 40, bottom: 40, left: 50, right: 50})
    |> Pdf.set_info(title: "RV Resort Receipt")

    x0 = 50
    page_w = 495
    x1 = x0 + page_w

    # ── Dark background bar at top ──
    doc = doc
    |> Pdf.save_state()
    |> Pdf.set_fill_color({0.97, 0.97, 0.97})
    |> Pdf.rectangle({0, 0}, {595, 842})
    |> Pdf.fill()
    |> Pdf.set_fill_color(bg_white)
    |> Pdf.rectangle({x0 - 15, 40}, {page_w + 30, 770})
    |> Pdf.fill()
    |> Pdf.restore_state()

    # ── Title ──
    doc = doc
    |> Pdf.set_font("Helvetica", 22)
    |> Pdf.set_fill_color(dark)
    |> Pdf.text_at({x0, 785}, "Your receipt from Spot2Nite", %{bold: true})

    # Brand name (right side)
    doc = doc
    |> Pdf.set_font("Helvetica", 20)
    |> Pdf.set_fill_color(teal)
    |> Pdf.text_at({x1 - 115, 785}, "SPOT2NITE", %{bold: true})

    # ── LEFT COLUMN: Resort info + Reservation details ──
    left_w = 230
    left_x = x0
    box_y = 750
    box_h = 260

    # Box border
    doc = doc
    |> Pdf.save_state()
    |> Pdf.set_stroke_color(light_border)
    |> Pdf.set_line_width(0.8)
    |> Pdf.rectangle({left_x, box_y - box_h}, {left_w, box_h})
    |> Pdf.stroke()
    |> Pdf.restore_state()

    # Image placeholder
    doc = doc
    |> Pdf.save_state()
    |> Pdf.set_fill_color({0.88, 0.91, 0.88})
    |> Pdf.rectangle({left_x + 8, box_y - 75}, {80, 65})
    |> Pdf.fill()
    |> Pdf.set_font("Helvetica", 6)
    |> Pdf.set_fill_color(gray)
    |> Pdf.text_at({left_x + 25, box_y - 45}, "[Photo]")
    |> Pdf.restore_state()

    # Resort info (next to image)
    info_x = left_x + 95
    doc = doc
    |> Pdf.set_font("Helvetica", 10)
    |> Pdf.set_fill_color(dark)
    |> Pdf.text_at({info_x, box_y - 18}, "Klamath Falls RV Resort", %{bold: true})
    |> Pdf.set_font("Helvetica", 9)
    |> Pdf.set_fill_color(gray)
    |> Pdf.text_at({info_x, box_y - 30}, "Klamath Falls")
    |> Pdf.text_at({info_x, box_y - 41}, "(541) 414-6657")
    |> Pdf.text_at({info_x, box_y - 52}, "Klamath@rjourney.com")

    # Reservation details
    detail_y = box_y - 95
    details = [
      {"Reservation ID:", "38111"},
      {"Site Location:", "Spot: 059"},
      {"Check-in:", "June 7, 2026"},
      {"Check-out:", "June 10, 2026"},
      {"Guest:", "2 adults, 1 pet"},
      {"RV Profile:", "Fifth Wheel, 45 feet"}
    ]

    doc = Enum.with_index(details) |> Enum.reduce(doc, fn {{label, value}, i}, d ->
      ly = detail_y - i * 22
      d
      |> Pdf.set_font("Helvetica", 10)
      |> Pdf.set_fill_color(dark)
      |> Pdf.text_at({left_x + 10, ly}, label, %{bold: true})
      |> Pdf.set_fill_color(dark)
      |> Pdf.text_at({left_x + left_w - 10 - estimate_width(value, 10), ly}, value)
    end)

    # ── RIGHT COLUMN: Price breakdown + Payment ──
    right_x = left_x + left_w + 15
    right_w = page_w - left_w - 15

    # ── Price breakdown box ──
    price_y = 750
    price_h = 170

    doc = doc
    |> Pdf.save_state()
    |> Pdf.set_stroke_color(light_border)
    |> Pdf.set_line_width(0.8)
    |> Pdf.rectangle({right_x, price_y - price_h}, {right_w, price_h})
    |> Pdf.stroke()
    |> Pdf.restore_state()

    # Price breakdown title
    doc = doc
    |> Pdf.set_font("Helvetica", 16)
    |> Pdf.set_fill_color(dark)
    |> Pdf.text_at({right_x + 12, price_y - 22}, "Price breakdown", %{bold: true})

    # Price items
    price_items = [
      {"3rd Party Calculated Tax", "$16.61"},
      {"Klamath Falls RV Resort ($60.50 x 3)", "$181.49"}
    ]

    doc = Enum.with_index(price_items) |> Enum.reduce(doc, fn {{label, value}, i}, d ->
      py = price_y - 48 - i * 18
      d
      |> Pdf.set_font("Helvetica", 9)
      |> Pdf.set_fill_color(dark)
      |> Pdf.text_at({right_x + 12, py}, label)
      |> Pdf.text_at({right_x + right_w - 12 - estimate_width(value, 9), py}, value)
    end)

    # Divider line
    div_y = price_y - 90
    doc = doc
    |> Pdf.save_state()
    |> Pdf.set_stroke_color(light_border)
    |> Pdf.set_line_width(0.5)
    |> Pdf.line({right_x + 10, div_y}, {right_x + right_w - 10, div_y})
    |> Pdf.stroke()
    |> Pdf.restore_state()

    # Subtotal / Service Fee
    sub_items = [
      {"Subtotal", "$198.10"},
      {"Service Fee", "$17.48"}
    ]

    doc = Enum.with_index(sub_items) |> Enum.reduce(doc, fn {{label, value}, i}, d ->
      sy = div_y - 16 - i * 16
      d
      |> Pdf.set_font("Helvetica", 9)
      |> Pdf.set_fill_color(dark)
      |> Pdf.text_at({right_x + 12, sy}, label)
      |> Pdf.text_at({right_x + right_w - 12 - estimate_width(value, 9), sy}, value)
    end)

    # Divider before total
    div2_y = div_y - 52
    doc = doc
    |> Pdf.save_state()
    |> Pdf.set_stroke_color(light_border)
    |> Pdf.set_line_width(0.5)
    |> Pdf.line({right_x + 10, div2_y}, {right_x + right_w - 10, div2_y})
    |> Pdf.stroke()
    |> Pdf.restore_state()

    # Total
    doc = doc
    |> Pdf.set_font("Helvetica", 10)
    |> Pdf.set_fill_color(dark)
    |> Pdf.text_at({right_x + 12, div2_y - 16}, "Total (USD)", %{bold: true})
    |> Pdf.text_at({right_x + right_w - 12 - estimate_width("$215.58", 10), div2_y - 16}, "$215.58", %{bold: true})

    # ── Payment box ──
    pay_y = price_y - price_h - 15
    pay_h = 95

    doc = doc
    |> Pdf.save_state()
    |> Pdf.set_stroke_color(light_border)
    |> Pdf.set_line_width(0.8)
    |> Pdf.rectangle({right_x, pay_y - pay_h}, {right_w, pay_h})
    |> Pdf.stroke()
    |> Pdf.restore_state()

    # Payment title
    doc = doc
    |> Pdf.set_font("Helvetica", 16)
    |> Pdf.set_fill_color(dark)
    |> Pdf.text_at({right_x + 12, pay_y - 22}, "Payment", %{bold: true})

    # VISA line
    doc = doc
    |> Pdf.set_font("Helvetica", 10)
    |> Pdf.set_fill_color(dark)
    |> Pdf.text_at({right_x + 12, pay_y - 44}, "VISA... 2060")
    |> Pdf.text_at({right_x + right_w - 12 - estimate_width("$215.58", 10), pay_y - 44}, "$215.58", %{bold: true})
    |> Pdf.set_font("Helvetica", 8)
    |> Pdf.set_fill_color(gray)
    |> Pdf.text_at({right_x + 12, pay_y - 56}, "Mar 30, 2026 - 8:47:59 PM")

    # Divider before amount paid
    apd_y = pay_y - 65
    doc = doc
    |> Pdf.save_state()
    |> Pdf.set_stroke_color(light_border)
    |> Pdf.set_line_width(0.5)
    |> Pdf.line({right_x + 10, apd_y}, {right_x + right_w - 10, apd_y})
    |> Pdf.stroke()
    |> Pdf.restore_state()

    # Amount paid
    doc
    |> Pdf.set_font("Helvetica", 10)
    |> Pdf.set_fill_color(dark)
    |> Pdf.text_at({right_x + 12, apd_y - 16}, "Amount paid (USD)", %{bold: true})
    |> Pdf.text_at({right_x + right_w - 12 - estimate_width("$215.58", 10), apd_y - 16}, "$215.58", %{bold: true})
  end

  defp estimate_width(text, font_size) do
    String.length(text) * font_size * 0.52
  end

  defp cfdi_invoice do
    # Colors
    dark = {0.2, 0.2, 0.2}
    orange = {0.9, 0.55, 0.0}
    header_bg = {0.95, 0.95, 0.95}
    border_c = {0.4, 0.4, 0.4}
    light_border = {0.7, 0.7, 0.7}

    # Page setup
    doc = Pdf.new(size: :a4, margin: %{top: 30, bottom: 30, left: 30, right: 30})
    |> Pdf.set_info(title: "Factura CFDI")

    page_w = 535
    x0 = 30
    x1 = x0 + page_w

    # ── Outer border ──
    doc = doc
    |> Pdf.save_state()
    |> Pdf.set_stroke_color(dark)
    |> Pdf.set_line_width(1.5)
    |> Pdf.rectangle({x0, 30}, {page_w, 782})
    |> Pdf.stroke()
    |> Pdf.restore_state()

    # ── HEADER SECTION (y ~812 down to ~720) ──
    # Logo placeholder (circle + text)
    doc = doc
    |> Pdf.save_state()
    |> Pdf.set_stroke_color(orange)
    |> Pdf.set_line_width(2)
    |> Pdf.set_fill_color({1.0, 1.0, 1.0})
    # Logo box area
    |> Pdf.rectangle({x0 + 10, 745}, {100, 60})
    |> Pdf.stroke()
    |> Pdf.set_font("Helvetica", 14)
    |> Pdf.set_fill_color(orange)
    |> Pdf.text_at({x0 + 30, 770}, "signati")
    |> Pdf.restore_state()

    # Company info
    doc = doc
    |> Pdf.set_font("Helvetica", 9)
    |> Pdf.set_fill_color(dark)
    |> Pdf.text_at({x0 + 120, 800}, "MARIA WATEMBER TORRES", %{bold: true})
    |> Pdf.text_at({x0 + 120, 789}, "R.F.C: WATM640917J45", %{bold: true})
    |> Pdf.text_at({x0 + 120, 778}, "REGIMEN: 612 - PERSONAS FISICAS CON", %{bold: true})
    |> Pdf.text_at({x0 + 120, 767}, "ACTIVIDADES EMPRESARIALES Y", %{bold: true})
    |> Pdf.text_at({x0 + 120, 756}, "PROFESIONALES", %{bold: true})
    |> Pdf.set_font("Helvetica", 8)
    |> Pdf.text_at({x0 + 120, 743}, "LUGAR DE EXPEDICION: CONSTITUYENTES y 115", %{bold: true})
    |> Pdf.text_at({x0 + 120, 733}, "AV MZA.25 LT.2 Y 3, EJIDO NORTE, 77714 PLAYA", %{bold: true})
    |> Pdf.text_at({x0 + 120, 723}, "DEL CARMEN, Q.R.", %{bold: true})

    # FACTURA box (right side)
    factura_x = x1 - 140
    doc = doc
    |> Pdf.save_state()
    # "FACTURA" header
    |> Pdf.set_fill_color(header_bg)
    |> Pdf.rectangle({factura_x, 795}, {130, 16})
    |> Pdf.fill()
    |> Pdf.set_stroke_color(border_c)
    |> Pdf.set_line_width(0.5)
    |> Pdf.rectangle({factura_x, 795}, {130, 16})
    |> Pdf.stroke()
    |> Pdf.set_font("Helvetica", 10)
    |> Pdf.set_fill_color(dark)
    |> Pdf.text_at({factura_x + 40, 799}, "FACTURA", %{bold: true})
    # "FOLIO" row
    |> Pdf.set_fill_color(header_bg)
    |> Pdf.rectangle({factura_x, 779}, {130, 16})
    |> Pdf.fill()
    |> Pdf.set_stroke_color(border_c)
    |> Pdf.rectangle({factura_x, 779}, {130, 16})
    |> Pdf.stroke()
    |> Pdf.set_fill_color(dark)
    |> Pdf.set_font("Helvetica", 8)
    |> Pdf.text_at({factura_x + 50, 783}, "FOLIO")
    # Folio value
    |> Pdf.rectangle({factura_x, 763}, {130, 16})
    |> Pdf.stroke()
    |> Pdf.set_fill_color(orange)
    |> Pdf.set_font("Helvetica", 9)
    |> Pdf.text_at({factura_x + 25, 767}, "A - MYLF-24", %{bold: true})
    # "FECHA" row
    |> Pdf.set_fill_color(header_bg)
    |> Pdf.rectangle({factura_x, 747}, {130, 16})
    |> Pdf.fill()
    |> Pdf.set_stroke_color(border_c)
    |> Pdf.rectangle({factura_x, 747}, {130, 16})
    |> Pdf.stroke()
    |> Pdf.set_fill_color(dark)
    |> Pdf.set_font("Helvetica", 8)
    |> Pdf.text_at({factura_x + 50, 751}, "FECHA")
    # Fecha value
    |> Pdf.set_stroke_color(orange)
    |> Pdf.set_line_width(1)
    |> Pdf.rectangle({factura_x, 731}, {130, 16})
    |> Pdf.stroke()
    |> Pdf.set_fill_color(orange)
    |> Pdf.set_font("Helvetica", 8)
    |> Pdf.text_at({factura_x + 10, 735}, "2022-05-07T04:33:52", %{bold: true})
    |> Pdf.restore_state()

    # ── DATOS DEL CLIENTE ──
    y_client = 708
    doc = doc
    |> Pdf.save_state()
    |> Pdf.set_stroke_color(light_border)
    |> Pdf.set_line_width(0.5)
    |> Pdf.line({x0, y_client + 5}, {x1, y_client + 5})
    |> Pdf.stroke()
    |> Pdf.restore_state()
    |> Pdf.set_font("Helvetica", 10)
    |> Pdf.set_fill_color(orange)
    |> Pdf.text_at({x0 + 5, y_client - 5}, "Datos del Cliente", %{italic: true})
    |> Pdf.set_fill_color(dark)
    |> Pdf.set_font("Helvetica", 9)
    |> Pdf.text_at({x0 + 5, y_client - 18}, "Razon Social: ", %{italic: true})
    |> Pdf.text_at({x0 + 75, y_client - 18}, "CALEB ISAAC MORA DIAZ", %{bold: true})
    |> Pdf.text_at({x0 + 5, y_client - 30}, "R.F.C.: ", %{italic: true})
    |> Pdf.text_at({x0 + 42, y_client - 30}, "MODC980924HK1", %{bold: true})
    |> Pdf.text_at({x0 + 5, y_client - 42}, "Uso CFDI: ", %{italic: true})
    |> Pdf.text_at({x0 + 52, y_client - 42}, "G03", %{bold: true})

    # ── ITEMS TABLE ──
    y_table = 652
    col_w = [55, 65, 195, 45, 60, 60, 55]
    headers = ["CANTIDAD", "CLAVE SAT", "CONCEPTO/DESCRIPCION", "UNIDAD", "P.UNITARIO", "DESCUENTO", "IMPORTE"]

    # Table header background
    doc = doc
    |> Pdf.save_state()
    |> Pdf.set_fill_color(header_bg)
    |> Pdf.rectangle({x0, y_table - 14}, {page_w, 16})
    |> Pdf.fill()
    |> Pdf.set_stroke_color(border_c)
    |> Pdf.set_line_width(0.5)
    |> Pdf.rectangle({x0, y_table - 14}, {page_w, 16})
    |> Pdf.stroke()
    |> Pdf.restore_state()

    # Header text
    doc = doc
    |> Pdf.set_font("Helvetica", 7)
    |> Pdf.set_fill_color(dark)

    {doc, _} = Enum.reduce(Enum.zip(headers, col_w), {doc, x0}, fn {header, w}, {d, cx} ->
      d = Pdf.text_at(d, {cx + 3, y_table - 10}, header, %{bold: true})
      {d, cx + w}
    end)

    # Table rows data
    rows = [
      {"1", "86121601", [
        "Mensualidad - octubre",
        "ALUMNO: PUBLICO GENERAL",
        "CURP: MACA961017HQRRHM06",
        "NIVEL EDUCATIVO: PRIMARIA",
        "CLAVE: C1",
        "RFC: MODC980924HK1"
      ], "E48", "$232.26", "$232.26", "$232.26"},
      {"1", "86121601", [
        "Mensualidad - noviembre",
        "ALUMNO: PUBLICO GENERAL",
        "CURP: MACA961017HQRRHM06",
        "NIVEL EDUCATIVO: PRIMARIA",
        "CLAVE: C1",
        "RFC: MODC980924HK1"
      ], "E48", "$232.26", "$0.00", "$232.26"},
      {"1", "86121601", [
        "Mensualidad - diciembre",
        "ALUMNO: PUBLICO GENERAL",
        "CURP: MACA961017HQRRHM06",
        "NIVEL EDUCATIVO: PRIMARIA",
        "CLAVE: C1",
        "RFC: MODC980924HK1"
      ], "E48", "$255.49", "$0.00", "$255.49"},
      {"1", "86121601", [
        "Mensualidad - enero",
        "ALUMNO: PUBLICO GENERAL",
        "CURP: MACA961017HQRRHM06",
        "NIVEL EDUCATIVO: PRIMARIA",
        "CLAVE: C1",
        "RFC: MODC980924HK1"
      ], "E48", "$232.26", "$0.00", "$232.26"}
    ]

    row_height = 70
    y_row_start = y_table - 14

    doc = Enum.with_index(rows) |> Enum.reduce(doc, fn {{cant, clave, desc_lines, unidad, precio, desc, importe}, idx}, d ->
      ry = y_row_start - (idx + 1) * row_height

      # Row border
      d = d
      |> Pdf.save_state()
      |> Pdf.set_stroke_color(light_border)
      |> Pdf.set_line_width(0.3)
      |> Pdf.rectangle({x0, ry}, {page_w, row_height})
      |> Pdf.stroke()
      |> Pdf.restore_state()

      # Column values
      cx = x0
      d = d
      |> Pdf.set_font("Helvetica", 8)
      |> Pdf.set_fill_color(dark)
      |> Pdf.text_at({cx + 20, ry + row_height - 12}, cant)

      cx = cx + Enum.at(col_w, 0)
      d = Pdf.text_at(d, {cx + 5, ry + row_height - 12}, clave)

      cx = cx + Enum.at(col_w, 1)
      # Description lines
      d = Enum.with_index(desc_lines) |> Enum.reduce(d, fn {line, li}, dd ->
        font_opts = if li == 0, do: %{bold: true}, else: %{}
        Pdf.text_at(dd, {cx + 3, ry + row_height - 12 - li * 10}, line, font_opts)
      end)

      cx = cx + Enum.at(col_w, 2)
      d = Pdf.text_at(d, {cx + 10, ry + row_height - 12}, unidad)

      cx = cx + Enum.at(col_w, 3)
      d = Pdf.text_at(d, {cx + 5, ry + row_height - 12}, precio)

      cx = cx + Enum.at(col_w, 4)
      d = Pdf.text_at(d, {cx + 10, ry + row_height - 12}, desc)

      cx = cx + Enum.at(col_w, 5)
      d = Pdf.text_at(d, {cx + 5, ry + row_height - 12}, importe)

      d
    end)

    # ── TOTALS SECTION ──
    y_totals = y_row_start - length(rows) * row_height

    # Left: CANTIDAD CON LETRA
    doc = doc
    |> Pdf.save_state()
    |> Pdf.set_stroke_color(border_c)
    |> Pdf.set_line_width(0.5)
    |> Pdf.rectangle({x0, y_totals - 30}, {page_w * 0.65, 30})
    |> Pdf.stroke()
    |> Pdf.restore_state()
    |> Pdf.set_font("Helvetica", 8)
    |> Pdf.set_fill_color(dark)
    |> Pdf.text_at({x0 + 5, y_totals - 10}, "CANTIDAD CON LETRA", %{bold: true})
    |> Pdf.text_at({x0 + 5, y_totals - 22}, "SETECIENTOS VEINTE PESOS 01/100 M.N")

    # Right: Totals box
    totals_x = x0 + page_w * 0.65
    totals_w = page_w * 0.35
    totals_data = [
      {"SUBTOTAL:", "$952.27"},
      {"DESCUENTO:", "$232.26"},
      {"IMPUESTOS:", "$"},
      {"TOTAL:", "$720.01"}
    ]

    doc = Enum.with_index(totals_data) |> Enum.reduce(doc, fn {{label, value}, i}, d ->
      ty = y_totals - 2 - i * 11
      is_total = i == length(totals_data) - 1

      d = if is_total do
        d
        |> Pdf.save_state()
        |> Pdf.set_fill_color({1.0, 0.97, 0.9})
        |> Pdf.rectangle({totals_x, ty - 4}, {totals_w, 13})
        |> Pdf.fill()
        |> Pdf.restore_state()
      else
        d
      end

      d
      |> Pdf.set_font("Helvetica", 8)
      |> Pdf.set_fill_color(if(is_total, do: orange, else: dark))
      |> Pdf.text_at({totals_x + 5, ty}, label, %{bold: is_total})
      |> Pdf.text_at({totals_x + totals_w - 55, ty}, value, %{bold: is_total})
    end)

    # ── PAYMENT INFO ──
    y_pay = y_totals - 55
    doc = doc
    |> Pdf.save_state()
    |> Pdf.set_stroke_color(light_border)
    |> Pdf.set_line_width(0.3)
    |> Pdf.line({x0, y_pay + 8}, {x1, y_pay + 8})
    |> Pdf.stroke()
    |> Pdf.restore_state()
    |> Pdf.set_font("Helvetica", 8)
    |> Pdf.set_fill_color(dark)
    |> Pdf.text_at({x0 + 5, y_pay - 5}, "Forma de pago: ")
    |> Pdf.text_at({x0 + 80, y_pay - 5}, "01 - Efectivo", %{bold: true})
    |> Pdf.text_at({x0 + 270, y_pay - 5}, "Moneda: ")
    |> Pdf.text_at({x0 + 310, y_pay - 5}, "MXN", %{bold: true})
    |> Pdf.text_at({x0 + 5, y_pay - 16}, "Metodo de pago: ")
    |> Pdf.text_at({x0 + 85, y_pay - 16}, "PUE - Pago en una sola exhibicion", %{bold: true})
    |> Pdf.text_at({x0 + 270, y_pay - 16}, "Tipo de comprobante: ")
    |> Pdf.text_at({x0 + 375, y_pay - 16}, "I - Ingreso", %{bold: true})
    |> Pdf.text_at({x0 + 5, y_pay - 27}, "No. de cuenta:")

    # ── CERTIFICATION INFO ──
    y_cert = y_pay - 45
    cert_mid = x0 + page_w / 2

    doc = doc
    |> Pdf.save_state()
    |> Pdf.set_stroke_color(border_c)
    |> Pdf.set_line_width(0.5)
    # Header row
    |> Pdf.set_fill_color(header_bg)
    |> Pdf.rectangle({x0, y_cert}, {page_w / 2, 14})
    |> Pdf.fill()
    |> Pdf.rectangle({cert_mid, y_cert}, {page_w / 2, 14})
    |> Pdf.fill()
    |> Pdf.set_stroke_color(border_c)
    |> Pdf.rectangle({x0, y_cert}, {page_w / 2, 14})
    |> Pdf.stroke()
    |> Pdf.rectangle({cert_mid, y_cert}, {page_w / 2, 14})
    |> Pdf.stroke()
    |> Pdf.set_fill_color(dark)
    |> Pdf.set_font("Helvetica", 7)
    |> Pdf.text_at({x0 + 50, y_cert + 3}, "No. CSD del Emisor", %{bold: true})
    |> Pdf.text_at({cert_mid + 30, y_cert + 3}, "Fecha y hora de certificacion", %{bold: true})
    # Values row
    |> Pdf.rectangle({x0, y_cert - 14}, {page_w / 2, 14})
    |> Pdf.stroke()
    |> Pdf.rectangle({cert_mid, y_cert - 14}, {page_w / 2, 14})
    |> Pdf.stroke()
    |> Pdf.set_font("Helvetica", 7)
    |> Pdf.text_at({x0 + 20, y_cert - 11}, "30001000000400002333")
    |> Pdf.text_at({cert_mid + 40, y_cert - 11}, "2022-05-07T16:32:00")
    # Folio Fiscal header
    |> Pdf.set_fill_color(header_bg)
    |> Pdf.rectangle({x0, y_cert - 28}, {page_w / 2, 14})
    |> Pdf.fill()
    |> Pdf.rectangle({cert_mid, y_cert - 28}, {page_w / 2, 14})
    |> Pdf.fill()
    |> Pdf.set_stroke_color(border_c)
    |> Pdf.rectangle({x0, y_cert - 28}, {page_w / 2, 14})
    |> Pdf.stroke()
    |> Pdf.rectangle({cert_mid, y_cert - 28}, {page_w / 2, 14})
    |> Pdf.stroke()
    |> Pdf.set_fill_color(dark)
    |> Pdf.text_at({x0 + 60, y_cert - 25}, "Folio Fiscal", %{bold: true})
    |> Pdf.text_at({cert_mid + 50, y_cert - 25}, "No. CSD del SAT", %{bold: true})
    # Folio values
    |> Pdf.rectangle({x0, y_cert - 42}, {page_w / 2, 14})
    |> Pdf.stroke()
    |> Pdf.rectangle({cert_mid, y_cert - 42}, {page_w / 2, 14})
    |> Pdf.stroke()
    |> Pdf.set_font("Courier", 6)
    |> Pdf.text_at({x0 + 5, y_cert - 39}, "6CE88083-E455-458D-BE8D-2A292BC6DEEE")
    |> Pdf.text_at({cert_mid + 15, y_cert - 39}, "30001000000400002495")
    |> Pdf.restore_state()

    # ── DIGITAL SEALS ──
    y_seal = y_cert - 62

    seal_emisor = "gieMqNUlmQPBElJY3bmZHyFU3mtUh+Qk5V2yUBRa83y/AmcBnwrtDo9hb9qLY+NSu5mOoN67fubNwcWv72qW/YKdJEzzUNP" <>
      "+clpPJbxMerTmVhRm4dusX4hFdA6M6WW..."
    seal_sat = "pXWM0nAQ8+d31f/SVRqZwfb6XHQOndGQyNQ8hqySoqRevKZ/6bp5NN" <>
      "+0BhR04Jj03qLgr0obj5t.J8EuLBeQfMNZawH4xboNpUA34og9Mv7jAaHdagzw..."
    cadena = "||1.1|6ce88b0b3-e455-458d-be8d-2a292bc6deee|2022-05-07T16:32:00|SPR190631i3S2|gieMqNUlmQPBElJY3bmZHyFU3mtUh" <>
      "+Qk5V2yUBRa83y/AmcBnwrtDo9hb9qLY+NSu5mOoN67fubNwcWv72qW/YKdJEzz..."

    doc = doc
    |> Pdf.save_state()
    |> Pdf.set_stroke_color(light_border)
    |> Pdf.set_line_width(0.3)
    |> Pdf.line({x0, y_seal + 5}, {x1, y_seal + 5})
    |> Pdf.stroke()
    |> Pdf.restore_state()

    # QR placeholder
    doc = doc
    |> Pdf.save_state()
    |> Pdf.set_stroke_color(border_c)
    |> Pdf.set_line_width(0.5)
    |> Pdf.rectangle({x0 + 5, y_seal - 95}, {80, 80})
    |> Pdf.stroke()
    |> Pdf.set_font("Helvetica", 7)
    |> Pdf.set_fill_color(:gray)
    |> Pdf.text_at({x0 + 25, y_seal - 55}, "[QR Code]")
    |> Pdf.restore_state()

    # Seal texts
    seal_x = x0 + 95
    doc = doc
    |> Pdf.set_font("Helvetica", 7)
    |> Pdf.set_fill_color(dark)
    |> Pdf.text_at({seal_x, y_seal - 5}, "SELLO DIGITAL DEL EMISOR", %{bold: true})
    |> Pdf.set_font("Courier", 5)
    |> Pdf.set_fill_color({0.3, 0.3, 0.3})
    |> Pdf.text_at({seal_x + 10, y_seal - 14}, seal_emisor)
    |> Pdf.set_font("Helvetica", 7)
    |> Pdf.set_fill_color(dark)
    |> Pdf.text_at({seal_x, y_seal - 30}, "SELLO DEL SAT", %{bold: true})
    |> Pdf.set_font("Courier", 5)
    |> Pdf.set_fill_color({0.3, 0.3, 0.3})
    |> Pdf.text_at({seal_x + 10, y_seal - 39}, seal_sat)
    |> Pdf.set_font("Helvetica", 7)
    |> Pdf.set_fill_color(dark)
    |> Pdf.text_at({seal_x, y_seal - 55}, "CADENA ORIGINAL DEL COMPLEMENTO DE CERTIFICACION DIGITAL DEL SAT", %{bold: true})
    |> Pdf.set_font("Courier", 5)
    |> Pdf.set_fill_color({0.3, 0.3, 0.3})
    |> Pdf.text_at({seal_x + 10, y_seal - 64}, cadena)

    # ── Footer ──
    doc
    |> Pdf.save_state()
    |> Pdf.set_stroke_color(light_border)
    |> Pdf.set_line_width(0.3)
    |> Pdf.line({x0, 42}, {x1, 42})
    |> Pdf.stroke()
    |> Pdf.restore_state()
    |> Pdf.set_font("Helvetica", 7)
    |> Pdf.set_fill_color(:gray)
    |> Pdf.text_at({x0 + 30, 34}, "by Signati")
  end

  defp debug_grid_example do
    Pdf.new(size: :a4, margin: %{top: 60, bottom: 50, left: 50, right: 50})
    |> Pdf.set_font("Helvetica", 12)
    # Page 1: area: :content (default)
    |> Pdf.debug_grid(%{grid: :both, spacing: 10, area: :content})
    |> Pdf.text("Page 1 — area: :content (default)", %{font_size: 20, bold: true, color: :navy})
    |> Pdf.spacer(8)
    |> Pdf.text("Grid only inside the margins. Red border = margin boundary.")
    |> Pdf.spacer(5)
    |> Pdf.text("Blue line = cursor Y position.")
    |> Pdf.spacer(15)
    |> Pdf.text("Options:", %{bold: true})
    |> Pdf.spacer(5)
    |> Pdf.text("  grid:   :both | :horizontal | :vertical", %{font: "Courier", font_size: 10})
    |> Pdf.text("  area:   :content | :page | :margins", %{font: "Courier", font_size: 10})
    |> Pdf.text("  spacing: 10  (distancia entre lineas en points)", %{font: "Courier", font_size: 10})
    |> Pdf.text("  color:  {0.85, 0.85, 0.85}", %{font: "Courier", font_size: 10})
    |> Pdf.text("  labels: true | false", %{font: "Courier", font_size: 10})
    |> Pdf.text("  info:   true | false", %{font: "Courier", font_size: 10})
    |> Pdf.spacer(15)
    |> Pdf.horizontal_line(%{stroke_color: :navy})
    |> Pdf.spacer(5)
    |> Pdf.text("Builder: debug: true  or  debug: %{area: :page, spacing: 20}", %{font: "Courier", font_size: 9, color: :gray})
    # Page 2: area: :page
    |> Pdf.page_break()
    |> Pdf.debug_grid(%{grid: :both, spacing: 10, area: :page})
    |> Pdf.text("Page 2 — area: :page", %{font_size: 20, bold: true, color: :navy})
    |> Pdf.spacer(8)
    |> Pdf.text("Grid covers the entire page (0,0 to page edge).")
    |> Pdf.spacer(5)
    |> Pdf.text("Useful to see absolute coordinates and margin zones.")
    # Page 3: area: :margins
    |> Pdf.page_break()
    |> Pdf.debug_grid(%{grid: :both, spacing: 20, area: :margins, color: {1.0, 0.85, 0.85}})
    |> Pdf.text("Page 3 — area: :margins", %{font_size: 20, bold: true, color: :navy})
    |> Pdf.spacer(8)
    |> Pdf.text("Grid only in the margin zones (outside content area).")
    |> Pdf.spacer(5)
    |> Pdf.text("Content area stays clean — helpful to debug header/footer space.")
    # Page 4: horizontal only
    |> Pdf.page_break()
    |> Pdf.debug_grid(%{grid: :horizontal, spacing: 5, area: :content})
    |> Pdf.text("Page 4 — grid: :horizontal, step: 5", %{font_size: 20, bold: true, color: :navy})
    |> Pdf.spacer(8)
    |> Pdf.text("Only horizontal lines, every 20pt. Great for checking vertical alignment.")
    # Page 5: vertical only
    |> Pdf.page_break()
    |> Pdf.debug_grid(%{grid: :vertical, spacing: 20, area: :content})
    |> Pdf.text("Page 5 — grid: :vertical, step: 20", %{font_size: 20, bold: true, color: :navy})
    |> Pdf.spacer(8)
    |> Pdf.text("Only vertical lines. Great for checking column alignment.")
  end

  defp full_document do
    template = [
      {:background, %{background: {0.98, 0.98, 1.0}}},
      {:text, "Full Document Example", %{font_size: 28, bold: true, color: :navy}},
      {:spacer, 8},
      {:text, "Demonstrating all features of elixir-pdf", %{font_size: 14, color: :gray}},
      {:spacer, 15},
      {:line, %{color: :navy}},
      {:spacer, 15},
      {:text, "1. Styled Text", %{font_size: 16, bold: true}},
      {:spacer, 5},
      {:text, "Regular text with automatic word-wrapping within the content area defined by margins. This text will flow naturally within the page boundaries."},
      {:spacer, 5},
      {:text, "Bold red text", %{bold: true, color: :red}},
      {:text, "Italic blue text", %{italic: true, color: :blue}},
      {:spacer, 15},
      {:text, "2. Opacity & Watermark", %{font_size: 16, bold: true}},
      {:spacer, 5},
      {:text, "This document has a light blue background and a watermark on page 2."},
      {:spacer, 15},
      {:text, "3. Builder API", %{font_size: 16, bold: true}},
      {:spacer, 5},
      {:text, "This entire document is generated from a declarative template list using Pdf.Builder.render/2."},
      {:spacer, 15},
      {:line, %{color: :gray}},
      {:spacer, 10},
      {:text, "End of page 1", %{font_size: 10, color: :gray}},
      {:page_break},
      {:watermark, "CONFIDENTIAL", %{opacity: 0.05, rotate: 45, font_size: 60, color: :red}},
      {:text, "Page 2 - More Features", %{font_size: 22, bold: true, color: :navy}},
      {:spacer, 15},
      {:text, "Page templates (header/footer) can be configured in the Builder config."},
      {:spacer, 10},
      {:text, "The watermark on this page was added with a single tuple in the template."},
      {:spacer, 15},
      {:line, %{color: :navy}},
      {:spacer, 10},
      {:text, "Built with elixir-pdf", %{font_size: 10, color: :gray}}
    ]

    config = %{
      size: :a4,
      margin: %{top: 70, bottom: 60, left: 50, right: 50},
      debug: true,
      font: "Helvetica",
      font_size: 12,
      header: fn doc, info ->
        doc
        |> Pdf.set_font("Helvetica", 8)
        |> Pdf.set_fill_color(:gray)
        |> Pdf.text_at({50, 820}, "elixir-pdf Full Document Example")
        |> Pdf.text_at({490, 820}, "Page #{info.number}")
        |> Pdf.set_fill_color(:black)
      end,
      footer: fn doc, _info ->
        doc
        |> Pdf.set_font("Helvetica", 7)
        |> Pdf.set_fill_color(:gray)
        |> Pdf.text_at({200, 30}, "Generated with elixir-pdf | github.com/andrewtimberlake/elixir-pdf")
        |> Pdf.set_fill_color(:black)
      end
    }

    Pdf.Builder.render(template, config)
  end
end
