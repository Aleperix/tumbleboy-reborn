# Fruitix — Ficha y port

**Género:** arcade de atrapar frutas con una canasta.
**Bundle Sugar:** `net.coderanger.olpc.fruitix`.
**Resolución original:** **1200×825**.
**Port nº:** 3.

## Cómo se juega

- La canasta se mueve en la **parte inferior** (flechas / joystick / D-pad).
- Caen **frutas** desde arriba; hay que atraparlas. Dejar caer frutas o que caigan
  en el suelo resta.
- Un **mono** ataca (roba/estorba), y un **camión** llega para recoger la fruta.
- **Tienda** (`Shop`): entre niveles se compran mejoras con la plata ganada:
  canasta más grande (`basket`) y zapatos para moverse más rápido (`shoes`).
- **Récords** (`HighScores`): tabla de puntajes guardada en `scores.txt`.

## Niveles

- **10 niveles** en `assets/fruitix/levels/level1.txt` … `level10.txt`, con
  configuración por nivel (tiempos, tipos de fruta, fallos permitidos).
- El parser del original (`Level.py`) se traduce a GDScript para leer los mismos
  archivos de texto.

## Assets (`assets/fruitix/`)

- Sprites: canasta (`b_bask_*`, `b_stay_*`), frutas (`f_turn_*`), mono
  (`m_move1/2`), camión (`tr_*`), tablero/UI (`board.png`, `UI.png`), pantallas
  (`fruitix_logo`, `win.png`, `lose.png`, `credits.png`), tienda (`sh_*`, `sc_*`),
  high scores (`hs_bg`, `hs_enter`), iconos de idiomas (`lang1..7`).
- **Sonidos OGG (11):** `fruit_pick`, `fruit_eat`, `monkey_attack`, `truck_deposit`,
  `truck_drives_in`, `cash_register`, `select_option`, `change_option`, `no_fruit`,
  `timer_warning`, `alarm_final`.
- **Música (convertida a OGG en `music_ogg/`):**
  - `jos_brb.mod` (4:34 al render) — menú.
  - `vodka.xm` (3:38) — nivel.
  - `jos_fuc.xm` (2:18) — nivel/tienda.
  - `highscore.xm` (1:48) — récords.
  > Conversión: `openmpt123 --render --output-type wav <archivo>` → `ffmpeg` a OGG 44.1 kHz.

## Port (GDScript)

- `scripts/fruitix/` — `Fruitix` (escena principal), `Level` (parser + bucle),
  `Menu`, `Shop`, `HighScores`.
- Las pantallas de tienda y récords son **menús con foco D-pad** para TV.
- La música se reproduce en loop (Godot `AudioStreamOGGVorbis.loop`).
