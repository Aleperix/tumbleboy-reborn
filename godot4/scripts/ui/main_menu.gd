extends Control
# MainMenu — TumbleBoy Reborn: menú principal (Modo historia / Packs / Editor / Créditos / Salir)
# Port a Godot 4: ALIGN_CENTER -> ALIGNMENT_CENTER, align -> horizontal_alignment,
# expand -> expand_mode, connect -> Callable, change_scene -> change_scene_to_file,
# add_font_override -> add_theme_font_override, add_stylebox_override ->
# add_theme_stylebox_override, rect_min_size -> custom_minimum_size.

const UIFonts = preload("res://scripts/ui/ui_fonts.gd")

const MENU_ITEMS := [
	{ "id": "story",   "name": "Modo historia",             "scene": "res://scenes/StoryHub.tscn" },
	{ "id": "packs",   "name": "Packs comunitarios",        "scene": "res://scenes/PacksCommunity.tscn" },
	{ "id": "editor",  "name": "Editor de niveles",         "scene": "res://scenes/EditorHub.tscn" },
	{ "id": "credits", "name": "Créditos",                  "scene": "res://scenes/Credits.tscn" },
	{ "id": "quit",    "name": "Salir",                     "scene": "" },
]

var buttons: Array = []

var _quit_confirm_timer := -1.0
var _quit_confirm_label: Label

func _ready():
	_build_ui()

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
	col.add_theme_constant_override("separation", 10)
	col.custom_minimum_size = Vector2(440, 0)
	center.add_child(col)

	var icon := TextureRect.new()
	icon.texture = load("res://assets/tumbleboy/icon.png")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(96, 96)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(icon)

	var spacer1 := Control.new()
	spacer1.custom_minimum_size = Vector2(0, 6)
	col.add_child(spacer1)

	var title := Label.new()
	title.text = "TUMBLEBOY REBORN"
	UIFonts.style_font(title, 36, true)
	title.add_theme_color_override("font_color", Color(0.95, 0.9, 0.6))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var sub := Label.new()
	sub.text = "TumbleBoy — el clásico del puzzle en Godot"
	UIFonts.style_font(sub, 16)
	sub.add_theme_color_override("font_color", Color(0.7, 0.67, 0.8))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 16)
	col.add_child(spacer2)

	for item in MENU_ITEMS:
		var btn := Button.new()
		btn.text = item["name"]
		btn.focus_mode = Control.FOCUS_ALL
		btn.custom_minimum_size = Vector2(400, 50)
		UIFonts.style_font(btn, 18)
		btn.add_theme_color_override("font_color", Color(0.95, 0.93, 0.88))
		btn.pressed.connect(_on_item_pressed.bind(item))
		col.add_child(btn)
		buttons.append(btn)

	var hint := Label.new()
	hint.text = "D-pad / Flechas: mover · A / Enter: entrar · B / ESC dos veces: salir"
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

	var quit_label := Label.new()
	quit_label.text = ""
	UIFonts.style_font(quit_label, 14)
	quit_label.add_theme_color_override("font_color", Color(0.95, 0.75, 0.6))
	quit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var quit_sb := StyleBoxFlat.new()
	quit_sb.bg_color = Color(0.35, 0.1, 0.1, 0.55)
	quit_sb.set_corner_radius_all(4)
	quit_sb.content_margin_left = 8
	quit_sb.content_margin_top = 8
	quit_sb.content_margin_right = 8
	quit_sb.content_margin_bottom = 8
	quit_label.add_theme_stylebox_override("normal", quit_sb)
	quit_label.visible = false
	col.add_child(quit_label)
	_quit_confirm_label = quit_label

	if buttons.size() > 0:
		buttons[0].grab_focus()

func _on_item_pressed(item: Dictionary):
	if item["scene"] == "":
		get_tree().quit()
	else:
		get_tree().change_scene_to_file(item["scene"])

func _process(delta):
	if _quit_confirm_timer > 0.0:
		_quit_confirm_timer -= delta
		if _quit_confirm_timer <= 0.0:
			_quit_confirm_timer = -1.0
			_quit_confirm_label.visible = false
	if not InputManager.back_just_pressed():
		return
	if _quit_confirm_timer > 0.0:
		get_tree().quit()
		return
	_quit_confirm_timer = 2.0
	_quit_confirm_label.text = "Pulsá Atrás otra vez para salir"
	_quit_confirm_label.visible = true
