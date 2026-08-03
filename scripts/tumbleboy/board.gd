extends Reference
# Board — grilla de bloques, alturas y bumpers (port de Board.py)

const C = preload("res://scripts/tumbleboy/tb_constants.gd")

var width := 0
var height := 0
var blocks: Array = []
var bumpers: Array = []
var theme := "default"

func clear():
	width = 0
	height = 0
	blocks = []
	bumpers = []
	theme = "default"

func set_theme(folder_name: String):
	theme = folder_name

func get_start_position() -> Vector2:
	for y in range(height):
		for x in range(width):
			if block_at(x, y) == C.BLOCK_START:
				return Vector2(x, y)
	return Vector2.ZERO

func get_colliding_bumper(x: float, y: float):
	for b in bumpers:
		var dx = b[0] - x
		var dy = b[1] - y
		if sqrt(dx * dx + dy * dy) <= 1.0:
			return [b[0], b[1]]
	return null

func set_block(xi: int, yi: int, blocktype: int) -> bool:
	if yi < 0 or xi < 0:
		return false
	var x = int(xi)
	var y = int(yi)
	while y >= height:
		blocks.append([])
		height += 1
	while blocks[y].size() <= x:
		blocks[y].append(C.BLOCK_NONE)
	if x >= width:
		width = x + 1
	blocks[y][x] = blocktype
	if blocktype == C.BLOCK_BUMPER:
		bumpers.append([x + 0.5, y + 0.5])
	return true

func height_at(x: float, y: float) -> float:
	if x < 0 or y < 0 or x >= width or y >= height:
		return C.MAX_DEPTH
	var t := block_at(x, y)
	match t:
		C.BLOCK_NONE:
			return C.MAX_DEPTH
		C.BLOCK_FLOOR, C.BLOCK_FLOOR2, C.BLOCK_FLOOR3, C.BLOCK_START, C.BLOCK_GOAL, C.BLOCK_BUMPER:
			return 0.0
		C.BLOCK_WALL, C.BLOCK_WALL2, C.BLOCK_WALL3:
			return 1.0
		C.BLOCK_DOUBLEWALL, C.BLOCK_DOUBLEWALL2, C.BLOCK_DOUBLEWALL3:
			return 2.0
		C.BLOCK_RAMP_RIGHT:
			return x - int(x)
		C.BLOCK_RAMP_LEFT:
			return 1.0 - (x - int(x))
		C.BLOCK_RAMP_UP:
			return 1.0 - (y - int(y))
		C.BLOCK_RAMP_DOWN:
			return y - int(y)
	return C.MAX_DEPTH

func block_at(x: float, y: float) -> int:
	if x < 0 or y < 0 or x >= width or y >= height:
		return C.BLOCK_NONE
	var xi = int(x)
	var yi = int(y)
	if xi >= blocks[yi].size():
		return C.BLOCK_NONE
	return blocks[yi][xi]
