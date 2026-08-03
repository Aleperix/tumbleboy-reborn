# TumbleBoy — Ficha y port

**Género:** marble-platformer pseudo-3D (la pelota sube/baja en "z" sobre un tablero de bloques).
**Autoría:** TeamLibya (Bob Rost, Chris Jackson, Eben Myers, Tom Corbett).
**Bundle Sugar:** `net.coderanger.olpc.tumbleboy`.
**Resolución original:** 640×480 escalada a **1100×825** en la XO (el resto de juegos usa 1200×825).
**Port nº:** 1 (el primero).

## Cómo se juega

- Se controla al **niño-bola** con las **flechas** (o joystick/D-pad). Empuje suave:
  `AddForce(dx, dy)` con `BALL_FORCE = 1` por segundo.
- No hay vidas ni puntos: si la bola cae por debajo de `MAX_DEPTH = -5` vuelve al
  inicio (`SOUND_LOSE_BALL`). Se supera el nivel llegando a un bloque meta `1`.
- **ESC** (Back) sale. En el menú principal, cualquier tecla empieza a jugar.
- Al ganar un nivel aparece `good_job.png` 3.5 s y pasa al siguiente automáticamente.
- Al terminar los 21 niveles se muestra `win_game.png` (10 s) con animación.

## Física (traducción fiel del original)

| Constante | Valor | Uso |
|-----------|-------|-----|
| `MAX_SPEED` | 2.0 bloques/s | Velocidad de rodadura máx. (`AddForce` la frena si excede) |
| `BUMPER_SPEED` | 4.0 | Velocidad de rebote de un bumper |
| `GRAVITY` | 8.0 | Gravedad al caer |
| `MAX_DEPTH` | -5.0 | Pérdida de la bola |
| `BALL_FORCE` | 1 | Empuje del jugador |
| `BALL_DRAG` | 0.003 | Rozamiento al rodar (`v -= v*DRAG` por frame) |
| `WALL_ELASTICITY` | 0.6 | Rebote contra muro |
| `BALL_CLIMB` | 0.75 | Altura máx. que puede subir de golpe |
| `BALL_RADIUS` | 0.45 | Radio de colisión |
| `BUMPER_HEIGHT` | 0.2 | Altura a la que chocan los bumpers |

Datos de altura (`Board.HeightAt`, unidades = bloques):
- hueco → `-5` (se cae); piso (`-` `=` `+`, inicio `$`, meta `1`, bumper `@`) → `0`;
- muro (`#` `w` `W`) → `1`; muro doble (`%` `d` `D`) → `2`;
- rampas: `<`→`x-frac(x)`, `>`→`frac(x)`, `^`→`1-frac(y)`, `v`→`frac(y)`.

Colisiones por casilla: la bola usa `HeightAt` en 4 puntos laterales (radio 0.45)
para apartarse de muros (0.02 por frame) y rebota con `WALL_ELASTICITY` si la pared
está `BALL_CLIMB` más alta.

Bumpers: colisión circular dentro de 1.0 bloque de centro a centro; la bola sale
despedida en dirección opuesta al centro a `BUMPER_SPEED`.

Animación del niño: 5 poses (reposo, derecha, izquierda, arriba, abajo) × 2 frames,
con escala por profundidad `z` (6 niveles, 0.8→1.15). Frames alternan cada 0.2 s
de "velocidad acumulada" (`anim_timer += speed*dt`).

## Niveles

- **21 niveles** en `assets/tumbleboy/data/levels/*.txt`, auto-cargados por orden
  de nombre (el original usa `glob.glob`). Mismo comportamiento en el port.
- Formato de texto completo y documentado en [tumbleboy-level-format.md](tumbleboy-level-format.md).
- Los niveles usan atributos `.boy {boy1}` (tema del niño), `.theme {spacetheme1}`
  y `.theme {beach}`; el resto usa el tema por defecto.

## Temas

- Tablero (`data/themes/`): `default`, `beach`, `spacetheme1`. Cada tema tiene
  `floor.png/f2/f3`, `wall.png/w2/w3`, `doublewall.png/...`, `startfloor.png`,
  `goal.png`, `rampright/left/up/down.png`, `bumper.png`.
- Niño (`data/themes/boy1..boy4`): sprites `tb*1.png` / `tb*2.png` de 70×81 px
  (`rest`, `right`, `left`, `up`, `down`).

## Sonidos (7 OGG)

`start_level`, `lose_ball`, `hit_wall`, `hit_ground`, `hit_bumper`, `win_level`,
`win_game`. Se disparan por umbrales: `HIT_GROUND >= 2`, `HIT_WALL >= 1`.

## Menús

- Portada `main_menu.png` con niño animado (`menu_anim1/2.png` en
  `MENU_ANIM_RECT`), victoria `win_game.png` con `win_anim1/2.png`.

## Port (GDScript)

- `scripts/tumbleboy/` — módulos por clase: `Board` (grilla, alturas, bumpers),
  `Ball` (física 3D, animación, escala por z), `Game` (bucle, niveles, cámara),
  `Levels` (parser del `.txt`), `TumbleBoy` (escena completa).
- La cámara sigue a la bola con margen `SCREEN_MARGIN` (200 px) y límites del nivel.
- Tiles de 64 px con borde de 12 px (PIXEL_BORDER) para el efecto de profundidad.
- Editor visual de niveles: paleta de bloques, pintar con tap/mouse, guardar/abrir
  archivos `.txt` del formato original, vista previa 3D con física.
