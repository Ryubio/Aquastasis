extends RefCounted
## CrisisSim: the Marine Health Crisis model (8 regions, routes, climate, resources, field
## operations, win/lose). Pure logic: no nodes, no autoloads, seeded RNG only, so the game
## (through GameState) and scripts/sim_test.gd run the exact same rules. Numbers: balance.gd.

const B := preload("res://scripts/balance.gd")
const RegionData := preload("res://scripts/region.gd")

# --- Public state (frozen API, see docs/ARCHITECTURE.md "CrisisSim") ---------------------
var regions: Dictionary = {}       # region id -> RegionData
var tick: int = 0
var temperature: float = B.TEMP_START
var budget: float = B.BUDGET_START
var political: float = B.POLITICAL_START
var science: float = B.SCIENCE_START
var actions_used: int = 0
var branch_usage: Dictionary = {}  # branch -> count (Phase 2 crisis evolution input)
var over: bool = false
var won: bool = false
var reason: String = ""
var rng := RandomNumberGenerator.new()

# --- Extra read-only statistics (end screen, sim_test) --------------------------------------
var spread_count: int = 0
var first_spread_tick: int = -1    # tick of the first spread, -1 = none yet
var first_alarm_tick: int = -1     # tick of the first "region critical" alarm, -1 = none yet
var peak_crisis: float = 0.0       # highest basin-average crisis seen

# --- Internals ----------------------------------------------------------------------------
var _links: Dictionary = {}              # region id -> Array of {"id": String, "w": float}
var _route_cooldown := PackedInt32Array()  # per RegionData.ROUTES index: ticks until it may spread again
var _ready_at: Dictionary = {}           # "action|region" -> tick at which the action is ready again
var _band: Dictionary = {}               # region id -> "critical" | "mid" | "recovered" (alert hysteresis)
var _toast_last: Dictionary = {}         # toast kind -> tick it was last emitted
var _next_milestone: int = 0             # index into B.TEMP_MILESTONES
var _depleted_ticks: int = 0             # consecutive ticks with budget AND political depleted
var _low_warned: bool = false            # low-resources warning already shown for this dip


func _init(p_seed: int = B.DEFAULT_SEED) -> void:
	reset(p_seed)


func reset(p_seed: int) -> void:
	rng.seed = p_seed
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
	_next_milestone = 0
	_depleted_ticks = 0
	_low_warned = false


## Advances one tick. Returns {"spreads": [[from_id, to_id], ...],
## "toasts": [[text_key, args, severity], ...], "game_over": bool, "won": bool, "reason": String}
func step() -> Dictionary:
	var spreads: Array = []
	var toasts: Array = []
	if over:
		return {"spreads": spreads, "toasts": toasts, "game_over": true, "won": won, "reason": reason}
	tick += 1
	var heat: float = maxf(temperature - B.TEMP_START, 0.0)

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
	_update_spread(spreads, toasts)
	# 4. Climate, economy and alerts.
	_update_temperature(toasts)
	_update_resources(toasts)
	_update_region_alerts(toasts)
	peak_crisis = maxf(peak_crisis, avg_crisis())
	# 5. Win / lose.
	_check_end()
	return {"spreads": spreads, "toasts": toasts, "game_over": over, "won": won, "reason": reason}


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


## Keys documented in docs/ARCHITECTURE.md "Snapshot"; "spreads" (int) is an extra stat.
func snapshot() -> Dictionary:
	var y: float = year()
	var y_int: int = int(floorf(y))
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
	}


func region_dict(region_id: String) -> Dictionary:
	if not regions.has(region_id):
		return {}
	var r: RegionData = regions[region_id]
	return r.to_dict()


func can_afford(action_id: String) -> bool:
	if not B.ACTIONS.has(action_id):
		return false
	var def: Dictionary = B.ACTIONS[action_id]
	var cost: Dictionary = def["cost"]
	return budget >= float(cost.get("budget", 0.0)) \
		and political >= float(cost.get("political", 0.0)) \
		and science >= float(cost.get("science", 0.0))


func can_perform(action_id: String, region_id: String) -> bool:
	return not over and regions.has(region_id) and can_afford(action_id) and cooldown_left_ticks(action_id, region_id) == 0


## Pollution a cleanup would remove in region_id now: skimmers collect more where there is
## more waste (CLEANUP_POLLUTION_DROP at pollution CLEANUP_REF_POLLUTION).
func cleanup_amount(region_id: String) -> float:
	if not regions.has(region_id):
		return 0.0
	var r: RegionData = regions[region_id]
	var factor: float = clampf(r.pollution / B.CLEANUP_REF_POLLUTION, B.CLEANUP_MIN_SCALE, B.CLEANUP_MAX_SCALE)
	return minf(B.CLEANUP_POLLUTION_DROP * factor, r.pollution)


## Ticks until action_id can be used again on region_id (0 = ready).
func cooldown_left_ticks(action_id: String, region_id: String) -> int:
	var key: String = _cd_key(action_id, region_id)
	if not _ready_at.has(key):
		return 0
	var ready_tick: int = _ready_at[key]
	return maxi(ready_tick - tick, 0)


