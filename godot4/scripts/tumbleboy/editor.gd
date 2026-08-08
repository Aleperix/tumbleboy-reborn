extends Node2D
# TumbleBoyEditor — editor visual de niveles con el formato .txt original.
# v3: help en 2 columnas, paleta sin Piso2/Piso3 (idénticos por tema),
# traducciones de temas/niños, campos autor/descripción (créditos),
# current_file + niveles de solo lectura, confirmación de guardado,
# creación y exportación de packs (ZIP + manifest.json).
# Port a Godot 4: rect_position -> position, rect_size -> size,
# add_font_override -> add_theme_font_override, connect -> Callable,
# ev.scancode -> ev.keycode, BUTTON_LEFT -> MOUSE_BUTTON_LEFT,
# Directory -> DirAccess, JSON.print -> JSON.stringify, focus_neighbour_* ->
# focus_neighbor_*, get_focus_owner() -> get_viewport().gui_get_focus_owner().

const C = preload("res://scripts/tumbleboy/tb_constants.gd")
const BoardScript = preload("res://scripts/tumbleboy/board.gd")
const BallScript = preload("res://scripts/tumbleboy/ball.gd")
const LevelsScript = preload("res://scripts/tumbleboy/levels.gd")
const UIFonts = preload("res://scripts/ui/ui_fonts.gd")
const PackReader = preload("res://scripts/tumbleboy/pack_reader.gd")
const ZIPWriter = preload("res://scripts/tumbleboy/zip_writer.gd")
const TouchControlsScene = preload("res://scenes/TouchControls.tscn")

