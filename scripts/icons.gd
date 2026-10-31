extends Control
## Icons: every HUD / resource / action / policy / evolution / event icon, vector-drawn in
## _draw() with antialiased neon strokes (no image files). Set icon_id + color (or call
## setup()); the icon scales to the control's size and stays readable from 16 to 64 px.

const UITheme := preload("res://scripts/ui_theme.gd")

const IDS := [
	# HUD, resources, field operations, chrome (Phase 1)
	"budget", "political", "science", "temperature", "sea_health", "crisis", "awareness",
	"pollution", "coral", "seagrass", "fish", "protection", "pause", "play", "fast", "faster",
	"cleanup", "patrol", "campaign", "globe", "warning", "clock", "target", "info",
	"crosshair", "restart", "home", "power", "check", "population",
	# Phase 2 HUD / modal chrome
	"tree", "evolution", "event", "news", "bubble_science", "bubble_political", "close", "lock",
	# Policy tree branches
	"branch_protect", "branch_source", "branch_science", "branch_economy",
	# Policy nodes (tech_tree.gd NODES[].icon)
	"mpa", "posidonia", "coral_nursery", "blue_carbon", "seal_turtle", "mpa_network",
	"plastic_ban", "river_filter", "ship_inspection", "wastewater", "ghost_net", "zero_waste_port",
	"satellite", "citizen_science", "mucilage_alert", "school", "data_hub", "fact_check",
	"fishing_quota", "green_tourism", "fishers_fund", "treaty", "blue_bond", "carbon_price",
	# Crisis evolutions (tech_tree.gd EVOLUTIONS[].icon)
	"upstream_surge", "poacher", "fake_news", "lobby", "heatwave", "invasive",
	# Decision events (events.gd EVENTS[].icon)
	"oil_spill", "heat_alert", "lobby_deal", "greenwash", "fishers_coop", "tourism_surge",
	"mucilage", "trawler", "caretta", "cop_summit",
]

var icon_id: String = "": set = set_icon_id
var color: Color = UITheme.TEXT: set = set_color
var glow: bool = true

var _c: Vector2 = Vector2.ZERO
var _r: float = 8.0
var _w: float = 1.5


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Convenience: id, tint and square pixel size in one call.
func setup(id: String, tint: Color, px: float) -> void:
	icon_id = id
	color = tint
	custom_minimum_size = Vector2(px, px)
	queue_redraw()


func set_icon(id: String, tint: Color, px: float = 0.0) -> void:
	icon_id = id
	color = tint
	if px > 0.0:
		custom_minimum_size = Vector2(px, px)
	queue_redraw()


func set_icon_id(v: String) -> void:
	icon_id = v
	queue_redraw()


func set_color(v: Color) -> void:
	color = v
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	_c = size * 0.5
	_r = minf(size.x, size.y) * 0.5 * 0.88
	_w = maxf(1.3, _r * 0.14)
	if _r < 2.0 or icon_id == "":
		return
	match icon_id:
		"budget":
			_draw_budget()
		"political":
			_draw_political()
		"science":
			_draw_science()
		"temperature":
			_draw_temperature()
		"sea_health":
			_draw_sea_health()
		"crisis":
			_draw_crisis()
		"awareness":
			_draw_awareness()
		"pollution":
			_draw_pollution()
		"coral":
			_draw_coral()
		"seagrass":
			_draw_seagrass()
		"fish":
			_draw_fish()
		"protection":
			_draw_protection()
		"pause":
			_fill_rect(Rect2(-0.5, -0.62, 0.34, 1.24), 1.0)
			_fill_rect(Rect2(0.16, -0.62, 0.34, 1.24), 1.0)
		"play":
			_fill([Vector2(-0.42, -0.68), Vector2(0.66, 0.0), Vector2(-0.42, 0.68)], 1.0)
		"fast":
			_fill([Vector2(-0.8, -0.56), Vector2(0.0, 0.0), Vector2(-0.8, 0.56)], 1.0)
			_fill([Vector2(-0.02, -0.56), Vector2(0.78, 0.0), Vector2(-0.02, 0.56)], 1.0)
		"faster":
			for i in 3:
				var x: float = -0.92 + float(i) * 0.56
				_fill([Vector2(x, -0.5), Vector2(x + 0.56, 0.0), Vector2(x, 0.5)], 1.0)
		"cleanup":
			_draw_cleanup()
		"patrol":
			_draw_patrol()
		"campaign":
			_draw_campaign()
		"globe":
			_draw_globe()
		"warning":
			_draw_warning()
		"clock":
			_ring(Vector2.ZERO, 0.82)
			_stroke([Vector2(0.0, -0.5), Vector2(0.0, 0.0), Vector2(0.38, 0.22)])
			_dot(Vector2.ZERO, 0.1)
		"target":
			_ring(Vector2.ZERO, 0.84)
			_ring(Vector2.ZERO, 0.52)
			_dot(Vector2.ZERO, 0.2)
		"info":
			_ring(Vector2.ZERO, 0.84)
			_stroke([Vector2(0.0, -0.08), Vector2(0.0, 0.48)], false, 1.2)
			_dot(Vector2(0.0, -0.38), 0.11)
		"crosshair":
			_ring(Vector2.ZERO, 0.6)
			_stroke([Vector2(0.0, -0.95), Vector2(0.0, -0.4)])
			_stroke([Vector2(0.0, 0.4), Vector2(0.0, 0.95)])
			_stroke([Vector2(-0.95, 0.0), Vector2(-0.4, 0.0)])
			_stroke([Vector2(0.4, 0.0), Vector2(0.95, 0.0)])
			_dot(Vector2.ZERO, 0.12)
		"restart":
			_arc(Vector2.ZERO, 0.68, -PI * 0.35, PI * 1.35)
			_arrowhead(Vector2.ZERO, 0.68, PI * 1.35, 0.34)
		"home":
			_stroke([Vector2(-0.85, -0.02), Vector2(0.0, -0.8), Vector2(0.85, -0.02)])
			_stroke([Vector2(-0.6, -0.2), Vector2(-0.6, 0.8), Vector2(0.6, 0.8), Vector2(0.6, -0.2)])
			_fill_rect(Rect2(-0.16, 0.3, 0.32, 0.5), 0.9)
		"power":
			_arc(Vector2(0.0, 0.08), 0.72, -PI * 0.32, PI * 1.32)
			_stroke([Vector2(0.0, -0.9), Vector2(0.0, -0.05)], false, 1.15)
		"check":
			_stroke([Vector2(-0.7, 0.02), Vector2(-0.22, 0.5), Vector2(0.72, -0.5)], false, 1.3)
		"population":
			_ring(Vector2(-0.32, -0.38), 0.22)
			_ring(Vector2(0.36, -0.42), 0.26)
			_arc(Vector2(-0.32, 0.55), 0.42, PI, TAU)
			_arc(Vector2(0.36, 0.55), 0.5, PI, TAU)
		# --- Phase 2: chrome ---
		"tree":
			_draw_tree_glyph()
		"evolution":
			_draw_evolution()
		"event":
			_draw_event_glyph()
		"news":
			_draw_news()
		"bubble_science":
			_draw_bubble(true)
		"bubble_political":
			_draw_bubble(false)
		"close":
			_stroke([Vector2(-0.56, -0.56), Vector2(0.56, 0.56)], false, 1.2)
			_stroke([Vector2(0.56, -0.56), Vector2(-0.56, 0.56)], false, 1.2)
		"lock":
			_draw_lock()
		# --- Phase 2: branches ---
		"branch_protect":
			_draw_branch_protect()
		"branch_source":
			_draw_branch_source()
		"branch_science":
			_draw_branch_science()
		"branch_economy":
			_draw_branch_economy()
		# --- Phase 2: policy nodes ---
		"mpa":
			_draw_mpa()
		"posidonia":
			_draw_posidonia()
		"coral_nursery":
			_draw_coral_nursery()
		"blue_carbon":
			_draw_blue_carbon()
		"seal_turtle":
			_turtle_at(Vector2(0.0, 0.06), 1.0, 0.0, 0.22)
		"mpa_network":
			_draw_mpa_network()
		"plastic_ban":
			_draw_plastic_ban()
		"river_filter":
			_draw_river_filter()
		"ship_inspection":
			_draw_ship_inspection()
		"wastewater":
			_draw_wastewater()
		"ghost_net":
			_draw_ghost_net()
		"zero_waste_port":
			_draw_zero_waste_port()
		"satellite":
			_draw_satellite()
		"citizen_science":
			_draw_citizen_science()
		"mucilage_alert":
			_draw_mucilage_alert()
		"school":
			_draw_school()
		"data_hub":
			_draw_data_hub()
		"fact_check":
			_draw_fact_check()
		"fishing_quota":
			_draw_fishing_quota()
		"green_tourism":
			_draw_green_tourism()
		"fishers_fund":
			_draw_fishers_fund()
		"treaty":
			_draw_treaty()
		"blue_bond":
			_draw_blue_bond()
		"carbon_price":
			_draw_carbon_price()
		# --- Phase 2: crisis evolutions ---
		"upstream_surge":
			_draw_upstream_surge()
		"poacher":
			_draw_poacher()
		"fake_news":
			_draw_fake_news()
		"lobby":
			_draw_lobby()
		"heatwave":
			_draw_heatwave()
		"invasive":
			_draw_invasive()
		# --- Phase 2: decision events ---
		"oil_spill":
			_draw_oil_spill()
		"heat_alert":
			_draw_heat_alert()
		"lobby_deal":
			_draw_lobby_deal()
		"greenwash":
			_draw_greenwash()
		"fishers_coop":
			_draw_fishers_coop()
		"tourism_surge":
			_draw_tourism_surge()
		"mucilage":
			_draw_mucilage()
		"trawler":
			_draw_trawler()
		"caretta":
			_draw_caretta()
		"cop_summit":
			_draw_cop_summit()
		_:
			_draw_fallback()


# --- Icon bodies -------------------------------------------------------------------

func _draw_budget() -> void:
	# Stack of three coins, drawn bottom-up so upper coins occlude lower ones.
	var offsets: Array = [Vector2(-0.06, 0.6), Vector2(0.06, 0.26), Vector2(-0.02, -0.08)]
	for o in offsets:
		var off: Vector2 = o
		var body: Array = _rounded_rect(Rect2(off.x - 0.66, off.y - 0.17, 1.32, 0.34), 0.17)
		_fill(body, 0.0, UITheme.DEEP)
		_fill(body, 0.22)
		_stroke(body, true)
	var top: Array = _ellipse(Vector2(-0.02, -0.42), 0.66, 0.24, 0.0, 28)
	_fill(top, 0.0, UITheme.DEEP)
	_fill(top, 0.45)
	_stroke(top, true)
	_dot(Vector2(-0.02, -0.42), 0.09)


