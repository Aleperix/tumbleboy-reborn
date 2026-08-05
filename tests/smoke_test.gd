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
const MainMenuScene = preload("res://scenes/MainMenu.tscn")
const StoryHubScene = preload("res://scenes/StoryHub.tscn")
const SlotPickerScene = preload("res://scenes/SlotPicker.tscn")
const PacksCommunityScene = preload("res://scenes/PacksCommunity.tscn")
const EditorHubScene = preload("res://scenes/EditorHub.tscn")
const CreditsScene = preload("res://scenes/Credits.tscn")
const PackReader = preload("res://scripts/tumbleboy/pack_reader.gd")
const ZipWriter = preload("res://scripts/tumbleboy/zip_writer.gd")
const ZipReader = preload("res://scripts/tumbleboy/zip_reader.gd")
const PackRow = preload("res://scripts/ui/pack_row.gd")
const FocusNav = preload("res://scripts/ui/focus_nav.gd")

var failures := 0

func _ready():
	_test_levels()
	_test_board()
	_test_ball()
	_test_scene()
	_test_editor()
	_test_zip()
	_test_save_slots()
	_test_level_queue()
	_test_story_hub()
	_test_slot_picker()
	_test_packs_community()
	_test_editor_hub()
	_test_main_menu()
	_test_credits()
	_test_play_button_toggle()
	_test_editor_ui_mode()
	_test_save_validation()
	_test_editor_draft_load()
	_test_thumbnail_zip()
	_test_draft_roundtrip()
	_test_nav_params_draft()
	_test_hub_draft_section()
	_test_descargados_buttons()
	_test_propios_buttons()
	_test_focus_nav()
	_test_settings()
	_test_touch_controls()
	_test_mobile_detection()
	yield(_test_list_layout(), "completed")
	yield(_test_focus_reentry(), "completed")
	_test_game_icon()
	_test_pack_row()
	yield(get_tree(), "idle_frame")
	yield(_test_navigation(), "completed")
	yield(get_tree(), "idle_frame")
	_test_focus()
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
	_check(ed.map.size() == 12 and ed.map[0].size() == 20, "nuevo nivel es 20x12")
	_check(ed.board.width == 20 and ed.board.height == 12, "board con dimensiones lógicas (20x12)")
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
	ed.name_edit.text = "Smoke"
	ed.author_edit.text = "Tester"
	ed.desc_edit.text = "Nivel de prueba"
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
	ed._select_paint(C.BLOCK_START)
	ed._paint_cell(1, 1, false)
	ed._select_paint(C.BLOCK_GOAL)
	ed._paint_cell(25, 16, false)
	_check(ed.map.size() == 17 and ed.map[16].size() == 26, "pintar fuera de bordes amplía el mapa (got %dx%d)" % [ed.map[16].size(), ed.map.size()])
	_check(ed.map[16][25] == C.BLOCK_GOAL, "bloque colocado fuera de los bordes iniciales")
	_check(ed.board.width == 26 and ed.board.height == 17, "board crece con el mapa")
	_check(ed._validate_map() == "", "meta lejos sigue válida (con $ y 1)")
	ed._select_paint(C.BLOCK_FLOOR)
	ed._paint_cell(50, 30, false)
	var rows = ed.map.size()
	var cols = 0
	if rows > 0:
		cols = ed.map[rows - 1].size()
	_check(rows == 31 and cols == 51, "crecimiento dentro del tope llega a 51x31 (got %dx%d)" % [cols, rows])
	ed._paint_cell(70, 50, false)
	_check(ed.map.size() == 31 and ed.map[30].size() == 51, "no crece más allá de GRID_MAX (60x40)")
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

func _backup_save() -> String:
	var f := File.new()
	if f.file_exists(SaveData.SAVE_PATH):
		if f.open(SaveData.SAVE_PATH, File.READ) == OK:
			var t := f.get_as_text()
			f.close()
			return t
	return ""

func _restore_save(text: String):
	if text == "":
		Directory.new().remove(SaveData.SAVE_PATH)
	else:
		var f := File.new()
		if f.open(SaveData.SAVE_PATH, File.WRITE) == OK:
			f.store_string(text)
			f.close()
	SaveData._load()