const PALETTE := [
	["Borrar", C.BLOCK_NONE],
	["Piso", C.BLOCK_FLOOR],
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
const THEME_NAMES := { "default": "Por defecto", "beach": "Playa", "spacetheme1": "Tema espacial" }
const BOYS := ["boy1", "boy2", "boy3", "boy4"]
const BOY_NAMES := { "boy1": "Predeterminado", "boy2": "Astronauta", "boy3": "Camiseta amarilla", "boy4": "Estirado" }
const USER_LEVELS_DIR := "user://tumbleboy_levels/"
const PACKS_DIR := "user://tumbleboy_packs/"
const TOP_H := 90
const BOTTOM_H := 88
const CURSOR_CELLS_PER_SEC := 6.0
const UNDO_LIMIT := 50
const GRID_MAX_W := 60
const GRID_MAX_H := 40

var board = null
var ball = null
var map: Array = []
var attributes := {}
var selected_block := C.BLOCK_FLOOR
var play_mode := false
var play_button: Button
var touch_controls: Control = null
var board_texture: Texture2D = null
var anim_timer := 0.0

var current_file := ""
var read_only := false

var status_label: Label
var file_label: Label
var hint_label: Label
var name_edit: LineEdit
var author_edit: LineEdit
var desc_edit: LineEdit
var theme_option: OptionButton
var boy_option: OptionButton
var paint_buttons: Array = []
var palette_scroll: ScrollContainer
var help_panel: Control
var help_visible := false
var dialog_open := false
var confirm_dialog: ConfirmationDialog
var save_pending_path := ""

var pack_panel: Control
var pack_name_edit: LineEdit
var pack_author_edit: LineEdit
var pack_desc_edit: LineEdit
var pack_thumb_image: Image
var pack_thumb_texture: ImageTexture
var pack_thumb_preview: TextureRect
var available_list: ItemList
var pack_list: ItemList
var pack_available: Array = []
var pack_selected: Array = []

var cursor_cell := Vector2(0, 0)
var cursor_accum := Vector2.ZERO
var last_mouse_pos := Vector2(-9999, -9999)
var mouse_button := 0
var touch_painting := false
var _grew := false
var _draft_dirty := false
var _draft_timer := 0.0

var ui_mode := false
var _last_ui_control: Control = null
var ui_controls: Array = []
var ui_fields: Array = []
var toolbar_controls: Array = []

var undo_stack: Array = []
var redo_stack: Array = []

var font_swatch: Font

var fit_origin := Vector2.ZERO
var fit_scale := 1.0

func _ready():
	board = BoardScript.new()
	font_swatch = UIFonts.make_font(15)
	_build_ui()
	if NavParams.open_draft and SaveData.has_draft():
		_load_draft(SaveData.get_draft())
		NavParams.open_draft = false
	elif NavParams.open_file != "":
		var path := NavParams.open_file
		NavParams.open_file = ""
		_new_board()
		call_deferred("open_file", path)
	elif NavParams.open_pack_panel:
		NavParams.open_pack_panel = false
		_new_board()
		call_deferred("open_pack_panel")
	else:
		SaveData.clear_draft()
		_new_board()
	_setup_touch_controls()
	_render()

func _setup_touch_controls():
	# En móvil, el joystick + switch Mando/Acelerómetro aparecen al probar el
	# nivel (play_mode) igual que en la partida; ocultos al editar para no
	# interferir con la pintura táctil.
	touch_controls = TouchControlsScene.instantiate()
	add_child(touch_controls)
	_sync_touch_controls()

func _sync_touch_controls():
	if touch_controls != null:
		touch_controls.visible = InputManager.is_mobile() and play_mode
		touch_controls.queue_redraw()

func _build_ui():
	var top := ColorRect.new()
	top.color = Color(0.12, 0.1, 0.16)
	top.position = Vector2(0, 0)
	top.size = Vector2(1200, TOP_H)
	add_child(top)

	var x := 8.0
	x = _add_tool_button(x, "Nuevo", "_on_new", 80)
	x = _add_tool_button(x, "Abrir", "_on_open", 80)
	x = _add_tool_button(x, "Guardar", "_on_save", 90)
	x = _add_tool_button(x, "Guardar como", "_on_save_as", 110)

	play_button = _make_tool_button("Probar", "_on_toggle_play", 90)
	play_button.position = Vector2(555, 8)

	_make_tool_button("Crear pack", "_on_open_pack", 104).position = Vector2(830, 8)
	_make_tool_button("Exportar pack", "_on_open_export", 124).position = Vector2(938, 8)
	_make_tool_button("?", "_toggle_help", 34).position = Vector2(1076, 8)
	_make_tool_button("Salir", "_on_exit", 70).position = Vector2(1122, 8)

	name_edit = LineEdit.new()
	name_edit.position = Vector2(8, 40)
	name_edit.size = Vector2(140, 24)
	name_edit.placeholder_text = "nombre del nivel"
	UIFonts.style_font(name_edit, 14)
	name_edit.text_submitted.connect(_on_name_entered)
	name_edit.text_changed.connect(_on_field_changed)
	add_child(name_edit)
	ui_fields.append(name_edit)

	author_edit = LineEdit.new()
	author_edit.position = Vector2(156, 40)
	author_edit.size = Vector2(140, 24)
	author_edit.placeholder_text = "autor / créditos"
	UIFonts.style_font(author_edit, 14)
	author_edit.text_changed.connect(_on_field_changed)
	add_child(author_edit)
	ui_fields.append(author_edit)

	var theme_label := Label.new()
	theme_label.text = "Tema"
	UIFonts.style_font(theme_label, 14)
	theme_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	theme_label.position = Vector2(304, 44)
	add_child(theme_label)

	theme_option = OptionButton.new()
	theme_option.position = Vector2(352, 40)
	theme_option.size = Vector2(150, 24)
	for t in THEMES:
		theme_option.add_item(THEME_NAMES.get(t, t))
	theme_option.select(0)
	theme_option.item_selected.connect(_on_theme_selected)
	add_child(theme_option)
	ui_fields.append(theme_option)

	var boy_label := Label.new()
	boy_label.text = "Niño"
	UIFonts.style_font(boy_label, 14)
	boy_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	boy_label.position = Vector2(512, 44)
	add_child(boy_label)

	boy_option = OptionButton.new()
	boy_option.position = Vector2(556, 40)
	boy_option.size = Vector2(170, 24)
	for b in BOYS:
		boy_option.add_item(BOY_NAMES.get(b, b))
	boy_option.select(0)
	boy_option.item_selected.connect(_on_boy_selected)
	add_child(boy_option)
	ui_fields.append(boy_option)

	status_label = Label.new()
	status_label.position = Vector2(736, 42)
	status_label.size = Vector2(456, 22)
	UIFonts.style_font(status_label, 14)
	status_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
	add_child(status_label)

	desc_edit = LineEdit.new()
	desc_edit.position = Vector2(8, 64)
	desc_edit.size = Vector2(360, 24)
	desc_edit.placeholder_text = "descripción del nivel"
	UIFonts.style_font(desc_edit, 14)
	desc_edit.text_changed.connect(_on_field_changed)
	add_child(desc_edit)
	ui_fields.append(desc_edit)

	file_label = Label.new()
	file_label.position = Vector2(380, 66)
	file_label.size = Vector2(812, 20)
	UIFonts.style_font(file_label, 13)
	file_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	add_child(file_label)

	var pal := ColorRect.new()
	pal.color = Color(0.1, 0.08, 0.13)
	pal.position = Vector2(0, 825 - BOTTOM_H)
	pal.size = Vector2(1200, BOTTOM_H)
	add_child(pal)

	palette_scroll = ScrollContainer.new()
	palette_scroll.position = Vector2(8, 825 - BOTTOM_H + 8)
	palette_scroll.size = Vector2(1184, 42)
	palette_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	palette_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(palette_scroll)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	palette_scroll.add_child(hbox)
	for entry in PALETTE:
		var btn := Button.new()
		btn.text = entry[0]
		btn.focus_mode = Control.FOCUS_NONE
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(76, 38)
		UIFonts.style_font(btn, 13)
		var block = entry[1]
		btn.pressed.connect(_on_palette_pressed.bind(btn, block))
		hbox.add_child(btn)
		paint_buttons.append([btn, block])
		ui_controls.append(btn)
	_select_paint(C.BLOCK_FLOOR)

	hint_label = Label.new()
	hint_label.text = "clic izq pintar · clic der borrar · arrastrar dibuja · flechas/D-pad mover · A/Enter pintar · 1-9 o Q/E bloque · G guardar · O abrir · N nuevo · T probar · F1 ayuda · F2/Y foco UI"
	hint_label.position = Vector2(10, 825 - 22)
	hint_label.size = Vector2(1180, 18)
	UIFonts.style_font(hint_label, 13)
	hint_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	add_child(hint_label)

	confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.title = "Guardar nivel"
	confirm_dialog.get_ok_button().text = "Guardar"
	confirm_dialog.cancel_button_text = "Cancelar"
	confirm_dialog.confirmed.connect(_on_save_confirmed)
	confirm_dialog.visibility_changed.connect(func(): if not confirm_dialog.visible: _on_dialog_closed())
	add_child(confirm_dialog)

	_build_help()
	_build_pack_panel()
	_build_export_panel()
	_sync_file_label()
	_wire_focus_rows()

# Conecta los vecinos de foco entre los controles de cada fila (toolbar arriba,
# campos en las filas 2ª/3ª y paleta abajo) y entre filas adyacentes. Con
# posiciones manuales bajo un Node2D la búsqueda automática de Godot no
# siempre encuentra vecino; fijar los focus_neighbor_* garantiza que el D-pad
# recorra cada fila en modo foco UI y salte entre ellas. Las filas se asignan
# explícitamente porque la paleta vive dentro de su ScrollContainer y su
# position es relativa al HBox (y=0), mientras toolbar/campos son hijos
# directos con y absoluta.
func _wire_focus_rows():
	var toolbar: Array = []
	for c in toolbar_controls:
		if is_instance_valid(c):
			toolbar.append(c)
	var fields2 := []
	var fields3 := []
	for f in ui_fields:
		if not is_instance_valid(f):
			continue
		if int(f.position.y) <= 50:
			fields2.append(f)
		else:
			fields3.append(f)
	var palette: Array = []
	for c in ui_controls:
		if is_instance_valid(c) and not toolbar_controls.has(c):
			palette.append(c)
	var rows := [toolbar, fields2, fields3, palette]
	for row in rows:
		row.sort_custom(_focus_sort_x)
		for i in range(row.size()):
			var c: Control = row[i]
			if i > 0:
				c.focus_neighbor_left = row[i - 1].get_path()
			if i < row.size() - 1:
				c.focus_neighbor_right = row[i + 1].get_path()
	for i in range(rows.size() - 1):
		if rows[i].size() > 0 and rows[i + 1].size() > 0:
			_wire_vertical(rows[i], rows[i + 1])

func _focus_sort_x(a: Control, b: Control) -> bool:
	return a.position.x < b.position.x

func _wire_vertical(upper: Array, lower: Array):
	for c in lower:
		c.focus_neighbor_top = _nearest_focus(upper, c).get_path()
	for c in upper:
		c.focus_neighbor_bottom = _nearest_focus(lower, c).get_path()

func _nearest_focus(row: Array, c: Control) -> Control:
	var best: Control = row[0]
	for other in row:
		if abs(other.position.x - c.position.x) < abs(best.position.x - c.position.x):
			best = other
	return best

func _build_help():
	help_panel = Control.new()
	help_panel.position = Vector2(0, 0)
	help_panel.size = Vector2(1200, 825)
	add_child(help_panel)

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.08, 0.94)
	bg.position = Vector2(0, 0)
	bg.size = Vector2(1200, 825)
	help_panel.add_child(bg)

	var box := ColorRect.new()
	box.color = Color(0.13, 0.11, 0.17)
	box.position = Vector2(120, 60)
	box.size = Vector2(960, 680)
	help_panel.add_child(box)

	var title := Label.new()
	title.text = "EDITOR DE NIVELES TUMBLEBOY"
	UIFonts.style_font(title, 26, true)
	title.add_theme_color_override("font_color", Color(0.95, 0.9, 0.6))
	title.position = Vector2(180, 84)
	help_panel.add_child(title)

	var hrow := HBoxContainer.new()
	hrow.position = Vector2(180, 140)
	hrow.size = Vector2(840, 400)
	help_panel.add_child(hrow)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 6)
	hrow.add_child(left)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	hrow.add_child(right)

	for entry in [
		["MOUSE", true],
		["  clic izq pintar", false],
		["  clic der borrar", false],
		["  arrastrar dibuja", false],
		["  rueda: ver paleta", false],
		["TECLADO", true],
		["  flechas: mover cursor", false],
		["  1-9 / Q / E: bloque", false],
		["  G guardar · O abrir", false],
		["  N nuevo · T probar", false],
		["  Retroceso: borrar", false],
		["  Ctrl+Z deshacer · Ctrl+Y rehacer", false],
		["  F1: cerrar esta ayuda", false],
	]:
		if entry[1]:
			left.add_child(_help_heading(entry[0]))
		else:
			left.add_child(_help_line(entry[0]))

	for entry in [
		["GAMEPAD / TV", true],
		["  D-pad: mover cursor", false],
		["  A pintar", false],
		["  L1/R1: cambiar bloque", false],
		["  B / ESC: volver", false],
		["  En el borde del tablero: arriba/abajo salta a botones", false],
		["  En los botones: arriba/abajo vuelve al tablero", false],
		["TOUCH", true],
		["  tap pintar", false],
		["  arrastrar dibuja", false],
		["  desliza la paleta", false],
		["", false],
		["FLUJO DE TRABAJO", true],
		["  1) Elige un bloque abajo (Inicio = $, Meta = 1)", false],
		["  2) Pinta sobre el tablero.", false],
		["  3) Ajusta Tema y Niño (créditos: autor/descripción).", false],
		["  4) Probar (T) testea con la bola.", false],
		["  5) Guardar (G) → user://tumbleboy_levels/", false],
	]:
		if entry[1]:
			right.add_child(_help_heading(entry[0]))
		else:
			right.add_child(_help_line(entry[0]))

	var close := Button.new()
	close.text = "Cerrar  (F1)"
	close.position = Vector2(480, 660)
	close.size = Vector2(240, 34)
	UIFonts.style_font(close, 15)
	close.pressed.connect(_toggle_help)
	help_panel.add_child(close)

	help_panel.visible = false

