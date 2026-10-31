extends RefCounted
## CrisisSim: the Marine Health Crisis model (regions, routes, climate, resources, field operations,
## policy tree, crisis evolution, decision events, data bubbles, news, win/lose). Pure logic: no nodes,
## no autoloads, seeded RNGs only, so GameState and scripts/sim_test.gd run the exact same rules.

const B := preload("res://scripts/balance.gd")
const RegionData := preload("res://scripts/region.gd")
const TechTree := preload("res://scripts/tech_tree.gd")
const Events := preload("res://scripts/events.gd")

## Modifier vocabulary (docs/ARCHITECTURE.md 11.2): multipliers start at 1.0, additive terms at 0.0.
const MUL_KEYS := [
	"inflow_mult", "base_pollution_mult", "neighbor_pressure_mult", "spread_chance_mult",
	"spread_damage_mult", "heat_stress_mult", "temp_rise_mult", "coral_heat_mult",
	"coral_recovery_mult", "seagrass_recovery_mult", "fishing_mult", "fish_regen_mult",
	"protect_effect_mult", "aware_effect_mult", "protect_decay_mult", "awareness_decay_mult",
	"budget_income_mult", "political_income_mult", "science_income_mult", "cleanup_power_mult",
	"patrol_power_mult", "campaign_power_mult", "action_cost_mult", "node_cost_mult",
	"bubble_rate_mult", "bubble_value_mult",
]
const ADD_KEYS := [
	"budget_per_tick", "political_per_tick", "science_per_tick", "blue_carbon",
	"protection_floor", "awareness_floor",
]
const SPREAD_NEWS_VARIANTS := 3    # sim.news.spread.0 .. 2
const ALERT_NEWS_VARIANTS := 2     # sim.news.critical.0 .. 1, sim.news.recovered.0 .. 1

# --- Public state (frozen API, see docs/ARCHITECTURE.md "CrisisSim") ---------------------
var regions: Dictionary = {}       # region id -> RegionData
var tick: int = 0
var temperature: float = B.TEMP_START
var budget: float = B.BUDGET_START
var political: float = B.POLITICAL_START
var science: float = B.SCIENCE_START
var actions_used: int = 0
var branch_usage: Dictionary = {}  # branch -> count of field operations
var over: bool = false
var won: bool = false
var reason: String = ""
var rng := RandomNumberGenerator.new()   # spread rolls
var pending_event: Dictionary = {}       # {"id": String, "region": String} while a card waits
var history: Array = []                  # [[tick, sea_health, crisis], ...] every B.HISTORY_EVERY ticks

# --- Extra read-only statistics (end screen, sim_test) --------------------------------------
var spread_count: int = 0
var first_spread_tick: int = -1    # tick of the first spread, -1 = none yet
var first_alarm_tick: int = -1     # tick of the first "region critical" alarm, -1 = none yet
var peak_crisis: float = 0.0       # highest basin-average crisis seen
var cards_seen: int = 0            # decision cards shown (random, summits and forced)
var evolution_log: Array = []      # [[tick, evolution_id], ...] in the order they happened
var event_log: Array = []          # [[tick, event_id, choice_index], ...]
var bubbles_spawned_total: int = 0
var bubbles_collected_total: int = 0

# --- Internals ----------------------------------------------------------------------------
var _links: Dictionary = {}              # region id -> Array of {"id": String, "w": float}
var _route_cooldown := PackedInt32Array()  # per RegionData.ROUTES index: ticks until it may spread again
var _ready_at: Dictionary = {}           # "action|region" -> tick at which the action is ready again
var _band: Dictionary = {}               # region id -> "critical" | "mid" | "recovered" (alert hysteresis)
var _toast_last: Dictionary = {}         # toast kind -> tick it was last emitted
var _news_last: Dictionary = {}          # news kind -> tick it was last emitted
var _next_milestone: int = 0             # index into B.TEMP_MILESTONES
var _depleted_ticks: int = 0             # consecutive ticks with budget AND political depleted
var _low_warned: bool = false            # low-resources warning already shown for this dip

var _rng_events := RandomNumberGenerator.new()    # card timing, card choice, card region
var _rng_bubbles := RandomNumberGenerator.new()   # bubble timing, kind, region, amount
var _mods: Dictionary = {}               # modifier key -> current value (recomputed every tick)
var _node_defs: Dictionary = {}          # node id -> tech_tree.gd node Dictionary
var _evo_defs: Dictionary = {}           # evolution id -> tech_tree.gd evolution Dictionary
var _event_defs: Dictionary = {}         # event id -> events.gd event Dictionary
var _adopted: Dictionary = {}            # node id -> tick it was adopted
var _adopted_order: Array = []           # node ids in adoption order
var _moves: Array = []                   # branches of the last B.EVO_WINDOW player moves
var _adapt: Dictionary = {}              # branch -> ticks of sustained one-sided play (see _update_adaptation)
var _adapt_warned: Dictionary = {}       # branch -> true once the "crisis is adapting" toast ran
var _active_evos: Array = []             # evolution ids in force (not cured)
var _evolved: Dictionary = {}            # evolution id -> tick it evolved (each evolves once)
var _immune: Dictionary = {}             # evolution id -> true once a counter node was adopted
var _timed: Array = []                   # event effects: {"op", "key", "value", "until"} (-1 = forever)
var _seen_events: Dictionary = {}        # event id -> tick it was shown
var _next_event_tick: int = 0            # earliest tick for the next random card
var _bubbles: Array = []                 # {"id", "kind", "region", "amount", "ttl", "born"}
var _next_bubble_id: int = 1


func _init(p_seed: int = B.DEFAULT_SEED) -> void:
	reset(p_seed)


func reset(p_seed: int) -> void:
	rng.seed = p_seed
	_rng_events.seed = hash("events|%d" % p_seed)
	_rng_bubbles.seed = hash("bubbles|%d" % p_seed)
	regions.clear()
	_links.clear()
	_band.clear()
	for rid in RegionData.IDS:
		var region_id: String = rid
		var r: RegionData = RegionData.new(region_id)
		regions[region_id] = r
		_links[region_id] = _build_links(region_id)
	for rid in RegionData.IDS:
		var region_id: String = rid
		_band[region_id] = _band_of(_region(region_id).crisis_level())
	_route_cooldown = PackedInt32Array()
	_route_cooldown.resize(RegionData.ROUTES.size())
	for i in range(_route_cooldown.size()):
		_route_cooldown[i] = 0
	tick = 0
	temperature = B.TEMP_START
	budget = B.BUDGET_START
	political = B.POLITICAL_START
	science = B.SCIENCE_START
	actions_used = 0
	branch_usage = {}
	for aid in B.ACTION_ORDER:
		var action_def: Dictionary = B.ACTIONS[aid]
		var branch: String = action_def["branch"]
		branch_usage[branch] = 0
	over = false
	won = false
	reason = ""
	spread_count = 0
	first_spread_tick = -1
	first_alarm_tick = -1
	peak_crisis = avg_crisis()
	_ready_at = {}
	_toast_last = {}
	_news_last = {}
	_next_milestone = 0
	_depleted_ticks = 0
	_low_warned = false
	_reset_phase2()


