extends Node2D
# TumbleBoyEditor — editor visual de niveles con el formato .txt original.
# v2: fuentes corregidas (DynamicFont sin font_data no renderiza en Godot 3),
# paleta scrollable, panel de ayuda (F1), cursor + preview de bloque,
# input unificado (mouse/teclado/touch/D-pad/gamepad), deshacer/rehacer.

const C = preload("res://scripts/tumbleboy/tb_constants.gd")
const BoardScript = preload("res://scripts/tumbleboy/board.gd")
const BallScript = preload("res://scripts/tumbleboy/ball.gd")
const LevelsScript = preload("res://scripts/tumbleboy/levels.gd")
const UIFonts = preload("res://scripts/ui/ui_fonts.gd")

const PALETTE := [
	["Borrar", C.BLOCK_NONE],
	["Piso", C.BLOCK_FLOOR],
	["Piso 2", C.BLOCK_FLOOR2],
	["Piso 3", C.BLOCK_FLOOR3],
	["Muro", C.BLOCK_WALL],
	["Muro 2", C.BLOCK_WALL2],
	["Muro 3", C.BLOCK_WALL3],
	["Doble", C.BLOCK_DOUBLEWALL],
	["Doble 2", C.BLOCK_DOUBLEWALL2],
	["Doble 3", C.BLOCK_DOUBLEWALL3],
	["Inicio", C.BLOCK_START],
	["Meta", C.BLOCK_GOAL],
	["Rampa >", C.BLOCK_RAMP_RIGHT],
	["Rampa <", C.BLOCK_RAMP_LEFT],
	["Rampa v", C.BLOCK_RAMP_UP],
	["Rampa ^", C.BLOCK_RAMP_DOWN],
	["Bumper", C.BLOCK_BUMPER],
]

const THEMES := ["default", "beach", "spacetheme1"]
const BOYS := ["boy1", "boy2", "boy3", "boy4"]
const TOP_H := 68
const BOTTOM_H := 88
const CURSOR_CELLS_PER_SEC := 6.0
const UNDO_LIMIT := 50

var board = null
var ball = null
var map: Array = []
var attributes := {}
var selected_block := C.BLOCK_FLOOR
var play_mode := false
var board_texture: Texture = null
var anim_timer := 0.0

var status_label: Label
var hint_label: Label
var name_edit: LineEdit
var theme_option: OptionButton
var boy_option: OptionButton
var paint_buttons: Array = []
var palette_scroll: ScrollContainer
var help_panel: Control
var help_visible := false
var dialog_open := false

var cursor_cell := Vector2(0, 0)
var cursor_accum := Vector2.ZERO
var last_mouse_pos := Vector2(-9999, -9999)
var mouse_button := 0
var touch_painting := false

var undo_stack: Array = []
var redo_stack: Array = []

var font_swatch: Font

var fit_origin := Vector2.ZERO
var fit_scale := 1.0

func _ready():
	board = BoardScript.new()
	font_swatch = UIFonts.make_font(15)
	_new_board()
	_build_ui()
	_render()

