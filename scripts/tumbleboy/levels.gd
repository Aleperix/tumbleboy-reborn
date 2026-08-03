extends Reference
# Levels — parser del formato de niveles .txt (port de LevelMaps.py)

const C = preload("res://scripts/tumbleboy/tb_constants.gd")

const MAP_TILES := {
	" ": C.BLOCK_NONE,
	"-": C.BLOCK_FLOOR,
	"=": C.BLOCK_FLOOR2,
	"+": C.BLOCK_FLOOR3,
	"#": C.BLOCK_WALL,
	"w": C.BLOCK_WALL2,
	"W": C.BLOCK_WALL3,
	"%": C.BLOCK_DOUBLEWALL,
	"d": C.BLOCK_DOUBLEWALL2,
	"D": C.BLOCK_DOUBLEWALL3,
	"$": C.BLOCK_START,
	"1": C.BLOCK_GOAL,
	"<": C.BLOCK_RAMP_RIGHT,
	">": C.BLOCK_RAMP_LEFT,
	"v": C.BLOCK_RAMP_UP,
	"^": C.BLOCK_RAMP_DOWN,
	"@": C.BLOCK_BUMPER,
}

# Devuelve { "attributes": {...}, "map": [ [int, ...], ... ] }
static func parse_level(level_file: String) -> Dictionary:
	var f := File.new()
	if not f.file_exists(level_file):
		return { "attributes": {}, "map": [] }
	f.open(level_file, File.READ)
	var attributes := {}
	var level_map: Array = []
	var in_level := false
	while not f.eof_reached():
		var line: String = f.get_line()
		if in_level:
			if line.begins_with("!!!"):
				in_level = false
			else:
				if line.length() > 0:
					var row: Array = []
					for i in range(line.length() - 1):
						var ch := line[i]
						if MAP_TILES.has(ch):
							row.append(MAP_TILES[ch])
						else:
							row.append(C.BLOCK_NONE)
					level_map.append(row)
		else:
			if line.begins_with("."):
				var attr = _parse_attribute(line)
				if attr != null:
					attributes[attr[0]] = attr[1]
			if line.begins_with("!!!"):
				in_level = true
	f.close()
	return { "attributes": attributes, "map": level_map }

static func _parse_attribute(line: String):
	var wordend := line.find(" ")
	var bracketstart := line.find("{")
	var bracketend := line.find("}")
	if bracketstart == -1:
		return null
	if bracketend == -1:
		bracketend = line.length()
	if wordend == -1 or bracketstart < wordend:
		wordend = bracketstart
	var name := line.substr(1, wordend - 1)
	var data := line.substr(bracketstart + 1, bracketend - bracketstart - 1)
	return [name, data]
