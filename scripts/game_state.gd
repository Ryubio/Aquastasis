extends Node
## GameState (autoload): owns the running CrisisSim, advances it with a fixed-step
## accumulator scaled by game speed, applies player actions (field operations, policy
## adoptions, event choices, bubble pickups) and republishes every result on EventBus.

const CrisisSim := preload("res://scripts/crisis_sim.gd")
const RegionData := preload("res://scripts/region.gd")

## Sim toast keys that may be newer than the string table: if I18n lacks one, the toast
## uses this older key with a close meaning instead of showing the raw key.
const TOAST_KEY_FALLBACK := {"toast.depleted": "toast.low_resources"}

var sim: CrisisSim = null
var running: bool = false          # a game is in progress (false in menus and after game over)
var menu_paused: bool = false      # pause menu is open (kept for Phase 1 callers)
var speed_index: int = 1           # index into Balance.SPEEDS (0 = pause)
var selected_region: String = ""
var game_seed: int = 0
var selected_difficulty: String = "commander"

var _last_speed: int = 1
var _accumulator: float = 0.0
var _pause_reasons: Dictionary = {}   # "menu" | "tree" | "event" | "summit" | "tutorial" -> true; any reason pauses time


func _ready() -> void:
	EventBus.region_selected.connect(_on_region_selected)


## Starts a fresh game. p_seed < 0 picks a random seed (logged for reproducibility).
func new_game(p_seed: int = -1, p_difficulty: String = "") -> void:
	Engine.time_scale = 1.0
	game_seed = p_seed if p_seed >= 0 else randi()
	if p_difficulty != "":
		selected_difficulty = p_difficulty
	print("GameState: new game, seed ", game_seed, " diff: ", selected_difficulty)
	sim = CrisisSim.new(game_seed, selected_difficulty)
	running = true
	menu_paused = false
	_pause_reasons.clear()
	_accumulator = 0.0
	_last_speed = 1
	EventBus.difficulty_changed.emit(selected_difficulty)
	EventBus.game_started.emit()
	_publish_all()
	EventBus.toast.emit("toast.game_start", {}, 1)


func stop_game() -> void:
	running = false
	menu_paused = false
	_pause_reasons.clear()
	_accumulator = 0.0


func set_speed(index: int) -> void:
	Engine.time_scale = 1.0
	speed_index = clampi(index, 0, Balance.SPEEDS.size() - 1)
	if speed_index > 0:
		_last_speed = speed_index
	EventBus.speed_changed.emit(speed_index)
	EventBus.paused_changed.emit(is_paused())


func toggle_pause() -> void:
	if speed_index == 0:
		set_speed(_last_speed)
	else:
		set_speed(0)


func set_menu_paused(on: bool) -> void:
	menu_paused = on
	set_pause_reason("menu", on)


## Modal views stop time while they are open: "menu", "tree", "event".
func set_pause_reason(reason: String, on: bool) -> void:
	if on:
		_pause_reasons[reason] = true
	else:
		_pause_reasons.erase(reason)
	EventBus.paused_changed.emit(is_paused())


func has_pause_reason(reason: String) -> bool:
	return _pause_reasons.has(reason)


func is_paused() -> bool:
	return speed_index == 0 or not _pause_reasons.is_empty() or not running


## Sub-tick accumulator progress 0..1 for the live HUD tick progress bar.
func tick_progress() -> float:
	if sim == null or not running:
		return 0.0
	return clampf(_accumulator / maxf(Balance.TICK_SECONDS, 0.001), 0.0, 1.0)


func _process(delta: float) -> void:
	if _pause_reasons.has("event") and (sim == null or sim.pending_event.is_empty()):
		_pause_reasons.erase("event")
		EventBus.paused_changed.emit(is_paused())
	if sim == null or not running or not _pause_reasons.is_empty():
		return
	var speed: float = Balance.SPEEDS[speed_index]
	if speed <= 0.0:
		return
	_accumulator += delta * speed
	var steps: int = 0
	while running and _pause_reasons.is_empty() and _accumulator >= Balance.TICK_SECONDS and steps < Balance.MAX_TICKS_PER_FRAME:
		_accumulator -= Balance.TICK_SECONDS
		steps += 1
		_do_tick()
	if steps >= Balance.MAX_TICKS_PER_FRAME or not _pause_reasons.is_empty():
		_accumulator = 0.0  # drop the backlog after a frame spike or when an event card stops time


func _do_tick() -> void:
	var result: Dictionary = sim.step()
	_publish_result(result)
	_publish_all()
	if bool(result.get("game_over", false)):
		running = false
		_pause_reasons.clear()
		AudioSynth.set_siren(false)
		AudioSynth.set_heartbeat(false)
		var stats: Dictionary = sim.snapshot()
		var reason: String = str(result.get("reason", ""))
		stats["reason"] = reason
		EventBus.game_over.emit(bool(result.get("won", false)), reason, stats)
		return
	var ev: Dictionary = result.get("event", {})
	if not ev.is_empty():
		set_pause_reason("event", true)
		EventBus.event_triggered.emit(str(ev.get("id", "")))
	var summit: Dictionary = result.get("summit", {})
	if not summit.is_empty():
		set_pause_reason("summit", true)
		EventBus.summit_triggered.emit(summit)


