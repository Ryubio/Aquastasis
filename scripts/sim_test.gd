extends SceneTree
## sim_test: headless balance test for crisis_sim.gd. Plays full games with scripted
## strategies on fixed seeds and prints a results table, per-strategy summaries and target checks.
## Run: "$G" --headless --path . -s res://scripts/sim_test.gd   (no autoloads: preloads only)

const CrisisSim := preload("res://scripts/crisis_sim.gd")
const B := preload("res://scripts/balance.gd")
const RegionData := preload("res://scripts/region.gd")

const SEEDS := [31, 7, 101, 2026, 4242, 77, 31337]
## do_nothing / spam_cleanup / balanced are the three required strategies. reckless probes the
## lose_resources path (spends every coin at once on the region that needs it least, never
## builds awareness); greedy shows that even well-aimed maximum effort is resource-bound.
const STRATEGIES := ["do_nothing", "spam_cleanup", "balanced", "reckless", "greedy"]
## Sensitivity variants (summary lines only): the other single-branch spams, the balanced
## rotation at other paces (every_N = one action every N ticks), and the rotation minus one branch.
const VARIANTS := ["spam_patrol", "spam_campaign", "every_6", "every_9", "every_16", "every_20",
	"no_cleanup", "no_patrol", "no_campaign"]
const BALANCED_INTERVAL := 12      # ticks between balanced actions (7.2 s at 1x)
const ROTATION := ["cleanup", "patrol", "campaign"]
const TIMELINE_EVERY := 100        # ticks between timeline samples


func _init() -> void:
	_run()
	quit(0)


func _run() -> void:
	print("")
	print("=== PULSE OF THE MEDITERRANEAN - simulation balance test ===")
	print("Full game: %d ticks x %.1f s = %.0f s at 1x (%d -> %d)" % [
		B.TOTAL_TICKS, B.TICK_SECONDS, float(B.TOTAL_TICKS) * B.TICK_SECONDS / float(B.SPEEDS[1]),
		B.START_YEAR, B.END_YEAR])
	var start_sim: CrisisSim = CrisisSim.new(B.DEFAULT_SEED)
	print("Start: sea health %.1f%%, avg crisis %.1f, temperature +%.2f C" % [
		start_sim.sea_health(), start_sim.avg_crisis(), start_sim.temperature])
	print("")

	var header: String = _row(["strategy", "seed", "outcome", "reason", "end yr", "sea %", "temp", "1st spread", "1st alarm", "actions", "starved", "spreads"])
	print(header)
	print("-".repeat(header.length()))
	var results: Dictionary = {}
	for s in STRATEGIES:
		var strategy: String = s
		var rows: Array = []
		for sd in SEEDS:
			var p_seed: int = sd
			var res: Dictionary = _play(strategy, p_seed, false)
			rows.append(res)
			print(_row([
				strategy,
				str(p_seed),
				"WIN" if bool(res["won"]) else "LOSE",
				str(res["reason"]),
				"%.1f" % float(res["year"]),
				"%.1f" % float(res["health"]),
				"+%.2f" % float(res["temp"]),
				_tick_str(int(res["first_spread"])),
				_tick_str(int(res["first_alarm"])),
				str(res["actions"]),
				str(res["starved"]),
				str(res["spreads"]),
			]))
		results[strategy] = rows
		print("-".repeat(header.length()))

	print("")
	print("=== Summary per strategy ===")
	for s in STRATEGIES:
		var strategy: String = s
		_print_summary(strategy, results[strategy])

	print("")
	print("=== Sensitivity: other play styles (same seeds) ===")
	for v in VARIANTS:
		var variant: String = v
		var rows: Array = []
		for sd in SEEDS:
			var p_seed: int = sd
			rows.append(_play(variant, p_seed, false))
		results[variant] = rows
		_print_summary(variant, rows)

	print("")
	print("=== Timeline, seed %d (tick: year | sea health | temp | avg crisis | budget | political) ===" % B.DEFAULT_SEED)
	for s in ["do_nothing", "balanced"]:
		var strategy: String = s
		print(strategy + ":")
		_play(strategy, B.DEFAULT_SEED, true)

	print("")
	print("=== Balance targets ===")
	_print_targets(results)
	print("")
	print("SIM TEST DONE")


