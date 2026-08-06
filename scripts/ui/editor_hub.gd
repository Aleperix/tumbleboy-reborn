extends Control
# EditorHub — Editor de niveles: Niveles propios / Packs propios / Nuevo nivel / Volver.

const UIFonts = preload("res://scripts/ui/ui_fonts.gd")
const PackReader = preload("res://scripts/tumbleboy/pack_reader.gd")
const LevelsScript = preload("res://scripts/tumbleboy/levels.gd")
const PackRow = preload("res://scripts/ui/pack_row.gd")
const FocusNav = preload("res://scripts/ui/focus_nav.gd")
const FocusGrab = preload("res://scripts/ui/focus_grab.gd")
const USER_LEVELS_DIR := "user://tumbleboy_levels/"

var hub_panel: Control
var niveles_panel: Control
var packs_panel: Control
var niveles_vbox: VBoxContainer
var packs_vbox: VBoxContainer
var niveles_scroll: ScrollContainer
var packs_scroll: ScrollContainer
var hub_buttons: Array = []
var niveles_back: Button
var packs_create: Button
var packs_back: Button
var niveles_col: VBoxContainer
var packs_col: VBoxContainer
var delete_dialog: ConfirmationDialog
var pending_delete: String = ""
var _panel_grabber: Reference = null

func _ready():
	_build_ui()
	set_process_input(true)
	if hub_buttons.size() > 0:
		hub_buttons[0].grab_focus()

func _build_ui():
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.05, 0.12)
	bg.set_anchors_preset(Control.PRESET_WIDE)
	add_child(bg)

	_build_hub()
	_build_niveles()
	_build_packs()
	hub_panel.visible = true
	niveles_panel.visible = false
	packs_panel.visible = false

# --- Hub principal ---

func _build_hub():
	hub_panel = Control.new()
	hub_panel.set_anchors_preset(Control.PRESET_WIDE)
	add_child(hub_panel)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_WIDE)
	hub_panel.add_child(center)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGN_CENTER
	col.add_constant_override("separation", 12)
	col.rect_min_size = Vector2(440, 0)
	center.add_child(col)

	var title := Label.new()
	title.text = "EDITOR DE NIVELES"
	title.add_font_override("font", UIFonts.make_font(30, true))
	title.add_color_override("font_color", Color(0.95, 0.9, 0.6))
	title.align = Label.ALIGN_CENTER
	col.add_child(title)

	var spacer := Control.new()
	spacer.rect_min_size = Vector2(0, 16)
	col.add_child(spacer)

	var b1 := Button.new()
	b1.text = "Niveles propios"
	b1.focus_mode = Control.FOCUS_ALL
	b1.rect_min_size = Vector2(400, 50)
	b1.add_font_override("font", UIFonts.make_font(18))
	b1.add_color_override("font_color", Color(0.95, 0.93, 0.88))
	b1.connect("pressed", self, "_on_open_niveles")
	col.add_child(b1)
	hub_buttons.append(b1)

	var b2 := Button.new()
	b2.text = "Packs propios"
	b2.focus_mode = Control.FOCUS_ALL
	b2.rect_min_size = Vector2(400, 50)
	b2.add_font_override("font", UIFonts.make_font(18))
	b2.add_color_override("font_color", Color(0.95, 0.93, 0.88))
	b2.connect("pressed", self, "_on_open_packs")
	col.add_child(b2)
	hub_buttons.append(b2)

	var b3 := Button.new()
	b3.text = "Nuevo nivel"
	b3.focus_mode = Control.FOCUS_ALL
	b3.rect_min_size = Vector2(400, 50)
	b3.add_font_override("font", UIFonts.make_font(18))
	b3.add_color_override("font_color", Color(0.95, 0.93, 0.88))
	b3.connect("pressed", self, "_on_new_level")
	col.add_child(b3)
	hub_buttons.append(b3)

	var spacer2 := Control.new()
	spacer2.rect_min_size = Vector2(0, 16)
	col.add_child(spacer2)

	var back := Button.new()
	back.text = "Volver"
	back.focus_mode = Control.FOCUS_ALL
	back.rect_min_size = Vector2(400, 44)
	back.add_font_override("font", UIFonts.make_font(16))
	back.connect("pressed", self, "_on_back")
	col.add_child(back)
	hub_buttons.append(back)

	var hint := Label.new()
	hint.text = "D-pad / Flechas: mover · A / Enter: entrar · B / ESC: volver"
	hint.add_font_override("font", UIFonts.make_font(14))
	hint.add_color_override("font_color", Color(0.65, 0.62, 0.72))
	hint.align = Label.ALIGN_CENTER
	var hint_sb := StyleBoxFlat.new()
	hint_sb.bg_color = Color(0, 0, 0, 0.35)
	hint_sb.set_corner_radius_all(4)
	hint_sb.content_margin_left = 8
	hint_sb.content_margin_top = 8
	hint_sb.content_margin_right = 8
	hint_sb.content_margin_bottom = 8
	hint.add_stylebox_override("normal", hint_sb)
	col.add_child(hint)

