extends Control
# MainMenu — lanzador nostálgico estilo "JUEGOS DE LA ÉPOCA DE LAS XO / CEIBALITAS".

const GAMES := [
	{ "id": "tumbleboy", "name": "TumbleBoy", "scene": "res://scenes/TumbleBoy.tscn", "icon": "res://assets/tumbleboy/icon.png", "enabled": true },
	{ "id": "redbird", "name": "RedBird", "scene": "res://scenes/RedBird.tscn", "icon": "res://assets/redbird/icon.png", "enabled": false },
	{ "id": "fruitix", "name": "Fruitix", "scene": "res://scenes/Fruitix.tscn", "icon": "res://assets/fruitix/icon.png", "enabled": false },
	{ "id": "headcat", "name": "HeadCat", "scene": "res://scenes/HeadCat.tscn", "icon": "res://assets/headcat/icon.png", "enabled": false },
	{ "id": "jump", "name": "Jump", "scene": "res://scenes/Jump.tscn", "icon": "res://assets/jump/icon.png", "enabled": false },
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

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.alignment = BoxContainer.ALIGN_CENTER
	vbox.add_constant_override("separation", 10)
	add_child(vbox)

	var title := Label.new()
	title.text = "JUEGOS DE LA ÉPOCA DE LAS XO / CEIBALITAS"
	title.add_color_override("font_color", Color(0.95, 0.9, 0.6))
	title.add_font_override("font", _make_font(34))
	title.align = Label.ALIGN_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "Lost Media Collection — port a Godot"
	sub.add_color_override("font_color", Color(0.6, 0.55, 0.7))
	sub.align = Label.ALIGN_CENTER
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(sub)

	for g in GAMES:
		var btn := Button.new()
		btn.text = g["name"]
		btn.icon = load(g["icon"]) if g["enabled"] else null
		btn.focus_mode = Control.FOCUS_ALL
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.rect_min_size = Vector2(420, 46)
		btn.disabled = not g["enabled"]
		if g["enabled"]:
			btn.connect("pressed", self, "_on_game_pressed", [g])
		vbox.add_child(btn)
		buttons.append(btn)

	var hint := Label.new()
	hint.text = "D-pad / Flechas: mover · A / Enter: entrar · B / ESC: salir"
	hint.add_color_override("font_color", Color(0.5, 0.5, 0.6))
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

func _make_font(size: int) -> DynamicFont:
	var f := DynamicFont.new()
	f.size = size
	return f

func _input(ev):
	if ev is InputEventKey and ev.pressed and not ev.echo:
		if InputManager.back_just_pressed():
			get_tree().quit()