func _test_save_slots():
	print("== save slots ==")
	var backup := _backup_save()
	SaveData.reset_all()
	_check(SaveData.count_saves("story") == 0, "historia sin zócalos al inicio")
	_check(SaveData.get_game_key("story", "historia") == "story", "clave historia = story")
	_check(SaveData.get_game_key("pack", "mi_pack") == "pack:mi_pack", "clave pack = pack:<id>")
	SaveData.begin_session("story", "historia", 0, 21, 0)
	_check(SaveData.has_save("story", 0), "zócalo 0 de historia guardado")
	_check(SaveData.count_saves("story") == 1, "1 zócalo ocupado (historia)")
	SaveData.record_progress(3)
	var info: Dictionary = SaveData.get_slot_info("story", 0)
	_check(info.get("completed", -1) == 3, "record_progress actualiza completed (got %s)" % str(info.get("completed", -1)))
	_check(not SaveData.has_save("pack:mi_pack", 0), "packs no comparten zócalos con historia")
	SaveData.begin_session("pack", "mi_pack", 1, 8, 0)
	_check(SaveData.has_save("pack:mi_pack", 1), "zócalo 1 del pack guardado independiente")
	_check(SaveData.count_saves("story") == 1, "historia intacta tras guardar pack")
	SaveData.end_session()
	_check(SaveData.active_slot == -1 and SaveData.active_key == "", "end_session limpia sesión")
	SaveData.clear_slot("story", 0)
	_check(not SaveData.has_save("story", 0), "clear_slot libera zócalo")
	SaveData.mark_pack_downloaded("x")
	_check(SaveData.is_pack_downloaded("x") and not SaveData.is_pack_local("x"), "mark_pack_downloaded registra y is_pack_local lo ve")
	SaveData.reset_all()
	_restore_save(backup)

func _test_level_queue():
	print("== level queue ==")
	LevelQueue.clear()
	_check(LevelQueue.start_index == 0 and LevelQueue.mode == "story", "clear resetea start_index/mode")
	LevelQueue.play_levels(["user://a.txt"], "P", "pack", "mi_pack")
	_check(LevelQueue.mode == "pack" and LevelQueue.pack_id == "mi_pack", "play_levels guarda modo pack + id")
	_check(LevelQueue.return_scene == "res://scenes/PacksCommunity.tscn", "pack vuelve a PacksCommunity")
	LevelQueue.play_levels(["user://a.txt"], "P", "level")
	_check(LevelQueue.return_scene == "res://scenes/EditorHub.tscn", "nivel suelto vuelve a EditorHub")
	LevelQueue.play_levels([], "Historia", "story")
	_check(LevelQueue.return_scene == "res://scenes/StoryHub.tscn", "historia vuelve a StoryHub")
	LevelQueue.clear()

func _collect_texts(col: Node) -> Array:
	var texts := []
	for ch in col.get_children():
		if ch.has_method("get_text") or ("text" in ch):
			texts.append(ch.text)
	return texts

func _test_story_hub():
	print("== story hub ==")
	var backup := _backup_save()
	SaveData.reset_all()
	var sh = StoryHubScene.instance()
	add_child(sh)
	_check(sh.buttons.size() == 3, "StoryHub con 3 botones (got %d)" % sh.buttons.size())
	_check(sh.buttons[0].text == "Nueva Partida", "botón Nueva Partida")
	_check(sh.buttons[2].text.begins_with("Volver"), "botón Volver")
	_check(sh.buttons[1].text.begins_with("Continuar"), "botón Continuar presente")
	_check(sh.buttons[1].disabled, "Continuar deshabilitado sin partida")
	_check(sh.buttons[1].focus_mode == Control.FOCUS_NONE, "Continuar sin foco (FOCUS_NONE) sin partida")
	sh.free()
	_restore_save(backup)

func _test_slot_picker():
	print("== slot picker ==")
	var backup := _backup_save()
	SaveData.reset_all()
	var sp = SlotPickerScene.instance()
	add_child(sp)
	_check(sp.slot_buttons.size() == SaveData.SLOT_COUNT, "3 zócalos visibles")
	sp.configure("story", "historia", "new")
	_check(sp.no_save_button != null, "intent=new muestra 'Sin guardado'")
	_check(sp.slot_buttons[0].text.find("Vacío") >= 0, "zócalo vacío etiquetado")
	SaveData.begin_session("story", "historia", 1, 21, 5)
	sp.configure("story", "historia", "continue")
	_check(sp.slot_buttons[1].text.find("nivel 6/21") >= 0, "continuar muestra nivel 6/21 en zócalo ocupado")
	_check(sp.slot_buttons[2].disabled, "continuar deshabilita zócalo vacío")
	_check(sp.slot_buttons[2].focus_mode == Control.FOCUS_NONE, "continuar quita foco al zócalo vacío")
	_check(sp.slot_buttons[1].focus_mode == Control.FOCUS_ALL, "zócalo ocupado es enfocable")
	SaveData.reset_all()
	_restore_save(backup)
	sp.free()

