extends Node2D
# TumbleBoy — escena de juego completa (modo historia, packs y niveles sueltos)

const C = preload("res://scripts/tumbleboy/tb_constants.gd")
const BoardScript = preload("res://scripts/tumbleboy/board.gd")
const BallScript = preload("res://scripts/tumbleboy/ball.gd")
const LevelsScript = preload("res://scripts/tumbleboy/levels.gd")
const TouchControlsScene = preload("res://scenes/TouchControls.tscn")
const UIFonts = preload("res://scripts/ui/ui_fonts.gd")

enum State { MENU, PLAYING, WIN_GAME }

var state: int = State.MENU

var board = null
var ball = null
var board_texture: Texture = null

var level_names: Array = []
var next_level := 0
var level_name := ""
var wait_timer := 0.0
var win_timer := 0.0
var screen_offset := Vector2.ZERO
var anim_timer := 0.0

var welcome_image: Texture = null
var win_game_image: Texture = null
var menu_anim1: Texture = null
var menu_anim2: Texture = null
var win_anim1: Texture = null
var win_anim2: Texture = null
var good_job_image: Texture = null

var hint_font: Font

var level_label: Label

func _ready():
	board = BoardScript.new()
	_load_level_list()
	level_label = Label.new()
	level_label.rect_position = Vector2(10 + C.GAME_OFFSET_X, 10)
	level_label.add_color_override("font_color", Color(1, 1, 1))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.4)
	level_label.add_stylebox_override("normal", sb)
	add_child(level_label)
	if InputManager.is_touch():
		add_child(TouchControlsScene.instance())

func _process(delta: float):
	match state:
		State.MENU:
			anim_timer += delta
			if anim_timer > 1.0:
				anim_timer -= 1.0
		State.PLAYING:
			if wait_timer > 0.0:
				wait_timer -= delta
				if wait_timer <= 0.0:
					_load_next_level()
			else:
				var force := InputManager.get_move_vector()
				ball.add_force(force.x * delta * C.BALL_FORCE, force.y * delta * C.BALL_FORCE)
				ball.update(delta)
				if ball.is_above_goal():
					_win_level()
		State.WIN_GAME:
			anim_timer += delta
			if anim_timer > 1.0:
				anim_timer -= 1.0
			win_timer -= delta
	update()

func _unhandled_input(ev):
	if state == State.MENU:
		if InputManager.back_just_pressed():
			_go_to_menu()
		elif ev is InputEventKey and ev.pressed and not ev.echo:
			_start_playing()
		elif ev is InputEventMouseButton and ev.pressed:
			_start_playing()
	elif state == State.PLAYING:
		if InputManager.back_just_pressed():
			_go_to_menu()
	elif state == State.WIN_GAME:
		if InputManager.back_just_pressed():
			_go_to_menu()
		elif (ev is InputEventKey and ev.pressed and not ev.echo) or (ev is InputEventMouseButton and ev.pressed):
			_go_to_menu()

func _go_to_menu():
	var target := LevelQueue.return_scene
	LevelQueue.clear()
	SaveData.end_session()
	if target != "":
		get_tree().change_scene(target)
		return
	get_tree().change_scene("res://scenes/MainMenu.tscn")

func _start_playing():
	_state_clear()
	if LevelQueue.paths.size() > 0:
		level_names = []
		level_names.append_array(LevelQueue.paths)
	else:
		_load_level_list()
	next_level = LevelQueue.start_index
	if next_level < 0:
		next_level = 0
	if next_level > level_names.size():
		next_level = level_names.size()
	var saved_scene := LevelQueue.return_scene
	LevelQueue.clear()
	LevelQueue.return_scene = saved_scene
	_load_next_level()
	state = State.PLAYING

func _state_clear():
	ball = null
	board.clear()
	board_texture = null

func _win_level():
	AudioManager.play_sfx(C.SOUNDS_DIR + "win_level.ogg")
	wait_timer = 3.5
	SaveData.record_progress(next_level)

func _load_level_list():
	# Modo historia nostálgico: SOLO los 21 niveles originales de res://,
	# sin cambios. Los niveles de usuario y packs van por el selector.
	level_names = []
	var dir := Directory.new()
	if dir.open(C.LEVELS_DIR) == OK:
		dir.list_dir_begin()
		var fname := dir.get_next()
		while fname != "":
			if not dir.current_is_dir() and fname.ends_with(".txt"):
				level_names.append(C.LEVELS_DIR + fname)
			fname = dir.get_next()
		dir.list_dir_end()
	level_names.sort()
	next_level = 0

func _load_next_level():
	if next_level >= level_names.size():
		state = State.WIN_GAME
		win_timer = 10.0
		anim_timer = 0.0
		AudioManager.play_sfx(C.SOUNDS_DIR + "win_game.ogg")
		return
	_load_level(level_names[next_level])
	next_level += 1

func _level_display_name(filename: String) -> String:
	var base := filename.get_file()
	return base.get_basename()

