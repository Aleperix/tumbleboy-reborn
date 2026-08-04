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
	"2": C.BLOCK_GOAL,
	"3": C.BLOCK_GOAL,
	"4": C.BLOCK_GOAL,
	"5": C.BLOCK_GOAL,
	"6": C.BLOCK_GOAL,
	"7": C.BLOCK_GOAL,
	"8": C.BLOCK_GOAL,
	"9": C.BLOCK_GOAL,
	"<": C.BLOCK_RAMP_RIGHT,
	">": C.BLOCK_RAMP_LEFT,
	"v": C.BLOCK_RAMP_UP,
	"^": C.BLOCK_RAMP_DOWN,
	"@": C.BLOCK_BUMPER,
}

const BLOCK_SYMBOLS := [
	" ", "-", "=", "+", "#", "w", "W", "%", "d", "D", "$", "1", "<", ">", "v", "^", "@"
]

# Devuelve { "attributes": {...}, "map": [ [int, ...], ... ] }
static func parse_level(level_file: String) -> Dictionary:
	var f := File.new()
	if not f.file_exists(level_file):
		return { "attributes": {}, "map": [] }
	f.open(level_file, File.READ)
	var content := f.get_as_text()
	f.close()
	return parse_level_text(content)

# Parsea un nivel desde texto (para packs leídos en memoria desde un ZIP).
static func parse_level_text(content: String) -> Dictionary:
	var attributes := {}
	var level_map: Array = []
	var in_level := false
	for line_raw in content.split("\n"):
		var line: String = line_raw.replace("\r", "")
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

# Escribe un nivel en el formato .txt original.
# level_map: Array de filas de ints. Las filas se rellenan a la anchura máxima
# y se escribe un carácter extra al final (el parser descarta el último char).
static func write_level(level_file: String, attributes: Dictionary, level_map: Array) -> bool:
	var f := File.new()
	if f.open(level_file, File.WRITE) != OK:
		return false
	var attr_names := ["name", "author", "theme", "boy", "instructions", "background-color", "text-color", "junk"]
	for name in attr_names:
		if attributes.has(name):
			f.store_line("." + name + " {" + str(attributes[name]) + "}")
	f.store_line("!!!")
	var width := 0
	for row in level_map:
		if row.size() > width:
			width = row.size()
	for row in level_map:
		var line := ""
		for i in range(width):
			if i < row.size():
				line += _symbol_for_block(row[i])
			else:
				line += " "
		f.store_line(line + " ")
	f.store_line("!!!")
	f.close()
	return true

static func _symbol_for_block(blocktype: int) -> String:
	if blocktype >= 0 and blocktype < BLOCK_SYMBOLS.size():
		return BLOCK_SYMBOLS[blocktype]
	return " "