# --- One game ---------------------------------------------------------------------------------

func _play(strategy: String, p_seed: int, timeline: bool) -> Dictionary:
	var sim: CrisisSim = CrisisSim.new(p_seed)
	var st: Dictionary = {"slot": 0, "starved": 0}
	var guard: int = 0
	while not sim.over and guard < B.TOTAL_TICKS + 10:
		guard += 1
		_act(strategy, sim, st)
		sim.step()
		if timeline and (sim.tick % TIMELINE_EVERY == 0 or sim.over):
			print("  %4d: %.1f | %5.1f%% | +%.2f | %5.1f | %6.1f | %5.1f" % [
				sim.tick, sim.year(), sim.sea_health(), sim.temperature, sim.avg_crisis(), sim.budget, sim.political])
	return {
		"won": sim.won,
		"reason": sim.reason,
		"year": sim.year(),
		"health": sim.sea_health(),
		"temp": sim.temperature,
		"first_spread": sim.first_spread_tick,
		"first_alarm": sim.first_alarm_tick,
		"actions": sim.actions_used,
		"starved": int(st["starved"]),
		"spreads": sim.spread_count,
	}


func _act(strategy: String, sim: CrisisSim, st: Dictionary) -> void:
	match strategy:
		"do_nothing":
			pass
		"spam_cleanup":
			_act_spam(sim)
		"balanced":
			_act_rotation(sim, st, BALANCED_INTERVAL, ROTATION)
		"reckless":
			_act_reckless(sim)
		"greedy":
			_act_greedy(sim, st)
		"spam_patrol", "spam_campaign":
			var action_id: String = strategy.trim_prefix("spam_")
			var target: String = _pick_target(sim, action_id)
			if target != "":
				sim.perform(action_id, target)
		"no_cleanup":
			_act_rotation(sim, st, BALANCED_INTERVAL, ["patrol", "campaign"])
		"no_patrol":
			_act_rotation(sim, st, BALANCED_INTERVAL, ["cleanup", "campaign"])
		"no_campaign":
			_act_rotation(sim, st, BALANCED_INTERVAL, ["cleanup", "patrol"])
		_:
			if strategy.begins_with("every_"):
				_act_rotation(sim, st, maxi(strategy.trim_prefix("every_").to_int(), 1), ROTATION)


## Cleanup only, always on the most polluted region, whenever it is possible.
func _act_spam(sim: CrisisSim) -> void:
	var target: String = ""
	var worst: float = -1.0
	for rid in RegionData.IDS:
		var region_id: String = rid
		var r: RegionData = sim.regions[region_id]
		if r.pollution > worst:
			worst = r.pollution
			target = region_id
	if target != "" and sim.can_perform("cleanup", target):
		sim.perform("cleanup", target)


## Balanced play: one action every `interval` ticks, rotating through `rotation`
## (cleanup -> patrol -> campaign); an unaffordable or cooling action is skipped for the next
## one. "starved" counts slots whose scheduled action was unaffordable.
func _act_rotation(sim: CrisisSim, st: Dictionary, interval: int, rotation: Array) -> void:
	if sim.tick % interval != 0:
		return
	var k: int = st["slot"]
	st["slot"] = k + 1
	var scheduled: String = rotation[k % rotation.size()]
	if not sim.can_afford(scheduled):
		st["starved"] = int(st["starved"]) + 1
	for i in range(rotation.size()):
		var action_id: String = rotation[(k + i) % rotation.size()]
		var target: String = _pick_target(sim, action_id)
		if target != "" and bool(sim.perform(action_id, target)["ok"]):
			return


