extends SceneTree
# Genera 2 packs para el repo (packs/<id>.zip + thumbnails).
# Uso: godot3 --headless --path . -s tests/make_packs.gd

const ZipWriter = preload("res://scripts/tumbleboy/zip_writer.gd")

var levels_dir := "res://assets/tumbleboy/data/levels/"

func _init():
	var packs := [
		{
			"id": "introduccion_rapida",
			"name": "Introducción rápida",
			"author": "Aleperix",
			"description": "Los primeros pasos: los 4 niveles iniciales del original, para quien empieza.",
			"files": ["01-Introduction.txt", "02-Kink.txt", "03-Bridge.txt", "04-Dangerous_Corner.txt"],
			"color_a": Color(0.25, 0.6, 0.35),
			"color_b": Color(0.9, 0.85, 0.3),
		},
		{
			"id": "la_recta_final",
			"name": "La recta final",
			"author": "Aleperix",
			"description": "Los últimos 5 niveles del original: trucos, huecos y espirales.",
			"files": ["17-Tricky_Jump.txt", "18-Gaps.txt", "19-Islands.txt", "20-Spiral.txt", "21-Bonus_Beach.txt"],
			"color_a": Color(0.75, 0.25, 0.2),
			"color_b": Color(0.95, 0.7, 0.2),
		},
	]
	var ok_all := true
	for p in packs:
		if not _make_pack(p):
			ok_all = false
	if ok_all:
		print("PACKS OK")
		quit(0)
	else:
		printerr("PACKS FAILED")
		quit(1)

func _make_pack(p: Dictionary) -> bool:
	var files := {}
	var level_names := []
	for fn in p["files"]:
		var path: String = levels_dir + fn
		var f := File.new()
		if f.open(path, File.READ) != OK:
			printerr("no se pudo leer " + path)
			return false
		files["levels/" + fn] = f.get_as_text()
		f.close()
		level_names.append("levels/" + fn)
	var manifest := {
		"name": p["name"],
		"author": p["author"],
		"description": p["description"],
		"levels": level_names,
	}
	files["manifest.json"] = JSON.print(manifest, "  ")
	var dir := Directory.new()
	dir.make_dir_recursive("res://packs")
	var zip_path: String = "res://packs/" + p["id"] + ".zip"
	if not ZipWriter.write_pack_zip(zip_path, files):
		printerr("ZIP FAILED: " + zip_path)
		return false
	print("ZIP OK: " + zip_path + " (" + str(level_names.size()) + " niveles)")
	var img := Image.new()
	img.create(128, 128, false, Image.FORMAT_RGB8)
	img.fill(p["color_a"])
	img.lock()
	for i in range(128):
		img.set_pixel(i, i, p["color_b"])
		img.set_pixel(127 - i, i, p["color_b"])
	img.unlock()
	var thumb: String = "res://packs/" + p["id"] + ".png"
	img.save_png(thumb)
	print("THUMB OK: " + thumb)
	return true
