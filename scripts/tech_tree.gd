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

## One Dictionary per node (content module fills this; schema in ARCHITECTURE section 11):
## {"id", "branch", "tier" (1-4), "slot" (0-1, column inside the branch), "cost" {budget,
##  political, science}, "requires" [node ids], "ramp_ticks", "effects" [...], "counters"
##  [evolution ids], "icon", "name_key", "desc_key", "fact_key"}
const NODES := []

## {"id", "trigger" ("branch" | "heat" | "spread"), "branch" (for "branch"), "effects" [...],
##  "icon", "name_key", "desc_key", "news_key", "cured_news_key"}
const EVOLUTIONS := []


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