# --- Niveles propios ---

func _build_niveles():
	niveles_panel = Control.new()
	niveles_panel.set_anchors_preset(Control.PRESET_WIDE)
	add_child(niveles_panel)

	var bg2 := ColorRect.new()
	bg2.color = Color(0.07, 0.05, 0.12)
	bg2.set_anchors_preset(Control.PRESET_WIDE)
	niveles_panel.add_child(bg2)

	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_WIDE)
	niveles_panel.add_child(center)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGN_CENTER
	col.add_constant_override("separation", 6)
	col.rect_min_size = Vector2(700, 0)
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	center.add_child(col)
	niveles_col = col

	var title := Label.new()
	title.text = "NIVELES PROPIOS"
	title.add_font_override("font", UIFonts.make_font(28, true))
	title.add_color_override("font_color", Color(0.95, 0.9, 0.6))
	title.align = Label.ALIGN_CENTER
	col.add_child(title)

	niveles_scroll = ScrollContainer.new()
	niveles_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	niveles_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	niveles_scroll.scroll_horizontal_enabled = false
	col.add_child(niveles_scroll)

	niveles_vbox = VBoxContainer.new()
	niveles_vbox.alignment = BoxContainer.ALIGN_CENTER
	niveles_vbox.add_constant_override("separation", 10)
	niveles_vbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	niveles_scroll.add_child(niveles_vbox)

	var spacer := Control.new()
	spacer.rect_min_size = Vector2(0, 6)
	col.add_child(spacer)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGN_CENTER
	row.add_constant_override("separation", 16)
	col.add_child(row)

	var back := Button.new()
	back.text = "Volver"
	back.rect_min_size = Vector2(160, 36)
	back.add_font_override("font", UIFonts.make_font(15))
	back.connect("pressed", self, "_on_close_niveles")
	row.add_child(back)
	niveles_back = back

	niveles_panel.visible = false

