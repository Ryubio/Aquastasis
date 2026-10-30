extends RefCounted
## CrisisSim: STUB with the frozen public API (see docs/ARCHITECTURE.md "CrisisSim").
## Pure logic (no nodes, no autoloads) so scripts/sim_test.gd can run it headless.
## The simulation module replaces the bodies; keep every public signature.

const B := preload("res://scripts/balance.gd")
const RegionData := preload("res://scripts/region.gd")

var regions: Dictionary = {}       # region id -> RegionData
var tick: int = 0
var temperature: float = B.TEMP_START
var budget: float = B.BUDGET_START
var political: float = B.POLITICAL_START
var science: float = B.SCIENCE_START
var actions_used: int = 0
var branch_usage: Dictionary = {}  # branch -> count (Phase 2 crisis evolution)
var over: bool = false
var won: bool = false
var reason: String = ""
var rng := RandomNumberGenerator.new()


func _init(p_seed: int = B.DEFAULT_SEED) -> void:
	reset(p_seed)


func reset(p_seed: int) -> void:
	rng.seed = p_seed
	regions.clear()
	for rid in RegionData.IDS:
		var region_id: String = rid
		regions[region_id] = RegionData.new(region_id)
	tick = 0
	temperature = B.TEMP_START
	budget = B.BUDGET_START
	political = B.POLITICAL_START
	science = B.SCIENCE_START
	actions_used = 0
	branch_usage = {}
	over = false
	won = false
	reason = ""


## Advances one tick. Returns {"spreads": [[from_id, to_id], ...],
## "toasts": [[text_key, args, severity], ...], "game_over": bool, "won": bool, "reason": String}
func step() -> Dictionary:
	tick += 1
	return {"spreads": [], "toasts": [], "game_over": false, "won": false, "reason": ""}


func year() -> float:
	return float(B.START_YEAR) + float(B.END_YEAR - B.START_YEAR) * float(tick) / float(B.TOTAL_TICKS)


func sea_health() -> float:
	return 50.0


func avg_crisis() -> float:
	return 50.0


func avg_awareness() -> float:
	return 25.0


func snapshot() -> Dictionary:
	var y: float = year()
	return {
		"tick": tick,
		"year": y,
		"year_int": int(floor(y)),
		"years_left": maxi(B.END_YEAR - int(floor(y)), 0),
		"progress": clampf(float(tick) / float(B.TOTAL_TICKS), 0.0, 1.0),
		"temperature": temperature,
		"sea_health": sea_health(),
		"crisis": avg_crisis(),
		"awareness": avg_awareness(),
		"budget": budget,
		"political": political,
		"science": science,
		"actions_used": actions_used,
	}


func region_dict(region_id: String) -> Dictionary:
	if not regions.has(region_id):
		return {}
	var r: RegionData = regions[region_id]
	return r.to_dict()


func can_afford(action_id: String) -> bool:
	return B.ACTIONS.has(action_id)


func can_perform(action_id: String, region_id: String) -> bool:
	return not over and regions.has(region_id) and can_afford(action_id) and cooldown_left_ticks(action_id, region_id) == 0


func cooldown_left_ticks(_action_id: String, _region_id: String) -> int:
	return 0


## Returns {"ok": bool, "spreads": [], "toasts": [[text_key, args, severity], ...]}
func perform(action_id: String, region_id: String) -> Dictionary:
	if not can_perform(action_id, region_id):
		return {"ok": false, "spreads": [], "toasts": []}
	actions_used += 1
	return {"ok": true, "spreads": [], "toasts": []}
