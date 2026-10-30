extends Node
## EventBus (autoload): the only channel between the simulation and the views.
## Views never call each other; they listen here. Payload dictionaries are documented
## in docs/ARCHITECTURE.md ("Signals and payloads").

# --- Game flow ---
signal game_started()
signal game_over(won: bool, reason: String, stats: Dictionary)
signal paused_changed(paused: bool)
signal speed_changed(speed_index: int)

# --- Simulation output ---
signal tick_done(snapshot: Dictionary)
signal region_changed(region_id: String, data: Dictionary)
signal spread_happened(from_id: String, to_id: String)
signal resources_changed(budget: float, political: float, science: float)
signal action_performed(action_id: String, region_id: String)

# --- Map interaction ---
signal region_hovered(region_id: String)
signal region_selected(region_id: String)

# --- Feedback / UI ---
## severity: 0 = info, 1 = good news, 2 = warning, 3 = alarm (alarm also shakes the camera)
signal toast(text_key: String, args: Dictionary, severity: int)
signal language_changed(lang: String)

# --- Phase 2 (declared now so listeners can connect early) ---
signal event_triggered(event_id: String)
signal evolution_happened(evolution_id: String)
