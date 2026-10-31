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

# --- Phase 2: policy tree, crisis evolution, decision events, data bubbles, news ---
signal node_adopted(node_id: String)
signal evolution_happened(evolution_id: String)
signal evolution_cured(evolution_id: String)
signal event_triggered(event_id: String)                 # details: GameState.current_event()
signal event_resolved(event_id: String, choice_index: int)
signal bubble_spawned(bubble: Dictionary)                # {"id", "kind", "region", "amount", "ttl"}
signal bubble_collected(bubble_id: int, kind: String, amount: float)
signal bubble_expired(bubble_id: int)
## tone: -1 alarming, 0 neutral, 1 hopeful. Args follow the toast convention (values that are
## i18n keys get translated by the displayer).
signal news(text_key: String, args: Dictionary, tone: int)
signal tree_toggle_requested()                           # any view asks main.gd to open/close the tree
signal tree_toggled(is_open: bool)                       # the tree modal opened / closed
signal summit_triggered(summit_data: Dictionary)
signal summit_resolved(choice_idx: int)
signal tutorial_requested()
signal difficulty_changed(diff_id: String)
