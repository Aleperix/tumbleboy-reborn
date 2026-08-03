# TumbleBoy — constantes escaladas fieles al original (Constants.py)
# El original escala de una resolución base 640x480 a 1100x825 (scale=825/480).
const SCALE := 825.0 / 480.0
const GAME_OFFSET_X := 50.0   # centrar los 1100px de TumbleBoy en los 1200px de la ventana

const SCREEN_W := 1100.0
const SCREEN_H := 825.0
const SCREEN_MARGIN := 200.0 * SCALE
const PIXEL_SIZE := 64.0 * SCALE
const PIXEL_BORDER := 12.0 * SCALE
const BALL_PIXEL_SIZE := 64.0 * SCALE
const BALLSPRITE_OFFSETX := 2.0 * SCALE
const BALLSPRITE_OFFSETY := 15.0 * SCALE
const BALLSPRITE_WIDTH := 70.0 * SCALE
const BALLSPRITE_HEIGHT := 81.0 * SCALE
const GOOD_JOB_SIZE := 300.0 * SCALE
const MENU_ANIM_RECT := Rect2(460.0 * SCALE, 260.0 * SCALE, 140.0 * SCALE, 162.0 * SCALE)
const WIN_ANIM_RECT := Rect2(326.0 * SCALE, 0, 105.0 * SCALE, 116.0 * SCALE)

const MAX_SPEED := 2.0
const BUMPER_SPEED := 4.0
const GRAVITY := 8.0
const MAX_DEPTH := -5.0
const BALL_FORCE := 1.0
const BALL_DRAG := 0.003
const WALL_ELASTICITY := 0.6
const BALL_CLIMB := 0.75
const BALL_RADIUS := 0.45
const BUMPER_HEIGHT := 0.2

const ANIM_LEAN_SPEED := 0.25
const GROUND_SOUND_SPEED := 2.0
const WALL_SOUND_SPEED := 1.0

const BLOCK_NONE := 0
const BLOCK_FLOOR := 1
const BLOCK_FLOOR2 := 2
const BLOCK_FLOOR3 := 3
const BLOCK_WALL := 4
const BLOCK_WALL2 := 5
const BLOCK_WALL3 := 6
const BLOCK_DOUBLEWALL := 7
const BLOCK_DOUBLEWALL2 := 8
const BLOCK_DOUBLEWALL3 := 9
const BLOCK_START := 10
const BLOCK_GOAL := 11
const BLOCK_RAMP_RIGHT := 12
const BLOCK_RAMP_LEFT := 13
const BLOCK_RAMP_UP := 14
const BLOCK_RAMP_DOWN := 15
const BLOCK_BUMPER := 16

const SOUND_NONE := 0
const SOUND_START_LEVEL := 1
const SOUND_LOSE_BALL := 2
const SOUND_HIT_WALL := 3
const SOUND_HIT_GROUND := 4
const SOUND_HIT_BUMPER := 5
const SOUND_WIN_LEVEL := 6
const SOUND_WIN_GAME := 7

const BOY_RESTING := 0
const BOY_RIGHT := 2
const BOY_LEFT := 4
const BOY_UP := 6
const BOY_DOWN := 8

# rutas de recursos
const ASSETS := "res://assets/tumbleboy/"
const LEVELS_DIR := ASSETS + "data/levels/"
const THEMES_DIR := ASSETS + "data/themes/"
const SOUNDS_DIR := ASSETS + "data/sounds/"
const MENUS_DIR := ASSETS + "data/menus/"