func _build_ui():
	var top := ColorRect.new()
	top.color = Color(0.12, 0.1, 0.16)
	top.rect_position = Vector2(0, 0)
	top.rect_size = Vector2(1200, TOP_H)
	add_child(top)

	var x := 8.0
	x = _add_tool_button(x, "Nuevo", "_on_new", 80)
	x = _add_tool_button(x, "Abrir", "_on_open", 80)
	x = _add_tool_button(x, "Guardar", "_on_save", 90)
	x = _add_tool_button(x, "Guardar como", "_on_save_as", 110)
	x = _add_tool_button(x, "Probar", "_on_toggle_play", 90)
	x = _add_tool_button(x, "Salir", "_on_exit", 70)
	x += 4
	x = _add_tool_button(x, "?", "_toggle_help", 34)

	name_edit = LineEdit.new()
	name_edit.rect_position = Vector2(8, 38)
	name_edit.rect_size = Vector2(180, 24)
	name_edit.placeholder_text = "nombre del nivel"
	name_edit.add_font_override("font", UIFonts.make_font(14))
	name_edit.connect("text_entered", self, "_on_name_entered")
	add_child(name_edit)

	var theme_label := Label.new()
	theme_label.text = "Tema"
	theme_label.add_font_override("font", UIFonts.make_font(14))
	theme_label.add_color_override("font_color", Color(0.8, 0.8, 0.85))
	theme_label.rect_position = Vector2(196, 42)
	add_child(theme_label)

	theme_option = OptionButton.new()
	theme_option.rect_position = Vector2(238, 38)
	theme_option.rect_size = Vector2(120, 24)
	for t in THEMES:
		theme_option.add_item(t)
	theme_option.select(0)
	theme_option.connect("item_selected", self, "_on_theme_selected")
	add_child(theme_option)

	var boy_label := Label.new()
	boy_label.text = "Niño"
	boy_label.add_font_override("font", UIFonts.make_font(14))
	boy_label.add_color_override("font_color", Color(0.8, 0.8, 0.85))
	boy_label.rect_position = Vector2(368, 42)
	add_child(boy_label)

	boy_option = OptionButton.new()
	boy_option.rect_position = Vector2(408, 38)
	boy_option.rect_size = Vector2(90, 24)
	for b in BOYS:
		boy_option.add_item(b)
	boy_option.select(0)
	boy_option.connect("item_selected", self, "_on_boy_selected")
	add_child(boy_option)

	status_label = Label.new()
	status_label.rect_position = Vector2(510, 42)
	status_label.rect_size = Vector2(680, 22)
	status_label.add_font_override("font", UIFonts.make_font(14))
	status_label.add_color_override("font_color", Color(0.6, 0.9, 0.6))
	add_child(status_label)

	var pal := ColorRect.new()
	pal.color = Color(0.1, 0.08, 0.13)
	pal.rect_position = Vector2(0, 825 - BOTTOM_H)
	pal.rect_size = Vector2(1200, BOTTOM_H)
	add_child(pal)

	palette_scroll = ScrollContainer.new()
	palette_scroll.rect_position = Vector2(8, 825 - BOTTOM_H + 8)
	palette_scroll.rect_size = Vector2(1184, 42)
	palette_scroll.scroll_horizontal_enabled = true
	palette_scroll.scroll_vertical_enabled = false
	add_child(palette_scroll)

	var hbox := HBoxContainer.new()
	hbox.add_constant_override("separation", 6)
	palette_scroll.add_child(hbox)
	for entry in PALETTE:
		var btn := Button.new()
		btn.text = entry[0]
		btn.focus_mode = Control.FOCUS_NONE
		btn.toggle_mode = true
		btn.rect_min_size = Vector2(76, 38)
		btn.add_font_override("font", UIFonts.make_font(13))
		var block = entry[1]
		btn.connect("pressed", self, "_on_palette_pressed", [btn, block])
		hbox.add_child(btn)
		paint_buttons.append([btn, block])
	_select_paint(C.BLOCK_FLOOR)

	hint_label = Label.new()
	hint_label.text = "clic izq pintar · clic der borrar · arrastrar dibuja · flechas/D-pad mover · A/Enter pintar · 1-9 o Q/E bloque · G guardar · O abrir · N nuevo · T probar · F1 ayuda"
	hint_label.rect_position = Vector2(10, 825 - 22)
	hint_label.rect_size = Vector2(1180, 18)
	hint_label.add_font_override("font", UIFonts.make_font(13))
	hint_label.add_color_override("font_color", Color(0.6, 0.6, 0.7))
	add_child(hint_label)

	_build_help()

