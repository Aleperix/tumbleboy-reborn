extends SceneTree
# Genera el pack de ejemplo para el repo (packs/primer_contacto.zip + thumbnail).
# Uso: godot3 --headless --path . -s tests/make_sample_pack.gd

const ZipWriter = preload("res://scripts/tumbleboy/zip_writer.gd")

func _init():
	var level_path := "res://assets/tumbleboy/data/levels/01-Introduction.txt"
	var f := File.new()
	if f.open(level_path, File.READ) != OK:
		printerr("no se pudo leer " + level_path)
		quit(1)
		return
	var level_text := f.get_as_text()
	f.close()

	var manifest := {
		"name": "Primer contacto",
		"author": "Aleperix",
		"description": "Nivel de ejemplo del repo para probar la descarga de packs.",
		"levels": ["levels/01-Introduction.txt"],
	}
	var files := {
		"manifest.json": JSON.print(manifest, "  "),
		"levels/01-Introduction.txt": level_text,
	}
	var dir := Directory.new()
	dir.make_dir_recursive("res://packs")
	var zip_path := "res://packs/primer_contacto.zip"
	if ZipWriter.write_pack_zip(zip_path, files):
		print("ZIP OK: " + zip_path)
	else:
		printerr("ZIP FAILED")
		quit(1)
		return

	var img := Image.new()
	img.create(128, 128, false, Image.FORMAT_RGB8)
	img.fill(Color(0.30, 0.55, 0.85))
	img.lock()
	for i in range(128):
		img.set_pixel(i, i, Color(0.95, 0.85, 0.30))
	img.unlock()
	img.save_png("res://packs/primer_contacto.png")
	print("THUMB OK: res://packs/primer_contacto.png")
	quit(0)
