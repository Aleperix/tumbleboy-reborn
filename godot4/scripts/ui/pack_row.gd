extends RefCounted
# PackRow — fila de pack con el mismo estilo que Packs online: bloque centrado
# con miniatura 64, información fija de 400px (nombre — autor + descripción) y
# botones de acción al final.
# Port a Godot 4: extends Reference -> RefCounted, ALIGN_CENTER ->
# ALIGNMENT_CENTER, expand -> expand_mode, autowrap -> autowrap_mode,
# add_font_override -> add_theme_font_override, Texture -> Texture2D.

const UIFonts = preload("res://scripts/ui/ui_fonts.gd")

static func make(pack: Dictionary, thumb: Texture2D, buttons: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)

	var preview := TextureRect.new()
	preview.custom_minimum_size = Vector2(64, 64)
	preview.size = Vector2(64, 64)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if thumb != null:
		preview.texture = thumb
	row.add_child(preview)

	var info_box := VBoxContainer.new()
	info_box.custom_minimum_size = Vector2(400, 0)
	info_box.add_theme_constant_override("separation", 2)

	var name: String = pack.get("name", pack.get("id", "???"))
	var author: String = pack.get("author", "")
	var name_label := Label.new()
	name_label.text = name + ("  —  " + author if author != "" else "")
	UIFonts.style_font(name_label, 16, true)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.98))
	info_box.add_child(name_label)

	var desc: String = pack.get("description", "")
	if desc != "":
		var desc_label := Label.new()
		desc_label.text = desc
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.custom_minimum_size = Vector2(400, 0)
		UIFonts.style_font(desc_label, 13)
		desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
		info_box.add_child(desc_label)

	row.add_child(info_box)

	for b in buttons:
		var btn: Button = b
		btn.custom_minimum_size = Vector2(120, 36)
		UIFonts.style_font(btn, 14)
		row.add_child(btn)

	return row
