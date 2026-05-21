defmodule Pdf.DevServer.Examples.Api do
  @moduledoc false

  alias Pdf.DevServer.Examples.Api.{
    HelloWorld, Styles, MarginsCursor, OpacityTransforms, Watermark, Background,
    LayoutBox, LayoutRow, LayoutColumn, PageTemplates, NamedStyles,
    TableSimple, TableZebra, TableReceipt, TableInvoice,
    CfdiInvoice, RvReceipt, DebugGrid, Avatar, ComponentsShowcase,
    FontShowcase, ImageShowcase, ImageBackground, BarcodeQr
  }

  def list do
    [
      {"hello_world", "Hello World", "Basic text on a page", &HelloWorld.render/0},
      {"styles", "Styled Text", "CSS-like styles: bold, colors, sizes", &Styles.render/0},
      {"margins_cursor", "Margins & Cursor", "Margins, cursor tracking, spacers", &MarginsCursor.render/0},
      {"opacity_transforms", "Opacity & Transforms", "Fill/stroke opacity, rotation, scaling", &OpacityTransforms.render/0},
      {"watermark", "Watermark", "Text watermark with opacity and rotation", &Watermark.render/0},
      {"background", "Background Color", "Colored page background", &Background.render/0},
      {"layout_box", "Layout: Box", "Box container with padding, border, background", &LayoutBox.render/0},
      {"layout_row", "Layout: Row", "Horizontal row distribution by weight", &LayoutRow.render/0},
      {"layout_column", "Layout: Column", "Vertical column stacking", &LayoutColumn.render/0},
      {"page_templates", "Page Templates", "Header/footer on every page", &PageTemplates.render/0},
      {"named_styles", "Named Styles", "Define reusable styles by name (like CSS classes)", &NamedStyles.render/0},
      {"table_simple", "Table: Simple", "Basic styled table with header", &TableSimple.render/0},
      {"table_zebra", "Table: Zebra Stripes", "Alternating row colors with rounded border", &TableZebra.render/0},
      {"table_receipt", "Table: Receipt", "Point-of-sale receipt style", &TableReceipt.render/0},
      {"table_invoice", "Table: Invoice", "Professional invoice with totals", &TableInvoice.render/0},
      {"cfdi_invoice", "CFDI (Direct API)", "Mexican invoice using direct API calls", &CfdiInvoice.render/0},
      {"rv_receipt", "RV Receipt (Direct API)", "Reservation receipt using direct API calls", &RvReceipt.render/0},
      {"avatar", "Avatar", "Circular avatars with initials, border, and elevation", &Avatar.render/0},
      {"components_showcase", "Components Showcase", "Divider, Badge, Chip, Progress, Card", &ComponentsShowcase.render/0},
      {"debug_grid", "Debug Grid", "Grid overlay with margin outline and cursor position", &DebugGrid.render/0},
      {"font_showcase", "Font Showcase", "All 14 built-in fonts with variants and sizes", &FontShowcase.render/0},
      {"image_showcase", "Image Types", "PNG images from binary data — solid, gradient, checker, scaling", &ImageShowcase.render/0},
      {"image_background", "Image Background", "Full-page image background with dot pattern and gradient", &ImageBackground.render/0},
      {"barcode_qr", "Barcode & QR", "Code 128 barcodes and QR codes — pure Elixir encoding", &BarcodeQr.render/0}
    ]
  end
end
