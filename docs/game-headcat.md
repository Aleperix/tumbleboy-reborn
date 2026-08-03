# HeadCat — Ficha y port

**Género:** puzle de programación visual (programar un robot para que llegue a un gatito).
**Bundle Sugar:** `net.coderanger.olpc.headcat`.
**Resolución original:** **1200×825** (celda `CELL_SIZE = 64`).
**Port nº:** 4.

## Cómo se juega

- Un **robot** debe llegar hasta un **gatito**. En lugar de moverlo a mano, el
  jugador **programa reglas** en un "cerebro cebra" (`brain_window.png`):
  cada regla combina un **sentido** (ver, tocar, cabeza, pies), un **objeto**
  (piso, cielo, robot, pelota…) y una **acción** (mover, girar, detener, taladrar).
- El robot ejecuta las reglas en orden; cuando una condición se cumple, hace la
  acción asociada. Resolver el nivel = que el robot llegue al gatito.
- El gato puede estar en el piso, flotando (hay que **inflar globos**) o bloqueado
  (taladrar **hielo**).
- El juego incluye un **editor de niveles** de desarrollo: se carga con un botón y
  permite crear niveles propios (el usuario pidió conservarlo).

## Niveles y editor

- **9 niveles** en `assets/headcat/levels/*.lev` (`00,01,03,04,05,06,adam3,adam4,saved`).
- Formato `.lev` (texto) del original; se parsea en GDScript (el editor lo usa
  para leer/escribir el mismo formato).
- El `saved.lev` es un nivel guardado de ejemplo.
- `HeadCat.py` original = 1141 líneas; `Level.py` + `constants.py` + `graphics/`.

## Assets (`assets/headcat/graphics/`)

- Robot: `robot_right1/2`, `robot_drilling1..4`, `robot_falling_right*`,
  `robot_finds_kitten1..7`.
- Acciones: `action_left/right/turnaround/stop/drill/magnet/balloon/blank/none`.
- Sentidos: `sense_see(_alt)/touch/head/feet/empty`.
- Objetos: `object_floor/sky/robot/blank`.
- Cerebro: `brain_window.png`, `brain_mockup.png`, `zebra_even/odd.png`,
  `attachment_*`, `motivation_*`, `checkmark.png`.
- Mundo: `background_beach/savannah/winter.png`, `block.png`, `iceblock.png`,
  `steel.png`, `magnet.png`, `pizza.png`, `kitten.png`, `balloon*`, `familiar_*`.
- UI: `titlescreen.png`, `level-choose.png`, `goplay_*`, `backbutton*`,
  `quitbutton*`, `scrollarrow_*`.

## Música (convertida a OGG en `music_ogg/`)

| MIDI original | OGG | Uso |
|---------------|-----|-----|
| `morn2.mid` | `morn2.ogg` | Menú |
| `proprietarypiano.mid` | `proprietarypiano.ogg` | Nivel |
| `proprietarypiano2.mid` | `proprietarypiano2.ogg` | Nivel alterno |
| `win.mid` | `win.ogg` | Victoria |
| `gamejam.mid` | — | **0 bytes** (vacío, no se convierte) |

> Conversión: `fluidsynth -ni -F out.wav FluidR3_GM.sf2 <archivo>.mid` → `ffmpeg` a OGG.

## Port (GDScript)

- `scripts/headcat/` — `HeadCat` (escena y bucle), `Level` (parser `.lev`),
  `Brain` (reglas sentido→objeto→acción + motor de ejecución), `Editor`
  (editor de niveles).
- En TV: seleccionar sentido/objeto/acción con D-pad + Confirmar; editar con el
  virtual pointer en teléfono.
