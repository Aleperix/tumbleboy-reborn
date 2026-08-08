extends Control
# SlotPicker — selector de zócalos de memoria genérico (historia y packs).
# Se invoca desde StoryHub (historia) o PacksCommunity (por pack).
# Muestra 3 zócalos + (si intent=new) 4ª opción "Sin guardado".
# Port a Godot 4: ALIGN_CENTER -> ALIGNMENT_CENTER, connect -> Callable,
# yield -> await, change_scene -> change_scene_to_file, add_font_override ->
# add_theme_font_override, rect_min_size -> custom_minimum_size.

const UIFonts = preload("res://scripts/ui/ui_fonts.gd")
const PackReader = preload("res://scripts/tumbleboy/pack_reader.gd")
const FocusNav = preload("res://scripts/ui/focus_nav.gd")

var game_mode: String = "story"
var game_id: String = "historia"
var intent: String = "new"
var slot_buttons: Array = []
var no_save_button: Button = null
var sub_label: Label = null
var back_button: Button = null

func _ready():
	set_process_input(true)
	_build_ui()
	if NavParams.pending_picker.size() == 3:
		configure(NavParams.pending_picker[0], NavParams.pending_picker[1], NavParams.pending_picker[2])
		NavParams.pending_picker = []
	_grab_first_enabled()

func configure(m: String, id: String, i: String):
	game_mode = m
	game_id = id
	intent = i
	if sub_label != null:
		sub_label.text = _mode_label()
	if no_save_button != null:
		no_save_button.visible = (intent == "new")
	_refresh_slots()
	_grab_first_enabled()

func _build_ui():
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.05, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 8)
	col.custom_minimum_size = Vector2(500, 0)
	center.add_child(col)

	var title := Label.new()
	title.text = "SELECCIONAR ZÓCALO"
	UIFonts.style_font(title, 30, true)
	title.add_theme_color_override("font_color", Color(0.95, 0.9, 0.6))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	sub_label = Label.new()
	sub_label.text = _mode_label()
	UIFonts.style_font(sub_label, 15)
	sub_label.add_theme_color_override("font_color", Color(0.7, 0.67, 0.8))
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	col.add_child(spacer)

	for i in SaveData.SLOT_COUNT:
		var btn := Button.new()
		btn.focus_mode = Control.FOCUS_ALL
		btn.custom_minimum_size = Vector2(460, 50)
		UIFonts.style_font(btn, 16)
		btn.add_theme_color_override("font_color", Color(0.95, 0.93, 0.88))
		btn.text = "Zócalo %d — Vacío" % (i + 1)
		btn.pressed.connect(_on_slot.bind(i))
		col.add_child(btn)
		slot_buttons.append(btn)

	if intent == "new":
		var spacer2 := Control.new()
		spacer2.custom_minimum_size = Vector2(0, 6)
		col.add_child(spacer2)
		no_save_button = Button.new()
		no_save_button.text = "Sin guardado — jugar sin guardar"
		no_save_button.focus_mode = Control.FOCUS_ALL
		no_save_button.custom_minimum_size = Vector2(460, 50)
		UIFonts.style_font(no_save_button, 16)
		no_save_button.add_theme_color_override("font_color", Color(0.8, 0.8, 0.7))
		no_save_button.pressed.connect(_on_no_save)
		col.add_child(no_save_button)

	var spacer3 := Control.new()
	spacer3.custom_minimum_size = Vector2(0, 16)
	col.add_child(spacer3)

	var back := Button.new()
	back.text = "Volver"
	back.focus_mode = Control.FOCUS_ALL
	back.custom_minimum_size = Vector2(460, 44)
	UIFonts.style_font(back, 16)
	back.pressed.connect(_on_back)
	col.add_child(back)
	back_button = back

	var hint := Label.new()
	hint.text = "D-pad / Flechas: mover · A / Enter: entrar · B / ESC: volver"
	UIFonts.style_font(hint, 14)
	hint.add_theme_color_override("font_color", Color(0.65, 0.62, 0.72))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hint_sb := StyleBoxFlat.new()
	hint_sb.bg_color = Color(0, 0, 0, 0.35)
	hint_sb.set_corner_radius_all(4)
	hint_sb.content_margin_left = 8
	hint_sb.content_margin_top = 8
	hint_sb.content_margin_right = 8
	hint_sb.content_margin_bottom = 8
	hint.add_theme_stylebox_override("normal", hint_sb)
	col.add_child(hint)

	_refresh_slots()

	if slot_buttons.size() > 0:
		slot_buttons[0].grab_focus()

