extends Control
# PacksCommunity — Packs comunitarios: Packs descargados + Packs online.
# Dos paneles conmutables. Pack store reutiliza pack_store.gd (ETag/cache).
# Port a Godot 4: connect->Callable, change_scene->change_scene_to_file,
# align->horizontal_alignment, autowrap->autowrap_mode, rect_min_size->
# custom_minimum_size, expand->expand_mode, Directory->DirAccess,
# idle_frame connect -> SceneTree.idle_frame.connect, get_focus_owner ->
# get_viewport().gui_get_focus_owner, get_ok()->get_ok_button.

const UIFonts = preload("res://scripts/ui/ui_fonts.gd")
const PackReader = preload("res://scripts/tumbleboy/pack_reader.gd")
const PackRow = preload("res://scripts/ui/pack_row.gd")
const FocusNav = preload("res://scripts/ui/focus_nav.gd")
const FocusGrab = preload("res://scripts/ui/focus_grab.gd")

var store: Node
var menu_panel: Control
var descargados_panel: Control
var online_panel: Control
var desc_vbox: VBoxContainer
var online_vbox: VBoxContainer
var desc_scroll: ScrollContainer
var online_scroll: ScrollContainer
var online_status: Label
var entries: Array = []
var pack_buttons: Dictionary = {}
var download_dialog: ConfirmationDialog
var uninstall_dialog: ConfirmationDialog
var pending_download: Dictionary = {}
var pending_uninstall: String = ""
var menu_buttons: Array = []
var desc_back: Button
var online_refresh: Button
var online_back: Button
var desc_col: VBoxContainer
var online_col: VBoxContainer
var _thumb_nodes: Dictionary = {}
var _online_grab_pending := false
var _online_focus_id := ""
var _restore_steps := 0
var _panel_grabber: RefCounted = null

func _ready():
	store = preload("res://scripts/tumbleboy/pack_store.gd").new()
	add_child(store)
	store.index_updated.connect(_on_index_updated)
	store.index_error.connect(_on_index_error)
	store.pack_downloaded.connect(_on_pack_downloaded)
	store.thumbnail_ready.connect(_on_thumbnail_ready)
	_build_ui()
	set_process_input(true)
	if menu_buttons.size() > 0:
		menu_buttons[0].grab_focus()

func _build_ui():
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.05, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_build_menu()
	_build_descargados()
	_build_online()
	menu_panel.visible = true
	descargados_panel.visible = false
	online_panel.visible = false

# --- Panel menú principal ---

func _build_menu():
	menu_panel = Control.new()
	menu_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(menu_panel)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_panel.add_child(center)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 12)
	col.custom_minimum_size = Vector2(440, 0)
	center.add_child(col)

	var title := Label.new()
	title.text = "PACKS COMUNITARIOS"
	UIFonts.style_font(title, 30, true)
	title.add_theme_color_override("font_color", Color(0.95, 0.9, 0.6))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	col.add_child(spacer)

	var dl_btn := Button.new()
	dl_btn.text = "Packs descargados"
	dl_btn.focus_mode = Control.FOCUS_ALL
	dl_btn.custom_minimum_size = Vector2(400, 50)
	UIFonts.style_font(dl_btn, 18)
	dl_btn.add_theme_color_override("font_color", Color(0.95, 0.93, 0.88))
	dl_btn.pressed.connect(_on_open_descargados)
	col.add_child(dl_btn)
	menu_buttons.append(dl_btn)

	var online_btn := Button.new()
	online_btn.text = "Packs online"
	online_btn.focus_mode = Control.FOCUS_ALL
	online_btn.custom_minimum_size = Vector2(400, 50)
	UIFonts.style_font(online_btn, 18)
	online_btn.add_theme_color_override("font_color", Color(0.95, 0.93, 0.88))
	online_btn.pressed.connect(_on_open_online)
	col.add_child(online_btn)
	menu_buttons.append(online_btn)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 16)
	col.add_child(spacer2)

	var back := Button.new()
	back.text = "Volver"
	back.focus_mode = Control.FOCUS_ALL
	back.custom_minimum_size = Vector2(400, 44)
	UIFonts.style_font(back, 16)
	back.pressed.connect(_on_back)
	col.add_child(back)
	menu_buttons.append(back)

	var hint := Label.new()
	hint.text = "D-pad / Flechas: mover · A / Enter: entrar · B / ESC: volver"
	UIFonts.style_font(hint, 14)
	hint.add_theme_color_override("font_color", Color(0.65, 0.62, 0.72))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hint_sb := StyleBoxFlat.new()
	hint_sb.bg_color = Color(0, 0, 0, 0.35)
	hint_sb.set_corner_radius_all(4)
	hint_sb.content_margin_left = 8
	hint_sb.content_margin_top = 8
	hint_sb.content_margin_right = 8
	hint_sb.content_margin_bottom = 8
	hint.add_theme_stylebox_override("normal", hint_sb)
	col.add_child(hint)

