extends Node
# Test de la tienda online (requiere red; se ejecuta en ventana, no headless).
# Uso: godot3 --path . res://tests/OnlineTest.tscn

const PackReader = preload("res://scripts/tumbleboy/pack_reader.gd")

var store: Node
var failures := 0
var done := false
var _t := 0.0
var _entry: Dictionary = {}
var _pack_ok := false
var _thumb_ok := false

func _ready():
	print("== online ==")
	store = preload("res://scripts/tumbleboy/pack_store.gd").new()
	add_child(store)
	store.connect("index_updated", self, "_on_index")
	store.connect("index_error", self, "_on_index_err")
	store.connect("pack_downloaded", self, "_on_pack")
	store.connect("thumbnail_ready", self, "_on_thumb")
	store.refresh_index()

func _check(cond: bool, msg: String):
	if cond:
		print("  OK: " + msg)
	else:
		failures += 1
		print("  FAIL: " + msg)

func _on_index_err(msg: String):
	_check(false, "index: " + msg)
	_finish()

func _on_index(list: Array, from_cache: bool):
	print("  index_updated (cache=%s) entries=%d" % [str(from_cache), list.size()])
	_check(list.size() == 1, "1 pack en el índice (hay %d)" % list.size())
	if list.size() != 1:
		_finish()
		return
	var e: Dictionary = list[0]
	_entry = e
	print("  entrada: id=%s name=%s author=%s" % [str(e.get("id")), str(e.get("name")), str(e.get("author"))])
	_check(e.get("name") == "Primer contacto", "nombre del pack")
	_check(e.get("author") == "Aleperix", "autor del pack")
	_check(store.is_pack_installed("primer_contacto") == false, "pack aún no instalado")
	store.download_pack(e)

func _on_pack(id: String, ok: bool, msg: String):
	print("  pack_downloaded id=%s ok=%s" % [id, str(ok)])
	_check(ok, "descarga del ZIP (" + msg + ")")
	_check(File.new().file_exists("user://tumbleboy_packs/" + id + ".zip"), "ZIP en user://tumbleboy_packs/")
	if ok:
		_check(store.is_pack_installed(id), "pack instalado detectado")
		var packs = PackReader.list_packs()
		var found := false
		for p in packs:
			if p.get("name") == "Primer contacto":
				found = true
				print("  manifest: name=%s author=%s" % [str(p.get("name")), str(p.get("author"))])
		_check(found, "manifest del pack leído")
		var lvl = PackReader.get_level_text("user://tumbleboy_packs/" + id + ".zip", "levels/01-Introduction.txt")
		_check(lvl.length() > 0, "nivel del pack leído del ZIP")
	_pack_ok = true
	if _pack_ok and not done:
		store.download_thumbnail(_entry)
	_on_thumb_done()

func _on_thumb(id: String):
	print("  thumbnail_ready id=%s" % id)
	_thumb_ok = true
	_check(File.new().file_exists("user://tumbleboy_cache/thumbs/" + id + ".png"), "thumb en caché")
	var tex = store.get_thumbnail_texture(id)
	_check(tex != null and tex is Texture, "thumb carga como textura (get_thumbnail_texture)")
	_on_thumb_done()

func _on_thumb_done():
	if done or not (_pack_ok and _thumb_ok):
		return
	# segundo refresh para probar ETag/304
	print("  refrescando de nuevo para ETag...")
	store.disconnect("index_updated", self, "_on_index")
	store.connect("index_updated", self, "_on_index_again", [], CONNECT_ONESHOT)
	store.refresh_index()

func _on_index_again(list: Array, from_cache: bool):
	print("  segundo index_updated (cache=%s)" % str(from_cache))
	_check(from_cache, "304 → se usó la caché")
	_finish()

func _finish():
	if done:
		return
	done = true
	if failures == 0:
		print("ONLINE TEST: ALL PASS")
	else:
		print("ONLINE TEST: %d FAILURES" % failures)
	yield(get_tree().create_timer(0.3), "timeout")
	get_tree().quit(failures)

func _process(delta):
	_t += delta
	if _t > 60.0 and not done:
		failures += 1
		print("  FAIL timeout de red")
		_finish()
