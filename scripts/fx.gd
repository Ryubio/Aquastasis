extends Control
## FX: STUB with the frozen public API (see docs/ARCHITECTURE.md section 11).
## The HUD module replaces this with the screen-space data bubble layer (pooled clickable
## Science / Political Support bubbles projected from the 3D map, pop bursts, expiry).

const MapBuilder := preload("res://scripts/map_builder.gd")

var map: MapBuilder = null   # set by main.gd before the first game; used to project bubbles


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Removes every bubble immediately (new game, main menu, game over).
func clear_all() -> void:
	pass