func _draw_political() -> void:
	_fill([Vector2(-0.88, -0.34), Vector2(0.0, -0.86), Vector2(0.88, -0.34)], 0.3)
	_stroke([Vector2(-0.88, -0.34), Vector2(0.0, -0.86), Vector2(0.88, -0.34), Vector2(-0.88, -0.34)])
	for i in 4:
		var x: float = -0.56 + float(i) * 0.373
		_stroke([Vector2(x, -0.18), Vector2(x, 0.5)])
	_stroke([Vector2(-0.78, 0.66), Vector2(0.78, 0.66)])
	_stroke([Vector2(-0.94, 0.86), Vector2(0.94, 0.86)])


func _draw_science() -> void:
	for i in 3:
		var rot: float = float(i) * PI / 3.0
		_stroke(_ellipse(Vector2.ZERO, 0.9, 0.32, rot, 40), true, 0.8)
	_dot(Vector2.ZERO, 0.17)


func _draw_temperature() -> void:
	var tube: Array = _rounded_rect(Rect2(-0.2, -0.9, 0.4, 1.2), 0.2)
	_fill(tube, 0.12)
	_stroke(tube, true, 0.9)
	_dot(Vector2(0.0, 0.52), 0.34)
	_fill_rect(Rect2(-0.08, -0.35, 0.16, 0.9), 1.0)
	for i in 3:
		var y: float = -0.62 + float(i) * 0.24
		_stroke([Vector2(0.34, y), Vector2(0.58, y)], false, 0.7)


func _draw_sea_health() -> void:
	var heart: Array = []
	for i in 40:
		var t: float = TAU * float(i) / 40.0
		var sx: float = pow(sin(t), 3.0)
		var hy: float = 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		heart.append(Vector2(sx * 0.9, -hy / 17.0 * 0.92 + 0.05))
	_fill(heart, 0.16)
	_stroke(heart, true)
	_stroke([
		Vector2(-0.62, 0.0), Vector2(-0.28, 0.0), Vector2(-0.14, -0.32), Vector2(0.02, 0.34),
		Vector2(0.16, -0.12), Vector2(0.26, 0.0), Vector2(0.62, 0.0)], false, 0.8)


func _draw_crisis() -> void:
	for i in 8:
		var a: float = TAU * float(i) / 8.0 + PI / 8.0
		var d := Vector2(cos(a), sin(a))
		_stroke([d * 0.44, d * 0.74], false, 0.85)
		_dot(d * 0.8, 0.11)
	_dot(Vector2.ZERO, 0.44, 0.25)
	_ring(Vector2.ZERO, 0.44)
	_dot(Vector2(-0.14, -0.1), 0.09)
	_dot(Vector2(0.15, 0.12), 0.07)


func _draw_awareness() -> void:
	var upper: Array = _quad(Vector2(-0.92, 0.0), Vector2(0.0, -0.82), Vector2(0.92, 0.0), 18)
	var lower: Array = _quad(Vector2(0.92, 0.0), Vector2(0.0, 0.82), Vector2(-0.92, 0.0), 18)
	var almond: Array = upper.duplicate()
	almond.append_array(lower.slice(1, lower.size() - 1))
	_fill(almond, 0.12)
	_stroke(almond, true)
	_ring(Vector2.ZERO, 0.3)
	_dot(Vector2.ZERO, 0.14)


func _draw_pollution() -> void:
	var drop: Array = [Vector2(0.0, -0.88)]
	var steps: int = 22
	for i in steps + 1:
		var a: float = lerpf(-PI * 0.2, PI * 1.2, float(i) / float(steps))
		drop.append(Vector2(cos(a), sin(a)) * 0.54 + Vector2(0.0, 0.3))
	_fill(drop, 0.35)
	_stroke(drop, true)
	_arc(Vector2(0.0, 0.3), 0.32, PI * 0.6, PI * 0.95, 0.7)
	_dot(Vector2(0.72, -0.5), 0.1)
	_dot(Vector2(-0.7, -0.3), 0.07)


func _draw_coral() -> void:
	_stroke([Vector2(0.0, 0.86), Vector2(0.0, 0.1), Vector2(-0.05, -0.72)])
	_stroke([Vector2(0.0, 0.38), Vector2(-0.44, -0.02), Vector2(-0.52, -0.58)])
	_stroke([Vector2(-0.44, -0.02), Vector2(-0.82, -0.26)])
	_stroke([Vector2(0.0, 0.14), Vector2(0.38, -0.3), Vector2(0.34, -0.78)])
	_stroke([Vector2(0.38, -0.3), Vector2(0.78, -0.5)])
	for tip in [Vector2(-0.05, -0.72), Vector2(-0.52, -0.58), Vector2(-0.82, -0.26), Vector2(0.34, -0.78), Vector2(0.78, -0.5)]:
		var p: Vector2 = tip
		_dot(p, 0.11)
	_stroke([Vector2(-0.6, 0.86), Vector2(0.6, 0.86)])


func _draw_seagrass() -> void:
	_stroke(_quad(Vector2(-0.3, 0.86), Vector2(-0.3, 0.0), Vector2(-0.72, -0.62), 12))
	_stroke(_quad(Vector2(0.02, 0.86), Vector2(0.14, -0.1), Vector2(-0.04, -0.92), 12))
	_stroke(_quad(Vector2(0.32, 0.86), Vector2(0.36, 0.1), Vector2(0.74, -0.46), 12))
	_stroke([Vector2(-0.7, 0.86), Vector2(0.7, 0.86)])
	_ring(Vector2(0.62, -0.84), 0.09, 0.6)
	_ring(Vector2(0.44, -0.62), 0.06, 0.6)


func _draw_fish() -> void:
	var upper: Array = _quad(Vector2(0.82, 0.0), Vector2(0.18, -0.78), Vector2(-0.46, 0.0), 16)
	var lower: Array = _quad(Vector2(-0.46, 0.0), Vector2(0.18, 0.78), Vector2(0.82, 0.0), 16)
	var body: Array = upper.duplicate()
	body.append_array(lower.slice(1, lower.size() - 1))
	_fill(body, 0.25)
	_stroke(body, true)
	var tail: Array = [Vector2(-0.4, 0.0), Vector2(-0.9, -0.44), Vector2(-0.84, 0.0), Vector2(-0.9, 0.44)]
	_fill([Vector2(-0.4, 0.0), Vector2(-0.9, -0.44), Vector2(-0.84, 0.0)], 0.6)
	_fill([Vector2(-0.4, 0.0), Vector2(-0.84, 0.0), Vector2(-0.9, 0.44)], 0.6)
	_stroke(tail, true, 0.8)
	_dot(Vector2(0.44, -0.1), 0.09)
	_arc(Vector2(0.08, 0.0), 0.3, -PI * 0.3, PI * 0.3, 0.6)


func _draw_protection() -> void:
	var shield: Array = _shield(1.0)
	_fill(shield, 0.2)
	_stroke(shield, true)
	_stroke([Vector2(-0.32, 0.0), Vector2(-0.08, 0.26), Vector2(0.36, -0.28)], false, 1.1)


func _draw_cleanup() -> void:
	for i in 3:
		var a0: float = -PI * 0.5 + float(i) * TAU / 3.0 + 0.32
		var a1: float = a0 + TAU / 3.0 - 0.78
		_arc(Vector2.ZERO, 0.66, a0, a1)
		_arrowhead(Vector2.ZERO, 0.66, a1, 0.3)
	_dot(Vector2.ZERO, 0.14)


func _draw_patrol() -> void:
	var hull: Array = [Vector2(-0.9, 0.2), Vector2(0.9, 0.2), Vector2(0.58, 0.6), Vector2(-0.64, 0.6)]
	_fill(hull, 0.35)
	_stroke(hull, true)
	var cabin: Array = [Vector2(-0.34, 0.2), Vector2(-0.34, -0.1), Vector2(0.3, -0.1), Vector2(0.4, 0.2)]
	_stroke(cabin)
	_stroke([Vector2(-0.02, -0.1), Vector2(-0.02, -0.5)])
	_arc(Vector2(-0.02, -0.5), 0.26, -PI * 0.82, -PI * 0.18, 0.75)
	_arc(Vector2(-0.02, -0.5), 0.46, -PI * 0.78, -PI * 0.22, 0.75)
	_stroke(_wave(-0.88, 0.88, 0.84, 0.07, 3.0), false, 0.75)


func _draw_campaign() -> void:
	var cone: Array = [Vector2(-0.46, -0.2), Vector2(0.34, -0.62), Vector2(0.34, 0.62), Vector2(-0.46, 0.2)]
	_fill(cone, 0.3)
	_stroke(cone, true)
	_fill_rect(Rect2(-0.78, -0.2, 0.26, 0.4), 0.9)
	_stroke([Vector2(-0.3, 0.2), Vector2(-0.18, 0.66)])
	_arc(Vector2(0.34, 0.0), 0.3, -PI * 0.25, PI * 0.25, 0.8)
	_arc(Vector2(0.34, 0.0), 0.52, -PI * 0.25, PI * 0.25, 0.8)


func _draw_globe() -> void:
	_ring(Vector2.ZERO, 0.84)
	_stroke(_ellipse(Vector2.ZERO, 0.36, 0.84, 0.0, 32), true, 0.75)
	_stroke([Vector2(-0.84, 0.0), Vector2(0.84, 0.0)], false, 0.75)
	_stroke([Vector2(-0.7, -0.42), Vector2(0.7, -0.42)], false, 0.6)
	_stroke([Vector2(-0.7, 0.42), Vector2(0.7, 0.42)], false, 0.6)


func _draw_warning() -> void:
	var tri: Array = [Vector2(0.0, -0.86), Vector2(0.92, 0.76), Vector2(-0.92, 0.76)]
	_fill(tri, 0.18)
	_stroke(tri, true)
	_stroke([Vector2(0.0, -0.3), Vector2(0.0, 0.22)], false, 1.15)
	_dot(Vector2(0.0, 0.48), 0.09)


# --- Phase 2: modal / HUD chrome ------------------------------------------------------

