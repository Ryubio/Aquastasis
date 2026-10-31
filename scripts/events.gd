extends RefCounted
## Events: the 10-12 two-choice decision cards (oil spill, heatwave, COP31 summits, ...) as
## DATA. crisis_sim.gd schedules them and applies choice effects; ui_event_card.gd shows
## them. Schema and effect vocabulary: docs/ARCHITECTURE.md section 11.

## One Dictionary per event:
## {"id", "weight", "min_tick", "max_tick", "at_tick" (-1 = random), "once", "region_rule"
##  ("random" | "worst" | "best" | "hero" | "none" | <region id>), "icon", "title_key",
##  "text_key", "choices": [{"label_key", "result_key", "cost" {...}, "effects" [...],
##  "tone" (-1 | 0 | 1)}, {...}]}
## Choice "a" is the paid response, choice "b" always costs nothing (it has a downside
## instead). Texts may use {region} (the card's region name) unless region_rule is "none".
## A "ticks" field on a mul / add effect makes it temporary (12 ticks = 1 game year).
## The three COP31 summits are scheduled (at_tick 60 / 120 / 180 = 2031 / 2036 / 2041).
const EVENTS := [
	# --- Random cards -------------------------------------------------------------------
	{
		"id": "oil_spill", "weight": 10, "min_tick": 15, "max_tick": 230, "at_tick": -1, "once": true,
		"region_rule": "random", "icon": "oil_spill",
		"title_key": "event.oil_spill.title", "text_key": "event.oil_spill.text",
		"choices": [
			{
				"label_key": "event.oil_spill.a.label", "result_key": "event.oil_spill.a.result",
				"cost": {"budget": 50.0, "political": 0.0, "science": 0.0},
				"effects": [
					{"op": "region", "stat": "pollution", "value": 4.0, "target": "event"},
					{"op": "region", "stat": "awareness", "value": 5.0, "target": "event"},
				],
				"tone": 1,
			},
			{
				"label_key": "event.oil_spill.b.label", "result_key": "event.oil_spill.b.result",
				"cost": {"budget": 0.0, "political": 0.0, "science": 0.0},
				"effects": [
					{"op": "region", "stat": "pollution", "value": 14.0, "target": "event"},
					{"op": "region", "stat": "fish_stock", "value": -8.0, "target": "event"},
				],
				"tone": -1,
			},
		],
	},
	{
		"id": "heatwave", "weight": 8, "min_tick": 40, "max_tick": 230, "at_tick": -1, "once": true,
		"region_rule": "random", "icon": "heat_alert",
		"title_key": "event.heatwave.title", "text_key": "event.heatwave.text",
		"choices": [
			{
				"label_key": "event.heatwave.a.label", "result_key": "event.heatwave.a.result",
				"cost": {"budget": 0.0, "political": 0.0, "science": 20.0},
				"effects": [
					{"op": "region", "stat": "coral_health", "value": -3.0, "target": "event"},
					{"op": "mul", "key": "coral_heat_mult", "value": 0.5, "ticks": 24},
				],
				"tone": 1,
			},
			{
				"label_key": "event.heatwave.b.label", "result_key": "event.heatwave.b.result",
				"cost": {"budget": 0.0, "political": 0.0, "science": 0.0},
				"effects": [
					{"op": "region", "stat": "coral_health", "value": -12.0, "target": "event"},
					{"op": "region", "stat": "seagrass", "value": -6.0, "target": "event"},
				],
				"tone": -1,
			},
		],
	},
	{
		"id": "lobby_pressure", "weight": 8, "min_tick": 35, "max_tick": 220, "at_tick": -1, "once": true,
		"region_rule": "none", "icon": "lobby_deal",
		"title_key": "event.lobby_pressure.title", "text_key": "event.lobby_pressure.text",
		"choices": [
			{
				"label_key": "event.lobby_pressure.a.label", "result_key": "event.lobby_pressure.a.result",
				"cost": {"budget": 0.0, "political": 20.0, "science": 0.0},
				"effects": [
					{"op": "region", "stat": "awareness", "value": 5.0, "target": "all"},
				],
				"tone": 1,
			},
			{
				"label_key": "event.lobby_pressure.b.label", "result_key": "event.lobby_pressure.b.result",
				"cost": {"budget": 0.0, "political": 0.0, "science": 0.0},
				"effects": [
					{"op": "resource", "key": "budget", "value": 60.0},
					{"op": "mul", "key": "inflow_mult", "value": 1.2, "ticks": 48},
				],
				"tone": -1,
			},
		],
	},
	{
		"id": "greenwashing", "weight": 6, "min_tick": 50, "max_tick": 230, "at_tick": -1, "once": true,
		"region_rule": "none", "icon": "greenwash",
		"title_key": "event.greenwashing.title", "text_key": "event.greenwashing.text",
		"choices": [
			{
				"label_key": "event.greenwashing.a.label", "result_key": "event.greenwashing.a.result",
				"cost": {"budget": 40.0, "political": 0.0, "science": 0.0},
				"effects": [
					{"op": "resource", "key": "political", "value": 15.0},
					{"op": "region", "stat": "awareness", "value": 4.0, "target": "all"},
				],
				"tone": 1,
			},
			{
				"label_key": "event.greenwashing.b.label", "result_key": "event.greenwashing.b.result",
				"cost": {"budget": 0.0, "political": 0.0, "science": 0.0},
				"effects": [
					{"op": "resource", "key": "political", "value": -15.0},
					{"op": "mul", "key": "awareness_decay_mult", "value": 1.5, "ticks": 36},
				],
				"tone": -1,
			},
		],
	},
	{
		"id": "fishers_coop", "weight": 8, "min_tick": 15, "max_tick": 210, "at_tick": -1, "once": true,
		"region_rule": "random", "icon": "fishers_coop",
		"title_key": "event.fishers_coop.title", "text_key": "event.fishers_coop.text",
		"choices": [
			{
				"label_key": "event.fishers_coop.a.label", "result_key": "event.fishers_coop.a.result",
				"cost": {"budget": 40.0, "political": 0.0, "science": 0.0},
				"effects": [
					{"op": "region", "stat": "fish_stock", "value": 8.0, "target": "event"},
					{"op": "mul", "key": "fishing_mult", "value": 0.9, "ticks": 48},
				],
				"tone": 1,
			},
			{
				"label_key": "event.fishers_coop.b.label", "result_key": "event.fishers_coop.b.result",
				"cost": {"budget": 0.0, "political": 0.0, "science": 0.0},
				"effects": [
					{"op": "region", "stat": "fish_stock", "value": -5.0, "target": "event"},
				],
				"tone": 0,
			},
		],
	},
	{
		"id": "tourism_surge", "weight": 8, "min_tick": 20, "max_tick": 230, "at_tick": -1, "once": true,
		"region_rule": "aegean", "icon": "tourism_surge",
		"title_key": "event.tourism_surge.title", "text_key": "event.tourism_surge.text",
		"choices": [
			{
				"label_key": "event.tourism_surge.a.label", "result_key": "event.tourism_surge.a.result",
				"cost": {"budget": 0.0, "political": 10.0, "science": 0.0},
				"effects": [
					{"op": "region", "stat": "seagrass", "value": 4.0, "target": "event"},
					{"op": "region", "stat": "pollution", "value": -4.0, "target": "event"},
					{"op": "region", "stat": "awareness", "value": 4.0, "target": "event"},
				],
				"tone": 1,
			},
			{
				"label_key": "event.tourism_surge.b.label", "result_key": "event.tourism_surge.b.result",
				"cost": {"budget": 0.0, "political": 0.0, "science": 0.0},
				"effects": [
					{"op": "resource", "key": "budget", "value": 70.0},
					{"op": "region", "stat": "seagrass", "value": -10.0, "target": "event"},
					{"op": "region", "stat": "pollution", "value": 8.0, "target": "event"},
				],
				"tone": -1,
			},
		],
	},
	{
		"id": "mucilage", "weight": 9, "min_tick": 15, "max_tick": 200, "at_tick": -1, "once": true,
		"region_rule": "marmara", "icon": "mucilage",
		"title_key": "event.mucilage.title", "text_key": "event.mucilage.text",
		"choices": [
			{
				"label_key": "event.mucilage.a.label", "result_key": "event.mucilage.a.result",
				"cost": {"budget": 50.0, "political": 0.0, "science": 0.0},
				"effects": [
					{"op": "region", "stat": "pollution", "value": -14.0, "target": "event"},
				],
				"tone": 1,
			},
			{
				"label_key": "event.mucilage.b.label", "result_key": "event.mucilage.b.result",
				"cost": {"budget": 0.0, "political": 0.0, "science": 0.0},
				"effects": [
					{"op": "resource", "key": "science", "value": 15.0},
					{"op": "region", "stat": "pollution", "value": 6.0, "target": "event"},
					{"op": "region", "stat": "fish_stock", "value": -6.0, "target": "event"},
				],
				"tone": -1,
			},
		],
	},
	{
		"id": "foreign_trawlers", "weight": 8, "min_tick": 30, "max_tick": 230, "at_tick": -1, "once": true,
		"region_rule": "best", "icon": "trawler",
		"title_key": "event.foreign_trawlers.title", "text_key": "event.foreign_trawlers.text",
		"choices": [
			{
				"label_key": "event.foreign_trawlers.a.label", "result_key": "event.foreign_trawlers.a.result",
				"cost": {"budget": 0.0, "political": 20.0, "science": 0.0},
				"effects": [
					{"op": "region", "stat": "protection", "value": 10.0, "target": "event"},
				],
				"tone": 1,
			},
			{
				"label_key": "event.foreign_trawlers.b.label", "result_key": "event.foreign_trawlers.b.result",
				"cost": {"budget": 0.0, "political": 0.0, "science": 0.0},
				"effects": [
					{"op": "region", "stat": "fish_stock", "value": -15.0, "target": "event"},
					{"op": "region", "stat": "seagrass", "value": -5.0, "target": "event"},
				],
				"tone": -1,
			},
		],
	},
	{
		"id": "caretta_nesting", "weight": 8, "min_tick": 15, "max_tick": 220, "at_tick": -1, "once": true,
		"region_rule": "hero", "icon": "caretta",
		"title_key": "event.caretta_nesting.title", "text_key": "event.caretta_nesting.text",
		"choices": [
			{
				"label_key": "event.caretta_nesting.a.label", "result_key": "event.caretta_nesting.a.result",
				"cost": {"budget": 25.0, "political": 0.0, "science": 0.0},
				"effects": [
					{"op": "region", "stat": "awareness", "value": 8.0, "target": "event"},
					{"op": "region", "stat": "protection", "value": 6.0, "target": "event"},
				],
				"tone": 1,
			},
			{
				"label_key": "event.caretta_nesting.b.label", "result_key": "event.caretta_nesting.b.result",
				"cost": {"budget": 0.0, "political": 0.0, "science": 0.0},
				"effects": [
					{"op": "resource", "key": "budget", "value": 30.0},
					{"op": "region", "stat": "awareness", "value": -5.0, "target": "event"},
				],
				"tone": -1,
			},
		],
	},

	# --- Scheduled COP31 summits (2031 / 2036 / 2041) ---------------------------------------
	{
		"id": "cop31_2031", "weight": 0, "min_tick": 60, "max_tick": 60, "at_tick": 60, "once": true,
		"region_rule": "none", "icon": "cop_summit",
		"title_key": "event.cop31_2031.title", "text_key": "event.cop31_2031.text",
		"choices": [
			{
				"label_key": "event.cop31_2031.a.label", "result_key": "event.cop31_2031.a.result",
				"cost": {"budget": 0.0, "political": 25.0, "science": 0.0},
				"effects": [
					{"op": "mul", "key": "inflow_mult", "value": 0.8, "ticks": 60},
				],
				"tone": 1,
			},
			{
				"label_key": "event.cop31_2031.b.label", "result_key": "event.cop31_2031.b.result",
				"cost": {"budget": 0.0, "political": 0.0, "science": 0.0},
				"effects": [
					{"op": "resource", "key": "budget", "value": 100.0},
				],
				"tone": 0,
			},
		],
	},
	{
		"id": "cop31_2036", "weight": 0, "min_tick": 120, "max_tick": 120, "at_tick": 120, "once": true,
		"region_rule": "none", "icon": "cop_summit",
		"title_key": "event.cop31_2036.title", "text_key": "event.cop31_2036.text",
		"choices": [
			{
				"label_key": "event.cop31_2036.a.label", "result_key": "event.cop31_2036.a.result",
				"cost": {"budget": 0.0, "political": 30.0, "science": 0.0},
				"effects": [
					{"op": "region", "stat": "protection", "value": 10.0, "target": "all"},
				],
				"tone": 1,
			},
			{
				"label_key": "event.cop31_2036.b.label", "result_key": "event.cop31_2036.b.result",
				"cost": {"budget": 0.0, "political": 0.0, "science": 0.0},
				"effects": [
					{"op": "resource", "key": "budget", "value": 80.0},
					{"op": "resource", "key": "political", "value": 10.0},
				],
				"tone": 0,
			},
		],
	},
	{
		"id": "cop31_2041", "weight": 0, "min_tick": 180, "max_tick": 180, "at_tick": 180, "once": true,
		"region_rule": "none", "icon": "cop_summit",
		"title_key": "event.cop31_2041.title", "text_key": "event.cop31_2041.text",
		"choices": [
			{
				"label_key": "event.cop31_2041.a.label", "result_key": "event.cop31_2041.a.result",
				"cost": {"budget": 80.0, "political": 20.0, "science": 0.0},
				"effects": [
					{"op": "temperature", "value": -0.05},
					{"op": "mul", "key": "temp_rise_mult", "value": 0.6, "ticks": 60},
				],
				"tone": 1,
			},
			{
				"label_key": "event.cop31_2041.b.label", "result_key": "event.cop31_2041.b.result",
				"cost": {"budget": 0.0, "political": 0.0, "science": 0.0},
				"effects": [
					{"op": "mul", "key": "budget_income_mult", "value": 1.2, "ticks": 60},
					{"op": "mul", "key": "temp_rise_mult", "value": 1.1, "ticks": 60},
				],
				"tone": -1,
			},
		],
	},
]


static func all_events() -> Array:
	return EVENTS


static func event_def(event_id: String) -> Dictionary:
	for e in EVENTS:
		var def: Dictionary = e
		if str(def.get("id", "")) == event_id:
			return def
	return {}
