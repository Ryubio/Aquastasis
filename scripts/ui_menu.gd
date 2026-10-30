extends Control
## UIMenu: STUB with the frozen public API (see docs/ARCHITECTURE.md "UIMenu").
## The UI module replaces this with the cinematic main menu, pause/settings menu and
## win/lose screens. Keep every public signal and method.

signal start_requested()
signal resume_requested()
signal restart_requested()
signal main_menu_requested()
signal quit_requested()

var _mode: String = ""   # "", "main", "pause", "end"


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_main() -> void:
	_mode = "main"
	visible = true


func show_pause() -> void:
	_mode = "pause"
	visible = true


func show_end(_won: bool, _reason: String, _stats: Dictionary) -> void:
	_mode = "end"
	visible = true


func hide_all() -> void:
	_mode = ""
	visible = false


func is_open() -> bool:
	return _mode != ""


func is_pause_open() -> bool:
	return _mode == "pause"