func _test_packs_community():
	print("== packs community ==")
	var pc = PacksCommunityScene.instance()
	add_child(pc)
	_check(pc.store != null, "PackCommunity crea PackStore")
	_check(pc.menu_panel != null and pc.descargados_panel != null and pc.online_panel != null, "3 paneles creados")
	_check(pc.desc_scroll != null and pc.desc_scroll is ScrollContainer, "descargados dentro de ScrollContainer")
	_check(pc.online_scroll != null and pc.online_scroll is ScrollContainer, "online dentro de ScrollContainer")
	_check(pc.menu_panel.visible, "menú visible al inicio")
	pc._on_open_descargados()
	_check(pc.descargados_panel.visible, "abrir descargados conmuta panel")
	pc._on_close_descargados()
	_check(pc.menu_panel.visible, "volver restaura menú")
	var row = pc._online_row({"id": "mi_pack", "name": "Mi Pack", "author": "alguien", "description": "desc"})
	_check(row != null and row is Control, "online_row construye la fila sin errores")
	_check(pc._focused_online_id() == "", "sin foco en la lista, _focused_online_id devuelve vacío")
	pc.online_vbox.add_child(row)
	var dl: Button = null
	for ch in row.get_children():
		if ch is Button:
			dl = ch
	if dl != null and not dl.disabled:
		dl.grab_focus()
	_check(pc._focused_online_id() == "mi_pack", "_focused_online_id detecta el pack enfocado (got '%s')" % pc._focused_online_id())
	pc.online_vbox.remove_child(row)
	pc.free()

func _test_editor_hub():
	print("== editor hub ==")
	var eh = EditorHubScene.instance()
	add_child(eh)
	eh._on_open_niveles()
	_check(eh.niveles_panel.visible, "abrir niveles propios conmuta panel")
	var wired := _count_wired(eh.niveles_vbox, eh.niveles_scroll)
	_check(wired > 0, "botones conectados a ensure_control_visible (got %d)" % wired)
	_check(eh.niveles_scroll.get("follow_focus") == true, "niveles_scroll sigue al foco")
	eh._on_close_niveles()
	eh._on_open_packs()
	_check(eh.packs_panel.visible, "abrir packs propios conmuta panel")
	eh._on_close_packs()
	_check(eh.hub_panel.visible, "volver restaura hub")
	eh.free()

func _test_navigation():
	print("== navigation ==")
	NavParams.clear()
	NavParams.pending_picker = ["pack", "mi_pack", "new"]
	var sp = SlotPickerScene.instance()
	get_tree().root.add_child(sp)
	_check(sp.game_mode == "pack" and sp.game_id == "mi_pack", "SlotPicker consume NavParams (got %s/%s)" % [sp.game_mode, sp.game_id])
	_check(sp.sub_label != null and sp.sub_label.text.find("mi_pack") >= 0, "subtítulo muestra el pack (got '%s')" % str(sp.sub_label.text if sp.sub_label else ""))
	_check(sp.no_save_button != null and sp.no_save_button.visible, "intent new muestra 'Sin guardado'")
	_check(NavParams.pending_picker.size() == 0, "NavParams consumido")
	sp.free()

	NavParams.open_file = "user://tumbleboy_levels/smoke_pack_level.txt"
	var ed = EditorScene.instance()
	get_tree().root.add_child(ed)
	_check(NavParams.open_file == "", "NavParams.open_file consumido en _ready")
	yield(get_tree(), "idle_frame")
	_check(ed.current_file == "user://tumbleboy_levels/smoke_pack_level.txt", "editor abre el archivo pedido (got '%s')" % str(ed.current_file))
	ed.free()
	NavParams.clear()

func _test_main_menu():
	print("== main menu ==")
	var mm = MainMenuScene.instance()
	add_child(mm)
	var col: VBoxContainer = null
	for ch in mm.get_children():
		if ch is CenterContainer:
			for ch2 in ch.get_children():
				if ch2 is VBoxContainer:
					col = ch2
					break
	_check(col != null, "menú tiene VBoxContainer dentro de CenterContainer")
	var texts := []
	var has_icon := false
	if col != null:
		for ch in col.get_children():
			if ch is TextureRect:
				has_icon = true
			if ch.has_method("get_text") or ("text" in ch):
				texts.append(ch.text)
	_check(has_icon, "menú tiene icono (TextureRect) arriba")
	_check(texts.has("TUMBLEBOY REBORN"), "título TumbleBoy presente")
	_check(texts.has("Modo historia"), "botón Modo historia presente")
	_check(texts.has("Packs comunitarios"), "botón Packs comunitarios presente")
	_check(texts.has("Editor de niveles"), "botón Editor de niveles presente")
	_check(texts.has("Créditos"), "botón Créditos presente")
	_check(texts.has("Salir"), "botón Salir presente")
	_check(texts.size() == 8, "8 textos: título+subtítulo+5 botones+hint (got %d)" % texts.size())
	_check(ProjectSettings.get_setting("application/config/name") == "TumbleBoy Reborn", "nombre del proyecto = TumbleBoy Reborn")
	mm.free()

func _test_credits():
	print("== credits ==")
	var cr = CreditsScene.instance()
	add_child(cr)
	for expected in ["CRÉDITOS", "Aleperix", "XO Galaxy", "Tom Corbet", "Chris Jackson", "Eben Myers", "Bob Rost", "Gummi", "SugarLabs"]:
		_check(_find_text(cr, expected), "créditos muestran '%s'" % expected)
	var bb = _back_button_of(cr)
	_check(bb != null, "créditos tienen botón Volver")
	if bb != null:
		_check(bb.text.find("Volver") >= 0, "botón de regreso etiquetado")
	cr.free()

