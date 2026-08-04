# TumbleBoy Reborn

Reencarnación del clásico de puzzle **TumbleBoy** (marble-platformer pseudo-3D)
hecha en **Godot 3.6** con renderer **GLES2**, pensada para jugar en Android
(teléfono y TV con gamepad) y en cajas genéricas con chips **Rockchip
(RK3128 / RK3328, Mali-400/450, OpenGL ES 2.0)** con 1 GB de RAM.

Incluye el **modo historia** con los 21 niveles originales, un sistema de
**guardado por zócalos de memoria**, un **editor de niveles** visual y un
sistema de **packs de la comunidad** descargables desde el propio juego.

> Fidelidad: TumbleBoy se ve y se juega igual que el original. No se reinventa
> mecánica ni estética: se portan los assets y la lógica tal cual, y el editor
> permite crear niveles y packs en el mismo formato.

## Contenido

- **Modo historia** — los 21 niveles originales de `res://` sin cambios, con
  guardado en 3 zócalos por partida (Nueva partida / Continuar / Sin guardado).
- **Packs comunitarios** — dos secciones:
  - *Packs descargados*: los packs instalados localmente, con su propio guardado
    (3 zócalos por pack).
  - *Packs online*: catálogo descargado desde el repo con thumbnail, título,
    creador y descripción; confirmación antes de descargar.
- **Editor de niveles** — pintar niveles, añadir créditos (autor/descripción),
  jugar tus niveles, crear packs propios (ZIP + `manifest.json`) y exportarlos.
- **Quick play** — jugar historia o niveles sueltos sin guardar nada.

## Requisitos y ejecución

- Godot 3.6.x (motor, no editor necesario para correr).
- Lanzar el juego: `godot3 --path .`
- Menú principal: **Modo historia** · **Packs comunitarios** · **Editor de niveles** · **Salir**

Controles unificados (ver [docs/API.md](docs/API.md#inputmanager)):

| Acción | Teclado | Gamepad / TV |
|--------|---------|--------------|
| Mover | Flechas / WASD | D-pad / palanca |
| Confirmar | Enter / Espacio | A / Start |
| Atrás | ESC / Retroceso | B / Back |

## Estructura del proyecto

```
README.md              Este archivo
docs/                  Documentación completa (índice, ficha, formatos, API, Android)
assets/tumbleboy/      data/ (niveles .txt, temas, sonidos, menús) + icono
assets/ui/fonts/       Fuente DejaVu para la interfaz
packs/                 index.json + packs oficiales (ZIP + thumbnails)
scenes/                Escenas .tscn (MainMenu, hubs, SlotPicker, TumbleBoy, editor)
scripts/tumbleboy/     Gameplay + editor + packs (lector/escritor ZIP, store)
scripts/ui/            Hubs y menús con foco D-pad
autoload/              AudioManager, SaveData, InputManager, LevelQueue
tests/                 SmokeTest (headless) + OnlineTest (requiere red) + PackLevelsTest
tools/                 gen_packs.py (genera los packs Números y Letras)
icon.svg               Icono de la aplicación (bola TumbleBoy)
```

Documentación: empieza en [docs/README.md](docs/README.md).

## Pruebas

```sh
# Smoke test (headless, sin red): niveles, física, editor, zócalos, hubs, menú
godot3 --headless --path . res://scenes/SmokeTest.tscn

# Pack test (headless, sin red): cada nivel de packs/ es jugable (BFS)
godot3 --headless --path . res://tests/PackLevelsTest.tscn

# Online test (requiere red): índice de packs, ETag/caché, descarga, thumbnail
godot3 --path . res://tests/OnlineTest.tscn
```

Ambos deben imprimir `ALL PASS` (ver `tests/`).

## Licencia y atribución

TumbleBoy original: TeamLibya. Assets originales portados tal cual a
`assets/tumbleboy/`. Packs oficiales en `packs/` creados por la comunidad.
