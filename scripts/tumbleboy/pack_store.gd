extends Node
# PackStore — descarga de packs desde el repo público de GitHub (solo lectura).
# - index.json del repo con caché ETag (If-None-Match → 304 = usar caché).
# - Descarga de ZIPs a user://tumbleboy_packs/ y thumbnails a la caché.

signal index_updated(entries, from_cache)
signal index_error(message)
signal pack_downloaded(id, ok, message)
signal thumbnail_ready(id)

const REPO := "Aleperix/tumbleboy-reborn"
const BRANCH := "main"
const API_INDEX_URL := "https://api.github.com/repos/Aleperix/tumbleboy-reborn/contents/packs/index.json"
const RAW_BASE := "https://raw.githubusercontent.com/Aleperix/tumbleboy-reborn/main/"
const CACHE_DIR := "user://tumbleboy_cache/"
const PACKS_DIR := "user://tumbleboy_packs/"

var http: HTTPRequest
var _pending := ""
var _pending_id := ""

func _ready():
	http = HTTPRequest.new()
	http.timeout = 20.0
	add_child(http)
	http.connect("request_completed", self, "_on_request_completed")
	var dir := Directory.new()
	dir.make_dir_recursive(CACHE_DIR)
	dir.make_dir_recursive(CACHE_DIR + "thumbs")
	dir.make_dir_recursive(PACKS_DIR)

# Devuelve el index en caché (sin red). Vacío si no hay caché.
func get_cached_index() -> Array:
	var text := _read_text(CACHE_DIR + "index.json")
	if text == "":
		return []
	var parsed = parse_json(text)
	if parsed is Array:
		return parsed
	return []

# Refresca el index: devuelve la caché al instante si existe, y en paralelo
# consulta GitHub con ETag; si el repo no cambió (304) no vuelve a descargar.
func refresh_index():
	if _pending != "":
		return
	var etag := _read_text(CACHE_DIR + "index_etag.txt").strip_edges()
	var headers := PoolStringArray(["Accept: application/vnd.github.raw+json"])
	if etag != "":
		headers.append("If-None-Match: " + etag)
	var err := http.request(API_INDEX_URL, headers, true, HTTPClient.METHOD_GET)
	if err != OK:
		emit_signal("index_error", "No se pudo iniciar la consulta")
		return
	_pending = "index"

func is_pack_installed(id: String) -> bool:
	var f := File.new()
	return f.file_exists(PACKS_DIR + id + ".zip")

func download_pack(entry: Dictionary):
	if _pending != "":
		return
	var id: String = entry.get("id", "")
	if id == "":
		return
	var url: String = entry.get("zip_url", "")
	if url == "":
		url = RAW_BASE + "packs/" + id + ".zip"
	_pending = "zip"
	_pending_id = id
	http.request(url, [], true, HTTPClient.METHOD_GET)

func download_thumbnail(entry: Dictionary):
	if _pending != "":
		return
	var id: String = entry.get("id", "")
	if id == "":
		return
	var url: String = entry.get("thumbnail_url", entry.get("thumbnail", ""))
	if url == "":
		emit_signal("thumbnail_ready", id)
		return
	if not url.begins_with("http"):
		url = RAW_BASE + url
	_pending = "thumb"
	_pending_id = id
	http.request(url, [], true, HTTPClient.METHOD_GET)

func get_thumbnail_texture(id: String):
	var p := CACHE_DIR + "thumbs/" + id + ".png"
	if ResourceLoader.exists(p):
		return load(p)
	return null

func _on_request_completed(result: int, response_code: int, headers: PoolStringArray, body: PoolByteArray):
	var what := _pending
	var id := _pending_id
	_pending = ""
	_pending_id = ""
	if what == "index":
		_handle_index(result, response_code, headers, body)
	elif what == "zip":
		_handle_zip(result, response_code, body, id)
	elif what == "thumb":
		_handle_thumb(result, response_code, body, id)

func _handle_index(result: int, response_code: int, headers: PoolStringArray, body: PoolByteArray):
	if result != HTTPRequest.RESULT_SUCCESS:
		emit_signal("index_error", "Error de red")
		return
	if response_code == 304:
		emit_signal("index_updated", get_cached_index(), true)
		return
	if response_code == 404:
		emit_signal("index_error", "El repo no tiene packs/index.json todavía")
		return
	if response_code != 200:
		emit_signal("index_error", "HTTP " + str(response_code))
		return
	var text := body.get_string_from_utf8()
	var etag := _extract_etag(headers)
	if etag != "":
		_write_text(CACHE_DIR + "index_etag.txt", etag)
	_write_text(CACHE_DIR + "index.json", text)
	var parsed = parse_json(text)
	if parsed is Array:
		emit_signal("index_updated", parsed, false)
	else:
		emit_signal("index_error", "index.json no es una lista")

func _handle_zip(result: int, response_code: int, body: PoolByteArray, id: String):
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		emit_signal("pack_downloaded", id, false, "HTTP " + str(response_code))
		return
	var f := File.new()
	if f.open(PACKS_DIR + id + ".zip", File.WRITE) != OK:
		emit_signal("pack_downloaded", id, false, "no se pudo escribir")
		return
	f.store_buffer(body)
	f.close()
	emit_signal("pack_downloaded", id, true, "")

func _handle_thumb(result: int, response_code: int, body: PoolByteArray, id: String):
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var f := File.new()
		if f.open(CACHE_DIR + "thumbs/" + id + ".png", File.WRITE) == OK:
			f.store_buffer(body)
			f.close()
	emit_signal("thumbnail_ready", id)

func _extract_etag(headers: PoolStringArray) -> String:
	for h in headers:
		var hl: String = h.to_lower()
		if hl.begins_with("etag"):
			var parts: Array = h.split(":", true, 1)
			if parts.size() == 2:
				return parts[1].strip_edges()
	return ""

func _read_text(path: String) -> String:
	var f := File.new()
	if not f.file_exists(path):
		return ""
	if f.open(path, File.READ) != OK:
		return ""
	var t := f.get_as_text()
	f.close()
	return t

func _write_text(path: String, text: String):
	var f := File.new()
	if f.open(path, File.WRITE) == OK:
		f.store_string(text)
		f.close()
