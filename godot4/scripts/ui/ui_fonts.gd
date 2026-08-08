extends RefCounted
# ui_fonts — fuentes compartidas para la interfaz.
# Port de templates/godot3 a Godot 4: DynamicFont -> FontFile (con FontData);
# el tamaño ya NO vive en la fuente (Godot 4), se aplica aparte con
# add_theme_font_size_override. Para eso existe style_font(), que es la única
# forma que deben usar los menús.
# Nota: NO usar variation_embolden — en Godot 4.7 la propiedad de FontFile es
# de solo lectura; el bold real se consigue cargando el TTF Bold.

const FONTS_DIR := "res://assets/ui/fonts/"

static func make_font(size: int, bold := false) -> Font:
	var path := FONTS_DIR + ("DejaVuSans-Bold.ttf" if bold else "DejaVuSans.ttf")
	if not ResourceLoader.exists(path):
		return null
	var font_data = load(path)
	if font_data is Font:
		return font_data.duplicate()
	return null

# Aplica fuente + tamaño a un control en un solo paso. Los menús NO deben
# llamar a add_theme_font_override sin el correspondiente font_size override.
static func style_font(c: Control, size: int, bold := false):
	c.add_theme_font_override("font", make_font(size, bold))
	c.add_theme_font_size_override("font_size", size)