func _reset_phase2() -> void:
	_node_defs = {}
	for n in TechTree.all_nodes():
		var def: Dictionary = n
		_node_defs[str(def.get("id", ""))] = def
	_evo_defs = {}
	for e in TechTree.all_evolutions():
		var def: Dictionary = e
		_evo_defs[str(def.get("id", ""))] = def
	_event_defs = {}
	for e in Events.all_events():
		var def: Dictionary = e
		_event_defs[str(def.get("id", ""))] = def
	_adopted = {}
	_adopted_order = []
	_moves = []
	_adapt = {}
	_adapt_warned = {}
	_active_evos = []
	_evolved = {}
	_immune = {}
	_timed = []
	_seen_events = {}
	pending_event = {}
	_next_event_tick = _rng_events.randi_range(B.EVENT_FIRST_MIN, B.EVENT_FIRST_MAX)
	_bubbles = []
	_next_bubble_id = 1
	cards_seen = 0
	evolution_log = []
	event_log = []
	bubbles_spawned_total = 0
	bubbles_collected_total = 0
	_recompute_mods()
	history = [[0, sea_health(), avg_crisis()]]


## Advances one tick. Returns {"spreads": [[from_id, to_id], ...], "toasts": [[key, args, severity], ...],
## "news": [[key, args, tone], ...], "evolutions": [ids], "cured": [ids], "bubbles_spawned": [bubble],
## "bubbles_expired": [bubble ids], "event": {"id", "region"} or {}, "game_over", "won", "reason"}
func step() -> Dictionary:
	var res: Dictionary = _new_result()
	if over:
		_finish_result(res)
		return res
	tick += 1
	_recompute_mods()
	var heat: float = maxf(temperature - B.TEMP_START, 0.0)
	var spreads: Array = res["spreads"]
	var toasts: Array = res["toasts"]
	var news: Array = res["news"]

	# 1. Pollution: every delta is computed from the same (previous tick) state.
	var deltas: Dictionary = {}
	for rid in RegionData.IDS:
		var region_id: String = rid
		deltas[region_id] = _pollution_delta(_region(region_id), heat)
	# 2. Apply, then ecosystems respond and social levers decay.
	for rid in RegionData.IDS:
		var region_id: String = rid
		var r: RegionData = _region(region_id)
		var dp: float = deltas[region_id]
		r.pollution += dp
		r.clamp_all()
		_update_ecology(r, heat)
		_decay_levers(r)
		r.clamp_all()
	# 3. Crisis spreads along currents and shipping lanes.
	_update_spread(spreads, toasts, news)
	# 4. Climate, economy and alerts.
	_update_temperature(toasts, news)
	_update_resources(toasts, news)
	_update_region_alerts(toasts, news)
	peak_crisis = maxf(peak_crisis, avg_crisis())
	# 5. The crisis adapts to one-sided play and to the world (heat, spreads); bubbles come and go.
	_update_adaptation(res)
	_check_world_evolutions(res)
	_update_bubbles(res)
	# 6. Win / lose, then the next decision card.
	_check_end()
	if not over:
		_schedule_events(res)
	if tick % B.HISTORY_EVERY == 0 or over:
		history.append([tick, sea_health(), avg_crisis()])
	_finish_result(res)
	return res


func year() -> float:
	return float(B.START_YEAR) + float(B.END_YEAR - B.START_YEAR) * float(tick) / float(B.TOTAL_TICKS)


## Sea Health Index 0-100: mean of region health weighted by coastal population.
func sea_health() -> float:
	var total_w: float = 0.0
	var acc: float = 0.0
	for rid in RegionData.IDS:
		var region_id: String = rid
		if not regions.has(region_id):
			continue
		var r: RegionData = regions[region_id]
		acc += r.health() * r.coastal_pop
		total_w += r.coastal_pop
	if total_w <= 0.0:
		return 0.0
	return acc / total_w


## Unweighted mean crisis level of all regions (0-100).
func avg_crisis() -> float:
	if regions.is_empty():
		return 0.0
	var acc: float = 0.0
	for rid in RegionData.IDS:
		var region_id: String = rid
		acc += _region(region_id).crisis_level()
	return acc / float(RegionData.IDS.size())


## Unweighted mean awareness of all regions (0-100).
func avg_awareness() -> float:
	if regions.is_empty():
		return 0.0
	var acc: float = 0.0
	for rid in RegionData.IDS:
		var region_id: String = rid
		acc += _region(region_id).awareness
	return acc / float(RegionData.IDS.size())


## Keys documented in docs/ARCHITECTURE.md "Snapshot" plus the Phase 2 net income per tick before
## spending (budget_rate / political_rate / science_rate) and a few extra stats.
func snapshot() -> Dictionary:
	var y: float = year()
	var y_int: int = int(floorf(y))
	var rates: Dictionary = income_rates()
	return {
		"tick": tick,
		"year": y,
		"year_int": y_int,
		"years_left": maxi(B.END_YEAR - y_int, 0),
		"progress": clampf(float(tick) / float(B.TOTAL_TICKS), 0.0, 1.0),
		"temperature": temperature,
		"sea_health": sea_health(),
		"crisis": avg_crisis(),
		"awareness": avg_awareness(),
		"budget": budget,
		"political": political,
		"science": science,
		"actions_used": actions_used,
		"spreads": spread_count,
		"budget_rate": float(rates["budget"]),
		"political_rate": float(rates["political"]),
		"science_rate": float(rates["science"]),
		"nodes_adopted": _adopted_order.size(),
		"evolutions_active": _active_evos.size(),
		"cards_seen": cards_seen,
		"bubbles_collected": bubbles_collected_total,
	}


func region_dict(region_id: String) -> Dictionary:
	if not regions.has(region_id):
		return {}
	var r: RegionData = regions[region_id]
	return r.to_dict()


func can_afford(action_id: String) -> bool:
	if not B.ACTIONS.has(action_id):
		return false
	return _has_resources(action_cost(action_id))


## Field operations are refused while a decision card waits for an answer.
func can_perform(action_id: String, region_id: String) -> bool:
	return not over and pending_event.is_empty() and regions.has(region_id) \
		and can_afford(action_id) and cooldown_left_ticks(action_id, region_id) == 0


## Pollution a cleanup would remove in region_id now: skimmers collect more where there is
## more waste (CLEANUP_POLLUTION_DROP at pollution CLEANUP_REF_POLLUTION) x cleanup_power_mult.
func cleanup_amount(region_id: String) -> float:
	if not regions.has(region_id):
		return 0.0
	var r: RegionData = regions[region_id]
	var factor: float = clampf(r.pollution / B.CLEANUP_REF_POLLUTION, B.CLEANUP_MIN_SCALE, B.CLEANUP_MAX_SCALE)
	return minf(B.CLEANUP_POLLUTION_DROP * factor * _mul("cleanup_power_mult"), r.pollution)


## Ticks until action_id can be used again on region_id (0 = ready).
func cooldown_left_ticks(action_id: String, region_id: String) -> int:
	var key: String = _cd_key(action_id, region_id)
	if not _ready_at.has(key):
		return 0
	var ready_tick: int = _ready_at[key]
	return maxi(ready_tick - tick, 0)


