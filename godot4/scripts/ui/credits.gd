extends Control
# Credits — créditos de TumbleBoy Reborn.
# Port a Godot 4: ALIGN_CENTER -> ALIGNMENT_CENTER, align ->
# horizontal_alignment, connect -> Callable, change_scene ->
# change_scene_to_file, add_font_override -> add_theme_font_override,
# rect_min_size -> custom_minimum_size.

const UIFonts = preload("res://scripts/ui/ui_fonts.gd")

var back_button: Button = null

func _ready():
	_build_ui()
	set_process_input(true)
	if back_button != null:
		back_button.grab_focus()

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
	col.add_theme_constant_override("separation", 6)
	col.custom_minimum_size = Vector2(560, 0)
	center.add_child(col)

	var title := Label.new()
	title.text = "CRÉDITOS"
	UIFonts.style_font(title, 34, true)
	title.add_theme_color_override("font_color", Color(0.95, 0.9, 0.6))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	col.add_child(_section_label("TUMBLEBOY REBORN", 20, true))
	col.add_child(_line_label("Desarrollado por Aleperix"))
	col.add_child(_line_label("Hecho para XO Galaxy"))

	col.add_child(_spacer(10))
	col.add_child(_section_label("Creadores originales de TumbleBoy:", 17, true))
	for name in ["Tom Corbet", "Chris Jackson", "Eben Myers", "Bob Rost"]:
		col.add_child(_line_label(name))

	col.add_child(_spacer(10))
	col.add_child(_section_label("Agradecimientos:", 17, true))
	col.add_child(_line_label("Gummi — Recuperación del Lost Media"))
	col.add_child(_line_label("SugarLabs — quienes hicieron posible este juego en las XO"))
	col.add_child(_line_label("github.com/sugarlabs/tumbleboy-activity", 13))

	col.add_child(_spacer(14))

	back_button = Button.new()
	back_button.text = "Volver"
	back_button.focus_mode = Control.FOCUS_ALL
	back_button.custom_minimum_size = Vector2(300, 44)
	UIFonts.style_font(back_button, 16)
	back_button.add_theme_color_override("font_color", Color(0.95, 0.93, 0.88))
	back_button.pressed.connect(_on_back)
	col.add_child(back_button)

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

func _spacer(px: float) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, px)
	return s

func _section_label(text: String, size: int, bold: bool) -> Label:
	return _line_label(text, size, bold)

func _line_label(text: String, size: int = 16, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	UIFonts.style_font(l, size, bold)
	l.add_theme_color_override("font_color", Color(0.95, 0.95, 0.98) if not bold else Color(0.95, 0.9, 0.6))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _on_back():
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _process(_delta):
	if InputManager.back_just_pressed():
		_on_back()