func _help_heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	UIFonts.style_font(l, 17, true)
	l.add_theme_color_override("font_color", Color(0.95, 0.9, 0.6))
	return l

func _help_line(text: String) -> Label:
	var l := Label.new()
	l.text = text
	UIFonts.style_font(l, 15)
	l.add_theme_color_override("font_color", Color(0.88, 0.88, 0.93))
	return l

func _build_pack_panel():
	pack_panel = Control.new()
	pack_panel.position = Vector2(0, 0)
	pack_panel.size = Vector2(1200, 825)
	add_child(pack_panel)

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.08, 0.94)
	bg.position = Vector2(0, 0)
	bg.size = Vector2(1200, 825)
	pack_panel.add_child(bg)

	var box := ColorRect.new()
	box.color = Color(0.13, 0.11, 0.17)
	box.position = Vector2(120, 50)
	box.size = Vector2(960, 700)
	pack_panel.add_child(box)

	var title := Label.new()
	title.text = "CREAR PACK"
	UIFonts.style_font(title, 26, true)
	title.add_theme_color_override("font_color", Color(0.95, 0.9, 0.6))
	title.position = Vector2(180, 70)
	pack_panel.add_child(title)

	var note := Label.new()
	note.text = "El pack se guarda como ZIP en user://tumbleboy_packs/ (título + créditos obligatorios)."
	UIFonts.style_font(note, 14)
	note.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	note.position = Vector2(180, 108)
	pack_panel.add_child(note)

	var lab1 := Label.new()
	lab1.text = "Título (id del pack):"
	UIFonts.style_font(lab1, 14)
	lab1.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	lab1.position = Vector2(180, 140)
	pack_panel.add_child(lab1)

	pack_name_edit = LineEdit.new()
	pack_name_edit.position = Vector2(320, 138)
	pack_name_edit.size = Vector2(440, 24)
	UIFonts.style_font(pack_name_edit, 14)
	pack_panel.add_child(pack_name_edit)

	var lab2 := Label.new()
	lab2.text = "Autor / créditos:"
	UIFonts.style_font(lab2, 14)
	lab2.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	lab2.position = Vector2(180, 172)
	pack_panel.add_child(lab2)

	pack_author_edit = LineEdit.new()
	pack_author_edit.position = Vector2(320, 170)
	pack_author_edit.size = Vector2(440, 24)
	UIFonts.style_font(pack_author_edit, 14)
	pack_panel.add_child(pack_author_edit)

	var lab3 := Label.new()
	lab3.text = "Descripción:"
	UIFonts.style_font(lab3, 14)
	lab3.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	lab3.position = Vector2(180, 204)
	pack_panel.add_child(lab3)

	pack_desc_edit = LineEdit.new()
	pack_desc_edit.position = Vector2(320, 202)
	pack_desc_edit.size = Vector2(600, 24)
	UIFonts.style_font(pack_desc_edit, 14)
	pack_panel.add_child(pack_desc_edit)

	var thumb_label := Label.new()
	thumb_label.text = "Miniatura:"
	UIFonts.style_font(thumb_label, 14)
	thumb_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	thumb_label.position = Vector2(180, 242)
	pack_panel.add_child(thumb_label)

	pack_thumb_preview = TextureRect.new()
	pack_thumb_preview.position = Vector2(300, 232)
	pack_thumb_preview.size = Vector2(96, 96)
	pack_thumb_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pack_panel.add_child(pack_thumb_preview)

	var thumb_btn_pick := Button.new()
	thumb_btn_pick.text = "Seleccionar imagen..."
	thumb_btn_pick.position = Vector2(416, 236)
	thumb_btn_pick.size = Vector2(180, 30)
	UIFonts.style_font(thumb_btn_pick, 13)
	thumb_btn_pick.pressed.connect(_on_pick_thumb)
	pack_panel.add_child(thumb_btn_pick)

	var thumb_btn_auto := Button.new()
	thumb_btn_auto.text = "Generar desde el primer nivel"
	thumb_btn_auto.position = Vector2(416, 274)
	thumb_btn_auto.size = Vector2(180, 30)
	UIFonts.style_font(thumb_btn_auto, 13)
	thumb_btn_auto.pressed.connect(_on_auto_thumb)
	pack_panel.add_child(thumb_btn_auto)

	var col_label := Label.new()
	col_label.text = "Niveles de usuario disponibles:"
	UIFonts.style_font(col_label, 15)
	col_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	col_label.position = Vector2(180, 344)
	pack_panel.add_child(col_label)

	available_list = ItemList.new()
	available_list.position = Vector2(180, 374)
	available_list.size = Vector2(360, 300)
	UIFonts.style_font(available_list, 14)
	available_list.focus_mode = Control.FOCUS_ALL
	pack_panel.add_child(available_list)

	var mid := VBoxContainer.new()
	mid.position = Vector2(556, 394)
	mid.size = Vector2(88, 260)
	mid.add_theme_constant_override("separation", 8)
	pack_panel.add_child(mid)
	mid.add_child(_pack_mid_button(">", "_on_pack_add"))
	mid.add_child(_pack_mid_button("<", "_on_pack_remove"))
	mid.add_child(_pack_mid_button("Subir", "_on_pack_up"))
	mid.add_child(_pack_mid_button("Bajar", "_on_pack_down"))

	var order_label := Label.new()
	order_label.text = "Niveles del pack (en orden):"
	UIFonts.style_font(order_label, 15)
	order_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	order_label.position = Vector2(660, 344)
	pack_panel.add_child(order_label)

	pack_list = ItemList.new()
	pack_list.position = Vector2(660, 374)
	pack_list.size = Vector2(360, 300)
	UIFonts.style_font(pack_list, 14)
	pack_list.focus_mode = Control.FOCUS_ALL
	pack_panel.add_child(pack_list)

	var ok := Button.new()
	ok.text = "Crear pack"
	ok.position = Vector2(560, 700)
	ok.size = Vector2(160, 36)
	UIFonts.style_font(ok, 15)
	ok.pressed.connect(_on_create_pack)
	pack_panel.add_child(ok)

	var cancel := Button.new()
	cancel.text = "Cancelar"
	cancel.position = Vector2(740, 700)
	cancel.size = Vector2(160, 36)
	UIFonts.style_font(cancel, 15)
	cancel.pressed.connect(_on_close_pack)
	pack_panel.add_child(cancel)

	pack_panel.visible = false

