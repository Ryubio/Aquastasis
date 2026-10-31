extends SceneTree
## sim_test: headless balance test for crisis_sim.gd. Bots play full games on fixed seeds (field
## operations, policy adoptions, card answers, ~60% of data bubbles) and the script prints a results
## table, per-strategy summaries and the Phase 1 + Phase 2 balance targets (docs/ARCHITECTURE.md 7, 11.12).
## Run: "$G" --headless --path . -s res://scripts/sim_test.gd   (no autoloads: preloads only)

const CrisisSim := preload("res://scripts/crisis_sim.gd")
const B := preload("res://scripts/balance.gd")
const RegionData := preload("res://scripts/region.gd")
const TechTree := preload("res://scripts/tech_tree.gd")
const Events := preload("res://scripts/events.gd")

const SEEDS := [31, 7, 101, 2026, 4242, 77, 31337]
## do_nothing / spam_cleanup / balanced are the three required strategies. reckless probes the
## lose_resources path (spends every coin at once on the region that needs it least, never
## builds awareness, never adopts); greedy shows that even maximum effort is resource-bound.
const STRATEGIES := ["do_nothing", "spam_cleanup", "balanced", "reckless", "greedy"]
## Sensitivity variants (summary lines only): the other single-branch spams, the balanced bot
## without the policy tree, the balanced rotation at other paces (every_N = one operation every
## N ticks), and the rotation minus one operation.
const VARIANTS := ["spam_patrol", "spam_campaign", "ops_only", "every_6", "every_9", "every_16",
	"every_20", "no_cleanup", "no_patrol", "no_campaign"]
const BALANCED_INTERVAL := 12      # ticks between balanced operations (7.2 s at 1x)
const ROTATION := ["cleanup", "patrol", "campaign"]
const TIMELINE_EVERY := 100        # ticks between timeline samples
const ADOPT_EVERY := 5             # balanced bots look at the policy tree every this many ticks
const RESERVE_BUDGET := 70.0       # ... and keep this much for field operations when adopting
const RESERVE_POLITICAL := 16.0
const BUBBLE_PICK_MOD := 5         # bots pick up bubbles whose id % 5 < 3: 60% of them
const BUBBLE_PICK_BELOW := 3
const SPAM_ACTION := {"spam_cleanup": "cleanup", "spam_patrol": "patrol", "spam_campaign": "campaign"}


func _init() -> void:
	_run()
	quit(0)


func _run() -> void:
	print("")
	print("=== AQUASTASIS - simulation balance test (Phase 2) ===")
	print("Full game: %d ticks x %.1f s = %.0f s at 1x (%d -> %d)" % [
		B.TOTAL_TICKS, B.TICK_SECONDS, float(B.TOTAL_TICKS) * B.TICK_SECONDS / float(B.SPEEDS[1]),
		B.START_YEAR, B.END_YEAR])
	var start_sim: CrisisSim = CrisisSim.new(B.DEFAULT_SEED)
	print("Start: sea health %.1f%%, avg crisis %.1f, temperature +%.2f C, policy nodes %d, evolutions %d" % [
		start_sim.sea_health(), start_sim.avg_crisis(), start_sim.temperature,
		TechTree.all_nodes().size(), TechTree.all_evolutions().size()])
	print("")

	var header: String = _row(["strategy", "seed", "outcome", "reason", "end yr", "sea %", "temp", "1st spread",
		"1st alarm", "actions", "starved", "spreads", "1st evo", "evos", "cards", "nodes", "bubbles"])
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
				_evo_str(res),
				str(_evo_count(res)),
				str(res["cards"]),
				str(res["nodes"]),
				"%d/%d" % [int(res["bubbles"]), int(res["spawned"])],
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
	print("=== Timeline, seed %d (tick: year | sea health | temp | avg crisis | budget | political | science | nodes | resistances) ===" % B.DEFAULT_SEED)
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

