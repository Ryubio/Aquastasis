extends Control
## UIEventCard: STUB with the frozen public API (see docs/ARCHITECTURE.md section 11).
## The tree UI module replaces this with the two-choice decision card that appears on
## EventBus.event_triggered, resolves through GameState.resolve_event() and shows the result.


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func is_open() -> bool:
	return visible


## Hides the card immediately (game over, main menu). Does not resolve the event.
func close_now() -> void:
	visible = false