func _pack_mid_button(text: String, method: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(80, 34)
	UIFonts.style_font(b, 14)
	b.pressed.connect(Callable(self, method))
	return b

func _build_export_panel():
	var panel := Control.new()
	panel.position = Vector2(0, 0)
	panel.size = Vector2(1200, 825)
	add_child(panel)
	export_panel = panel

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.08, 0.94)
	bg.position = Vector2(0, 0)
	bg.size = Vector2(1200, 825)
	panel.add_child(bg)

	var box := ColorRect.new()
	box.color = Color(0.13, 0.11, 0.17)
	box.position = Vector2(200, 120)
	box.size = Vector2(800, 480)
	panel.add_child(box)

	var title := Label.new()
	title.text = "EXPORTAR PACK"
	UIFonts.style_font(title, 24, true)
	title.add_theme_color_override("font_color", Color(0.95, 0.9, 0.6))
	title.position = Vector2(240, 150)
	panel.add_child(title)

	var note := Label.new()
	note.text = "Elige un pack para copiar su ZIP a otra carpeta y compartirlo."
	UIFonts.style_font(note, 14)
	note.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	note.position = Vector2(240, 190)
	panel.add_child(note)

	export_list = ItemList.new()
	export_list.position = Vector2(240, 230)
	export_list.size = Vector2(720, 250)
	UIFonts.style_font(export_list, 14)
	export_list.focus_mode = Control.FOCUS_ALL
	panel.add_child(export_list)

	var ok := Button.new()
	ok.text = "Exportar"
	ok.position = Vector2(440, 510)
	ok.size = Vector2(160, 36)
	UIFonts.style_font(ok, 15)
	ok.pressed.connect(_on_export_selected)
	panel.add_child(ok)

	var cancel := Button.new()
	cancel.text = "Cancelar"
	cancel.position = Vector2(620, 510)
	cancel.size = Vector2(160, 36)
	UIFonts.style_font(cancel, 15)
	cancel.pressed.connect(_on_close_export)
	panel.add_child(cancel)

	panel.visible = false

var export_panel: Control
var export_list: ItemList
var export_packs: Array = []

func _toggle_help():
	help_visible = not help_visible
	help_panel.visible = help_visible
	if help_visible:
		_set_status("Ayuda (F1 para cerrar)")
	else:
		_set_status("")

func _add_tool_button(x: float, text: String, method: String, width: float) -> float:
	var btn := _make_tool_button(text, method, width)
	btn.position = Vector2(x, 8)
	return x + width + 4

func _make_tool_button(text: String, method: String, width: float) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.size = Vector2(width, 30)
	UIFonts.style_font(btn, 14)
	btn.pressed.connect(Callable(self, method))
	add_child(btn)
	ui_controls.append(btn)
	toolbar_controls.append(btn)
	return btn

func _on_name_entered(_text: String):
	_set_status("Nombre: " + name_edit.text)

func _on_field_changed(_text: String):
	_mark_draft_dirty()

func _on_theme_selected(idx: int):
	attributes["theme"] = THEMES[idx]
	_mark_draft_dirty()
	_render()

func _on_boy_selected(idx: int):
	attributes["boy"] = BOYS[idx]
	_mark_draft_dirty()

func _on_palette_pressed(btn: Button, block: int):
	_select_paint(block)
	_play_sfx_quiet()

func _select_paint(block: int):
	selected_block = block
	for i in range(paint_buttons.size()):
		paint_buttons[i][0].set_pressed(paint_buttons[i][1] == block)
	_set_status("Bloque: " + _block_name())
	queue_redraw()

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
	var target: float = btn.position.x + btn.size.x * 0.5 - palette_scroll.size.x * 0.5
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
	_sync_play_button()
	ball = null
	undo_stack = []
	redo_stack = []
	cursor_cell = Vector2.ZERO
	cursor_accum = Vector2.ZERO
	current_file = ""
	read_only = false
	SaveData.clear_draft()
	_draft_dirty = false
	_attributes_to_fields()
	_theme_sync()
	_sync_file_label()
	_set_dim(20, 12)

func _set_dim(w: int, h: int):
	map = []
	for y in range(h):
		var row: Array = []
		for x in range(w):
			row.append(C.BLOCK_NONE)
		map.append(row)

func _attributes_to_fields():
	if name_edit != null:
		name_edit.text = attributes.get("name", "")
	if author_edit != null:
		author_edit.text = attributes.get("author", "")
	if desc_edit != null:
		desc_edit.text = attributes.get("instructions", "")

