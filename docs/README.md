# Lost Games XO — Port a Godot

Port nostálgico de 5 juegos perdidos de la era XO/Ceibal (OLPC de Uruguay) a un
solo proyecto **Godot 3.6 + renderer GLES2** para Android (teléfono y TV con
gamepad), corriendo incluso en cajas Android genéricas con chips **Rockchip
(RK3128 / RK3328, Mali-400/450, OpenGL ES 2.0)** y **1 GB de RAM**.

> Fidelidad: cada juego debe **verse y jugarse igual** que el original.
> No se reinventa mecánica ni estética: se portan los assets y la lógica tal cual.

## Los juegos

| # | Juego | Género | Ficha |
|---|-------|--------|-------|
| 1 | **TumbleBoy** | Marble-platformer pseudo-3D | [game-tumbleboy.md](game-tumbleboy.md) |
| 2 | **RedBird** | Puzle de reacciones en cadena | [game-redbird.md](game-redbird.md) |
| 3 | **Fruitix** | Arcade de atrapar frutas | [game-fruitix.md](game-fruitix.md) |
| 4 | **HeadCat** | Puzle de programación visual | [game-headcat.md](game-headcat.md) |
| 5 | **Jump** | Solitario de canicas (peg) | [game-jump.md](game-jump.md) |

## Origen de los assets

- Carpeta analizada: `Juegos Lost Media XO/` (colección encontrada en un PC).
- 4 juegos son actividades **Sugar** (`activity/activity.info` con bundle
  `net.coderanger.olpc.*`) empaquetadas en un instalador **Inno Setup** con
  **Python 2.7 + pygame** embebido, ejecutado bajo Wine.
- Los assets se copiaron **tal cual** a `assets/<juego>/` (PNG, WAV, OGG, texto).
- La música en formatos antiguos (`.mid`, `.mod`, `.xm`) se convirtió a OGG.

## Estructura del proyecto

```
docs/                Documentación (este índice, fichas, formatos, Android)
assets/
  tumbleboy/         data/ (niveles .txt, temas, sonidos, menús)
  redbird/           data/ (sprites y sonidos)
  fruitix/           data/ + levels/ + music_ogg/ (música convertida)
  headcat/           graphics/ + levels/ + music_ogg/ (música convertida)
  jump/              data/ (canicas, banderas, sonidos)
scenes/              Escenas .tscn (menú principal + una escena por juego)
scripts/             Scripts GDScript por juego (un directorio por juego)
autoload/            AudioManager, SaveData, InputManager
ui/                  Controles táctiles, menús con foco D-pad
```

## Decisiones técnicas (resumen)

| Decisión | Valor | Motivo |
|----------|-------|--------|
| Motor | Godot 3.6.x (no 4.x) | 4.x exige OpenGL ES 3.0 en Android; los chips RK3128/RK3328 (Mali-400/450) solo tienen ES 2.0 |
| Renderer | GLES2 | Requisito hardware y de RAM de 1 GB |
| minSdk | 21 | Nativo de Godot 3.6; restaura el requisito API 21 |
| APK | arm64-v8a + armeabi-v7a + x86, landscape | Cubre cajas Android baratas y teléfonos |
| Package | `org.lostgames.xo` | Identidad de la app |
| Ventana base | 1200×825 (TumbleBoy 1100×825) | Resolución nativa de los originales |
| Entrada | InputMap unificado + capa táctil + D-pad | Jugar igual en teléfono y TV |
| Niveles TumbleBoy | Formato `.txt` fiel + editor visual | El original los crea como texto sin editor |
| HeadCat | Incluye editor de niveles | Es parte del juego original |
| Música | `.mid`→OGG con fluidsynth+FluidR3 GM; `.mod`/`.xm`→OGG con openmpt123 | Melodías fieles |

## Hardware objetivo

- **Teléfonos Android**: cualquier equipo con Android 5.0+ (API 21+), touch.
- **TV Android / TV Box**: D-pad del control/remoto + botones Confirmar y Atrás.
- **Cajas genéricas (RK3128/RK3328, 1 GB RAM)**: funcionan porque usamos GLES2
  y texturas livianas (los sprites originales son PNG pequeños).

Ver [ANDROID.md](ANDROID.md) para exportar y probar.

## Herramientas usadas

- `paru -S godot3-bin godot3-export-templates` (AUR, Godot 3.6.2).
- Godot 4.7 no puede usarse (OpenGL ES 3.0 obligatorio en Android).
- `fluidsynth` + `FluidR3_GM.sf2` → `.mid` a WAV.
- `openmpt123` (libopenmpt) → `.mod`/`.xm` a WAV.
- `ffmpeg` → WAV a OGG (Vorbis).

Nota: si `godot3-bin` se instala por AUR requiere `sudo`; también se puede
extraer el paquete y ejecutar el binario directo (ver Fase 0 del desarrollo).