## How a strategy treats the Phase 2 systems: "cards" "free" (always the no-cost choice) or "best"
## (the most hopeful affordable choice); "bubbles" picks up ~60%; "adopt" is "none", "balanced"
## (diverse, keeps a reserve), "greedy" (anything affordable) or "branch" (only its own branch).
func _profile(strategy: String) -> Dictionary:
	if strategy == "do_nothing" or strategy == "reckless":
		return {"cards": "free", "bubbles": false, "adopt": "none", "branch": ""}
	if SPAM_ACTION.has(strategy):
		var action_id: String = SPAM_ACTION[strategy]
		var def: Dictionary = B.ACTIONS[action_id]
		return {"cards": "free", "bubbles": true, "adopt": "branch", "branch": str(def["branch"])}
	if strategy == "ops_only":
		return {"cards": "best", "bubbles": true, "adopt": "none", "branch": ""}
	if strategy == "greedy":
		return {"cards": "best", "bubbles": true, "adopt": "greedy", "branch": ""}
	return {"cards": "best", "bubbles": true, "adopt": "balanced", "branch": ""}


func _play(strategy: String, p_seed: int, timeline: bool) -> Dictionary:
	var sim: CrisisSim = CrisisSim.new(p_seed)
	var prof: Dictionary = _profile(strategy)
	var st: Dictionary = {"slot": 0, "starved": 0, "stuck": 0}
	var guard: int = 0
	while not sim.over and guard < B.TOTAL_TICKS + 10:
		guard += 1
		_answer_card(sim, str(prof["cards"]), st)
		if bool(prof["bubbles"]):
			_collect_bubbles(sim)
		_adopt(sim, prof)
		_act(strategy, sim, st)
		sim.step()
		if timeline and (sim.tick % TIMELINE_EVERY == 0 or sim.over):
			print("  %4d: %.1f | %5.1f%% | +%.2f | %5.1f | %6.1f | %5.1f | %5.1f | %2d | %s" % [
				sim.tick, sim.year(), sim.sea_health(), sim.temperature, sim.avg_crisis(), sim.budget,
				sim.political, sim.science, sim.adopted_nodes().size(), ", ".join(PackedStringArray(sim.active_evolutions()))])
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
		"stuck": int(st["stuck"]),
		"spreads": sim.spread_count,
		"evos": sim.evolution_log.duplicate(true),
		"cards": sim.cards_seen,
		"nodes": sim.adopted_nodes().size(),
		"bubbles": sim.bubbles_collected_total,
		"spawned": sim.bubbles_spawned_total,
		"branch": str(prof["branch"]),
	}


## Answers a waiting decision card. "best": the most hopeful (highest tone) affordable choice;
## "free": the choice that costs nothing.
func _answer_card(sim: CrisisSim, mode: String, st: Dictionary) -> void:
	if sim.pending_event.is_empty():
		return
	var def: Dictionary = _event_def(str(sim.pending_event.get("id", "")))
	var choices: Array = def.get("choices", [])
	var pick: int = -1
	var best_tone: int = -100
	for i in range(choices.size()):
		var ch: Dictionary = choices[i]
		if not sim.can_choose(i):
			continue
		var tone: int = int(ch.get("tone", 0))
		var free: bool = _cost_total(ch.get("cost", {})) <= 0.0
		if mode == "free":
			if free:
				pick = i
				break
		elif tone > best_tone:
			best_tone = tone
			pick = i
	if pick < 0 or not bool(sim.resolve_event(pick)["ok"]):
		st["stuck"] = int(st["stuck"]) + 1
		if not bool(sim.resolve_event(choices.size() - 1)["ok"]):
			sim.pending_event = {}


func _collect_bubbles(sim: CrisisSim) -> void:
	for b in sim.active_bubbles():
		var bub: Dictionary = b
		var bid: int = int(bub["id"])
		if bid % BUBBLE_PICK_MOD < BUBBLE_PICK_BELOW:
			sim.collect_bubble(bid)


func _adopt(sim: CrisisSim, prof: Dictionary) -> void:
	match str(prof["adopt"]):
		"balanced":
			if sim.tick % ADOPT_EVERY == 0:
				_adopt_diverse(sim, true)
		"greedy":
			_adopt_diverse(sim, false)
		"branch":
			_adopt_branch(sim, str(prof["branch"]))


