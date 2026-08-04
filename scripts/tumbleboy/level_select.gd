extends Control
# LevelSelect — selector de niveles y packs de TumbleBoy.
# Secciones: Modo historia (nostálgico, 21 originales), Packs instalados,
# packs online (descarga), y niveles individuales de usuario.

const C = preload("res://scripts/tumbleboy/tb_constants.gd")
const UIFonts = preload("res://scripts/ui/ui_fonts.gd")
const PackReader = preload("res://scripts/tumbleboy/pack_reader.gd")
const PackStoreScript = preload("res://scripts/tumbleboy/pack_store.gd")

const USER_LEVELS_DIR := "user://tumbleboy_levels/"

var store: Node
var menu_vbox: VBoxContainer
var online_panel: Control
var online_vbox: VBoxContainer
var online_status: Label
var entries: Array = []
var pack_buttons: Dictionary = {}

func _ready():
	store = PackStoreScript.new()
	add_child(store)
	store.connect("index_updated", self, "_on_index_updated")
	store.connect("index_error", self, "_on_index_error")
	store.connect("pack_downloaded", self, "_on_pack_downloaded")
	store.connect("thumbnail_ready", self, "_on_thumbnail_ready")
	_build_ui()
	_build_online_panel()
	_rebuild_menu()

func _build_ui():
	set_anchors_preset(Control.PRESET_WIDE)
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.05, 0.12)
	bg.set_anchors_preset(Control.PRESET_WIDE)
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.alignment = BoxContainer.ALIGN_CENTER
	vbox.add_constant_override("separation", 8)
	add_child(vbox)

	var title := Label.new()
	title.text = "SELECCIONAR NIVEL"
	title.add_font_override("font", UIFonts.make_font(34, true))
	title.add_color_override("font_color", Color(0.95, 0.9, 0.6))
	title.align = Label.ALIGN_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "Historia nostálgica · packs de la comunidad · tus niveles"
	sub.add_font_override("font", UIFonts.make_font(16))
	sub.add_color_override("font_color", Color(0.7, 0.67, 0.8))
	sub.align = Label.ALIGN_CENTER
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(sub)

	menu_vbox = VBoxContainer.new()
	menu_vbox.alignment = BoxContainer.ALIGN_CENTER
	menu_vbox.add_constant_override("separation", 6)
	vbox.add_child(menu_vbox)

	var hint := Label.new()
	hint.text = "D-pad / Flechas: mover · A / Enter: entrar · B / ESC: volver"
	hint.add_font_override("font", UIFonts.make_font(14))
	hint.add_color_override("font_color", Color(0.5, 0.5, 0.6))
	hint.align = Label.ALIGN_CENTER
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.margin_bottom = -6
	add_child(hint)

func _section_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_font_override("font", UIFonts.make_font(18, true))
	l.add_color_override("font_color", Color(0.7, 0.75, 0.9))
	l.align = Label.ALIGN_CENTER
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func _menu_button(text: String, method: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.rect_min_size = Vector2(620, 46)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_font_override("font", UIFonts.make_font(17))
	b.connect("pressed", self, method)
	menu_vbox.add_child(b)
	return b

func _rebuild_menu():
	for ch in menu_vbox.get_children():
		ch.queue_free()
	pack_buttons = {}
	menu_vbox.add_child(_section_label("HISTORIA"))
	_menu_button("Modo historia nostálgico — los 21 niveles originales", "_on_story")
	menu_vbox.add_child(_section_label("PACKS INSTALADOS"))
	var packs := PackReader.list_packs()
	if packs.size() == 0:
		menu_vbox.add_child(_section_label("(ninguno — crea uno en el editor o descarga de internet)"))
	for p in packs:
		var label: String = p.get("name", "?")
		if p.has("author") and String(p.get("author", "")) != "":
			label += "  —  " + str(p.get("author", ""))
		var b := _menu_button(label, "_on_pack")
		pack_buttons[str(p.get("id", ""))] = b
	_menu_button("Buscar packs online…", "_on_open_online")
	menu_vbox.add_child(_section_label("MIS NIVELES"))
	var user_levels := _list_user_levels()
	if user_levels.size() == 0:
		menu_vbox.add_child(_section_label("(sin niveles propios — pruébalos en el editor)"))
	for path in user_levels:
		_menu_button(path.get_file(), "_on_level")
	_menu_button("Volver al menú", "_on_back")

func _list_user_levels() -> Array:
	var result := []
	var dir := Directory.new()
	if dir.open(USER_LEVELS_DIR) == OK:
		dir.list_dir_begin()
		var fname := dir.get_next()
		while fname != "":
			if not dir.current_is_dir() and fname.ends_with(".txt"):
				result.append(USER_LEVELS_DIR + fname)
			fname = dir.get_next()
		dir.list_dir_end()
	result.sort()
	return result

func _on_story():
	LevelQueue.clear()
	get_tree().change_scene("res://scenes/TumbleBoy.tscn")

func _on_pack():
	var id: String = ""
	for k in pack_buttons:
		if pack_buttons[k] == _focused_owner():
			id = k
			break
	if id == "":
		return
	var zip_path := PackReader.zip_path_for_id(id)
	var dest := "user://tumbleboy_cache/play/" + id + "/"
	var paths := PackReader.extract_pack(zip_path, dest)
	if paths.size() == 0:
		return
	LevelQueue.play_levels(paths, id)
	get_tree().change_scene("res://scenes/TumbleBoy.tscn")

func _on_level():
	# el botón presionado es el que tiene el foco
	var b = _focused_owner()
	if b == null:
		return
	var path: String = USER_LEVELS_DIR + b.text
	LevelQueue.play_levels([path], b.text.get_basename())
	get_tree().change_scene("res://scenes/TumbleBoy.tscn")

func _focused_owner():
	for ch in menu_vbox.get_children():
		if ch is Button and ch.has_focus():
			return ch
	return null

func _on_back():
	get_tree().change_scene("res://scenes/MainMenu.tscn")

# ---- panel online ----

func _build_online_panel():
	online_panel = Control.new()
	online_panel.set_anchors_preset(Control.PRESET_WIDE)
	add_child(online_panel)

	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.05, 0.12)
	bg.set_anchors_preset(Control.PRESET_WIDE)
	online_panel.add_child(bg)

	var title := Label.new()
	title.text = "PACKS DE LA COMUNIDAD"
	title.add_font_override("font", UIFonts.make_font(28, true))
	title.add_color_override("font_color", Color(0.95, 0.9, 0.6))
	title.align = Label.ALIGN_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.margin_top = 18
	online_panel.add_child(title)

	online_status = Label.new()
	online_status.text = "Actualizando…"
	online_status.add_font_override("font", UIFonts.make_font(15))
	online_status.add_color_override("font_color", Color(0.7, 0.7, 0.8))
	online_status.align = Label.ALIGN_CENTER
	online_status.set_anchors_preset(Control.PRESET_TOP_WIDE)
	online_status.margin_top = 62
	online_panel.add_child(online_status)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_WIDE)
	scroll.margin_top = 100
	scroll.margin_bottom = -64
	online_panel.add_child(scroll)

	online_vbox = VBoxContainer.new()
	online_vbox.set_anchors_preset(Control.PRESET_CENTER)
	online_vbox.alignment = BoxContainer.ALIGN_CENTER
	online_vbox.add_constant_override("separation", 10)
	online_vbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	scroll.add_child(online_vbox)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGN_CENTER
	row.add_constant_override("separation", 16)
	row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	row.margin_bottom = -8
	online_panel.add_child(row)

	var update_btn := Button.new()
	update_btn.text = "Actualizar"
	update_btn.rect_min_size = Vector2(200, 40)
	update_btn.add_font_override("font", UIFonts.make_font(16))
	update_btn.connect("pressed", self, "_on_online_refresh")
	row.add_child(update_btn)

	var back_btn := Button.new()
	back_btn.text = "Volver  (B)"
	back_btn.rect_min_size = Vector2(200, 40)
	back_btn.add_font_override("font", UIFonts.make_font(16))
	back_btn.connect("pressed", self, "_on_close_online")
	row.add_child(back_btn)

	online_panel.visible = false

