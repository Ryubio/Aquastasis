extends RefCounted
## TechTree: the COP31 policy tree as DATA (4 branches, 24-28 nodes) plus the crisis
## evolutions (resistances) it counters. Pure data and lookups; crisis_sim.gd applies the
## effects, ui_tree.gd draws it. Effect vocabulary: docs/ARCHITECTURE.md section 11.

const BRANCHES := ["protect", "source", "science", "economy"]

## color: "healthy" | "amber" | "science" | "terracotta" (UI maps these to palette colors)
const BRANCH_INFO := {
	"protect": {"name_key": "tree.branch.protect.name", "desc_key": "tree.branch.protect.desc", "icon": "branch_protect", "color": "healthy"},
	"source": {"name_key": "tree.branch.source.name", "desc_key": "tree.branch.source.desc", "icon": "branch_source", "color": "amber"},
	"science": {"name_key": "tree.branch.science.name", "desc_key": "tree.branch.science.desc", "icon": "branch_science", "color": "science"},
	"economy": {"name_key": "tree.branch.economy.name", "desc_key": "tree.branch.economy.desc", "icon": "branch_economy", "color": "terracotta"},
}

## One Dictionary per node (schema in ARCHITECTURE section 11):
## {"id", "branch", "tier" (1-4), "slot" (0-1, column inside the branch), "cost" {budget,
##  political, science}, "requires" [node ids], "ramp_ticks", "effects" [...], "counters"
##  [evolution ids], "icon", "name_key", "desc_key", "fact_key"}
## Layout per branch: one tier-1 root, two tier-2 and two tier-3 specialisations, one
## tier-4 capstone that needs both tier-3 nodes. Cross-branch links only join neighbouring
## columns (protect <- source, source <- science, economy <- science).
## mul / add effects are persistent and ramp in over ramp_ticks; region / resource effects
## are one-shot, applied once at adoption. Tick = 0.6 s; 50 ticks = 1 game year, so an
## "add" of 0.2 per tick reads as "+10 per year" in the descriptions.
const NODES := [
	# --- PROTECTION (political support + science for bio-tech) -------------------------
	{
		"id": "protect_mpa", "branch": "protect", "tier": 1, "slot": 0,
		"cost": {"budget": 0.0, "political": 25.0, "science": 0.0},
		"requires": [], "ramp_ticks": 6,
		"effects": [
			{"op": "mul", "key": "protect_effect_mult", "value": 1.25},
			{"op": "mul", "key": "protect_decay_mult", "value": 0.75},
		],
		"counters": ["lobby_backlash"], "icon": "mpa",
		"name_key": "tree.protect_mpa.name", "desc_key": "tree.protect_mpa.desc", "fact_key": "tree.protect_mpa.fact",
	},
	{
		"id": "protect_posidonia", "branch": "protect", "tier": 2, "slot": 0,
		"cost": {"budget": 0.0, "political": 40.0, "science": 15.0},
		"requires": ["protect_mpa"], "ramp_ticks": 8,
		"effects": [
			{"op": "region", "stat": "seagrass", "value": 8.0, "target": "all"},
			{"op": "mul", "key": "seagrass_recovery_mult", "value": 1.35},
			{"op": "mul", "key": "fish_regen_mult", "value": 1.2},
		],
		"counters": ["invasive_species"], "icon": "posidonia",
		"name_key": "tree.protect_posidonia.name", "desc_key": "tree.protect_posidonia.desc", "fact_key": "tree.protect_posidonia.fact",
	},
	{
		"id": "protect_coral", "branch": "protect", "tier": 2, "slot": 1,
		"cost": {"budget": 20.0, "political": 25.0, "science": 25.0},
		"requires": ["protect_mpa"], "ramp_ticks": 8,
		"effects": [
			{"op": "mul", "key": "coral_recovery_mult", "value": 1.45},
			{"op": "mul", "key": "coral_heat_mult", "value": 0.70},
		],
		"counters": ["marine_heatwave"], "icon": "coral_nursery",
		"name_key": "tree.protect_coral.name", "desc_key": "tree.protect_coral.desc", "fact_key": "tree.protect_coral.fact",
	},
	{
		"id": "protect_blue_carbon", "branch": "protect", "tier": 3, "slot": 0,
		"cost": {"budget": 45.0, "political": 35.0, "science": 30.0},
		"requires": ["protect_posidonia"], "ramp_ticks": 12,
		"effects": [
			{"op": "add", "key": "blue_carbon", "value": 0.8},
			{"op": "mul", "key": "temp_rise_mult", "value": 0.90},
		],
		"counters": ["marine_heatwave"], "icon": "blue_carbon",
		"name_key": "tree.protect_blue_carbon.name", "desc_key": "tree.protect_blue_carbon.desc", "fact_key": "tree.protect_blue_carbon.fact",
	},
	{
		"id": "protect_sanctuary", "branch": "protect", "tier": 3, "slot": 1,
		"cost": {"budget": 35.0, "political": 45.0, "science": 20.0},
		"requires": ["protect_coral", "source_plastic_ban"], "ramp_ticks": 10,
		"effects": [
			{"op": "mul", "key": "political_income_mult", "value": 1.25},
			{"op": "mul", "key": "awareness_decay_mult", "value": 0.75},
		],
		"counters": ["disinformation"], "icon": "seal_turtle",
		"name_key": "tree.protect_sanctuary.name", "desc_key": "tree.protect_sanctuary.desc", "fact_key": "tree.protect_sanctuary.fact",
	},
	{
		"id": "protect_network", "branch": "protect", "tier": 4, "slot": 1,
		"cost": {"budget": 95.0, "political": 60.0, "science": 45.0},
		"requires": ["protect_blue_carbon", "protect_sanctuary"], "ramp_ticks": 16,
		"effects": [
			{"op": "add", "key": "protection_floor", "value": 25.0},
			{"op": "mul", "key": "spread_damage_mult", "value": 0.65},
		],
		"counters": ["invasive_species"], "icon": "mpa_network",
		"name_key": "tree.protect_network.name", "desc_key": "tree.protect_network.desc", "fact_key": "tree.protect_network.fact",
	},

	# --- SOURCE CUTTING (budget + science for smart sorting/inspection) ---------------------
	{
		"id": "source_plastic_ban", "branch": "source", "tier": 1, "slot": 0,
		"cost": {"budget": 50.0, "political": 10.0, "science": 0.0},
		"requires": [], "ramp_ticks": 6,
		"effects": [
			{"op": "mul", "key": "inflow_mult", "value": 0.85},
			{"op": "region", "stat": "awareness", "value": 6.0, "target": "all"},
		],
		"counters": ["disinformation"], "icon": "plastic_ban",
		"name_key": "tree.source_plastic_ban.name", "desc_key": "tree.source_plastic_ban.desc", "fact_key": "tree.source_plastic_ban.fact",
	},
	{
		"id": "source_river_filters", "branch": "source", "tier": 2, "slot": 0,
		"cost": {"budget": 80.0, "political": 0.0, "science": 15.0},
		"requires": ["source_plastic_ban"], "ramp_ticks": 8,
		"effects": [
			{"op": "mul", "key": "inflow_mult", "value": 0.75},
			{"op": "mul", "key": "cleanup_power_mult", "value": 1.30},
		],
		"counters": ["disinformation"], "icon": "river_filter",
		"name_key": "tree.source_river_filters.name", "desc_key": "tree.source_river_filters.desc", "fact_key": "tree.source_river_filters.fact",
	},
	{
		"id": "source_ship_inspection", "branch": "source", "tier": 2, "slot": 1,
		"cost": {"budget": 65.0, "political": 0.0, "science": 25.0},
		"requires": ["source_plastic_ban"], "ramp_ticks": 8,
		"effects": [
			{"op": "mul", "key": "neighbor_pressure_mult", "value": 0.70},
			{"op": "mul", "key": "spread_chance_mult", "value": 0.75},
		],
		"counters": ["invasive_species"], "icon": "ship_inspection",
		"name_key": "tree.source_ship_inspection.name", "desc_key": "tree.source_ship_inspection.desc", "fact_key": "tree.source_ship_inspection.fact",
	},
	{
		"id": "source_wastewater", "branch": "source", "tier": 3, "slot": 0,
		"cost": {"budget": 100.0, "political": 0.0, "science": 35.0},
		"requires": ["source_river_filters"], "ramp_ticks": 12,
		"effects": [
			{"op": "mul", "key": "base_pollution_mult", "value": 0.70},
			{"op": "mul", "key": "seagrass_recovery_mult", "value": 1.30},
		],
		"counters": ["marine_heatwave"], "icon": "wastewater",
		"name_key": "tree.source_wastewater.name", "desc_key": "tree.source_wastewater.desc", "fact_key": "tree.source_wastewater.fact",
	},
	{
		"id": "source_ghost_nets", "branch": "source", "tier": 3, "slot": 1,
		"cost": {"budget": 85.0, "political": 15.0, "science": 20.0},
		"requires": ["source_ship_inspection", "science_citizen"], "ramp_ticks": 10,
		"effects": [
			{"op": "region", "stat": "fish_stock", "value": 6.0, "target": "all"},
			{"op": "mul", "key": "fish_regen_mult", "value": 1.25},
		],
		"counters": ["illegal_fishing"], "icon": "ghost_net",
		"name_key": "tree.source_ghost_nets.name", "desc_key": "tree.source_ghost_nets.desc", "fact_key": "tree.source_ghost_nets.fact",
	},
	{
		"id": "source_zero_waste_ports", "branch": "source", "tier": 4, "slot": 1,
		"cost": {"budget": 150.0, "political": 20.0, "science": 50.0},
		"requires": ["source_wastewater", "source_ghost_nets"], "ramp_ticks": 16,
		"effects": [
			{"op": "mul", "key": "inflow_mult", "value": 0.75},
			{"op": "mul", "key": "action_cost_mult", "value": 0.75},
		],
		"counters": ["lobby_backlash"], "icon": "zero_waste_port",
		"name_key": "tree.source_zero_waste_ports.name", "desc_key": "tree.source_zero_waste_ports.desc", "fact_key": "tree.source_zero_waste_ports.fact",
	},

	# --- SCIENCE & PUBLIC (pure science points) ---------------------------------------------------
	{
		"id": "science_satellite", "branch": "science", "tier": 1, "slot": 0,
		"cost": {"budget": 0.0, "political": 0.0, "science": 20.0},
		"requires": [], "ramp_ticks": 6,
		"effects": [
			{"op": "mul", "key": "cleanup_power_mult", "value": 1.25},
			{"op": "mul", "key": "bubble_rate_mult", "value": 1.35},
		],
		"counters": ["illegal_fishing"], "icon": "satellite",
		"name_key": "tree.science_satellite.name", "desc_key": "tree.science_satellite.desc", "fact_key": "tree.science_satellite.fact",
	},
	{
		"id": "science_citizen", "branch": "science", "tier": 2, "slot": 0,
		"cost": {"budget": 0.0, "political": 0.0, "science": 30.0},
		"requires": ["science_satellite"], "ramp_ticks": 8,
		"effects": [
			{"op": "mul", "key": "campaign_power_mult", "value": 1.25},
			{"op": "mul", "key": "bubble_value_mult", "value": 1.35},
		],
		"counters": ["source_surge"], "icon": "citizen_science",
		"name_key": "tree.science_citizen.name", "desc_key": "tree.science_citizen.desc", "fact_key": "tree.science_citizen.fact",
	},
	{
		"id": "science_mucilage", "branch": "science", "tier": 2, "slot": 1,
		"cost": {"budget": 0.0, "political": 0.0, "science": 30.0},
		"requires": ["science_satellite"], "ramp_ticks": 6,
		"effects": [
			{"op": "region", "stat": "pollution", "value": -15.0, "target": "marmara"},
			{"op": "mul", "key": "heat_stress_mult", "value": 0.75},
		],
		"counters": ["source_surge"], "icon": "mucilage_alert",
		"name_key": "tree.science_mucilage.name", "desc_key": "tree.science_mucilage.desc", "fact_key": "tree.science_mucilage.fact",
	},
	{
		"id": "science_curriculum", "branch": "science", "tier": 3, "slot": 0,
		"cost": {"budget": 0.0, "political": 0.0, "science": 50.0},
		"requires": ["science_citizen"], "ramp_ticks": 12,
		"effects": [
			{"op": "add", "key": "awareness_floor", "value": 15.0},
			{"op": "mul", "key": "awareness_decay_mult", "value": 0.70},
		],
		"counters": ["source_surge"], "icon": "school",
		"name_key": "tree.science_curriculum.name", "desc_key": "tree.science_curriculum.desc", "fact_key": "tree.science_curriculum.fact",
	},
	{
		"id": "science_data_hub", "branch": "science", "tier": 3, "slot": 1,
		"cost": {"budget": 0.0, "political": 0.0, "science": 55.0},
		"requires": ["science_mucilage"], "ramp_ticks": 10,
		"effects": [
			{"op": "add", "key": "science_per_tick", "value": 0.5},
			{"op": "mul", "key": "node_cost_mult", "value": 0.85},
		],
		"counters": ["lobby_backlash"], "icon": "data_hub",
		"name_key": "tree.science_data_hub.name", "desc_key": "tree.science_data_hub.desc", "fact_key": "tree.science_data_hub.fact",
	},
	{
		"id": "science_disinfo", "branch": "science", "tier": 4, "slot": 1,
		"cost": {"budget": 0.0, "political": 0.0, "science": 85.0},
		"requires": ["science_curriculum", "science_data_hub"], "ramp_ticks": 14,
		"effects": [
			{"op": "mul", "key": "aware_effect_mult", "value": 1.35},
			{"op": "mul", "key": "campaign_power_mult", "value": 1.35},
		],
		"counters": ["disinformation"], "icon": "fact_check",
		"name_key": "tree.science_disinfo.name", "desc_key": "tree.science_disinfo.desc", "fact_key": "tree.science_disinfo.fact",
	},

	# --- ECONOMY & DIPLOMACY (budget + political + science for green algorithms) ------------
	{
		"id": "economy_quotas", "branch": "economy", "tier": 1, "slot": 0,
		"cost": {"budget": 35.0, "political": 15.0, "science": 0.0},
		"requires": [], "ramp_ticks": 6,
		"effects": [
			{"op": "mul", "key": "fishing_mult", "value": 0.80},
		],
		"counters": ["illegal_fishing"], "icon": "fishing_quota",
		"name_key": "tree.economy_quotas.name", "desc_key": "tree.economy_quotas.desc", "fact_key": "tree.economy_quotas.fact",
	},
	{
		"id": "economy_tourism", "branch": "economy", "tier": 2, "slot": 0,
		"cost": {"budget": 45.0, "political": 15.0, "science": 15.0},
		"requires": ["economy_quotas"], "ramp_ticks": 8,
		"effects": [
			{"op": "mul", "key": "budget_income_mult", "value": 1.25},
			{"op": "mul", "key": "inflow_mult", "value": 0.90},
		],
		"counters": ["source_surge"], "icon": "green_tourism",
		"name_key": "tree.economy_tourism.name", "desc_key": "tree.economy_tourism.desc", "fact_key": "tree.economy_tourism.fact",
	},
	{
		"id": "economy_fishers", "branch": "economy", "tier": 2, "slot": 1,
		"cost": {"budget": 50.0, "political": 20.0, "science": 10.0},
		"requires": ["economy_quotas"], "ramp_ticks": 8,
		"effects": [
			{"op": "mul", "key": "fishing_mult", "value": 0.85},
			{"op": "add", "key": "political_per_tick", "value": 0.5},
		],
		"counters": ["illegal_fishing"], "icon": "fishers_fund",
		"name_key": "tree.economy_fishers.name", "desc_key": "tree.economy_fishers.desc", "fact_key": "tree.economy_fishers.fact",
	},
	{
		"id": "economy_treaty", "branch": "economy", "tier": 3, "slot": 0,
		"cost": {"budget": 65.0, "political": 40.0, "science": 20.0},
		"requires": ["economy_tourism", "science_satellite"], "ramp_ticks": 12,
		"effects": [
			{"op": "mul", "key": "patrol_power_mult", "value": 1.30},
			{"op": "mul", "key": "political_income_mult", "value": 1.25},
		],
		"counters": ["invasive_species"], "icon": "treaty",
		"name_key": "tree.economy_treaty.name", "desc_key": "tree.economy_treaty.desc", "fact_key": "tree.economy_treaty.fact",
	},
	{
		"id": "economy_bonds", "branch": "economy", "tier": 3, "slot": 1,
		"cost": {"budget": 80.0, "political": 20.0, "science": 30.0},
		"requires": ["economy_fishers"], "ramp_ticks": 10,
		"effects": [
			{"op": "add", "key": "budget_per_tick", "value": 1.5},
			{"op": "mul", "key": "coral_recovery_mult", "value": 1.25},
		],
		"counters": ["lobby_backlash"], "icon": "blue_bond",
		"name_key": "tree.economy_bonds.name", "desc_key": "tree.economy_bonds.desc", "fact_key": "tree.economy_bonds.fact",
	},
	{
		"id": "economy_carbon", "branch": "economy", "tier": 4, "slot": 1,
		"cost": {"budget": 120.0, "political": 40.0, "science": 45.0},
		"requires": ["economy_treaty", "economy_bonds"], "ramp_ticks": 16,
		"effects": [
			{"op": "mul", "key": "temp_rise_mult", "value": 0.75},
			{"op": "add", "key": "budget_per_tick", "value": 1.0},
		],
		"counters": ["marine_heatwave"], "icon": "carbon_price",
		"name_key": "tree.economy_carbon.name", "desc_key": "tree.economy_carbon.desc", "fact_key": "tree.economy_carbon.fact",
	},
]

