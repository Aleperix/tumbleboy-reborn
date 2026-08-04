extends Node
# LevelQueue — secuencia de niveles que el selector pasa a la escena de juego.
# Si paths está vacío, TumbleBoy juega el modo historia nostálgico (res://).
# mode: "story" | "pack" | "level"  — usado para el guardado por zócalo.

var paths: Array = []
var title := ""
var return_scene := ""
var mode := "story"
var pack_id := ""
var start_index := 0

func clear():
	paths = []
	title = ""
	return_scene = ""
	mode = "story"
	pack_id = ""
	start_index = 0

func play_levels(list: Array, t: String, m: String = "story", pid: String = ""):
	clear()
	paths = list
	title = t
	mode = m
	pack_id = pid
	return_scene = "res://scenes/PacksCommunity.tscn" if m == "pack" else ("res://scenes/EditorHub.tscn" if m == "level" else "res://scenes/StoryHub.tscn")
