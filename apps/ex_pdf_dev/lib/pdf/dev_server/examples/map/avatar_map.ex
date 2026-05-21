defmodule Pdf.DevServer.Examples.Map.AvatarMap do
  @moduledoc false

  def render do
    blue = {0.23, 0.53, 0.88}
    red = {0.85, 0.26, 0.33}
    green = {0.18, 0.72, 0.45}
    purple = {0.56, 0.27, 0.78}
    orange = {0.95, 0.55, 0.0}
    gray = {0.5, 0.5, 0.5}
    light = {0.96, 0.96, 0.96}
    dark = {0.2, 0.2, 0.2}

    template = [
      # ── Title ──
      %{text: "Avatar Component (Builder API)", font_size: 24, bold: true, x: 50, y: 780},
      %{text: "Declarative avatars via map syntax", font_size: 11, color: gray, x: 50, y: 762},

      # ── Basic Avatars ──
      %{text: "Basic Avatars", font_size: 14, bold: true, x: 50, y: 720},
      %{text: "Circular shape with initials", font_size: 9, color: gray, x: 50, y: 706},
      %{avatar: {60, 695}, size: 48, initials: "AM", background: blue},
      %{avatar: {120, 695}, size: 48, initials: "JS", background: red},
      %{avatar: {180, 695}, size: 48, initials: "RG", background: green},
      %{avatar: {240, 695}, size: 48, initials: "K", background: purple},
      %{avatar: {300, 695}, size: 48, initials: "TW", background: orange},

      # ── Sizes ──
      %{text: "Sizes", font_size: 14, bold: true, x: 50, y: 615},
      %{text: "size: 24, 32, 40, 48, 64", font_size: 9, color: gray, x: 50, y: 601},
      %{avatar: {60, 590}, size: 24, initials: "24", background: blue},
      %{avatar: {95, 590}, size: 32, initials: "32", background: blue},
      %{avatar: {140, 590}, size: 40, initials: "40", background: blue},
      %{avatar: {195, 590}, size: 48, initials: "48", background: blue},
      %{avatar: {260, 590}, size: 64, initials: "64", background: blue},

      # ── Border Radius ──
      %{text: "Border Radius", font_size: 14, bold: true, x: 50, y: 500},
      %{text: ":circle | :rounded | numeric", font_size: 9, color: gray, x: 50, y: 486},
      %{avatar: {60, 475}, size: 56, initials: "CI", background: red, border_radius: :circle},
      %{avatar: {130, 475}, size: 56, initials: "RD", background: green, border_radius: :rounded},
      %{avatar: {200, 475}, size: 56, initials: "N8", background: purple, border_radius: 8},
      %{text: ":circle", font_size: 8, color: gray, x: 65, y: 410},
      %{text: ":rounded", font_size: 8, color: gray, x: 130, y: 410},
      %{text: "8", font_size: 8, color: gray, x: 220, y: 410},

      # ── Borders ──
      %{text: "Borders", font_size: 14, bold: true, x: 50, y: 385},
      %{text: "border + border_color", font_size: 9, color: gray, x: 50, y: 371},
      %{avatar: {60, 360}, size: 56, initials: "WH", background: blue, border: 2, border_color: :white},
      %{avatar: {130, 360}, size: 56, initials: "BK", background: orange, border: 2, border_color: :black},
      %{avatar: {200, 360}, size: 56, initials: "RD", background: green, border: 3, border_color: red},
      %{avatar: {270, 360}, size: 56, initials: "GD", background: {0.12, 0.12, 0.12}, border: 2, border_color: {0.95, 0.75, 0.0}},

      # ── Elevation ──
      %{text: "Elevation (Box Shadow)", font_size: 14, bold: true, x: 50, y: 280},
      %{text: "elevation: 0 through 5", font_size: 9, color: gray, x: 50, y: 266},
      %{avatar: {60, 255}, size: 56, initials: "E0", background: light, color: dark, elevation: 0, border: 1, border_color: {0.88, 0.88, 0.88}},
      %{avatar: {135, 255}, size: 56, initials: "E1", background: light, color: dark, elevation: 1, border: 1, border_color: {0.88, 0.88, 0.88}},
      %{avatar: {210, 255}, size: 56, initials: "E2", background: light, color: dark, elevation: 2, border: 1, border_color: {0.88, 0.88, 0.88}},
      %{avatar: {285, 255}, size: 56, initials: "E3", background: light, color: dark, elevation: 3, border: 1, border_color: {0.88, 0.88, 0.88}},
      %{avatar: {360, 255}, size: 56, initials: "E4", background: light, color: dark, elevation: 4, border: 1, border_color: {0.88, 0.88, 0.88}},
      %{avatar: {435, 255}, size: 56, initials: "E5", background: light, color: dark, elevation: 5, border: 1, border_color: {0.88, 0.88, 0.88}},

      # ── Avatar Group ──
      %{text: "Avatar Group (overlapping)", font_size: 14, bold: true, x: 50, y: 165},
      %{text: "Overlapping avatars with white border", font_size: 9, color: gray, x: 50, y: 151},
      %{avatar: {60, 140}, size: 40, initials: "AM", background: blue, border: 2, border_color: :white, elevation: 1},
      %{avatar: {90, 140}, size: 40, initials: "JS", background: red, border: 2, border_color: :white, elevation: 1},
      %{avatar: {120, 140}, size: 40, initials: "RG", background: green, border: 2, border_color: :white, elevation: 1},
      %{avatar: {150, 140}, size: 40, initials: "KP", background: purple, border: 2, border_color: :white, elevation: 1},
      %{avatar: {180, 140}, size: 40, initials: "+3", background: orange, border: 2, border_color: :white, elevation: 1}
    ]

    config = %{
      size: :a4,
      margin: %{top: 40, bottom: 40, left: 40, right: 40},
      font: "Helvetica",
      font_size: 12
    }

    Pdf.Builder.render(template, config)
  end
end
