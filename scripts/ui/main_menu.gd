extends Control
# MainMenu — TumbleBoy Reborn: lanzador nostálgico (Jugar / Niveles y packs / Editor).

const UIFonts = preload("res://scripts/ui/ui_fonts.gd")

const GAMES := [
	{ "id": "play", "name": "Jugar — TumbleBoy (historia)", "scene": "res://scenes/TumbleBoy.tscn", "icon": "res://assets/tumbleboy/icon.png", "enabled": true },
	{ "id": "levels", "name": "Niveles y packs", "scene": "res://scenes/LevelSelect.tscn", "icon": "res://assets/tumbleboy/icon.png", "enabled": true },
	{ "id": "editor", "name": "Editor de niveles", "scene": "res://scenes/TumbleBoyEditor.tscn", "icon": "res://assets/tumbleboy/icon.png", "enabled": true },
]

var buttons: Array = []
var selected := 0

func _ready():
	_build_ui()
	set_process_input(true)

func _build_ui():
	set_anchors_preset(Control.PRESET_WIDE)
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.05, 0.12)
	bg.set_anchors_preset(Control.PRESET_WIDE)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_WIDE)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGN_CENTER
	vbox.add_constant_override("separation", 10)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "TUMBLEBOY REBORN"
	title.add_color_override("font_color", Color(0.95, 0.9, 0.6))
	title.add_font_override("font", UIFonts.make_font(34, true))
	title.align = Label.ALIGN_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "La reencarnación del juego perdido de las XO / Ceibalitas"
	sub.add_color_override("font_color", Color(0.6, 0.55, 0.7))
	sub.align = Label.ALIGN_CENTER
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(sub)

	for g in GAMES:
		var btn := Button.new()
		btn.text = g["name"]
		btn.focus_mode = Control.FOCUS_ALL
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.rect_min_size = Vector2(420, 46)
		btn.add_font_override("font", UIFonts.make_font(17))
		btn.add_color_override("font_color", Color(0.95, 0.93, 0.88))
		btn.disabled = not g["enabled"]
		if g["enabled"]:
			btn.connect("pressed", self, "_on_game_pressed", [g])
		vbox.add_child(btn)
		buttons.append(btn)

	var hint := Label.new()
	hint.text = "D-pad / Flechas: mover · A / Enter: entrar · B / ESC: salir"
	hint.add_font_override("font", UIFonts.make_font(14))
	hint.add_color_override("font_color", Color(0.65, 0.62, 0.72))
	hint.align = Label.ALIGN_CENTER
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(hint)

	# foco inicial
	var first_enabled := -1
	for i in range(buttons.size()):
		if not buttons[i].disabled:
			first_enabled = i
			break
	if first_enabled >= 0:
		buttons[first_enabled].grab_focus()
		selected = first_enabled

func _on_game_pressed(g: Dictionary):
	get_tree().change_scene(g["scene"])

func _input(ev):
	if ev is InputEventKey and ev.pressed and not ev.echo:
		if InputManager.back_just_pressed():
			get_tree().quit()
