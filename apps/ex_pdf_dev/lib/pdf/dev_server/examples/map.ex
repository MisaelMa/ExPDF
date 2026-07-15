defmodule Pdf.DevServer.Examples.Map do
  @moduledoc false

  alias Pdf.DevServer.Examples.Map.{Builder, CfdiMaps, CfeReceipt, RvMaps, FullDocument, AvatarMap}

  def list do
    [
      {"builder", "Builder API", "Declarative PDF from template list", &Builder.render/0},
      {"cfdi_maps", "CFDI (Style Maps)", "Mexican invoice using style maps %{x:, y:, bold:}", &CfdiMaps.render/0},
      {"cfe_receipt", "CFE Recibo (Builder)", "Recibo CFE con boxes, KeyValue, tablas y QR", &CfeReceipt.render/0},
      {"rv_maps", "RV Receipt (Style Maps)", "Reservation receipt using style maps", &RvMaps.render/0},
      {"full_document", "Full Document", "Complete document with all features", &FullDocument.render/0},
      {"avatar_map", "Avatar (Maps)", "Avatars with initials, border, elevation via maps", &AvatarMap.render/0}
    ]
  end
end
