# Jump — Ficha y port

**Género:** solitario de canicas (peg solitaire) sobre un tablero de 7×7.
**Bundle Sugar:** `net.coderanger.olpc.jump`.
**Resolución original:** **1200×825**.
**Port nº:** 5.

## Cómo se juega

- Tablero **7×7** con **32 canicas** (una posición central vacía). Se juega por
  **arrastrar una canica** para saltar sobre otra adyacente y aterrizar en el hueco
  del otro lado; la canica saltada se elimina.
- El objetivo es **quedar con una sola canica** (idealmente en el centro).
- Cada vez que se elimina una canica se llega a un **flag** (bandera), y al cruzar
  un umbral se desbloquean canicas especiales con su propio sonido.

## Flags y desbloqueo

- **7 banderas** (`Flag01.png`…`Flag07.png`) que indican progreso.
- **36 canicas especiales** (`S01.png`…`S36.png`) que se desbloquean al alcanzar
  los umbrales de banderas (lista en `marble.txt` del original).
- **7 sonidos OGG** de salto por umbral (`0.ogg`…`6.ogg`), más `drop.ogg`,
  `newboard.ogg`, `pop1.ogg` y el sonido de canica que se elimina.
- Botones: `NewBoard.png`/`NewBoardOn.png` (nuevo tablero), `HelpOn/Off.png`
  (ayuda), `Instructions.png`, `Arrow*.png` (flechas de dirección de salto).

## Assets (`assets/jump/data/`)

- Canicas numeradas `0..25` (formas/clases) + `0_alpha.png`, `blank.png`,
  `Background2.png`.
- Marbles: `0_alpha`, `0`…`25`, `S01`…`S36`.
- `marble.txt` (desbloqueos) está en el directorio de la actividad original; se
  porta como dato de configuración.

## Port (GDScript)

- `scripts/jump/` — `Jump` (escena), `Board` (7×7, reglas de salto válidas),
  `Marble` (canica con drag&drop), `Flags` (progreso y desbloqueos).
- **Drag & drop en teléfono**: virtual pointer (toque = "levantar" canica, arrastrar,
  soltar). En TV: D-pad mueve el cursor entre canicas + Confirmar para saltar.
- Reglas de salto: solo movimientos ortogonales, con canica intermedia y hueco al
  otro lado (traducido de `levelBase.py`).
