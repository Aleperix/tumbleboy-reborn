extends Control
# Credits — créditos de TumbleBoy Reborn.

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
	bg.set_anchors_preset(Control.PRESET_WIDE)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_WIDE)
	add_child(center)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGN_CENTER
	col.add_constant_override("separation", 6)
	col.rect_min_size = Vector2(560, 0)
	center.add_child(col)

	var title := Label.new()
	title.text = "CRÉDITOS"
	title.add_font_override("font", UIFonts.make_font(34, true))
	title.add_color_override("font_color", Color(0.95, 0.9, 0.6))
	title.align = Label.ALIGN_CENTER
	col.add_child(title)

	col.add_child(_section_label("TUMBLEBOY REBORN", 20, true))
	col.add_child(_line_label("Desarrollado por Aleperix"))
	col.add_child(_line_label("Hecho para TuPlanetXO"))

	col.add_child(_spacer(10))
	col.add_child(_section_label("Creadores originales de TumbleBoy:", 17, true))
	for name in ["Tom Corbet", "Chris Jackson", "Eben Myers", "Bob Rost"]:
		col.add_child(_line_label(name))

	col.add_child(_spacer(10))
	col.add_child(_section_label("Agradecimientos:", 17, true))
	col.add_child(_line_label("Álvaro Benítez — Fundador de TuPlanetXO"))
	col.add_child(_line_label("Gummi — Recuperación del Lost Media"))
	col.add_child(_line_label("SugarLabs — quienes hicieron posible este juego en las XO"))
	col.add_child(_line_label("github.com/sugarlabs/tumbleboy-activity", 13))

	col.add_child(_spacer(14))

	back_button = Button.new()
	back_button.text = "Volver  (B)"
	back_button.focus_mode = Control.FOCUS_ALL
	back_button.rect_min_size = Vector2(300, 44)
	back_button.add_font_override("font", UIFonts.make_font(16))
	back_button.add_color_override("font_color", Color(0.95, 0.93, 0.88))
	back_button.connect("pressed", self, "_on_back")
	col.add_child(back_button)

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

func _spacer(px: float) -> Control:
	var s := Control.new()
	s.rect_min_size = Vector2(0, px)
	return s

func _section_label(text: String, size: int, bold: bool) -> Label:
	return _line_label(text, size, bold)

func _line_label(text: String, size: int = 16, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_font_override("font", UIFonts.make_font(size, bold))
	l.add_color_override("font_color", Color(0.95, 0.95, 0.98) if not bold else Color(0.95, 0.9, 0.6))
	l.align = Label.ALIGN_CENTER
	return l

func _on_back():
	get_tree().change_scene("res://scenes/MainMenu.tscn")

func _input(ev):
	if ev is InputEventKey and ev.pressed and not ev.echo:
		if InputManager.back_just_pressed():
			_on_back()
