extends Reference
# Ball — física 3D de la bola-niño (port de Ball.py)

const C = preload("res://scripts/tumbleboy/tb_constants.gd")

var on_ground := true
var position := Vector3.ZERO
var velocity := Vector3.ZERO
var board = null
var images: Array = []

var anim_pose := C.BOY_RESTING
var anim_frame := 0
var anim_timer := 0.0
var theme := "boy1"

const POSE_FILES := [
	["tbrest1.png", "tbrest2.png"],
	["tbright1.png", "tbright2.png"],
	["tbleft1.png", "tbleft2.png"],
	["tbup1.png", "tbup2.png"],
	["tbdown1.png", "tbdown2.png"],
]
const SCALE_LEVELS := [0.8, 0.9, 1.0, 1.05, 1.1, 1.15]

func set_theme(folder_name: String):
	theme = folder_name
	images = []

func set_board(b):
	board = b

func add_force(dx: float, dy: float):
	var v := velocity
	var start_speed := sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
	v.x += dx
	v.y += dy
	var end_speed := sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
	if start_speed >= C.MAX_SPEED and end_speed > start_speed:
		return
	velocity = v

func is_above_goal() -> bool:
	if board == null:
		return false
	return board.block_at(position.x + 0.5, position.y + 0.5) == C.BLOCK_GOAL

func update(dt: float):
	var v := velocity
	var p := position
	if p.z <= C.MAX_DEPTH and board != null:
		var sp = board.get_start_position()
		set_position(sp.x, sp.y, 0)
		velocity = Vector3.ZERO
		on_ground = false
		AudioManager.play_sfx(C.SOUNDS_DIR + "lose_ball.ogg")
		return

	if on_ground:
		v.x -= v.x * C.BALL_DRAG
		v.y -= v.y * C.BALL_DRAG
		velocity = v
	p.x += v.x * dt
	p.y += v.y * dt
	p.z += v.z * dt

	if board == null:
		position = p
		return

	# bumpers
	if p.z >= -1.0 and p.z <= C.BUMPER_HEIGHT:
		var b = board.get_colliding_bumper(p.x + 0.5, p.y + 0.5)
		if b != null:
			var dx = b[0] - 0.5 - p.x
			var dy = b[1] - 0.5 - p.y
			var angle := atan2(dy, dx)
			v.x = -cos(angle) * C.BUMPER_SPEED
			v.y = -sin(angle) * C.BUMPER_SPEED
			velocity = v
			position = Vector3(position.x + v.x * dt, position.y + v.y * dt, position.z)
			AudioManager.play_sfx(C.SOUNDS_DIR + "hit_bumper.ogg")
			return

	# colisión con el nivel (altura del suelo)
	var height_beneath = board.height_at(p.x + 0.5, p.y + 0.5)
	if height_beneath < p.z:
		on_ground = false
		v.z += -C.GRAVITY * dt
	elif height_beneath > p.z:
		if -v.z >= C.GROUND_SOUND_SPEED:
			AudioManager.play_sfx(C.SOUNDS_DIR + "hit_ground.ogg")
		if v.z >= 0:
			p.z = height_beneath
			v.z = (height_beneath - p.z) / dt
			on_ground = false
		else:
			p.z = height_beneath
			v.z = 0
			on_ground = true

	# apartar la bola de los muros
	var height_left = board.height_at(p.x + 0.5 - C.BALL_RADIUS, p.y + 0.5)
	var height_right = board.height_at(p.x + 0.5 + C.BALL_RADIUS, p.y + 0.5)
	var height_up = board.height_at(p.x + 0.5, p.y + 0.5 - C.BALL_RADIUS)
	var height_down = board.height_at(p.x + 0.5, p.y + 0.5 + C.BALL_RADIUS)
	var myz := p.z + 0.5
	if height_left > myz:
		position.x = position.x + 0.02
	elif height_right > myz:
		position.x = position.x - 0.02
	if height_up > myz:
		position.y = position.y + 0.02
	elif height_down > myz:
		position.y = position.y - 0.02

	var dx := 0.0
	if v.x > 0:
		dx = C.BALL_RADIUS
	elif v.x < 0:
		dx = -C.BALL_RADIUS
	var dy := 0.0
	if v.y > 0:
		dy = C.BALL_RADIUS
	elif v.y < 0:
		dy = -C.BALL_RADIUS

	var height_x = board.height_at(p.x + 0.5 + dx, p.y + 0.5)
	var height_y = board.height_at(p.x + 0.5, p.y + 0.5 + dy)
	var speed := sqrt(v.x * v.x + v.y * v.y)
	if height_x - p.z >= C.BALL_CLIMB:
		v.x = -v.x * C.WALL_ELASTICITY
		if speed >= C.WALL_SOUND_SPEED:
			AudioManager.play_sfx(C.SOUNDS_DIR + "hit_wall.ogg")
	if height_y - p.z >= C.BALL_CLIMB:
		v.y = -v.y * C.WALL_ELASTICITY
		if speed >= C.WALL_SOUND_SPEED:
			AudioManager.play_sfx(C.SOUNDS_DIR + "hit_wall.ogg")

	p.x = position.x + v.x * dt
	p.y = position.y + v.y * dt
	position = p
	velocity = v

	anim_timer += speed * dt
	if anim_timer > 0.2:
		anim_timer = 0
		anim_frame = (anim_frame + 1) % 2
	if v.x > C.ANIM_LEAN_SPEED:
		anim_pose = C.BOY_RIGHT
	elif v.x < -C.ANIM_LEAN_SPEED:
		anim_pose = C.BOY_LEFT
	elif v.y < -C.ANIM_LEAN_SPEED:
		anim_pose = C.BOY_UP
	elif v.y > C.ANIM_LEAN_SPEED:
		anim_pose = C.BOY_DOWN
	else:
		anim_pose = C.BOY_RESTING