func _test_play_button_toggle():
	print("== play button toggle ==")
	var ed = EditorScene.instance()
	add_child(ed)
	_check(ed.play_button != null, "play_button existe")
	_check(ed.play_button.text == "Probar", "botón inicia como 'Probar'")
	ed._select_paint(C.BLOCK_START)
	ed._paint_cell(1, 1, false)
	ed._enter_play()
	_check(ed.play_button.text == "Parar", "tras _enter_play cambia a 'Parar'")
	ed._exit_play()
	_check(ed.play_button.text == "Probar", "tras _exit_play vuelve a 'Probar'")
	ed._new_board()
	_check(ed.play_button.text == "Probar", "tras _new_board es 'Probar'")
	ed.free()

func _test_save_validation():
	print("== save validation ==")
	var ed = EditorScene.instance()
	add_child(ed)
	ed.name_edit.text = ""
	ed.author_edit.text = ""
	ed.desc_edit.text = ""
	ed._on_save()
	_check(ed.status_label.text.find("nombre") >= 0, "guardar sin nombre avisa (got '%s')" % ed.status_label.text)
	ed.name_edit.text = "Nivel"
	ed._on_save()
	_check(ed.status_label.text.find("autor") >= 0, "guardar sin autor avisa (got '%s')" % ed.status_label.text)
	ed.author_edit.text = "Autor"
	ed._on_save()
	_check(ed.status_label.text.find("descripción") >= 0, "guardar sin descripción avisa (got '%s')" % ed.status_label.text)
	ed.desc_edit.text = "Desc"
	ed._save_to("user://tumbleboy_levels/smoke_validation.txt")
	_check(File.new().file_exists("user://tumbleboy_levels/smoke_validation.txt"), "guardar con campos completos funciona")
	Directory.new().remove("user://tumbleboy_levels/smoke_validation.txt")
	ed.free()

func _test_editor_draft_load():
	print("== editor draft load ==")
	var backup := _backup_save()
	SaveData.reset_all()
	SaveData.save_draft({
		"map": [[1, 2], [3, 4]],
		"attributes": { "theme": "beach", "boy": "boy2", "name": "Borrador", "author": "A", "instructions": "I" },
		"current_file": "",
		"read_only": false,
		"updated": 1
	})
	NavParams.clear()
	NavParams.open_draft = true
	var ed = EditorScene.instance()
	add_child(ed)
	_check(ed.map.size() == 2 and ed.map[0].size() == 2, "editor carga el mapa del borrador en _ready")
	_check(ed.attributes.get("theme") == "beach", "tema del borrador cargado")
	_check(ed.name_edit.text == "Borrador", "nombre del borrador en el campo (got '%s')" % ed.name_edit.text)
	_check(ed.author_edit.text == "A", "autor del borrador en el campo")
	_check(ed.desc_edit.text == "I", "descripción del borrador en el campo")
	_check(ed.theme_option.get_selected_id() == ed.THEMES.find("beach"), "tema seleccionado en OptionButton")
	_check(not NavParams.open_draft, "NavParams.open_draft consumido")
	_check(not ed._draft_dirty, "cargar borrador no deja dirty")
	ed.free()
	SaveData.reset_all()
	_restore_save(backup)

func _test_thumbnail_zip():
	print("== thumbnail zip ==")
	var img := Image.new()
	img.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 0, 0))
	var png_bytes := img.save_png_to_buffer()
	var files := {
		"manifest.json": "{\"name\": \"ThumbTest\"}",
		"levels/a.txt": ".name {A}\n!!!\n---- \n!!!\n",
		"thumbnail.png": png_bytes,
	}
	var zp := "user://smoke_thumb.zip"
	Directory.new().remove(zp)
	_check(ZipWriter.write_pack_zip(zp, files), "ZIP con thumbnail se crea")
	var names = ZipReader.get_files(zp)
	_check(names.has("thumbnail.png"), "thumbnail.png está en el ZIP")
	var thumb_data = ZipReader.read_file(zp, "thumbnail.png")
	_check(thumb_data != null and thumb_data.size() > 0, "thumbnail.png tiene contenido")
	var loaded_img := Image.new()
	_check(loaded_img.load_png_from_buffer(thumb_data) == OK, "thumbnail.png se carga como PNG")
	var tex = PackReader.get_thumbnail_texture(zp)
	_check(tex != null, "get_thumbnail_texture retorna textura")
	Directory.new().remove(zp)

