# TumbleBoy Reborn — Referencia técnica (API)

Documentación interna completa del proyecto: configuración, autoloads, scripts,
constantes, escenas, formatos de archivo y tests. Reflecte el estado actual.

## Arquitectura en una diapositiva

```
MainMenu (scenes/MainMenu.tscn)
 ├── StoryHub ───────────► SlotPicker("story")  ──► TumbleBoy.tscn
 ├── PacksCommunity ──────► [Descargados | Online]
 │      ├── SlotPicker("pack:<id>") ────────────► TumbleBoy.tscn
 │      └── PackStore (descarga ZIP desde GitHub)
 ├── EditorHub ───────────► TumbleBoyEditor.tscn
 └── Salir

Autoloads (singletons): AudioManager · SaveData · InputManager · LevelQueue
```

El flujo de datos entre hubs y la escena de juego pasa por **LevelQueue**
(secuencia a jugar) y **SaveData** (zócalos de memoria y sesión activa).

## Configuración del proyecto (`project.godot`)

| Clave | Valor |
|-------|-------|
| `application/config/name` | `TumbleBoy Reborn` |
| `application/run/main_scene` | `res://scenes/MainMenu.tscn` |
| `application/config/icon` | `res://assets/tumbleboy/icon.png` |
| `display/window/size` | 1200×825, stretch `2d`, aspect `keep` |
| `rendering/quality/driver` | `GLES2` |

Autoloads (en orden):

1. `AudioManager` — `autoload/audio_manager.gd`
2. `SaveData` — `autoload/save_data.gd`
3. `InputManager` — `autoload/input_manager.gd`
4. `LevelQueue` — `autoload/level_queue.gd`

## Autoloads

### AudioManager

Gestión de música y SFX con caché de streams.

- `play_music(path: String, loops: bool = true)` — música en bucle; no reinicia
  si ya suena el mismo archivo.
- `stop_music()` — detiene y libera la música.
- `play_sfx(path: String, volume_db: float = 0.0, pitch_scale: float = 1.0)` —
  SFX a través del bus `sfx_bus`.
- `clear_sfx()` — libera la caché de SFX (para cambiar de escena pesada).
- Variables: `music_player`, `music_cache`, `sfx_cache`, `current_music`,
  `sfx_bus`.

### SaveData

Zócalos de memoria persistentes en `user://save_slots.json`.
**3 zócalos por modo**: uno para el modo historia (`key = "story"`) y uno por
cada pack (`key = "pack:<id>"`). Los niveles sueltos no usan guardado.

Constantes y estado:

- `const SAVE_PATH := "user://save_slots.json"`, `const SLOT_COUNT := 3`,
  `const SAVE_VERSION := 2`
- `games: Dictionary` (clave → array de 3, cada elemento `null` o un diccionario)
- `active_slot: int = -1`, `active_key: String = ""` — sesión activa
- `downloaded_packs: Array` — ids marcados como descargados de la tienda
- `settings: Dictionary` — preferencias del usuario persistidas (p. ej. modo de
  control móvil)
- `get_setting(key, default) -> value` / `set_setting(key, value)` — lee/escribe
  una preferencia; se persiste en el mismo JSON.

Zócalos:

- `get_slot(key, index) -> Dictionary` — zócalo (o `{}` si vacío).
- `has_save(key, index) -> bool` — ¿hay partida guardada?
- `set_slot(key, index, data)` — guarda (data puede ser `null` para vaciar).
- `clear_slot(key, index)` — libera un zócalo.
- `get_slot_info(key, index) -> Dictionary` — igual que `get_slot`.
- `has_any_save(key) -> bool`, `count_saves(key) -> int`.
- `get_game_key(mode, id) -> String` — `"pack:<id>"` o `"story"`.

Sesión activa (la usa TumbleBoy para registrar progreso):

- `begin_session(mode, id, slot, total, completed = 0)` — abre sesión en un
  zócalo y escribe el estado inicial.
- `begin_session_quick(mode, id, total)` — sesión sin zócalo (sin guardado).
- `record_progress(completed)` — escribe el nivel completado de la sesión activa.
- `end_session()` — cierra la sesión activa.

Packs descargados:

- `mark_pack_downloaded(id)` / `is_pack_downloaded(id)` / `is_pack_local(id)`
  (`is_pack_local` = NO descargado desde la tienda, p. ej. packs propios).
- `clear_pack(id)` — elimina el pack de downloaded_packs y games.

Borrador del editor (un solo borrador activo):

- `has_draft() -> bool`, `get_draft() -> Dictionary`, `save_draft(data)`, `clear_draft()`
- Guardado automático continuo (~2-3 s). Se limpia al crear/Abrir/Guardar con éxito.