## Returns {"ok": bool, "spreads": [], "toasts": [...], "news": [...], "evolutions": [...], "cured": []}
func perform(action_id: String, region_id: String) -> Dictionary:
	var res: Dictionary = _new_move_result()
	res["spreads"] = []
	if not can_perform(action_id, region_id):
		return res
	var def: Dictionary = B.ACTIONS[action_id]
	_pay(action_cost(action_id))

	var r: RegionData = _region(region_id)
	match action_id:
		"cleanup":
			r.pollution -= cleanup_amount(region_id)
		"patrol":
			var patrol_gain: float = B.PATROL_PROTECTION_GAIN * _mul("patrol_power_mult")
			r.protection += _saturated(patrol_gain, r.protection, B.PATROL_SATURATION)
		"campaign":
			var campaign_gain: float = B.CAMPAIGN_AWARENESS_GAIN * _mul("campaign_power_mult")
			r.awareness += _saturated(campaign_gain, r.awareness, B.CAMPAIGN_SATURATION)
			var links: Array = _links[region_id]
			for l in links:
				var link: Dictionary = l
				var other_id: String = link["id"]
				var other: RegionData = _region(other_id)
				other.awareness += _saturated(campaign_gain * B.CAMPAIGN_NEIGHBOR_SHARE, other.awareness, B.CAMPAIGN_SATURATION)
				other.clamp_all()
	r.clamp_all()

	var cooldown: int = int(def["cooldown_ticks"])
	_ready_at[_cd_key(action_id, region_id)] = tick + cooldown
	actions_used += 1
	var branch: String = def["branch"]
	branch_usage[branch] = int(branch_usage.get(branch, 0)) + 1
	var toast_key: String = def["toast_key"]
	# Player feedback is never rate-limited: per (action, region) cooldowns already bound it.
	var toasts: Array = res["toasts"]
	toasts.append([toast_key, {"region": r.name_key}, 0])
	_record_move(branch)
	res["ok"] = true
	return res


# --- Per-tick model --------------------------------------------------------------------------

## delta = base + sum(neighbour pollution x route weight) + heat stress + coastal inflow
##         - protection - awareness   (README "SIMULATION DESIGN"), each term x its modifier.
## The two levers remove a share of what is there (their coefficient applies as written at
## pollution LEVER_POLLUTION_REF), so every region settles toward an equilibrium instead of
## overshooting to 0 or 100 when the levers are high.
func _pollution_delta(r: RegionData, heat: float) -> float:
	var pressure: float = 0.0
	var links: Array = _links[r.id]
	for l in links:
		var link: Dictionary = l
		var other_id: String = link["id"]
		var w: float = link["w"]
		pressure += _region(other_id).pollution * w
	var lever_share: float = r.pollution / B.LEVER_POLLUTION_REF
	var protect_pull: float = r.protection * B.PROTECT_COEFF * _mul("protect_effect_mult")
	var aware_pull: float = r.awareness * B.AWARE_COEFF * _mul("aware_effect_mult")
	return B.BASE_POLLUTION_RATE * _mul("base_pollution_mult") \
		+ pressure * B.NEIGHBOR_PRESSURE_COEFF * _mul("neighbor_pressure_mult") \
		+ heat * B.TEMP_STRESS_COEFF * _mul("heat_stress_mult") \
		+ r.coastal_pop * B.SOURCE_INFLOW_COEFF * _mul("inflow_mult") \
		- (protect_pull + aware_pull) * lever_share


## Coral, Posidonia seagrass and fish respond to pollution, heat and protection.
func _update_ecology(r: RegionData, heat: float) -> void:
	# Below BIO_SAFE_POLLUTION clean water lets life regrow; above it pollution damages it.
	var clean01: float = clampf((B.BIO_SAFE_POLLUTION - r.pollution) / B.BIO_SAFE_POLLUTION, 0.0, 1.0)
	var dirty01: float = clampf((r.pollution - B.BIO_SAFE_POLLUTION) / (100.0 - B.BIO_SAFE_POLLUTION), 0.0, 1.0)
	var prot01: float = r.protection / 100.0
	# Protected reefs and meadows recover best in clean water (cleanup supports patrols).
	var guarded01: float = prot01 * (1.0 - dirty01 * B.BIO_DIRTY_RECOVERY_CUT)
	var heat_stress: float = heat * _mul("heat_stress_mult")

	# Room to grow ^ BIO_ROOM_EXPONENT: recovery is quick when degraded, slow near pristine.
	var coral_room: float = pow(1.0 - r.coral_health / 100.0, B.BIO_ROOM_EXPONENT)
	r.coral_health += (B.CORAL_RECOVERY * guarded01 + B.CORAL_CLEAN_REGROWTH * clean01) * coral_room * _mul("coral_recovery_mult") \
		- B.CORAL_POLLUTION_DAMAGE * dirty01 \
		- B.CORAL_HEAT_DAMAGE * heat_stress * _mul("coral_heat_mult")

	var grass_room: float = pow(1.0 - r.seagrass / 100.0, B.BIO_ROOM_EXPONENT)
	r.seagrass += (B.SEAGRASS_RECOVERY * guarded01 + B.SEAGRASS_CLEAN_REGROWTH * clean01) * grass_room * _mul("seagrass_recovery_mult") \
		- B.SEAGRASS_POLLUTION_DAMAGE * dirty01 \
		- B.SEAGRASS_HEAT_DAMAGE * heat_stress

	# Fish: logistic regrowth (peaks at stock 50) helped by seagrass nurseries, minus
	# fishing (cut by no-take zones and by aware, sustainable demand) and pollution.
	var f: float = r.fish_stock
	var habitat: float = (1.0 - B.FISH_HABITAT_WEIGHT) + B.FISH_HABITAT_WEIGHT * r.seagrass / 100.0
	var regen: float = B.FISH_REGEN * (f + B.FISH_SEED_STOCK) * (1.0 - f / 100.0) / 25.0 * habitat * _mul("fish_regen_mult")
	var no_take01: float = clampf(prot01 * B.FISH_PROTECT_MULT, 0.0, 1.0)
	var demand: float = 1.0 - clampf(r.awareness / 100.0 * B.AWARE_FISHING_CUT, 0.0, 1.0)
	var harvest: float = B.FISHING_PRESSURE * (f / 50.0) * (1.0 - no_take01) * demand * _mul("fishing_mult")
	var poison: float = B.FISH_POLLUTION_DAMAGE * r.pollution / 100.0
	r.fish_stock = f + regen - harvest - poison


## Awareness fades from the news; protection erodes without enforcement, more slowly where
## the public backs it (awareness x AWARE_PROTECTION_HOLD). Policy floors keep a minimum.
func _decay_levers(r: RegionData) -> void:
	r.awareness -= (B.AWARENESS_DECAY_PER_TICK + r.awareness * B.AWARENESS_DECAY_RATE) * _mul("awareness_decay_mult")
	var hold: float = 1.0 - clampf(r.awareness / 100.0 * B.AWARE_PROTECTION_HOLD, 0.0, 1.0)
	r.protection -= (B.PROTECTION_DECAY_PER_TICK + r.protection * B.PROTECTION_DECAY_RATE) * hold * _mul("protect_decay_mult")
	r.awareness = maxf(r.awareness, minf(_add("awareness_floor"), 100.0))
	r.protection = maxf(r.protection, minf(_add("protection_floor"), 100.0))


