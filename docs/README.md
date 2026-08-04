# Documentación — TumbleBoy Reborn

Índice de toda la documentación del proyecto. Está escrita para reflejar
**únicamente el estado actual** del juego (TumbleBoy), sin referencias a otros
proyectos.

## Índice

| Documento | Contenido |
|-----------|-----------|
| [game-tumbleboy.md](game-tumbleboy.md) | Ficha del juego: cómo se juega, física, constantes, temas, sonidos |
| [tumbleboy-level-format.md](tumbleboy-level-format.md) | Formato de los niveles `.txt` (atributos, símbolos del mapa, ejemplo) |
| [API.md](API.md) | Referencia técnica completa: autoloads, scripts, constantes, escenas, formatos, tests |
| [ANDROID.md](ANDROID.md) | Cómo compilar el APK, minSdk/ABI, despliegue en caja/TV |
| [../packs/README.md](../packs/README.md) | Cómo funciona un pack, crearlos y aportarlos a la comunidad |

## El juego en una frase

TumbleBoy Reborn es un *marble-platformer* pseudo-3D: controlas a un niño-bola
sobre un tablero de bloques con alturas reales, llegas al bloque **meta** y
avanzas por los 21 niveles del modo historia o por packs de la comunidad.
Incluye editor de niveles y guardado por zócalos de memoria.

## Cómo navegar el menú

```
MainMenu
├── Modo historia ──► StoryHub (Nueva partida / Continuar / Volver)
│                       └── SlotPicker (3 zócalos + "Sin guardado")
├── Packs comunitarios ──► Packs descargados ──► SlotPicker (3 zócalos por pack)
│                        └── Packs online ──► descargar pack
├── Editor de niveles ──► Niveles propios (Jugar / Editar)
│                       ├── Packs propios (Jugar / Crear nuevo)
│                       └── Nuevo nivel ──► editor
└── Salir
```

## Decisiones técnicas (resumen)

| Decisión | Valor | Motivo |
|----------|-------|--------|
| Motor | Godot 3.6.x (no 4.x) | 4.x exige OpenGL ES 3.0 en Android; los chips RK3128/RK3328 (Mali-400/450) solo tienen ES 2.0 |
| Renderer | GLES2 | Requisito hardware y de RAM de 1 GB |
| minSdk | 21 | Mínimo nativo de Godot 3.6 (Android 5.0+) |
| ABI | arm64-v8a + armeabi-v7a + x86, landscape | Cubre cajas Android baratas y teléfonos |
| Ventana base | 1200×825 (TumbleBoy 1100×825, offset 50 px) | Resolución nativa del original escalada |
| Entrada | InputMap unificado + D-pad + táctil | Jugar igual en teléfono y TV |
| Niveles | Formato `.txt` fiel + editor visual | El original los crea como texto sin editor |
| Guardado | `user://save_slots.json`, 3 zócalos por modo | Los zócalos de memoria de la versión original |
| Packs | ZIP (store) + `manifest.json`, lector/escritor GDScript propio | `ZIPReader` no está compilado en este build de Godot |
| Packs online | Descarga desde GitHub (API + ETag/304), solo lectura | El juego nunca sube nada |
| Música | `.mid`→OGG con fluidsynth+FluidR3 GM; `.mod`/`.xm`→OGG con openmpt123 | Melodías fieles |

## Hardware objetivo

- **Teléfonos Android**: cualquier equipo con Android 5.0+ (API 21+), touch.
- **TV Android / TV Box**: D-pad del control/remoto + botones Confirmar y Atrás.
- **Cajas genéricas (RK3128/RK3328, 1 GB RAM)**: funcionan porque usamos GLES2
  y texturas livianas (los sprites originales son PNG pequeños).

Ver [ANDROID.md](ANDROID.md) para exportar y probar.

## Herramientas de desarrollo

- `paru -S godot3-bin godot3-export-templates` (AUR, Godot 3.6.2).
- `fluidsynth` + `FluidR3_GM.sf2` → `.mid` a WAV.
- `openmpt123` (libopenmpt) → `.mod`/`.xm` a WAV.
- `ffmpeg` → WAV a OGG (Vorbis).
