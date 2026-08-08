extends Node
# InputManager — capa de entrada unificada (destilado del caso TumbleBoy).
# Port de templates/godot3 a Godot 4: scancode -> physical_keycode,
# JOY_DPAD_* -> JOY_BUTTON_DPAD_*, clamped -> limit_length,
# linear_interpolate -> lerp, yield -> await.
# - Construye el InputMap en tiempo de ejecución (mismo comportamiento en
#   teclado, gamepad/D-pad y touch).
# - Expone helpers usados por los menús y el juego.
# - Traduce el botón Atrás (Android BACK, ESC, botón B) a la acción `back`.
#   GOTCHA: en Android el BACK llega solo como NOTIFICATION_WM_GO_BACK_REQUEST,
#   nunca como InputEventKey; hay que sondear back_just_pressed en _process.

signal confirm_pressed
signal back_pressed
signal control_mode_changed(mode)

enum ControlMode { TOUCH, TILT }

var virtual_move: Vector2 = Vector2.ZERO
var virtual_pointer_pos: Vector2 = Vector2.ZERO
var virtual_pointer_down: bool = false

var control_mode: int = ControlMode.TOUCH

var _tilt_calib := Vector2.ZERO
var _tilt_smoothed := Vector2.ZERO

func _init():
	_build_input_map()

func _ready():
	set_process_input(true)
	control_mode = SaveData.get_setting("control_mode", ControlMode.TOUCH)

func _notification(what):
	# En Godot el botón Atrás de Android NO llega como InputEventKey: el sistema
	# solo emite NOTIFICATION_WM_GO_BACK_REQUEST (en Godot 4 vive en Node;
	# en Godot 3 colgaba de MainLoop). Con quit_on_go_back=false la app no se
	# cierra sola; aquí traducimos esa petición a la acción `back` para que toda
	# la lógica (back_just_pressed) funcione igual en Android.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# En Android el Atrás es un tap sin key-up; action_press marca el frame
		# incondicionalmente, así cada GO_BACK genera un just_pressed fresco
		# (sin necesidad de un release intermedio).
		Input.action_press("back")
		Input.action_press("ui_cancel")

func _build_input_map():
	_add_axis("move_up", "move_down", JOY_AXIS_LEFT_Y, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, KEY_W, KEY_UP, KEY_S, KEY_DOWN)
	_add_axis("move_left", "move_right", JOY_AXIS_LEFT_X, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, KEY_A, KEY_LEFT, KEY_D, KEY_RIGHT)

	_add_simple("confirm", [KEY_ENTER, KEY_SPACE, KEY_KP_ENTER], [JOY_BUTTON_A, JOY_BUTTON_START])
	_add_simple("back", [KEY_ESCAPE, KEY_BACK], [JOY_BUTTON_B, JOY_BUTTON_BACK])
	_add_simple("ui_toggle", [KEY_F2], [JOY_BUTTON_Y])

	# Acciones de foco (navegación con D-pad en TV)
	_add_axis("ui_up", "ui_down", JOY_AXIS_LEFT_Y, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, KEY_UP, KEY_UP, KEY_DOWN, KEY_DOWN)
	_add_axis("ui_left", "ui_right", JOY_AXIS_LEFT_X, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, KEY_LEFT, KEY_LEFT, KEY_RIGHT, KEY_RIGHT)
	_add_simple("ui_accept", [KEY_ENTER, KEY_SPACE, KEY_KP_ENTER], [JOY_BUTTON_A, JOY_BUTTON_START])
	_add_simple("ui_cancel", [KEY_ESCAPE, KEY_BACK], [JOY_BUTTON_B, JOY_BUTTON_BACK])

func _add_simple(action: String, keys: Array, buttons: Array):
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
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
	if is_tilt_mode():
		var tilt := _get_tilt_vector()
		if tilt != Vector2.ZERO:
			return tilt
	var v := Vector2(
		float(Input.is_action_pressed("move_right")) - float(Input.is_action_pressed("move_left")),
		float(Input.is_action_pressed("move_down")) - float(Input.is_action_pressed("move_up"))
	)
	if v.length_squared() > 1.0:
		v = v.normalized()
	if virtual_move.length_squared() > 0.0:
		v = virtual_move
	return v

func get_hardware_move_vector() -> Vector2:
	var v := Vector2(
		float(Input.is_action_pressed("move_right")) - float(Input.is_action_pressed("move_left")),
		float(Input.is_action_pressed("move_down")) - float(Input.is_action_pressed("move_up"))
	)
	if v.length_squared() > 1.0:
		v = v.normalized()
	return v

func press_action(action: String):
	Input.action_press(action)

func release_action(action: String):
	Input.action_release(action)

func tap_action(action: String):
	press_action(action)
	await get_tree().create_timer(0.05).timeout
	release_action(action)

func confirm_just_pressed() -> bool:
	return Input.is_action_just_pressed("confirm") or Input.is_action_just_pressed("ui_accept")

func back_just_pressed() -> bool:
	return Input.is_action_just_pressed("back") or Input.is_action_just_pressed("ui_cancel")

# Teclas que el InputMap trata como Atrás (ESC / BACK de Android). Sirve para que
# ramas de "cualquier tecla" de un _unhandled_input no disparen a la vez que el back.
func is_back_key(keycode: int) -> bool:
	return keycode == KEY_ESCAPE or keycode == KEY_BACK

func ui_toggle_just_pressed() -> bool:
	return Input.is_action_just_pressed("ui_toggle")

func has_joypad() -> bool:
	return Input.get_connected_joypads().size() > 0

# --- Móvil: controles táctiles y modo tilt ---

func is_mobile() -> bool:
	# El tag correcto es "mobile" (OS.get_name() devuelve "Android" con mayúscula;
	# "android" en minúsculas NO existe como feature tag).
	if OS.has_feature("mobile"):
		return true
	return "--force-touch" in OS.get_cmdline_args()

func set_control_mode(mode: int):
	control_mode = mode
	SaveData.set_setting("control_mode", mode)
	control_mode_changed.emit(mode)

func is_tilt_mode() -> bool:
	return control_mode == ControlMode.TILT and is_mobile()

func recalibrate_tilt():
	_tilt_calib = _raw_tilt()
	_tilt_smoothed = Vector2.ZERO

func _raw_tilt() -> Vector2:
	var acc := Input.get_accelerometer()
	return Vector2(acc.x, acc.y)

func _get_tilt_vector() -> Vector2:
	var raw := _raw_tilt() - _tilt_calib
	var v := Vector2(raw.x, -raw.y)
	if v.length() < 0.7:
		return Vector2.ZERO
	v = v.limit_length(6.0)
	_tilt_smoothed = _tilt_smoothed.lerp(v / 6.0, 0.3)
	return _tilt_smoothed