# --- Field operations -------------------------------------------------------------------

func can_perform(action_id: String, region_id: String) -> bool:
	return sim != null and running and sim.can_perform(action_id, region_id)


func can_afford(action_id: String) -> bool:
	return sim != null and sim.can_afford(action_id)


## {"budget": float, "political": float, "science": float} (missing keys = 0). Includes the
## running cost modifiers once a game is on.
func action_cost(action_id: String) -> Dictionary:
	if sim != null:
		return sim.action_cost(action_id)
	var def: Dictionary = Balance.ACTIONS.get(action_id, {})
	return def.get("cost", {})


## Remaining cooldown in seconds at 1x speed (0 = ready).
func action_cooldown_left(action_id: String, region_id: String) -> float:
	if sim == null:
		return 0.0
	return float(sim.cooldown_left_ticks(action_id, region_id)) * Balance.TICK_SECONDS


## Remaining cooldown as a fraction 0..1 (1 = just used).
func action_cooldown_fraction(action_id: String, region_id: String) -> float:
	if sim == null:
		return 0.0
	var def: Dictionary = Balance.ACTIONS.get(action_id, {})
	var total: int = int(def.get("cooldown_ticks", 1))
	return clampf(float(sim.cooldown_left_ticks(action_id, region_id)) / float(maxi(total, 1)), 0.0, 1.0)


func perform_action(action_id: String, region_id: String) -> bool:
	if not can_perform(action_id, region_id) or has_pause_reason("event"):
		return false
	var result: Dictionary = sim.perform(action_id, region_id)
	if not bool(result.get("ok", false)):
		return false
	AudioSynth.play_click()
	EventBus.action_performed.emit(action_id, region_id)
	_publish_result(result)
	_publish_all()
	return true


# --- Policy tree --------------------------------------------------------------------------

## "adopted" | "available" (prerequisites met) | "locked". "" before the first game.
func node_state(node_id: String) -> String:
	if sim == null:
		return ""
	return sim.node_state(node_id)


## 0..1 implementation progress of an adopted node (1 = full effect).
func node_ramp(node_id: String) -> float:
	if sim == null:
		return 0.0
	return sim.node_ramp(node_id)


## Current cost with modifiers: {"budget", "political", "science"} (missing keys = 0).
func node_cost(node_id: String) -> Dictionary:
	if sim == null:
		return {}
	return sim.node_cost(node_id)


func can_adopt(node_id: String) -> bool:
	return sim != null and running and not has_pause_reason("event") and sim.can_adopt(node_id)


func adopt_node(node_id: String) -> bool:
	if not can_adopt(node_id):
		return false
	var result: Dictionary = sim.adopt(node_id)
	if not bool(result.get("ok", false)):
		return false
	AudioSynth.play_policy_adopt()
	EventBus.node_adopted.emit(node_id)
	_publish_result(result)
	_publish_all()
	return true


func adopted_nodes() -> Array:
	if sim == null:
		return []
	return sim.adopted_nodes()


# --- Crisis evolution ------------------------------------------------------------------------

## Ids of the resistances the crisis has evolved and the player has not cured.
func active_evolutions() -> Array:
	if sim == null:
		return []
	return sim.active_evolutions()


func can_synthesize_counter(evo_id: String) -> bool:
	return sim != null and running and not has_pause_reason("event") and sim.can_synthesize_counter(evo_id)


func synthesize_counter(evo_id: String) -> bool:
	if not can_synthesize_counter(evo_id):
		return false
	var res: Dictionary = sim.synthesize_counter(evo_id)
	if not bool(res.get("ok", false)):
		return false
	AudioSynth.play_cured()
	_publish_result(res)
	_publish_all()
	return true


func can_perform_project(project_id: String) -> bool:
	return sim != null and running and not has_pause_reason("event") and sim.can_perform_project(project_id)


func project_cooldown_left_ticks(project_id: String) -> int:
	if sim == null:
		return 0
	return sim.project_cooldown_left_ticks(project_id)


func perform_project(project_id: String) -> bool:
	if not can_perform_project(project_id):
		return false
	var res: Dictionary = sim.perform_project(project_id)
	if not bool(res.get("ok", false)):
		return false
	_publish_result(res)
	_publish_all()
	return true


## {"shares": {branch: 0..1}, "threshold": float, "moves": int, "min_moves": int} - how close
## the player's recent strategy is to provoking a resistance.
func evolution_pressure() -> Dictionary:
	if sim == null:
		return {}
	return sim.evolution_pressure()


# --- Decision events ---------------------------------------------------------------------------

## {"id": String, "region": String} while a card is waiting for a choice, else {}.
func current_event() -> Dictionary:
	if sim == null:
		return {}
	return sim.pending_event.duplicate()


func can_choose(choice_index: int) -> bool:
	return sim != null and running and sim.can_choose(choice_index)