Utilidades: `reset_all()` (borra todo el guardado), `_load()`/`_save()`
(re-lectura/escritura del JSON; útil en tests).

Formato de `save_slots.json`:

```json
{
  "version": 2,
  "games": {
    "story":   [ null, {"mode":"story","id":"historia","completed":3,"total":21,"updated":1712345678}, null ],
    "pack:abc":[ null, null, null ]
  },
  "downloaded_packs": ["abc"],
  "draft": { "map": [[1,2]], "attributes": {"theme":"default"}, "current_file": "", "read_only": false, "updated": 123 },
  "settings": { "control_mode": 0 }
}
```

### InputManager

Capa de entrada unificada. Construye el `InputMap` en tiempo de ejecución para
que teclado, gamepad y D-pad se comporten igual.

Acciones: `move_up/down/left/right`, `confirm`, `back`, `ui_toggle`
(tecla `F2` / botón `Y` del mando), y las `ui_*` para el foco
(`ui_up/down/left/right`, `ui_accept`, `ui_cancel`).

Modo de control móvil (`enum ControlMode { TOUCH, TILT }`, donde `TILT` = modo
Acelerómetro):

- `control_mode: int` — modo activo, cargado desde `SaveData.get_setting("control_mode", TOUCH)`.
- `set_control_mode(mode)` — cambia el modo, lo persiste en `SaveData` y emite
  `control_mode_changed(mode)`.
- `is_tilt_mode() -> bool` — `true` solo si `control_mode == TILT` **y**
  `is_mobile()` (el modo Acelerómetro usa el acelerómetro, sin giroscopio).
- `recalibrate_tilt()` — fija la calibración actual como punto neutro.
- `is_mobile() -> bool` — `true` en Android o si la línea de comandos incluye
  `--force-touch` (pruebas táctiles en escritorio). Sustituye a la antigua `is_touch()`.

Vector de movimiento:

- `get_move_vector() -> Vector2` — vector normalizado para el juego: si está en
  modo Acelerómetro y el acelerómetro supera la deadzone (0.7, clamp 6.0,
  suavizado lerp 0.3) devuelve ese vector; si no, hardware; y `virtual_move`
  (joystick táctil) tiene prioridad sobre el hardware.
- `get_hardware_move_vector() -> Vector2` — solo teclado/D-pad del mando (lo usa
  el editor para mover el cursor sin interferir con el joystick táctil).
- `virtual_move: Vector2` — lo escribe `touch_controls.gd`.

Helpers:

- `confirm_just_pressed() -> bool`, `back_just_pressed() -> bool`,
  `ui_toggle_just_pressed() -> bool`.
- `press_action(action)`, `release_action(action)`, `tap_action(action)`.
- `has_joypad() -> bool`.
- Señales: `confirm_pressed`, `back_pressed`, `control_mode_changed(mode)`.
- Constantes de joypad: `JOY_BUTTON_A=0`, `JOY_BUTTON_B=1`,
  `JOY_BUTTON_X=2`, `JOY_BUTTON_Y=3`, `JOY_BUTTON_START=9`,
  `JOY_BUTTON_BACK=10`, `JOY_DPAD_*`.

### LevelQueue

Secuencia de niveles que un hub deja preparada para `TumbleBoy`.

- `paths: Array` — rutas de niveles (vacío = modo historia nostálgico de `res://`).
- `title: String` — nombre de la secuencia.
- `return_scene: String` — escena a la que volver al salir (se calcula según modo).
- `mode: String` — `"story"` | `"pack"` | `"level"`.
- `pack_id: String` — id del pack (para el guardado por zócalo).
- `start_index: int` — nivel inicial (reanudar partida).

Métodos:

- `clear()` — resetea todos los campos.
- `play_levels(list: Array, t: String, m := "story", pid := "")` — configura la
  secuencia; calcula `return_scene` (PacksCommunity si `pack`, EditorHub si
  `level`, StoryHub en caso contrario).

> Ojo: `play_levels` llama a `clear()` y por tanto resetea `start_index`.
> Asigna `start_index` **después** de llamar a `play_levels` (lo hace `SlotPicker`).

## Scripts de gameplay (`scripts/tumbleboy/`)

### tb_constants.gd

Constantes escaladas del original (resolución base 640×480 → 1100×825).

- `SCALE = 825.0/480.0`, `GAME_OFFSET_X = 50.0` (centra TumbleBoy en la ventana de 1200).
- `SCREEN_W/H = 1100/825`, `SCREEN_MARGIN = 200*SCALE`, `PIXEL_SIZE = 64*SCALE`,
  `PIXEL_BORDER = 12*SCALE`, `BALL_PIXEL_SIZE`, `BALLSPRITE_*`.