func _test_draft_roundtrip():
	print("== draft roundtrip ==")
	var backup := _backup_save()
	SaveData.reset_all()
	_check(not SaveData.has_draft(), "sin borrador al inicio")
	SaveData.save_draft({ "map": [[1, 2]], "attributes": { "theme": "desert" }, "current_file": "", "read_only": false, "updated": 123 })
	_check(SaveData.has_draft(), "has_draft tras save_draft")
	var d: Dictionary = SaveData.get_draft()
	_check(d.get("map", []).size() == 1, "draft.map保存")
	_check(d.get("attributes", {}).get("theme") == "desert", "draft.attributes保存")
	SaveData.clear_draft()
	_check(not SaveData.has_draft(), "clear_draft elimina el borrador")
	SaveData.save_draft({ "map": [[3]], "attributes": {}, "current_file": "", "read_only": false, "updated": 456 })
	SaveData.reset_all()
	_check(not SaveData.has_draft(), "reset_all limpia borrador")
	_restore_save(backup)

func _test_nav_params_draft():
	print("== nav params draft ==")
	NavParams.clear()
	_check(not NavParams.open_draft, "open_draft false al inicio")
	NavParams.open_draft = true
	_check(NavParams.open_draft, "open_draft se puede activar")
	NavParams.clear()
	_check(not NavParams.open_draft, "clear resetea open_draft")

func _test_hub_draft_section():
	print("== hub draft section ==")
	var backup := _backup_save()
	SaveData.reset_all()
	var eh = EditorHubScene.instance()
	add_child(eh)
	eh._on_open_niveles()
	_check(eh.niveles_panel.visible, "abre niveles sin draft: sin sección borrador")
	var no_borrador := true
	for ch in eh.niveles_vbox.get_children():
		if ch is Label and ch.text == "Borrador":
			no_borrador = false
	_check(no_borrador, "no aparece 'Borrador' cuando no hay draft")
	SaveData.save_draft({ "map": [[1]], "attributes": {}, "current_file": "", "read_only": false, "updated": 1 })
	eh._refresh_niveles()
	var found_borrador := false
	for ch in eh.niveles_vbox.get_children():
		if ch is Label and ch.text == "Borrador":
			found_borrador = true
	_check(found_borrador, "aparece 'Borrador' cuando hay draft")
	eh._on_close_niveles()
	eh.free()
	SaveData.reset_all()
	_restore_save(backup)

func _test_descargados_buttons():
	print("== descargados buttons ==")
	var pc = PacksCommunityScene.instance()
	add_child(pc)
	_check(pc.uninstall_dialog == null, "uninstall_dialog se crea bajo demanda")
	pc.free()

func _test_propios_buttons():
	print("== propios buttons ==")
	var eh = EditorHubScene.instance()
	add_child(eh)
	_check(eh.delete_dialog == null, "delete_dialog se crea bajo demanda")
	eh.free()

func _wait_scroll_height(scroll: ScrollContainer) -> float:
	for i in range(5):
		yield(get_tree(), "idle_frame")
		if scroll.get_size().y > 0.0:
			return scroll.get_size().y
	return scroll.get_size().y

func _test_list_layout():
	print("== list layout: scroll con altura visible ==")
	var pc = PacksCommunityScene.instance()
	add_child(pc)
	pc.rect_min_size = Vector2(1200, 825)
	pc._on_open_descargados()
	var dh = yield(_wait_scroll_height(pc.desc_scroll), "completed")
	_check(dh > 0.0, "desc_scroll con altura (got %.1f)" % dh)
	_check(_col_centered(pc.desc_col), "columna descargados centrada (x=%.0f)" % pc.desc_col.get_global_rect().position.x)
	pc._on_close_descargados()
	pc._on_open_online()
	var oh = yield(_wait_scroll_height(pc.online_scroll), "completed")
	_check(oh > 0.0, "online_scroll con altura (got %.1f)" % oh)
	_check(pc.online_vbox.get_child_count() > 0, "online_vbox con filas (got %d)" % pc.online_vbox.get_child_count())
	_check(_col_centered(pc.online_col), "columna online centrada (x=%.0f)" % pc.online_col.get_global_rect().position.x)
	pc.free()

	var eh = EditorHubScene.instance()
	add_child(eh)
	eh.rect_min_size = Vector2(1200, 825)
	eh._on_open_niveles()
	var nh = yield(_wait_scroll_height(eh.niveles_scroll), "completed")
	_check(nh > 0.0, "niveles_scroll con altura (got %.1f)" % nh)
	_check(_col_centered(eh.niveles_col), "columna niveles propios centrada (x=%.0f)" % eh.niveles_col.get_global_rect().position.x)
	eh._on_close_niveles()
	eh._on_open_packs()
	var ph = yield(_wait_scroll_height(eh.packs_scroll), "completed")
	_check(ph > 0.0, "packs_scroll con altura (got %.1f)" % ph)
	_check(_col_centered(eh.packs_col), "columna packs propios centrada (x=%.0f)" % eh.packs_col.get_global_rect().position.x)
	eh.free()

func _col_centered(col: Control) -> bool:
	if col == null or col.get_parent() == null:
		return false
	var parent: Control = col.get_parent()
	var target: float = (parent.get_size().x - col.get_size().x) * 0.5
	return abs(col.get_global_rect().position.x - target) < 2.0