func resolve_event(choice_index: int) -> bool:
	if not can_choose(choice_index):
		return false
	var event_id: String = str(sim.pending_event.get("id", ""))
	var result: Dictionary = sim.resolve_event(choice_index)
	if not bool(result.get("ok", false)):
		return false
	set_pause_reason("event", false)
	EventBus.event_resolved.emit(event_id, choice_index)
	_publish_result(result)
	_publish_all()
	return true


## Dev / demo hook (main.gd --event=<id>): shows that event card now, as if it was rolled.
func debug_force_event(event_id: String) -> void:
	if sim == null or not running:
		return
	var ev: Dictionary = sim.force_event(event_id)
	if ev.is_empty():
		return
	set_pause_reason("event", true)
	EventBus.event_triggered.emit(str(ev.get("id", "")))


# --- Data bubbles ---------------------------------------------------------------------------------

func active_bubbles() -> Array:
	if sim == null:
		return []
	return sim.active_bubbles()


func collect_bubble(bubble_id: int) -> bool:
	if sim == null or not running:
		return false
	var result: Dictionary = sim.collect_bubble(bubble_id)
	if not bool(result.get("ok", false)):
		return false
	var b_kind: String = str(result.get("kind", ""))
	AudioSynth.play_bubble(b_kind == "science")
	EventBus.bubble_collected.emit(bubble_id, b_kind, float(result.get("amount", 0.0)))
	var snap: Dictionary = get_snapshot()
	EventBus.resources_changed.emit(float(snap.get("budget", 0.0)), float(snap.get("political", 0.0)), float(snap.get("science", 0.0)))
	return true


# --- COP31 Summits -------------------------------------------------------------------

func current_summit() -> Dictionary:
	if sim == null:
		return {}
	return sim.pending_summit.duplicate(true)


func resolve_summit(choice_idx: int) -> bool:
	if sim == null or not running:
		return false
	var res: Dictionary = sim.resolve_summit(choice_idx)
	if not bool(res.get("ok", false)):
		return false
	set_pause_reason("summit", false)
	EventBus.summit_resolved.emit(choice_idx)
	_publish_result(res)
	_publish_all()
	AudioSynth.play_policy_adopt()
	return true


# --- Read access for views ------------------------------------------------------------

## See docs/ARCHITECTURE.md "Snapshot" for keys. Empty before the first game.
func get_snapshot() -> Dictionary:
	if sim == null:
		return {}
	var snap: Dictionary = sim.snapshot()
	snap["speed_index"] = speed_index
	return snap


## See docs/ARCHITECTURE.md "Region dictionary" for keys. Empty if unknown.
func get_region(region_id: String) -> Dictionary:
	if sim == null:
		return {}
	return sim.region_dict(region_id)


## A copy of the region id list (the constant itself is read-only).
func region_ids() -> Array:
	return RegionData.IDS.duplicate()


## [[tick, sea_health, crisis], ...] sampled every Balance.HISTORY_EVERY ticks (live chart).
func get_history() -> Array:
	if sim == null:
		return []
	return sim.history.duplicate()


# --- Publishing -----------------------------------------------------------------------

func _publish_all() -> void:
	if sim == null:
		return
	for rid in RegionData.IDS:
		var region_id: String = rid
		EventBus.region_changed.emit(region_id, sim.region_dict(region_id))
	var snap: Dictionary = get_snapshot()
	EventBus.resources_changed.emit(float(snap.get("budget", 0.0)), float(snap.get("political", 0.0)), float(snap.get("science", 0.0)))
	EventBus.tick_done.emit(snap)
	if running:
		var defcon: int = sim.defcon_level()
		AudioSynth.set_siren(defcon <= 1)
		AudioSynth.set_heartbeat(sim.sea_health() < 30.0)


## Re-emits every list of a sim step / perform / adopt / resolve result.
func _publish_result(result: Dictionary) -> void:
	var spreads: Array = result.get("spreads", [])
	for s in spreads:
		var pair: Array = s
		EventBus.spread_happened.emit(str(pair[0]), str(pair[1]))
	var toasts: Array = result.get("toasts", [])
	for t in toasts:
		var item: Array = t
		var args: Dictionary = item[1]
		var key: String = str(item[0])
		if TOAST_KEY_FALLBACK.has(key) and not I18n.has_key(key):
			key = str(TOAST_KEY_FALLBACK[key])
		EventBus.toast.emit(key, args, int(item[2]))
	var news_items: Array = result.get("news", [])
	for n in news_items:
		var item: Array = n
		var args: Dictionary = item[1]
		EventBus.news.emit(str(item[0]), args, int(item[2]))
	var evolved: Array = result.get("evolutions", [])
	for e in evolved:
		EventBus.evolution_happened.emit(str(e))
	var cured: Array = result.get("cured", [])
	for c in cured:
		EventBus.evolution_cured.emit(str(c))
	var spawned: Array = result.get("bubbles_spawned", [])
	for b in spawned:
		var bubble: Dictionary = b
		EventBus.bubble_spawned.emit(bubble)
	var expired: Array = result.get("bubbles_expired", [])
	for x in expired:
		EventBus.bubble_expired.emit(int(x))


func _on_region_selected(region_id: String) -> void:
	selected_region = region_id
