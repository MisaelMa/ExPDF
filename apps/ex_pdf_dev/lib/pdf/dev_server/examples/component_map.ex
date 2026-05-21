defmodule Pdf.DevServer.Examples.ComponentMap do
  @moduledoc false

  def list do
    [
      {"box_map", "Box (Builder)", "Box component via %{box:} map element", &box_map/0},
      {"row_map", "Row (Builder)", "Row component via %{row:} map element", &row_map/0},
      {"column_map", "Column (Builder)", "Column component via %{column:} map element", &column_map/0},
      {"nested_map", "Nested (Builder)", "Nested box/row/column via Builder maps", &nested_map/0},
      {"avatar_map", "Avatar (Builder)", "Avatars with initials, border, elevation via maps", &avatar_map/0}
    ]
  end

  defp box_map do
    template = [
      %{text: "Box Component — Builder API", font_size: 20, bold: true, x: 50, y: 780},

      # Box with background and rounded corners
      %{box: {50, 720}, size: {250, 120},
        padding: 15, border: 2, border_color: :navy,
        background: {0.93, 0.93, 1.0}, border_radius: 10,
        children: [
          %{text: "Box with bg & radius", x: 0, y: -14, bold: true},
          %{text: "border_radius: 10", x: 0, y: -30},
          %{text: "Relative positioning", x: 0, y: -46, color: :gray}
        ]},

      # Box with just border
      %{box: {320, 720}, size: {220, 120},
        padding: 10, margin: 5, border: 1, border_color: :gray,
        children: [
          %{text: "Box with margin=5", x: 0, y: -14, bold: true},
          %{text: "padding=10, border=1", x: 0, y: -30}
        ]},

      # Full-width box
      %{box: {50, 570}, size: {490, 80},
        padding: 12, background: {1.0, 0.95, 0.9},
        border: 1, border_color: {0.9, 0.55, 0.0}, border_radius: 15,
        children: [
          %{text: "Full-width box via %{box:} map element", x: 0, y: -14, font_size: 14, bold: true},
          %{text: "Children use relative positioning by default", x: 0, y: -34, font_size: 10, color: :gray}
        ]},

      # Demo: absolute positioning
      %{box: {50, 460}, size: {490, 80},
        padding: 12, border: 1, border_color: :navy, border_radius: 8,
        children: [
          %{text: "This child is relative (default)", x: 0, y: -14, font_size: 11},
          %{text: "This child is ABSOLUTE (page coords)", x: 400, y: 430, font_size: 11, color: :red, bold: true, position: :absolute}
        ]}
    ]

    Pdf.Builder.render(template, %{
      size: :a4,
      margin: %{top: 0, bottom: 0, left: 0, right: 0},
      font: "Helvetica",
      font_size: 12
    })
  end

  defp row_map do
    template = [
      %{text: "Row Component — Builder API", font_size: 20, bold: true, x: 50, y: 780},

      # Row with 3 columns (weight 1:2:1)
      %{row: {50, 720}, size: {495, 80}, gap: 1, children: [
        {1, [
          %{rect: {0, 0}, size: {0, 0}},
          %{box: {0, 0}, size: {120, 80},
            padding: 8, border: 1, background: {1.0, 0.9, 0.9}, border_radius: 6,
            children: [%{text: "Col 1 (w:1)", x: 0, y: -14, bold: true}]}
        ]},
        {2, [
          %{box: {0, 0}, size: {245, 80},
            padding: 8, border: 1, background: {0.9, 1.0, 0.9}, border_radius: 6,
            children: [%{text: "Col 2 (w:2, double)", x: 0, y: -14, bold: true}]}
        ]},
        {1, [
          %{box: {0, 0}, size: {120, 80},
            padding: 8, border: 1, background: {0.9, 0.9, 1.0}, border_radius: 6,
            children: [%{text: "Col 3 (w:1)", x: 0, y: -14, bold: true}]}
        ]}
      ]},

      # Row with 2 equal columns
      %{row: {50, 610}, size: {495, 60}, gap: 10, children: [
        {1, [%{text: "Left half", x: 8, y: -14}]},
        {1, [%{text: "Right half", x: 8, y: -14}]}
      ]}
    ]

    Pdf.Builder.render(template, %{
      size: :a4,
      margin: %{top: 0, bottom: 0, left: 0, right: 0},
      font: "Helvetica",
      font_size: 12
    })
  end

  defp column_map do
    template = [
      %{text: "Column Component — Builder API", font_size: 20, bold: true, x: 50, y: 780},

      %{column: {50, 720}, size: {300, 220}, gap: 8, children: [
        {50, [
          %{box: {0, 0}, size: {300, 50},
            padding: 10, border: 1, background: {1.0, 0.95, 0.9}, border_radius: 6,
            children: [%{text: "Row 1 — height 50", x: 0, y: -14, bold: true}]}
        ]},
        {80, [
          %{box: {0, 0}, size: {300, 80},
            padding: 10, border: 1, background: {0.9, 0.95, 1.0}, border_radius: 6,
            children: [
              %{text: "Row 2 — height 80", x: 0, y: -14, bold: true},
              %{text: "More space for content", x: 0, y: -30, color: :gray}
            ]}
        ]},
        {40, [
          %{box: {0, 0}, size: {300, 40},
            padding: 10, border: 1, background: {0.95, 1.0, 0.9}, border_radius: 6,
            children: [%{text: "Row 3 — height 40", x: 0, y: -14, bold: true}]}
        ]}
      ]}
    ]

    Pdf.Builder.render(template, %{
      size: :a4,
      margin: %{top: 0, bottom: 0, left: 0, right: 0},
      font: "Helvetica",
      font_size: 12
    })
  end

  defp nested_map do
    template = [
      %{text: "Nested Components — Builder Maps", font_size: 20, bold: true, x: 50, y: 780},

      # Outer box containing a row with columns
      %{box: {50, 720}, size: {495, 200},
        padding: 15, border: 2, border_color: :navy,
        border_radius: 12, background: {0.97, 0.97, 1.0},
        children: [
          %{text: "Outer Box", x: 0, y: -14, font_size: 16, bold: true, color: :navy},

          %{row: {0, -35}, size: {465, 130}, gap: 10, children: [
            {1, [
              %{column: {0, 0}, size: {148, 130}, gap: 5, children: [
                {40, [
                  %{box: {0, 0}, size: {148, 40},
                    padding: 6, background: {1.0, 0.9, 0.9}, border_radius: 4,
                    children: [%{text: "A1", x: 0, y: -12, font_size: 10, bold: true}]}
                ]},
                {40, [
                  %{box: {0, 0}, size: {148, 40},
                    padding: 6, background: {1.0, 0.95, 0.9}, border_radius: 4,
                    children: [%{text: "A2", x: 0, y: -12, font_size: 10, bold: true}]}
                ]}
              ]}
            ]},
            {2, [
              %{box: {0, 0}, size: {300, 130},
                padding: 10, border: 1, border_color: :gray, border_radius: 6,
                children: [
                  %{text: "Main Content Area", x: 0, y: -14, font_size: 14, bold: true},
                  %{text: "Row weight: 2 (double width)", x: 0, y: -32, font_size: 10, color: :gray},
                  %{text: "Nested: box > row > column > box", x: 0, y: -48, font_size: 10, color: :gray}
                ]}
            ]}
          ]}
        ]}
    ]

    Pdf.Builder.render(template, %{
      size: :a4,
      margin: %{top: 0, bottom: 0, left: 0, right: 0},
      font: "Helvetica",
      font_size: 12
    })
  end

  defp avatar_map do
    blue = {0.23, 0.53, 0.88}
    red = {0.85, 0.26, 0.33}
    green = {0.18, 0.72, 0.45}
    purple = {0.56, 0.27, 0.78}
    orange = {0.95, 0.55, 0.0}
    gray = {0.5, 0.5, 0.5}
    light = {0.96, 0.96, 0.96}
    dark = {0.2, 0.2, 0.2}

    template = [
      %{text: "Avatar Component — Builder API", font_size: 20, bold: true, x: 50, y: 780},
      %{text: "All avatars below use %{avatar: {x, y}, ...} map syntax", font_size: 10, color: gray, x: 50, y: 762},

      # Basic
      %{text: "Basic Avatars", font_size: 13, bold: true, x: 50, y: 730},
      %{avatar: {60, 715}, size: 48, initials: "AM", background: blue},
      %{avatar: {120, 715}, size: 48, initials: "JS", background: red},
      %{avatar: {180, 715}, size: 48, initials: "RG", background: green},
      %{avatar: {240, 715}, size: 48, initials: "K", background: purple},
      %{avatar: {300, 715}, size: 48, initials: "TW", background: orange},

      # Sizes
      %{text: "Sizes", font_size: 13, bold: true, x: 50, y: 645},
      %{avatar: {60, 630}, size: 24, initials: "S", background: blue},
      %{avatar: {95, 630}, size: 32, initials: "M", background: blue},
      %{avatar: {140, 630}, size: 40, initials: "L", background: blue},
      %{avatar: {195, 630}, size: 48, initials: "XL", background: blue},
      %{avatar: {260, 630}, size: 64, initials: "2X", background: blue},

      # Border radius
      %{text: "Border Radius", font_size: 13, bold: true, x: 50, y: 545},
      %{avatar: {60, 530}, size: 56, initials: "CI", background: red, border_radius: :circle},
      %{avatar: {130, 530}, size: 56, initials: "RD", background: green, border_radius: :rounded},
      %{avatar: {200, 530}, size: 56, initials: "N8", background: purple, border_radius: 8},
      %{text: ":circle", font_size: 8, color: gray, x: 65, y: 467},
      %{text: ":rounded", font_size: 8, color: gray, x: 133, y: 467},
      %{text: "8", font_size: 8, color: gray, x: 220, y: 467},

      # Borders
      %{text: "Borders", font_size: 13, bold: true, x: 50, y: 445},
      %{avatar: {60, 430}, size: 56, initials: "WH", background: blue, border: 2, border_color: :white},
      %{avatar: {130, 430}, size: 56, initials: "BK", background: orange, border: 2, border_color: :black},
      %{avatar: {200, 430}, size: 56, initials: "RD", background: green, border: 3, border_color: red},

      # Elevation
      %{text: "Elevation (Box Shadow)", font_size: 13, bold: true, x: 50, y: 350},
      %{avatar: {60, 335}, size: 56, initials: "E0", background: light, color: dark, elevation: 0, border: 1, border_color: {0.88, 0.88, 0.88}},
      %{avatar: {135, 335}, size: 56, initials: "E1", background: light, color: dark, elevation: 1, border: 1, border_color: {0.88, 0.88, 0.88}},
      %{avatar: {210, 335}, size: 56, initials: "E2", background: light, color: dark, elevation: 2, border: 1, border_color: {0.88, 0.88, 0.88}},
      %{avatar: {285, 335}, size: 56, initials: "E3", background: light, color: dark, elevation: 3, border: 1, border_color: {0.88, 0.88, 0.88}},
      %{avatar: {360, 335}, size: 56, initials: "E4", background: light, color: dark, elevation: 4, border: 1, border_color: {0.88, 0.88, 0.88}},
      %{avatar: {435, 335}, size: 56, initials: "E5", background: light, color: dark, elevation: 5, border: 1, border_color: {0.88, 0.88, 0.88}},

      # Avatar group
      %{text: "Avatar Group (overlapping)", font_size: 13, bold: true, x: 50, y: 255},
      %{avatar: {60, 240}, size: 40, initials: "AM", background: blue, border: 2, border_color: :white, elevation: 1},
      %{avatar: {90, 240}, size: 40, initials: "JS", background: red, border: 2, border_color: :white, elevation: 1},
      %{avatar: {120, 240}, size: 40, initials: "RG", background: green, border: 2, border_color: :white, elevation: 1},
      %{avatar: {150, 240}, size: 40, initials: "KP", background: purple, border: 2, border_color: :white, elevation: 1},
      %{avatar: {180, 240}, size: 40, initials: "+3", background: orange, border: 2, border_color: :white, elevation: 1},

      # Avatar inside a box
      %{text: "Avatar inside Box (composition)", font_size: 13, bold: true, x: 50, y: 175},
      %{box: {50, 160}, size: {350, 60},
        padding: 10, border: 1, border_color: {0.85, 0.85, 0.85},
        border_radius: 10, background: {0.98, 0.98, 0.98},
        children: [
          %{avatar: {0, 0}, size: 40, initials: "AM", background: blue, elevation: 1},
          %{text: "Amir M.", x: 50, y: -12, bold: true, font_size: 12},
          %{text: "Senior Developer", x: 50, y: -26, font_size: 10, color: gray}
        ]}
    ]

    Pdf.Builder.render(template, %{
      size: :a4,
      margin: %{top: 0, bottom: 0, left: 0, right: 0},
      font: "Helvetica",
      font_size: 12
    })
  end
end
