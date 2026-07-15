defmodule Pdf.DevServer.Examples.Map.CfeReceipt do
  @moduledoc """
  Recibo CFE — réplica visual del aviso MEZETA (layout calibrado por coordenadas).

  El diseño (posiciones, tablas, colores, proporciones) vive en
  `Pdf.DevServer.Examples.Map.CfeReceipt.Layout`. La tipografía se puede
  cambiar después sin tocar el layout.

  Ver: `/pdf/map/cfe_receipt`
  """

  alias Pdf.DevServer.Examples.Map.CfeReceipt.Layout

  def render, do: render_with_data(mock_data())

  def render_with_data(data) do
    doc =
      Pdf.new(
        size: :a4,
        margin: %{top: 8, bottom: 8, left: 8, right: 8},
        compress: false
      )

    template = [
      %{
        type: :custom,
        props: %{
          callback: fn d -> Layout.render(d, data) end
        }
      }
    ]

    Pdf.Builder.render_into(doc, template)
  end

  defp mock_data do
    %{
      rfc_line: "CFE SUMINISTRADOR DE SERVICIOS BÁSICOS  RFC: CSS160330CP7",
      company_line: "Av. Paseo de la Reforma 164, Col. Juárez, Alcaldía Cuauhtémoc,",
      company_line2: "C.P. 06600, Ciudad de México",
      customer_name: "MEZETA SANTOS EUNICE",
      customer_address1: "CERRADA 5 DE MAYO MZ 2 LT 12",
      customer_address2: "COL. EMILIANO ZAPATA",
      customer_address3: "C.P. 56607, VALLE DE CHALCO SOLIDARIDAD, MÉXICO",
      total_display: "$2,679",
      total_words: "DOS MIL SEISCIENTOS SETENTA Y NUEVE PESOS M.N.",
      billing_period: "25 ENE 23 - 27 MAR 23",
      service_number: "773991000533",
      rmu: "773991000533-1",
      barcode_data: "773991000533000000267947",
      barcode_top: "773991000533 000000267947",
      barcode_bottom: "01 773991000533 230327 000002679 0",
      qr_payload: "https://app.cfe.mx/AvisoRecibo?svc=773991000533",
      consumption_percent: 58,
      gauge_label: "Este gráfico refleja tu nivel de consumo respecto al límite de excedente",
      print_info:
        "Fecha, hora y lugar de impresión: 27 MAR 2023 14:22:15 hrs. Av. Santa Ana 2994 Ex Ejido de San Francisco Culhuacan Coyoacan D.F.",
      service_stack: [
        {"CORTE A PARTIR:", "05 JUN 23"},
        {"LÍMITE DE PAGO:", "27 ABR 23"},
        {"TARIFA:", "01"},
        {"NO. MEDIDOR:", "G123AB4567"},
        {"MULTIPLICADOR:", "1"},
        {"PERIODO:", "BIMESTRAL"}
      ],
      consumption_body: [
        ["Energía (kWh)", "", "", "", "", "", "", ""],
        ["Básico", "01273", "", "01150", "", "123", "0.793", "$97.53"],
        ["Intermedio", "—", "", "—", "", "—", "—", "—"],
        ["Excedente", "—", "", "—", "", "—", "—", "—"],
        ["Suma", "", "", "", "", "123", "", "$97.53"]
      ],
      costs: [
        ["Suministro", "—", "—", "—", "$45.20"],
        ["Distribución", "—", "—", "—", "$892.15"],
        ["Transmisión", "—", "—", "—", "$156.80"],
        ["CENACE", "—", "—", "—", "$78.40"],
        ["Energía", "—", "—", "—", "$97.53"],
        ["Capacidad", "—", "—", "—", "$234.50"],
        ["SCnMEM", "—", "—", "—", "$12.30"]
      ],
      breakdown: [
        {"Energía", "$2,308.17"},
        {"IVA 16%", "$369.31"},
        {"Fac. del Periodo", "$2,677.48"},
        {"DAP", "$0.00"},
        {"Adeudo Anterior", "$0.00"},
        {"Su Pago", "$0.00"},
        {"Total", "$2,679.47"}
      ]
    }
  end
end
