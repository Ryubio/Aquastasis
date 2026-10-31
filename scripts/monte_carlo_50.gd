extends SceneTree
## monte_carlo_50.gd: Autonomous 50+ Game Playtester for AQUASTASIS
## Simulates 50+ full-length games (240 ticks / 20 years each) across 10 distinct seeds
## and 5 realistic player archetypes + benchmark controls.
## Gathers comprehensive metrics on win rates, resources, temperatures, mutations,
## repeatable projects, and policy adoptions to diagnose balance and pacing issues.

const CrisisSim := preload("res://scripts/crisis_sim.gd")
const B := preload("res://scripts/balance.gd")
const RegionData := preload("res://scripts/region.gd")
const TechTree := preload("res://scripts/tech_tree.gd")
const Events := preload("res://scripts/events.gd")

const SEEDS := [31, 7, 101, 2026, 4242, 77, 31337, 8888, 55555, 99999]
const ARCHETYPES := [
	"balanced",
	"science_tech",
	"conservation",
	"source_cutter",
	"diplomacy_eco",
	"human_casual",
	"struggling_player",
	"no_project_player"
]

func _init() -> void:
	_run_suite()
	quit(0)


func _run_suite() -> void:
	print("")
	print("================================================================================")
	print("       AQUASTASIS - 50-GAME MONTE CARLO BALANCE & PLAYABILITY SUITE            ")
	print("================================================================================")
	print("Running 10 Seeds x 5 Archetypes = 50 Full 20-Year Games (240 ticks / 600s each)")
	print("Start Year: %d -> End Year: %d | Base Warming: +%.2f C" % [B.START_YEAR, B.END_YEAR, B.TEMP_START])
	print("")

	var total_runs := 0
	var total_wins := 0
	var stats_by_archetype: Dictionary = {}

	for arch in ARCHETYPES:
		stats_by_archetype[arch] = {
			"wins": 0, "losses": 0, "reasons": {},
			"final_health": [], "final_temp": [], "final_crisis": [],
			"final_budget": [], "final_political": [], "final_science": [],
			"nodes_adopted": [], "projects_run": [], "mutations_cured": [],
			"operations_used": [], "bubbles_collected": []
		}

	print("%-16s | %-6s | %-6s | %-14s | %-5s | %-6s | %-6s | %-5s | %-4s | %-4s | %-4s" % [
		"ARCHETYPE", "SEED", "RESULT", "REASON", "YEAR", "HEALTH", "TEMP", "CRISIS", "NODE", "PROJ", "CURE"
	])
	print("-".repeat(95))

	for arch in ARCHETYPES:
		for sd in SEEDS:
			total_runs += 1
			var res: Dictionary = _simulate_game(arch, sd)
			var won: bool = bool(res["won"])
			if won:
				total_wins += 1
				stats_by_archetype[arch]["wins"] += 1
			else:
				stats_by_archetype[arch]["losses"] += 1

			var r_key: String = str(res["reason"])
			var reasons: Dictionary = stats_by_archetype[arch]["reasons"]
			reasons[r_key] = int(reasons.get(r_key, 0)) + 1

			stats_by_archetype[arch]["final_health"].append(res["health"])
			stats_by_archetype[arch]["final_temp"].append(res["temp"])
			stats_by_archetype[arch]["final_crisis"].append(res["avg_crisis"])
			stats_by_archetype[arch]["final_budget"].append(res["budget"])
			stats_by_archetype[arch]["final_political"].append(res["political"])
			stats_by_archetype[arch]["final_science"].append(res["science"])
			stats_by_archetype[arch]["nodes_adopted"].append(res["nodes"])
			stats_by_archetype[arch]["projects_run"].append(res["projects_run"])
			stats_by_archetype[arch]["mutations_cured"].append(res["mutations_cured"])
			stats_by_archetype[arch]["operations_used"].append(res["actions"])
			stats_by_archetype[arch]["bubbles_collected"].append(res["bubbles"])

			print("%-16s | %-6d | %-6s | %-14s | %-5.1f | %5.1f%% | +%4.2fC | %5.1f | %-4d | %-4d | %-4d" % [
				arch, sd, "WIN" if won else "LOSE", r_key,
				float(res["year"]), float(res["health"]), float(res["temp"]), float(res["avg_crisis"]),
				int(res["nodes"]), int(res["projects_run"]), int(res["mutations_cured"])
			])
		print("-".repeat(95))

	print("")
	print("================================================================================")
	print("                     50-GAME AGGREGATE SUMMARY & FINDINGS                       ")
	print("================================================================================")
	print("Total Games Completed: %d | Total Wins: %d (%.1f%% overall win rate)" % [
		total_runs, total_wins, (float(total_wins) / float(total_runs)) * 100.0
	])
	print("")

	for arch in ARCHETYPES:
		var st: Dictionary = stats_by_archetype[arch]
		var runs_count: int = int(st["wins"]) + int(st["losses"])
		var win_rate: float = (float(st["wins"]) / float(runs_count)) * 100.0
		var avg_h: float = _avg(st["final_health"])
		var avg_t: float = _avg(st["final_temp"])
		var avg_c: float = _avg(st["final_crisis"])
		var avg_b: float = _avg(st["final_budget"])
		var avg_p: float = _avg(st["final_political"])
		var avg_s: float = _avg(st["final_science"])
		var avg_nodes: float = _avg(st["nodes_adopted"])
		var avg_proj: float = _avg(st["projects_run"])
		var avg_cure: float = _avg(st["mutations_cured"])
		var avg_ops: float = _avg(st["operations_used"])
		var avg_bubs: float = _avg(st["bubbles_collected"])

		print(">>> Archetype: %s" % arch.to_upper())
		print("    Win Rate: %d/%d (%.1f%%) | Loss reasons: %s" % [
			int(st["wins"]), runs_count, win_rate, str(st["reasons"])
		])
		print("    Sea Health: %.1f%% | Temp: +%.2f C | Avg Regional Crisis: %.1f" % [avg_h, avg_t, avg_c])
		print("    Avg End Resources -> Budget: %.1f | Political: %.1f | Science: %.1f" % [avg_b, avg_p, avg_s])
		print("    Avg Activity     -> Nodes: %.1f/24 | Projects: %.1f | Cures: %.1f | Ops: %.1f | Bubbles: %.1f" % [
			avg_nodes, avg_proj, avg_cure, avg_ops, avg_bubs
		])
		print("")

	print("================================================================================")
	print("MONTE CARLO 50 FINISHED SUCCESSFULLY")


