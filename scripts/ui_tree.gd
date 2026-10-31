extends Control
## UITree: STUB with the frozen public API (see docs/ARCHITECTURE.md section 11).
## The tree UI module replaces this with the policy tree modal (4 branches, connected
## nodes, node details with real-world facts, adopt button, evolution pressure).

var _open: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func open() -> void:
	if _open:
		return
	_open = true
	visible = true
	GameState.set_pause_reason("tree", true)
	EventBus.tree_toggled.emit(true)


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	GameState.set_pause_reason("tree", false)
	EventBus.tree_toggled.emit(false)


func toggle() -> void:
	if _open:
		close()
	else:
		open()


func is_open() -> bool:
	return _open
