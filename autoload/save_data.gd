extends Node
# SaveData — guardado persistente en user://save.json
# (puntajes, tienda, canicas desbloqueadas, niveles completados...)

const SAVE_PATH := "user://save.json"

var data: Dictionary = {}

func _init():
	load_data()

func load_data():
	var file := File.new()
	if file.file_exists(SAVE_PATH):
		if file.open(SAVE_PATH, File.READ) == OK:
			var parsed = parse_json(file.get_as_text())
			if parsed is Dictionary:
				data = parsed
			file.close()

func save():
	var file := File.new()
	if file.open(SAVE_PATH, File.WRITE) == OK:
		file.store_string(JSON.print(data))
		file.close()

func get_value(key: String, default = null):
	if data.has(key):
		return data[key]
	return default

func set_value(key: String, value):
	data[key] = value
	save()

func reset_all():
	data = {}
	save()
