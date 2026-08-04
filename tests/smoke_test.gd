extends Node2D
# Smoke test — valida la lógica de TumbleBoy en headless.
# Uso: godot3 --headless --path . res://scenes/SmokeTest.tscn

const C = preload("res://scripts/tumbleboy/tb_constants.gd")
const BoardScript = preload("res://scripts/tumbleboy/board.gd")
const LevelsScript = preload("res://scripts/tumbleboy/levels.gd")
const BallScript = preload("res://scripts/tumbleboy/ball.gd")
const TumbleBoyScript = preload("res://scripts/tumbleboy/tumbleboy.gd")
const TumbleBoyScene = preload("res://scenes/TumbleBoy.tscn")
const EditorScene = preload("res://scenes/TumbleBoyEditor.tscn")
const LevelSelectScene = preload("res://scenes/LevelSelect.tscn")
const MainMenuScene = preload("res://scenes/MainMenu.tscn")
const PackReader = preload("res://scripts/tumbleboy/pack_reader.gd")
const ZipWriter = preload("res://scripts/tumbleboy/zip_writer.gd")
const ZipReader = preload("res://scripts/tumbleboy/zip_reader.gd")

var failures := 0

func _ready():
	_test_levels()
	_test_board()
	_test_ball()
	_test_scene()
	_test_editor()
	_test_zip()
	_test_level_select()
	_test_main_menu()
	if failures == 0:
		print("SMOKE TEST: ALL PASS")
	else:
		print("SMOKE TEST: %d FAILURES" % failures)
	get_tree().quit(failures)

func _check(cond: bool, msg: String):
	if cond:
		print("  OK: " + msg)
	else:
		failures += 1
		print("  FAIL: " + msg)

func _test_levels():
	print("== levels ==")
	var dir := Directory.new()
	var count := 0
	if dir.open(C.LEVELS_DIR) == OK:
		dir.list_dir_begin()
		var fname := dir.get_next()
		while fname != "":
			if not dir.current_is_dir() and fname.ends_with(".txt"):
				count += 1
			fname = dir.get_next()
	_check(count == 21, "21 niveles detectados (got %d)" % count)

	var l1: Dictionary = LevelsScript.parse_level(C.LEVELS_DIR + "01-Introduction.txt")
	_check(l1["attributes"].has("boy"), "nivel 1 tiene atributo .boy")
	_check(l1["attributes"]["boy"] == "boy1", "nivel 1 .boy = boy1")
	_check(l1["map"].size() > 0, "nivel 1 tiene mapa")
	var rows := 0
	var total := 0
	for row in l1["map"]:
		rows += 1
		total += row.size()
	_check(rows == 5 and total == 5 * 12, "nivel 1 es 5x12 (%dx%d)" % [rows, total])

	_test_write_level(l1)

func _test_write_level(l1: Dictionary):
	var attrs := { "name": "Smoke", "author": "Test", "theme": "default", "boy": "boy1" }
	var map2: Array = []
	for row in l1["map"]:
		var nr: Array = []
		nr.append_array(row)
		map2.append(nr)
	var tmp := "user://smoke_write_level.txt"
	var saved := LevelsScript.write_level(tmp, attrs, map2)
	_check(saved, "write_level guarda a user://")
	var back: Dictionary = LevelsScript.parse_level(tmp)
	_check(back["attributes"].has("name") and back["attributes"]["name"] == "Smoke", "atributos sobreviven al round-trip")
	_check(back["map"].size() == map2.size(), "mismo nº de filas tras round-trip")
	var equal := true
	for i in range(map2.size()):
		if back["map"][i] != map2[i]:
			equal = false
	_check(equal, "mapa idéntico tras round-trip")
	var dir := Directory.new()
	dir.remove(tmp)

func _test_board():
	print("== board ==")
	var b = BoardScript.new()
	b.set_block(0, 0, C.BLOCK_FLOOR)
	b.set_block(1, 0, C.BLOCK_WALL)
	b.set_block(2, 0, C.BLOCK_DOUBLEWALL)
	b.set_block(3, 0, C.BLOCK_RAMP_RIGHT)
	b.set_block(4, 0, C.BLOCK_START)
	b.set_block(5, 0, C.BLOCK_GOAL)
	_check(b.height_at(0.5, 0.5) == 0.0, "floor height 0")
	_check(b.height_at(1.5, 0.5) == 1.0, "wall height 1")
	_check(b.height_at(2.5, 0.5) == 2.0, "doublewall height 2")
	_check(abs(b.height_at(3.2, 0.5) - 0.2) < 0.001, "ramp right height fraccional")
	_check(b.block_at(5, 0) == C.BLOCK_GOAL, "block_at goal")
	var sp: Vector2 = b.get_start_position()
	_check(sp == Vector2(4, 0), "start position = (4,0)")
	b.set_block(0, 1, C.BLOCK_BUMPER)
	_check(b.get_colliding_bumper(0.5, 1.5) != null, "bumper colisiona en centro")

