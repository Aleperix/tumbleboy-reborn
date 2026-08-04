extends Node2D
# Test de packs — valida que los packs de res://packs/ se leen con el
# PackReader del juego y que cada nivel es jugable (1 inicio, >=1 meta,
# meta alcanzable desde el inicio por BFS sobre suelo/rampas/bumpers).
# Uso: godot3 --headless --path . res://tests/PackLevelsTest.tscn

const PackReader = preload("res://scripts/tumbleboy/pack_reader.gd")
const Levels = preload("res://scripts/tumbleboy/levels.gd")
const C = preload("res://scripts/tumbleboy/tb_constants.gd")

var failures := 0
var checks := 0

func _ready():
	_test_pack("res://packs/numeros.zip")
	_test_pack("res://packs/letras.zip")
	if failures == 0:
		print("PACK LEVELS TEST: ALL PASS (%d checks)" % checks)
	else:
		printerr("PACK LEVELS TEST: %d FAILURES" % failures)
	get_tree().quit(failures)

func _ok(cond: bool, msg: String):
	checks += 1
	if not cond:
		failures += 1
		printerr("FAIL: " + msg)

func _test_pack(zip: String):
	var manifest = PackReader.read_manifest(zip)
	_ok(manifest != null, "manifest de " + zip)
	_ok(manifest.get("name", "") != "", "nombre del pack " + zip)
	var levels := PackReader.list_level_filenames(zip)
	_ok(levels.size() > 0, "niveles en " + zip)
	for l in levels:
		var text := PackReader.get_level_text(zip, l)
		_ok(text.length() > 0, "nivel no vacío: " + l)
		var parsed := Levels.parse_level_text(text)
		var map: Array = parsed["map"]
		_ok(map.size() > 0, "mapa no vacío: " + l)
		_check_map(map, l)
	var thumb = PackReader.get_thumbnail_texture(zip)
	_ok(thumb != null, "thumbnail.png decodificable en " + zip)

func _check_map(map: Array, label: String):
	if map.size() == 0:
		return
	var width := -1
	var start := Vector2(-1, -1)
	var goals := []
	for y in range(map.size()):
		var row = map[y]
		if width == -1:
			width = row.size()
		elif row.size() != width:
			_ok(false, "filas de distinta anchura: " + label)
		for x in range(row.size()):
			var b: int = row[x]
			if b == C.BLOCK_START:
				start = Vector2(x, y)
			elif b >= C.BLOCK_GOAL and b <= C.BLOCK_GOAL + 8:
				goals.append(Vector2(x, y))
	_ok(width > 0, "anchura > 0: " + label)
	_ok(start.x >= 0, "1 inicio ($): " + label)
	_ok(goals.size() >= 1, ">=1 meta: " + label)
	if start.x < 0 or goals.size() == 0:
		return
	_ok(_goal_reachable(map, start, goals), "meta alcanzable: " + label)

func _goal_reachable(map: Array, start: Vector2, goals: Array) -> bool:
	var h := map.size()
	var w: int = (map[0] as Array).size()
	var seen := {}
	var queue := [start]
	seen[int(start.x + start.y * w)] = true
	var passable := {
		C.BLOCK_FLOOR: true, C.BLOCK_FLOOR2: true, C.BLOCK_FLOOR3: true,
		C.BLOCK_START: true, C.BLOCK_GOAL: true,
		C.BLOCK_RAMP_RIGHT: true, C.BLOCK_RAMP_LEFT: true,
		C.BLOCK_RAMP_UP: true, C.BLOCK_RAMP_DOWN: true, C.BLOCK_BUMPER: true,
	}
	while queue.size() > 0:
		var cur = queue.pop_front()
		for goal in goals:
			if cur == goal:
				return true
		var dirs := [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]
		for d in dirs:
			var n = cur + d
			if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h:
				continue
			if seen.has(int(n.x + n.y * w)):
				continue
			var b = map[int(n.y)][int(n.x)]
			if passable.has(b):
				seen[int(n.x + n.y * w)] = true
				queue.append(n)
	return false