func _test_focus_reentry():
	print("== focus re-entry ==")
	var pc = PacksCommunityScene.instance()
	add_child(pc)
	pc.rect_min_size = Vector2(1200, 825)
	pc._on_open_descargados()
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	var dfo = pc.get_focus_owner()
	_check(dfo != null and dfo.is_inside_tree(), "foco vivo al entrar en descargados")
	pc._on_close_descargados()
	pc._on_open_descargados()
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	dfo = pc.get_focus_owner()
	_check(dfo != null and dfo.is_inside_tree(), "foco vivo al re-entrar en descargados")
	pc.free()

	var eh = EditorHubScene.instance()
	add_child(eh)
	eh.rect_min_size = Vector2(1200, 825)
	eh._on_open_niveles()
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	var nfo = eh.get_focus_owner()
	_check(nfo != null and nfo.is_inside_tree(), "foco vivo al entrar en niveles")
	eh._on_close_niveles()
	eh._on_open_niveles()
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	nfo = eh.get_focus_owner()
	_check(nfo != null and nfo.is_inside_tree(), "foco vivo al re-entrar en niveles")
	eh._on_close_niveles()
	eh._on_open_packs()
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	var pfo = eh.get_focus_owner()
	_check(pfo != null and pfo.is_inside_tree(), "foco vivo al entrar en packs")
	eh._on_close_packs()
	eh._on_open_packs()
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	pfo = eh.get_focus_owner()
	_check(pfo != null and pfo.is_inside_tree(), "foco vivo al re-entrar en packs")
	eh.free()

func _test_game_icon():
	print("== game icon ==")
	var icon_path: String = ProjectSettings.get_setting("application/config/icon")
	_check(icon_path == "res://assets/tumbleboy/icon.png", "icono del proyecto = assets/tumbleboy/icon.png (got '%s')" % icon_path)
	_check(File.new().file_exists(icon_path), "archivo de icono existe")

func _test_pack_row():
	print("== pack_row ==")
	var p := { "name": "TestPack", "author": "Tester" }
	var row = PackRow.make(p, null, [])
	_check(row is HBoxContainer, "pack_row retorna HBoxContainer")
	_check(row.get_child_count() == 2, "pack_row sin botones: preview + info (got %d)" % row.get_child_count())
	var info_box: Control = row.get_child(1)
	_check(info_box is VBoxContainer and info_box.rect_min_size.x == 400, "info fija de 400px (got %s)" % str(info_box.rect_min_size))
	var preview: Control = row.get_child(0)
	_check(preview is TextureRect and preview.rect_min_size == Vector2(64, 64), "miniatura de 64px")
	_check(info_box.get_child(0).text == "TestPack  —  Tester", "nombre — autor en una línea (got '%s')" % info_box.get_child(0).text)
	var play_btn := Button.new()
	play_btn.text = "Jugar"
	var del_btn := Button.new()
	del_btn.text = "Eliminar"
	var row2 = PackRow.make(p, null, [play_btn, del_btn])
	_check(row2.get_child_count() == 4, "pack_row con 2 botones: preview + info + 2 btns (got %d)" % row2.get_child_count())
	_check(play_btn.rect_min_size == Vector2(120, 36), "botones de acción a 120x36")
	var pdesc := { "name": "ConDesc", "author": "A", "description": "algo" }
	var row3 = PackRow.make(pdesc, null, [])
	_check(row3.get_child(1).get_child_count() == 2, "con descripción: info con 2 líneas (got %d)" % row3.get_child(1).get_child_count())