## Policy tree glyph: root, two branches, four leaves joined by elbow links.
func _draw_tree_glyph() -> void:
	_stroke([Vector2(0.0, -0.54), Vector2(0.0, -0.34)], false, 0.8)
	_stroke([Vector2(-0.48, -0.34), Vector2(0.48, -0.34)], false, 0.8)
	for sx in [-1.0, 1.0]:
		var side: float = sx
		var x: float = 0.48 * side
		_stroke([Vector2(x, -0.34), Vector2(x, -0.15)], false, 0.8)
		_stroke([Vector2(x, 0.15), Vector2(x, 0.32)], false, 0.8)
		_stroke([Vector2(x - 0.24, 0.32), Vector2(x + 0.24, 0.32)], false, 0.8)
		for kx in [-0.24, 0.24]:
			var cx: float = x + float(kx)
			_stroke([Vector2(cx, 0.32), Vector2(cx, 0.52)], false, 0.8)
			_dot(Vector2(cx, 0.68), 0.13)
		_fill(_ellipse(Vector2(x, 0.0), 0.15, 0.15, 0.0, 16), 0.35)
		_ring(Vector2(x, 0.0), 0.15, 0.8)
	_dot(Vector2(0.0, -0.7), 0.17)


## Crisis evolution: DNA double helix.
func _draw_evolution() -> void:
	var a: Array = []
	var b: Array = []
	var n: int = 28
	for i in n + 1:
		var t: float = float(i) / float(n)
		var y: float = lerpf(-0.88, 0.88, t)
		var x: float = sin(t * TAU * 1.25) * 0.46
		a.append(Vector2(x, y))
		b.append(Vector2(-x, y))
	for k in 9:
		var t2: float = (float(k) + 0.5) / 9.0
		var y2: float = lerpf(-0.88, 0.88, t2)
		var x2: float = sin(t2 * TAU * 1.25) * 0.46
		if absf(x2) > 0.12:
			_stroke([Vector2(x2, y2), Vector2(-x2, y2)], false, 0.5)
	_stroke(a, false, 0.95)
	_stroke(b, false, 0.95)


## Decision event: two stacked briefing cards, the front one marked "!".
func _draw_event_glyph() -> void:
	var back: Array = _rounded_rect(Rect2(-0.34, -0.9, 1.16, 1.5), 0.1)
	_stroke(back, true, 0.6)
	var front: Array = _rounded_rect(Rect2(-0.82, -0.62, 1.16, 1.5), 0.1)
	_fill(front, 0.0, UITheme.DEEP)
	_fill(front, 0.2)
	_stroke(front, true)
	_stroke([Vector2(-0.24, -0.3), Vector2(-0.24, 0.3)], false, 1.3)
	_dot(Vector2(-0.24, 0.56), 0.1)


## News: broadcast mast with radio waves.
func _draw_news() -> void:
	_stroke([Vector2(-0.4, 0.88), Vector2(0.0, -0.42), Vector2(0.4, 0.88)], false, 0.9)
	_stroke([Vector2(-0.295, 0.54), Vector2(0.295, 0.54)], false, 0.6)
	_stroke([Vector2(-0.185, 0.18), Vector2(0.185, 0.18)], false, 0.6)
	_stroke([Vector2(-0.295, 0.54), Vector2(0.185, 0.18)], false, 0.5)
	_stroke([Vector2(0.295, 0.54), Vector2(-0.185, 0.18)], false, 0.5)
	_dot(Vector2(0.0, -0.52), 0.15)
	_arc(Vector2(0.0, -0.52), 0.4, -PI * 0.28, PI * 0.28, 0.8)
	_arc(Vector2(0.0, -0.52), 0.66, -PI * 0.24, PI * 0.24, 0.8)
	_arc(Vector2(0.0, -0.52), 0.4, PI * 0.72, PI * 1.28, 0.8)
	_arc(Vector2(0.0, -0.52), 0.66, PI * 0.76, PI * 1.24, 0.8)


## Data bubble: glossy sphere with an atom (science) or a star (political support) inside.
func _draw_bubble(science_kind: bool) -> void:
	_fill(_ellipse(Vector2.ZERO, 0.86, 0.86, 0.0, 36), 0.12)
	_ring(Vector2.ZERO, 0.86, 0.9)
	_arc(Vector2.ZERO, 0.66, PI * 1.08, PI * 1.42, 0.8)
	_dot(Vector2(0.18, -0.64), 0.05)
	if science_kind:
		_stroke(_ellipse(Vector2(0.0, 0.06), 0.46, 0.16, 0.55, 26), true, 0.6)
		_stroke(_ellipse(Vector2(0.0, 0.06), 0.46, 0.16, -0.55, 26), true, 0.6)
		_dot(Vector2(0.0, 0.06), 0.11)
	else:
		var star: Array = _star(Vector2(0.0, 0.08), 0.46, 0.2, 5, -PI * 0.5)
		_fill(star, 0.85)
		_stroke(star, true, 0.55)


func _draw_lock() -> void:
	_arc(Vector2(0.0, -0.2), 0.36, PI, TAU, 1.0)
	_stroke([Vector2(-0.36, -0.2), Vector2(-0.36, 0.02)])
	_stroke([Vector2(0.36, -0.2), Vector2(0.36, 0.02)])
	var body: Array = _rounded_rect(Rect2(-0.6, 0.0, 1.2, 0.86), 0.1)
	_fill(body, 0.3)
	_stroke(body, true)
	_dot(Vector2(0.0, 0.36), 0.11)
	_stroke([Vector2(0.0, 0.4), Vector2(0.0, 0.62)], false, 0.9)


func _draw_fallback() -> void:
	var hexa: Array = []
	for i in 6:
		var a: float = TAU * float(i) / 6.0 - PI * 0.5
		hexa.append(Vector2(cos(a), sin(a)) * 0.8)
	_fill(hexa, 0.12)
	_stroke(hexa, true)
	_fill([Vector2(0.0, -0.3), Vector2(0.3, 0.0), Vector2(0.0, 0.3), Vector2(-0.3, 0.0)], 0.8)


# --- Phase 2: policy branches --------------------------------------------------------------

func _draw_branch_protect() -> void:
	var sh: Array = _shield(0.98)
	_fill(sh, 0.16)
	_stroke(sh, true)
	_stroke(_wave(-0.44, 0.44, -0.2, 0.09, 1.5), false, 0.85)
	_stroke(_wave(-0.4, 0.4, 0.14, 0.09, 1.5), false, 0.85)
	_dot(Vector2(0.0, 0.48), 0.09)


## Source cutting: an outfall pipe and a "no pollution" sign over a drop.
func _draw_branch_source() -> void:
	var pipe: Array = [Vector2(-0.94, -0.8), Vector2(-0.14, -0.8), Vector2(-0.14, -0.5), Vector2(-0.94, -0.5)]
	_fill(pipe, 0.25)
	_stroke(pipe, true, 0.85)
	_fill_rect(Rect2(-0.16, -0.9, 0.16, 0.5), 0.85)
	var c := Vector2(0.3, 0.34)
	var drop: Array = _teardrop(c + Vector2(0.0, 0.1), 0.2)
	_fill(drop, 0.45)
	_stroke(drop, true, 0.6)
	_ring(c, 0.54)
	_stroke([c + Vector2(-0.382, -0.382), c + Vector2(0.382, 0.382)], false, 1.1)


## Science & public: lab flask with bubbles.
func _draw_branch_science() -> void:
	var flask: Array = [
		Vector2(-0.18, -0.82), Vector2(0.18, -0.82), Vector2(0.18, -0.26), Vector2(0.74, 0.66),
		Vector2(0.64, 0.84), Vector2(-0.64, 0.84), Vector2(-0.74, 0.66), Vector2(-0.18, -0.26),
	]
	var liquid: Array = [
		Vector2(-0.5, 0.28), Vector2(0.5, 0.28), Vector2(0.74, 0.66), Vector2(0.64, 0.84),
		Vector2(-0.64, 0.84), Vector2(-0.74, 0.66),
	]
	_fill(flask, 0.1)
	_fill(liquid, 0.45)
	_stroke(flask, true)
	_stroke([Vector2(-0.3, -0.82), Vector2(0.3, -0.82)], false, 1.0)
	_ring(Vector2(-0.08, 0.02), 0.08, 0.6)
	_ring(Vector2(0.1, -0.26), 0.06, 0.6)
	_dot(Vector2(0.22, 0.52), 0.07)
	_dot(Vector2(-0.26, 0.6), 0.05)


## Economy & diplomacy: balance scale.
func _draw_branch_economy() -> void:
	_stroke([Vector2(0.0, -0.66), Vector2(0.0, 0.76)])
	_stroke([Vector2(-0.44, 0.84), Vector2(0.44, 0.84)], false, 1.1)
	_stroke([Vector2(-0.72, -0.5), Vector2(0.72, -0.5)])
	_dot(Vector2(0.0, -0.74), 0.11)
	for sx in [-1.0, 1.0]:
		var x: float = 0.7 * float(sx)
		_stroke([Vector2(x, -0.5), Vector2(x - 0.25, 0.06)], false, 0.6)
		_stroke([Vector2(x, -0.5), Vector2(x + 0.25, 0.06)], false, 0.6)
		var pan: Array = _arc_pts(Vector2(x, 0.06), 0.27, 0.0, PI, 12)
		_fill(pan, 0.45)
		_stroke(pan, true, 0.9)


# --- Phase 2: policy nodes -----------------------------------------------------------------

## Marine Protected Areas: dashed boundary around a fish.
func _draw_mpa() -> void:
	for i in 10:
		var a0: float = TAU * float(i) / 10.0
		_arc(Vector2.ZERO, 0.86, a0, a0 + TAU * 0.06, 0.85)
	_fill(_ellipse(Vector2.ZERO, 0.64, 0.64, 0.0, 30), 0.1)
	_fish_at(Vector2(0.06, 0.0), 0.58, 0.3)


## Posidonia restoration: ribbon blades rising from a rooted rhizome.
func _draw_posidonia() -> void:
	var blades: Array = [
		[Vector2(-0.52, 0.72), Vector2(-0.56, 0.0), Vector2(-0.82, -0.6)],
		[Vector2(-0.16, 0.72), Vector2(-0.12, -0.1), Vector2(-0.24, -0.92)],
		[Vector2(0.2, 0.72), Vector2(0.28, -0.06), Vector2(0.4, -0.8)],
		[Vector2(0.54, 0.72), Vector2(0.62, 0.18), Vector2(0.88, -0.32)],
	]
	for b in blades:
		var spec: Array = b
		var b0: Vector2 = spec[0]
		var b1: Vector2 = spec[1]
		var b2: Vector2 = spec[2]
		var pts: Array = _blade(b0, b1, b2, 0.09)
		_fill(pts, 0.4)
		_stroke(pts, true, 0.55)
	_stroke([Vector2(-0.86, 0.76), Vector2(0.86, 0.76)], false, 0.9)
	for x in [-0.66, -0.3, 0.06, 0.4, 0.72]:
		var rx: float = x
		_stroke([Vector2(rx, 0.76), Vector2(rx - 0.06, 0.94)], false, 0.5)