func _simulate_game(archetype: String, p_seed: int) -> Dictionary:
	var sim: CrisisSim = CrisisSim.new(p_seed)
	var projects_run := 0
	var mutations_cured := 0
	var guard := 0

	# Archetype settings:
	# bubble_rate: chance to pick up spawned bubble
	# op_interval: ticks between regional operations
	# op_rotation: action priority
	# primary_branch: focus branch for tech tree
	var bubble_chance := 0.60
	var op_interval := 10
	var op_rotation := ["cleanup", "patrol", "campaign"]
	var primary_branch := ""
	var reserve_budget := 50.0
	var reserve_political := 12.0

	match archetype:
		"balanced":
			bubble_chance = 0.65
			op_interval = 10
			op_rotation = ["cleanup", "patrol", "campaign"]
			primary_branch = ""
			reserve_budget = 50.0
			reserve_political = 12.0
		"science_tech":
			bubble_chance = 0.80
			op_interval = 12
			op_rotation = ["campaign", "cleanup", "patrol"]
			primary_branch = "science"
			reserve_budget = 40.0
			reserve_political = 8.0
		"conservation":
			bubble_chance = 0.55
			op_interval = 8
			op_rotation = ["patrol", "cleanup", "campaign"]
			primary_branch = "protect"
			reserve_budget = 40.0
			reserve_political = 18.0
		"source_cutter":
			bubble_chance = 0.55
			op_interval = 8
			op_rotation = ["cleanup", "patrol", "campaign"]
			primary_branch = "source"
			reserve_budget = 60.0
			reserve_political = 8.0
		"diplomacy_eco":
			bubble_chance = 0.70
			op_interval = 10
			op_rotation = ["campaign", "patrol", "cleanup"]
			primary_branch = "economy"
			reserve_budget = 30.0
			reserve_political = 10.0
		"human_casual":
			bubble_chance = 0.45
			op_interval = 16
			op_rotation = ["cleanup", "campaign", "patrol"]
			primary_branch = ""
			reserve_budget = 50.0
			reserve_political = 15.0
		"struggling_player":
			bubble_chance = 0.30
			op_interval = 22
			op_rotation = ["cleanup", "patrol"]
			primary_branch = ""
			reserve_budget = 60.0
			reserve_political = 20.0
		"no_project_player":
			bubble_chance = 0.60
			op_interval = 12
			op_rotation = ["cleanup", "patrol", "campaign"]
			primary_branch = ""
			reserve_budget = 50.0
			reserve_political = 15.0

	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed + 999

	while not sim.over and guard < B.TOTAL_TICKS + 10:
		guard += 1

		# 1. Answer event cards (choose best affordable option)
		if not sim.pending_event.is_empty():
			_answer_card(sim)

		# 2. Bubble collection
		for b in sim.active_bubbles():
			var bid: int = int(b["id"])
			if rng.randf() <= bubble_chance:
				sim.collect_bubble(bid)

		# 3. Crisis mutation counter-research (spend 30 Science to cure resistance)
		var active_evos: Array = sim.active_evolutions()
		if not active_evos.is_empty():
			var to_cure: String = str(active_evos[0])
			if sim.can_synthesize_counter(to_cure):
				var cure_res: Dictionary = sim.synthesize_counter(to_cure)
				if bool(cure_res.get("ok", false)):
					mutations_cured += 1

		# 4. Repeatable science projects
		var allows_projects: bool = (archetype != "no_project_player" and archetype != "struggling_player")
		if allows_projects:
			var do_project: bool = (archetype != "human_casual" or rng.randf() < 0.25)
			if do_project:
				if sim.can_perform_project("bio_algae") and (sim.temperature > 2.0 or archetype == "science_tech"):
					var p_res: Dictionary = sim.perform_project("bio_algae")
					if bool(p_res.get("ok", false)):
						projects_run += 1
				elif sim.can_perform_project("drone_swarm") and (sim.avg_crisis() > 40.0 or archetype == "science_tech"):
					var p_res: Dictionary = sim.perform_project("drone_swarm")
					if bool(p_res.get("ok", false)):
						projects_run += 1

		# 5. Policy Tree Adoption (every 4 ticks)
		if sim.tick % 4 == 0:
			_adopt_policy(sim, primary_branch, reserve_budget, reserve_political)

		# 6. Field operations (rotational or targeted)
		if sim.tick % op_interval == 0:
			_perform_field_op(sim, op_rotation)

		# Step the simulation
		sim.step()

	return {
		"won": sim.won,
		"reason": sim.reason,
		"year": sim.year(),
		"health": sim.sea_health(),
		"temp": sim.temperature,
		"avg_crisis": sim.avg_crisis(),
		"budget": sim.budget,
		"political": sim.political,
		"science": sim.science,
		"nodes": sim.adopted_nodes().size(),
		"projects_run": projects_run,
		"mutations_cured": mutations_cured,
		"actions": sim.actions_used,
		"bubbles": sim.bubbles_collected_total
	}