func _build_help():
	help_panel = Control.new()
	help_panel.rect_position = Vector2(0, 0)
	help_panel.rect_size = Vector2(1200, 825)
	add_child(help_panel)

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.08, 0.94)
	bg.rect_position = Vector2(0, 0)
	bg.rect_size = Vector2(1200, 825)
	help_panel.add_child(bg)

	var box := ColorRect.new()
	box.color = Color(0.13, 0.11, 0.17)
	box.rect_position = Vector2(160, 70)
	box.rect_size = Vector2(880, 620)
	help_panel.add_child(box)

	var title := Label.new()
	title.text = "EDITOR DE NIVELES TUMBLEBOY"
	title.add_font_override("font", UIFonts.make_font(26, true))
	title.add_color_override("font_color", Color(0.95, 0.9, 0.6))
	title.rect_position = Vector2(180, 90)
	help_panel.add_child(title)

	var body := Label.new()
	body.text = """MOUSE:  clic izq pintar · clic der borrar · arrastrar dibuja · rueda: ver paleta
TECLADO: flechas mover cursor · 1-9 / Q / E: elegir bloque
		 G guardar · O abrir · N nuevo · T probar · F1 cerrar esta ayuda
		 Retroceso: borrar · Ctrl+Z deshacer · Ctrl+Y rehacer
GAMEPAD / TV:  D-pad mover cursor · A pintar · L1/R1 cambiar bloque
		 B / ESC: volver (salir de la vista previa primero)
TOUCH:  tap pintar · arrastrar dibuja · deslizar la paleta para ver más bloques

FLUJO DE TRABAJO:
  1) Elige un bloque en la paleta de abajo (Inicio = $, Meta = 1).
  2) Pinta sobre el tablero.
  3) Ajusta Tema y Niño si quieres.
  4) Pulsa Probar (T) para testear el nivel con la bola.
  5) Pulsa Guardar (G); se guarda en user://tumbleboy_levels/."""
	body.add_font_override("font", UIFonts.make_font(16))
	body.add_color_override("font_color", Color(0.88, 0.88, 0.93))
	body.autowrap = true
	body.rect_position = Vector2(190, 140)
	body.rect_size = Vector2(820, 480)
	help_panel.add_child(body)

	var close := Button.new()
	close.text = "Cerrar  (F1)"
	close.rect_position = Vector2(480, 650)
	close.rect_size = Vector2(240, 34)
	close.add_font_override("font", UIFonts.make_font(15))
	close.connect("pressed", self, "_toggle_help")
	help_panel.add_child(close)

	help_panel.visible = false

func _toggle_help():
	help_visible = not help_visible
	help_panel.visible = help_visible
	if help_visible:
		_set_status("Ayuda (F1 para cerrar)")
	else:
		_set_status("")

func _add_tool_button(x: float, text: String, method: String, width: float) -> float:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.rect_position = Vector2(x, 8)
	btn.rect_size = Vector2(width, 30)
	btn.add_font_override("font", UIFonts.make_font(14))
	btn.connect("pressed", self, method)
	add_child(btn)
	return x + width + 4

func _on_name_entered(_text: String):
	_set_status("Nombre: " + name_edit.text)

func _on_theme_selected(_idx: int):
	attributes["theme"] = THEMES[theme_option.get_selected_id()]
	_render()

func _on_boy_selected(_idx: int):
	attributes["boy"] = BOYS[boy_option.get_selected_id()]

func _on_palette_pressed(btn: Button, block: int):
	_select_paint(block)
	_play_sfx_quiet()

func _select_paint(block: int):
	selected_block = block
	for i in range(paint_buttons.size()):
		paint_buttons[i][0].set_pressed(paint_buttons[i][1] == block)
	_set_status("Bloque: " + _block_name())
	update()

func _select_paint_index(idx: int):
	if idx < 0 or idx >= paint_buttons.size():
		return
	_select_paint(paint_buttons[idx][1])
	_scroll_palette_to(idx)

func _cycle_block(dir: int):
	var idx := 0
	for i in range(paint_buttons.size()):
		if paint_buttons[i][1] == selected_block:
			idx = i
			break
	idx = (idx + dir + paint_buttons.size()) % paint_buttons.size()
	_select_paint_index(idx)

func _scroll_palette_to(idx: int):
	if idx < 0 or idx >= paint_buttons.size():
		return
	var btn = paint_buttons[idx][0]
	var target: float = btn.rect_position.x + btn.rect_size.x * 0.5 - palette_scroll.rect_size.x * 0.5
	palette_scroll.scroll_horizontal = int(max(0.0, target))

func _block_name() -> String:
	for entry in PALETTE:
		if entry[1] == selected_block:
			return entry[0]
	return ""