## Spends everything the moment it can, on the healthiest region, and never campaigns:
## the economy collapses with the sea while no reserves are kept.
func _act_reckless(sim: CrisisSim) -> void:
	for a in ["cleanup", "patrol"]:
		var action_id: String = a
		var target: String = ""
		var best: float = 1000.0
		for rid in RegionData.IDS:
			var region_id: String = rid
			var r: RegionData = sim.regions[region_id]
			var c: float = r.crisis_level()
			if c < best and sim.can_perform(action_id, region_id):
				best = c
				target = region_id
		if target != "":
			sim.perform(action_id, target)


## Every action the moment it is ready and affordable, aimed like the balanced bot. "starved"
## counts ticks where some action was ready on some region but could not be afforded.
func _act_greedy(sim: CrisisSim, st: Dictionary) -> void:
	var starved: bool = false
	for a in ROTATION:
		var action_id: String = a
		if not sim.can_afford(action_id):
			for rid in RegionData.IDS:
				var region_id: String = rid
				if sim.cooldown_left_ticks(action_id, region_id) == 0:
					starved = true
					break
			continue
		var target: String = _pick_target(sim, action_id)
		if target != "":
			sim.perform(action_id, target)
	if starved:
		st["starved"] = int(st["starved"]) + 1


## cleanup -> worst pollution; patrol -> least-protected critical region (then stressed, then
## any); campaign -> lowest awareness. Only regions where the action can be performed now.
func _pick_target(sim: CrisisSim, action_id: String) -> String:
	if action_id == "patrol":
		for tier in [B.STATUS_CRITICAL, B.STATUS_STRESSED, -1.0]:
			var min_crisis: float = tier
			var best_id: String = ""
			var best_prot: float = 1000.0
			for rid in RegionData.IDS:
				var region_id: String = rid
				var r: RegionData = sim.regions[region_id]
				if r.crisis_level() >= min_crisis and r.protection < best_prot and sim.can_perform(action_id, region_id):
					best_prot = r.protection
					best_id = region_id
			if best_id != "":
				return best_id
		return ""
	var target: String = ""
	var best_score: float = -1000.0
	for rid in RegionData.IDS:
		var region_id: String = rid
		if not sim.can_perform(action_id, region_id):
			continue
		var r: RegionData = sim.regions[region_id]
		var score: float = r.pollution if action_id == "cleanup" else -r.awareness
		if score > best_score:
			best_score = score
			target = region_id
	return target


# --- Reporting ---------------------------------------------------------------------------------

func _print_summary(strategy: String, rows: Array) -> void:
	var wins: int = 0
	var reasons: Dictionary = {}
	var sum_year: float = 0.0
	var sum_health: float = 0.0
	var sum_temp: float = 0.0
	var sum_actions: float = 0.0
	for r in rows:
		var res: Dictionary = r
		if bool(res["won"]):
			wins += 1
		var why: String = res["reason"]
		reasons[why] = int(reasons.get(why, 0)) + 1
		sum_year += float(res["year"])
		sum_health += float(res["health"])
		sum_temp += float(res["temp"])
		sum_actions += float(res["actions"])
	var n: float = float(maxi(rows.size(), 1))
	var reason_parts: PackedStringArray = PackedStringArray()
	for k in reasons.keys():
		var key: String = k
		reason_parts.append("%s x%d" % [key, int(reasons[key])])
	print("%s wins %d/%d | %s | avg end %.1f | avg sea %.1f%% | avg temp +%.2f | avg actions %.0f" % [
		strategy.rpad(13), wins, rows.size(), ", ".join(reason_parts), sum_year / n, sum_health / n, sum_temp / n, sum_actions / n])


