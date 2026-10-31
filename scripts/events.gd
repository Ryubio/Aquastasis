extends RefCounted
## Events: the 10-12 two-choice decision cards (oil spill, heatwave, COP31 summits, ...) as
## DATA. crisis_sim.gd schedules them and applies choice effects; ui_event_card.gd shows
## them. Schema and effect vocabulary: docs/ARCHITECTURE.md section 11.

## One Dictionary per event (content module fills this):
## {"id", "weight", "min_tick", "max_tick", "at_tick" (-1 = random), "once", "region_rule"
##  ("random" | "worst" | "best" | "hero" | "none" | <region id>), "icon", "title_key",
##  "text_key", "choices": [{"label_key", "result_key", "cost" {...}, "effects" [...],
##  "tone" (-1 | 0 | 1)}, {...}]}
const EVENTS := []


static func all_events() -> Array:
	return EVENTS


static func event_def(event_id: String) -> Dictionary:
	for e in EVENTS:
		var def: Dictionary = e
		if str(def.get("id", "")) == event_id:
			return def
	return {}
