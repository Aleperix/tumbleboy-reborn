# RedBird — Ficha y port

**Género:** puzle de reacciones en cadena (posicionar 11 nubes para guiar a un pájaro).
**Bundle Sugar:** `net.coderanger.olpc.redbird`.
**Resolución original:** **1200×825**.
**Port nº:** 2.

## Cómo se juega

- En cada nivel hay **11 nubes** desplegadas en el cielo. El jugador las **mueve
  con las flechas ↑↓ Enter (Confirmar) y ESC (Back)** para formar una escalera.
- El pájaro, cuando arranca, vuela y **rebota contra cada nube** en cadena.
  El nivel se gana cuando el pájaro recorre todas las nubes sin caer.
- Las nubes tienen un **tiempo de liberación** (`release`) creciente por nivel;
  después de ese tiempo se activan y el pájaro puede empezar.
- Un **contador de Enters** (número de veces que pulsaste Confirmar) hace las
  veces de puntuación: cuanto menos, mejor.

## Niveles (hardcodeados en el original, se portan igual)

| Nivel | Release (ms) | Notas |
|-------|--------------|-------|
| 1 | 3000 | Introducción |
| 2 | 2100 | |
| 3 | 1700 | |
| 4 | 1000 | Nivel final |

> En el original `world.py` define el nivel y `cloud.py` la clase `CloudSprite`.
> El port los conserva como datos del juego, no como archivos.

## Assets (`assets/redbird/data/`)

- Pájaro `bird.png`, 4 variantes de nube × color (blanco `cloud_white*`, gris
  `cloud_gray*`, amarillo `cloud_yellow*`, y una "L" grande `cloud_whiteL*`).
- Árboles `tree_1..4.png`, fondos y pantallas: `splash_screen`, `instruction_screen`,
  `credits_screen`, `scoreboard`, `endmovie_1..4` (+ variantes `.2`).
- Contadores: `clock_counter.png`, `hand_counter.png`, `clock_icon.png`, `hand.png`.
- **Notas musicales WAV** `c.wav` … `g.wav` (las nubes hacen sonidos al rebotar).

## Port (GDScript)

- `scripts/redbird/` — `World` (estado del nivel, nubes, liberación), `CloudSprite`,
  `Bird` (rebotes en cadena), pantallas (splash/instrucciones/juego/victoria).
- En teléfono: mover nubes con el **virtual pointer** (toque directo) o D-pad +
  Confirmar; en TV con el D-pad del control.
- La lógica de cadena se copia tal cual de `world.py`/`cloud.py`.