func _collect_fields_to_attributes():
	attributes["name"] = name_edit.text.strip_edges()
	attributes["author"] = author_edit.text.strip_edges()
	attributes["instructions"] = desc_edit.text.strip_edges()

func _theme_sync():
	if theme_option != null:
		var t = attributes.get("theme", "default")
		var idx := THEMES.find(t)
		theme_option.select(idx if idx >= 0 else 0)
	if boy_option != null:
		var b = attributes.get("boy", "boy1")
		var idx2 := BOYS.find(b)
		boy_option.select(idx2 if idx2 >= 0 else 0)

func _sync_file_label():
	if file_label == null:
		return
	if current_file == "":
		file_label.text = "Sin archivo — nivel nuevo"
	else:
		var suffix := "  (solo lectura: usa 'Guardar como')" if read_only else ""
		file_label.text = "Archivo: " + current_file + suffix

func _on_open():
	dialog_open = true
	var fd := FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.access = FileDialog.ACCESS_RESOURCES
	fd.current_dir = USER_LEVELS_DIR
	fd.add_filter("*.txt ; Niveles TumbleBoy")
	fd.title = "Abrir nivel"
	fd.file_selected.connect(_on_open_selected)
	fd.visibility_changed.connect(func(): if not fd.visible: _on_dialog_closed())
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
	_sync_play_button()
	ball = null
	undo_stack = []
	redo_stack = []
	cursor_cell = Vector2.ZERO
	cursor_accum = Vector2.ZERO
	current_file = path
	read_only = path.begins_with("res://")
	SaveData.clear_draft()
	_draft_dirty = false
	_attributes_to_fields()
	_theme_sync()
	_sync_file_label()
	_render()
	_set_status("Abierto: " + path.get_file() + ("  (solo lectura)" if read_only else ""))

func _on_save():
	if read_only:
		_set_status("Nivel de solo lectura: usa 'Guardar como' para copiarlo a tus niveles")
		return
	var fmsg := _validate_fields()
	if fmsg != "":
		_set_status("No guardado: " + fmsg)
		return
	var msg := _validate_map()
	if msg != "":
		_set_status("No guardado: " + msg)
		return
	_collect_fields_to_attributes()
	var fname := name_edit.text.strip_edges()
	if fname == "":
		fname = "nuevo_nivel"
	if not fname.ends_with(".txt"):
		fname += ".txt"
	save_pending_path = USER_LEVELS_DIR + fname
	confirm_dialog.dialog_text = "¿Guardar en\n" + save_pending_path + "?"
	confirm_dialog.popup_centered()
	dialog_open = true

func _on_save_confirmed():
	dialog_open = false
	_save_to(save_pending_path)

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

func _validate_fields() -> String:
	_collect_fields_to_attributes()
	if attributes.get("name", "").strip_edges() == "":
		return "escribe el nombre del nivel"
	if attributes.get("author", "").strip_edges() == "":
		return "escribe el autor / créditos"
	if attributes.get("instructions", "").strip_edges() == "":
		return "escribe la descripción del nivel"
	return ""

func _on_save_as():
	dialog_open = true
	var fd := FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	fd.access = FileDialog.ACCESS_RESOURCES
	fd.current_dir = USER_LEVELS_DIR
	fd.add_filter("*.txt ; Niveles TumbleBoy")
	fd.title = "Guardar nivel como"
	fd.file_selected.connect(_save_to)
	fd.visibility_changed.connect(func(): if not fd.visible: _on_dialog_closed())
	add_child(fd)
	fd.popup_centered_ratio(0.8)

func _save_to(path: String):
	if not path.ends_with(".txt"):
		path += ".txt"
	var fmsg := _validate_fields()
	if fmsg != "":
		_set_status("No guardado: " + fmsg)
		return
	var dir := DirAccess.open("user://")
	if dir != null:
		dir.make_dir_recursive(path.get_base_dir())
	_collect_fields_to_attributes()
	var saved := LevelsScript.write_level(path, attributes, map)
	if saved:
		current_file = path
		read_only = false
		SaveData.clear_draft()
		_draft_dirty = false
		_sync_file_label()
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
		_sync_play_button()
		_sync_touch_controls()
		_set_status("Vista previa: B para volver a editar")
	else:
		_set_status("Pon el bloque 'Inicio' ($) primero")

func _exit_play():
	play_mode = false
	ball = null
	_sync_play_button()
	_sync_touch_controls()
	_set_status("")

func _sync_play_button():
	if play_button != null:
		play_button.text = "Parar" if play_mode else "Probar"

func _on_exit():
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _set_status(text: String):
	if status_label != null:
		status_label.text = text

func _render():
	_render_board_data()
	queue_redraw()

func _exit_tree():
	if _draft_dirty:
		_save_draft()

func _mark_draft_dirty():
	_draft_dirty = true
	_draft_timer = 0.0

func _save_draft():
	_collect_fields_to_attributes()
	SaveData.save_draft({
		"map": map,
		"attributes": attributes,
		"current_file": current_file,
		"read_only": read_only,
		"updated": Time.get_unix_time_from_system()
	})
	_draft_dirty = false

func _load_draft(data: Dictionary):
	map = data.get("map", [])
	attributes = data.get("attributes", {})
	current_file = data.get("current_file", "")
	read_only = data.get("read_only", false)
	selected_block = C.BLOCK_FLOOR
	ball = null
	undo_stack = []
	redo_stack = []
	cursor_cell = Vector2.ZERO
	cursor_accum = Vector2.ZERO
	_attributes_to_fields()
	_theme_sync()
	_sync_file_label()
	_draft_dirty = false
	_set_status("Borrador restaurado")
	_render()

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
	if _draft_dirty:
		_draft_timer += delta
		if _draft_timer >= 2.5:
			_save_draft()
	if play_mode:
		_process_play(delta)
		return
	if pack_panel.visible or export_panel.visible:
		if InputManager.back_just_pressed():
			if pack_panel.visible:
				_on_close_pack()
			else:
				_on_close_export()
		return
	if dialog_open:
		return
	if help_visible:
		if InputManager.back_just_pressed():
			_toggle_help()
		return
	if ui_mode:
		if InputManager.ui_toggle_just_pressed() or InputManager.back_just_pressed():
			_toggle_ui_mode()
			return
		var fo: Control = _focus_owner()
		if fo != null:
			_last_ui_control = fo
		return
	if InputManager.ui_toggle_just_pressed():
		_toggle_ui_mode()
		return
	if InputManager.back_just_pressed():
		_on_exit()
		return
	if InputManager.confirm_just_pressed() and not _is_typing():
		_paint_cell(int(cursor_cell.x), int(cursor_cell.y), false)
	_update_cursor_from_mouse()
	_move_cursor(delta)
	queue_redraw()

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
	queue_redraw()