## One roll per route per tick, from the worse region to the better one, when the source is
## above SPREAD_THRESHOLD and the route is not cooling down. Protection shields the target.
func _update_spread(spreads: Array, toasts: Array, news: Array) -> void:
	var chance_mult: float = _mul("spread_chance_mult")
	var damage_mult: float = _mul("spread_damage_mult")
	for i in range(RegionData.ROUTES.size()):
		var cd: int = _route_cooldown[i]
		if cd > 0:
			_route_cooldown[i] = cd - 1
			continue
		var route: Dictionary = RegionData.ROUTES[i]
		var a_id: String = route["a"]
		var b_id: String = route["b"]
		var kind: String = route["kind"]
		var weight: float = route["weight"]
		var a: RegionData = _region(a_id)
		var b: RegionData = _region(b_id)
		var ca: float = a.crisis_level()
		var cb: float = b.crisis_level()
		var src: RegionData = a
		var dst: RegionData = b
		var c_src: float = ca
		var c_dst: float = cb
		if cb > ca:
			src = b
			dst = a
			c_src = cb
			c_dst = ca
		if c_src < B.SPREAD_THRESHOLD or c_dst >= c_src:
			continue
		var shield: float = 1.0 - clampf(dst.protection / 100.0 * B.SPREAD_PROTECTION_SHIELD, 0.0, 1.0)
		var chance: float = B.SPREAD_CHANCE_PER_TICK * weight * _kind_mult(kind) * (c_src / 100.0) * shield * chance_mult
		if rng.randf() >= chance:
			continue
		var hit: float = shield * damage_mult
		dst.pollution += B.SPREAD_POLLUTION_BUMP * hit
		dst.coral_health -= B.SPREAD_BIO_DAMAGE * hit
		dst.seagrass -= B.SPREAD_BIO_DAMAGE * hit
		dst.fish_stock -= B.SPREAD_BIO_DAMAGE * hit
		dst.clamp_all()
		_route_cooldown[i] = B.SPREAD_ROUTE_COOLDOWN_TICKS
		spreads.append([src.id, dst.id])
		spread_count += 1
		if first_spread_tick < 0:
			first_spread_tick = tick
		_push_toast(toasts, "spread", "toast.spread", {"from": src.name_key, "to": dst.name_key}, 2, B.TOAST_MIN_GAP_TICKS)
		var news_key: String = "sim.news.spread.%d" % (spread_count % SPREAD_NEWS_VARIANTS)
		_push_news(news, "spread", news_key, {"from": src.name_key, "to": dst.name_key}, -1, B.NEWS_SPREAD_GAP_TICKS)


## Base warming plus a share driven by the basin's average crisis (x temp_rise_mult); milestones.
func _update_temperature(toasts: Array, news: Array) -> void:
	var rise: float = (B.TEMP_BASE_RISE_PER_TICK + B.TEMP_CRISIS_RISE_PER_TICK * avg_crisis() / 100.0) * _mul("temp_rise_mult")
	temperature = clampf(temperature + rise, 0.0, B.TEMP_LOSE)
	while _next_milestone < B.TEMP_MILESTONES.size():
		var m: float = B.TEMP_MILESTONES[_next_milestone]
		if temperature < m:
			break
		var alarm: bool = m >= B.TEMP_ALARM_MILESTONE
		var severity: int = 3 if alarm else 2
		if not _push_toast(toasts, "temperature", "toast.temp_warning", {"temp": "%.1f" % m}, severity, B.TOAST_MIN_GAP_TICKS):
			break
		news.append(["sim.news.temp_alarm" if alarm else "sim.news.temp", {"temp": "%.1f" % m}, -1])
		_next_milestone += 1


## Net income per tick before spending: {"budget", "political", "science"}. Budget follows the
## sea economy (fisheries, tourism) and political support follows public awareness; both turn
## negative below their break-even points (income multipliers only boost a positive base).
## Policies add flat income and blue-carbon credits; science trickles in (bubbles add more).
func income_rates() -> Dictionary:
	var h: float = sea_health()
	var budget_gain: float = B.BUDGET_INCOME_PER_TICK * (h - B.BUDGET_BREAKEVEN_HEALTH) \
		/ maxf(B.BUDGET_REF_HEALTH - B.BUDGET_BREAKEVEN_HEALTH, 1.0)
	if budget_gain > 0.0:
		budget_gain *= _mul("budget_income_mult")
	budget_gain += _add("budget_per_tick") + _add("blue_carbon") * float(blue_carbon_regions())
	var aw: float = avg_awareness()
	var political_gain: float = B.POLITICAL_INCOME_PER_TICK * (aw - B.POLITICAL_BREAKEVEN_AWARENESS) \
		/ maxf(B.POLITICAL_REF_AWARENESS - B.POLITICAL_BREAKEVEN_AWARENESS, 1.0)
	if political_gain > 0.0:
		political_gain *= _mul("political_income_mult")
	political_gain += _add("political_per_tick")
	var science_gain: float = B.SCIENCE_INCOME_PER_TICK * _mul("science_income_mult") + _add("science_per_tick")
	return {"budget": budget_gain, "political": political_gain, "science": science_gain}


## Regions whose Posidonia meadows earn blue-carbon credits (seagrass above BLUE_CARBON_SEAGRASS).
func blue_carbon_regions() -> int:
	var n: int = 0
	for rid in RegionData.IDS:
		var region_id: String = rid
		if regions.has(region_id) and _region(region_id).seagrass > B.BLUE_CARBON_SEAGRASS:
			n += 1
	return n


func _update_resources(toasts: Array, news: Array) -> void:
	var inc: Dictionary = income_rates()
	budget = clampf(budget + float(inc["budget"]), 0.0, B.RESOURCE_CAP)
	political = clampf(political + float(inc["political"]), 0.0, B.RESOURCE_CAP)
	science = clampf(science + float(inc["science"]), 0.0, B.RESOURCE_CAP)

	var depleted: bool = budget < B.DEPLETED_THRESHOLD and political < B.DEPLETED_THRESHOLD
	if depleted:
		_depleted_ticks += 1
		if _depleted_ticks == 1:
			if _push_toast(toasts, "depleted", "toast.depleted", {}, 3, B.TOAST_MIN_GAP_TICKS):
				news.append(["sim.news.depleted", {}, -1])
	else:
		_depleted_ticks = 0

	var low: bool = budget < B.LOW_BUDGET_WARN and political < B.LOW_POLITICAL_WARN
	if low and not _low_warned and not depleted:
		if _push_toast(toasts, "low_resources", "toast.low_resources", {}, 2, B.LOW_RESOURCE_TOAST_GAP_TICKS):
			_low_warned = true
	elif budget >= B.LOW_BUDGET_WARN * 2.0 or political >= B.LOW_POLITICAL_WARN * 2.0:
		_low_warned = false