- Física: `MAX_SPEED=2`, `BUMPER_SPEED=4`, `GRAVITY=8`, `MAX_DEPTH=-5`,
  `BALL_FORCE=1`, `BALL_DRAG=0.003`, `WALL_ELASTICITY=0.6`, `BALL_CLIMB=0.75`,
  `BALL_RADIUS=0.45`, `BUMPER_HEIGHT=0.2`.
- Bloques: `BLOCK_NONE=0`, `BLOCK_FLOOR=1`, `BLOCK_FLOOR2=2`, `BLOCK_FLOOR3=3`,
  `BLOCK_WALL=4`, `BLOCK_WALL2=5`, `BLOCK_WALL3=6`, `BLOCK_DOUBLEWALL=7`,
  `BLOCK_DOUBLEWALL2=8`, `BLOCK_DOUBLEWALL3=9`, `BLOCK_START=10`, `BLOCK_GOAL=11`,
  `BLOCK_RAMP_RIGHT=12`, `BLOCK_RAMP_LEFT=13`, `BLOCK_RAMP_UP=14`,
  `BLOCK_RAMP_DOWN=15`, `BLOCK_BUMPER=16`.
- Sonidos: `SOUND_NONE..SOUND_WIN_GAME` (0-7).
- Poses del niño: `BOY_RESTING=0`, `BOY_RIGHT=2`, `BOY_LEFT=4`, `BOY_UP=6`,
  `BOY_DOWN=8`.
- Rutas: `ASSETS`, `LEVELS_DIR`, `THEMES_DIR`, `SOUNDS_DIR`, `MENUS_DIR`.

### board.gd

`Board` — grilla de bloques, alturas y bumpers.

- `width/height`, `blocks: Array`, `bumpers: Array`, `theme: String`,
  `block_images: Array`.
- `clear()`, `set_dimensions(w, h)`, `set_theme(folder)`.
- `set_block(xi, yi, blocktype) -> bool`.
- `height_at(x: float, y: float) -> float` — altura en unidades de bloque.
- `block_at(x, y) -> int`, `get_start_position() -> Vector2`.
- `get_colliding_bumper(x, y)` — bumper en colisión o `null`.
- `load_block_images()`, `render_board_image() -> Texture` — dibuja el tablero.

### ball.gd

`Ball` — física 3D del niño-bola, animación y escala por profundidad.

- `position: Vector3`, `velocity: Vector3`, `on_ground: bool`, `board`.
- `set_theme(folder)`, `set_board(b)`, `set_position(x, y, z)`.
- `add_force(dx, dy)`, `update(dt)`, `is_above_goal() -> bool`.
- `scale_index(z) -> int`, `current_texture() -> Texture`, `current_offs()`,
  `current_size()`, `setup_images()`.
- Poses y escalas: `SCALE_LEVELS = [0.8, 0.9, 1.0, 1.05, 1.1, 1.15]`, 6 imágenes
  de escala × 10 frames.

### levels.gd

Parser del formato de nivel (estático).

- `parse_level(level_file: String) -> Dictionary` → `{ "attributes": {...}, "map": [...] }`.
- `parse_level_text(content: String) -> Dictionary`.
- `write_level(level_file: String, attributes: Dictionary, level_map: Array) -> bool`.
- Mapa de símbolos `MAP_TILES` y lista inversa `BLOCK_SYMBOLS`.

### tumbleboy.gd

`TumbleBoy` — la escena de juego completa (`scenes/TumbleBoy.tscn`).

Estados: `State.PLAYING`, `State.WIN_LEVEL`, `State.WIN_GAME`.

- `_ready()` — lee `LevelQueue`; si `paths` no está vacío juega esa lista, si no
  carga el modo historia (`_load_level_list()`), y arranca en `start_index`.
- `_start_playing()` — monta la partida (preserva `return_scene` al limpiar
  `LevelQueue`).
- `_load_next_level()` — avanza; si no hay más niveles → `WIN_GAME`.
- `_win_level()` — sonido de victoria + `SaveData.record_progress(next_level)`.
- `_go_to_menu()` — vuelve a `LevelQueue.return_scene` (o MainMenu) y hace
  `SaveData.end_session()`.
- `_unhandled_input(ev)` — movimiento (vía `InputManager.get_move_vector()`) y
  B/ESC para salir (`_go_to_menu`).
- En estado `MENU`, un toque de pantalla (`InputEventScreenTouch`) arranca la
  partida (móvil).