func _play_sfx_quiet():
	AudioManager.play_sfx(C.SOUNDS_DIR + "hit_wall.ogg")

func _on_new():
	_new_board()
	_render()
	_set_status("Nuevo nivel")

func _new_board():
	map = []
	attributes = { "theme": "default", "boy": "boy1" }
	selected_block = C.BLOCK_FLOOR
	play_mode = false
	ball = null
	undo_stack = []
	redo_stack = []
	cursor_cell = Vector2.ZERO
	cursor_accum = Vector2.ZERO
	_name_sync()
	_theme_sync()
	_set_dim(12, 5)

func _set_dim(w: int, h: int):
	map = []
	for y in range(h):
		var row: Array = []
		for x in range(w):
			row.append(C.BLOCK_NONE)
		map.append(row)

func _name_sync():
	if name_edit != null:
		name_edit.text = attributes.get("name", "")

func _theme_sync():
	if theme_option != null:
		var t = attributes.get("theme", "default")
		var idx := THEMES.find(t)
		theme_option.select(idx if idx >= 0 else 0)
	if boy_option != null:
		var b = attributes.get("boy", "boy1")
		var idx2 := BOYS.find(b)
		boy_option.select(idx2 if idx2 >= 0 else 0)

func _on_open():
	dialog_open = true
	var fd := FileDialog.new()
	fd.mode = FileDialog.MODE_OPEN_FILE
	fd.access = FileDialog.ACCESS_RESOURCES
	fd.current_dir = C.LEVELS_DIR
	fd.add_filter("*.txt ; Niveles TumbleBoy")
	fd.window_title = "Abrir nivel"
	fd.connect("file_selected", self, "_on_open_selected")
	fd.connect("popup_hide", self, "_on_dialog_closed")
	add_child(fd)
	fd.popup_centered_ratio(0.8)

func _on_dialog_closed():
	dialog_open = false

func _on_open_selected(path: String):
	var info = LevelsScript.parse_level(path)
	map = info["map"]
	attributes = info["attributes"]
	selected_block = C.BLOCK_FLOOR
	play_mode = false
	ball = null
	undo_stack = []
	redo_stack = []
	cursor_cell = Vector2.ZERO
	cursor_accum = Vector2.ZERO
	_name_sync()
	_theme_sync()
	_render()
	_set_status("Abierto: " + path.get_file())

func _on_save():
	var msg := _validate_map()
	if msg != "":
		_set_status("No guardado: " + msg)
		return
	var fname := name_edit.text.strip_edges()
	if fname == "":
		fname = "nuevo_nivel"
	if not fname.ends_with(".txt"):
		fname += ".txt"
	if attributes.has("name"):
		attributes["name"] = name_edit.text.strip_edges()
	var dir := Directory.new()
	dir.make_dir_recursive("user://tumbleboy_levels")
	var path := "user://tumbleboy_levels/" + fname
	_save_to(path)

func _validate_map() -> String:
	var has_start := false
	var has_goal := false
	for row in map:
		for cell in row:
			if cell == C.BLOCK_START:
				has_start = true
			elif cell == C.BLOCK_GOAL:
				has_goal = true
	if not has_start:
		return "falta el bloque Inicio ($)"
	if not has_goal:
		return "falta el bloque Meta (1)"
	return ""

func _on_save_as():
	dialog_open = true
	var fd := FileDialog.new()
	fd.mode = FileDialog.MODE_SAVE_FILE
	fd.access = FileDialog.ACCESS_RESOURCES
	fd.current_dir = C.LEVELS_DIR
	fd.add_filter("*.txt ; Niveles TumbleBoy")
	fd.window_title = "Guardar nivel"
	fd.connect("file_selected", self, "_save_to")
	fd.connect("popup_hide", self, "_on_dialog_closed")
	add_child(fd)
	fd.popup_centered_ratio(0.8)

func _save_to(path: String):
	if not path.ends_with(".txt"):
		path += ".txt"
	var saved := LevelsScript.write_level(path, attributes, map)
	if saved:
		_set_status("Guardado: " + path)
	else:
		_set_status("ERROR al guardar")

func _on_toggle_play():
	if play_mode:
		_exit_play()
	else:
		_enter_play()

