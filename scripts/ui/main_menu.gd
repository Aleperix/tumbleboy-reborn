extends Control
# MainMenu — TumbleBoy Reborn: lanzador nostálgico (Jugar / Niveles y packs / Editor).

const UIFonts = preload("res://scripts/ui/ui_fonts.gd")

const GAMES := [
	{ "id": "play", "name": "Jugar — TumbleBoy (historia)", "scene": "res://scenes/TumbleBoy.tscn" },
	{ "id": "levels", "name": "Niveles y packs", "scene": "res://scenes/LevelSelect.tscn" },
	{ "id": "editor", "name": "Editor de niveles", "scene": "res://scenes/TumbleBoyEditor.tscn" },
]

var buttons: Array = []
var selected := 0

func _ready():
	_build_ui()
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
	title.text = "TUMBLEBOY REBORN"
	title.add_font_override("font", UIFonts.make_font(36, true))
	title.add_color_override("font_color", Color(0.95, 0.9, 0.6))
	title.align = Label.ALIGN_CENTER
	col.add_child(title)

	var sub := Label.new()
	sub.text = "La reencarnación del juego perdido de las XO / Ceibalitas"
	sub.add_font_override("font", UIFonts.make_font(16))
	sub.add_color_override("font_color", Color(0.7, 0.67, 0.8))
	sub.align = Label.ALIGN_CENTER
	col.add_child(sub)

	var spacer := Control.new()
	spacer.rect_min_size = Vector2(0, 16)
	col.add_child(spacer)

	for g in GAMES:
		var btn := Button.new()
		btn.text = g["name"]
		btn.focus_mode = Control.FOCUS_ALL
		btn.rect_min_size = Vector2(400, 50)
		btn.add_font_override("font", UIFonts.make_font(18))
		btn.add_color_override("font_color", Color(0.95, 0.93, 0.88))
		btn.connect("pressed", self, "_on_game_pressed", [g])
		col.add_child(btn)
		buttons.append(btn)

	var hint := Label.new()
	hint.text = "D-pad / Flechas: mover · A / Enter: entrar · B / ESC: salir"
	hint.add_font_override("font", UIFonts.make_font(14))
	hint.add_color_override("font_color", Color(0.65, 0.62, 0.72))
	hint.align = Label.ALIGN_CENTER
	col.add_child(hint)

	if buttons.size() > 0:
		buttons[0].grab_focus()
		selected = 0

func _on_game_pressed(g: Dictionary):
	get_tree().change_scene(g["scene"])

func _input(ev):
	if ev is InputEventKey and ev.pressed and not ev.echo:
		if InputManager.back_just_pressed():
			get_tree().quit()