## Alarm when a region crosses REGION_CRITICAL_CRISIS, good news when it drops below
## REGION_RECOVERED_CRISIS. Bands only change when the toast is actually emitted, so a
## rate-limited alert fires on a later tick instead of being lost.
func _update_region_alerts(toasts: Array, news: Array) -> void:
	for rid in RegionData.IDS:
		var region_id: String = rid
		var r: RegionData = _region(region_id)
		var c: float = r.crisis_level()
		var band: String = _band[region_id]
		if c >= B.REGION_CRITICAL_CRISIS:
			if band != "critical":
				if _push_toast(toasts, "critical", "toast.region_critical", {"region": r.name_key}, 3, B.TOAST_MIN_GAP_TICKS):
					_band[region_id] = "critical"
					if first_alarm_tick < 0:
						first_alarm_tick = tick
					var critical_key: String = "sim.news.critical.%d" % (tick % ALERT_NEWS_VARIANTS)
					_push_news(news, "critical", critical_key, {"region": r.name_key}, -1, B.NEWS_ALERT_GAP_TICKS)
		elif c < B.REGION_RECOVERED_CRISIS:
			if band != "recovered":
				if _push_toast(toasts, "recovering", "toast.region_recovering", {"region": r.name_key}, 1, B.TOAST_MIN_GAP_TICKS):
					_band[region_id] = "recovered"
					var recovered_key: String = "sim.news.recovered.%d" % (tick % ALERT_NEWS_VARIANTS)
					_push_news(news, "recovered", recovered_key, {"region": r.name_key}, 1, B.NEWS_ALERT_GAP_TICKS)
		elif band == "critical" and c < B.REGION_CRITICAL_CRISIS - B.ALERT_HYSTERESIS:
			_band[region_id] = "mid"
		elif band == "recovered" and c > B.REGION_RECOVERED_CRISIS + B.ALERT_HYSTERESIS:
			_band[region_id] = "mid"


func _check_end() -> void:
	if temperature >= B.TEMP_LOSE:
		_finish(false, "lose_temperature")
	elif sea_health() < B.LOSE_SEA_HEALTH:
		_finish(false, "lose_health")
	elif _depleted_ticks >= B.DEPLETED_GRACE_TICKS:
		_finish(false, "lose_resources")
	elif _all_regions_below(B.WIN_ALL_CRISIS_BELOW):
		_finish(true, "win_crisis")
	elif tick >= B.TOTAL_TICKS:
		if sea_health() >= B.WIN_SEA_HEALTH:
			_finish(true, "win_health")
		else:
			_finish(false, "lose_time")


func _finish(p_won: bool, p_reason: String) -> void:
	over = true
	won = p_won
	reason = p_reason


# --- Helpers ---------------------------------------------------------------------------------

func _region(region_id: String) -> RegionData:
	return regions[region_id]


## Lever gain shrinks as the lever fills up ("preaching to the converted"):
## gain x (1 - level / 100 x saturation).
func _saturated(gain: float, level: float, saturation: float) -> float:
	return gain * clampf(1.0 - level / 100.0 * saturation, 0.0, 1.0)


func _all_regions_below(level: float) -> bool:
	for rid in RegionData.IDS:
		var region_id: String = rid
		if _region(region_id).crisis_level() >= level:
			return false
	return true


func _kind_mult(kind: String) -> float:
	if kind == "shipping":
		return B.SHIPPING_WEIGHT_MULT
	return B.CURRENT_WEIGHT_MULT


func _build_links(region_id: String) -> Array:
	var out: Array = []
	for n in RegionData.neighbors_of(region_id):
		var nb: Dictionary = n
		var kind: String = nb["kind"]
		var weight: float = nb["weight"]
		var other_id: String = nb["id"]
		out.append({"id": other_id, "w": weight * _kind_mult(kind)})
	return out


func _band_of(crisis: float) -> String:
	if crisis >= B.REGION_CRITICAL_CRISIS:
		return "critical"
	if crisis < B.REGION_RECOVERED_CRISIS:
		return "recovered"
	return "mid"


func _cd_key(action_id: String, region_id: String) -> String:
	return action_id + "|" + region_id


## Appends a toast unless one of the same kind was emitted less than min_gap ticks ago.
func _push_toast(toasts: Array, kind: String, key: String, args: Dictionary, severity: int, min_gap: int) -> bool:
	if _toast_last.has(kind):
		var last: int = _toast_last[kind]
		if tick - last < min_gap:
			return false
	_toast_last[kind] = tick
	toasts.append([key, args, severity])
	return true


## Appends a news headline unless one of the same kind ran less than min_gap ticks ago.
func _push_news(news: Array, kind: String, key: String, args: Dictionary, tone: int, min_gap: int) -> bool:
	if _news_last.has(kind):
		var last: int = _news_last[kind]
		if tick - last < min_gap:
			return false
	_news_last[kind] = tick
	news.append([key, args, tone])
	return true


func _new_result() -> Dictionary:
	return {
		"spreads": [], "toasts": [], "news": [], "evolutions": [], "cured": [],
		"bubbles_spawned": [], "bubbles_expired": [], "event": {},
		"game_over": false, "won": false, "reason": "",
	}


func _finish_result(res: Dictionary) -> void:
	res["game_over"] = over
	res["won"] = won
	res["reason"] = reason


## Result of a player move (operation, adoption, card choice).
func _new_move_result() -> Dictionary:
	return {"ok": false, "toasts": [], "news": [], "evolutions": [], "cured": []}


func _has_resources(cost: Dictionary) -> bool:
	return budget >= float(cost.get("budget", 0.0)) \
		and political >= float(cost.get("political", 0.0)) \
		and science >= float(cost.get("science", 0.0))


func _pay(cost: Dictionary) -> void:
	budget = maxf(budget - float(cost.get("budget", 0.0)), 0.0)
	political = maxf(political - float(cost.get("political", 0.0)), 0.0)
	science = maxf(science - float(cost.get("science", 0.0)), 0.0)


## base cost x multiplier, rounded to whole points (a non-zero cost never rounds down to 0).
func _scaled_cost(cost: Dictionary, mult: float) -> Dictionary:
	var out: Dictionary = {}
	for k in cost.keys():
		var key: String = str(k)
		var base: float = float(cost[k])
		var v: float = 0.0
		if base > 0.0:
			v = maxf(roundf(base * mult), 1.0)
		out[key] = v
	return out


func _mul(key: String) -> float:
	return float(_mods.get(key, 1.0))


func _add(key: String) -> float:
	return float(_mods.get(key, 0.0))


# =====================================================================================
# Phase 2: modifiers, policy tree, crisis evolution, decision events, data bubbles
# (docs/ARCHITECTURE.md section 11).
# =====================================================================================

## Current value of every modifier key (copy): multipliers default 1.0, additive terms 0.0.
func modifiers() -> Dictionary:
	return _mods.duplicate()


## Rebuilds the whole modifier set from scratch: adopted nodes (scaled by their ramp), active
## evolutions and live timed event effects. Expired event effects are dropped here.
func _recompute_mods() -> void:
	var m: Dictionary = {}
	for k in MUL_KEYS:
		m[str(k)] = 1.0
	for k in ADD_KEYS:
		m[str(k)] = 0.0
	for nid in _adopted_order:
		var node_id: String = nid
		var def: Dictionary = _node_defs[node_id]
		var effects: Array = def.get("effects", [])
		var ramp: float = node_ramp(node_id)
		for e in effects:
			var eff: Dictionary = e
			_fold_effect(m, eff, ramp)
	for eid in _active_evos:
		var evo_id: String = eid
		var edef: Dictionary = _evo_defs[evo_id]
		var evo_effects: Array = edef.get("effects", [])
		for e in evo_effects:
			var eff: Dictionary = e
			_fold_effect(m, eff, 1.0)
	var keep: Array = []
	for t in _timed:
		var item: Dictionary = t
		var until: int = int(item.get("until", -1))
		if until >= 0 and tick > until:
			continue
		keep.append(item)
		_fold_effect(m, item, 1.0)
	_timed = keep
	_mods = m


