extends Reference
# PackRow — fila de pack con el mismo estilo que Packs online: bloque centrado
# con miniatura 64, información fija de 400px (nombre — autor + descripción) y
# botones de acción al final.

const UIFonts = preload("res://scripts/ui/ui_fonts.gd")

static func make(pack: Dictionary, thumb: Texture, buttons: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGN_CENTER
	row.add_constant_override("separation", 12)

	var preview := TextureRect.new()
	preview.rect_min_size = Vector2(64, 64)
	preview.rect_size = Vector2(64, 64)
	preview.expand = true
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if thumb != null:
		preview.texture = thumb
	row.add_child(preview)

	var info_box := VBoxContainer.new()
	info_box.rect_min_size = Vector2(400, 0)
	info_box.add_constant_override("separation", 2)

	var name: String = pack.get("name", pack.get("id", "???"))
	var author: String = pack.get("author", "")
	var name_label := Label.new()
	name_label.text = name + ("  —  " + author if author != "" else "")
	name_label.add_font_override("font", UIFonts.make_font(16, true))
	name_label.add_color_override("font_color", Color(0.95, 0.95, 0.98))
	info_box.add_child(name_label)

	var desc: String = pack.get("description", "")
	if desc != "":
		var desc_label := Label.new()
		desc_label.text = desc
		desc_label.autowrap = true
		desc_label.rect_min_size = Vector2(400, 0)
		desc_label.add_font_override("font", UIFonts.make_font(13))
		desc_label.add_color_override("font_color", Color(0.7, 0.7, 0.8))
		info_box.add_child(desc_label)

	row.add_child(info_box)

	for b in buttons:
		var btn: Button = b
		btn.rect_min_size = Vector2(120, 36)
		btn.add_font_override("font", UIFonts.make_font(14))
		row.add_child(btn)

	return row