func _enter_play():
	_render_board_data()
	var sp = board.get_start_position()
	if board.block_at(int(sp.x), int(sp.y)) == C.BLOCK_START:
		ball = BallScript.new()
		ball.set_theme(attributes.get("boy", "boy1"))
		ball.set_board(board)
		ball.set_position(sp.x, sp.y, 0)
		play_mode = true
		_set_status("Vista previa: B para volver a editar")
	else:
		_set_status("Pon el bloque 'Inicio' ($) primero")

func _exit_play():
	play_mode = false
	ball = null
	_set_status("")

func _on_exit():
	get_tree().change_scene("res://scenes/MainMenu.tscn")

func _set_status(text: String):
	if status_label != null:
		status_label.text = text

func _render():
	_render_board_data()
	update()

func _render_board_data():
	board.clear()
	board.set_theme(attributes.get("theme", "default"))
	var w := 0
	for row in map:
		w = max(w, row.size())
	board.set_dimensions(w, map.size())
	for y in range(map.size()):
		var row = map[y]
		for x in range(row.size()):
			if row[x] != C.BLOCK_NONE:
				board.set_block(x, y, row[x])
	board_texture = board.render_board_image()

func _process(delta):
	if play_mode:
		_process_play(delta)
		return
	if dialog_open:
		return
	if help_visible:
		if InputManager.back_just_pressed():
			_toggle_help()
		return
	if InputManager.back_just_pressed():
		_on_exit()
		return
	if InputManager.confirm_just_pressed() and not _is_typing():
		_paint_cell(int(cursor_cell.x), int(cursor_cell.y), false)
	_update_cursor_from_mouse()
	_move_cursor(delta)
	update()

func _process_play(delta):
	if ball != null:
		anim_timer += delta
		var force := InputManager.get_move_vector()
		ball.add_force(force.x * delta * C.BALL_FORCE, force.y * delta * C.BALL_FORCE)
		ball.update(delta)
		if ball.is_above_goal():
			AudioManager.play_sfx(C.SOUNDS_DIR + "win_level.ogg")
			_exit_play()
			_set_status("Meta alcanzada")
	if InputManager.back_just_pressed():
		_exit_play()
	update()

func _is_typing() -> bool:
	return (name_edit != null and name_edit.has_focus()) or (theme_option != null and theme_option.has_focus()) or (boy_option != null and boy_option.has_focus())

func _move_cursor(delta):
	if board.width <= 0 or board.height <= 0:
		cursor_accum = Vector2.ZERO
		return
	if _is_typing():
		cursor_accum = Vector2.ZERO
		return
	var move := InputManager.get_move_vector()
	if move == Vector2.ZERO:
		cursor_accum = Vector2.ZERO
		return
	cursor_accum += move * delta * CURSOR_CELLS_PER_SEC
	var step := Vector2(int(cursor_accum.x), int(cursor_accum.y))
	if step != Vector2.ZERO:
		cursor_accum -= step
		cursor_cell += step
		cursor_cell.x = clamp(cursor_cell.x, 0, board.width - 1)
		cursor_cell.y = clamp(cursor_cell.y, 0, board.height - 1)

func _update_cursor_from_mouse():
	if InputManager.has_joypad():
		return
	var mpos := get_viewport().get_mouse_position()
	if mpos == last_mouse_pos:
		return
	last_mouse_pos = mpos
	var cell := _screen_to_cell(mpos)
	if cell.x >= 0 and cell.y >= 0:
		cursor_cell = cell

func _unhandled_input(ev):
	if play_mode:
		return
	if dialog_open:
		return
	if help_visible:
		if ev is InputEventKey and ev.pressed and not ev.echo and ev.scancode == KEY_F1:
			_toggle_help()
		return
	if ev is InputEventKey and ev.pressed and not ev.echo:
		_handle_key(ev)
		return
	_handle_paint_input(ev)