## Folds one persistent effect into the modifier set: mul -> 1 + (value - 1) x ramp, add -> value x ramp.
func _fold_effect(m: Dictionary, eff: Dictionary, ramp: float) -> void:
	var op: String = str(eff.get("op", ""))
	var key: String = str(eff.get("key", ""))
	if not m.has(key):
		return
	var cur: float = float(m[key])
	if op == "mul":
		var value: float = float(eff.get("value", 1.0))
		m[key] = cur * (1.0 + (value - 1.0) * ramp)
	elif op == "add":
		var value: float = float(eff.get("value", 0.0))
		m[key] = cur + value * ramp


## One-shot effects ("region", "resource", "temperature"); persistent ones are folded elsewhere.
## event_region is the card's region for target "event" ("" outside a card).
func _apply_one_shot(eff: Dictionary, event_region: String) -> void:
	var op: String = str(eff.get("op", ""))
	var value: float = float(eff.get("value", 0.0))
	match op:
		"region":
			var stat: String = str(eff.get("stat", ""))
			for t in _effect_targets(str(eff.get("target", "all")), event_region):
				var r: RegionData = _region(str(t))
				_add_stat(r, stat, value)
				r.clamp_all()
		"resource":
			match str(eff.get("key", "")):
				"budget":
					budget = clampf(budget + value, 0.0, B.RESOURCE_CAP)
				"political":
					political = clampf(political + value, 0.0, B.RESOURCE_CAP)
				"science":
					science = clampf(science + value, 0.0, B.RESOURCE_CAP)
		"temperature":
			temperature = clampf(temperature + value, 0.0, B.TEMP_LOSE)


func _add_stat(r: RegionData, stat: String, value: float) -> void:
	match stat:
		"pollution":
			r.pollution += value
		"coral_health":
			r.coral_health += value
		"seagrass":
			r.seagrass += value
		"fish_stock":
			r.fish_stock += value
		"awareness":
			r.awareness += value
		"protection":
			r.protection += value


## Region ids an effect target names: "all" | "event" | "worst" | "best" | "hero" | <region id>.
func _effect_targets(target: String, event_region: String) -> Array:
	match target:
		"all":
			return RegionData.IDS.duplicate()
		"event":
			if regions.has(event_region):
				return [event_region]
			return []
		"worst":
			return [_extreme_region(true)]
		"best":
			return [_extreme_region(false)]
		"hero":
			return [RegionData.HERO_ID]
	if regions.has(target):
		return [target]
	return []


## Region with the highest (worst = true) or lowest crisis level.
func _extreme_region(worst: bool) -> String:
	var best_id: String = RegionData.HERO_ID
	var best_val: float = -1.0 if worst else 1000.0
	for rid in RegionData.IDS:
		var region_id: String = rid
		var c: float = _region(region_id).crisis_level()
		if (worst and c > best_val) or (not worst and c < best_val):
			best_val = c
			best_id = region_id
	return best_id


# --- Policy tree -----------------------------------------------------------------------------

## "adopted" | "available" (every prerequisite adopted) | "locked" (also for unknown ids).
func node_state(node_id: String) -> String:
	if _adopted.has(node_id):
		return "adopted"
	if not _node_defs.has(node_id):
		return "locked"
	var def: Dictionary = _node_defs[node_id]
	var requires: Array = def.get("requires", [])
	for q in requires:
		if not _adopted.has(str(q)):
			return "locked"
	return "available"


## 0..1 implementation progress of an adopted node (1 = full effect).
func node_ramp(node_id: String) -> float:
	if not _adopted.has(node_id):
		return 0.0
	var def: Dictionary = _node_defs[node_id]
	var ramp_ticks: int = int(def.get("ramp_ticks", 0))
	if ramp_ticks <= 0:
		return 1.0
	var since: int = _adopted[node_id]
	return clampf(float(tick - since) / float(ramp_ticks), 0.0, 1.0)


## Current cost with node_cost_mult applied: same keys as the node's cost (missing keys = 0).
func node_cost(node_id: String) -> Dictionary:
	if not _node_defs.has(node_id):
		return {}
	var def: Dictionary = _node_defs[node_id]
	var cost: Dictionary = def.get("cost", {})
	return _scaled_cost(cost, _mul("node_cost_mult"))


func can_adopt(node_id: String) -> bool:
	return not over and pending_event.is_empty() and node_state(node_id) == "available" \
		and _has_resources(node_cost(node_id))


## Returns {"ok": bool, "toasts": [...], "news": [...], "evolutions": [...], "cured": [...]}
func adopt(node_id: String) -> Dictionary:
	var res: Dictionary = _new_move_result()
	if not can_adopt(node_id):
		return res
	var def: Dictionary = _node_defs[node_id]
	_pay(node_cost(node_id))
	_adopted[node_id] = tick
	_adopted_order.append(node_id)
	var effects: Array = def.get("effects", [])
	for e in effects:
		var eff: Dictionary = e
		_apply_one_shot(eff, "")
	var name_key: String = str(def.get("name_key", node_id))
	var branch: String = str(def.get("branch", ""))
	var toasts: Array = res["toasts"]
	toasts.append(["sim.toast.adopted", {"name": name_key}, 1])
	var news: Array = res["news"]
	news.append(["sim.news.adopted." + branch, {"name": name_key}, 1])
	var counters: Array = def.get("counters", [])
	for c in counters:
		_apply_counter(str(c), res)
	_record_move(branch)
	_recompute_mods()
	res["ok"] = true
	return res


func adopted_nodes() -> Array:
	return _adopted_order.duplicate()


## A counter node cures its evolution if active and makes the crisis immune to it from now on.
func _apply_counter(evo_id: String, res: Dictionary) -> void:
	if not _evo_defs.has(evo_id):
		return
	var def: Dictionary = _evo_defs[evo_id]
	var name_key: String = str(def.get("name_key", evo_id))
	var toasts: Array = res["toasts"]
	if _active_evos.has(evo_id):
		_active_evos.erase(evo_id)
		var cured: Array = res["cured"]
		cured.append(evo_id)
		toasts.append(["sim.toast.cured", {"name": name_key}, 1])
		var news: Array = res["news"]
		news.append([str(def.get("cured_news_key", "")), {}, 1])
	elif not _immune.has(evo_id) and not _evolved.has(evo_id):
		toasts.append(["sim.toast.immune", {"name": name_key}, 0])
	_immune[evo_id] = true


# --- Crisis evolution ------------------------------------------------------------------------

## Ids of the resistances the crisis has evolved and the player has not cured.
func active_evolutions() -> Array:
	return _active_evos.duplicate()