func _load_level(filename: String):
	level_name = _level_display_name(filename)
	level_label.text = level_name

	ball = BallScript.new()
	board.clear()
	board_texture = null

	var info = LevelsScript.parse_level(filename)
	var attributes = info["attributes"]
	var level_map = info["map"]
	if attributes.has("name") and str(attributes["name"]) != "":
		level_label.text = str(attributes["name"])
	if attributes.has("boy"):
		ball.set_theme(attributes["boy"])
	if attributes.has("theme"):
		board.set_theme(attributes["theme"])

	for row in range(level_map.size()):
		var cols = level_map[row]
		for col in range(cols.size()):
			board.set_block(col, row, cols[col])

	ball.set_board(board)
	var sp = board.get_start_position()
	ball.set_position(sp.x, sp.y, 0)
	AudioManager.play_sfx(C.SOUNDS_DIR + "start_level.ogg")
	_render_board_image()

func _render_board_image():
	board_texture = board.render_board_image()

func _get_screen_offset() -> Vector2:
	if ball == null:
		return Vector2.ZERO
	var ox := screen_offset.x
	var oy := screen_offset.y
	var px = ball.position.x * C.PIXEL_SIZE
	var py = ball.position.y * C.PIXEL_SIZE
	var maxx = -(px - C.SCREEN_MARGIN)
	var minx = -(px + C.SCREEN_MARGIN + C.BALL_PIXEL_SIZE - C.SCREEN_W)
	var maxy = -(py - C.SCREEN_MARGIN)
	var miny = -(py + C.SCREEN_MARGIN + C.BALL_PIXEL_SIZE - C.SCREEN_H)
	if ox < minx:
		ox = minx
	if ox > maxx:
		ox = maxx
	if oy < miny:
		oy = miny
	if oy > maxy:
		oy = maxy
	screen_offset = Vector2(ox, oy)
	return screen_offset

func _load_texture(path: String) -> Texture:
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture:
			return res
	return null

func _draw():
	draw_rect(Rect2(0, 0, 1200, 825), Color(0, 0, 0))
	if state == State.MENU:
		_draw_menu()
	elif state == State.WIN_GAME:
		_draw_win()
	else:
		_draw_game()

func _draw_menu():
	if welcome_image == null:
		welcome_image = _load_texture(C.MENUS_DIR + "main_menu.png")
		menu_anim1 = _load_texture(C.MENUS_DIR + "menu_anim1.png")
		menu_anim2 = _load_texture(C.MENUS_DIR + "menu_anim2.png")
	if welcome_image != null:
		draw_texture(welcome_image, Vector2(C.GAME_OFFSET_X, 0))
	var anim: Texture = menu_anim1 if anim_timer > 0.5 else menu_anim2
	if anim != null:
		draw_texture(anim, C.MENU_ANIM_RECT.position + Vector2(C.GAME_OFFSET_X, 0))
	_draw_hint()

func _draw_win():
	if win_game_image == null:
		win_game_image = _load_texture(C.MENUS_DIR + "win_game.png")
		win_anim1 = _load_texture(C.MENUS_DIR + "win_anim1.png")
		win_anim2 = _load_texture(C.MENUS_DIR + "win_anim2.png")
	if win_game_image != null:
		draw_texture(win_game_image, Vector2(C.GAME_OFFSET_X, 0))
	var anim: Texture = win_anim1 if anim_timer > 0.5 else win_anim2
	if anim != null:
		draw_texture(anim, C.WIN_ANIM_RECT.position + Vector2(C.GAME_OFFSET_X, 0))
	_draw_hint()

func _draw_game():
	var offset := _get_screen_offset()
	if board_texture != null:
		draw_texture(board_texture, offset + Vector2(C.GAME_OFFSET_X, 0))
	if ball != null:
		if ball.images.size() == 0:
			ball.setup_images()
		var tex = ball.current_texture()
		if tex != null:
			var draw_pos := Vector2(
				ball.position.x * C.PIXEL_SIZE + offset.x + C.GAME_OFFSET_X - C.BALLSPRITE_OFFSETX + ball.current_offs().x,
				ball.position.y * C.PIXEL_SIZE + offset.y - C.BALLSPRITE_OFFSETY + ball.current_offs().y
			)
			draw_texture(tex, draw_pos)
	if wait_timer > 0.0:
		if good_job_image == null:
			good_job_image = _load_texture(C.MENUS_DIR + "good_job.png")
		if good_job_image != null:
			var size := Vector2(C.GOOD_JOB_SIZE, C.GOOD_JOB_SIZE)
			draw_texture_rect(good_job_image, Rect2(Vector2(600 - size.x * 0.5, 412.5 - size.y * 0.5), size), false)

func _draw_hint():
	if hint_font == null:
		hint_font = UIFonts.make_font(20)
	var text := "B / ESC: menú"
	var pos := Vector2(C.GAME_OFFSET_X + 20, C.SCREEN_H - 20)
	var text_size := hint_font.get_string_size(text)
	var pad := Vector2(10, 6)
	draw_rect(Rect2(pos.x - pad.x, pos.y - text_size.y - pad.y, text_size.x + pad.x * 2, text_size.y + pad.y * 2), Color(0, 0, 0, 0.55))
	draw_string(hint_font, pos, text, Color(1, 1, 1, 0.8))
