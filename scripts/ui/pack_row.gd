extends Reference

const UIFonts = preload("res://scripts/ui/ui_fonts.gd")

static func make(pack: Dictionary, thumb: Texture, buttons: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_constant_override("separation", 8)

	var preview := TextureRect.new()
	preview.rect_min_size = Vector2(56, 56)
	preview.rect_size = Vector2(56, 56)
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if thumb != null:
		preview.texture = thumb
	row.add_child(preview)

	var info_box := VBoxContainer.new()
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_box.add_constant_override("separation", 2)

	var name_label := Label.new()
	name_label.text = pack.get("name", pack.get("id", "???"))
	name_label.add_font_override("font", UIFonts.make_font(16, true))
	name_label.add_color_override("font_color", Color(0.95, 0.9, 0.6))
	info_box.add_child(name_label)

	var author_label := Label.new()
	author_label.text = pack.get("author", "")
	author_label.add_font_override("font", UIFonts.make_font(12))
	author_label.add_color_override("font_color", Color(0.6, 0.6, 0.7))
	info_box.add_child(author_label)

	row.add_child(info_box)

	for b in buttons:
		var btn: Button = b
		row.add_child(btn)

	return row