## Picks one affordable node: counters of active resistances first, then the branch with the
## fewest adoptions, then lower tiers and cheaper nodes. With reserve, budget / political for
## field operations are kept back.
func _adopt_diverse(sim: CrisisSim, reserve: bool) -> void:
	var active: Array = sim.active_evolutions()
	var per_branch: Dictionary = {}
	for nid in sim.adopted_nodes():
		var adopted_def: Dictionary = TechTree.node_def(str(nid))
		var ab: String = str(adopted_def.get("branch", ""))
		per_branch[ab] = int(per_branch.get(ab, 0)) + 1
	var best_id: String = ""
	var best_score: float = -1.0e9
	for n in TechTree.all_nodes():
		var def: Dictionary = n
		var node_id: String = str(def.get("id", ""))
		if not sim.can_adopt(node_id):
			continue
		var cost: Dictionary = sim.node_cost(node_id)
		if reserve and not _keeps_reserve(sim, cost):
			continue
		var score: float = 0.0
		var counters: Array = def.get("counters", [])
		for c in counters:
			if active.has(str(c)):
				score += 100.0
		score -= float(int(per_branch.get(str(def.get("branch", "")), 0))) * 10.0
		score -= float(int(def.get("tier", 1))) * 2.0
		score -= _cost_total(cost) * 0.02
		if score > best_score:
			best_score = score
			best_id = node_id
	if best_id != "":
		sim.adopt(best_id)


## One-branch spammer: the cheapest affordable node of its own branch, whenever it can.
func _adopt_branch(sim: CrisisSim, branch: String) -> void:
	var best_id: String = ""
	var best_cost: float = 1.0e9
	for n in TechTree.branch_nodes(branch):
		var def: Dictionary = n
		var node_id: String = str(def.get("id", ""))
		if not sim.can_adopt(node_id):
			continue
		var c: float = _cost_total(sim.node_cost(node_id))
		if c < best_cost:
			best_cost = c
			best_id = node_id
	if best_id != "":
		sim.adopt(best_id)


func _keeps_reserve(sim: CrisisSim, cost: Dictionary) -> bool:
	var cb: float = float(cost.get("budget", 0.0))
	var cp: float = float(cost.get("political", 0.0))
	if cb > 0.0 and sim.budget - cb < RESERVE_BUDGET:
		return false
	if cp > 0.0 and sim.political - cp < RESERVE_POLITICAL:
		return false
	return true


func _act(strategy: String, sim: CrisisSim, st: Dictionary) -> void:
	match strategy:
		"do_nothing":
			pass
		"spam_cleanup":
			_act_spam(sim)
		"balanced", "ops_only":
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


## Balanced play: one operation every `interval` ticks, rotating through `rotation`
## (cleanup -> patrol -> campaign); an unaffordable or cooling operation is skipped for the next
## one. "starved" counts slots whose scheduled operation was unaffordable.
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


## Every operation the moment it is ready and affordable, aimed like the balanced bot. "starved"
## counts ticks where some operation was ready on some region but could not be afforded.
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
## any); campaign -> lowest awareness. Only regions where the operation can be performed now.
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
	var sum_cards: float = 0.0
	var sum_nodes: float = 0.0
	var sum_bubbles: float = 0.0
	var sum_spawned: float = 0.0
	var evo_seen: Dictionary = {}     # evolution id -> [count, sum of ticks]
	var stuck: int = 0
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
		sum_cards += float(res["cards"])
		sum_nodes += float(res["nodes"])
		sum_bubbles += float(res["bubbles"])
		sum_spawned += float(res["spawned"])
		stuck += int(res["stuck"])
		var evos: Array = res["evos"]
		for e in evos:
			var item: Array = e
			var evo_id: String = str(item[1])
			var acc: Array = evo_seen.get(evo_id, [0, 0])
			evo_seen[evo_id] = [int(acc[0]) + 1, int(acc[1]) + int(item[0])]
	var n: float = float(maxi(rows.size(), 1))
	var reason_parts: PackedStringArray = PackedStringArray()
	for k in reasons.keys():
		var key: String = k
		reason_parts.append("%s x%d" % [key, int(reasons[key])])
	print("%s wins %d/%d | %s | avg end %.1f | avg sea %.1f%% | avg temp +%.2f | avg actions %.0f" % [
		strategy.rpad(13), wins, rows.size(), ", ".join(reason_parts), sum_year / n, sum_health / n, sum_temp / n, sum_actions / n])
	var evo_parts: PackedStringArray = PackedStringArray()
	for k in evo_seen.keys():
		var evo_id: String = k
		var acc: Array = evo_seen[evo_id]
		var cnt: int = int(acc[0])
		var avg_tick: float = float(int(acc[1])) / float(maxi(cnt, 1))
		evo_parts.append("%s %d/%d @t%.0f (%.1f)" % [evo_id, cnt, rows.size(), avg_tick, _year_of(avg_tick)])
	var evo_text: String = ", ".join(evo_parts) if not evo_parts.is_empty() else "none"
	var bubble_share: float = sum_bubbles / maxf(sum_spawned, 1.0) * 100.0
	print("%s cards %.1f | nodes %.1f | bubbles %.1f of %.1f (%.0f%%) | stuck cards %d | evolutions: %s" % [
		"".rpad(13), sum_cards / n, sum_nodes / n, sum_bubbles / n, sum_spawned / n, bubble_share, stuck, evo_text])


