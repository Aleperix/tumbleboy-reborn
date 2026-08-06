extends Control
# StoryHub — Modo historia: Nueva Partida / Continuar / Volver.

const UIFonts = preload("res://scripts/ui/ui_fonts.gd")
const FocusNav = preload("res://scripts/ui/focus_nav.gd")

var buttons: Array = []

func _ready():
	_build_ui()
	_update_continue()
	set_process_input(true)

func _build_ui():
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.05, 0.12)
	bg.set_anchors_preset(Control.PRESET_WIDE)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_WIDE)
	add_child(center)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGN_CENTER
	col.add_constant_override("separation", 12)
	col.rect_min_size = Vector2(440, 0)
	center.add_child(col)

	var title := Label.new()
	title.text = "MODO HISTORIA"
	title.add_font_override("font", UIFonts.make_font(34, true))
	title.add_color_override("font_color", Color(0.95, 0.9, 0.6))
	title.align = Label.ALIGN_CENTER
	col.add_child(title)

	var sub := Label.new()
	sub.text = "21 niveles nostálgicos de TumbleBoy"
	sub.add_font_override("font", UIFonts.make_font(16))
	sub.add_color_override("font_color", Color(0.7, 0.67, 0.8))
	sub.align = Label.ALIGN_CENTER
	col.add_child(sub)

	var spacer := Control.new()
	spacer.rect_min_size = Vector2(0, 16)
	col.add_child(spacer)

	var new_btn := Button.new()
	new_btn.text = "Nueva Partida"
	new_btn.focus_mode = Control.FOCUS_ALL
	new_btn.rect_min_size = Vector2(400, 50)
	new_btn.add_font_override("font", UIFonts.make_font(18))
	new_btn.add_color_override("font_color", Color(0.95, 0.93, 0.88))
	new_btn.connect("pressed", self, "_on_new")
	col.add_child(new_btn)
	buttons.append(new_btn)

	var cont_btn := Button.new()
	cont_btn.text = "Continuar"
	cont_btn.focus_mode = Control.FOCUS_ALL
	cont_btn.rect_min_size = Vector2(400, 50)
	cont_btn.add_font_override("font", UIFonts.make_font(18))
	cont_btn.add_color_override("font_color", Color(0.95, 0.93, 0.88))
	cont_btn.connect("pressed", self, "_on_continue")
	col.add_child(cont_btn)
	buttons.append(cont_btn)

	var spacer2 := Control.new()
	spacer2.rect_min_size = Vector2(0, 16)
	col.add_child(spacer2)

	var back := Button.new()
	back.text = "Volver"
	back.focus_mode = Control.FOCUS_ALL
	back.rect_min_size = Vector2(400, 50)
	back.add_font_override("font", UIFonts.make_font(16))
	back.connect("pressed", self, "_on_back")
	col.add_child(back)
	buttons.append(back)

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

	if buttons.size() > 0:
		buttons[0].grab_focus()

func _update_continue():
	var key := SaveData.get_game_key("story", "historia")
	var has := SaveData.has_any_save(key)
	if buttons.size() > 1:
		FocusNav.set_skippable(buttons[1], not has)
		if has:
			var s := SaveData.get_slot_info(key, _first_save_slot(key))
			if not s.empty():
				buttons[1].text = "Continuar — nivel %d/%d" % [s["completed"] + 1, s["total"]]
		else:
			buttons[1].text = "Continuar (sin partida)"

func _first_save_slot(key: String) -> int:
	for i in SaveData.SLOT_COUNT:
		if SaveData.has_save(key, i):
			return i
	return 0

func _on_new():
	NavParams.pending_picker = ["story", "historia", "new"]
	get_tree().change_scene("res://scenes/SlotPicker.tscn")

func _on_continue():
	NavParams.pending_picker = ["story", "historia", "continue"]
	get_tree().change_scene("res://scenes/SlotPicker.tscn")

func _on_back():
	get_tree().change_scene("res://scenes/MainMenu.tscn")

func _process(_delta):
	if InputManager.back_just_pressed():
		if FocusNav.popup_open(self):
			return
		_on_back()