func _handle_key(ev):
	if ev.control:
		if ev.scancode == KEY_Z:
			if ev.shift:
				_redo()
			else:
				_undo()
		elif ev.scancode == KEY_Y:
			_redo()
		return
	if ev.scancode >= KEY_1 and ev.scancode <= KEY_9:
		_select_paint_index(ev.scancode - KEY_1)
		return
	match ev.scancode:
		KEY_Q:
			_cycle_block(-1)
		KEY_E:
			_cycle_block(1)
		KEY_G:
			_on_save()
		KEY_O:
			_on_open()
		KEY_N:
			_on_new()
		KEY_T:
			_on_toggle_play()
		KEY_F1:
			_toggle_help()
		KEY_BACKSPACE, KEY_DELETE:
			_paint_cell(int(cursor_cell.x), int(cursor_cell.y), true)

func _handle_paint_input(ev):
	if ev is InputEventMouseButton:
		if ev.pressed and (ev.button_index == BUTTON_LEFT or ev.button_index == BUTTON_RIGHT):
			mouse_button = ev.button_index
			_paint_at(ev.position, ev.button_index == BUTTON_RIGHT)
		elif not ev.pressed and ev.button_index == mouse_button:
			mouse_button = 0
	elif ev is InputEventMouseMotion and mouse_button != 0:
		_paint_at(ev.position, mouse_button == BUTTON_RIGHT)
	elif ev is InputEventScreenTouch:
		if ev.pressed:
			touch_painting = true
			_paint_at(ev.position, false)
		else:
			touch_painting = false
	elif ev is InputEventScreenDrag and touch_painting:
		_paint_at(ev.position, false)

func _paint_at(pos: Vector2, erase: bool):
	var cell := _screen_to_cell(pos)
	if cell.x >= 0 and cell.y >= 0:
		_paint_cell(int(cell.x), int(cell.y), erase)

func _screen_to_cell(pos: Vector2) -> Vector2:
	var area := _board_area()
	if area.size.x <= 0 or area.size.y <= 0:
		return Vector2(-1, -1)
	if pos.x < area.position.x or pos.y < area.position.y:
		return Vector2(-1, -1)
	if pos.x > area.end.x or pos.y > area.end.y:
		return Vector2(-1, -1)
	var local := (pos - area.position) / fit_scale
	return Vector2(int(local.x / C.PIXEL_SIZE), int(local.y / C.PIXEL_SIZE))

func _paint_cell(x: int, y: int, erase: bool):
	if y < 0 or y >= map.size():
		return
	var row = map[y]
	if x < 0 or x >= row.size():
		return
	var block := C.BLOCK_NONE if erase else selected_block
	var changed := false
	if block == C.BLOCK_START:
		for ry in range(map.size()):
			var r2 = map[ry]
			for rx in range(r2.size()):
				if r2[rx] == C.BLOCK_START:
					_push_undo(rx, ry, C.BLOCK_START, C.BLOCK_NONE)
					r2[rx] = C.BLOCK_NONE
					changed = true
	if map[y][x] != block:
		_push_undo(x, y, map[y][x], block)
		map[y][x] = block
		changed = true
	if changed:
		_render()

func _push_undo(x: int, y: int, old_block: int, new_block: int):
	undo_stack.append([x, y, old_block, new_block])
	if undo_stack.size() > UNDO_LIMIT:
		undo_stack.pop_front()
	redo_stack = []

func _undo():
	if undo_stack.empty():
		return
	var op = undo_stack.pop_back()
	redo_stack.append(op)
	map[op[1]][op[0]] = op[2]
	cursor_cell = Vector2(op[0], op[1])
	_render()
	_set_status("Deshacer")

func _redo():
	if redo_stack.empty():
		return
	var op = redo_stack.pop_back()
	undo_stack.append(op)
	map[op[1]][op[0]] = op[3]
	cursor_cell = Vector2(op[0], op[1])
	_render()
	_set_status("Rehacer")

func _board_area() -> Rect2:
	var board_px := float(board.width) * C.PIXEL_SIZE
	var board_py := float(board.height) * C.PIXEL_SIZE
	if board_px <= 0 or board_py <= 0:
		return Rect2(0, 0, 0, 0)
	var area := Rect2(20, TOP_H + 10, 1160, 825 - TOP_H - BOTTOM_H - 20)
	fit_scale = min(area.size.x / board_px, area.size.y / board_py)
	fit_origin = area.position + (area.size - Vector2(board_px, board_py) * fit_scale) * 0.5
	return Rect2(fit_origin, Vector2(board_px, board_py) * fit_scale)