func set_position(x: float, y: float, z: float):
	position = Vector3(x, y, z)

func scale_index(z: float) -> int:
	var index := int((z + 1.25) / 0.5)
	if index < 0:
		return 0
	elif index >= 5:
		return 5
	return index

func current_texture() -> Texture:
	var si := scale_index(position.z)
	if images.size() <= si:
		return null
	var entry = images[si]
	return entry.frames[anim_pose + anim_frame]

func current_offs() -> Vector2:
	var si := scale_index(position.z)
	if images.size() <= si:
		return Vector2.ZERO
	return images[si].offs

func current_size() -> Vector2:
	var si := scale_index(position.z)
	if images.size() <= si:
		return Vector2.ZERO
	return images[si].size

func setup_images():
	var base_w := int(C.BALLSPRITE_WIDTH)
	var base_h := int(C.BALLSPRITE_HEIGHT)
	var base_imgs: Array = []
	for pose in POSE_FILES:
		for fn in pose:
			var path = C.THEMES_DIR + theme + "/" + fn
			var tex: Texture = null
			if ResourceLoader.exists(path):
				var res = load(path)
				if res is Texture:
					tex = res
			base_imgs.append(tex)
	images = []
	for scale in SCALE_LEVELS:
		var w := int(scale * base_w)
		var h := int(scale * base_h)
		var offs := Vector2((base_w - w) * 0.5, (base_h - h) * 0.5)
		var frames: Array = []
		for tex in base_imgs:
			if tex == null:
				frames.append(null)
			else:
				frames.append(_scale_tex(tex, w, h))
		images.append({ "size": Vector2(w, h), "offs": offs, "frames": frames })
	anim_pose = C.BOY_RESTING
	anim_frame = 0

func _scale_tex(tex: Texture, w: int, h: int) -> Texture:
	if tex.get_size() == Vector2(w, h):
		return tex
	var img: Image = tex.get_data()
	img.resize(w, h, Image.INTERPOLATE_BILINEAR)
	var it := ImageTexture.new()
	it.create_from_image(img)
	return it
