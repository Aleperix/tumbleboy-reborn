extends Reference
# Board — grilla de bloques, alturas y bumpers (port de Board.py)

const C = preload("res://scripts/tumbleboy/tb_constants.gd")

var width := 0
var height := 0
var blocks: Array = []
var bumpers: Array = []
var theme := "default"
var block_images: Array = []

func clear():
	width = 0
	height = 0
	blocks = []
	bumpers = []
	theme = "default"

func set_theme(folder_name: String):
	theme = folder_name

func set_dimensions(w: int, h: int):
	width = max(width, w)
	height = max(height, h)
	while blocks.size() < height:
		blocks.append([])
	for row in blocks:
		while row.size() < width:
			row.append(C.BLOCK_NONE)

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

func load_block_images():
	block_images = []
	var names := [
		"", "floor.png", "floor2.png", "floor3.png",
		"wall.png", "wall2.png", "wall3.png",
		"doublewall.png", "doublewall2.png", "doublewall3.png",
		"startfloor.png", "goal.png",
		"rampright.png", "rampleft.png", "rampup.png", "rampdown.png",
		"bumper.png", ""
	]
	var size := int(C.PIXEL_SIZE + C.PIXEL_BORDER)
	for name in names:
		if name == "":
			block_images.append(null)
			continue
		var path = C.THEMES_DIR + theme + "/" + name
		if ResourceLoader.exists(path):
			var tex = load(path)
			if tex is Texture:
				if tex.get_size() != Vector2(size, size):
					var img: Image = tex.get_data()
					img.resize(size, size, Image.INTERPOLATE_BILINEAR)
					var it := ImageTexture.new()
					it.create_from_image(img)
					block_images.append(it)
				else:
					block_images.append(tex)
			else:
				block_images.append(null)
		else:
			block_images.append(null)

func render_board_image() -> Texture:
	load_block_images()
	var iw := int(width * C.PIXEL_SIZE + C.PIXEL_BORDER)
	var ih := int(height * C.PIXEL_SIZE + C.PIXEL_BORDER)
	if iw <= 0 or ih <= 0:
		return null
	var img: Image = Image.new()
	img.create(iw, ih, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var blocksize := int(C.PIXEL_SIZE + C.PIXEL_BORDER)
	for y in range(height):
		for x in range(width):
			var t := block_at(x, y)
			if t >= 0 and t < block_images.size():
				var tile: Texture = block_images[t]
				if tile != null:
					var tile_img: Image = tile.get_data()
					img.blend_rect(tile_img, Rect2(0, 0, tile_img.get_width(), tile_img.get_height()), Vector2(int(x * C.PIXEL_SIZE), int(y * C.PIXEL_SIZE)))
	var it := ImageTexture.new()
	it.create_from_image(img)
	return it