## Coral nursery: a nursery "tree" frame with coral fragments on its arms.
func _draw_coral_nursery() -> void:
	_stroke([Vector2(0.0, -0.9), Vector2(0.0, 0.84)])
	_stroke([Vector2(-0.5, 0.86), Vector2(0.5, 0.86)])
	_stroke([Vector2(-0.82, -0.42), Vector2(0.82, -0.42)], false, 0.85)
	_stroke([Vector2(-0.82, 0.32), Vector2(0.82, 0.32)], false, 0.85)
	for arm_y in [-0.42, 0.32]:
		var y: float = arm_y
		for fx in [-0.52, 0.52]:
			var x: float = fx
			_stroke([Vector2(x, y), Vector2(x, y - 0.1), Vector2(x + 0.03, y - 0.34)], false, 0.6)
			_stroke([Vector2(x, y - 0.1), Vector2(x - 0.12, y - 0.18), Vector2(x - 0.2, y - 0.3)], false, 0.6)
			_stroke([Vector2(x, y - 0.14), Vector2(x + 0.16, y - 0.22), Vector2(x + 0.24, y - 0.3)], false, 0.6)
			_dot(Vector2(x - 0.2, y - 0.31), 0.045)
			_dot(Vector2(x + 0.24, y - 0.31), 0.045)
			_dot(Vector2(x + 0.03, y - 0.36), 0.045)


## Blue carbon: seagrass pulling carbon down into the seabed store.
func _draw_blue_carbon() -> void:
	var b1: Array = _blade(Vector2(-0.46, 0.02), Vector2(-0.48, -0.42), Vector2(-0.72, -0.86), 0.08)
	var b2: Array = _blade(Vector2(-0.14, 0.02), Vector2(-0.1, -0.4), Vector2(-0.2, -0.92), 0.08)
	_fill(b1, 0.45)
	_stroke(b1, true, 0.55)
	_fill(b2, 0.45)
	_stroke(b2, true, 0.55)
	_arrow_line(Vector2(0.5, -0.9), Vector2(0.5, -0.1), 0.3, 0.95)
	_stroke([Vector2(-0.9, 0.06), Vector2(0.9, 0.06)], false, 0.9)
	for p in [Vector2(-0.56, 0.38), Vector2(-0.02, 0.38), Vector2(0.52, 0.38), Vector2(-0.3, 0.72), Vector2(0.24, 0.72)]:
		var pc: Vector2 = p
		_dot(pc, 0.15, 0.85)


## 30x30 ocean network: linked protected areas.
func _draw_mpa_network() -> void:
	var nodes: Array = [Vector2(0.0, -0.7), Vector2(0.7, 0.0), Vector2(0.0, 0.7), Vector2(-0.7, 0.0)]
	for i in 4:
		var a: Vector2 = nodes[i]
		var b: Vector2 = nodes[(i + 1) % 4]
		_link(a, b, 0.2, 0.2, 0.8)
		_link(a, Vector2.ZERO, 0.2, 0.17, 0.6)
	for n in nodes:
		var p: Vector2 = n
		_fill(_ellipse(p, 0.2, 0.2, 0.0, 18), 0.35)
		_ring(p, 0.2, 0.85)
	_ring(Vector2.ZERO, 0.17, 0.85)
	_dot(Vector2.ZERO, 0.08)


## Single-use plastic ban: bottle under a prohibition sign.
func _draw_plastic_ban() -> void:
	var bottle: Array = [
		Vector2(-0.12, -0.42), Vector2(0.12, -0.42), Vector2(0.3, -0.2), Vector2(0.3, 0.62),
		Vector2(0.22, 0.7), Vector2(-0.22, 0.7), Vector2(-0.3, 0.62), Vector2(-0.3, -0.2),
	]
	_fill(bottle, 0.28)
	_stroke(bottle, true, 0.85)
	_stroke([Vector2(-0.12, -0.42), Vector2(-0.12, -0.56), Vector2(0.12, -0.56), Vector2(0.12, -0.42)], false, 0.85)
	_fill_rect(Rect2(-0.16, -0.7, 0.32, 0.14), 0.9)
	_stroke([Vector2(-0.3, 0.08), Vector2(0.3, 0.08)], false, 0.6)
	_ring(Vector2.ZERO, 0.88, 1.05)
	_stroke([Vector2(-0.62, -0.62), Vector2(0.62, 0.62)], false, 1.1)


## River-mouth filters: river currents caught by a filter grid.
func _draw_river_filter() -> void:
	for y in [-0.42, 0.0, 0.42]:
		var wy: float = y
		_stroke(_wave(-0.94, 0.02, wy, 0.07, 1.5), false, 0.75)
	var grid: Array = [Vector2(0.14, -0.74), Vector2(0.86, -0.74), Vector2(0.86, 0.74), Vector2(0.14, 0.74)]
	_fill(grid, 0.16)
	_stroke(grid, true, 0.9)
	for x in [0.38, 0.62]:
		var gx: float = x
		_stroke([Vector2(gx, -0.74), Vector2(gx, 0.74)], false, 0.5)
	for y2 in [-0.25, 0.25]:
		var gy: float = y2
		_stroke([Vector2(0.14, gy), Vector2(0.86, gy)], false, 0.5)
	_dot(Vector2(0.26, -0.5), 0.07)
	_dot(Vector2(0.5, 0.0), 0.07)
	_dot(Vector2(0.26, 0.5), 0.06)


## Ship waste inspection: a magnifier over a ship.
func _draw_ship_inspection() -> void:
	var hull: Array = [Vector2(-0.94, 0.4), Vector2(0.16, 0.4), Vector2(0.0, 0.72), Vector2(-0.78, 0.72)]
	_fill(hull, 0.35)
	_stroke(hull, true, 0.85)
	_stroke([Vector2(-0.84, 0.4), Vector2(-0.84, 0.14), Vector2(-0.5, 0.14), Vector2(-0.5, 0.4)], false, 0.75)
	_stroke([Vector2(-0.68, 0.14), Vector2(-0.68, -0.06)], false, 0.75)
	var c := Vector2(0.16, -0.32)
	_fill(_ellipse(c, 0.42, 0.42, 0.0, 28), 0.14)
	_ring(c, 0.42)
	_stroke([c + Vector2(-0.24, 0.04), c + Vector2(0.24, 0.04)], false, 0.5)
	_stroke([c + Vector2(-0.16, -0.14), c + Vector2(0.12, -0.14)], false, 0.5)
	_stroke([c + Vector2(0.3, 0.3), Vector2(0.86, 0.38)], false, 1.6)


## Wastewater upgrade: outfall pipe, clean drops, treated basin and a check.
func _draw_wastewater() -> void:
	var pipe: Array = [Vector2(-0.94, -0.82), Vector2(-0.3, -0.82), Vector2(-0.3, -0.52), Vector2(-0.94, -0.52)]
	_fill(pipe, 0.25)
	_stroke(pipe, true, 0.8)
	_fill_rect(Rect2(-0.32, -0.92, 0.14, 0.5), 0.85)
	var d1: Array = _teardrop(Vector2(-0.22, -0.2), 0.08)
	var d2: Array = _teardrop(Vector2(-0.22, 0.06), 0.08)
	_fill(d1, 0.8)
	_fill(d2, 0.8)
	var water: Array = [
		Vector2(-0.74, 0.46), Vector2(0.62, 0.46), Vector2(0.62, 0.62), Vector2(0.44, 0.86),
		Vector2(-0.56, 0.86), Vector2(-0.74, 0.62),
	]
	_fill(water, 0.3)
	_stroke(_wave(-0.7, 0.58, 0.46, 0.04, 2.0), false, 0.7)
	_stroke([Vector2(-0.74, 0.2), Vector2(-0.74, 0.62), Vector2(-0.56, 0.86), Vector2(0.44, 0.86), Vector2(0.62, 0.62), Vector2(0.62, 0.2)], false, 0.9)
	_stroke([Vector2(0.28, -0.5), Vector2(0.46, -0.3), Vector2(0.86, -0.74)], false, 1.2)


## Ghost-net recovery: a tangled net hauled up on a line.
func _draw_ghost_net() -> void:
	var a := Vector2(0.0, -0.46)
	var b := Vector2(-0.74, 0.72)
	var c := Vector2(0.74, 0.72)
	_fill([a, c, b], 0.12)
	for k in 3:
		var t: float = float(k + 1) * 0.25
		_stroke([a.lerp(b, t), b.lerp(c, 1.0 - t)], false, 0.5)
		_stroke([a.lerp(c, t), b.lerp(c, t)], false, 0.5)
	_stroke([a, c, b], true, 0.85)
	_stroke([Vector2(0.0, -0.46), Vector2(0.0, -0.72)], false, 0.8)
	_fill([Vector2(0.0, -0.98), Vector2(-0.18, -0.7), Vector2(0.18, -0.7)], 1.0)
	_dot(Vector2(-0.18, 0.46), 0.08)


## Zero-waste ports: ship-to-shore crane landing a ship's waste container on the quay.
func _draw_zero_waste_port() -> void:
	_stroke([Vector2(-0.94, 0.8), Vector2(-0.02, 0.8)])
	_stroke(_wave(0.02, 0.94, 0.8, 0.04, 2.5), false, 0.6)
	_stroke([Vector2(-0.72, 0.8), Vector2(-0.58, -0.46)], false, 0.9)
	_stroke([Vector2(-0.16, 0.8), Vector2(-0.3, -0.46)], false, 0.9)
	_stroke([Vector2(-0.68, 0.4), Vector2(-0.2, 0.4)], false, 0.6)
	_stroke([Vector2(-0.66, 0.4), Vector2(-0.33, -0.2)], false, 0.45)
	_stroke([Vector2(-0.92, -0.46), Vector2(0.94, -0.46)])
	_stroke([Vector2(-0.44, -0.9), Vector2(-0.44, -0.46)], false, 0.8)
	_stroke([Vector2(-0.44, -0.9), Vector2(0.94, -0.46)], false, 0.5)
	_stroke([Vector2(-0.44, -0.9), Vector2(-0.92, -0.46)], false, 0.5)
	_fill_rect(Rect2(0.36, -0.53, 0.16, 0.1), 1.0)
	_stroke([Vector2(0.44, -0.43), Vector2(0.44, -0.2)], false, 0.55)
	var box: Array = [Vector2(0.18, -0.2), Vector2(0.7, -0.2), Vector2(0.7, 0.1), Vector2(0.18, 0.1)]
	_fill(box, 0.45)
	_stroke(box, true, 0.75)
	for x in [0.31, 0.44, 0.57]:
		var bx: float = x
		_stroke([Vector2(bx, -0.14), Vector2(bx, 0.04)], false, 0.4)
	var hull: Array = [Vector2(0.04, 0.36), Vector2(0.94, 0.36), Vector2(0.84, 0.62), Vector2(0.12, 0.62)]
	_fill(hull, 0.3)
	_stroke(hull, true, 0.75)