func _answer_card(sim: CrisisSim) -> void:
	var def: Dictionary = Events.event_def(str(sim.pending_event.get("id", "")))
	var choices: Array = def.get("choices", [])
	var best_idx := -1
	var best_tone := -100

	for i in range(choices.size()):
		if sim.can_choose(i):
			var tone: int = int(choices[i].get("tone", 0))
			if tone > best_tone:
				best_tone = tone
				best_idx = i

	if best_idx >= 0:
		sim.resolve_event(best_idx)
	else:
		sim.resolve_event(choices.size() - 1)


func _adopt_policy(sim: CrisisSim, primary_branch: String, res_budget: float, res_political: float) -> void:
	var best_id := ""
	var best_score := -1.0e9

	for n in TechTree.all_nodes():
		var node_id: String = str(n.get("id", ""))
		if not sim.can_adopt(node_id):
			continue
		var cost: Dictionary = sim.node_cost(node_id)
		var cb: float = float(cost.get("budget", 0.0))
		var cp: float = float(cost.get("political", 0.0))
		if cb > 0.0 and (sim.budget - cb < res_budget):
			continue
		if cp > 0.0 and (sim.political - cp < res_political):
			continue

		var branch: String = str(n.get("branch", ""))
		var tier: int = int(n.get("tier", 1))
		var score := 0.0

		if primary_branch != "" and branch == primary_branch:
			score += 50.0
		elif primary_branch == "":
			# Balanced: diversify across branches
			var branch_count := 0
			for anid in sim.adopted_nodes():
				var adef: Dictionary = TechTree.node_def(str(anid))
				if str(adef.get("branch", "")) == branch:
					branch_count += 1
			score -= float(branch_count) * 12.0

		score -= float(tier) * 3.0
		score -= (cb + cp + float(cost.get("science", 0.0))) * 0.05

		if score > best_score:
			best_score = score
			best_id = node_id

	if best_id != "":
		sim.adopt(best_id)


func _perform_field_op(sim: CrisisSim, op_rotation: Array) -> void:
	for action_id in op_rotation:
		if not sim.can_afford(action_id):
			continue
		var target := _pick_target(sim, action_id)
		if target != "" and bool(sim.perform(action_id, target).get("ok", false)):
			return


func _pick_target(sim: CrisisSim, action_id: String) -> String:
	match action_id:
		"cleanup":
			var worst_id := ""
			var worst_poll := -1.0
			for rid in RegionData.IDS:
				var r: RegionData = sim.regions[rid]
				if r.pollution > worst_poll and sim.can_perform(action_id, rid):
					worst_poll = r.pollution
					worst_id = rid
			return worst_id
		"patrol":
			var best_id := ""
			var worst_prot := 1000.0
			for rid in RegionData.IDS:
				var r: RegionData = sim.regions[rid]
				if r.protection < worst_prot and sim.can_perform(action_id, rid):
					worst_prot = r.protection
					best_id = rid
			return best_id
		"campaign":
			var best_id := ""
			var worst_aware := 1000.0
			for rid in RegionData.IDS:
				var r: RegionData = sim.regions[rid]
				if r.awareness < worst_aware and sim.can_perform(action_id, rid):
					worst_aware = r.awareness
					best_id = rid
			return best_id
	return ""


func _avg(arr: Array) -> float:
	if arr.is_empty():
		return 0.0
	var sum := 0.0
	for v in arr:
		sum += float(v)
	return sum / float(arr.size())