## {"shares": {branch: 0..1}, "threshold", "moves", "min_moves", "window", "mix", "blocked",
## "adapt"}. "shares" only counts branches whose resistance can still evolve (others read 0);
## "mix" is the raw share of every branch in the last moves; "blocked" lists branches already
## evolved or made immune; "adapt" is {branch: 0..1}, how far a sustained one-sided strategy
## (share at or above the threshold) has pushed the crisis toward evolving (1 = it evolves).
func evolution_pressure() -> Dictionary:
	var mix: Dictionary = _branch_mix()
	var shares: Dictionary = {}
	var adapt: Dictionary = {}
	var blocked: Array = []
	for b in TechTree.BRANCHES:
		var branch: String = b
		adapt[branch] = clampf(float(_adapt.get(branch, 0.0)) / float(maxi(B.EVO_ADAPT_TICKS, 1)), 0.0, 1.0)
		if _branch_can_evolve(branch):
			shares[branch] = float(mix[branch])
		else:
			shares[branch] = 0.0
			blocked.append(branch)
	return {
		"shares": shares,
		"threshold": B.EVO_SHARE,
		"moves": _moves.size(),
		"min_moves": B.EVO_MIN_MOVES,
		"window": B.EVO_WINDOW,
		"mix": mix,
		"blocked": blocked,
		"adapt": adapt,
	}


func _branch_mix() -> Dictionary:
	var counts: Dictionary = {}
	for b in TechTree.BRANCHES:
		counts[str(b)] = 0
	for mv in _moves:
		var branch: String = mv
		counts[branch] = int(counts.get(branch, 0)) + 1
	var n: int = _moves.size()
	var mix: Dictionary = {}
	for b in TechTree.BRANCHES:
		var branch: String = b
		mix[branch] = float(counts[branch]) / float(n) if n > 0 else 0.0
	return mix


## The evolution provoked by one-sided play in this branch ("" if none).
func _branch_evolution(branch: String) -> String:
	for eid in _evo_defs.keys():
		var def: Dictionary = _evo_defs[eid]
		if str(def.get("trigger", "")) == "branch" and str(def.get("branch", "")) == branch:
			return str(eid)
	return ""


func _branch_can_evolve(branch: String) -> bool:
	var evo_id: String = _branch_evolution(branch)
	return evo_id != "" and not _evolved.has(evo_id) and not _immune.has(evo_id)


## Remembers a player move (operation or adoption) for the crisis to read the strategy.
func _record_move(branch: String) -> void:
	if branch == "":
		return
	_moves.append(branch)
	while _moves.size() > B.EVO_WINDOW:
		_moves.remove_at(0)


## Every tick: a branch holding at least EVO_SHARE of the last moves (once there are
## EVO_MIN_MOVES) builds adaptation; after EVO_ADAPT_TICKS of it the resistance evolves. Diverse
## play drains it again, so the pressure warning gives the player time to react.
func _update_adaptation(res: Dictionary) -> void:
	var mix: Dictionary = _branch_mix()
	var enough: bool = _moves.size() >= B.EVO_MIN_MOVES
	for b in TechTree.BRANCHES:
		var branch: String = b
		var cur: float = float(_adapt.get(branch, 0.0))
		if enough and float(mix[branch]) >= B.EVO_SHARE and _branch_can_evolve(branch):
			cur += 1.0
		else:
			cur = maxf(cur - B.EVO_ADAPT_DECAY, 0.0)
		if cur >= float(B.EVO_ADAPT_TICKS):
			cur = 0.0
			_evolve(_branch_evolution(branch), res)
		elif cur >= float(B.EVO_ADAPT_TICKS) * B.EVO_WARN_AT and not _adapt_warned.has(branch):
			# One warning per branch, halfway there: the player can still diversify in time.
			_adapt_warned[branch] = true
			var toasts: Array = res["toasts"]
			toasts.append(["sim.toast.adapting", {"branch": "tree.branch.%s.name" % branch}, 2])
		_adapt[branch] = cur


## Heat and spread triggered resistances.
func _check_world_evolutions(res: Dictionary) -> void:
	for e in TechTree.all_evolutions():
		var def: Dictionary = e
		var evo_id: String = str(def.get("id", ""))
		var trigger: String = str(def.get("trigger", ""))
		if trigger == "heat" and temperature >= B.EVO_HEAT_TEMP:
			_evolve(evo_id, res)
		elif trigger == "spread" and spread_count >= B.EVO_SPREAD_COUNT:
			_evolve(evo_id, res)


func _evolve(evo_id: String, res: Dictionary) -> void:
	if over or _evolved.has(evo_id) or _immune.has(evo_id) or not _evo_defs.has(evo_id):
		return
	var def: Dictionary = _evo_defs[evo_id]
	_evolved[evo_id] = tick
	_active_evos.append(evo_id)
	evolution_log.append([tick, evo_id])
	var toasts: Array = res["toasts"]
	toasts.append(["sim.toast.evolved", {"name": str(def.get("name_key", evo_id))}, 3])
	var news: Array = res["news"]
	news.append([str(def.get("news_key", "")), {}, -1])
	var evolved: Array = res["evolutions"]
	evolved.append(evo_id)
	_recompute_mods()


# --- Decision events -------------------------------------------------------------------------

## Opens the next card when it is due: COP31 summits at their at_tick, otherwise a weighted
## random card every EVENT_INTERVAL_MIN..MAX ticks, kept clear of the summits.
func _schedule_events(res: Dictionary) -> void:
	if not pending_event.is_empty():
		return
	for e in Events.all_events():
		var def: Dictionary = e
		var at: int = int(def.get("at_tick", -1))
		if at >= 0 and tick >= at and not _seen_events.has(str(def.get("id", ""))):
			_open_event(def)
			res["event"] = pending_event.duplicate()
			_next_event_tick = maxi(_next_event_tick, tick + B.EVENT_SUMMIT_GAP_TICKS)
			return
	if tick < _next_event_tick or _ticks_to_next_summit() < B.EVENT_SUMMIT_GAP_TICKS:
		return
	var pick: Dictionary = _pick_random_event()
	_next_event_tick = tick + _rng_events.randi_range(B.EVENT_INTERVAL_MIN, B.EVENT_INTERVAL_MAX)
	if pick.is_empty():
		return
	_open_event(pick)
	res["event"] = pending_event.duplicate()


func _ticks_to_next_summit() -> int:
	var best: int = B.TOTAL_TICKS * 10
	for e in Events.all_events():
		var def: Dictionary = e
		var at: int = int(def.get("at_tick", -1))
		if at < tick or _seen_events.has(str(def.get("id", ""))):
			continue
		best = mini(best, at - tick)
	return best


func _pick_random_event() -> Dictionary:
	var pool: Array = []
	var total: float = 0.0
	for e in Events.all_events():
		var def: Dictionary = e
		var event_id: String = str(def.get("id", ""))
		var w: float = float(def.get("weight", 0))
		if w <= 0.0 or int(def.get("at_tick", -1)) >= 0:
			continue
		if tick < int(def.get("min_tick", 0)) or tick > int(def.get("max_tick", B.TOTAL_TICKS)):
			continue
		if bool(def.get("once", true)) and _seen_events.has(event_id):
			continue
		pool.append(def)
		total += w
	if pool.is_empty() or total <= 0.0:
		return {}
	var roll: float = _rng_events.randf() * total
	for p in pool:
		var def: Dictionary = p
		roll -= float(def.get("weight", 0))
		if roll < 0.0:
			return def
	var last: Dictionary = pool[pool.size() - 1]
	return last


func _open_event(def: Dictionary) -> void:
	var event_id: String = str(def.get("id", ""))
	pending_event = {"id": event_id, "region": _event_region(str(def.get("region_rule", "none")))}
	_seen_events[event_id] = tick
	cards_seen += 1


