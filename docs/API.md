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

- `const SAVE_PATH := "user://save_slots.json"`, `const SLOT_COUNT := 3`
- `games: Dictionary` (clave → array de 3, cada elemento `null` o un diccionario)
- `active_slot: int = -1`, `active_key: String = ""` — sesión activa
- `downloaded_packs: Array` — ids marcados como descargados de la tienda

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
  "version": 1,
  "games": {
    "story":   [ null, {"mode":"story","id":"historia","completed":3,"total":21,"updated":1712345678}, null ],
    "pack:abc":[ null, null, null ]
  },
  "downloaded_packs": ["abc"],
  "draft": { "map": [[1,2]], "attributes": {"theme":"default"}, "current_file": "", "read_only": false, "updated": 123 }
}
```

### InputManager

Capa de entrada unificada. Construye el `InputMap` en tiempo de ejecución para
que teclado, gamepad y D-pad se comporten igual.

Acciones: `move_up/down/left/right`, `confirm`, `back`, y las `ui_*` para el foco.

- `get_move_vector() -> Vector2` — vector de movimiento normalizado (tiene en
  cuenta `virtual_move` del joystick táctil).
- `confirm_just_pressed() -> bool`, `back_just_pressed() -> bool`.
- `press_action(action)`, `release_action(action)`, `tap_action(action)`.
- `has_joypad() -> bool`, `is_touch() -> bool`.
- Señales: `confirm_pressed`, `back_pressed`.
- Constantes de joypad: `JOY_BUTTON_A=0`, `JOY_BUTTON_B=1`, `JOY_BUTTON_START=9`,
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
- Dibujo: `_draw()`, `_draw_game()`, `_draw_menu()`, `_draw_win()`,
  `_draw_hint()` (pinta el hint "B / ESC: menú" con fondo oscuro para legibilidad).
- Cámara: `_get_screen_offset()` sigue a la bola con márgenes.

### editor.gd

Editor visual de niveles (`scenes/TumbleBoyEditor.tscn`).

Métodos públicos usados por `EditorHub`:

- `open_file(path)` — carga un nivel existente (equivale a `_on_open_selected`).
- `open_pack_panel()` — abre el panel de creación de packs (equivale a `_on_open_pack`).
- `open_draft()` — restaura el borrador guardado (equivale a `_load_draft`).

Otros destacados:

- `_on_new()`, `_on_open()`, `_on_save()`, `_on_save_as()`, `_save_to(path)`.
- `_paint_cell(col, row, erase)`, `_select_paint(block)`, `_undo()`, `_redo()`,
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

Builder compartido de filas de packs (HBoxContainer con preview + info + botones).
Usado por `packs_community.gd` (descargados) y `editor_hub.gd` (propios).

- `PackRow.make(pack: Dictionary, thumb: Texture, buttons: Array) -> HBoxContainer`

### pack_store.gd

Tienda online (descarga desde el repo). La instancia `PackCommunity` en la
escena; no es autoload.

Señales:

- `index_updated(entries: Array, from_cache: bool)`
- `index_error(message: String)`
- `pack_downloaded(id: String, ok: bool, message: String)`
- `thumbnail_ready(id: String)`

Métodos:

- `refresh_index()` — descarga `packs/index.json` (GitHub Contents API) con ETag/304.
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

### main_menu.gd

Menú principal. `MENU_ITEMS`: Modo historia (`StoryHub.tscn`), Packs comunitarios
(`PacksCommunity.tscn`), Editor de niveles (`EditorHub.tscn`), Salir.

- `_build_ui()` — icono (`assets/tumbleboy/icon.png`), título, subtítulo,
  botones 400×50, hint con fondo.
- `_on_item_pressed(item)` — navega o sale.

### story_hub.gd

Modo historia: **Nueva Partida** / **Continuar** / **Volver**.

- `_update_continue()` — activa/desactiva Continuar y muestra
  "Continuar — nivel X/Y" según el primer zócalo con partida.
- `_on_new()` / `_on_continue()` — abren `SlotPicker` con
  `configure("story", "historia", "new" | "continue")`.
- `_on_back()` — vuelve a MainMenu.
- Variables: `buttons: Array` (3 botones).

### slot_picker.gd

Selector de zócalos genérico (historia y packs).

- `configure(m: String, id: String, i: String)` — `m` es `"story"` o `"pack"`,
  `id` el identificador, `i` el intent (`"new"` | `"continue"`).
- Muestra 3 botones de zócalo + (si `i == "new"`) la opción "Sin guardado".
- `_refresh_slots()` — etiqueta cada zócalo ("Zócalo N — Historia: nivel X/Y" o
  "Vacío"); en modo `continue` deshabilita los vacíos.
- `_on_slot(index)` — en `new` sobre zócalo ocupado pide confirmación de
  sobrescritura (`ConfirmationDialog`); luego `_start_game(index)`.
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
- Variables: `store`, `menu_panel`, `descargados_panel`, `online_panel`,
  `desc_vbox`, `online_vbox`, `online_status`, `entries`, `download_dialog`,
  `uninstall_dialog`, `pending_download`, `pending_uninstall`.

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
- Variables: `hub_panel`, `niveles_panel`, `packs_panel`, `niveles_vbox`,
  `packs_vbox`, `delete_dialog`, `pending_delete`.

### ui_fonts.gd

- `UIFonts.make_font(size: int, bold := false) -> DynamicFont` — fuentes DejaVu
  de `res://assets/ui/fonts/`.

### touch_controls.gd

Capa táctil para Android: joystick virtual + botones A/B. Actualiza
`InputManager.virtual_move` y dispara `confirm`/`back`. Solo relevante en
dispositivos táctiles.

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
  { "id": "primer_contacto", "name": "Primer contacto", "author": "Aleperix",
    "description": "...", "thumbnail": "packs/primer_contacto.png" }
]
```

Ver `packs/README.md` para el flujo completo de creación y aporte.

## Tests

- **`tests/smoke_test.gd`** (`res://scenes/SmokeTest.tscn`, headless):
  niveles (21), parser, board, ball, escena, editor, ZIP round-trip,
  zócalos de SaveData, LevelQueue, StoryHub, SlotPicker, PacksCommunity,
  EditorHub y MainMenu. Resultado: `SMOKE TEST: ALL PASS`.
- **`tests/online_test.gd`** (`res://tests/OnlineTest.tscn`, requiere red y
  ventana): índice (3 packs), descarga, ETag/304, thumbnail.
- **`tests/verify_packs.gd`**, **`tests/make_packs.gd`**,
  **`tests/make_sample_pack.gd`** — utilidades de mantenimiento de `packs/`.
