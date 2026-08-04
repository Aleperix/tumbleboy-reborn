# Packs de la comunidad (TumbleBoy Reborn)

Aquí viven los packs de niveles que se pueden descargar desde el juego
(Menú → **Packs comunitarios → Packs online**). El juego lee `index.json`
de esta carpeta y descarga los ZIP a `user://tumbleboy_packs/`.

Packs actuales:

| id | Niveles | Generador |
|----|---------|-----------|
| `numeros` | `0, 2, 4, 6, 8, 10` (6) | `tools/gen_packs.py` |
| `letras`  | `B, D, F, H, J, L, N, P, R, T, V, X, Z` (13) | `tools/gen_packs.py` |

`tools/gen_packs.py` renderiza cada glifo con DejaVuSans-Bold y genera un nivel
cuyo corredor traza el contorno "neón" del glifo (2-3 tiles de ancho, ojos
interiores unidos con puentes, inicio y meta en los extremos más lejanos y un
bumper + una rampa como decoración fácil). Emite los ZIP, las miniaturas PNG y
`index.json`. Los niveles se validan con `tests/PackLevelsTest.tscn` (BFS de
meta alcanzable).

## Cómo funciona un pack

Un pack es un ZIP (compresión store, sin encriptar) con esta estructura:

```
mi_pack.zip
├── manifest.json
└── levels/
    ├── nivel1.txt
    └── nivel2.txt
```

`manifest.json`:

```json
{
  "name": "Mi pack",
  "author": "Tu nombre",
  "description": "Unos niveles divertidos.",
  "levels": ["levels/nivel1.txt", "levels/nivel2.txt"]
}
```

## Cómo crear un pack

1. Abre el **Editor de niveles** (Menú → Editor de niveles).
2. Pinta tus niveles y guárdalos (G).
3. En **Packs propios → Crear nuevo pack** elige el título, el autor y la
   descripción, ordena los niveles y pulsa crear.
4. Usa **Exportar pack** para copiar el ZIP a una carpeta (compartirlo por
   redes sociales, etc.).

También puedes crear el ZIP a mano con la estructura de arriba.

## Cómo aportar un pack al juego

1. Crea tu pack y una miniatura PNG (cuadrado, p. ej. 128×128) llamada
   `<id>.png`.
2. Añade el ZIP como `packs/<id>.zip`, la miniatura como `packs/<id>.png`
   y una entrada nueva al final de `packs/index.json`:

   ```json
   {
     "id": "mi_pack",
     "name": "Mi pack",
     "author": "Tu nombre",
     "description": "Unos niveles divertidos.",
     "thumbnail": "packs/mi_pack.png"
   }
   ```

3. Abre un Pull Request. El mantenedor lo prueba (niveles válidos, sin
   nada raro dentro del ZIP) y lo mergea. El juego lo mostrará a todo el
   mundo la próxima vez que refresque la lista.

## Notas

- El juego **solo descarga**; nunca sube nada desde el dispositivo.
- Los niveles dentro del ZIP deben respetar el formato de nivel de TumbleBoy
  (ver `docs/tumbleboy-level-format.md`).
- `id` debe ser único, sin espacios ni caracteres raros.
- Cada pack tiene su propio guardado (3 zócalos por pack, ver `docs/API.md`).
