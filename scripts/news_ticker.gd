extends Control
## NewsTicker: STUB (see docs/ARCHITECTURE.md section 11). The HUD module replaces this with
## the localized scrolling marquee inside the HUD's 32 px top strip, fed by EventBus.news
## and by ambient headlines generated from live game state.


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Drops all queued headlines (new game).
func clear() -> void:
	pass