- Dibujo: `_draw()`, `_draw_game()`, `_draw_menu()`, `_draw_win()`,
  `_draw_hint()` (pinta el hint "B / ESC: menú" con fondo oscuro para legibilidad).
- Cámara: `_get_screen_offset()` sigue a la bola con márgenes.
- Controles táctiles: instancia `TouchControls.tscn` si `InputManager.is_mobile()`.

### editor.gd

Editor visual de niveles (`scenes/TumbleBoyEditor.tscn`).

Métodos públicos usados por `EditorHub`:

- `open_file(path)` — carga un nivel existente (equivale a `_on_open_selected`).
- `open_pack_panel()` — abre el panel de creación de packs (equivale a `_on_open_pack`).
- `open_draft()` — restaura el borrador guardado (equivale a `_load_draft`).

Otros destacados:

- `_on_new()`, `_on_open()`, `_on_save()`, `_on_save_as()`, `_save_to(path)`.
- `_validate_fields()` — exige nombre, autor y descripción antes de guardar
  (bloquea el guardado si falta alguno).
- `_validate_map()` — exige bloques Inicio ($) y Meta (1).
- `_paint_cell(col, row, erase)`, `_select_paint(block)`, `_undo()`, `_redo()`,
  `_validate_map()`, `_validate_fields()`.
- Modo foco UI (navegar los widgets con D-pad en TV): `ui_mode: bool`,
  `ui_controls: Array`, `_toggle_ui_mode()` (tecla `F2` / botón `Y`),
  `_set_ui_focus_mode(mode)`. Al activarse, toolbar y paleta pasan a
  `FOCUS_ALL` y `play_button` toma el foco; al salir, se suelta el foco y
  vuelven a `FOCUS_NONE`. En modo foco, `B` vuelve al plano (no sale del
  editor). El cursor de pintado siempre usa `get_hardware_move_vector()` para
  no mezclarse con el joystick táctil.
- **Navegación vertical completa (4 filas)**: `_wire_focus_rows()` enlaza los
  vecinos left/right dentro de cada fila y top/bottom entre filas adyacentes.
  Filas: (1) `toolbar_controls` (Nuevo/Abrir/Guardar/…), (2) campos con `rect_position.y ≤ 50`
  (nombre, autor), (3) campos con `y > 50` (tema, niño, descripción) y (4) la
  paleta. Los vecinos verticales se emparejan por la x más cercana
  (`_nearest_focus`), así el D-pad baja "en vertical" de toolbar → fila 2 →
  fila 3 → paleta y sube en orden inverso. `ui_fields` agrupa los 5 campos
  editables (name_edit, author_edit, theme_option, boy_option, desc_edit);
  toolbar y campos quedan fuera de `ui_controls`, de modo que en modo pintura
  siguen siendo clicables con el ratón sin alterar `_set_ui_focus_mode`.
- Transición automática celda ↔ botones: `_try_ui_edge(step, prev)` se llama
  desde `_move_cursor` con la celda anterior, y al llegar al tope del grid
  (arriba) entra en modo foco UI sobre la toolbar (`ui_controls[0]`), y en el
  borde inferior sobre la paleta (el bloque seleccionado). A la inversa, en
  modo foco UI una pulsación vertical que no mueve el foco (`_focus_owner() ==
  _ui_last_focus`, navegación bloqueada) sale al tablero dejando el cursor donde
  estaba. `_enter_ui_focus(target)` / `_exit_ui_focus()` centralizan la lógica.
- Al abrir un nivel (`_on_open_selected`) se cargan automáticamente nombre,
  autor, descripción, tema y niño (`_attributes_to_fields` + `_theme_sync`).
- Borrador: se marca sucio solo al modificar (pintar, deshacer, rehacer, tema,
  niño o campos). Abrir/crear un nivel lo limpia; `_ready` carga el borrador
  antes de crear un tablero nuevo.
  `_cycle_block(dir)`.
- `_validate_map() -> String` — devuelve `""` si el nivel es válido, si no el motivo.
- Atributos: `_collect_fields_to_attributes()`, `_attributes_to_fields()`.
- Modo prueba: `_enter_play()`, `_exit_play()`, `_process_play(delta)`.
- Packs: `_on_create_pack()`, `_refresh_pack_available()`, `_pack_*`,
  `_on_open_export()`, `_on_export_copy(target, id)`.
- Variables clave: `map`, `attributes`, `board`, `current_file`, `read_only`,
  `pack_available`, `pack_selected`, `paint_buttons`, `theme_option`,
  `boy_option`, `status_label`.

Niveles del usuario: `user://tumbleboy_levels/`. Packs propios:
`user://tumbleboy_packs/` (el editor usa `PACKS_DIR`).

