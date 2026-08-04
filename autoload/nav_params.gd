extends Node
# NavParams — parámetros de navegación entre hubs.
# Un hub no puede usar yield+configure al cambiar de escena: su nodo se libera
# al hacer el swap y la coroutine muere antes de configurar la escena nueva.
# Este autoload sobrevive al cambio de escena y transporta la petición.

var pending_picker: Array = []   # [mode, id, intent] para SlotPicker
var open_file: String = ""       # archivo a abrir en TumbleBoyEditor
var open_pack_panel: bool = false # abrir el panel de packs en TumbleBoyEditor
var open_draft: bool = false     # abrir el borrador del editor

func clear():
	pending_picker = []
	open_file = ""
	open_pack_panel = false
	open_draft = false
