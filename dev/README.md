# Pdf Dev Server

Servidor de desarrollo para previsualizar y probar diseños PDF generados con `elixir-pdf`.

## Iniciar el servidor

```bash
mix pdf.server
```

El servidor se inicia en **http://localhost:4200**.

### Puerto personalizado

```bash
mix pdf.server --port 3000
```

## Uso

1. Abre **http://localhost:4200** en tu navegador
2. En la barra lateral izquierda verás la lista de ejemplos disponibles
3. Haz clic en cualquier ejemplo para ver el PDF renderizado en tiempo real
4. Usa el botón **Reload** (o tecla `R`) para regenerar el PDF actual
5. Usa el botón **Download** para descargar el PDF generado

## Ejemplos incluidos

| Ejemplo | Descripción |
|---------|-------------|
| **Hello World** | Texto básico en una página |
| **Styled Text** | Estilos CSS-like: bold, colores, tamaños |
| **Margins & Cursor** | Márgenes, cursor tracking, spacers |
| **Opacity & Transforms** | Opacidad fill/stroke, rotación, escalado |
| **Watermark** | Marca de agua con opacidad y rotación |
| **Background Color** | Fondo de página con color |
| **Layout: Box** | Contenedor box con padding, border, background |
| **Layout: Row** | Distribución horizontal por peso |
| **Layout: Column** | Apilado vertical |
| **Page Templates** | Header/footer automático en cada página |
| **Builder API** | PDF declarativo desde lista de templates |
| **Full Document** | Documento completo con todas las features |

## Agregar nuevos ejemplos

Edita `dev/pdf/dev_server/examples.ex` y agrega una entrada en la función `list/0`:

```elixir
def list do
  [
    # ... ejemplos existentes ...
    {"mi_ejemplo", "Mi Ejemplo", "Descripción corta", &mi_ejemplo/0}
  ]
end

defp mi_ejemplo do
  Pdf.new(size: :a4, margin: 40)
  |> Pdf.set_font("Helvetica", 14)
  |> Pdf.text("Mi texto de prueba")
end
```

Recarga la página para ver el nuevo ejemplo — no necesitas reiniciar el servidor.

## Estructura

```
dev/
├── README.md                        # Este archivo
└── pdf/
    ├── dev_server.ex                # Plug router + UI HTML
    └── dev_server/
        └── examples.ex              # Definición de ejemplos PDF
```

## Notas

- El servidor es **solo para desarrollo** (`only: :dev` en mix.exs)
- Las dependencias (`plug_cowboy`, `jason`) no se incluyen en el paquete hex
- La carpeta `dev/` no se publica en hex (excluida de `files` en `package()`)
- Los PDFs se generan en cada request, así que los cambios al código se reflejan al recargar