## Packs

### pack_reader.gd

Lector de packs (estático). `const PACKS_DIR := "user://tumbleboy_packs/"`.

- `list_packs() -> Array` — packs locales ordenados por nombre (`manifest.json`).
- `zip_path_for_id(id) -> String` — `user://tumbleboy_packs/<id>.zip`.
- `read_manifest(zip_path) -> Dictionary`.
- `get_level_text(zip_path, level_filename) -> String`.
- `list_level_filenames(zip_path) -> Array`.
- `extract_pack(zip_path, dest_dir) -> Array` — extrae los niveles a `dest_dir`
  y devuelve sus rutas (juego temporal para un pack).
- `get_thumbnail_texture(zip_path) -> Texture` — carga `thumbnail.png` del ZIP como textura (o `null`).
- `remove_pack(id) -> bool` — elimina el ZIP del pack.

### zip_reader.gd / zip_writer.gd

Implementación GDScript propia de ZIP (el `ZIPReader` no está compilado en este
build de Godot). Formato ZIP clásico, sin compresión (store).

- `ZipReader.get_files(zip_path) -> Array`.
- `ZipReader.read_file(zip_path, file_name) -> PoolByteArray`.
- `ZipWriter.write_pack_zip(zip_path, files: Dictionary) -> bool` — `files` es
  `{ "ruta/en/zip": contenido }` donde contenido puede ser `String` o `PoolByteArray`
  (para imágenes PNG embebidas).

### pack_row.gd

Builder compartido de filas de packs (estilo de Packs online). Usado por
`packs_community.gd` (descargados) y `editor_hub.gd` (propios).

- `PackRow.make(pack: Dictionary, thumb: Texture, buttons: Array) -> HBoxContainer`
  — bloque centrado (`ALIGN_CENTER`, sep 12): preview 64×64 + columna de info
  **fija de 400px no expandible** (`"nombre — autor"` en una sola línea, 16 bold;
  descripción opcional como segunda línea con autowrap 13 y color gris) +
  botones de 120×36 con fuente 14. El bloque de info fijo hace que las filas no
  se anclen a la izquierda aunque el contenido sea corto.

### pack_store.gd

Tienda online (descarga desde el repo). La instancia `PackCommunity` en la
escena; no es autoload.

Señales:

- `index_updated(entries: Array, from_cache: bool)`
- `index_error(message: String)`
- `pack_downloaded(id: String, ok: bool, message: String)`
- `thumbnail_ready(id: String)`

Métodos:

- `refresh_index()` — muestra la caché al instante si existe (`index_updated`
  con `from_cache=true`) y en paralelo descarga `packs/index.json` (GitHub
  Contents API) con ETag/304; si la red falla o hay rate-limit, la lista
  queda visible desde la caché.
- `get_cached_index() -> Array`.
- `is_pack_installed(id) -> bool` — ¿existe el ZIP en `user://tumbleboy_packs/`?
- `download_pack(entry: Dictionary)` — descarga el ZIP y lo guarda.
- `download_thumbnail(entry: Dictionary)` — descarga `<id>.png` a caché.
- `get_thumbnail_texture(id) -> Texture` (o `null`).

Constantes: `REPO = "Aleperix/tumbleboy-reborn"`, `BRANCH = "main"`,
`API_INDEX_URL` (GitHub Contents API), `RAW_BASE` (raw.githubusercontent.com),
`CACHE_DIR = "user://tumbleboy_cache/"`.

## Scripts de interfaz (`scripts/ui/`)

Todas las escenas de menú usan el patrón: `ColorRect` de fondo oscuro,
`CenterContainer` → `VBoxContainer`, botones con `focus_mode = FOCUS_ALL`,
hint al pie con `StyleBoxFlat` de fondo `Color(0,0,0,0.35)`. El patrón de
navegación entre hubs es: `get_tree().change_scene(...)` + `yield(tree, "idle_frame")`
+ `configure(...)` para pasar parámetros al siguiente hub.

### focus_nav.gd

Utilidades de navegación de foco (D-pad/TV) compartidas por menús y hubs
(helper estático, `extends Reference`).

- `FocusNav.grab_first(root) -> bool` — enfoca el primer `Button` visible y
  habilitado en orden de árbol (recursivo).
- `FocusNav.set_skippable(btn, disabled)` — marca `disabled` y pone
  `focus_mode = FOCUS_NONE` para que el D-pad salte los controles
  deshabilitados (Continuar sin partida, zócalos vacíos en continue).
