extends Reference
# PackReader — lista packs de user://tumbleboy_packs/*.zip, lee manifest.json
# y extrae el texto de los niveles desde el ZIP en memoria (ZipReader propio,
# porque ZIPReader no está compilado en este Godot).

const PACKS_DIR := "user://tumbleboy_packs/"
const ZipReader = preload("res://scripts/tumbleboy/zip_reader.gd")

# Devuelve [{ "id", "name", "author", "description", "levels": [..] }, ...]
static func list_packs() -> Array:
	var result := []
	var dir := Directory.new()
	if dir.open(PACKS_DIR) != OK:
		return result
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".zip"):
			var info = read_manifest(PACKS_DIR + fname)
			if info.size() > 0:
				info["id"] = fname.get_basename()
				result.append(info)
		fname = dir.get_next()
	dir.list_dir_end()
	for i in range(result.size()):
		for j in range(i + 1, result.size()):
			if _name_lt(result[j], result[i]):
				var tmp = result[i]
				result[i] = result[j]
				result[j] = tmp
	return result

static func _name_lt(a, b) -> bool:
	return String(a.get("name", "")).to_lower() < String(b.get("name", "")).to_lower()

static func zip_path_for_id(id: String) -> String:
	return PACKS_DIR + id + ".zip"

# Lee el manifest.json del zip. Devuelve {} si no es válido.
static func read_manifest(zip_path: String) -> Dictionary:
	var data = ZipReader.read_file(zip_path, "manifest.json")
	if data == null:
		return {}
	var parsed = parse_json(data.get_string_from_utf8())
	if parsed is Dictionary:
		return parsed
	return {}

static func get_level_text(zip_path: String, level_filename: String) -> String:
	var data = ZipReader.read_file(zip_path, level_filename)
	if data == null:
		return ""
	return data.get_string_from_utf8()

static func list_level_filenames(zip_path: String) -> Array:
	var names := ZipReader.get_files(zip_path)
	var result := []
	for n in names:
		if String(n).ends_with(".txt"):
			result.append(n)
	return result

# Extrae los .txt de un pack a dest_dir y devuelve las rutas resultantes.
static func extract_pack(zip_path: String, dest_dir: String) -> Array:
	var names := list_level_filenames(zip_path)
	var out := []
	var dir := Directory.new()
	dir.make_dir_recursive(dest_dir)
	for n in names:
		var data = ZipReader.read_file(zip_path, n)
		if data == null:
			continue
		var rel := String(n).replace("/", "_")
		var target := dest_dir + rel
		var f := File.new()
		if f.open(target, File.WRITE) == OK:
			f.store_buffer(data)
			f.close()
			out.append(target)
	out.sort()
	return out

static func get_thumbnail_texture(zip_path: String) -> Texture:
	var data = ZipReader.read_file(zip_path, "thumbnail.png")
	if data == null or data.size() == 0:
		return null
	var img := Image.new()
	if img.load_png_from_buffer(data) != OK:
		return null
	var tex := ImageTexture.new()
	tex.create_from_image(img)
	return tex

static func remove_pack(id: String) -> bool:
	var dir := Directory.new()
	if dir.remove(PACKS_DIR + id + ".zip") == OK:
		return true
	return false