func _test_ball():
	print("== ball ==")
	var b = BoardScript.new()
	b.set_block(0, 0, C.BLOCK_FLOOR)
	b.set_block(1, 0, C.BLOCK_FLOOR)
	b.set_block(2, 0, C.BLOCK_FLOOR)
	b.set_block(1, 0, C.BLOCK_START)
	b.set_block(2, 0, C.BLOCK_GOAL)
	var ball = BallScript.new()
	ball.set_theme("boy1")
	ball.set_board(b)
	ball.set_position(1, 0, 0)
	for i in range(120):
		ball.add_force(1.0, 0.0)
		ball.update(1.0 / 60.0)
	_check(ball.position.x > 1.0, "la bola se mueve +x (x=%.3f)" % ball.position.x)
	_check(ball.position.z <= 0.001, "la bola queda en el suelo (z=%.3f)" % ball.position.z)
	_check(ball.velocity.length() <= C.MAX_SPEED + 0.01, "velocidad <= MAX_SPEED (%.3f)" % ball.velocity.length())
	ball.setup_images()
	_check(ball.images.size() == 6, "6 niveles de escala")
	_check(ball.images[0].frames.size() == 10, "10 frames por escala")
	var tex = ball.current_texture()
	_check(tex != null, "textura actual no nula")

func _test_scene():
	print("== scene ==")
	var tb = TumbleBoyScene.instance()
	add_child(tb)
	tb._start_playing()
	_check(tb.state == TumbleBoyScript.State.PLAYING, "scene en PLAYING")
	_check(tb.ball != null, "ball creada")
	_check(tb.board.width > 0, "board con tamaño")
	_check(tb.board_texture != null, "board renderizado a textura")
	_check(tb.level_names.size() == 21, "modo historia = 21 niveles de res:// (got %d)" % tb.level_names.size())
	for i in range(30):
		tb._process(1.0 / 60.0)
	_check(tb.ball.position.x >= 0.0, "física estable tras 30 frames (x=%.3f)" % tb.ball.position.x)

func _test_editor():
	print("== editor ==")
	var ed = EditorScene.instance()
	add_child(ed)
	_check(ed.map.size() == 5 and ed.map[0].size() == 12, "nuevo nivel es 5x12")
	_check(ed.board.width == 12 and ed.board.height == 5, "board con dimensiones lógicas (12x5)")
	ed._paint_cell(3, 2, false)
	_check(ed.map[2][3] == C.BLOCK_FLOOR, "pintar piso en (3,2)")
	_check(ed.board.block_at(3, 2) == C.BLOCK_FLOOR, "board refleja el bloque pintado")
	ed._select_paint(C.BLOCK_START)
	ed._paint_cell(1, 1, false)
	ed._paint_cell(8, 4, false)
	var starts := 0
	for row in ed.map:
		for cell in row:
			if cell == C.BLOCK_START:
				starts += 1
	_check(starts == 1, "solo un bloque Inicio a la vez")
	_check(ed._validate_map() != "", "sin Meta: nivel inválido")
	ed._select_paint(C.BLOCK_GOAL)
	ed._paint_cell(9, 4, false)
	_check(ed._validate_map() == "", "con $ y 1: nivel válido")
	ed._paint_cell(3, 2, true)
	_check(ed.map[2][3] == C.BLOCK_NONE, "borrar con erase=true")
	ed._undo()
	_check(ed.map[2][3] == C.BLOCK_FLOOR, "undo restaura el piso")
	ed._redo()
	_check(ed.map[2][3] == C.BLOCK_NONE, "redo vuelve a borrar")
	ed._select_paint(C.BLOCK_FLOOR)
	ed._paint_cell(0, 0, false)
	_check(ed.board.block_at(0, 0) == C.BLOCK_FLOOR, "board crece al pintar en 0,0")
	_check(ed.paint_buttons.size() == 15, "paleta sin Piso2/Piso3 (%d bloques)" % ed.paint_buttons.size())
	_check(ed.theme_option.get_item_text(0) == "Por defecto", "tema traducido en OptionButton")
	_check(ed.boy_option.get_item_text(0) == "Predeterminado", "niño traducido en OptionButton")
	ed.author_edit.text = "Tester"
	ed.desc_edit.text = "Nivel de prueba"
	ed._collect_fields_to_attributes()
	_check(ed.attributes.get("author") == "Tester", "autor (créditos) a atributos")
	_check(ed.attributes.get("instructions") == "Nivel de prueba", "descripción a atributos")
	ed.current_file = "res://assets/tumbleboy/data/levels/01-Introduction.txt"
	ed.read_only = true
	ed._paint_cell(10, 4, false)
	_check(ed.map[4][10] == C.BLOCK_NONE, "solo lectura bloquea pintar")
	ed._on_save()
	_check(ed.status_label.text.find("solo lectura") >= 0, "guardar en solo lectura avisa")
	ed.read_only = false
	ed.current_file = ""
	ed.author_edit.text = "Tester"
	ed._save_to("user://tumbleboy_levels/smoke_pack_level.txt")
	_check(File.new().file_exists("user://tumbleboy_levels/smoke_pack_level.txt"), "nivel guardado a user://")
	var zip_dir := Directory.new()
	if zip_dir.open("user://tumbleboy_packs") == OK:
		zip_dir.remove("smoke_pack.zip")
	ed.pack_name_edit.text = "Smoke Pack"
	ed.pack_author_edit.text = "Tester"
	ed.pack_desc_edit.text = "Pack de prueba"
	ed._refresh_pack_available()
	_check(ed.pack_available.has("user://tumbleboy_levels/smoke_pack_level.txt"), "nivel disponible para el pack")
	ed.pack_selected = ["user://tumbleboy_levels/smoke_pack_level.txt"]
	ed.pack_list.add_item("smoke_pack_level.txt")
	ed._on_create_pack()
	_check(File.new().file_exists("user://tumbleboy_packs/smoke_pack.zip"), "pack ZIP creado")
	var packs = PackReader.list_packs()
	var found := false
	for p in packs:
		if p.get("name") == "Smoke Pack":
			found = true
	_check(found, "manifest del pack leído con título")
	var lvl_text := PackReader.get_level_text("user://tumbleboy_packs/smoke_pack.zip", "levels/smoke_pack_level.txt")
	_check(lvl_text.length() > 0, "nivel leído del ZIP")
	var lvl = LevelsScript.parse_level_text(lvl_text)
	_check(lvl["map"].size() > 0, "nivel del pack parseable")
	var znames = PackReader.list_level_filenames("user://tumbleboy_packs/smoke_pack.zip")
	_check(znames.size() == 1 and znames[0] == "levels/smoke_pack_level.txt", "get_files del ZIP")
	ed.free()