func _is_typing() -> bool:
	return (name_edit != null and name_edit.has_focus()) or (author_edit != null and author_edit.has_focus()) or (desc_edit != null and desc_edit.has_focus()) or (theme_option != null and theme_option.has_focus()) or (boy_option != null and boy_option.has_focus())

func _focus_owner() -> Control:
	return get_viewport().gui_get_focus_owner()

func _release_focus():
	var fo := _focus_owner()
	if fo != null:
		fo.release_focus()

func _toggle_ui_mode():
	if ui_mode:
		_exit_ui_focus()
	else:
		_enter_ui_focus(null)

func _enter_ui_focus(target: Control):
	_set_ui_focus_mode(Control.FOCUS_ALL)
	ui_mode = true
	var t: Control = target
	if t == null or not is_instance_valid(t) or not t.is_inside_tree():
		t = _last_ui_control
	if t == null or not is_instance_valid(t) or not t.is_inside_tree():
		t = play_button
	if t != null:
		t.grab_focus()
	cursor_accum = Vector2.ZERO
	_set_status("Foco UI: D-pad navega · A activa · B vuelve al plano")

func _exit_ui_focus():
	var fo: Control = _focus_owner()
	if fo != null:
		fo.release_focus()
	_set_ui_focus_mode(Control.FOCUS_NONE)
	ui_mode = false
	cursor_accum = Vector2.ZERO
	_set_status("")

# Transición automática celda ↔ botones: al llegar al tope del tablero (arriba)
# salta a la toolbar, al borde inferior a la paleta; se llama desde _move_cursor
# con la celda anterior para no dispararse desde el medio del grid.
func _try_ui_edge(step: Vector2, prev: Vector2) -> bool:
	if ui_mode or play_mode or dialog_open or help_visible:
		return false
	if step.y < 0 and prev.y <= 0:
		_enter_ui_focus(ui_controls[0] if ui_controls.size() > 0 else null)
		return true
	if step.y > 0 and prev.y >= _visible_max_cell().y:
		_enter_ui_focus(_selected_paint_button())
		return true
	return false

func _selected_paint_button() -> Control:
	for entry in paint_buttons:
		if entry[1] == selected_block:
			return entry[0]
	if paint_buttons.size() > 0:
		return paint_buttons[0][0]
	return null

func _set_ui_focus_mode(mode: int):
	for c in ui_controls:
		if is_instance_valid(c):
			c.focus_mode = mode

func _move_cursor(delta):
	if board.width <= 0 or board.height <= 0:
		cursor_accum = Vector2.ZERO
		return
	if _is_typing():
		cursor_accum = Vector2.ZERO
		return
	var move := InputManager.get_hardware_move_vector()
	if move == Vector2.ZERO:
		cursor_accum = Vector2.ZERO
		return
	cursor_accum += move * delta * CURSOR_CELLS_PER_SEC
	var step := Vector2(int(cursor_accum.x), int(cursor_accum.y))
	if step != Vector2.ZERO:
		cursor_accum -= step
		var prev := cursor_cell
		cursor_cell += step
		var max_cell := _visible_max_cell()
		cursor_cell.x = clamp(cursor_cell.x, 0, max_cell.x)
		cursor_cell.y = clamp(cursor_cell.y, 0, max_cell.y)
		if _try_ui_edge(step, prev):
			return

func _visible_max_cell() -> Vector2:
	var draw := _draw_area()
	var cell := C.PIXEL_SIZE * fit_scale
	if cell <= 0:
		return Vector2.ZERO
	return Vector2(max(0, int(floor(draw.size.x / cell))), max(0, int(floor(draw.size.y / cell))))

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
	if pack_panel.visible or export_panel.visible:
		if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_ESCAPE:
			if pack_panel.visible:
				_on_close_pack()
			else:
				_on_close_export()
		return
	if dialog_open:
		return
	if help_visible:
		if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_F1:
			_toggle_help()
		return
	if ui_mode:
		return
	if ev is InputEventKey and ev.pressed and not ev.echo:
		_handle_key(ev)
		return
	_handle_paint_input(ev)

func _handle_key(ev):
	if ev.ctrl_pressed:
		if ev.keycode == KEY_Z:
			if ev.shift_pressed:
				_redo()
			else:
				_undo()
		elif ev.keycode == KEY_Y:
			_redo()
		return
	if ev.keycode >= KEY_1 and ev.keycode <= KEY_9:
		_select_paint_index(ev.keycode - KEY_1)
		return
	match ev.keycode:
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
		if ev.pressed and (ev.button_index == MOUSE_BUTTON_LEFT or ev.button_index == MOUSE_BUTTON_RIGHT):
			mouse_button = ev.button_index
			_paint_at(ev.position, ev.button_index == MOUSE_BUTTON_RIGHT)
		elif not ev.pressed and ev.button_index == mouse_button:
			mouse_button = 0
	elif ev is InputEventMouseMotion and mouse_button != 0:
		_paint_at(ev.position, mouse_button == MOUSE_BUTTON_RIGHT)
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
	var draw := _draw_area()
	if pos.x < draw.position.x or pos.y < draw.position.y:
		return Vector2(-1, -1)
	if pos.x > draw.end.x or pos.y > draw.end.y:
		return Vector2(-1, -1)
	var local := (pos - area.position) / fit_scale
	return Vector2(int(local.x / C.PIXEL_SIZE), int(local.y / C.PIXEL_SIZE))

func _paint_cell(x: int, y: int, erase: bool):
	if read_only:
		return
	_grew = false
	if not erase and not _grow_to(x, y):
		return
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
		_mark_draft_dirty()
		_render()
		if not erase and _grew:
			var w := 0
			for r2 in map:
				w = max(w, r2.size())
			_set_status("Mapa ampliado a %dx%d" % [w, map.size()])

func _grow_to(x: int, y: int) -> bool:
	if x < 0 or y < 0:
		return false
	if x >= GRID_MAX_W or y >= GRID_MAX_H:
		return false
	var h_before := map.size()
	var w_before := 0
	for r2 in map:
		w_before = max(w_before, r2.size())
	while map.size() <= y:
		map.append([])
	while map[y].size() <= x:
		map[y].append(C.BLOCK_NONE)
	var w_after := 0
	for r2 in map:
		w_after = max(w_after, r2.size())
	_grew = (map.size() > h_before or w_after > w_before)
	return true

func _push_undo(x: int, y: int, old_block: int, new_block: int):
	undo_stack.append([x, y, old_block, new_block])
	if undo_stack.size() > UNDO_LIMIT:
		undo_stack.pop_front()
	redo_stack = []

func _undo():
	if read_only:
		return
	if undo_stack.is_empty():
		return
	var op = undo_stack.pop_back()
	redo_stack.append(op)
	map[op[1]][op[0]] = op[2]
	cursor_cell = Vector2(op[0], op[1])
	_mark_draft_dirty()
	_render()
	_set_status("Deshacer")