## Returns {"ok": bool, "spreads": [], "toasts": [[text_key, args, severity], ...]}
func perform(action_id: String, region_id: String) -> Dictionary:
	var toasts: Array = []
	if not can_perform(action_id, region_id):
		return {"ok": false, "spreads": [], "toasts": toasts}
	var def: Dictionary = B.ACTIONS[action_id]
	var cost: Dictionary = def["cost"]
	budget = maxf(budget - float(cost.get("budget", 0.0)), 0.0)
	political = maxf(political - float(cost.get("political", 0.0)), 0.0)
	science = maxf(science - float(cost.get("science", 0.0)), 0.0)

	var r: RegionData = _region(region_id)
	match action_id:
		"cleanup":
			r.pollution -= cleanup_amount(region_id)
		"patrol":
			r.protection += _saturated(B.PATROL_PROTECTION_GAIN, r.protection, B.PATROL_SATURATION)
		"campaign":
			r.awareness += _saturated(B.CAMPAIGN_AWARENESS_GAIN, r.awareness, B.CAMPAIGN_SATURATION)
			var links: Array = _links[region_id]
			for l in links:
				var link: Dictionary = l
				var other_id: String = link["id"]
				var other: RegionData = _region(other_id)
				other.awareness += _saturated(B.CAMPAIGN_AWARENESS_GAIN * B.CAMPAIGN_NEIGHBOR_SHARE, other.awareness, B.CAMPAIGN_SATURATION)
				other.clamp_all()
	r.clamp_all()

	var cooldown: int = int(def["cooldown_ticks"])
	_ready_at[_cd_key(action_id, region_id)] = tick + cooldown
	actions_used += 1
	var branch: String = def["branch"]
	branch_usage[branch] = int(branch_usage.get(branch, 0)) + 1
	var toast_key: String = def["toast_key"]
	# Player feedback is never rate-limited: per (action, region) cooldowns already bound it.
	toasts.append([toast_key, {"region": r.name_key}, 0])
	return {"ok": true, "spreads": [], "toasts": toasts}


# --- Per-tick model --------------------------------------------------------------------------

## delta = base + sum(neighbour pollution x route weight) + heat stress + coastal inflow
##         - protection - awareness   (README "SIMULATION DESIGN")
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
	return B.BASE_POLLUTION_RATE \
		+ pressure * B.NEIGHBOR_PRESSURE_COEFF \
		+ heat * B.TEMP_STRESS_COEFF \
		+ r.coastal_pop * B.SOURCE_INFLOW_COEFF \
		- (r.protection * B.PROTECT_COEFF + r.awareness * B.AWARE_COEFF) * lever_share


## Coral, Posidonia seagrass and fish respond to pollution, heat and protection.
func _update_ecology(r: RegionData, heat: float) -> void:
	# Below BIO_SAFE_POLLUTION clean water lets life regrow; above it pollution damages it.
	var clean01: float = clampf((B.BIO_SAFE_POLLUTION - r.pollution) / B.BIO_SAFE_POLLUTION, 0.0, 1.0)
	var dirty01: float = clampf((r.pollution - B.BIO_SAFE_POLLUTION) / (100.0 - B.BIO_SAFE_POLLUTION), 0.0, 1.0)
	var prot01: float = r.protection / 100.0
	# Protected reefs and meadows recover best in clean water (cleanup supports patrols).
	var guarded01: float = prot01 * (1.0 - dirty01 * B.BIO_DIRTY_RECOVERY_CUT)

	# Room to grow ^ BIO_ROOM_EXPONENT: recovery is quick when degraded, slow near pristine.
	var coral_room: float = pow(1.0 - r.coral_health / 100.0, B.BIO_ROOM_EXPONENT)
	r.coral_health += (B.CORAL_RECOVERY * guarded01 + B.CORAL_CLEAN_REGROWTH * clean01) * coral_room \
		- B.CORAL_POLLUTION_DAMAGE * dirty01 \
		- B.CORAL_HEAT_DAMAGE * heat

	var grass_room: float = pow(1.0 - r.seagrass / 100.0, B.BIO_ROOM_EXPONENT)
	r.seagrass += (B.SEAGRASS_RECOVERY * guarded01 + B.SEAGRASS_CLEAN_REGROWTH * clean01) * grass_room \
		- B.SEAGRASS_POLLUTION_DAMAGE * dirty01 \
		- B.SEAGRASS_HEAT_DAMAGE * heat

	# Fish: logistic regrowth (peaks at stock 50) helped by seagrass nurseries, minus
	# fishing (cut by no-take zones and by aware, sustainable demand) and pollution.
	var f: float = r.fish_stock
	var habitat: float = (1.0 - B.FISH_HABITAT_WEIGHT) + B.FISH_HABITAT_WEIGHT * r.seagrass / 100.0
	var regen: float = B.FISH_REGEN * (f + B.FISH_SEED_STOCK) * (1.0 - f / 100.0) / 25.0 * habitat
	var no_take01: float = clampf(prot01 * B.FISH_PROTECT_MULT, 0.0, 1.0)
	var demand: float = 1.0 - clampf(r.awareness / 100.0 * B.AWARE_FISHING_CUT, 0.0, 1.0)
	var harvest: float = B.FISHING_PRESSURE * (f / 50.0) * (1.0 - no_take01) * demand
	var poison: float = B.FISH_POLLUTION_DAMAGE * r.pollution / 100.0
	r.fish_stock = f + regen - harvest - poison