func _test_zip():
	print("== zip ==")
	var files := {
		"manifest.json": "{\"name\": \"Z\", \"author\": \"T\"}",
		"levels/a.txt": ".name {A}\n!!!\n---- \n!!!\n",
		"levels/b.txt": ".name {B}\n!!!\n-1-$ \n!!!\n",
	}
	var zp := "user://smoke_roundtrip.zip"
	var dir := Directory.new()
	dir.remove(zp)
	_check(ZipWriter.write_pack_zip(zp, files), "write_pack_zip guarda")
	var names = ZipReader.get_files(zp)
	_check(names.size() == 3, "get_files devuelve %d archivos (3)" % names.size())
	var manifest = ZipReader.read_file(zp, "manifest.json")
	_check(manifest != null and manifest.get_string_from_utf8().find("Z") >= 0, "read_file lee manifest")
	var b = ZipReader.read_file(zp, "levels/b.txt")
	_check(b != null and b.get_string_from_utf8().find(".name {B}") >= 0, "read_file lee nivel con contenido")
	dir.remove(zp)

func _test_level_select():
	print("== level select ==")
	LevelQueue.clear()
	LevelQueue.play_levels(["user://a.txt", "user://b.txt"], "Prueba")
	_check(LevelQueue.paths.size() == 2 and LevelQueue.return_scene == "res://scenes/LevelSelect.tscn", "LevelQueue guarda secuencia y vuelta al selector")
	LevelQueue.clear()
	var ls = LevelSelectScene.instance()
	add_child(ls)
	_check(ls.store != null, "selector crea PackStore")
	_check(ls.pack_buttons.has("smoke_pack"), "pack del editor visible en el selector")
	var users = ls._list_user_levels()
	_check(users.has("user://tumbleboy_levels/smoke_pack_level.txt"), "niveles de usuario listados")
	var bcount := 0
	for ch in ls.menu_vbox.get_children():
		if ch is Button:
			bcount += 1
	_check(bcount >= 4, "menú del selector con botones (got %d)" % bcount)
	ls.free()

func _test_main_menu():
	print("== main menu ==")
	var mm = MainMenuScene.instance()
	add_child(mm)
	var vbox: VBoxContainer = null
	for ch in mm.get_children():
		if ch is VBoxContainer:
			vbox = ch
			break
	_check(vbox != null, "menú tiene VBoxContainer")
	var texts := []
	if vbox != null:
		for ch in vbox.get_children():
			if ch.has_method("get_text") or "text" in ch:
				texts.append(ch.text)
	_check(texts.size() == 6, "menú: título+subtítulo+3 botones+hint (got %d)" % texts.size())
	_check(texts.has("TUMBLEBOY REBORN"), "título TumbleBoy presente")
	_check(texts.has("Niveles y packs"), "botón Niveles y packs presente")
	_check(texts.has("Editor de niveles"), "botón Editor de niveles presente")
	_check(texts.has("Jugar — TumbleBoy (historia)"), "botón Jugar historia presente")
	_check(ProjectSettings.get_setting("application/config/name") == "TumbleBoy Reborn", "nombre del proyecto = TumbleBoy Reborn")
	mm.free()