# --- Panel descargados ---

func _build_descargados():
	descargados_panel = Control.new()
	descargados_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(descargados_panel)

	var bg2 := ColorRect.new()
	bg2.color = Color(0.07, 0.05, 0.12)
	bg2.set_anchors_preset(Control.PRESET_FULL_RECT)
	descargados_panel.add_child(bg2)

	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	descargados_panel.add_child(center)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 6)
	col.custom_minimum_size = Vector2(700, 0)
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	center.add_child(col)
	desc_col = col

	var title := Label.new()
	title.text = "PACKS DESCARGADOS"
	UIFonts.style_font(title, 28, true)
	title.add_theme_color_override("font_color", Color(0.95, 0.9, 0.6))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	desc_scroll = ScrollContainer.new()
	desc_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(desc_scroll)

	desc_vbox = VBoxContainer.new()
	desc_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	desc_vbox.add_theme_constant_override("separation", 10)
	desc_vbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	desc_scroll.add_child(desc_vbox)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	col.add_child(spacer)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	col.add_child(row)

	var back := Button.new()
	back.text = "Volver"
	back.custom_minimum_size = Vector2(160, 36)
	UIFonts.style_font(back, 15)
	back.pressed.connect(_on_close_descargados)
	row.add_child(back)
	desc_back = back

	descargados_panel.visible = false

func _refresh_descargados():
	for ch in desc_vbox.get_children():
		ch.queue_free()
	var packs := PackReader.list_packs()
	if packs.size() == 0:
		var l := Label.new()
		l.text = "(no hay packs instalados)"
		UIFonts.style_font(l, 16)
		l.add_theme_color_override("font_color", Color(0.65, 0.62, 0.72))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_vbox.add_child(l)
		return
	for p in packs:
		var id: String = str(p.get("id", ""))
		var thumb = PackReader.get_thumbnail_texture(PackReader.PACKS_DIR + id + ".zip")
		var play_btn := Button.new()
		play_btn.text = "Jugar"
		play_btn.custom_minimum_size = Vector2(120, 36)
		play_btn.pressed.connect(_on_pack_play.bind(p))
		var uninstall_btn := Button.new()
		uninstall_btn.text = "Desinstalar"
		uninstall_btn.custom_minimum_size = Vector2(120, 36)
		uninstall_btn.pressed.connect(_on_uninstall.bind(id))
		var row = PackRow.make(p, thumb, [play_btn, uninstall_btn])
		desc_vbox.add_child(row)
	FocusNav.enable_scroll_follow(desc_scroll)

func _on_pack_play(p: Dictionary):
	var id: String = str(p.get("id", ""))
	NavParams.pending_picker = ["pack", id, "new"]
	get_tree().change_scene_to_file("res://scenes/SlotPicker.tscn")

# --- Panel online ---

func _build_online():
	online_panel = Control.new()
	online_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(online_panel)

	var bg3 := ColorRect.new()
	bg3.color = Color(0.07, 0.05, 0.12)
	bg3.set_anchors_preset(Control.PRESET_FULL_RECT)
	online_panel.add_child(bg3)

	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	online_panel.add_child(center)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 6)
	col.custom_minimum_size = Vector2(700, 0)
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	center.add_child(col)
	online_col = col

	var title := Label.new()
	title.text = "PACKS ONLINE"
	UIFonts.style_font(title, 28, true)
	title.add_theme_color_override("font_color", Color(0.95, 0.9, 0.6))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	online_status = Label.new()
	online_status.text = "Actualizando…"
	UIFonts.style_font(online_status, 14)
	online_status.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	online_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(online_status)

	online_scroll = ScrollContainer.new()
	online_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	online_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	online_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(online_scroll)

	online_vbox = VBoxContainer.new()
	online_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	online_vbox.add_theme_constant_override("separation", 10)
	online_vbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	online_scroll.add_child(online_vbox)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	col.add_child(spacer)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	col.add_child(row)

	var refresh := Button.new()
	refresh.text = "Actualizar"
	refresh.custom_minimum_size = Vector2(160, 36)
	UIFonts.style_font(refresh, 15)
	refresh.pressed.connect(_on_online_refresh)
	row.add_child(refresh)
	online_refresh = refresh

	var back := Button.new()
	back.text = "Volver"
	back.custom_minimum_size = Vector2(160, 36)
	UIFonts.style_font(back, 15)
	back.pressed.connect(_on_close_online)
	row.add_child(back)
	online_back = back

	online_panel.visible = false

