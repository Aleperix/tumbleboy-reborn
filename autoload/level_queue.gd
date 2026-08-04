extends Node
# LevelQueue — secuencia de niveles que el selector pasa a la escena de juego.
# Si paths está vacío, TumbleBoy juega el modo historia nostálgico (res://).

var paths: Array = []
var title := ""
var return_scene := ""

func clear():
	paths = []
	title = ""
	return_scene = ""

func play_levels(list: Array, t: String):
	clear()
	paths = list
	title = t
	return_scene = "res://scenes/LevelSelect.tscn"
