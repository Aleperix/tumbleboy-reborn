# TumbleBoy Reborn — Port a Godot

Reencarnación del juego perdido de la era XO/Ceibal (OLPC de Uruguay) en
**Godot 3.6 + renderer GLES2** para Android (teléfono y TV con gamepad),
corriendo incluso en cajas Android genéricas con chips **Rockchip
(RK3128 / RK3328, Mali-400/450, OpenGL ES 2.0)** y **1 GB de RAM**.

> Fidelidad: TumbleBoy debe **verse y jugarse igual** que el original.
> No se reinventa mecánica ni estética: se portan los assets y la lógica tal cual.
> Además del juego hay un **editor de niveles** y un sistema de **packs de la
> comunidad** descargables desde el propio juego.

Los otros juegos del conjunto "Lost Games XO" (RedBird, Fruitix, HeadCat,
Jump) se recrearán **en proyectos separados** más adelante; sus fichas quedan
archivadas en `docs/` como referencia para ese trabajo.

## El juego

- **TumbleBoy** (marble-platformer pseudo-3D): ficha en
  [game-tumbleboy.md](game-tumbleboy.md).
- **Modo historia**: los 21 niveles originales de `res://` sin cambios.
- **Niveles y packs**: selector con Historia / Packs instalados / Packs online
  / Mis niveles. Los packs se descargan desde el repo
  `Aleperix/tumbleboy-reborn` (ver `packs/README.md` para aportar niveles).
- **Editor de niveles**: pinta niveles, añade créditos (autor/descripción),
  crea y exporta packs (ZIP + `manifest.json`).

## Origen de los assets

- Carpeta analizada: `Juegos Lost Media XO/` (colección encontrada en un PC).
- El juego original era una actividad **Sugar** empaquetada en un instalador
  **Inno Setup** con **Python 2.7 + pygame** embebido, ejecutado bajo Wine.
- Los assets se copiaron **tal cual** a `assets/tumbleboy/` (PNG, WAV, OGG,
  texto). La música en formatos antiguos (`.mid`, `.mod`, `.xm`) se convirtió
  a OGG.

## Estructura del proyecto

```
docs/                Documentación (este índice, fichas, formatos, Android)
assets/tumbleboy/    data/ (niveles .txt, temas, sonidos, menús)
packs/               index.json + packs de la comunidad (ZIP + thumbnails)
scenes/              Escenas .tscn (menú, TumbleBoy, selector, editor)
scripts/tumbleboy/   Gameplay + zip_writer/zip_reader + pack_reader + pack_store
autoload/            AudioManager, SaveData, InputManager, LevelQueue
ui/                  Controles táctiles, menús con foco D-pad
tests/               SmokeTest (headless) + OnlineTest (requiere red, en ventana)
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
| Packs | ZIP (store) + `manifest.json`, lector/escritor GDScript propio | ZIPReader no está compilado en este build de Godot |
| Packs online | Descarga desde GitHub (API + ETag/304), solo lectura | El juego nunca sube nada |
| Música | `.mid`→OGG con fluidsynth+FluidR3 GM; `.mod`/`.xm`→OGG con openmpt123 | Melodías fieles |

## Hardware objetivo

- **Teléfonos Android**: cualquier equipo con Android 5.0+ (API 21+), touch.
- **TV Android / TV Box**: D-pad del control/remoto + botones Confirmar y Atrás.
- **Cajas genéricas (RK3128/RK3328, 1 GB RAM)**: funcionan porque usamos GLES2
  y texturas livianas (los sprites originales son PNG pequeños).

Ver [ANDROID.md](ANDROID.md) para exportar y probar.

## Herramientas usadas

- `paru -S godot3-bin godot3-export-templates` (AUR, Godot 3.6.2).
- Godot 4.x no puede usarse (OpenGL ES 3.0 obligatorio en Android).
- `fluidsynth` + `FluidR3_GM.sf2` → `.mid` a WAV.
- `openmpt123` (libopenmpt) → `.mod`/`.xm` a WAV.
- `ffmpeg` → WAV a OGG (Vorbis).

Nota: si `godot3-bin` se instala por AUR requiere `sudo`; también se puede
extraer el paquete y ejecutar el binario directo (ver Fase 0 del desarrollo).
