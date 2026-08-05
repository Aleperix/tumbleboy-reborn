extends Reference
# FocusGrab — devuelve el foco al primer botón de una lista tras 2 frames.
# Los paneles reconstruyen sus filas con queue_free; esperar un par de frames
# garantiza que los nodos viejos hayan desaparecido antes de agarrar el foco
# (si no, el foco cae en un botón pendiente de liberar y se pierde al liberarlo).

const FocusNav = preload("res://scripts/ui/focus_nav.gd")

var tree: SceneTree
var root: Node
var fallback: Control
var steps := 0

func start(p_tree: SceneTree, p_root: Node, p_fallback: Control):
	cancel()
	tree = p_tree
	root = p_root
	fallback = p_fallback
	steps = 2
	if not tree.is_connected("idle_frame", self, "_tick"):
		tree.connect("idle_frame", self, "_tick")

func cancel():
	if tree != null and tree.is_connected("idle_frame", self, "_tick"):
		tree.disconnect("idle_frame", self, "_tick")
	steps = 0

func _tick():
	steps -= 1
	if steps > 0:
		return
	tree.disconnect("idle_frame", self, "_tick")
	steps = 0
	if not is_instance_valid(root) or not root.is_inside_tree():
		return
	if FocusNav.grab_first(root):
		return
	if fallback != null and is_instance_valid(fallback) and fallback.is_inside_tree():
		fallback.grab_focus()