func _render_online():
	_online_focus_id = _focused_online_id()
	for ch in online_vbox.get_children():
		ch.queue_free()
	_thumb_nodes = {}
	if entries.size() == 0:
		online_vbox.add_child(_section_label("(no hay packs publicados todavía)"))
		if online_panel.visible and _online_grab_pending:
			online_refresh.grab_focus()
		_online_grab_pending = false
		return
	for e in entries:
		online_vbox.add_child(_online_row(e))
	FocusNav.enable_scroll_follow(online_scroll)
	if online_panel.visible and (_online_grab_pending or get_viewport().gui_get_focus_owner() == null):
		if not FocusNav.grab_first(online_vbox):
			online_refresh.grab_focus()
	_online_grab_pending = false
	_restore_online_focus()

# Restaura el foco tras refrescar la lista online. La respuesta de red llega de
# forma asíncrona y _render_online reconstruye los nodos (queue_free), así que
# hay que esperar un par de frames para que el botón viejo desaparezca antes de
# devolver el foco al mismo pack (o al primero si ya no está).
func _restore_online_focus():
	_restore_steps = 2
	if not get_tree().process_frame.is_connected(_on_restore_tick):
		get_tree().process_frame.connect(_on_restore_tick)

func _on_restore_tick():
	_restore_steps -= 1
	if _restore_steps > 0:
		return
	get_tree().process_frame.disconnect(_on_restore_tick)
	if not online_panel.visible or FocusNav.popup_open(self):
		return
	if _online_focus_id != "" and _grab_button_for_row(_online_focus_id):
		_online_focus_id = ""
		return
	if FocusNav.grab_first(online_vbox):
		_online_focus_id = ""
		return
	online_refresh.grab_focus()
	_online_focus_id = ""

func _focused_online_id() -> String:
	var fo = get_viewport().gui_get_focus_owner()
	if fo == null or not is_instance_valid(fo):
		return ""
	var row: Node = fo.get_parent()
	if row == null:
		return ""
	for id in _thumb_nodes.keys():
		if is_instance_valid(_thumb_nodes[id]) and _thumb_nodes[id].get_parent() == row:
			return id
	return ""

func _online_row(e: Dictionary) -> Control:
	var id: String = e.get("id", "")
	var name: String = e.get("name", id)
	var author: String = e.get("author", "")
	var desc: String = e.get("description", "")
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 12)

	var thumb := TextureRect.new()
	thumb.custom_minimum_size = Vector2(64, 64)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var tex = store.get_thumbnail_texture(id)
	if tex == null:
		store.download_thumbnail(e)
	thumb.texture = tex
	_thumb_nodes[id] = thumb
	hb.add_child(thumb)

	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(400, 0)
	hb.add_child(vb)

	var n := Label.new()
	n.text = name + ("  —  " + author if author != "" else "")
	UIFonts.style_font(n, 16, true)
	n.add_theme_color_override("font_color", Color(0.95, 0.95, 0.98))
	vb.add_child(n)
	if desc != "":
		var d := Label.new()
		d.text = desc
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(400, 0)
		UIFonts.style_font(d, 13)
		d.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
		vb.add_child(d)

	var dl := Button.new()
	dl.focus_mode = Control.FOCUS_ALL
	dl.custom_minimum_size = Vector2(120, 36)
	UIFonts.style_font(dl, 14)
	if store.is_pack_installed(id):
		dl.text = "Instalado"
		FocusNav.set_skippable(dl, true)
	else:
		dl.text = "Descargar"
		dl.pressed.connect(_on_download.bind(e))
	hb.add_child(dl)
	return hb

func _section_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	UIFonts.style_font(l, 16)
	l.add_theme_color_override("font_color", Color(0.65, 0.62, 0.72))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

# --- Acciones ---

func _focus_grabber() -> RefCounted:
	if _panel_grabber == null:
		_panel_grabber = FocusGrab.new()
	return _panel_grabber

func _on_open_descargados():
	menu_panel.visible = false
	_refresh_descargados()
	descargados_panel.visible = true
	descargados_panel.move_to_front()
	_focus_grabber().start(get_tree(), desc_vbox, desc_back)