func _print_targets(results: Dictionary) -> void:
	var n: int = SEEDS.size()
	print("-- Phase 1 targets (with every Phase 2 system on) --")
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
		if bool(res["won"]) and h >= 58.0 and h <= 77.0:
			bal_band += 1
		bal_starved += int(res["starved"])
	_check("balanced wins on %d/%d seeds, %d of them with sea health ~60-75%%" % [bal_wins, n, bal_band], bal_wins * 2 > n and bal_band * 2 > n)

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
	_check("balanced starved on %d of ~%d operation slots (never starved)" % [bal_starved, slots], float(bal_starved) <= float(slots) * 0.1)
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

	print("-- Phase 2 targets (docs/ARCHITECTURE.md 11.12) --")
	# One-sided play provokes its own branch's resistance within about 3-5 minutes (<= 500 ticks).
	var spam_rows: Array = results["spam_cleanup"]
	var own_ok: int = 0
	var own_ticks: PackedStringArray = PackedStringArray()
	var first_ok: int = 0
	for r in spam_rows:
		var res: Dictionary = r
		var t_own: int = _branch_evo_tick(res)
		own_ticks.append(_tick_str(t_own))
		if t_own >= 0 and t_own <= 500:
			own_ok += 1
		var t_first: int = _first_evo_tick(res)
		var y_first: float = _year_of(float(t_first))
		if t_first >= 0 and y_first >= 2029.5 and y_first <= 2033.5:
			first_ok += 1
	_check("spam_cleanup provokes its resistance within ~3-5 min on %d/%d seeds (ticks %s)" % [
		own_ok, n, ", ".join(own_ticks)], own_ok * 2 > n)
	_check("first evolution of the one-sided bot around 2030-2033 on %d/%d seeds" % [first_ok, n], first_ok * 2 > n)
	var variant_ok: int = 0
	var variant_games: int = 0
	for s in ["spam_patrol", "spam_campaign"]:
		for r in results[s]:
			var res: Dictionary = r
			variant_games += 1
			if _branch_evo_tick(res) >= 0:
				variant_ok += 1
	print("       (info) spam_patrol + spam_campaign provoke their own resistance in %d/%d games" % [variant_ok, variant_games])

	# Balanced play keeps its strategy diverse: few or no branch resistances.
	var bal_branch: int = 0
	for r in bal:
		var res: Dictionary = r
		if _any_branch_evo(res):
			bal_branch += 1
	_check("balanced provokes a branch resistance on %d/%d seeds (diverse play, target few)" % [bal_branch, n], bal_branch * 3 <= n)

	# Cards per game.
	var cards_ok: int = 0
	var cards_txt: PackedStringArray = PackedStringArray()
	for r in bal:
		var res: Dictionary = r
		var c: int = res["cards"]
		cards_txt.append(str(c))
		if c >= 9 and c <= 12:
			cards_ok += 1
	_check("9-12 decision cards per full game on %d/%d balanced games (%s)" % [cards_ok, n, ", ".join(cards_txt)], cards_ok * 2 > n)

	# Policy adoptions.
	var nodes_ok: int = 0
	var nodes_txt: PackedStringArray = PackedStringArray()
	for r in bal:
		var res: Dictionary = r
		var k: int = res["nodes"]
		nodes_txt.append(str(k))
		if k >= 14 and k <= 20:
			nodes_ok += 1
	_check("balanced adopts 14-20 of %d nodes by 2046 on %d/%d seeds (%s)" % [
		TechTree.all_nodes().size(), nodes_ok, n, ", ".join(nodes_txt)], nodes_ok * 2 > n)

	# Bubble pickups and card answers work as scripted.
	var picked: float = 0.0
	var spawned: float = 0.0
	var stuck: int = 0
	for k in results.keys():
		for r in results[k]:
			var res: Dictionary = r
			stuck += int(res["stuck"])
			if bool(_profile(str(k))["bubbles"]):
				picked += float(res["bubbles"])
				spawned += float(res["spawned"])
	var share: float = picked / maxf(spawned, 1.0)
	_check("bots pick up %.0f%% of %d bubbles (target ~60%%), %d cards could not be answered" % [
		share * 100.0, int(spawned), stuck], share >= 0.5 and share <= 0.7 and stuck == 0)

	# The policy tree matters: the balanced bot does clearly better than the same bot without it.
	var ops: Array = results["ops_only"]
	var bal_avg: float = _avg(bal, "health")
	var ops_avg: float = _avg(ops, "health")
	_check("policy tree matters: balanced %.1f%% vs ops_only %.1f%% sea health" % [bal_avg, ops_avg], bal_avg >= ops_avg + 4.0)


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[MISS] ") + label)


