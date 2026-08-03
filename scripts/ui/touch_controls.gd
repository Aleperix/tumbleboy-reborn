extends Control
# TouchControls — joystick virtual (izquierda) y botones Confirmar/Atrás (derecha).
# Solo se muestra en dispositivos táctiles (teléfono). En TV/escritorio se oculta.

var joystick_center := Vector2(150, 680)
var joystick_radius := 65.0
var knob_max := 55.0
var knob_offset := Vector2.ZERO
var confirm_center := Vector2(1120, 690)
var back_center := Vector2(1020, 690)
var button_radius := 55.0

var joystick_active := false
var joystick_touch_id := -1

func _ready():
	visible = OS.has_touchscreen_ui_hint() or OS.has_feature("android")

func _input(ev):
	if not visible:
		return
	if ev is InputEventScreenTouch:
		if ev.pressed:
			if joystick_center.distance_to(ev.position) <= joystick_radius * 1.8:
				joystick_active = true
				joystick_touch_id = ev.index
				_update_knob(ev.position)
				get_tree().set_input_as_handled()
			elif confirm_center.distance_to(ev.position) <= button_radius * 1.3:
				InputManager.press_action("confirm")
				get_tree().set_input_as_handled()
			elif back_center.distance_to(ev.position) <= button_radius * 1.3:
				InputManager.press_action("back")
				get_tree().set_input_as_handled()
		else:
			if joystick_touch_id == ev.index:
				joystick_active = false
				joystick_touch_id = -1
				knob_offset = Vector2.ZERO
				InputManager.virtual_move = Vector2.ZERO
				get_tree().set_input_as_handled()
			elif confirm_center.distance_to(ev.position) <= button_radius * 1.3:
				InputManager.release_action("confirm")
				get_tree().set_input_as_handled()
			elif back_center.distance_to(ev.position) <= button_radius * 1.3:
				InputManager.release_action("back")
				get_tree().set_input_as_handled()
	elif ev is InputEventScreenDrag:
		if joystick_touch_id == ev.index and joystick_active:
			_update_knob(ev.position)
			get_tree().set_input_as_handled()

func _update_knob(pos: Vector2):
	var offset := pos - joystick_center
	if offset.length() > knob_max:
		offset = offset.normalized() * knob_max
	knob_offset = offset
	InputManager.virtual_move = offset / knob_max
	update()

func _draw():
	if not visible:
		return
	draw_circle(joystick_center, joystick_radius, Color(1, 1, 1, 0.15))
	draw_arc(joystick_center, joystick_radius, 0, TAU, 48, Color(1, 1, 1, 0.5), 3.0)
	draw_circle(joystick_center + knob_offset, 30, Color(1, 1, 1, 0.45))
	_draw_button(confirm_center, button_radius, "A")
	_draw_button(back_center, button_radius, "B")

func _draw_button(center: Vector2, radius: float, label: String):
	draw_circle(center, radius, Color(1, 1, 1, 0.12))
	draw_arc(center, radius, 0, TAU, 48, Color(1, 1, 1, 0.5), 3.0)
	draw_string(_default_font(), center + Vector2(-10, 8), label, Color(1, 1, 1, 0.8))

func _default_font() -> Font:
	return get_font("font")