func _refresh_niveles():
	for ch in niveles_vbox.get_children():
		ch.queue_free()
	if SaveData.has_draft():
		var draft_label := Label.new()
		draft_label.text = "Borrador"
		draft_label.add_font_override("font", UIFonts.make_font(18, true))
		draft_label.add_color_override("font_color", Color(0.95, 0.8, 0.4))
		draft_label.align = Label.ALIGN_CENTER
		niveles_vbox.add_child(draft_label)
		var draft_hb := HBoxContainer.new()
		draft_hb.alignment = BoxContainer.ALIGN_CENTER
		draft_hb.add_constant_override("separation", 8)
		var draft_edit_btn := Button.new()
		draft_edit_btn.text = "Editar borrador"
		draft_edit_btn.rect_min_size = Vector2(160, 36)
		draft_edit_btn.add_font_override("font", UIFonts.make_font(14))
		draft_edit_btn.connect("pressed", self, "_on_edit_draft")
		draft_hb.add_child(draft_edit_btn)
		var draft_del_btn := Button.new()
		draft_del_btn.text = "Eliminar borrador"
		draft_del_btn.rect_min_size = Vector2(160, 36)
		draft_del_btn.add_font_override("font", UIFonts.make_font(14))
		draft_del_btn.connect("pressed", self, "_on_delete_draft")
		draft_hb.add_child(draft_del_btn)
		niveles_vbox.add_child(draft_hb)
		var spacer := Control.new()
		spacer.rect_min_size = Vector2(0, 12)
		niveles_vbox.add_child(spacer)
	var files := _list_user_levels()
	if files.size() == 0 and not SaveData.has_draft():
		var l := Label.new()
		l.text = "(no tienes niveles creados — usa 'Nuevo nivel' para crear uno)"
		l.add_font_override("font", UIFonts.make_font(15))
		l.add_color_override("font_color", Color(0.65, 0.62, 0.72))
		l.align = Label.ALIGN_CENTER
		niveles_vbox.add_child(l)
		FocusNav.enable_scroll_follow(niveles_scroll)
		return
	for path in files:
		var info = LevelsScript.parse_level(path)
		var fname: String = path.get_file()
		var display_name: String = info["attributes"].get("name", fname.get_basename())
		var author: String = info["attributes"].get("author", "")
		var instructions: String = info["attributes"].get("instructions", "")
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGN_CENTER
		row.add_constant_override("separation", 12)
		var info_box := VBoxContainer.new()
		info_box.rect_min_size = Vector2(400, 0)
		info_box.add_constant_override("separation", 2)
		var name_label := Label.new()
		name_label.text = display_name + ("  —  " + author if author != "" else "")
		name_label.add_font_override("font", UIFonts.make_font(16, true))
		name_label.add_color_override("font_color", Color(0.95, 0.95, 0.98))
		info_box.add_child(name_label)
		if instructions != "":
			var instr_label := Label.new()
			instr_label.text = instructions
			instr_label.autowrap = true
			instr_label.rect_min_size = Vector2(400, 0)
			instr_label.add_font_override("font", UIFonts.make_font(13))
			instr_label.add_color_override("font_color", Color(0.7, 0.7, 0.8))
			info_box.add_child(instr_label)
		row.add_child(info_box)
		var play_btn := Button.new()
		play_btn.text = "Jugar"
		play_btn.rect_min_size = Vector2(84, 36)
		play_btn.add_font_override("font", UIFonts.make_font(14))
		play_btn.connect("pressed", self, "_on_play_level", [path, display_name])
		row.add_child(play_btn)
		var edit_btn := Button.new()
		edit_btn.text = "Editar"
		edit_btn.rect_min_size = Vector2(84, 36)
		edit_btn.add_font_override("font", UIFonts.make_font(14))
		edit_btn.connect("pressed", self, "_on_edit_level", [path])
		row.add_child(edit_btn)
		var del_btn := Button.new()
		del_btn.text = "Eliminar"
		del_btn.rect_min_size = Vector2(84, 36)
		del_btn.add_font_override("font", UIFonts.make_font(14))
		del_btn.connect("pressed", self, "_on_delete_level", [path, display_name])
		row.add_child(del_btn)
		niveles_vbox.add_child(row)
	FocusNav.enable_scroll_follow(niveles_scroll)

func _list_user_levels() -> Array:
	var result := []
	var dir := Directory.new()
	if dir.open(USER_LEVELS_DIR) == OK:
		dir.list_dir_begin()
		var fname := dir.get_next()
		while fname != "":
			if not dir.current_is_dir() and fname.ends_with(".txt"):
				result.append(USER_LEVELS_DIR + fname)
			fname = dir.get_next()
		dir.list_dir_end()
	result.sort()
	return result

func _on_play_level(path: String, display: String):
	LevelQueue.play_levels([path], display, "level")
	get_tree().change_scene("res://scenes/TumbleBoy.tscn")