- `FocusNav.enable_scroll_follow(scroll)` — activa `ScrollContainer.follow_focus`
  y conecta `focus_entered → ensure_control_visible` en todos los botones del
  contenido (evita los scrollbars internos del ScrollContainer).
- `FocusNav.popup_open(root) -> bool` — `true` si algún `Popup`/diálogo hijo
  está visible; los `_input` de back lo usan para no cerrar dos capas a la vez.

### main_menu.gd

Menú principal. `MENU_ITEMS`: Modo historia (`StoryHub.tscn`), Packs comunitarios
(`PacksCommunity.tscn`), Editor de niveles (`EditorHub.tscn`), Salir.

- `_build_ui()` — icono (`assets/tumbleboy/icon.png`), título, subtítulo,
  botones 400×50, hint con fondo.
- `_on_item_pressed(item)` — navega o sale.
- `_input(ev)` — con `back_just_pressed()` (ESC, BACK de Android o botón B del
  mando) **sale de la app** (el menú principal es la única pantalla en la que
  Back cierra el juego).

### credits.gd

Pantalla de créditos.

- `_on_back()` — vuelve al menú principal.
- `_input(ev)` — `back_just_pressed()` vuelve al menú.
- Variable: `back_button` (etiqueta "Volver").

### story_hub.gd

Modo historia: **Nueva Partida** / **Continuar** / **Volver**.

- `_update_continue()` — activa/desactiva Continuar (con
  `FocusNav.set_skippable`, sin partida queda sin foco) y muestra
  "Continuar — nivel X/Y" según el primer zócalo con partida.
- `_on_new()` / `_on_continue()` — abren `SlotPicker` con
  `configure("story", "historia", "new" | "continue")`.
- `_on_back()` — vuelve a MainMenu.
- `_input(ev)` — `back_just_pressed()` vuelve a MainMenu (con guard
  `FocusNav.popup_open(self)`).
- Variables: `buttons: Array` (3 botones).

### slot_picker.gd

Selector de zócalos genérico (historia y packs).

- `configure(m: String, id: String, i: String)` — `m` es `"story"` o `"pack"`,
  `id` el identificador, `i` el intent (`"new"` | `"continue"`).
- Muestra 3 botones de zócalo + (si `i == "new"`) la opción "Sin guardado".
- `_refresh_slots()` — etiqueta cada zócalo ("Zócalo N — Historia: nivel X/Y" o
  "Vacío"); en modo `continue` marca los vacíos con `FocusNav.set_skippable`
  (sin foco).
- `_on_slot(index)` — en `new` sobre zócalo ocupado pide confirmación de
  sobrescritura (`ConfirmationDialog`); luego `_start_game(index)`.
- `_on_dialog_closed()` — al cerrarse un diálogo (señal `popup_hide`) espera 2
  frames y restaura el foco al primer botón habilitado.
- `_start_game(index)` — `begin_session(...)` y `_launch(completed)`.
- `_launch(start)` — extrae el pack si corresponde, `play_levels(...)` y
  `LevelQueue.start_index = start` (después de `play_levels`).
- `_on_no_save()` — `begin_session_quick(...)` y lanza desde 0.
- `_pack_total()` — nº de niveles del pack (extrae temporalmente a
  `user://tumbleboy_cache/play/<id>/`).
- `_on_back()` — vuelve a StoryHub o PacksCommunity según `game_mode`.

### packs_community.gd

Packs comunitarios: menú → **Packs descargados** / **Packs online** / Volver.

- Crea su propia instancia de `pack_store.gd` y la conecta.
- `_refresh_descargados()` — lista packs locales con `PackRow` (Jugar + Desinstalar).
- `_on_open_online()` — `store.refresh_index()`; `_render_online()` pinta cada
  pack con thumbnail (64×64), nombre, autor, descripción y botón
  Descargar/Instalado.
- `_on_download(e)` — abre `ConfirmationDialog` ("¿Descargar el pack X?"); al
  confirmar llama a `store.download_pack(e)`.
- `_on_uninstall(id)` — abre `ConfirmationDialog` para desinstalar; al confirmar
  llama `PackReader.remove_pack(id)` + `SaveData.clear_pack(id)` y refresca.
- `_on_pack_downloaded(id, ok, msg)` — si ok: `SaveData.mark_pack_downloaded(id)`
  y re-renderiza.
- Cada lista (descargados/online) vive dentro de un `ScrollContainer`
  (`desc_scroll`, `online_scroll`) con foco-follow: al navegar con flechas/D-pad
  el scroll sigue al botón enfocado (`FocusNav.enable_scroll_follow`).
