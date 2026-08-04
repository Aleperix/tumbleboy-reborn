extends Reference
# ui_fonts — fuentes compartidas para toda la interfaz.
# Un DynamicFont SIN font_data no renderiza nada en Godot 3; por eso las
# fuentes se cargan desde un .ttf empaquetado (mismo resultado en desktop,
# Android y Android TV).

const FONTS_DIR := "res://assets/ui/fonts/"

static func make_font(size: int, bold := false) -> DynamicFont:
	var path := FONTS_DIR + ("DejaVuSans-Bold.ttf" if bold else "DejaVuSans.ttf")
	var font_data = load(path)
	var f := DynamicFont.new()
	f.font_data = font_data
	f.size = size
	return f