func _on_edit_level(path: String):
	NavParams.open_file = path
	get_tree().change_scene("res://scenes/TumbleBoyEditor.tscn")

func _on_edit_draft():
	NavParams.open_draft = true
	get_tree().change_scene("res://scenes/TumbleBoyEditor.tscn")

func _on_delete_draft():
	SaveData.clear_draft()
	_refresh_niveles()

var _pending_delete_path: String = ""
var _pending_delete_display: String = ""

func _on_delete_level(path: String, display: String):
	_pending_delete_path = path
	_pending_delete_display = display
	if delete_dialog == null:
		delete_dialog = ConfirmationDialog.new()
		delete_dialog.window_title = "Eliminar nivel"
		delete_dialog.get_ok().text = "Eliminar"
		delete_dialog.get_cancel().text = "Cancelar"
		delete_dialog.connect("confirmed", self, "_on_delete_level_confirmed")
		delete_dialog.connect("popup_hide", self, "_on_dialog_closed")
		add_child(delete_dialog)
	delete_dialog.dialog_text = "¿Eliminar el nivel '" + display + "'?\nEsta acción no se puede deshacer."
	delete_dialog.popup_centered()

func _on_delete_level_confirmed():
	if _pending_delete_path == "":
		return
	var dir := Directory.new()
	dir.remove(_pending_delete_path)
	_pending_delete_path = ""
	_pending_delete_display = ""
	_refresh_niveles()

# --- Packs propios ---

func _build_packs():
	packs_panel = Control.new()
	packs_panel.set_anchors_preset(Control.PRESET_WIDE)
	add_child(packs_panel)

	var bg3 := ColorRect.new()
	bg3.color = Color(0.07, 0.05, 0.12)
	bg3.set_anchors_preset(Control.PRESET_WIDE)
	packs_panel.add_child(bg3)

	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_WIDE)
	packs_panel.add_child(center)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGN_CENTER
	col.add_constant_override("separation", 6)
	col.rect_min_size = Vector2(700, 0)
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	center.add_child(col)
	packs_col = col

	var title := Label.new()
	title.text = "PACKS PROPIOS"
	title.add_font_override("font", UIFonts.make_font(28, true))
	title.add_color_override("font_color", Color(0.95, 0.9, 0.6))
	title.align = Label.ALIGN_CENTER
	col.add_child(title)

	packs_scroll = ScrollContainer.new()
	packs_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	packs_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	packs_scroll.scroll_horizontal_enabled = false
	col.add_child(packs_scroll)

	packs_vbox = VBoxContainer.new()
	packs_vbox.alignment = BoxContainer.ALIGN_CENTER
	packs_vbox.add_constant_override("separation", 10)
	packs_vbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	packs_scroll.add_child(packs_vbox)

	var spacer := Control.new()
	spacer.rect_min_size = Vector2(0, 6)
	col.add_child(spacer)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGN_CENTER
	row.add_constant_override("separation", 16)
	col.add_child(row)

	var create_btn := Button.new()
	create_btn.text = "Crear nuevo pack"
	create_btn.rect_min_size = Vector2(160, 36)
	create_btn.add_font_override("font", UIFonts.make_font(15))
	create_btn.connect("pressed", self, "_on_create_pack")
	row.add_child(create_btn)
	packs_create = create_btn

	var back := Button.new()
	back.text = "Volver"
	back.rect_min_size = Vector2(160, 36)
	back.add_font_override("font", UIFonts.make_font(15))
	back.connect("pressed", self, "_on_close_packs")
	row.add_child(back)
	packs_back = back

	packs_panel.visible = false

