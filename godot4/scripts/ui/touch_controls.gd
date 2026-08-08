extends Control
# TouchControls — joystick virtual (izquierda) + botón derecho del mismo tamaño
# que el análogo para alternar entre Mando (joystick) y Acelerómetro.
# Adaptativo al tamaño del viewport. Solo se muestra en móvil (Android) o con
# --force-touch (pruebas en escritorio).
# Port a Godot 4: connect("control_mode_changed", self, ...) -> Callable,
# draw_string con font_size explícito.

const UIFonts = preload("res://scripts/ui/ui_fonts.gd")

var joystick_center := Vector2(150, 680)
var joystick_radius := 65.0
var knob_max := 55.0
var knob_offset := Vector2.ZERO
var toggle_center := Vector2(1120, 680)
var toggle_radius := 65.0

var joystick_visible := true
var joystick_active := false
var joystick_touch_id := -1
var toggle_touch_id := -1

var _label_font: Font

func _ready():
	_label_font = UIFonts.make_font(13)
	visible = InputManager.is_mobile()
	if visible:
		_recalculate_positions()
		InputManager.control_mode_changed.connect(_on_mode_changed)
		_update_mode_ui()

func _notification(what):
	if what == NOTIFICATION_RESIZED and visible:
		_recalculate_positions()

func _recalculate_positions():
	var vp := get_viewport().get_visible_rect().size
	if vp.x <= 0.0 or vp.y <= 0.0:
		return
	var m := 24.0
	joystick_center = Vector2(m + joystick_radius, vp.y - m - joystick_radius)
	toggle_center = Vector2(vp.x - m - toggle_radius, vp.y - m - toggle_radius)
	queue_redraw()

func _input(ev):
	if not visible:
		return
	if ev is InputEventScreenTouch:
		if ev.pressed:
			if joystick_visible and joystick_center.distance_to(ev.position) <= joystick_radius * 1.8:
				joystick_active = true
				joystick_touch_id = ev.index
				_update_knob(ev.position)
				get_viewport().set_input_as_handled()
			elif toggle_center.distance_to(ev.position) <= toggle_radius * 1.3:
				toggle_touch_id = ev.index
				_toggle_control_mode()
				get_viewport().set_input_as_handled()
		else:
			if joystick_touch_id == ev.index:
				joystick_active = false
				joystick_touch_id = -1
				knob_offset = Vector2.ZERO
				InputManager.virtual_move = Vector2.ZERO
				queue_redraw()
				get_viewport().set_input_as_handled()
			elif toggle_touch_id == ev.index:
				toggle_touch_id = -1
				get_viewport().set_input_as_handled()
	elif ev is InputEventScreenDrag:
		if joystick_touch_id == ev.index and joystick_active:
			_update_knob(ev.position)
			get_viewport().set_input_as_handled()

func _toggle_control_mode():
	if InputManager.is_tilt_mode():
		InputManager.set_control_mode(InputManager.ControlMode.TOUCH)
	else:
		InputManager.recalibrate_tilt()
		InputManager.set_control_mode(InputManager.ControlMode.TILT)
	_update_mode_ui()

func _on_mode_changed(_mode: int):
	_update_mode_ui()

func _update_mode_ui():
	if InputManager.is_tilt_mode():
		joystick_visible = false
		if joystick_active:
			joystick_active = false
			joystick_touch_id = -1
			knob_offset = Vector2.ZERO
			InputManager.virtual_move = Vector2.ZERO
	else:
		joystick_visible = true
	queue_redraw()

func _update_knob(pos: Vector2):
	var offset := pos - joystick_center
	if offset.length() > knob_max:
		offset = offset.normalized() * knob_max
	knob_offset = offset
	InputManager.virtual_move = offset / knob_max
	queue_redraw()

func _draw():
	if not visible:
		return
	if joystick_visible:
		draw_circle(joystick_center, joystick_radius, Color(1, 1, 1, 0.15))
		draw_arc(joystick_center, joystick_radius, 0, TAU, 48, Color(1, 1, 1, 0.5), 3.0)
		draw_circle(joystick_center + knob_offset, 30, Color(1, 1, 1, 0.45))
	_draw_button(toggle_center, toggle_radius, "Acelerómetro" if not InputManager.is_tilt_mode() else "Mando")

func _draw_button(center: Vector2, radius: float, label: String):
	draw_circle(center, radius, Color(1, 1, 1, 0.12))
	draw_arc(center, radius, 0, TAU, 48, Color(1, 1, 1, 0.5), 3.0)
	var size := _label_font.get_string_size(label)
	var base := center.y + (_label_font.get_ascent() - _label_font.get_descent()) * 0.5
	draw_string(_label_font, Vector2(center.x - size.x * 0.5, base), label, -1, -1, 13, Color(1, 1, 1, 0.8))