## Satellite monitoring: tilted satellite beaming down.
func _draw_satellite() -> void:
	var c := Vector2(-0.1, -0.2)
	var rot: float = -0.45
	var body: Array = _xf([Vector2(-0.2, -0.2), Vector2(0.2, -0.2), Vector2(0.2, 0.2), Vector2(-0.2, 0.2)], c, 1.0, rot)
	for sx in [-1.0, 1.0]:
		var s: float = sx
		var x0: float = 0.32 * s
		var x1: float = 0.94 * s
		var panel: Array = _xf([Vector2(x0, -0.16), Vector2(x1, -0.16), Vector2(x1, 0.16), Vector2(x0, 0.16)], c, 1.0, rot)
		_fill(panel, 0.25)
		_stroke(panel, true, 0.7)
		_stroke(_xf([Vector2(0.53 * s, -0.16), Vector2(0.53 * s, 0.16)], c, 1.0, rot), false, 0.45)
		_stroke(_xf([Vector2(0.74 * s, -0.16), Vector2(0.74 * s, 0.16)], c, 1.0, rot), false, 0.45)
		_stroke(_xf([Vector2(0.2 * s, 0.0), Vector2(x0, 0.0)], c, 1.0, rot), false, 0.6)
	_fill(body, 0.55)
	_stroke(body, true, 0.85)
	_stroke(_xf([Vector2(0.0, 0.2), Vector2(0.0, 0.36)], c, 1.0, rot), false, 0.7)
	var dish: Array = _xf(_arc_pts(Vector2(0.0, 0.36), 0.14, 0.0, PI, 8), c, 1.0, rot)
	_fill(dish, 0.6)
	var beam_c: Vector2 = c + Vector2(0.0, 0.42).rotated(rot)
	_arc(beam_c, 0.32, PI * 0.14, PI * 0.58, 0.7)
	_arc(beam_c, 0.56, PI * 0.16, PI * 0.56, 0.7)


## Citizen science: a volunteer with a magnifier.
func _draw_citizen_science() -> void:
	_fill(_ellipse(Vector2(-0.38, -0.44), 0.24, 0.24, 0.0, 20), 0.5)
	_ring(Vector2(-0.38, -0.44), 0.24)
	var torso: Array = _arc_pts(Vector2(-0.38, 0.66), 0.52, PI, TAU, 16)
	_fill(torso, 0.3)
	_stroke(torso, true)
	var c := Vector2(0.44, -0.04)
	_fill(_ellipse(c, 0.3, 0.3, 0.0, 22), 0.15)
	_ring(c, 0.3)
	_stroke([c + Vector2(0.21, 0.21), Vector2(0.9, 0.62)], false, 1.4)
	_stroke([Vector2(-0.04, 0.36), c + Vector2(-0.2, 0.22)], false, 0.8)


## Mucilage early warning: alarm bell over a slimy surface.
func _draw_mucilage_alert() -> void:
	var bell: Array = _quad(Vector2(-0.58, 0.22), Vector2(-0.5, -0.78), Vector2(0.0, -0.72), 10)
	bell.append_array(_quad(Vector2(0.0, -0.72), Vector2(0.5, -0.78), Vector2(0.58, 0.22), 10).slice(1))
	_fill(bell, 0.25)
	_stroke(bell, true)
	_dot(Vector2(0.0, 0.36), 0.11)
	_ring(Vector2(0.0, -0.82), 0.07, 0.7)
	_stroke([Vector2(-0.76, -0.46), Vector2(-0.92, -0.6)], false, 0.8)
	_stroke([Vector2(0.76, -0.46), Vector2(0.92, -0.6)], false, 0.8)
	_stroke([Vector2(-0.8, -0.14), Vector2(-0.96, -0.14)], false, 0.8)
	_stroke([Vector2(0.8, -0.14), Vector2(0.96, -0.14)], false, 0.8)
	_stroke(_wave(-0.9, 0.9, 0.7, 0.08, 2.5), false, 1.0)
	_dot(Vector2(-0.36, 0.9), 0.07)
	_dot(Vector2(0.4, 0.92), 0.06)


## School curriculum: mortarboard cap.
func _draw_school() -> void:
	_stroke([Vector2(-0.5, -0.06), Vector2(-0.5, 0.38)], false, 0.9)
	_stroke([Vector2(0.5, -0.06), Vector2(0.5, 0.38)], false, 0.9)
	_stroke(_quad(Vector2(-0.5, 0.38), Vector2(0.0, 0.66), Vector2(0.5, 0.38), 12), false, 0.9)
	var top: Array = [Vector2(0.0, -0.66), Vector2(0.94, -0.24), Vector2(0.0, 0.16), Vector2(-0.94, -0.24)]
	_fill(top, 0.0, UITheme.DEEP)
	_fill(top, 0.35)
	_stroke(top, true)
	_dot(Vector2(0.0, -0.24), 0.08)
	_stroke([Vector2(0.0, -0.24), Vector2(0.72, -0.04), Vector2(0.72, 0.42)], false, 0.7)
	_dot(Vector2(0.72, 0.5), 0.09)


## Ocean data hub: database cylinder feeding linked nodes.
func _draw_data_hub() -> void:
	var cx: float = -0.2
	var rx: float = 0.48
	var ry: float = 0.17
	var body: Array = _ellipse_arc(Vector2(cx, -0.58), rx, ry, PI, TAU, 14)
	body.append_array(_ellipse_arc(Vector2(cx, 0.6), rx, ry, 0.0, PI, 14))
	_fill(body, 0.22)
	_stroke(body, true)
	_stroke(_ellipse(Vector2(cx, -0.58), rx, ry, 0.0, 28), true, 0.8)
	_stroke(_ellipse_arc(Vector2(cx, -0.18), rx, ry, 0.0, PI, 14), false, 0.6)
	_stroke(_ellipse_arc(Vector2(cx, 0.21), rx, ry, 0.0, PI, 14), false, 0.6)
	var ends: Array = [Vector2(0.78, -0.62), Vector2(0.84, 0.04), Vector2(0.74, 0.7)]
	var starts: Array = [Vector2(0.28, -0.36), Vector2(0.28, 0.04), Vector2(0.28, 0.42)]
	for i in 3:
		var e: Vector2 = ends[i]
		var s0: Vector2 = starts[i]
		_link(s0, e, 0.0, 0.12, 0.6)
		_ring(e, 0.12, 0.7)


## Anti-disinformation: speech bubble with a check mark.
func _draw_fact_check() -> void:
	var bubble: Array = _rounded_rect(Rect2(-0.88, -0.78, 1.76, 1.2), 0.24)
	_fill(bubble, 0.18)
	_stroke(bubble, true)
	_fill([Vector2(-0.5, 0.42), Vector2(-0.64, 0.86), Vector2(-0.12, 0.42)], 0.18)
	_stroke([Vector2(-0.5, 0.44), Vector2(-0.64, 0.86), Vector2(-0.12, 0.44)], false)
	_stroke([Vector2(-0.42, -0.2), Vector2(-0.1, 0.1), Vector2(0.46, -0.46)], false, 1.3)


## Sustainable fishing quotas: catch pie with one allowed slice holding a fish.
func _draw_fishing_quota() -> void:
	var c := Vector2(0.14, 0.16)
	var sector: Array = [c]
	sector.append_array(_arc_pts(c, 0.72, -PI * 0.5, PI, 24))
	_fill(sector, 0.3)
	_stroke(sector, true)
	_arc(c, 0.72, PI, PI * 1.5, 0.4)
	_fish_at(Vector2(-0.3, -0.26), 0.4, 0.95)


## Green tourism label: beach umbrella with a leaf.
func _draw_green_tourism() -> void:
	var apex := Vector2(-0.12, -0.84)
	var c := Vector2(-0.12, -0.06)
	var canopy: Array = _arc_pts(c, 0.78, PI, TAU, 20)
	_fill(canopy, 0.3)
	_stroke(canopy, true)
	for k in [-0.42, 0.42]:
		var x: float = c.x + float(k)
		_stroke([apex, Vector2(x, c.y)], false, 0.5)
	_stroke([apex, Vector2(-0.12, 0.86)], false, 0.9)
	_stroke([Vector2(-0.62, 0.86), Vector2(0.3, 0.86)], false, 0.8)
	var leaf: Array = _leaf(Vector2(0.36, 0.8), Vector2(0.9, 0.2), 0.2)
	_fill(leaf, 0.55)
	_stroke(leaf, true, 0.7)
	_stroke([Vector2(0.36, 0.8), Vector2(0.9, 0.2)], false, 0.45)


## Fishers transition fund: fishing boat and a coin.
func _draw_fishers_fund() -> void:
	var cc := Vector2(0.5, -0.5)
	_fill(_ellipse(cc, 0.36, 0.36, 0.0, 24), 0.3)
	_ring(cc, 0.36)
	_ring(cc, 0.2, 0.6)
	var hull: Array = [Vector2(-0.94, 0.3), Vector2(0.44, 0.3), Vector2(0.24, 0.66), Vector2(-0.74, 0.66)]
	_fill(hull, 0.35)
	_stroke(hull, true, 0.9)
	_stroke([Vector2(-0.4, 0.3), Vector2(-0.4, -0.62)], false, 0.9)
	_stroke([Vector2(-0.4, -0.62), Vector2(-0.86, 0.14)], false, 0.6)
	_stroke([Vector2(-0.4, -0.3), Vector2(0.06, 0.3)], false, 0.5)
	_stroke(_wave(-0.92, 0.6, 0.86, 0.05, 3.0), false, 0.6)


## Regional treaty: signed document with a seal.
func _draw_treaty() -> void:
	var doc: Array = [Vector2(-0.64, -0.88), Vector2(0.3, -0.88), Vector2(0.64, -0.54), Vector2(0.64, 0.88), Vector2(-0.64, 0.88)]
	_fill(doc, 0.14)
	_stroke(doc, true, 0.9)
	_stroke([Vector2(0.3, -0.88), Vector2(0.3, -0.54), Vector2(0.64, -0.54)], false, 0.6)
	_stroke([Vector2(-0.4, -0.52), Vector2(0.1, -0.52)], false, 0.55)
	_stroke([Vector2(-0.4, -0.24), Vector2(0.4, -0.24)], false, 0.55)
	_stroke([Vector2(-0.4, 0.04), Vector2(0.4, 0.04)], false, 0.55)
	_stroke(_wave(-0.44, -0.04, 0.46, 0.07, 1.5), false, 0.6)
	_stroke([Vector2(0.14, 0.62), Vector2(0.06, 0.98)], false, 0.7)
	_stroke([Vector2(0.3, 0.62), Vector2(0.38, 0.98)], false, 0.7)
	_dot(Vector2(0.22, 0.48), 0.2)
	_ring(Vector2(0.22, 0.48), 0.28, 0.55)