func _refresh_packs():
	for ch in packs_vbox.get_children():
		ch.queue_free()
	var packs := PackReader.list_packs()
	var local := []
	for p in packs:
		var id: String = str(p.get("id", ""))
		if SaveData.is_pack_local(id):
			local.append(p)
	if local.size() == 0:
		var l := Label.new()
		l.text = "(no tienes packs creados)"
		l.add_font_override("font", UIFonts.make_font(15))
		l.add_color_override("font_color", Color(0.65, 0.62, 0.72))
		l.align = Label.ALIGN_CENTER
		packs_vbox.add_child(l)
		FocusNav.enable_scroll_follow(packs_scroll)
		return
	for p in local:
		var id: String = str(p.get("id", ""))
		var thumb = PackReader.get_thumbnail_texture(PackReader.PACKS_DIR + id + ".zip")
		var play_btn := Button.new()
		play_btn.text = "Jugar"
		play_btn.rect_min_size = Vector2(120, 36)
		play_btn.connect("pressed", self, "_on_play_pack", [p])
		var del_btn := Button.new()
		del_btn.text = "Eliminar"
		del_btn.rect_min_size = Vector2(120, 36)
		del_btn.connect("pressed", self, "_on_delete_pack", [id])
		var row = PackRow.make(p, thumb, [play_btn, del_btn])
		packs_vbox.add_child(row)
	FocusNav.enable_scroll_follow(packs_scroll)

func _on_play_pack(p: Dictionary):
	var id: String = str(p.get("id", ""))
	NavParams.pending_picker = ["pack", id, "new"]
	get_tree().change_scene("res://scenes/SlotPicker.tscn")

func _on_delete_pack(id: String):
	pending_delete = id
	if delete_dialog == null:
		delete_dialog = ConfirmationDialog.new()
		delete_dialog.window_title = "Eliminar pack"
		delete_dialog.get_ok().text = "Eliminar"
		delete_dialog.get_cancel().text = "Cancelar"
		delete_dialog.connect("confirmed", self, "_on_delete_pack_confirmed")
		delete_dialog.connect("popup_hide", self, "_on_dialog_closed")
		add_child(delete_dialog)
	delete_dialog.dialog_text = "¿Eliminar el pack '" + id + "'?\nSe eliminará el archivo ZIP y todos sus niveles."
	delete_dialog.popup_centered()

func _on_delete_pack_confirmed():
	if pending_delete == "":
		return
	PackReader.remove_pack(pending_delete)
	pending_delete = ""
	_refresh_packs()

func _on_create_pack():
	NavParams.open_pack_panel = true
	get_tree().change_scene("res://scenes/TumbleBoyEditor.tscn")

# --- Navegación ---

func _panel_grabber() -> Reference:
	if _panel_grabber == null:
		_panel_grabber = FocusGrab.new()
	return _panel_grabber

func _on_open_niveles():
	hub_panel.visible = false
	_refresh_niveles()
	niveles_panel.visible = true
	niveles_panel.raise()
	_panel_grabber().start(get_tree(), niveles_vbox, niveles_back)

func _on_close_niveles():
	niveles_panel.visible = false
	hub_panel.visible = true
	if hub_buttons.size() > 0:
		hub_buttons[0].grab_focus()

func _on_open_packs():
	hub_panel.visible = false
	_refresh_packs()
	packs_panel.visible = true
	packs_panel.raise()
	_panel_grabber().start(get_tree(), packs_vbox, packs_create)

func _on_close_packs():
	packs_panel.visible = false
	hub_panel.visible = true
	if hub_buttons.size() > 0:
		hub_buttons[0].grab_focus()

func _on_new_level():
	get_tree().change_scene("res://scenes/TumbleBoyEditor.tscn")

func _on_back():
	get_tree().change_scene("res://scenes/MainMenu.tscn")

func _on_dialog_closed():
	if niveles_panel.visible:
		_panel_grabber().start(get_tree(), niveles_vbox, niveles_back)
	elif packs_panel.visible:
		_panel_grabber().start(get_tree(), packs_vbox, packs_back)

func _process(_delta):
	if InputManager.back_just_pressed():
		if FocusNav.popup_open(self):
			return
		if niveles_panel.visible:
			_on_close_niveles()
		elif packs_panel.visible:
			_on_close_packs()
		else:
			_on_back()