- Las dos listas comparten el estilo de **Packs online**: columna de **700px
  centrada horizontalmente** (`desc_col` / `online_col`, `SIZE_SHRINK_CENTER`)
  y filas `PackRow` con botones de 120×36. Los botones de *descargados* son
  Jugar (120×36) y Desinstalar.
- Thumbnails online: `_thumb_nodes: {id → TextureRect}`; `_on_thumbnail_ready`
  actualiza solo la textura del nodo correspondiente (no reconstruye la lista,
  para no mover el foco ni re-descargar).
- **Foco Packs Online (datos asíncronos)**: la respuesta de red llega de forma
  asíncrona y `_render_online()` reconstruye la lista (`queue_free`), lo que
  libera el botón enfocado a fin de frame. Patrón estándar de apps con datos de
  internet: `_render_online()` captura primero `_online_focus_id` con
  `_focused_online_id()` (id del pack cuyo botón está enfocado), y tras
  reconstruir llama `call_deferred("_restore_online_focus")`, que espera 2
  frames (para que el botón viejo desaparezca) y devuelve el foco al mismo pack
  (`_grab_button_for_row`), o al primer botón, o a "Actualizar" si ya no existe.
  No actúa si el panel no está visible o hay un diálogo abierto
  (`FocusNav.popup_open`).
- Botones "Instalado" (pack ya descargado) se marcan con
  `FocusNav.set_skippable` para que el D-pad no se quede en ellos.
- `_input(ev)` — con `back_just_pressed()` (incluye el botón B del mando)
  navega por paneles; `FocusNav.popup_open(self)` evita cerrar el diálogo y el
  panel a la vez. `_on_dialog_closed()` restaura el foco a la lista tras cerrar
  diálogos.
- Variables: `store`, `menu_panel`, `descargados_panel`, `online_panel`,
  `desc_scroll`, `online_scroll`, `desc_vbox`, `online_vbox`, `online_status`,
  `entries`, `download_dialog`, `uninstall_dialog`, `pending_download`,
  `pending_uninstall`, `_thumb_nodes`.

### editor_hub.gd

Editor de niveles: **Niveles propios** (con Borrador arriba si existe) / **Packs propios** / **Nuevo nivel** / Volver.

- `_list_user_levels() -> Array` — `.txt` en `user://tumbleboy_levels/`.
- `_refresh_niveles()` — muestra Borrador (si existe: Editar/Eliminar) y debajo
  cada nivel con nombre/autor/instrucciones + Jugar/Editar/Eliminar.
- `_on_play_level(path, display)` — `LevelQueue.play_levels([path], display, "level")`
  y `change_scene("res://scenes/TumbleBoy.tscn")` (quick play, sin guardado).
- `_on_edit_level(path)` — abre el editor y llama `editor.open_file(path)`.
- `_on_edit_draft()` — abre el editor con `NavParams.open_draft = true`.
- `_on_delete_draft()` — `SaveData.clear_draft()` y refresca.
- `_on_delete_level(path, display)` — `ConfirmationDialog` → `dir.remove(path)`.
- `_refresh_packs()` — packs propios con `PackRow` (Jugar + Eliminar).
- `_on_play_pack(p)` — abre `SlotPicker` con `configure("pack", id, "new")`.
- `_on_delete_pack(id)` — `ConfirmationDialog` → `PackReader.remove_pack(id)` y refresca.
- `_on_create_pack()` — abre el editor y llama `editor.open_pack_panel()`.
- `_on_new_level()` — abre el editor vacío.
- Cada lista (niveles/packs propios) vive dentro de un `ScrollContainer`
  (`niveles_scroll`, `packs_scroll`) con foco-follow (`FocusNav.enable_scroll_follow`).
- Las dos listas comparten el estilo de **Packs online**: columna de **700px
  centrada horizontalmente** (`niveles_col` / `packs_col`, `SIZE_SHRINK_CENTER`).
  *Niveles propios*: filas centradas con info fija de 400px ("nombre — autor" +
  instrucciones con autowrap, sin miniatura) y botones Jugar/Editar/Eliminar de
  84×36. *Packs propios*: filas `PackRow` con botones de 120×36 (Jugar + Eliminar).
- `_input(ev)` — con `back_just_pressed()` (incluye botón B del mando) cierra
  paneles o vuelve al hub; `_on_dialog_closed()` restaura el foco tras los
  diálogos de borrado.
- Variables: `hub_panel`, `niveles_panel`, `packs_panel`, `niveles_scroll`,
  `packs_scroll`, `niveles_vbox`, `packs_vbox`, `delete_dialog`,
  `pending_delete`.

### ui_fonts.gd

- `UIFonts.make_font(size: int, bold := false) -> DynamicFont` — fuentes DejaVu
  de `res://assets/ui/fonts/`.

