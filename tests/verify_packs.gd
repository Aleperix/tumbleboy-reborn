extends SceneTree
# Verifica que los packs de packs/ se leen con el PackReader del juego.
# Uso: godot3 --headless --path . -s tests/verify_packs.gd

const PackReader = preload("res://scripts/tumbleboy/pack_reader.gd")

func _init():
	var ids := ["primer_contacto", "introduccion_rapida", "la_recta_final"]
	var bad := false
	for id in ids:
		var zip: String = "res://packs/" + id + ".zip"
		var manifest = PackReader.read_manifest(zip)
		if manifest == null:
			printerr("FAIL manifest: " + id)
			bad = true
			continue
		var levels = PackReader.list_level_filenames(zip)
		var ok := true
		for l in levels:
			var t = PackReader.get_level_text(zip, l)
			if t.length() == 0:
				printerr("FAIL nivel vacío: " + l)
				ok = false
		var parsed_ok := true
		var level_texts = preload("res://scripts/tumbleboy/levels.gd")
		for l in levels:
			var parsed = level_texts.parse_level_text(PackReader.get_level_text(zip, l))
			if parsed["map"].size() == 0:
				parsed_ok = false
		print("  %s: '%s' por %s — %d niveles, parse %s" % [id, str(manifest.get("name")), str(manifest.get("author")), levels.size(), str(parsed_ok)])
		if not ok or not parsed_ok:
			bad = true
	if bad:
		printerr("VERIFY FAILED")
		quit(1)
	print("VERIFY OK")
	quit(0)