func _print_targets(results: Dictionary) -> void:
	var n: int = SEEDS.size()
	var minutes: float = float(B.TOTAL_TICKS) * B.TICK_SECONDS / float(B.SPEEDS[1]) / 60.0
	_check("full game at 1x lasts %.1f min (target 8-12)" % minutes, minutes >= 8.0 and minutes <= 12.0)

	var dn: Array = results["do_nothing"]
	var dn_ok: int = 0
	for r in dn:
		var res: Dictionary = r
		var y: float = res["year"]
		if not bool(res["won"]) and y >= 2040.0 and y <= 2045.0:
			dn_ok += 1
	_check("do_nothing loses in 2040-2045 on %d/%d seeds" % [dn_ok, n], dn_ok * 2 > n)

	var spam_wins: int = _count_wins(results["spam_cleanup"])
	_check("spam_cleanup wins on %d/%d seeds (target 0)" % [spam_wins, n], spam_wins == 0)
	var other_spam_wins: int = _count_wins(results["spam_patrol"]) + _count_wins(results["spam_campaign"])
	_check("spam_patrol + spam_campaign win on %d/%d games (target 0)" % [other_spam_wins, n * 2], other_spam_wins == 0)

	var bal: Array = results["balanced"]
	var bal_wins: int = _count_wins(bal)
	var bal_band: int = 0
	var bal_starved: int = 0
	for r in bal:
		var res: Dictionary = r
		var h: float = res["health"]
		if bool(res["won"]) and h >= 58.0 and h <= 72.0:
			bal_band += 1
		bal_starved += int(res["starved"])
	_check("balanced wins on %d/%d seeds, %d of them with sea health ~60-70%%" % [bal_wins, n, bal_band], bal_wins * 2 > n and bal_band * 2 > n)

	var spread_ok: int = 0
	var alarm_ok: int = 0
	for r in dn:
		var res: Dictionary = r
		var fs: int = res["first_spread"]
		var fa: int = res["first_alarm"]
		if fs >= 0 and fs <= 33:
			spread_ok += 1
		if fa >= 0 and fa <= 100:
			alarm_ok += 1
	_check("first spread within 33 ticks (20 s) on %d/%d seeds" % [spread_ok, n], spread_ok * 2 > n)
	_check("first critical alarm within 100 ticks (60 s) on %d/%d seeds" % [alarm_ok, n], alarm_ok * 2 > n)

	var slots: int = n * (int(float(B.TOTAL_TICKS) / float(BALANCED_INTERVAL)) + 1)
	_check("balanced starved on %d of ~%d action slots (never starved)" % [bal_starved, slots], float(bal_starved) <= float(slots) * 0.1)
	var greedy_starved: int = 0
	for r in results["greedy"]:
		var res: Dictionary = r
		greedy_starved += int(res["starved"])
	_check("greedy is resource-bound on %d ticks (cannot afford everything)" % greedy_starved, greedy_starved > 0)

	var reckless_res: int = 0
	for r in results["reckless"]:
		var res: Dictionary = r
		if str(res["reason"]) == "lose_resources":
			reckless_res += 1
	var main_res: int = 0
	for s in ["do_nothing", "spam_cleanup", "balanced"]:
		for r in results[s]:
			var res: Dictionary = r
			if str(res["reason"]) == "lose_resources":
				main_res += 1
	_check("lose_resources reachable: reckless %d/%d, required strategies %d/%d" % [reckless_res, n, main_res, n * 3], reckless_res > 0 and main_res * 3 <= n)

	var crisis_wins: int = 0
	for k in results.keys():
		for r in results[k]:
			var res: Dictionary = r
			if str(res["reason"]) == "win_crisis":
				crisis_wins += 1
	_check("win_crisis (every region below %.0f) reachable by intense play: %d games" % [B.WIN_ALL_CRISIS_BELOW, crisis_wins], crisis_wins > 0)


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[MISS] ") + label)


func _count_wins(rows: Array) -> int:
	var wins: int = 0
	for r in rows:
		var res: Dictionary = r
		if bool(res["won"]):
			wins += 1
	return wins


func _tick_str(t: int) -> String:
	if t < 0:
		return "-"
	return "%d (%.0fs)" % [t, float(t) * B.TICK_SECONDS]


func _row(cols: Array) -> String:
	var widths: Array = [13, 6, 8, 17, 7, 6, 6, 11, 11, 8, 8, 7]
	var out: String = ""
	for i in range(cols.size()):
		var w: int = widths[i] if i < widths.size() else 8
		out += str(cols[i]).rpad(w) + " "
	return out.strip_edges(false, true)