func _redo():
	if read_only:
		return
	if redo_stack.is_empty():
		return
	var op = redo_stack.pop_back()
	undo_stack.append(op)
	map[op[1]][op[0]] = op[3]
	cursor_cell = Vector2(op[0], op[1])
	_mark_draft_dirty()
	_render()
	_set_status("Rehacer")

func _draw_area() -> Rect2:
	return Rect2(20, TOP_H + 10, 1160, 825 - TOP_H - BOTTOM_H - 20)

func _board_area() -> Rect2:
	var board_px := float(board.width) * C.PIXEL_SIZE
	var board_py := float(board.height) * C.PIXEL_SIZE
	if board_px <= 0 or board_py <= 0:
		return Rect2(0, 0, 0, 0)
	var draw := _draw_area()
	fit_scale = min(draw.size.x / board_px, draw.size.y / board_py)
	fit_origin = draw.position
	return Rect2(fit_origin, Vector2(board_px, board_py) * fit_scale)

func _draw():
	draw_rect(Rect2(0, 0, 1200, 825), Color(0.06, 0.05, 0.09))
	if play_mode:
		_draw_preview()
	else:
		_draw_edit()

func _draw_edit():
	var area := _board_area()
	if area.size.x <= 0 or area.size.y <= 0:
		return
	if board_texture == null:
		return
	var draw := _draw_area()
	draw_set_transform(area.position, 0, Vector2(fit_scale, fit_scale))
	draw_texture(board_texture, -Vector2(C.PIXEL_BORDER, C.PIXEL_BORDER) * 0.5)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	_draw_background_grid(draw, area)
	if _cursor_visible(cursor_cell):
		_draw_cursor(area)
	_draw_swatch(area)

func _draw_background_grid(draw: Rect2, area: Rect2):
	var cell := C.PIXEL_SIZE * fit_scale
	if cell <= 0:
		return
	var x0 := int(floor((draw.position.x - area.position.x) / cell))
	var y0 := int(floor((draw.position.y - area.position.y) / cell))
	var x1 := int(ceil((draw.end.x - area.position.x) / cell))
	var y1 := int(ceil((draw.end.y - area.position.y) / cell))
	for y in range(y0, y1 + 1):
		draw_line(Vector2(draw.position.x, area.position.y + y * cell), Vector2(draw.end.x, area.position.y + y * cell), Color(1, 1, 1, 0.07), 1)
	for x in range(x0, x1 + 1):
		draw_line(Vector2(area.position.x + x * cell, draw.position.y), Vector2(area.position.x + x * cell, draw.end.y), Color(1, 1, 1, 0.07), 1)

func _cursor_visible(cell: Vector2) -> bool:
	if cell.x < 0 or cell.y < 0:
		return false
	if cell.x >= GRID_MAX_W or cell.y >= GRID_MAX_H:
		return false
	var max_cell := _visible_max_cell()
	return cell.x <= max_cell.x and cell.y <= max_cell.y

func _draw_cursor(area: Rect2):
	var cell_origin := area.position + cursor_cell * (C.PIXEL_SIZE * fit_scale)
	var cell_size := Vector2(C.PIXEL_SIZE, C.PIXEL_SIZE) * fit_scale
	var rect := Rect2(cell_origin, cell_size)
	if selected_block != C.BLOCK_NONE and selected_block < board.block_images.size():
		var preview: Texture2D = board.block_images[selected_block]
		if preview != null:
			var preview_rect := Rect2(
				cell_origin - Vector2(C.PIXEL_BORDER, C.PIXEL_BORDER) * 0.5 * fit_scale,
				Vector2(C.PIXEL_SIZE + C.PIXEL_BORDER, C.PIXEL_SIZE + C.PIXEL_BORDER) * fit_scale
			)
			draw_texture_rect(preview, preview_rect, false)
	draw_rect(rect, Color(1, 1, 1, 0.45))
	if selected_block == C.BLOCK_NONE or selected_block >= board.block_images.size():
		draw_rect(rect, Color(0.9, 0.2, 0.2, 0.5))
	draw_rect(rect, Color(1, 1, 1, 0.9), false, 2.0)
	draw_rect(Rect2(cell_origin + Vector2(3, 3), cell_size - Vector2(6, 6)), Color(0.95, 0.9, 0.4, 0.8), false, 1.0)

func _draw_swatch(area: Rect2):
	var swatch_pos := Vector2(area.end.x - 158, area.position.y + 8)
	draw_rect(Rect2(swatch_pos, Vector2(150, 46)), Color(0.1, 0.1, 0.14, 0.85))
	var img: Texture2D = null
	if selected_block >= 0 and selected_block < board.block_images.size():
		img = board.block_images[selected_block]
	if img != null:
		draw_texture_rect(img, Rect2(swatch_pos + Vector2(5, 5), Vector2(36, 36)), false)
	else:
		draw_rect(Rect2(swatch_pos + Vector2(5, 5), Vector2(36, 36)), Color(0.9, 0.2, 0.2, 0.6))
	draw_string(font_swatch, swatch_pos + Vector2(48, 29), _block_name(), -1, -1, 15, Color(0.9, 0.9, 0.95))

func _draw_preview():
	var area := _board_area()
	if board_texture != null:
		draw_set_transform(area.position, 0, Vector2(fit_scale, fit_scale))
		draw_texture(board_texture, -Vector2(C.PIXEL_BORDER, C.PIXEL_BORDER) * 0.5)
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

# ---- creación de packs ----

func _on_open_pack():
	_refresh_pack_available()
	pack_panel.visible = true
	pack_name_edit.text = attributes.get("name", "") + " pack"
	pack_author_edit.text = attributes.get("author", "")
	pack_desc_edit.text = ""
	pack_thumb_image = null
	pack_thumb_texture = null
	pack_thumb_preview.texture = null
	pack_name_edit.grab_focus()
	_set_status("Crea un pack de niveles (ZIP + manifest.json)")

func _on_pick_thumb():
	var fd := FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.add_filter("*.png ; PNG Images")
	fd.title = "Seleccionar miniatura (PNG)"
	fd.file_selected.connect(_on_thumb_picked)
	fd.visibility_changed.connect(func(): if not fd.visible: _on_dialog_closed())
	add_child(fd)
	fd.popup_centered_ratio(0.7)

func _on_thumb_picked(path: String):
	var img := Image.new()
	if img.load(path) != OK:
		_set_status("Error al cargar imagen")
		return
	img.resize(128, 128, Image.INTERPOLATE_BILINEAR)
	pack_thumb_image = img
	pack_thumb_texture = ImageTexture.create_from_image(img)
	pack_thumb_preview.texture = pack_thumb_texture
	_set_status("Miniatura cargada")