## region_rule: "random" | "worst" | "best" | "hero" | "none" | <region id>.
func _event_region(rule: String) -> String:
	match rule:
		"random":
			return str(RegionData.IDS[_rng_events.randi_range(0, RegionData.IDS.size() - 1)])
		"worst":
			return _extreme_region(true)
		"best":
			return _extreme_region(false)
		"hero":
			return RegionData.HERO_ID
		"none", "":
			return ""
	if regions.has(rule):
		return rule
	return ""


## True when choice_index exists on the waiting card and its cost is affordable.
func can_choose(choice_index: int) -> bool:
	if over or pending_event.is_empty():
		return false
	var event_id: String = str(pending_event.get("id", ""))
	if not _event_defs.has(event_id):
		return false
	var def: Dictionary = _event_defs[event_id]
	var choices: Array = def.get("choices", [])
	if choice_index < 0 or choice_index >= choices.size():
		return false
	var ch: Dictionary = choices[choice_index]
	var cost: Dictionary = ch.get("cost", {})
	return _has_resources(cost)


## Returns {"ok": bool, "toasts": [...], "news": [...], "evolutions": [...], "cured": [...]}
func resolve_event(choice_index: int) -> Dictionary:
	var res: Dictionary = _new_move_result()
	if not can_choose(choice_index):
		return res
	var event_id: String = str(pending_event.get("id", ""))
	var region_id: String = str(pending_event.get("region", ""))
	var def: Dictionary = _event_defs[event_id]
	var choices: Array = def.get("choices", [])
	var ch: Dictionary = choices[choice_index]
	var cost: Dictionary = ch.get("cost", {})
	_pay(cost)
	var effects: Array = ch.get("effects", [])
	for e in effects:
		var eff: Dictionary = e
		var op: String = str(eff.get("op", ""))
		if op == "mul" or op == "add":
			var ticks: int = int(eff.get("ticks", -1))
			_timed.append({
				"op": op,
				"key": str(eff.get("key", "")),
				"value": float(eff.get("value", 1.0 if op == "mul" else 0.0)),
				"until": tick + ticks if ticks > 0 else -1,
			})
		else:
			_apply_one_shot(eff, region_id)
	var tone: int = int(ch.get("tone", 0))
	var args: Dictionary = {}
	if regions.has(region_id):
		args["region"] = _region(region_id).name_key
	var toasts: Array = res["toasts"]
	toasts.append([str(ch.get("result_key", "")), args, _tone_severity(tone)])
	var news: Array = res["news"]
	var letter: String = "a" if choice_index == 0 else "b"
	news.append(["sim.news.event.%s.%s" % [event_id, letter], args.duplicate(), tone])
	event_log.append([tick, event_id, choice_index])
	pending_event = {}
	_recompute_mods()
	res["ok"] = true
	return res


## Dev / demo hook: makes event_id the pending card now (region by its region_rule).
## Returns the new pending_event, or {} if the id is unknown or a card is already waiting.
func force_event(event_id: String) -> Dictionary:
	if over or not pending_event.is_empty() or not _event_defs.has(event_id):
		return {}
	var def: Dictionary = _event_defs[event_id]
	_open_event(def)
	return pending_event.duplicate()


## News tone -> toast severity: hopeful = good news, alarming = warning, neutral = info.
func _tone_severity(tone: int) -> int:
	if tone > 0:
		return 1
	if tone < 0:
		return 2
	return 0


# --- Data bubbles ------------------------------------------------------------------------------

## Field-operation cost with the running modifiers applied (same keys as Balance.ACTIONS).
func action_cost(action_id: String) -> Dictionary:
	if not B.ACTIONS.has(action_id):
		return {}
	var def: Dictionary = B.ACTIONS[action_id]
	var cost: Dictionary = def["cost"]
	return _scaled_cost(cost, _mul("action_cost_mult"))


## Copies of the bubbles alive now: {"id", "kind", "region", "amount", "ttl", "born"}.
func active_bubbles() -> Array:
	return _bubbles.duplicate(true)


## Pays the bubble's amount (bubble_value_mult was applied when it surfaced, so the number shown
## on the bubble is what the player gets). Returns {"ok": bool, "kind": String, "amount": float}.
func collect_bubble(bubble_id: int) -> Dictionary:
	if over:
		return {"ok": false, "kind": "", "amount": 0.0}
	for i in range(_bubbles.size()):
		var bub: Dictionary = _bubbles[i]
		if int(bub["id"]) != bubble_id:
			continue
		_bubbles.remove_at(i)
		var kind: String = str(bub["kind"])
		var amount: float = float(bub["amount"])
		if kind == "political":
			political = clampf(political + amount, 0.0, B.RESOURCE_CAP)
		else:
			science = clampf(science + amount, 0.0, B.RESOURCE_CAP)
		bubbles_collected_total += 1
		return {"ok": true, "kind": kind, "amount": amount}
	return {"ok": false, "kind": "", "amount": 0.0}


## Expires old bubbles, then rolls for a new one (BUBBLE_CHANCE_PER_TICK x bubble_rate_mult).
func _update_bubbles(res: Dictionary) -> void:
	var expired: Array = res["bubbles_expired"]
	var keep: Array = []
	for b in _bubbles:
		var bub: Dictionary = b
		var born: int = bub["born"]
		var ttl: int = bub["ttl"]
		if tick - born >= ttl:
			expired.append(int(bub["id"]))
		else:
			keep.append(bub)
	_bubbles = keep
	var chance: float = B.BUBBLE_CHANCE_PER_TICK * _mul("bubble_rate_mult")
	if _rng_bubbles.randf() >= chance or _bubbles.size() >= B.BUBBLES_MAX:
		return
	var political_kind: bool = _rng_bubbles.randf() < B.BUBBLE_POLITICAL_SHARE
	var kind: String = "political" if political_kind else "science"
	var region_id: String = _bubble_region(political_kind)
	var base: int = 0
	if political_kind:
		base = _rng_bubbles.randi_range(B.BUBBLE_POLITICAL_MIN, B.BUBBLE_POLITICAL_MAX)
	else:
		base = _rng_bubbles.randi_range(B.BUBBLE_SCIENCE_MIN, B.BUBBLE_SCIENCE_MAX)
	var amount: float = maxf(roundf(float(base) * _mul("bubble_value_mult")), 1.0)
	var bubble: Dictionary = {
		"id": _next_bubble_id,
		"kind": kind,
		"region": region_id,
		"amount": amount,
		"ttl": B.BUBBLE_TTL_TICKS,
		"born": tick,
	}
	_next_bubble_id += 1
	bubbles_spawned_total += 1
	_bubbles.append(bubble)
	var spawned: Array = res["bubbles_spawned"]
	spawned.append(bubble.duplicate())


## Science bubbles surface anywhere; political ones favour regions with high awareness.
func _bubble_region(political_kind: bool) -> String:
	if not political_kind:
		return str(RegionData.IDS[_rng_bubbles.randi_range(0, RegionData.IDS.size() - 1)])
	var total: float = 0.0
	for rid in RegionData.IDS:
		var region_id: String = rid
		total += _region(region_id).awareness + B.BUBBLE_AWARENESS_WEIGHT
	var roll: float = _rng_bubbles.randf() * total
	for rid in RegionData.IDS:
		var region_id: String = rid
		roll -= _region(region_id).awareness + B.BUBBLE_AWARENESS_WEIGHT
		if roll < 0.0:
			return region_id
	return RegionData.HERO_ID