func _test_editor_ui_mode():
	print("== editor ui mode ==")
	var ed = EditorScene.instance()
	add_child(ed)
	_check(not ed.ui_mode, "editor inicia en modo pintura")
	_check(ed.play_button.focus_mode == Control.FOCUS_NONE, "toolbar sin foco en modo pintura")
	_check(ed.ui_controls.size() >= 24, "ui_controls recoge toolbar + paleta (got %d)" % ed.ui_controls.size())
	ed._toggle_ui_mode()
	_check(ed.ui_mode, "toggle activa modo foco UI")
	_check(ed.play_button.focus_mode == Control.FOCUS_ALL, "toolbar con foco en modo UI")
	_check(ed.play_button.has_focus(), "play_button toma el foco al entrar en modo UI")
	var all_focusable := true
	for c in ed.ui_controls:
		if c.focus_mode != Control.FOCUS_ALL:
			all_focusable = false
	_check(all_focusable, "todos los controles de UI enfocables en modo UI")
	ed._toggle_ui_mode()
	_check(not ed.ui_mode, "toggle vuelve a modo pintura")
	_check(ed.play_button.focus_mode == Control.FOCUS_NONE, "toolbar sin foco al salir de modo UI")

	ed.cursor_cell = Vector2(3, 3)
	_check(not ed._try_ui_edge(Vector2(0, -1), Vector2(3, 3)), "desde el medio del grid no salta a UI")
	ed.cursor_cell = Vector2(3, 0)
	_check(ed._try_ui_edge(Vector2(0, -1), Vector2(3, 0)) and ed.ui_mode, "arriba en el tope salta a modo foco UI (toolbar)")
	_check(ed.ui_controls[0].has_focus(), "el foco cae en la toolbar al entrar desde arriba")
	ed._toggle_ui_mode()
	_check(not ed.ui_mode, "vuelve a modo pintura tras el salto de arriba")
	var bottom := Vector2(3, ed._visible_max_cell().y)
	ed.cursor_cell = bottom
	_check(ed._try_ui_edge(Vector2(0, 1), bottom) and ed.ui_mode, "abajo en el borde salta a modo foco UI (paleta)")
	ed._toggle_ui_mode()
	_check(not ed.ui_mode, "vuelve a modo pintura tras el salto de abajo")
	ed._toggle_ui_mode()
	ed._exit_ui_focus()
	_check(not ed.ui_mode, "exit_ui_focus vuelve al tablero")
	_check(ed.ui_controls[0].focus_neighbour_right == ed.ui_controls[1].get_path(), "toolbar cableada: Nuevo → Abrir")
	_check(ed.ui_controls[1].focus_neighbour_left == ed.ui_controls[0].get_path(), "toolbar cableada: Abrir → Nuevo")
	_check(ed.ui_fields.size() == 5, "ui_fields recoge los 5 campos editables (got %d)" % ed.ui_fields.size())
	_check(ed.name_edit.focus_neighbour_right == ed.author_edit.get_path(), "fila 2 cableada: nombre → autor")
	_check(ed.theme_option.focus_neighbour_left == ed.author_edit.get_path(), "fila 2 cableada: autor → tema")
	_check(ed.name_edit.focus_neighbour_top == ed.ui_controls[0].get_path(), "fila 1 → fila 2: nombre sube a Nuevo")
	_check(ed.ui_controls[0].focus_neighbour_bottom == ed.name_edit.get_path(), "fila 2 → fila 1: Nuevo baja a nombre")
	_check(ed.desc_edit.focus_neighbour_top == ed.name_edit.get_path(), "fila 3 → fila 2: descripción sube a nombre")
	_check(ed.name_edit.focus_neighbour_bottom == ed.desc_edit.get_path(), "fila 2 → fila 3: nombre baja a descripción")
	var first_palette: Control = ed.ui_controls[ed.toolbar_controls.size()]
	_check(first_palette.focus_neighbour_top == ed.desc_edit.get_path(), "paleta → fila 3: primer bloque sube a descripción")
	_check(ed.desc_edit.focus_neighbour_bottom == first_palette.get_path(), "fila 3 → paleta: descripción baja al primer bloque")
	ed.free()

func _test_focus_nav():
	print("== focus nav ==")
	var root := VBoxContainer.new()
	var btn := Button.new()
	btn.text = "Uno"
	var b2 := Button.new()
	b2.text = "Dos"
	root.add_child(btn)
	root.add_child(b2)
	add_child(root)
	FocusNav.set_skippable(b2, true)
	_check(b2.disabled and b2.focus_mode == Control.FOCUS_NONE, "set_skippable deshabilita y quita foco")
	FocusNav.set_skippable(b2, false)
	_check(not b2.disabled and b2.focus_mode == Control.FOCUS_ALL, "set_skippable reactiva y restaura foco")
	var grabbed := FocusNav.grab_first(root)
	_check(grabbed and btn.has_focus(), "grab_first enfoca el primer botón habilitado")
	_check(not FocusNav.popup_open(root), "popup_open falso sin popups")
	var dlg := ConfirmationDialog.new()
	root.add_child(dlg)
	dlg.popup_centered()
	_check(FocusNav.popup_open(root), "popup_open detecta popup abierto")
	dlg.hide()
	dlg.free()
	root.free()

func _test_settings():
	print("== settings ==")
	var backup := _backup_save()
	SaveData.reset_all()
	_check(SaveData.get_setting("control_mode", 0) == InputManager.ControlMode.TOUCH, "control_mode por defecto = TOUCH")
	SaveData.set_setting("control_mode", InputManager.ControlMode.TILT)
	_check(SaveData.get_setting("control_mode", 0) == InputManager.ControlMode.TILT, "set_setting guarda el valor")
	InputManager.set_control_mode(InputManager.ControlMode.TILT)
	_check(InputManager.control_mode == InputManager.ControlMode.TILT, "set_control_mode cambia el modo")
	_check(SaveData.get_setting("control_mode", 0) == InputManager.ControlMode.TILT, "set_control_mode persiste en settings")
	_restore_save(backup)
	InputManager.control_mode = SaveData.get_setting("control_mode", InputManager.ControlMode.TOUCH)