func _on_auto_thumb():
	if pack_list.get_item_count() == 0:
		_set_status("Agrega al menos un nivel antes de generar la miniatura")
		return
	var first_path = pack_list.get_item_text(0)
	if not first_path.begins_with("user://") and not first_path.begins_with("res://"):
		first_path = "user://tumbleboy_levels/" + first_path
	var info = LevelsScript.parse_level(first_path)
	var temp_board = BoardScript.new()
	temp_board.set_theme(info["attributes"].get("theme", "default"))
	var temp_map = info["map"]
	var w := 0
	for row in temp_map:
		w = max(w, row.size())
	temp_board.set_dimensions(w, temp_map.size())
	for y in range(temp_map.size()):
		var row = temp_map[y]
		for x in range(row.size()):
			if row[x] != C.BLOCK_NONE:
				temp_board.set_block(x, y, row[x])
	var tex = temp_board.render_board_image()
	var img = tex.get_image()
	img.resize(128, 128, Image.INTERPOLATE_BILINEAR)
	pack_thumb_image = img
	pack_thumb_texture = ImageTexture.create_from_image(img)
	pack_thumb_preview.texture = pack_thumb_texture
	_set_status("Miniatura generada del primer nivel")

func _on_close_pack():
	pack_panel.visible = false
	_release_focus()
	_set_status("")

func _refresh_pack_available():
	pack_available = []
	var dir := DirAccess.open(USER_LEVELS_DIR)
	if dir != null:
		dir.list_dir_begin()
		var fname := dir.get_next()
		while fname != "":
			if not dir.current_is_dir() and fname.ends_with(".txt"):
				pack_available.append(USER_LEVELS_DIR + fname)
			fname = dir.get_next()
		dir.list_dir_end()
	pack_available.sort()
	available_list.clear()
	for p in pack_available:
		available_list.add_item(p.get_file())
	pack_selected = []
	pack_list.clear()

func _pack_cur_available() -> int:
	var sel := available_list.get_selected_items()
	if sel.size() > 0:
		return sel[0]
	return -1

func _pack_cur_selected() -> int:
	var sel := pack_list.get_selected_items()
	if sel.size() > 0:
		return sel[0]
	return -1

func _on_pack_add():
	var idx := _pack_cur_available()
	if idx < 0 or idx >= pack_available.size():
		_set_status("Selecciona un nivel disponible")
		return
	var path = pack_available[idx]
	if pack_selected.has(path):
		return
	pack_selected.append(path)
	pack_list.add_item(path.get_file())
	_set_status("")

func _on_pack_remove():
	var idx := _pack_cur_selected()
	if idx < 0 or idx >= pack_selected.size():
		_set_status("Selecciona un nivel del pack")
		return
	pack_selected.remove_at(idx)
	pack_list.remove_item(idx)
	_set_status("")

func _on_pack_up():
	var idx := _pack_cur_selected()
	if idx <= 0 or idx >= pack_selected.size():
		return
	_pack_swap(idx, idx - 1)

func _on_pack_down():
	var idx := _pack_cur_selected()
	if idx < 0 or idx >= pack_selected.size() - 1:
		return
	_pack_swap(idx, idx + 1)

func _pack_swap(a: int, b: int):
	var tmp = pack_selected[a]
	pack_selected[a] = pack_selected[b]
	pack_selected[b] = tmp
	var a_text := pack_list.get_item_text(a)
	var b_text := pack_list.get_item_text(b)
	pack_list.set_item_text(a, b_text)
	pack_list.set_item_text(b, a_text)
	pack_list.select(b)
	pack_list.ensure_current_is_visible()

func _on_create_pack():
	var title := pack_name_edit.text.strip_edges()
	if title == "":
		_set_status("El pack necesita un título")
		return
	if pack_selected.size() == 0:
		_set_status("Elige al menos un nivel para el pack")
		return
	var author := pack_author_edit.text.strip_edges()
	if author == "":
		_set_status("El pack necesita el autor / créditos")
		return
	var id := title.replace(" ", "_").to_lower()
	for ch in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]:
		id = id.replace(ch, "")
	if id == "":
		id = "pack"
	var level_names := []
	for p in pack_selected:
		level_names.append("levels/" + p.get_file())
	var manifest := {
		"name": title,
		"author": author,
		"description": pack_desc_edit.text.strip_edges(),
		"levels": level_names,
	}
	var files := {}
	files["manifest.json"] = JSON.stringify(manifest, "  ")
	for p in pack_selected:
		files["levels/" + p.get_file()] = _read_text_file(p)
	if pack_thumb_image != null:
		pack_thumb_image.resize(128, 128, Image.INTERPOLATE_BILINEAR)
		files["thumbnail.png"] = pack_thumb_image.save_png_to_buffer()
	var dir := DirAccess.open("user://")
	if dir != null:
		dir.make_dir_recursive(PACKS_DIR)
	var zip_path := PACKS_DIR + id + ".zip"
	if ZIPWriter.write_pack_zip(zip_path, files):
		_set_status("Pack creado: " + zip_path)
	else:
		_set_status("ERROR al crear el pack")
	pack_panel.visible = false
	_release_focus()

func _read_text_file(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var text := f.get_as_text()
	f.close()
	return text

# ---- exportar pack ----

func _on_open_export():
	export_packs = PackReader.list_packs()
	export_list.clear()
	for p in export_packs:
		export_list.add_item(p.get("name", "?") + "  —  " + p.get("author", ""))
	export_panel.visible = true
	export_list.grab_focus()
	_set_status("")

func _on_close_export():
	export_panel.visible = false
	_release_focus()
	_set_status("")

func _on_export_selected():
	var idx := _pack_cur_export()
	if idx < 0 or idx >= export_packs.size():
		_set_status("Selecciona un pack")
		return
	var id: String = export_packs[idx].get("id", "")
	if id == "":
		return
	dialog_open = true
	var fd := FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	fd.access = FileDialog.ACCESS_RESOURCES
	fd.current_dir = "user://"
	fd.current_file = id + ".zip"
	fd.title = "Exportar pack"
	fd.file_selected.connect(_on_export_copy.bind(id))
	fd.visibility_changed.connect(func(): if not fd.visible: _on_dialog_closed())
	add_child(fd)
	fd.popup_centered_ratio(0.8)

func _pack_cur_export() -> int:
	var sel := export_list.get_selected_items()
	if sel.size() > 0:
		return sel[0]
	return -1

func _on_export_copy(target: String, id: String):
	var src := PackReader.zip_path_for_id(id)
	if DirAccess.copy_absolute(ProjectSettings.globalize_path(src), ProjectSettings.globalize_path(target)) == OK:
		_set_status("Pack exportado: " + target)
	else:
		_set_status("ERROR al exportar")
	export_panel.visible = false

func open_file(path: String):
	_on_open_selected(path)

func open_pack_panel():
	_on_open_pack()