## Blue bonds: a sea-themed bond note under a rising trend line.
func _draw_blue_bond() -> void:
	var note: Array = _rounded_rect(Rect2(-0.92, -0.3, 1.84, 0.98), 0.08)
	_fill(note, 0.18)
	_stroke(note, true)
	_stroke(_rounded_rect(Rect2(-0.76, -0.17, 1.52, 0.72), 0.05), true, 0.4)
	_ring(Vector2(0.0, 0.19), 0.27, 0.7)
	_stroke(_wave(-0.2, 0.2, 0.19, 0.07, 1.5), false, 0.75)
	_dot(Vector2(-0.6, 0.0), 0.05)
	_dot(Vector2(0.6, 0.38), 0.05)
	_stroke([Vector2(-0.78, -0.48), Vector2(-0.4, -0.66), Vector2(-0.1, -0.52)], false, 0.85)
	_arrow_line(Vector2(-0.1, -0.52), Vector2(0.62, -0.92), 0.3, 0.85)


## Carbon pricing: price tag carrying a smoke cloud.
func _draw_carbon_price() -> void:
	var tag: Array = [Vector2(-0.92, -0.06), Vector2(-0.5, -0.56), Vector2(0.88, -0.56), Vector2(0.88, 0.44), Vector2(-0.5, 0.44)]
	_fill(tag, 0.16)
	_stroke(tag, true)
	_ring(Vector2(-0.52, -0.06), 0.1, 0.7)
	_stroke(_quad(Vector2(-0.6, -0.12), Vector2(-0.84, -0.7), Vector2(-0.46, -0.94), 10), false, 0.6)
	_dot(Vector2(0.08, 0.06), 0.17)
	_dot(Vector2(0.32, -0.12), 0.23)
	_dot(Vector2(0.56, 0.06), 0.16)
	_fill_rect(Rect2(0.08, 0.0, 0.48, 0.23), 1.0)


# --- Phase 2: crisis evolutions -------------------------------------------------------------

## Upstream surge: a river with a surge arrow going upstream.
func _draw_upstream_surge() -> void:
	_stroke(_vwave(-0.9, 0.9, -0.62, 0.08, 1.5), false, 0.85)
	_stroke(_vwave(-0.9, 0.9, 0.62, 0.08, 1.5), false, 0.85)
	_arrow_line(Vector2(0.0, 0.88), Vector2(0.0, -0.92), 0.44, 1.3)
	_stroke([Vector2(-0.4, 0.46), Vector2(-0.3, 0.32), Vector2(-0.2, 0.46)], false, 0.6)
	_stroke([Vector2(0.2, 0.1), Vector2(0.3, -0.04), Vector2(0.4, 0.1)], false, 0.6)


## Poacher fleets: night fishing (crescent moon and a hook).
func _draw_poacher() -> void:
	var mc := Vector2(-0.46, -0.48)
	var mr: float = 0.38
	var away: float = PI * 0.75
	var a0: float = away - PI * 0.62
	var a1: float = away + PI * 0.62
	var p0: Vector2 = mc + Vector2(cos(a0), sin(a0)) * mr
	var p1: Vector2 = mc + Vector2(cos(a1), sin(a1)) * mr
	var moon: Array = _arc_pts(mc, mr, a0, a1, 20)
	var inner: Array = _quad(p1, mc + Vector2(cos(away), sin(away)) * mr * 0.8, p0, 14)
	moon.append_array(inner.slice(1, inner.size() - 1))
	_fill(moon, 0.85)
	_stroke(moon, true, 0.5)
	_dot(Vector2(-0.84, 0.2), 0.05)
	_dot(Vector2(-0.02, -0.86), 0.05)
	_dot(Vector2(-0.6, 0.56), 0.04)
	_ring(Vector2(0.42, -0.86), 0.07, 0.7)
	_stroke([Vector2(0.42, -0.79), Vector2(0.42, 0.3)])
	_arc(Vector2(0.16, 0.3), 0.26, 0.0, PI, 1.0)
	_stroke([Vector2(-0.1, 0.3), Vector2(-0.1, 0.06), Vector2(0.04, 0.2)], false, 0.9)


## Disinformation wave: spiky outburst crossed out.
func _draw_fake_news() -> void:
	var burst: Array = _star(Vector2(0.0, -0.02), 0.9, 0.66, 12, -PI * 0.5)
	_fill(burst, 0.18)
	_stroke(burst, true, 0.9)
	_stroke([Vector2(-0.28, -0.3), Vector2(0.28, 0.26)], false, 1.25)
	_stroke([Vector2(0.28, -0.3), Vector2(-0.28, 0.26)], false, 1.25)


## Lobby backlash: briefcase.
func _draw_lobby() -> void:
	_stroke([Vector2(-0.3, -0.36), Vector2(-0.3, -0.66), Vector2(0.3, -0.66), Vector2(0.3, -0.36)], false, 0.9)
	var body: Array = _rounded_rect(Rect2(-0.88, -0.38, 1.76, 1.12), 0.12)
	_fill(body, 0.25)
	_stroke(body, true)
	_stroke([Vector2(-0.88, 0.06), Vector2(0.88, 0.06)], false, 0.65)
	_fill_rect(Rect2(-0.13, -0.04, 0.26, 0.22), 1.0)


## Marine heatwaves: sun over the horizon with heat shimmer.
func _draw_heatwave() -> void:
	var c := Vector2(0.0, -0.02)
	var sun: Array = _arc_pts(c, 0.42, PI, TAU, 18)
	_fill(sun, 0.55)
	_stroke(sun, true)
	for k in 5:
		var a: float = PI + PI * (float(k) + 0.5) / 5.0
		var d := Vector2(cos(a), sin(a))
		_stroke([c + d * 0.56, c + d * 0.84], false, 0.85)
	_stroke(_wave(-0.86, 0.86, 0.3, 0.07, 2.5), false, 0.9)
	_stroke(_wave(-0.68, 0.68, 0.56, 0.07, 2.0), false, 0.85)
	_stroke(_wave(-0.48, 0.48, 0.8, 0.06, 1.5), false, 0.8)


## Invasive species: a spiny lionfish.
func _draw_invasive() -> void:
	var c := Vector2(0.18, 0.04)
	var top_root := Vector2(0.08, -0.12)
	for k in 6:
		var a: float = lerpf(-PI * 0.94, -PI * 0.4, float(k) / 5.0)
		var tip: Vector2 = top_root + Vector2(cos(a), sin(a)) * 0.8
		_stroke([top_root, tip], false, 0.5)
		_dot(tip, 0.045)
	var fin_root := Vector2(0.04, 0.2)
	for k in 4:
		var a2: float = lerpf(PI * 0.55, PI * 0.92, float(k) / 3.0)
		var tip2: Vector2 = fin_root + Vector2(cos(a2), sin(a2)) * 0.64
		_stroke([fin_root, tip2], false, 0.5)
		_dot(tip2, 0.04)
	_fish_at(c, 0.56, 0.5)
	_stroke([c + Vector2(-0.08, -0.17), c + Vector2(-0.08, 0.17)], false, 0.45)
	_stroke([c + Vector2(0.1, -0.2), c + Vector2(0.1, 0.2)], false, 0.45)


# --- Phase 2: decision events -----------------------------------------------------------------

## Oil spill: tanker leaking into a slick.
func _draw_oil_spill() -> void:
	var hull: Array = [Vector2(-0.94, -0.26), Vector2(0.86, -0.26), Vector2(0.66, 0.06), Vector2(-0.78, 0.06)]
	_fill(hull, 0.35)
	_stroke(hull, true, 0.9)
	_stroke([Vector2(-0.82, -0.26), Vector2(-0.82, -0.56), Vector2(-0.48, -0.56), Vector2(-0.48, -0.26)], false, 0.75)
	_stroke([Vector2(-0.6, -0.56), Vector2(-0.6, -0.76)], false, 0.75)
	_stroke([Vector2(-0.3, -0.36), Vector2(0.7, -0.36)], false, 0.5)
	var slick: Array = []
	for i in 32:
		var t: float = TAU * float(i) / 32.0
		var k: float = 1.0 + 0.12 * sin(3.0 * t + 0.6) + 0.07 * cos(5.0 * t)
		slick.append(Vector2(0.06 + cos(t) * 0.84 * k, 0.6 + sin(t) * 0.24 * k))
	_fill(slick, 0.55)
	_stroke(slick, true, 0.7)
	_arc(Vector2(-0.22, 0.62), 0.16, PI * 1.1, PI * 1.9, 0.45)
	_arc(Vector2(0.34, 0.6), 0.12, PI * 1.1, PI * 1.9, 0.45)


## Heat alert: thermometer radiating over the sea.
func _draw_heat_alert() -> void:
	var tube: Array = _rounded_rect(Rect2(-0.17, -0.9, 0.34, 1.0), 0.17)
	_fill(tube, 0.12)
	_stroke(tube, true, 0.85)
	_dot(Vector2(0.0, 0.22), 0.28)
	_fill_rect(Rect2(-0.07, -0.56, 0.14, 0.7), 1.0)
	for sx in [-1.0, 1.0]:
		var s: float = sx
		_stroke([Vector2(0.34 * s, -0.66), Vector2(0.62 * s, -0.8)], false, 0.75)
		_stroke([Vector2(0.36 * s, -0.36), Vector2(0.68 * s, -0.36)], false, 0.75)
		_stroke([Vector2(0.34 * s, -0.06), Vector2(0.62 * s, 0.08)], false, 0.75)
	_stroke(_wave(-0.92, 0.92, 0.72, 0.08, 2.5), false, 0.95)