## Awareness fades from the news; protection erodes without enforcement, more slowly where
## the public backs it (awareness x AWARE_PROTECTION_HOLD).
func _decay_levers(r: RegionData) -> void:
	r.awareness -= B.AWARENESS_DECAY_PER_TICK + r.awareness * B.AWARENESS_DECAY_RATE
	var hold: float = 1.0 - clampf(r.awareness / 100.0 * B.AWARE_PROTECTION_HOLD, 0.0, 1.0)
	r.protection -= (B.PROTECTION_DECAY_PER_TICK + r.protection * B.PROTECTION_DECAY_RATE) * hold


## One roll per route per tick, from the worse region to the better one, when the source is
## above SPREAD_THRESHOLD and the route is not cooling down. Protection shields the target.
func _update_spread(spreads: Array, toasts: Array) -> void:
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
		var chance: float = B.SPREAD_CHANCE_PER_TICK * weight * _kind_mult(kind) * (c_src / 100.0) * shield
		if rng.randf() >= chance:
			continue
		dst.pollution += B.SPREAD_POLLUTION_BUMP * shield
		dst.coral_health -= B.SPREAD_BIO_DAMAGE * shield
		dst.seagrass -= B.SPREAD_BIO_DAMAGE * shield
		dst.fish_stock -= B.SPREAD_BIO_DAMAGE * shield
		dst.clamp_all()
		_route_cooldown[i] = B.SPREAD_ROUTE_COOLDOWN_TICKS
		spreads.append([src.id, dst.id])
		spread_count += 1
		if first_spread_tick < 0:
			first_spread_tick = tick
		_push_toast(toasts, "spread", "toast.spread", {"from": src.name_key, "to": dst.name_key}, 2, B.TOAST_MIN_GAP_TICKS)


## Base warming plus a share driven by the basin's average crisis; milestone toasts.
func _update_temperature(toasts: Array) -> void:
	var rise: float = B.TEMP_BASE_RISE_PER_TICK + B.TEMP_CRISIS_RISE_PER_TICK * avg_crisis() / 100.0
	temperature = minf(temperature + rise, B.TEMP_LOSE)
	while _next_milestone < B.TEMP_MILESTONES.size():
		var m: float = B.TEMP_MILESTONES[_next_milestone]
		if temperature < m:
			break
		var severity: int = 3 if m >= B.TEMP_ALARM_MILESTONE else 2
		if not _push_toast(toasts, "temperature", "toast.temp_warning", {"temp": "%.1f" % m}, severity, B.TOAST_MIN_GAP_TICKS):
			break
		_next_milestone += 1


## Budget follows the sea economy (fisheries, tourism), political support follows public
## awareness; both can turn negative below their break-even points. Science trickles in.
func _update_resources(toasts: Array) -> void:
	var h: float = sea_health()
	var budget_gain: float = B.BUDGET_INCOME_PER_TICK * (h - B.BUDGET_BREAKEVEN_HEALTH) \
		/ maxf(B.BUDGET_REF_HEALTH - B.BUDGET_BREAKEVEN_HEALTH, 1.0)
	budget = clampf(budget + budget_gain, 0.0, B.RESOURCE_CAP)
	var aw: float = avg_awareness()
	var political_gain: float = B.POLITICAL_INCOME_PER_TICK * (aw - B.POLITICAL_BREAKEVEN_AWARENESS) \
		/ maxf(B.POLITICAL_REF_AWARENESS - B.POLITICAL_BREAKEVEN_AWARENESS, 1.0)
	political = clampf(political + political_gain, 0.0, B.RESOURCE_CAP)
	science = clampf(science + B.SCIENCE_INCOME_PER_TICK, 0.0, B.RESOURCE_CAP)

	var depleted: bool = budget < B.DEPLETED_THRESHOLD and political < B.DEPLETED_THRESHOLD
	if depleted:
		_depleted_ticks += 1
		if _depleted_ticks == 1:
			_push_toast(toasts, "depleted", "toast.depleted", {}, 3, B.TOAST_MIN_GAP_TICKS)
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
func _update_region_alerts(toasts: Array) -> void:
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
		elif c < B.REGION_RECOVERED_CRISIS:
			if band != "recovered":
				if _push_toast(toasts, "recovering", "toast.region_recovering", {"region": r.name_key}, 1, B.TOAST_MIN_GAP_TICKS):
					_band[region_id] = "recovered"
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