### touch_controls.gd

Capa táctil para móvil (`visible = InputManager.is_mobile()`): joystick virtual
a la izquierda y un botón a la derecha **del mismo tamaño que el análogo** para
alternar entre **Mando** (joystick) y **Acelerómetro**. Adaptativo: recalcula
posiciones con `_recalculate_positions()` al cambiar el tamaño del viewport (no
usa la ventana fija de 1200×825). Actualiza `InputManager.virtual_move`; el
release de cada control se identifica por **índice de touch**, de modo que
soltar fuera del radio no lo deja "pulsado", y **devuelve el knob al centro**
(`knob_offset = ZERO` + `update()` para redibujarlo al instante). En modo
Acelerómetro oculta el joystick (`_update_mode_ui`). Se conecta a
`InputManager.control_mode_changed`.

## Escenas (`scenes/`)

| Escena | Uso |
|--------|-----|
| `MainMenu.tscn` | Menú principal |
| `StoryHub.tscn` | Modo historia (Nueva partida / Continuar) |
| `SlotPicker.tscn` | Zócalos de memoria (historia y packs) |
| `PacksCommunity.tscn` | Packs descargados + online |
| `EditorHub.tscn` | Editor de niveles (lista, packs, nuevo) |
| `TumbleBoy.tscn` | Juego |
| `TumbleBoyEditor.tscn` | Editor visual |
| `TouchControls.tscn` | Controles táctiles (añadida en TumbleBoy) |
| `SmokeTest.tscn` | Test headless (raíz `tests/smoke_test.gd`) |
| `PackLevelsTest.tscn` | Test de packs headless (raíz `tests/pack_levels_test.gd`) |

## Directorios `user://`

| Ruta | Contenido |
|------|-----------|
| `user://save_slots.json` | Guardado por zócalos (`SaveData`) |
| `user://tumbleboy_levels/` | Niveles creados en el editor |
| `user://tumbleboy_packs/` | Packs (ZIP) — propios y descargados |
| `user://tumbleboy_cache/` | Caché de la tienda (`index.json`, ETag, thumbs) |
| `user://tumbleboy_cache/play/<id>/` | Extracción temporal de un pack para jugar |
| `user://tumbleboy_cache/thumbs/` | Thumbnails `<id>.png` |

## Formato de los packs

Un pack es un ZIP (compresión store) con:

```
<pack_id>.zip
├── manifest.json   {"name","author","description","levels":[...]}
└── levels/
    ├── nivel1.txt
    └── ...
```

El índice online `packs/index.json` del repo:

```json
[
  { "id": "numeros", "name": "Números", "author": "Aleperix",
    "description": "Los números pares del 0 al 10 en trazos de neón.",
    "thumbnail": "packs/numeros.png" },
  { "id": "letras", "name": "Letras", "author": "Aleperix",
    "description": "Las letras de la B a la Z en trazos de neón.",
    "thumbnail": "packs/letras.png" }
]
```

Ver `packs/README.md` para el flujo completo de creación y aporte.

## Tests

- **`tests/smoke_test.gd`** (`res://scenes/SmokeTest.tscn`, headless):
  niveles (21), parser, board, ball, escena, editor, ZIP round-trip,
  zócalos de SaveData, LevelQueue, StoryHub, SlotPicker, PacksCommunity,
  EditorHub, MainMenu, FocusNav (`set_skippable`/`grab_first`/`popup_open`),
  settings round-trip (`control_mode`), TouchControls (joystick → `virtual_move`,
  release por índice con knob al centro, toggle Mando/Acelerómetro y tamaño del
  botón derecho) y modo foco UI del editor (incluida la transición celda ↔
  botones en los bordes del grid).
  Resultado: `SMOKE TEST: ALL PASS`.
- **`tests/online_test.gd`** (`res://tests/OnlineTest.tscn`, requiere red y
  ventana): índice (2 packs), descarga, ETag/304, thumbnail.
- **`tests/pack_levels_test.gd`** (`res://tests/PackLevelsTest.tscn`, headless):
  lee los packs de `res://packs/*.zip` con el `PackReader` y valida cada nivel
  (1 inicio, ≥1 meta, meta alcanzable por BFS, filas iguales, thumbnail PNG).
- **`tests/verify_packs.gd`**, **`tests/make_packs.gd`**,
  **`tests/make_sample_pack.gd`** — utilidades de mantenimiento de `packs/`.
- **`tools/gen_packs.py`** — genera los packs `Números` y `Letras` (glifo neón
  renderizado con PIL → contorno 3 tiles → puentes para bucles → BFS →
  zip store) y sus thumbnails.