## Lobby deal: money bag.
func _draw_lobby_deal() -> void:
	var bag: Array = _ellipse(Vector2(0.0, 0.3), 0.66, 0.56, 0.0, 30)
	_fill(bag, 0.25)
	_stroke(bag, true)
	var flaps: Array = [
		Vector2(-0.22, -0.24), Vector2(-0.46, -0.72), Vector2(-0.12, -0.56), Vector2(0.0, -0.76),
		Vector2(0.12, -0.56), Vector2(0.46, -0.72), Vector2(0.22, -0.24),
	]
	_fill(flaps, 0.3)
	_stroke(flaps, true, 0.8)
	_stroke([Vector2(-0.3, -0.24), Vector2(0.3, -0.24)], false, 1.2)
	_stroke([Vector2(0.0, -0.02), Vector2(0.0, 0.68)], false, 0.6)
	_stroke([
		Vector2(0.2, 0.1), Vector2(0.0, 0.04), Vector2(-0.2, 0.12), Vector2(-0.18, 0.28),
		Vector2(0.18, 0.36), Vector2(0.2, 0.52), Vector2(0.0, 0.6), Vector2(-0.22, 0.52)], false, 0.8)


## Greenwashing: a leaf dripping paint.
func _draw_greenwash() -> void:
	var a := Vector2(-0.72, 0.36)
	var b := Vector2(0.8, -0.78)
	var leaf: Array = _leaf(a, b, 0.42)
	_fill(leaf, 0.3)
	_stroke(leaf, true)
	_stroke([a, b], false, 0.55)
	var drips: Array = [[Vector2(-0.43, 0.27), 0.62], [Vector2(-0.16, 0.16), 0.52], [Vector2(0.17, -0.04), 0.36]]
	for d in drips:
		var spec: Array = d
		var top: Vector2 = spec[0]
		var bottom: float = spec[1]
		_stroke([top, Vector2(top.x, bottom)], false, 0.7)
		_fill(_teardrop(Vector2(top.x, bottom + 0.1), 0.07), 1.0)


## Fishers' cooperative: a school of fish.
func _draw_fishers_coop() -> void:
	_ring(Vector2.ZERO, 0.9, 0.6)
	_fish_at(Vector2(-0.08, -0.46), 0.36, 0.35)
	_fish_at(Vector2(0.32, 0.1), 0.36, 0.35)
	_fish_at(Vector2(-0.3, 0.5), 0.36, 0.35)


## Tourism surge: cruise ship under the summer sun.
func _draw_tourism_surge() -> void:
	_dot(Vector2(-0.7, -0.68), 0.13)
	for k in 6:
		var a: float = TAU * float(k) / 6.0
		var d := Vector2(cos(a), sin(a))
		_stroke([Vector2(-0.7, -0.68) + d * 0.2, Vector2(-0.7, -0.68) + d * 0.3], false, 0.55)
	var hull: Array = [Vector2(-0.94, 0.2), Vector2(0.94, 0.2), Vector2(0.72, 0.6), Vector2(-0.8, 0.6)]
	_fill(hull, 0.35)
	_stroke(hull, true, 0.9)
	_stroke([Vector2(-0.7, 0.2), Vector2(-0.7, -0.08), Vector2(0.62, -0.08), Vector2(0.62, 0.2)], false, 0.75)
	_stroke([Vector2(-0.44, -0.08), Vector2(-0.44, -0.34), Vector2(0.4, -0.34), Vector2(0.4, -0.08)], false, 0.75)
	_fill_rect(Rect2(0.04, -0.62, 0.2, 0.28), 0.7)
	for i in 5:
		_dot(Vector2(-0.48 + float(i) * 0.24, 0.06), 0.045)
	_stroke(_wave(-0.92, 0.92, 0.8, 0.05, 3.0), false, 0.6)


## Mucilage outbreak: a dripping blanket of sea snot under the surface.
func _draw_mucilage() -> void:
	_stroke(_wave(-0.94, 0.94, -0.74, 0.06, 3.0), false, 0.6)
	var top: Array = []
	var bottom: Array = []
	var n: int = 24
	for i in n + 1:
		var t: float = float(i) / float(n)
		var x: float = lerpf(-0.88, 0.88, t)
		top.append(Vector2(x, -0.42 + sin(t * TAU * 2.0 + 0.5) * 0.06))
		bottom.append(Vector2(x, _slime_bottom(t)))
	bottom.reverse()
	var band: Array = top.duplicate()
	band.append_array(bottom)
	_fill(band, 0.4)
	_stroke(band, true, 0.85)
	var strands: Array = [[0.14, 0.46], [0.34, 0.74], [0.54, 0.56], [0.74, 0.86], [0.9, 0.42]]
	for s in strands:
		var spec: Array = s
		var t2: float = spec[0]
		var y_end: float = spec[1]
		var x2: float = lerpf(-0.88, 0.88, t2)
		var y0: float = _slime_bottom(t2)
		_stroke(_quad(Vector2(x2, y0), Vector2(x2 + 0.07, (y0 + y_end) * 0.5), Vector2(x2 - 0.02, y_end), 6), false, 0.5)
		_dot(Vector2(x2 - 0.02, y_end + 0.05), 0.05)
	_ring(Vector2(-0.42, -0.14), 0.09, 0.55)
	_ring(Vector2(0.18, -0.2), 0.07, 0.55)
	_ring(Vector2(0.52, -0.04), 0.05, 0.55)


func _slime_bottom(t: float) -> float:
	return 0.12 + sin(t * TAU * 1.5 + 1.3) * 0.08


## Foreign trawlers: a trawler dragging a cone net along the seabed.
func _draw_trawler() -> void:
	var hull: Array = [Vector2(-0.94, -0.32), Vector2(0.12, -0.32), Vector2(-0.04, -0.04), Vector2(-0.8, -0.04)]
	_fill(hull, 0.35)
	_stroke(hull, true, 0.85)
	_stroke([Vector2(-0.78, -0.32), Vector2(-0.78, -0.58), Vector2(-0.46, -0.58), Vector2(-0.46, -0.32)], false, 0.7)
	_stroke([Vector2(-0.02, -0.32), Vector2(0.07, -0.56), Vector2(0.16, -0.32)], false, 0.7)
	_stroke([Vector2(0.06, -0.24), Vector2(0.3, 0.2)], false, 0.5)
	_stroke([Vector2(0.06, -0.24), Vector2(0.58, 0.0)], false, 0.5)
	var q0 := Vector2(0.3, 0.2)
	var q1 := Vector2(0.58, 0.0)
	var q2 := Vector2(0.94, 0.66)
	var q3 := Vector2(0.78, 0.84)
	_fill([q0, q1, q2, q3], 0.18)
	_stroke([q0, q1, q2, q3], true, 0.8)
	for t in [0.33, 0.66]:
		var tt: float = t
		_stroke([q0.lerp(q3, tt), q1.lerp(q2, tt)], false, 0.45)
	_stroke([q0.lerp(q1, 0.5), q3.lerp(q2, 0.5)], false, 0.45)
	_stroke(_wave(-0.94, 0.0, 0.08, 0.04, 2.5), false, 0.55)
	_stroke([Vector2(-0.94, 0.92), Vector2(0.94, 0.92)], false, 0.6)


## Caretta caretta nesting: eggs in the sand, a hatchling heading to the sea.
func _draw_caretta() -> void:
	_stroke(_wave(0.06, 0.94, -0.82, 0.05, 2.0), false, 0.7)
	_turtle_at(Vector2(0.32, -0.34), 0.42, 0.75, 0.3)
	var mound: Array = _quad(Vector2(-0.94, 0.9), Vector2(0.0, 0.0), Vector2(0.94, 0.9), 16)
	_fill(mound, 0.16)
	_stroke(mound, false, 0.9)
	for e in [Vector2(-0.27, 0.72), Vector2(0.0, 0.64), Vector2(0.27, 0.72)]:
		var ec: Vector2 = e
		var egg: Array = _ellipse(ec, 0.11, 0.13, 0.0, 16)
		_fill(egg, 0.0, UITheme.DEEP)
		_fill(egg, 0.75)
		_stroke(egg, true, 0.45)


## COP31 summits: laurel wreath around the sea.
func _draw_cop_summit() -> void:
	var c := Vector2(0.0, -0.06)
	_fill(_ellipse(c, 0.36, 0.36, 0.0, 24), 0.2)
	_ring(c, 0.36, 0.9)
	_stroke(_wave(-0.28, 0.28, -0.06, 0.06, 1.5), false, 0.6)
	for side in [-1.0, 1.0]:
		var sd: float = side
		var a0: float = PI * 0.62 if sd < 0.0 else PI * 0.38
		var a1: float = PI * 1.36 if sd < 0.0 else -PI * 0.36
		_arc(c, 0.7, minf(a0, a1), maxf(a0, a1), 0.7)
		for k in 5:
			var a: float = lerpf(a0, a1, (float(k) + 0.5) / 5.0)
			var outward := Vector2(cos(a), sin(a))
			var travel := Vector2(-sin(a), cos(a)) * (1.0 if sd < 0.0 else -1.0)
			var dir: Vector2 = (travel + outward * 0.9).normalized()
			var lc: Vector2 = c + outward * 0.78 + travel * 0.02
			_fill(_ellipse(lc, 0.15, 0.065, dir.angle(), 12), 0.8)
	_stroke([Vector2(-0.16, 0.72), Vector2(0.0, 0.62), Vector2(0.16, 0.72)], false, 0.7)


# --- Shape builders (Phase 2) ---------------------------------------------------------

## Points transformed from icon-local space: c + p.rotated(rot) * s.
func _xf(arr: Array, c: Vector2, s: float, rot: float = 0.0) -> Array:
	var out: Array = []
	for v in arr:
		var p: Vector2 = v
		out.append(c + p.rotated(rot) * s)
	return out


func _shield(s: float) -> Array:
	var pts: Array = [Vector2(0.0, -0.9), Vector2(0.74, -0.62), Vector2(0.7, 0.02)]
	pts.append_array(_quad(Vector2(0.7, 0.02), Vector2(0.56, 0.62), Vector2(0.0, 0.92), 8).slice(1))
	pts.append_array(_quad(Vector2(0.0, 0.92), Vector2(-0.56, 0.62), Vector2(-0.7, 0.02), 8).slice(1))
	pts.append(Vector2(-0.74, -0.62))
	return _xf(pts, Vector2.ZERO, s)


## Teardrop with its round part centred on c (radius r) and the tip above.
func _teardrop(c: Vector2, r: float) -> Array:
	var out: Array = [c + Vector2(0.0, -r * 2.15)]
	var steps: int = 18
	for i in steps + 1:
		var a: float = lerpf(-PI * 0.2, PI * 1.2, float(i) / float(steps))
		out.append(c + Vector2(cos(a), sin(a)) * r)
	return out


func _arc_pts(c: Vector2, r: float, a0: float, a1: float, n: int) -> Array:
	var out: Array = []
	for i in n + 1:
		var a: float = lerpf(a0, a1, float(i) / float(n))
		out.append(c + Vector2(cos(a), sin(a)) * r)
	return out