func _on_close_descargados():
	descargados_panel.visible = false
	menu_panel.visible = true
	if menu_buttons.size() > 0:
		menu_buttons[0].grab_focus()

func _on_open_online():
	menu_panel.visible = false
	online_panel.visible = true
	online_panel.move_to_front()
	_online_grab_pending = true
	online_refresh.grab_focus()
	store.refresh_index()

func _on_close_online():
	online_panel.visible = false
	menu_panel.visible = true
	if menu_buttons.size() > 0:
		menu_buttons[0].grab_focus()

func _on_online_refresh():
	online_status.text = "Actualizando…"
	store.refresh_index()

func _on_index_updated(list: Array, from_cache: bool):
	entries = list
	online_status.text = "Lista actualizada" if not from_cache else "Usando caché"
	_render_online()

func _on_index_error(msg: String):
	online_status.text = "Error: " + msg
	_render_online()

func _on_download(e: Dictionary):
	pending_download = e
	var id: String = e.get("id", "")
	var name: String = e.get("name", id)
	if download_dialog == null:
		download_dialog = ConfirmationDialog.new()
		download_dialog.title = "Descargar pack"
		download_dialog.get_ok_button().text = "Descargar"
		download_dialog.get_cancel_button().text = "Cancelar"
		download_dialog.confirmed.connect(_on_download_confirmed)
		download_dialog.visibility_changed.connect(func(): if not download_dialog.visible: _on_dialog_closed())
		add_child(download_dialog)
	download_dialog.dialog_text = "¿Descargar el pack '" + name + "'?\n"
	if e.has("author"):
		download_dialog.dialog_text += "Creador: " + str(e.get("author", "")) + "\n"
	if e.has("description"):
		download_dialog.dialog_text += "\n" + str(e.get("description", ""))
	download_dialog.popup_centered()

func _on_download_confirmed():
	if pending_download.size() > 0:
		store.download_pack(pending_download)
	pending_download = {}

func _on_uninstall(id: String):
	pending_uninstall = id
	if uninstall_dialog == null:
		uninstall_dialog = ConfirmationDialog.new()
		uninstall_dialog.title = "Desinstalar pack"
		uninstall_dialog.get_ok_button().text = "Desinstalar"
		uninstall_dialog.get_cancel_button().text = "Cancelar"
		uninstall_dialog.confirmed.connect(_on_uninstall_confirmed)
		uninstall_dialog.visibility_changed.connect(func(): if not uninstall_dialog.visible: _on_dialog_closed())
		add_child(uninstall_dialog)
	uninstall_dialog.dialog_text = "¿Desinstalar el pack '" + id + "'?\nSe eliminarán todos sus niveles."
	uninstall_dialog.popup_centered()

func _on_uninstall_confirmed():
	if pending_uninstall == "":
		return
	PackReader.remove_pack(pending_uninstall)
	SaveData.clear_pack(pending_uninstall)
	pending_uninstall = ""
	_refresh_descargados()

func _on_pack_downloaded(id: String, ok: bool, msg: String):
	if ok:
		SaveData.mark_pack_downloaded(id)
		online_status.text = "Pack '" + id + "' descargado"
		_render_online()
		if online_panel.visible and not _grab_button_for_row(id):
			if not FocusNav.grab_first(online_vbox):
				online_refresh.grab_focus()
	else:
		online_status.text = "Error: " + msg

func _on_thumbnail_ready(id: String):
	if _thumb_nodes.has(id) and is_instance_valid(_thumb_nodes[id]):
		_thumb_nodes[id].texture = store.get_thumbnail_texture(id)

func _grab_button_for_row(id: String) -> bool:
	if _thumb_nodes.has(id) and is_instance_valid(_thumb_nodes[id]):
		var row: Node = _thumb_nodes[id].get_parent()
		if row != null:
			for ch in row.get_children():
				if ch is Button and not ch.disabled:
					ch.grab_focus()
					return true
	return false

func _on_back():
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_dialog_closed():
	if online_panel.visible:
		_focus_grabber().start(get_tree(), online_vbox, online_refresh)
	elif descargados_panel.visible:
		_focus_grabber().start(get_tree(), desc_vbox, desc_back)

func _process(_delta):
	if InputManager.back_just_pressed():
		if FocusNav.popup_open(self):
			return
		if online_panel.visible:
			_on_close_online()
		elif descargados_panel.visible:
			_on_close_descargados()
		else:
			_on_back()
