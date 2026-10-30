extends Node
## GameState (autoload): owns the running CrisisSim, advances it with a fixed-step
## accumulator scaled by game speed, applies player actions and republishes every
## result on EventBus. Views read state through get_snapshot() / get_region().

const CrisisSim := preload("res://scripts/crisis_sim.gd")
const RegionData := preload("res://scripts/region.gd")

var sim: CrisisSim = null
var running: bool = false          # a game is in progress (false in menus and after game over)
var menu_paused: bool = false      # pause menu is open
var speed_index: int = 1           # index into Balance.SPEEDS (0 = pause)
var selected_region: String = ""
var game_seed: int = 0

var _last_speed: int = 1
var _accumulator: float = 0.0


func _ready() -> void:
	EventBus.region_selected.connect(_on_region_selected)


## Starts a fresh game. p_seed < 0 picks a random seed (logged for reproducibility).
func new_game(p_seed: int = -1) -> void:
	game_seed = p_seed if p_seed >= 0 else randi()
	print("GameState: new game, seed ", game_seed)
	sim = CrisisSim.new(game_seed)
	running = true
	menu_paused = false
	_accumulator = 0.0
	_last_speed = 1
	EventBus.game_started.emit()
	_publish_all()
	EventBus.toast.emit("toast.game_start", {}, 1)


func stop_game() -> void:
	running = false
	menu_paused = false
	_accumulator = 0.0


func set_speed(index: int) -> void:
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
	EventBus.paused_changed.emit(is_paused())


func is_paused() -> bool:
	return speed_index == 0 or menu_paused or not running


func _process(delta: float) -> void:
	if sim == null or not running or menu_paused:
		return
	var speed: float = Balance.SPEEDS[speed_index]
	if speed <= 0.0:
		return
	_accumulator += delta * speed
	var steps: int = 0
	while running and _accumulator >= Balance.TICK_SECONDS and steps < Balance.MAX_TICKS_PER_FRAME:
		_accumulator -= Balance.TICK_SECONDS
		steps += 1
		_do_tick()
	if steps >= Balance.MAX_TICKS_PER_FRAME:
		_accumulator = 0.0  # drop the backlog after a frame spike instead of spiralling


func _do_tick() -> void:
	var result: Dictionary = sim.step()
	_publish_result(result)
	_publish_all()
	if bool(result.get("game_over", false)):
		running = false
		var stats: Dictionary = sim.snapshot()
		var reason: String = str(result.get("reason", ""))
		stats["reason"] = reason
		EventBus.game_over.emit(bool(result.get("won", false)), reason, stats)


# --- Player actions ----------------------------------------------------------------

func can_perform(action_id: String, region_id: String) -> bool:
	return sim != null and running and sim.can_perform(action_id, region_id)


func can_afford(action_id: String) -> bool:
	return sim != null and sim.can_afford(action_id)


## {"budget": float, "political": float, "science": float} (missing keys = 0)
func action_cost(action_id: String) -> Dictionary:
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
	if not can_perform(action_id, region_id):
		return false
	var result: Dictionary = sim.perform(action_id, region_id)
	if not bool(result.get("ok", false)):
		return false
	EventBus.action_performed.emit(action_id, region_id)
	_publish_result(result)
	_publish_all()
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


# --- Publishing -----------------------------------------------------------------------

func _publish_all() -> void:
	for rid in RegionData.IDS:
		var region_id: String = rid
		EventBus.region_changed.emit(region_id, sim.region_dict(region_id))
	var snap: Dictionary = get_snapshot()
	EventBus.resources_changed.emit(float(snap.get("budget", 0.0)), float(snap.get("political", 0.0)), float(snap.get("science", 0.0)))
	EventBus.tick_done.emit(snap)


## Re-emits the "spreads" and "toasts" lists of a sim step/perform result.
func _publish_result(result: Dictionary) -> void:
	var spreads: Array = result.get("spreads", [])
	for s in spreads:
		var pair: Array = s
		EventBus.spread_happened.emit(str(pair[0]), str(pair[1]))
	var toasts: Array = result.get("toasts", [])
	for t in toasts:
		var item: Array = t
		var args: Dictionary = item[1]
		EventBus.toast.emit(str(item[0]), args, int(item[2]))


func _on_region_selected(region_id: String) -> void:
	selected_region = region_id
