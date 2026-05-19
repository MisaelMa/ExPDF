defmodule Pdf.DevServer.Examples.Component do
  @moduledoc false
  alias Pdf.Component.{Avatar, Badge, Card, Chip, Divider, Progress}

  alias Pdf.DevServer.Examples.Component.{
    ListDemo, BlockquoteDemo, CodeBlockDemo,
    SignatureDemo, StatCardDemo, AlertDemo,
    KeyValueDemo, TimelineDemo, StepIndicatorDemo,
    RatingDemo, MetricDemo, TOCDemo, FootnoteDemo,
    PaginatorDemo
  }

  def list do
    [
      {"box_demo", "Box Component", "Box with padding, border, border_radius, background", &box_demo/0},
      {"row_demo", "Row Component", "Horizontal row distribution by weight", &row_demo/0},
      {"column_demo", "Column Component", "Vertical column stacking", &column_demo/0},
      {"nested_layout", "Nested Layout", "Box + Row + Column combined", &nested_layout/0},
      {"avatar_demo", "Avatar Component", "Circular avatars with initials, border, elevation", &avatar_demo/0},
      {"divider_demo", "Divider Component", "Horizontal/vertical line separators", &divider_demo/0},
      {"badge_demo", "Badge Component", "Dot, circle, and pill badges", &badge_demo/0},
      {"chip_demo", "Chip Component", "Filled and outlined tag labels", &chip_demo/0},
      {"progress_demo", "Progress Component", "Horizontal progress bars", &progress_demo/0},
      {"card_demo", "Card Component", "Card containers with header, elevation", &card_demo/0},
      {"list_demo", "List Component", "Bulleted and numbered lists with nesting", &ListDemo.render/0},
      {"blockquote_demo", "Blockquote Component", "Indented text with left accent bar", &BlockquoteDemo.render/0},
      {"code_block_demo", "CodeBlock Component", "Monospaced code with line numbers", &CodeBlockDemo.render/0},
      {"signature_demo", "Signature Component", "Signature lines with name, title, date", &SignatureDemo.render/0},
      {"stat_card_demo", "StatCard Component", "Dashboard KPI cards with trend", &StatCardDemo.render/0},
      {"alert_demo", "Alert Component", "Info/success/warning/error notification boxes", &AlertDemo.render/0},
      {"key_value_demo", "KeyValue Component", "Aligned label-value pairs", &KeyValueDemo.render/0},
      {"timeline_demo", "Timeline Component", "Vertical timeline with events", &TimelineDemo.render/0},
      {"step_indicator_demo", "StepIndicator Component", "Numbered steps with progress line", &StepIndicatorDemo.render/0},
      {"rating_demo", "Rating Component", "Star/score rating display", &RatingDemo.render/0},
      {"metric_demo", "Metric Component", "Before/after comparison with delta", &MetricDemo.render/0},
      {"toc_demo", "TOC Component", "Table of contents with dot leaders", &TOCDemo.render/0},
      {"footnote_demo", "Footnote Component", "Numbered footnotes with separator", &FootnoteDemo.render/0},
      {"paginator_demo", "Paginator Component", "Automatic page numbering in footer", &PaginatorDemo.render/0}
    ]
  end

  defp box_demo do
    Pdf.new(size: :a4, margin: 50)
    |> Pdf.set_info(title: "Box Component")
    |> Pdf.set_font("Helvetica", 12)
    |> Pdf.text("Pdf.Component.Box — Document-level box containers", %{font_size: 20, bold: true})
    |> Pdf.spacer(20)
    # Box with background and border_radius
    |> Pdf.box({50, 720}, {250, 120}, %{padding: 15, border: 2, border_color: :navy, background: {0.93, 0.93, 1.0}, border_radius: 10}, fn doc, area ->
      doc
      |> Pdf.text_at({area.x, area.y - 14}, "Box with padding, border & bg", %{bold: true})
      |> Pdf.text_at({area.x, area.y - 30}, "border_radius: 10")
      |> Pdf.text_at({area.x, area.y - 46}, "Inner: #{round(area.width)}x#{round(area.height)}", %{color: :gray})
    end)
    # Box with just border
    |> Pdf.box({320, 720}, {220, 120}, %{padding: 10, margin: 5, border: 1, border_color: :gray}, fn doc, area ->
      doc
      |> Pdf.text_at({area.x, area.y - 14}, "Box with margin=5", %{bold: true})
      |> Pdf.text_at({area.x, area.y - 30}, "padding=10, border=1")
    end)
    # Box with rounded corners and fill
    |> Pdf.box({50, 570}, {490, 80}, %{padding: 12, background: {1.0, 0.95, 0.9}, border: 1, border_color: {0.9, 0.55, 0.0}, border_radius: 15}, fn doc, area ->
      doc
      |> Pdf.text_at({area.x, area.y - 14}, "Full-width box with warm background", %{font_size: 14, bold: true})
      |> Pdf.text_at({area.x, area.y - 34}, "Uses Pdf.box/5 which delegates to Pdf.Component.Box.render/5", %{font_size: 10, color: :gray})
    end)
  end

  defp row_demo do
    Pdf.new(size: :a4, margin: 50)
    |> Pdf.set_info(title: "Row Component")
    |> Pdf.set_font("Helvetica", 12)
    |> Pdf.text("Pdf.Component.Row — Horizontal distribution by weight", %{font_size: 20, bold: true})
    |> Pdf.spacer(20)
    # Row with 3 columns
    |> Pdf.row({50, 720}, {495, 80}, [
      {1, fn doc, area ->
        Pdf.box(doc, {area.x, area.y}, {area.width, area.height},
          %{padding: 8, border: 1, background: {1.0, 0.9, 0.9}, border_radius: 6},
          fn doc, a -> Pdf.text_at(doc, {a.x, a.y - 14}, "Col 1 (w:1)", %{bold: true}) end)
      end},
      {2, fn doc, area ->
        Pdf.box(doc, {area.x, area.y}, {area.width, area.height},
          %{padding: 8, border: 1, background: {0.9, 1.0, 0.9}, border_radius: 6},
          fn doc, a -> Pdf.text_at(doc, {a.x, a.y - 14}, "Col 2 (w:2, double)", %{bold: true}) end)
      end},
      {1, fn doc, area ->
        Pdf.box(doc, {area.x, area.y}, {area.width, area.height},
          %{padding: 8, border: 1, background: {0.9, 0.9, 1.0}, border_radius: 6},
          fn doc, a -> Pdf.text_at(doc, {a.x, a.y - 14}, "Col 3 (w:1)", %{bold: true}) end)
      end}
    ], gap: 10)
    # Row with 2 equal columns
    |> Pdf.row({50, 610}, {495, 60}, [
      {1, fn doc, area ->
        Pdf.box(doc, {area.x, area.y}, {area.width, area.height},
          %{padding: 8, border: 1, border_color: :navy},
          fn doc, a -> Pdf.text_at(doc, {a.x, a.y - 14}, "Left half") end)
      end},
      {1, fn doc, area ->
        Pdf.box(doc, {area.x, area.y}, {area.width, area.height},
          %{padding: 8, border: 1, border_color: :navy},
          fn doc, a -> Pdf.text_at(doc, {a.x, a.y - 14}, "Right half") end)
      end}
    ], gap: 10)
  end

  defp column_demo do
    Pdf.new(size: :a4, margin: 50)
    |> Pdf.set_info(title: "Column Component")
    |> Pdf.set_font("Helvetica", 12)
    |> Pdf.text("Pdf.Component.Column — Vertical stacking", %{font_size: 20, bold: true})
    |> Pdf.spacer(20)
    |> Pdf.column({50, 720}, {300, 300}, [
      {50, fn doc, area ->
        Pdf.box(doc, {area.x, area.y}, {area.width, area.height},
          %{padding: 10, border: 1, background: {1.0, 0.95, 0.9}, border_radius: 6},
          fn doc, a -> Pdf.text_at(doc, {a.x, a.y - 14}, "Row 1 — height 50", %{bold: true}) end)
      end},
      {80, fn doc, area ->
        Pdf.box(doc, {area.x, area.y}, {area.width, area.height},
          %{padding: 10, border: 1, background: {0.9, 0.95, 1.0}, border_radius: 6},
          fn doc, a ->
            doc
            |> Pdf.text_at({a.x, a.y - 14}, "Row 2 — height 80", %{bold: true})
            |> Pdf.text_at({a.x, a.y - 30}, "More space for content", %{color: :gray})
          end)
      end},
      {40, fn doc, area ->
        Pdf.box(doc, {area.x, area.y}, {area.width, area.height},
          %{padding: 10, border: 1, background: {0.95, 1.0, 0.9}, border_radius: 6},
          fn doc, a -> Pdf.text_at(doc, {a.x, a.y - 14}, "Row 3 — height 40", %{bold: true}) end)
      end}
    ], gap: 8)
  end

  defp nested_layout do
    Pdf.new(size: :a4, margin: 50)
    |> Pdf.set_info(title: "Nested Layout")
    |> Pdf.set_font("Helvetica", 12)
    |> Pdf.text("Nested Components — Box + Row + Column", %{font_size: 20, bold: true})
    |> Pdf.spacer(20)
    # Outer box with a row inside
    |> Pdf.box({50, 720}, {495, 200}, %{padding: 15, border: 2, border_color: :navy, border_radius: 12, background: {0.97, 0.97, 1.0}}, fn doc, area ->
      doc
      |> Pdf.text_at({area.x, area.y - 14}, "Outer Box", %{font_size: 16, bold: true, color: :navy})
      |> Pdf.row({area.x, area.y - 35}, {area.width, 130}, [
        {1, fn doc, col ->
          Pdf.column(doc, {col.x, col.y}, {col.width, col.height}, [
            {40, fn doc, row ->
              Pdf.box(doc, {row.x, row.y}, {row.width, row.height},
                %{padding: 6, background: {1.0, 0.9, 0.9}, border_radius: 4},
                fn doc, a -> Pdf.text_at(doc, {a.x, a.y - 12}, "A1", %{font_size: 10, bold: true}) end)
            end},
            {40, fn doc, row ->
              Pdf.box(doc, {row.x, row.y}, {row.width, row.height},
                %{padding: 6, background: {1.0, 0.95, 0.9}, border_radius: 4},
                fn doc, a -> Pdf.text_at(doc, {a.x, a.y - 12}, "A2", %{font_size: 10, bold: true}) end)
            end}
          ], gap: 5)
        end},
        {2, fn doc, col ->
          Pdf.box(doc, {col.x, col.y}, {col.width, col.height},
            %{padding: 10, border: 1, border_color: :gray, border_radius: 6},
            fn doc, a ->
              doc
              |> Pdf.text_at({a.x, a.y - 14}, "Main Content Area", %{font_size: 14, bold: true})
              |> Pdf.text_at({a.x, a.y - 32}, "Row weight: 2 (double width)", %{font_size: 10, color: :gray})
              |> Pdf.text_at({a.x, a.y - 48}, "Nested inside: Box > Row > Box", %{font_size: 10, color: :gray})
            end)
        end}
      ], gap: 10)
    end)
  end

  defp avatar_demo do
    blue = {0.23, 0.53, 0.88}
    red = {0.85, 0.26, 0.33}
    green = {0.18, 0.72, 0.45}
    purple = {0.56, 0.27, 0.78}
    orange = {0.95, 0.55, 0.0}

    Pdf.new(size: :a4, margin: 50)
    |> Pdf.set_info(title: "Avatar Component")
    |> Pdf.set_font("Helvetica", 12)
    |> Pdf.text("Pdf.avatar/3 — Circular avatars with initials, border & elevation", %{font_size: 18, bold: true})
    |> Pdf.spacer(15)

    # Basic avatars
    |> Pdf.text("Basic Avatars", %{font_size: 13, bold: true})
    |> Pdf.spacer(8)
    |> Avatar.render({60, 710}, %{size: 48, initials: "AM", background: blue})
    |> Avatar.render({120, 710}, %{size: 48, initials: "JS", background: red})
    |> Avatar.render({180, 710}, %{size: 48, initials: "RG", background: green})
    |> Avatar.render({240, 710}, %{size: 48, initials: "K", background: purple})
    |> Avatar.render({300, 710}, %{size: 48, initials: "TW", background: orange})

    # Sizes
    |> Pdf.set_font("Helvetica", 13)
    |> Pdf.text_at({50, 640}, "Sizes")
    |> Pdf.set_font("Helvetica", 12)
    |> Avatar.render({60, 625}, %{size: 24, initials: "S", background: blue})
    |> Avatar.render({95, 625}, %{size: 32, initials: "M", background: blue})
    |> Avatar.render({140, 625}, %{size: 40, initials: "L", background: blue})
    |> Avatar.render({195, 625}, %{size: 48, initials: "XL", background: blue})
    |> Avatar.render({260, 625}, %{size: 64, initials: "2X", background: blue})

    # Border radius variants
    |> Pdf.set_font("Helvetica", 13)
    |> Pdf.text_at({50, 545}, "Border Radius")
    |> Avatar.render({60, 530}, %{size: 56, initials: "CI", background: red, border_radius: :circle})
    |> Avatar.render({130, 530}, %{size: 56, initials: "RD", background: green, border_radius: :rounded})
    |> Avatar.render({200, 530}, %{size: 56, initials: "N8", background: purple, border_radius: 8})
    |> Pdf.set_font("Helvetica", 8)
    |> Pdf.text_at({65, 467}, ":circle")
    |> Pdf.text_at({133, 467}, ":rounded")
    |> Pdf.text_at({218, 467}, "8")

    # Borders
    |> Pdf.set_font("Helvetica", 13)
    |> Pdf.text_at({50, 445}, "Borders")
    |> Avatar.render({60, 430}, %{size: 56, initials: "WH", background: blue, border: 2, border_color: :white})
    |> Avatar.render({130, 430}, %{size: 56, initials: "BK", background: orange, border: 2, border_color: :black})
    |> Avatar.render({200, 430}, %{size: 56, initials: "RD", background: green, border: 3, border_color: red})

    # Elevation
    |> Pdf.set_font("Helvetica", 13)
    |> Pdf.text_at({50, 350}, "Elevation (Box Shadow)")
    |> Pdf.set_font("Helvetica", 8)
    |> then(fn doc ->
      Enum.reduce(0..5, doc, fn elev, doc ->
        x = 60 + elev * 75
        doc
        |> Avatar.render({x, 335}, %{
          size: 56,
          initials: "E#{elev}",
          background: {0.96, 0.96, 0.96},
          color: {0.2, 0.2, 0.2},
          elevation: elev,
          border: 1,
          border_color: {0.88, 0.88, 0.88}
        })
        |> Pdf.text_at({x + 15, 272}, "elev: #{elev}")
      end)
    end)

    # Avatar group (overlapping)
    |> Pdf.set_font("Helvetica", 13)
    |> Pdf.text_at({50, 250}, "Avatar Group (overlapping)")
    |> Pdf.set_font("Helvetica", 12)
    |> Avatar.render({60, 235}, %{size: 40, initials: "AM", background: blue, border: 2, border_color: :white, elevation: 1})
    |> Avatar.render({90, 235}, %{size: 40, initials: "JS", background: red, border: 2, border_color: :white, elevation: 1})
    |> Avatar.render({120, 235}, %{size: 40, initials: "RG", background: green, border: 2, border_color: :white, elevation: 1})
    |> Avatar.render({150, 235}, %{size: 40, initials: "KP", background: purple, border: 2, border_color: :white, elevation: 1})
    |> Avatar.render({180, 235}, %{size: 40, initials: "+3", background: orange, border: 2, border_color: :white, elevation: 1})

    # Avatar inside a box (composition)
    |> Pdf.set_font("Helvetica", 13)
    |> Pdf.text_at({50, 170}, "Avatar inside Box (composition)")
    |> Pdf.box({50, 155}, {350, 60}, %{padding: 10, border: 1, border_color: {0.85, 0.85, 0.85}, border_radius: 10, background: {0.98, 0.98, 0.98}}, fn doc, area ->
      doc
      |> Avatar.render({area.x, area.y}, %{size: 40, initials: "AM", background: blue, elevation: 1})
      |> Pdf.set_font("Helvetica", 12)
      |> Pdf.text_at({area.x + 50, area.y - 12}, "Amir M.", %{bold: true})
      |> Pdf.set_font("Helvetica", 10)
      |> Pdf.text_at({area.x + 50, area.y - 26}, "Senior Developer", %{color: {0.5, 0.5, 0.5}})
    end)
  end

  defp divider_demo do
    gray = {0.5, 0.5, 0.5}
    blue = {0.23, 0.53, 0.88}
    red = {0.85, 0.26, 0.33}

    Pdf.new(size: :a4, margin: 50)
    |> Pdf.set_info(title: "Divider Component")
    |> Pdf.set_font("Helvetica", 12)
    |> Pdf.text("Divider Component", %{font_size: 18, bold: true})
    |> Pdf.spacer(15)

    |> Pdf.text("Solid (default):", %{font_size: 11, bold: true})
    |> Pdf.spacer(5)
    |> Divider.render({50, 730}, %{width: 450})
    |> Divider.render({50, 720}, %{width: 450, color: blue, thickness: 1})
    |> Divider.render({50, 710}, %{width: 450, color: red, thickness: 2})

    |> Pdf.set_font("Helvetica", 11)
    |> Pdf.text_at({50, 690}, "Dashed:")
    |> Divider.render({50, 680}, %{width: 450, style: :dashed, color: gray})
    |> Divider.render({50, 670}, %{width: 450, style: :dashed, dash: {8, 3}, color: blue, thickness: 1})

    |> Pdf.text_at({50, 650}, "Vertical:")
    |> Divider.render({110, 650}, %{height: 40, orientation: :vertical, color: red, thickness: 1})
    |> Divider.render({125, 650}, %{height: 40, orientation: :vertical, style: :dashed, color: blue})
    |> Divider.render({140, 650}, %{height: 40, orientation: :vertical, color: {0.18, 0.72, 0.45}, thickness: 2})
  end

  defp badge_demo do
    red = {0.85, 0.26, 0.33}
    green = {0.18, 0.72, 0.45}
    blue = {0.23, 0.53, 0.88}
    purple = {0.56, 0.27, 0.78}

    Pdf.new(size: :a4, margin: 50)
    |> Pdf.set_info(title: "Badge Component")
    |> Pdf.set_font("Helvetica", 12)
    |> Pdf.text("Badge Component", %{font_size: 18, bold: true})
    |> Pdf.spacer(15)

    |> Pdf.text("Dot variant:", %{font_size: 11, bold: true})
    |> Pdf.spacer(5)
    |> Badge.render({80, 720}, %{variant: :dot, size: 10})
    |> Badge.render({100, 720}, %{variant: :dot, size: 10, background: green})
    |> Badge.render({120, 720}, %{variant: :dot, size: 10, background: blue})

    |> Pdf.set_font("Helvetica", 11)
    |> Pdf.text_at({50, 700}, "Standard:")
    |> Badge.render({120, 700}, %{content: "3"})
    |> Badge.render({150, 700}, %{content: "42", background: blue})
    |> Badge.render({185, 700}, %{content: "99+", size: 24, background: purple})

    |> Pdf.text_at({50, 675}, "Pill:")
    |> Badge.render({110, 675}, %{content: "NEW", variant: :pill, size: 18, background: green})
    |> Badge.render({170, 675}, %{content: "SALE", variant: :pill, size: 18, background: red})
    |> Badge.render({235, 675}, %{content: "PRO", variant: :pill, size: 18, background: blue})

    |> Pdf.text_at({50, 650}, "With border:")
    |> Badge.render({130, 650}, %{content: "5", size: 22, border: 2, border_color: :white})
    |> Badge.render({165, 650}, %{content: "OK", variant: :pill, background: green, border: 1.5, border_color: :white})
  end

  defp chip_demo do
    blue = {0.23, 0.53, 0.88}
    red = {0.85, 0.26, 0.33}
    green = {0.18, 0.72, 0.45}
    orange = {0.95, 0.55, 0.0}
    purple = {0.56, 0.27, 0.78}

    doc = Pdf.new(size: :a4, margin: 50)
    |> Pdf.set_info(title: "Chip Component")
    |> Pdf.set_font("Helvetica", 12)
    |> Pdf.text("Chip Component", %{font_size: 18, bold: true})
    |> Pdf.spacer(15)
    |> Pdf.text("Filled:", %{font_size: 11, bold: true})
    |> Pdf.spacer(5)

    {doc, w1} = Chip.render(doc, {50, 730}, %{label: "Elixir", background: purple, color: :white})
    {doc, w2} = Chip.render(doc, {50 + w1 + 8, 730}, %{label: "Phoenix", background: orange, color: :white})
    {doc, w3} = Chip.render(doc, {50 + w1 + w2 + 16, 730}, %{label: "LiveView", background: green, color: :white})
    {doc, _} = Chip.render(doc, {50 + w1 + w2 + w3 + 24, 730}, %{label: "OTP", background: blue, color: :white})

    doc = doc
    |> Pdf.set_font("Helvetica", 11)
    |> Pdf.text_at({50, 700}, "Outlined:")
    x = 50
    {doc, w1} = Chip.render(doc, {x, 690}, %{label: "Active", variant: :outlined, color: green})
    {doc, w2} = Chip.render(doc, {x + w1 + 8, 690}, %{label: "Pending", variant: :outlined, color: orange})
    {doc, w3} = Chip.render(doc, {x + w1 + w2 + 16, 690}, %{label: "Error", variant: :outlined, color: red})
    {doc, _} = Chip.render(doc, {x + w1 + w2 + w3 + 24, 690}, %{label: "Info", variant: :outlined, color: blue})

    doc
  end

  defp progress_demo do
    blue = {0.23, 0.53, 0.88}
    green = {0.18, 0.72, 0.45}
    orange = {0.95, 0.55, 0.0}
    red = {0.85, 0.26, 0.33}

    Pdf.new(size: :a4, margin: 50)
    |> Pdf.set_info(title: "Progress Component")
    |> Pdf.set_font("Helvetica", 12)
    |> Pdf.text("Progress Component", %{font_size: 18, bold: true})
    |> Pdf.spacer(15)

    |> Pdf.text("Different values:", %{font_size: 11, bold: true})
    |> Pdf.spacer(5)
    |> Progress.render({50, 730}, %{width: 300, value: 25, height: 10, color: blue, show_label: true})
    |> Progress.render({50, 712}, %{width: 300, value: 50, height: 10, color: orange, show_label: true})
    |> Progress.render({50, 694}, %{width: 300, value: 75, height: 10, color: green, show_label: true})
    |> Progress.render({50, 676}, %{width: 300, value: 100, height: 10, color: red, show_label: true})

    |> Pdf.set_font("Helvetica", 11)
    |> Pdf.text_at({50, 650}, "Tall bar:")
    |> Progress.render({50, 640}, %{width: 300, value: 65, height: 20, color: blue, show_label: true})

    |> Pdf.text_at({50, 610}, "Square corners:")
    |> Progress.render({50, 600}, %{width: 300, value: 80, height: 12, border_radius: :square, color: green, show_label: true})
  end

  defp card_demo do
    blue = {0.23, 0.53, 0.88}
    gray = {0.5, 0.5, 0.5}
    light_gray = {0.85, 0.85, 0.85}

    doc = Pdf.new(size: :a4, margin: 50)
    |> Pdf.set_info(title: "Card Component")
    |> Pdf.set_font("Helvetica", 12)
    |> Pdf.text("Card Component", %{font_size: 18, bold: true})
    |> Pdf.spacer(15)

    # Simple card
    doc = Card.render(doc, {50, 740}, {220, 100}, %{
      elevation: 2,
      border_radius: 8,
      padding: 10
    }, fn doc, area ->
      doc
      |> Pdf.set_font("Helvetica", 11, bold: true)
      |> Pdf.text_at({area.x, area.y - 14}, "Simple Card")
      |> Pdf.set_font("Helvetica", 9)
      |> Pdf.set_fill_color(gray)
      |> Pdf.text_at({area.x, area.y - 28}, "Elevation 2 with rounded corners")
      |> Pdf.set_fill_color(:black)
    end)

    # Card with header
    doc = Card.render(doc, {290, 740}, {220, 100}, %{
      elevation: 3,
      border_radius: 8,
      header: %{title: "With Header", subtitle: "And subtitle"},
      padding: 10
    }, fn doc, area ->
      doc
      |> Pdf.set_font("Helvetica", 9)
      |> Pdf.set_fill_color(gray)
      |> Pdf.text_at({area.x, area.y - 12}, "Content below the header")
      |> Pdf.set_fill_color(:black)
    end)

    # Card with border, no shadow
    doc = Card.render(doc, {50, 620}, {220, 80}, %{
      elevation: 0,
      border: 1,
      border_color: light_gray,
      border_radius: 6,
      padding: 10
    }, fn doc, area ->
      doc
      |> Pdf.set_font("Helvetica", 10, bold: true)
      |> Pdf.text_at({area.x, area.y - 12}, "Bordered Card")
      |> Pdf.set_font("Helvetica", 9)
      |> Pdf.set_fill_color(gray)
      |> Pdf.text_at({area.x, area.y - 26}, "No shadow, just a clean border")
      |> Pdf.set_fill_color(:black)
    end)

    # Card with footer and avatar
    Card.render(doc, {290, 620}, {220, 80}, %{
      elevation: 1,
      border_radius: 6,
      footer: %{text: "Updated 2 hours ago"},
      padding: 8
    }, fn doc, area ->
      doc
      |> Avatar.render({area.x, area.y}, %{size: 24, initials: "AM", background: blue})
      |> Pdf.set_font("Helvetica", 10, bold: true)
      |> Pdf.text_at({area.x + 30, area.y - 10}, "With Footer")
      |> Pdf.set_fill_color(:black)
    end)
  end
end
