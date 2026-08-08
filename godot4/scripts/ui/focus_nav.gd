extends RefCounted
# FocusNav — utilidades de navegación de foco (D-pad/TV) para menús y hubs.
# Patrón consistente: primer botón habilitado toma el foco, los scrolls siguen
# al foco, y los controles deshabilitados NO son enfocables (FOCUS_NONE) para
# que el D-pad los salte.
# Port a Godot 4: extends Reference -> RefCounted, is_connected/connect ->
# Signal.is_connected / Signal.connect (con bind).

static func grab_first(root: Node) -> bool:
	if root is Button and root.visible and not root.disabled:
		root.grab_focus()
		return true
	for ch in root.get_children():
		if grab_first(ch):
			return true
	return false

static func set_skippable(btn: Button, disabled: bool):
	btn.disabled = disabled
	btn.focus_mode = Control.FOCUS_NONE if disabled else Control.FOCUS_ALL

static func enable_scroll_follow(scroll: ScrollContainer):
	if scroll == null:
		return
	if scroll.get("follow_focus") != null:
		scroll.follow_focus = true
	for ch in scroll.get_children():
		if ch is Control and not ch is ScrollBar:
			_wire_ensure_visible(scroll, ch)

static func _wire_ensure_visible(scroll: ScrollContainer, root: Node):
	for ch in root.get_children():
		if ch is Button:
			var cb := Callable(scroll, "ensure_control_visible").bind(ch)
			if not ch.focus_entered.is_connected(cb):
				ch.focus_entered.connect(cb)
		if ch.get_child_count() > 0:
			_wire_ensure_visible(scroll, ch)

static func popup_open(root: Node) -> bool:
	for ch in root.get_children():
		if (ch is Popup or ch is Window) and ch.visible:
			return true
		if ch.get_child_count() > 0 and popup_open(ch):
			return true
	return false