func _count_wins(rows: Array) -> int:
	var wins: int = 0
	for r in rows:
		var res: Dictionary = r
		if bool(res["won"]):
			wins += 1
	return wins


func _avg(rows: Array, key: String) -> float:
	var acc: float = 0.0
	for r in rows:
		var res: Dictionary = r
		acc += float(res[key])
	return acc / float(maxi(rows.size(), 1))


## Tick at which the bot's own branch resistance evolved, -1 = never.
func _branch_evo_tick(res: Dictionary) -> int:
	var branch: String = res["branch"]
	if branch == "":
		return -1
	var evos: Array = res["evos"]
	for e in evos:
		var item: Array = e
		var def: Dictionary = TechTree.evolution_def(str(item[1]))
		if str(def.get("trigger", "")) == "branch" and str(def.get("branch", "")) == branch:
			return int(item[0])
	return -1


func _any_branch_evo(res: Dictionary) -> bool:
	var evos: Array = res["evos"]
	for e in evos:
		var item: Array = e
		var def: Dictionary = TechTree.evolution_def(str(item[1]))
		if str(def.get("trigger", "")) == "branch":
			return true
	return false


func _first_evo_tick(res: Dictionary) -> int:
	var evos: Array = res["evos"]
	if evos.is_empty():
		return -1
	var first: Array = evos[0]
	return int(first[0])


func _evo_count(res: Dictionary) -> int:
	var evos: Array = res["evos"]
	return evos.size()


func _evo_str(res: Dictionary) -> String:
	var t: int = _first_evo_tick(res)
	if t < 0:
		return "-"
	return "%d (%.1f)" % [t, _year_of(float(t))]


func _year_of(t: float) -> float:
	return float(B.START_YEAR) + float(B.END_YEAR - B.START_YEAR) * t / float(B.TOTAL_TICKS)


func _cost_total(cost: Dictionary) -> float:
	return float(cost.get("budget", 0.0)) + float(cost.get("political", 0.0)) + float(cost.get("science", 0.0))


func _event_def(event_id: String) -> Dictionary:
	return Events.event_def(event_id)


func _tick_str(t: int) -> String:
	if t < 0:
		return "-"
	return "%d (%.0fs)" % [t, float(t) * B.TICK_SECONDS]


func _row(cols: Array) -> String:
	var widths: Array = [13, 6, 8, 17, 7, 6, 6, 11, 11, 8, 8, 7, 14, 5, 6, 6, 8]
	var out: String = ""
	for i in range(cols.size()):
		var w: int = widths[i] if i < widths.size() else 8
		out += str(cols[i]).rpad(w) + " "
	return out.strip_edges(false, true)
