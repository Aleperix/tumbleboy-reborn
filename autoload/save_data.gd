extends Node
# SaveData — zócalos de memoria persistentes en user://save_slots.json
# 3 zócalos por modo (historia, y cada pack individual). Niveles sueltos sin guardado.

const SAVE_PATH := "user://save_slots.json"
const SLOT_COUNT := 3
const SAVE_VERSION := 2

var games: Dictionary = {}
var active_slot: int = -1
var active_key: String = ""
var downloaded_packs: Array = []
var draft: Dictionary = {}
var settings: Dictionary = {}

func _init():
	_load()

func _load():
	var file := File.new()
	if file.file_exists(SAVE_PATH):
		if file.open(SAVE_PATH, File.READ) == OK:
			var parsed = parse_json(file.get_as_text())
			if parsed is Dictionary:
				if parsed.has("games"):
					games = parsed["games"]
				if parsed.has("downloaded_packs"):
					downloaded_packs = parsed["downloaded_packs"]
				if parsed.has("draft"):
					draft = parsed["draft"]
					if not draft is Dictionary:
						draft = {}
				if parsed.has("settings"):
					settings = parsed["settings"]
					if not settings is Dictionary:
						settings = {}
			file.close()

func _save():
	var file := File.new()
	if file.open(SAVE_PATH, File.WRITE) == OK:
		file.store_string(JSON.print({ "version": SAVE_VERSION, "games": games, "downloaded_packs": downloaded_packs, "draft": draft, "settings": settings }))
		file.close()

# --- Ajustes ---

func get_setting(key: String, default = null):
	return settings.get(key, default)

func set_setting(key: String, value):
	settings[key] = value
	_save()

# --- Zócalos ---

func _ensure_game(key: String):
	if not games.has(key):
		var arr := []
		arr.resize(SLOT_COUNT)
		for i in SLOT_COUNT:
			arr[i] = null
		games[key] = arr

func get_slot(key: String, index: int) -> Dictionary:
	_ensure_game(key)
	if index >= 0 and index < SLOT_COUNT:
		var s = games[key][index]
		if s is Dictionary:
			return s
	return {}

func has_save(key: String, index: int) -> bool:
	_ensure_game(key)
	if index >= 0 and index < SLOT_COUNT:
		return games[key][index] is Dictionary
	return false

func set_slot(key: String, index: int, data):
	_ensure_game(key)
	if index >= 0 and index < SLOT_COUNT:
		games[key][index] = data
		_save()

func clear_slot(key: String, index: int):
	set_slot(key, index, null)

func get_slot_info(key: String, index: int) -> Dictionary:
	var s = get_slot(key, index)
	if s.empty():
		return {}
	return s

func has_any_save(key: String) -> bool:
	_ensure_game(key)
	for i in SLOT_COUNT:
		if has_save(key, i):
			return true
	return false

func count_saves(key: String) -> int:
	_ensure_game(key)
	var n := 0
	for i in SLOT_COUNT:
		if has_save(key, i):
			n += 1
	return n

# --- Sesión activa (se llama desde los hubs/picker al iniciar) ---

func begin_session(mode: String, id: String, slot: int, total: int, completed: int = 0):
	active_slot = slot
	active_key = _make_key(mode, id)
	set_slot(active_key, slot, {
		"mode": mode,
		"id": id,
		"completed": completed,
		"total": total,
		"updated": OS.get_unix_time()
	})

func begin_session_quick(mode: String, id: String, total: int):
	active_slot = -1
	active_key = ""

func record_progress(completed: int):
	if active_slot < 0 or active_key == "":
		return
	var s = get_slot(active_key, active_slot)
	if s.empty():
		return
	s["completed"] = completed
	s["updated"] = OS.get_unix_time()
	set_slot(active_key, active_slot, s)

func end_session():
	active_slot = -1
	active_key = ""

# --- Packs descargados ---

func mark_pack_downloaded(id: String):
	if not downloaded_packs.has(id):
		downloaded_packs.append(id)
		_save()

func is_pack_downloaded(id: String) -> bool:
	return downloaded_packs.has(id)

func is_pack_local(id: String) -> bool:
	return not downloaded_packs.has(id)

func clear_pack(id: String):
	downloaded_packs.erase(id)
	games.erase("pack:" + id)
	_save()

# --- Borrador del editor ---

func has_draft() -> bool:
	return draft.size() > 0

func get_draft() -> Dictionary:
	return draft

func save_draft(data: Dictionary):
	draft = data
	_save()

func clear_draft():
	draft = {}
	_save()

# --- Utilidades ---

func _make_key(mode: String, id: String) -> String:
	if mode == "pack":
		return "pack:" + id
	return mode

func get_game_key(mode: String, id: String) -> String:
	return _make_key(mode, id)

func reset_all():
	games = {}
	downloaded_packs = []
	draft = {}
	settings = {}
	active_slot = -1
	active_key = ""
	_save()