func _on_open_online():
	entries = store.get_cached_index()
	_render_online()
	online_panel.visible = true
	online_panel.raise()
	store.refresh_index()

func _on_close_online():
	online_panel.visible = false

func _on_online_refresh():
	online_status.text = "Actualizando…"
	store.refresh_index()

func _render_online():
	for ch in online_vbox.get_children():
		ch.queue_free()
	if entries.size() == 0:
		online_vbox.add_child(_section_label("(no hay packs publicados todavía)"))
		return
	for e in entries:
		online_vbox.add_child(_online_row(e))

func _online_row(e: Dictionary) -> Control:
	var id: String = e.get("id", "")
	var name: String = e.get("name", id)
	var author: String = e.get("author", "")
	var desc: String = e.get("description", "")
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGN_CENTER
	hb.add_constant_override("separation", 12)

	var thumb := TextureRect.new()
	thumb.rect_min_size = Vector2(72, 72)
	thumb.expand = true
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var tex = store.get_thumbnail_texture(id)
	if tex == null:
		store.download_thumbnail(e)
		thumb.texture = null
	else:
		thumb.texture = tex
	hb.add_child(thumb)

	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(480, 0)
	hb.add_child(vb)
	var n := Label.new()
	n.text = name + ("  —  " + author if author != "" else "")
	n.add_font_override("font", UIFonts.make_font(17, true))
	n.add_color_override("font_color", Color(0.95, 0.95, 0.98))
	vb.add_child(n)
	if desc != "":
		var d := Label.new()
		d.text = desc
		d.autowrap = true
		d.custom_minimum_size = Vector2(480, 0)
		d.add_font_override("font", UIFonts.make_font(14))
		d.add_color_override("font_color", Color(0.7, 0.7, 0.8))
		vb.add_child(d)

	var dl := Button.new()
	dl.focus_mode = Control.FOCUS_ALL
	dl.rect_min_size = Vector2(140, 40)
	dl.add_font_override("font", UIFonts.make_font(15))
	if store.is_pack_installed(id):
		dl.text = "Instalado ✓"
		dl.disabled = true
	else:
		dl.text = "Descargar"
		dl.connect("pressed", self, "_on_download", [e])
	hb.add_child(dl)
	return hb

func _on_download(e: Dictionary):
	store.download_pack(e)

func _on_index_updated(list: Array, from_cache: bool):
	entries = list
	online_status.text = "Lista actualizada desde GitHub" if not from_cache else "Sin cambios en el repo (usando caché)"
	_render_online()

func _on_index_error(msg: String):
	online_status.text = "Error: " + msg
	if entries.size() == 0:
		_render_online()

func _on_pack_downloaded(id: String, ok: bool, msg: String):
	if ok:
		online_status.text = "Pack '" + id + "' descargado"
		_render_online()
		_rebuild_menu()
	else:
		online_status.text = "Error al descargar: " + msg

func _on_thumbnail_ready(id: String):
	_render_online()

func _input(ev):
	if InputManager.back_just_pressed():
		if online_panel.visible:
			_on_close_online()
		else:
			_on_back()