func _ellipse_arc(c: Vector2, rx: float, ry: float, a0: float, a1: float, n: int) -> Array:
	var out: Array = []
	for i in n + 1:
		var a: float = lerpf(a0, a1, float(i) / float(n))
		out.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return out


func _vwave(y0: float, y1: float, x: float, amp: float, cycles: float) -> Array:
	var out: Array = []
	var n: int = 16
	for i in n + 1:
		var t: float = float(i) / float(n)
		out.append(Vector2(x + sin(t * TAU * cycles) * amp, lerpf(y0, y1, t)))
	return out


## Ribbon leaf from base to tip, bent through ctrl (closed outline).
func _blade(base: Vector2, ctrl: Vector2, tip: Vector2, half_w: float) -> Array:
	var left: Array = _quad(base + Vector2(-half_w, 0.0), ctrl + Vector2(-half_w * 0.7, 0.0), tip, 10)
	var right: Array = _quad(tip, ctrl + Vector2(half_w * 0.7, 0.0), base + Vector2(half_w, 0.0), 10)
	var out: Array = left.duplicate()
	out.append_array(right.slice(1))
	return out


## Lens-shaped leaf between a and b, bulging by `bulge` on both sides.
func _leaf(a: Vector2, b: Vector2, bulge: float) -> Array:
	var mid: Vector2 = (a + b) * 0.5
	var d: Vector2 = b - a
	var n: Vector2 = Vector2(-d.y, d.x).normalized() * bulge
	var side1: Array = _quad(a, mid + n, b, 10)
	var side2: Array = _quad(b, mid - n, a, 10)
	var out: Array = side1.duplicate()
	out.append_array(side2.slice(1, side2.size() - 1))
	return out


func _star(c: Vector2, r_out: float, r_in: float, n: int, rot: float) -> Array:
	var out: Array = []
	for i in n * 2:
		var a: float = rot + PI * float(i) / float(n)
		var rr: float = r_out if i % 2 == 0 else r_in
		out.append(c + Vector2(cos(a), sin(a)) * rr)
	return out


## Straight line between two circles (stops at their rims).
func _link(a: Vector2, b: Vector2, ra: float, rb: float, wmul: float = 1.0) -> void:
	var d: Vector2 = (b - a).normalized()
	_stroke([a + d * ra, b - d * rb], false, wmul)


## Straight arrow from a to b with a filled head of length `head`.
func _arrow_line(a: Vector2, b: Vector2, head: float, wmul: float = 1.0) -> void:
	var d: Vector2 = (b - a).normalized()
	var n := Vector2(-d.y, d.x)
	var base: Vector2 = b - d * head
	_stroke([a, base + d * head * 0.2], false, wmul)
	_fill([b, base + n * head * 0.62, base - n * head * 0.62], 1.0)


## Fish facing right (body, tail, eye) at c, scaled by s.
func _fish_at(c: Vector2, s: float, fill_alpha: float) -> void:
	var wm: float = clampf(s * 1.4, 0.55, 1.0)
	var upper: Array = _quad(Vector2(0.82, 0.0), Vector2(0.18, -0.78), Vector2(-0.46, 0.0), 12)
	var lower: Array = _quad(Vector2(-0.46, 0.0), Vector2(0.18, 0.78), Vector2(0.82, 0.0), 12)
	var body: Array = upper.duplicate()
	body.append_array(lower.slice(1, lower.size() - 1))
	body = _xf(body, c, s)
	var t_up: Array = _xf([Vector2(-0.4, 0.0), Vector2(-0.9, -0.44), Vector2(-0.84, 0.0)], c, s)
	var t_dn: Array = _xf([Vector2(-0.4, 0.0), Vector2(-0.84, 0.0), Vector2(-0.9, 0.44)], c, s)
	_fill(body, fill_alpha)
	_stroke(body, true, wm)
	_fill(t_up, 0.6)
	_fill(t_dn, 0.6)
	_stroke(_xf([Vector2(-0.4, 0.0), Vector2(-0.9, -0.44), Vector2(-0.84, 0.0), Vector2(-0.9, 0.44)], c, s), true, wm * 0.8)
	_dot(c + Vector2(0.44, -0.1) * s, maxf(0.09 * s, 0.05))


## Sea turtle seen from above (flippers, head, patterned shell) at c, scaled and rotated.
func _turtle_at(c: Vector2, s: float, rot: float, fill_alpha: float) -> void:
	var wm: float = clampf(s * 1.3, 0.55, 1.0)
	var flippers: Array = [
		[Vector2(-0.54, -0.3), 0.32, 0.13, -0.55],
		[Vector2(0.54, -0.3), 0.32, 0.13, 0.55],
		[Vector2(-0.42, 0.52), 0.2, 0.1, 0.7],
		[Vector2(0.42, 0.52), 0.2, 0.1, -0.7],
	]
	for f in flippers:
		var spec: Array = f
		var fc: Vector2 = spec[0]
		var e: Array = _ellipse(fc, float(spec[1]), float(spec[2]), float(spec[3]), 14)
		_fill(_xf(e, c, s, rot), 0.55)
	_fill(_xf(_ellipse(Vector2(0.0, -0.74), 0.16, 0.19, 0.0, 14), c, s, rot), 0.75)
	_fill(_xf([Vector2(-0.06, 0.6), Vector2(0.06, 0.6), Vector2(0.0, 0.84)], c, s, rot), 0.6)
	var shell: Array = _xf(_ellipse(Vector2(0.0, 0.05), 0.46, 0.58, 0.0, 28), c, s, rot)
	_fill(shell, 0.0, UITheme.DEEP)
	_fill(shell, fill_alpha)
	_stroke(shell, true, wm)
	var hexa: Array = []
	var spokes: Array = []
	for i in 6:
		var a: float = TAU * float(i) / 6.0
		var inner := Vector2(0.0, 0.05) + Vector2(cos(a) * 0.2, sin(a) * 0.25)
		hexa.append(inner)
		spokes.append([inner, Vector2(0.0, 0.05) + Vector2(cos(a) * 0.44, sin(a) * 0.56)])
	_stroke(_xf(hexa, c, s, rot), true, wm * 0.6)
	for sp in spokes:
		var seg: Array = sp
		_stroke(_xf(seg, c, s, rot), false, wm * 0.5)


# --- Primitive helpers (unit space: -1..1, y down) ------------------------------------

func _map(arr: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v in arr:
		var p: Vector2 = v
		out.append(_c + p * _r)
	return out


func _stroke(arr: Array, closed: bool = false, wmul: float = 1.0) -> void:
	if arr.size() < 2:
		return
	var pts: PackedVector2Array = _map(arr)
	if closed:
		pts.append(pts[0])
	var w: float = _w * wmul
	if glow:
		draw_polyline(pts, UITheme.with_alpha(color, color.a * 0.2), w * 2.8, true)
	draw_polyline(pts, color, w, true)


func _fill(arr: Array, alpha: float, fill_col: Color = Color(0, 0, 0, 0)) -> void:
	if arr.size() < 3:
		return
	var pts: PackedVector2Array = _map(arr)
	var col: Color = UITheme.with_alpha(color, color.a * alpha)
	if fill_col.a > 0.0:
		col = fill_col
	if col.a <= 0.0:
		return
	draw_colored_polygon(pts, col)
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, col, 1.0, true)


func _fill_rect(rect: Rect2, alpha: float) -> void:
	_fill([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)], alpha)


func _dot(center: Vector2, radius: float, alpha: float = 1.0) -> void:
	var col: Color = UITheme.with_alpha(color, color.a * alpha)
	var p: Vector2 = _c + center * _r
	var rr: float = maxf(radius * _r, 1.0)
	if glow and alpha >= 1.0:
		draw_circle(p, rr + _w * 0.9, UITheme.with_alpha(color, color.a * 0.16))
	draw_circle(p, rr, col)
	draw_arc(p, rr, 0.0, TAU, 24, col, 1.0, true)


func _ring(center: Vector2, radius: float, wmul: float = 1.0) -> void:
	_arc(center, radius, 0.0, TAU, wmul)


func _arc(center: Vector2, radius: float, a0: float, a1: float, wmul: float = 1.0) -> void:
	var p: Vector2 = _c + center * _r
	var w: float = _w * wmul
	var n: int = maxi(8, int(absf(a1 - a0) * 9.0))
	if glow:
		draw_arc(p, radius * _r, a0, a1, n, UITheme.with_alpha(color, color.a * 0.2), w * 2.8, true)
	draw_arc(p, radius * _r, a0, a1, n, color, w, true)


## Filled arrowhead at angle `a` on a circle, pointing along increasing angle.
func _arrowhead(center: Vector2, radius: float, a: float, head: float) -> void:
	var tip_base: Vector2 = center + Vector2(cos(a), sin(a)) * radius
	var tangent := Vector2(-sin(a), cos(a))
	var normal := Vector2(cos(a), sin(a))
	var tip: Vector2 = tip_base + tangent * head * 0.75
	_fill([tip, tip_base + normal * head * 0.55, tip_base - normal * head * 0.55], 1.0)


func _ellipse(center: Vector2, rx: float, ry: float, rot: float, n: int) -> Array:
	var out: Array = []
	for i in n:
		var t: float = TAU * float(i) / float(n)
		var v := Vector2(cos(t) * rx, sin(t) * ry).rotated(rot)
		out.append(center + v)
	return out


func _quad(a: Vector2, ctrl: Vector2, b: Vector2, n: int) -> Array:
	var out: Array = []
	for i in n + 1:
		var t: float = float(i) / float(n)
		out.append(a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t))
	return out


func _rounded_rect(rect: Rect2, radius: float) -> Array:
	var out: Array = []
	var rr: float = minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var centers: Array = [
		Vector2(rect.end.x - rr, rect.position.y + rr),
		Vector2(rect.end.x - rr, rect.end.y - rr),
		Vector2(rect.position.x + rr, rect.end.y - rr),
		Vector2(rect.position.x + rr, rect.position.y + rr),
	]
	for k in 4:
		var cc: Vector2 = centers[k]
		var start: float = -PI * 0.5 + float(k) * PI * 0.5
		for j in 5:
			var a: float = start + PI * 0.5 * float(j) / 4.0
			out.append(cc + Vector2(cos(a), sin(a)) * rr)
	return out


func _wave(x0: float, x1: float, y: float, amp: float, cycles: float) -> Array:
	var out: Array = []
	var n: int = 16
	for i in n + 1:
		var t: float = float(i) / float(n)
		out.append(Vector2(lerpf(x0, x1, t), y + sin(t * TAU * cycles) * amp))
	return out