func _test_touch_controls():
	print("== touch controls ==")
	var backup := _backup_save()
	var tc = preload("res://scripts/ui/touch_controls.gd").new()
	add_child(tc)
	tc.visible = true
	tc._recalculate_positions()
	_check(tc.joystick_center.y > 0.0, "joystick posicionado según viewport")
	_check(tc.joystick_visible, "joystick visible por defecto")
	_check(tc.toggle_radius == tc.joystick_radius, "botón derecho del mismo tamaño que el análogo")
	_check(tc.toggle_center.x > tc.joystick_center.x, "toggle colocado a la derecha")
	var touch := InputEventScreenTouch.new()
	touch.index = 5
	touch.pressed = true
	touch.position = tc.joystick_center + Vector2(30, 0)
	tc._input(touch)
	_check(tc.joystick_active and tc.joystick_touch_id == 5, "touch inicia el joystick")
	_check(InputManager.virtual_move.x > 0.0, "knob actualiza virtual_move")
	var drag := InputEventScreenDrag.new()
	drag.index = 5
	drag.position = tc.joystick_center + Vector2(60, 0)
	tc._input(drag)
	_check(abs(InputManager.virtual_move.x - 1.0) < 0.01, "drag al borde satura virtual_move")
	var up := InputEventScreenTouch.new()
	up.index = 5
	up.pressed = false
	up.position = Vector2(2000, 2000)
	tc._input(up)
	_check(not tc.joystick_active and InputManager.virtual_move == Vector2.ZERO, "release por índice suelta el joystick fuera del radio")
	_check(tc.knob_offset == Vector2.ZERO, "release devuelve el knob al centro")
	InputManager.virtual_move = Vector2.ZERO
	tc._toggle_control_mode()
	_check(InputManager.control_mode == InputManager.ControlMode.TILT, "toggle pasa a acelerómetro (control_mode)")
	_check(tc.joystick_visible == (not InputManager.is_tilt_mode()), "joystick oculto solo en modo acelerómetro real")
	InputManager.set_control_mode(InputManager.ControlMode.TOUCH)
	_check(InputManager.control_mode == InputManager.ControlMode.TOUCH, "toggle vuelve a mando (control_mode)")
	_check(tc.joystick_visible, "en modo mando se muestra el joystick")
	tc.free()
	_restore_save(backup)
	InputManager.control_mode = SaveData.get_setting("control_mode", InputManager.ControlMode.TOUCH)

func _test_mobile_detection():
	print("== mobile detection ==")
	_check(InputManager.is_mobile() == ("--force-touch" in OS.get_cmdline_args()), "is_mobile en desktop solo con --force-touch")
	var ed = EditorScene.instance()
	add_child(ed)
	_check(ed.touch_controls != null, "el editor crea touch_controls")
	_check(not ed.touch_controls.visible, "touch_controls oculto en edición (desktop)")
	ed._select_paint(C.BLOCK_START)
	ed._paint_cell(1, 1, false)
	ed._enter_play()
	_check(ed.play_mode, "editor en play_mode")
	_check(not ed.touch_controls.visible, "touch_controls oculto en play_mode desktop (is_mobile=false)")
	ed._exit_play()
	_check(not ed.play_mode, "editor fuera de play_mode")
	_check(not ed.touch_controls.visible, "touch_controls oculto tras salir de play_mode")
	ed.free()

func _find_text(root: Node, needle: String) -> bool:
	for ch in root.get_children():
		if ("text" in ch) and String(ch.text).find(needle) >= 0:
			return true
		if _find_text(ch, needle):
			return true
	return false

func _count_wired(root: Node, scroll: ScrollContainer) -> int:
	var count := 0
	for ch in root.get_children():
		if ch is Button and ch.is_connected("focus_entered", scroll, "ensure_control_visible"):
			count += 1
		count += _count_wired(ch, scroll)
	return count

func _back_button_of(root: Node) -> Control:
	for ch in root.get_children():
		if ch is Button:
			return ch
		var found := _back_button_of(ch)
		if found != null:
			return found
	return null

func _test_focus():
	print("== focus ==")
	var navs := []
	var mm = MainMenuScene.instance()
	get_tree().root.add_child(mm)
	_check(mm.get_focus_owner() != null, "MainMenu toma el foco al arrancar")
	navs.append(mm)
	var sp = SlotPickerScene.instance()
	get_tree().root.add_child(sp)
	_check(sp.get_focus_owner() != null, "SlotPicker toma el foco al arrancar")
	_check(sp.get_focus_owner() is Button, "foco inicial del SlotPicker en un botón")
	navs.append(sp)
	var pc = PacksCommunityScene.instance()
	get_tree().root.add_child(pc)
	_check(pc.get_focus_owner() != null, "PacksCommunity toma el foco al arrancar")
	navs.append(pc)
	var eh = EditorHubScene.instance()
	get_tree().root.add_child(eh)
	_check(eh.get_focus_owner() != null, "EditorHub toma el foco al arrancar")
	navs.append(eh)
	var cr = CreditsScene.instance()
	get_tree().root.add_child(cr)
	_check(cr.get_focus_owner() != null, "Credits toma el foco al arrancar")
	navs.append(cr)
	for n in navs:
		n.free()
	NavParams.clear()