func _draw():
	draw_rect(Rect2(0, 0, 1200, 825), Color(0.06, 0.05, 0.09))
	if play_mode:
		_draw_preview()
	else:
		_draw_edit()

func _draw_edit():
	var area := _board_area()
	if board_texture == null:
		return
	draw_set_transform(area.position, 0, Vector2(fit_scale, fit_scale))
	draw_texture(board_texture, Vector2.ZERO)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	for y in range(board.height + 1):
		draw_line(area.position + Vector2(0, y * C.PIXEL_SIZE * fit_scale), area.position + Vector2(board.width * C.PIXEL_SIZE * fit_scale, y * C.PIXEL_SIZE * fit_scale), Color(1, 1, 1, 0.08), 1)
	for x in range(board.width + 1):
		draw_line(area.position + Vector2(x * C.PIXEL_SIZE * fit_scale, 0), area.position + Vector2(x * C.PIXEL_SIZE * fit_scale, board.height * C.PIXEL_SIZE * fit_scale), Color(1, 1, 1, 0.08), 1)
	if cursor_cell.x >= 0 and cursor_cell.y >= 0 and cursor_cell.x < board.width and cursor_cell.y < board.height:
		_draw_cursor(area)
	_draw_swatch(area)

func _draw_cursor(area: Rect2):
	var cell_origin := area.position + cursor_cell * (C.PIXEL_SIZE * fit_scale)
	var cell_size := Vector2(C.PIXEL_SIZE, C.PIXEL_SIZE) * fit_scale
	var rect := Rect2(cell_origin, cell_size)
	if selected_block != C.BLOCK_NONE and selected_block < board.block_images.size():
		var preview: Texture = board.block_images[selected_block]
		if preview != null:
			draw_texture_rect(preview, rect, false)
	draw_rect(rect, Color(1, 1, 1, 0.45))
	if selected_block == C.BLOCK_NONE or selected_block >= board.block_images.size():
		draw_rect(rect, Color(0.9, 0.2, 0.2, 0.5))
	draw_rect(rect, Color(1, 1, 1, 0.9), false, 2.0)
	draw_rect(Rect2(cell_origin + Vector2(3, 3), cell_size - Vector2(6, 6)), Color(0.95, 0.9, 0.4, 0.8), false, 1.0)

func _draw_swatch(area: Rect2):
	var swatch_pos := Vector2(area.end.x - 158, area.position.y + 8)
	draw_rect(Rect2(swatch_pos, Vector2(150, 46)), Color(0.1, 0.1, 0.14, 0.85))
	var img: Texture = null
	if selected_block >= 0 and selected_block < board.block_images.size():
		img = board.block_images[selected_block]
	if img != null:
		draw_texture_rect(img, Rect2(swatch_pos + Vector2(5, 5), Vector2(36, 36)), false)
	else:
		draw_rect(Rect2(swatch_pos + Vector2(5, 5), Vector2(36, 36)), Color(0.9, 0.2, 0.2, 0.6))
	draw_string(font_swatch, swatch_pos + Vector2(48, 29), _block_name(), Color(0.9, 0.9, 0.95))

func _draw_preview():
	var area := _board_area()
	if board_texture != null:
		draw_set_transform(area.position, 0, Vector2(fit_scale, fit_scale))
		draw_texture(board_texture, Vector2.ZERO)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	if ball != null:
		if ball.images.size() == 0:
			ball.setup_images()
		var tex = ball.current_texture()
		if tex != null:
			var draw_pos := area.position + Vector2(
				ball.position.x * C.PIXEL_SIZE - C.BALLSPRITE_OFFSETX,
				ball.position.y * C.PIXEL_SIZE - C.BALLSPRITE_OFFSETY
			) * fit_scale
			draw_pos += ball.current_offs() * fit_scale
			var s: Vector2 = tex.get_size() * fit_scale
			draw_texture_rect(tex, Rect2(draw_pos, s), false)
