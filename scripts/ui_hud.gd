extends Control
## UIHud: STUB with the frozen public API (see docs/ARCHITECTURE.md "UIHud").
## The UI module replaces this with the in-game HUD (top bar, basin status, region
## panel with field operations, toasts). Keep every public signature.


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_hud() -> void:
	visible = true


func hide_hud() -> void:
	visible = false
