extends Node
# InputManager — capa de entrada unificada.
# - Construye el InputMap en tiempo de ejecución (mismo comportamiento en
#   teclado, gamepad/D-pad y touch).
# - Expone helpers usados por todos los juegos y el menú.
# - Traduce el botón Atrás (Android BACK, ESC, botón B) a la acción `back`.

const JOY_DPAD_UP := 11
const JOY_DPAD_DOWN := 12
const JOY_DPAD_LEFT := 13
const JOY_DPAD_RIGHT := 14
const JOY_BUTTON_A := 0
const JOY_BUTTON_B := 1
const JOY_BUTTON_X := 2
const JOY_BUTTON_Y := 3
const JOY_BUTTON_START := 9
const JOY_BUTTON_BACK := 10

signal confirm_pressed
signal back_pressed

var virtual_move: Vector2 = Vector2.ZERO
var virtual_pointer_pos: Vector2 = Vector2.ZERO
var virtual_pointer_down: bool = false

func _init():
	_build_input_map()

func _ready():
	set_process_input(true)

func _build_input_map():
	_add_axis("move_up", "move_down", JOY_AXIS_1, JOY_DPAD_UP, JOY_DPAD_DOWN, KEY_W, KEY_UP, KEY_S, KEY_DOWN)
	_add_axis("move_left", "move_right", JOY_AXIS_0, JOY_DPAD_LEFT, JOY_DPAD_RIGHT, KEY_A, KEY_LEFT, KEY_D, KEY_RIGHT)

	_add_simple("confirm", [KEY_ENTER, KEY_SPACE, KEY_KP_ENTER], [JOY_BUTTON_A, JOY_BUTTON_START])
	_add_simple("back", [KEY_ESCAPE, KEY_BACK], [JOY_BUTTON_B, JOY_BUTTON_BACK])

	# Acciones de foco (necesarias para navegar botones con D-pad en TV)
	_add_axis("ui_up", "ui_down", JOY_AXIS_1, JOY_DPAD_UP, JOY_DPAD_DOWN, KEY_UP, KEY_UP, KEY_DOWN, KEY_DOWN)
	_add_axis("ui_left", "ui_right", JOY_AXIS_0, JOY_DPAD_LEFT, JOY_DPAD_RIGHT, KEY_LEFT, KEY_LEFT, KEY_RIGHT, KEY_RIGHT)
	_add_simple("ui_accept", [KEY_ENTER, KEY_SPACE, KEY_KP_ENTER], [JOY_BUTTON_A, JOY_BUTTON_START])
	_add_simple("ui_cancel", [KEY_ESCAPE, KEY_BACK], [JOY_BUTTON_B, JOY_BUTTON_BACK])

func _add_simple(action: String, keys: Array, buttons: Array):
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.scancode = k
		InputMap.action_add_event(action, ev)
	for b in buttons:
		var ev := InputEventJoypadButton.new()
		ev.button_index = b
		InputMap.action_add_event(action, ev)

func _add_axis(neg_action: String, pos_action: String, joy_axis: int, dpad_neg: int, dpad_pos: int, key_neg: int, key_neg2: int, key_pos: int, key_pos2: int):
	_add_simple(neg_action, [key_neg, key_neg2], [dpad_neg])
	_add_simple(pos_action, [key_pos, key_pos2], [dpad_pos])
	var ev := InputEventJoypadMotion.new()
	ev.axis = joy_axis
	ev.axis_value = -1.0
	InputMap.action_add_event(neg_action, ev)
	ev = InputEventJoypadMotion.new()
	ev.axis = joy_axis
	ev.axis_value = 1.0
	InputMap.action_add_event(pos_action, ev)

func get_move_vector() -> Vector2:
	var v := Vector2(
		float(Input.is_action_pressed("move_right")) - float(Input.is_action_pressed("move_left")),
		float(Input.is_action_pressed("move_down")) - float(Input.is_action_pressed("move_up"))
	)
	if v.length_squared() > 1.0:
		v = v.normalized()
	if virtual_move.length_squared() > 0.0:
		v = virtual_move
	return v

func press_action(action: String):
	Input.action_press(action)

func release_action(action: String):
	Input.action_release(action)

func tap_action(action: String):
	press_action(action)
	yield(get_tree().create_timer(0.05), "timeout")
	release_action(action)

func confirm_just_pressed() -> bool:
	return Input.is_action_just_pressed("confirm") or Input.is_action_just_pressed("ui_accept")

func back_just_pressed() -> bool:
	return Input.is_action_just_pressed("back") or Input.is_action_just_pressed("ui_cancel")

func has_joypad() -> bool:
	return Input.get_connected_joypads().size() > 0

func is_touch() -> bool:
	return OS.has_feature("android") and not has_joypad()