func _grab_first_enabled():
	for b in slot_buttons:
		if not b.disabled:
			b.grab_focus()
			return
	if no_save_button != null and not no_save_button.disabled:
		no_save_button.grab_focus()
		return
	if back_button != null:
		back_button.grab_focus()

func _mode_label() -> String:
	if game_mode == "story":
		return "Historia — 21 niveles"
	return "Pack: " + game_id

func _refresh_slots():
	var key := SaveData.get_game_key(game_mode, game_id)
	for i in SaveData.SLOT_COUNT:
		var btn = slot_buttons[i]
		if SaveData.has_save(key, i):
			var info: Dictionary = SaveData.get_slot_info(key, i)
			var mode_label := ""
			if info.has("mode") and info["mode"] == "pack":
				mode_label = "Pack"
			else:
				mode_label = "Historia"
			var comp = info.get("completed", 0)
			var tot = info.get("total", 1)
			btn.text = "Zócalo %d — %s: nivel %d/%d" % [i + 1, mode_label, comp + 1, tot]
			btn.add_theme_color_override("font_color", Color(0.95, 0.93, 0.88))
			FocusNav.set_skippable(btn, false)
		else:
			btn.text = "Zócalo %d — Vacío" % (i + 1)
			btn.add_theme_color_override("font_color", Color(0.65, 0.62, 0.72))
			FocusNav.set_skippable(btn, intent == "continue")

func _on_slot(index: int):
	var key := SaveData.get_game_key(game_mode, game_id)
	if intent == "new" and SaveData.has_save(key, index):
		_confirm_overwrite(index)
		return
	_start_game(index)

func _confirm_overwrite(index: int):
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "¿Sobrescribir zócalo %d? Se perderá la partida guardada." % (index + 1)
	dialog.title = "Confirmar"
	dialog.custom_minimum_size = Vector2(300, 150)
	dialog.confirmed.connect(_start_game.bind(index))
	dialog.visibility_changed.connect(func(): if not dialog.visible: _on_dialog_closed())
	add_child(dialog)
	dialog.popup_centered()

func _on_dialog_closed():
	await get_tree().process_frame
	await get_tree().process_frame
	_grab_first_enabled()

func _start_game(index: int):
	var key := SaveData.get_game_key(game_mode, game_id)
	if intent == "new":
		var total := 21 if game_mode == "story" else _pack_total()
		SaveData.begin_session(game_mode, game_id, index, total, 0)
		_launch(0)
	elif intent == "continue":
		var info: Dictionary = SaveData.get_slot_info(key, index)
		if info.is_empty():
			return
		SaveData.begin_session(game_mode, game_id, index, info.get("total", 1), info.get("completed", 0))
		_launch(info.get("completed", 0))

func _pack_total() -> int:
	var zip_path := PackReader.zip_path_for_id(game_id)
	var dest := "user://tumbleboy_cache/play/" + game_id + "/"
	var paths := PackReader.extract_pack(zip_path, dest)
	return paths.size()

func _launch(start: int):
	if game_mode == "pack":
		var zip_path := PackReader.zip_path_for_id(game_id)
		var dest := "user://tumbleboy_cache/play/" + game_id + "/"
		var paths := PackReader.extract_pack(zip_path, dest)
		LevelQueue.play_levels(paths, game_id, "pack", game_id)
	else:
		LevelQueue.play_levels([], game_id, "story")
	LevelQueue.start_index = start
	get_tree().change_scene_to_file("res://scenes/TumbleBoy.tscn")

func _on_no_save():
	SaveData.begin_session_quick(game_mode, game_id, 21 if game_mode == "story" else _pack_total())
	if game_mode == "pack":
		var zip_path := PackReader.zip_path_for_id(game_id)
		var dest := "user://tumbleboy_cache/play/" + game_id + "/"
		var paths := PackReader.extract_pack(zip_path, dest)
		LevelQueue.play_levels(paths, game_id, "pack", game_id)
	else:
		LevelQueue.play_levels([], game_id, "story")
	LevelQueue.start_index = 0
	get_tree().change_scene_to_file("res://scenes/TumbleBoy.tscn")

func _on_back():
	get_tree().change_scene_to_file("res://scenes/StoryHub.tscn" if game_mode == "story" else "res://scenes/PacksCommunity.tscn")

func _process(_delta):
	if InputManager.back_just_pressed():
		if FocusNav.popup_open(self):
			return
		_on_back()