## {"id", "trigger" ("branch" | "heat" | "spread"), "branch" (for "branch", else ""),
##  "effects" [...], "icon", "name_key", "desc_key", "news_key", "cured_news_key"}
## Effects stay active until a counter node is adopted (TechTree.counters_of(id)).
const EVOLUTIONS := [
	{
		"id": "source_surge", "trigger": "branch", "branch": "source",
		"effects": [
			{"op": "mul", "key": "inflow_mult", "value": 1.4},
			{"op": "mul", "key": "cleanup_power_mult", "value": 0.8},
		],
		"icon": "upstream_surge",
		"name_key": "evo.source_surge.name", "desc_key": "evo.source_surge.desc",
		"news_key": "evo.source_surge.news", "cured_news_key": "evo.source_surge.cured",
	},
	{
		"id": "illegal_fishing", "trigger": "branch", "branch": "protect",
		"effects": [
			{"op": "mul", "key": "fishing_mult", "value": 1.5},
			{"op": "mul", "key": "patrol_power_mult", "value": 0.8},
		],
		"icon": "poacher",
		"name_key": "evo.illegal_fishing.name", "desc_key": "evo.illegal_fishing.desc",
		"news_key": "evo.illegal_fishing.news", "cured_news_key": "evo.illegal_fishing.cured",
	},
	{
		"id": "disinformation", "trigger": "branch", "branch": "science",
		"effects": [
			{"op": "mul", "key": "awareness_decay_mult", "value": 1.5},
			{"op": "mul", "key": "political_income_mult", "value": 0.8},
		],
		"icon": "fake_news",
		"name_key": "evo.disinformation.name", "desc_key": "evo.disinformation.desc",
		"news_key": "evo.disinformation.news", "cured_news_key": "evo.disinformation.cured",
	},
	{
		"id": "lobby_backlash", "trigger": "branch", "branch": "economy",
		"effects": [
			{"op": "mul", "key": "node_cost_mult", "value": 1.25},
			{"op": "mul", "key": "political_income_mult", "value": 0.8},
		],
		"icon": "lobby",
		"name_key": "evo.lobby_backlash.name", "desc_key": "evo.lobby_backlash.desc",
		"news_key": "evo.lobby_backlash.news", "cured_news_key": "evo.lobby_backlash.cured",
	},
	{
		"id": "marine_heatwave", "trigger": "heat", "branch": "",
		"effects": [
			{"op": "mul", "key": "coral_heat_mult", "value": 1.5},
			{"op": "mul", "key": "heat_stress_mult", "value": 1.3},
		],
		"icon": "heatwave",
		"name_key": "evo.marine_heatwave.name", "desc_key": "evo.marine_heatwave.desc",
		"news_key": "evo.marine_heatwave.news", "cured_news_key": "evo.marine_heatwave.cured",
	},
	{
		"id": "invasive_species", "trigger": "spread", "branch": "",
		"effects": [
			{"op": "mul", "key": "spread_chance_mult", "value": 1.3},
			{"op": "mul", "key": "fish_regen_mult", "value": 0.85},
		],
		"icon": "invasive",
		"name_key": "evo.invasive_species.name", "desc_key": "evo.invasive_species.desc",
		"news_key": "evo.invasive_species.news", "cured_news_key": "evo.invasive_species.cured",
	},
]


static func all_nodes() -> Array:
	return NODES


static func node_def(node_id: String) -> Dictionary:
	for n in NODES:
		var def: Dictionary = n
		if str(def.get("id", "")) == node_id:
			return def
	return {}


static func branch_nodes(branch: String) -> Array:
	var out: Array = []
	for n in NODES:
		var def: Dictionary = n
		if str(def.get("branch", "")) == branch:
			out.append(def)
	return out


static func all_evolutions() -> Array:
	return EVOLUTIONS


static func evolution_def(evolution_id: String) -> Dictionary:
	for e in EVOLUTIONS:
		var def: Dictionary = e
		if str(def.get("id", "")) == evolution_id:
			return def
	return {}


## Node ids whose adoption cures (or pre-empts) the given evolution.
static func counters_of(evolution_id: String) -> Array:
	var out: Array = []
	for n in NODES:
		var def: Dictionary = n
		var counters: Array = def.get("counters", [])
		if counters.has(evolution_id):
			out.append(str(def.get("id", "")))
	return out
