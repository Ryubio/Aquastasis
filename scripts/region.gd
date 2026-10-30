extends RefCounted
## RegionData: static geography of the 8 sea regions (polygons, anchors, routes, coastal
## weights) plus the live 0-100 state of one region. Pure logic, no nodes.
## Map plane coordinates: x = east, y = south (3D: Vector3(x, 0, y)); north is far from camera.

const B := preload("res://scripts/balance.gd")

const IDS := ["western", "central", "adriatic", "aegean", "marmara", "blacksea", "antalya", "levant"]
const HERO_ID := "antalya"

## polygon: hand-authored coastline-like outline (approx. x = lon - 14, y = (39 - lat) * 1.3,
## small straits exaggerated for playability). anchor: label / route endpoint position.
const DEFS := {
	"western": {
		"name_key": "region.western.name",
		"coastal_pop": 1.0,
		"anchor": Vector2(-8.2, 0.4),
		"polygon": [
			Vector2(-19.35, 4.78), Vector2(-17.99, 5.17), Vector2(-16.97, 5.11), Vector2(-15.88, 5.37),
			Vector2(-12.6, 3.54), Vector2(-10.92, 3.2), Vector2(-8.89, 3.23), Vector2(-5.23, 2.96),
			Vector2(-4.27, 2.62), Vector2(-4.01, 3.07), Vector2(-3.74, 3.15), Vector2(-3.6, 3.1),
			Vector2(-3.51, 2.82), Vector2(-3.08, 2.48), Vector2(-1.47, 1.59), Vector2(-0.52, 1.84),
			Vector2(-1.2, 1.46), Vector2(-0.67, 1.43), Vector2(0.02, 1.56), Vector2(0.97, 1.42),
			Vector2(1.5, 0.86), Vector2(2.07, 0.45), Vector2(2.34, -0.29), Vector2(2.29, -0.54),
			Vector2(1.84, -1.56), Vector2(1.2, -1.85), Vector2(1.0, -2.37), Vector2(0.57, -2.41),
			Vector2(0.43, -2.62), Vector2(0.15, -2.73), Vector2(-0.39, -3.17), Vector2(-0.88, -3.22),
			Vector2(-2.01, -4.26), Vector2(-2.61, -4.65), Vector2(-3.23, -5.29), Vector2(-3.43, -6.04),
			Vector2(-3.99, -6.84), Vector2(-5.14, -7.31), Vector2(-5.95, -6.64), Vector2(-6.86, -6.38),
			Vector2(-7.51, -5.82), Vector2(-8.05, -5.65), Vector2(-8.55, -5.88), Vector2(-9.35, -6.02),
			Vector2(-10.3, -6.02), Vector2(-11.09, -5.62), Vector2(-11.19, -5.44), Vector2(-11.25, -4.8),
			Vector2(-11.01, -4.25), Vector2(-11.07, -3.95), Vector2(-11.97, -3.36), Vector2(-12.93, -2.97),
			Vector2(-14.24, -1.48), Vector2(-14.63, -0.6), Vector2(-14.17, 0.26), Vector2(-14.73, 0.67),
			Vector2(-14.95, 1.51), Vector2(-15.79, 1.98), Vector2(-16.28, 2.57), Vector2(-16.46, 2.52),
			Vector2(-18.47, 2.7), Vector2(-19.35, 3.24),
		],
	},
	"central": {
		"name_key": "region.central.name",
		"coastal_pop": 0.55,
		"anchor": Vector2(3.0, 5.4),
		"polygon": [
			Vector2(1.08, 1.73), Vector2(0.84, 1.8), Vector2(0.8, 1.91), Vector2(0.98, 2.47),
			Vector2(0.9, 2.69), Vector2(0.62, 2.64), Vector2(-0.17, 2.07), Vector2(-0.5, 2.16),
			Vector2(-1.43, 1.91), Vector2(-2.92, 2.72), Vector2(-3.25, 3.0), Vector2(-3.63, 4.24),
			Vector2(-3.28, 4.63), Vector2(-3.52, 5.42), Vector2(-3.76, 5.83), Vector2(-3.77, 6.98),
			Vector2(-3.24, 7.05), Vector2(-2.02, 8.17), Vector2(-0.87, 8.23), Vector2(0.95, 8.83),
			Vector2(1.32, 9.99), Vector2(2.48, 10.42), Vector2(4.95, 11.61), Vector2(5.16, 11.56),
			Vector2(6.37, 10.73), Vector2(6.37, 9.12), Vector2(8.04, 8.25), Vector2(8.51, 8.38),
			Vector2(9.17, 8.83), Vector2(9.5, 4.62), Vector2(8.99, 3.32), Vector2(8.49, 2.64),
			Vector2(8.31, 2.76), Vector2(7.94, 2.51), Vector2(7.52, 1.51), Vector2(7.95, 1.15),
			Vector2(7.95, 0.82), Vector2(7.32, 0.54), Vector2(7.0, -0.11), Vector2(6.46, -0.8),
			Vector2(6.25, -1.3), Vector2(5.87, -1.67), Vector2(4.31, -1.29), Vector2(3.82, -1.72),
			Vector2(3.03, -2.12), Vector2(2.42, -1.44), Vector2(2.6, -0.54), Vector2(2.84, -0.37),
			Vector2(2.84, -0.26), Vector2(2.59, -0.09), Vector2(2.33, 0.65), Vector2(1.7, 1.08),
		],
	},
	"adriatic": {
		"name_key": "region.adriatic.name",
		"coastal_pop": 0.5,
		"anchor": Vector2(2.1, -4.9),
		"polygon": [
			Vector2(-1.26, -6.17), Vector2(-0.73, -5.81), Vector2(-0.42, -4.94), Vector2(-0.01, -4.3),
			Vector2(0.86, -3.63), Vector2(1.63, -3.5), Vector2(1.72, -3.09), Vector2(1.84, -2.93),
			Vector2(3.98, -1.98), Vector2(4.39, -1.61), Vector2(5.79, -1.96), Vector2(5.7, -2.48),
			Vector2(5.8, -3.56), Vector2(5.32, -4.23), Vector2(2.59, -6.12), Vector2(2.05, -6.25),
			Vector2(1.49, -6.82), Vector2(1.16, -7.81), Vector2(0.65, -8.44), Vector2(0.38, -8.52),
			Vector2(-0.01, -8.27), Vector2(0.07, -8.69), Vector2(-0.11, -8.92), Vector2(-0.96, -9.0),
			Vector2(-1.82, -8.63), Vector2(-1.94, -8.5), Vector2(-1.81, -7.75), Vector2(-1.99, -7.08),
		],
	},
	"aegean": {
		"name_key": "region.aegean.name",
		"coastal_pop": 0.6,
		"anchor": Vector2(11.0, 0.3),
		"polygon": [
			Vector2(8.9, 2.66), Vector2(9.25, 3.18), Vector2(9.76, 4.46), Vector2(12.16, 4.8),
			Vector2(14.36, 4.85), Vector2(14.53, 2.56), Vector2(14.28, 2.49), Vector2(14.08, 2.31),
			Vector2(13.65, 2.28), Vector2(13.54, 1.41), Vector2(13.22, 1.04), Vector2(13.38, 0.94),
			Vector2(13.45, 0.75), Vector2(13.03, -0.35), Vector2(13.19, -0.63), Vector2(13.18, -0.83),
			Vector2(12.96, -1.0), Vector2(12.52, -0.98), Vector2(12.77, -1.24), Vector2(12.13, -1.67),
			Vector2(12.49, -2.45), Vector2(11.35, -2.87), Vector2(10.33, -2.8), Vector2(9.63, -2.22),
			Vector2(9.62, -1.96), Vector2(9.84, -1.68), Vector2(9.72, -1.61), Vector2(9.03, -2.41),
			Vector2(8.83, -2.4), Vector2(8.35, -2.12), Vector2(8.32, -1.32), Vector2(8.9, -0.66),
			Vector2(8.9, -0.34), Vector2(8.72, -0.16), Vector2(8.73, 0.07), Vector2(8.91, 0.22),
			Vector2(9.37, 0.29), Vector2(10.06, 1.0), Vector2(9.77, 1.11), Vector2(8.95, 1.13),
			Vector2(8.75, 1.26), Vector2(8.73, 1.57), Vector2(8.55, 1.7), Vector2(8.5, 1.89),
			Vector2(8.54, 2.23),
		],
	},
	"marmara": {
		"name_key": "region.marmara.name",
		"coastal_pop": 0.95,
		"anchor": Vector2(14.6, -2.25),
		"polygon": [
			Vector2(13.11, -1.37), Vector2(13.37, -1.32), Vector2(13.71, -1.4), Vector2(13.98, -1.2),
			Vector2(14.9, -1.32), Vector2(15.37, -1.65), Vector2(15.47, -1.97), Vector2(16.34, -2.32),
			Vector2(16.43, -2.66), Vector2(16.27, -2.82), Vector2(15.57, -3.03), Vector2(14.77, -3.05),
			Vector2(14.3, -3.24), Vector2(12.91, -2.64), Vector2(12.51, -1.77),
		],
	},
	"blacksea": {
		"name_key": "region.blacksea.name",
		"coastal_pop": 0.45,
		"anchor": Vector2(17.8, -6.3),
		"polygon": [
			Vector2(14.37, -3.53), Vector2(14.83, -3.35), Vector2(15.52, -3.35), Vector2(16.67, -3.1),
			Vector2(17.45, -3.15), Vector2(17.85, -3.3), Vector2(18.45, -3.28), Vector2(19.35, -3.6),
			Vector2(20.96, -3.62), Vector2(21.42, -8.14), Vector2(20.08, -7.36), Vector2(19.67, -7.53),
			Vector2(18.97, -8.27), Vector2(19.75, -8.8), Vector2(19.8, -9.02), Vector2(19.68, -9.21),
			Vector2(18.65, -9.5), Vector2(17.88, -10.17), Vector2(16.53, -10.0), Vector2(15.36, -7.98),
			Vector2(14.4, -6.92), Vector2(14.31, -6.36), Vector2(13.66, -5.54), Vector2(13.6, -4.67),
			Vector2(13.81, -3.88),
		],
	},
	"antalya": {
		"name_key": "region.antalya.name",
		"coastal_pop": 0.55,
		"anchor": Vector2(17.4, 4.2),
		"polygon": [
			Vector2(14.66, 4.86), Vector2(18.53, 5.05), Vector2(20.2, 4.43), Vector2(21.34, 2.81),
			Vector2(20.54, 2.57), Vector2(19.75, 3.18), Vector2(18.88, 3.53), Vector2(18.13, 2.94),
			Vector2(17.5, 2.65), Vector2(16.77, 2.47), Vector2(16.46, 2.57), Vector2(16.18, 3.24),
			Vector2(15.76, 3.32), Vector2(15.27, 2.81), Vector2(14.82, 2.65),
		],
	},
	"levant": {
		"name_key": "region.levant.name",
		"coastal_pop": 0.85,
		"anchor": Vector2(16.0, 8.0),
		"polygon": [
			Vector2(9.46, 9.03), Vector2(11.04, 9.9), Vector2(13.17, 10.23), Vector2(14.92, 10.92),
			Vector2(16.04, 10.41), Vector2(16.5, 10.09), Vector2(17.72, 10.05), Vector2(18.23, 10.34),
			Vector2(19.94, 10.5), Vector2(20.72, 9.84), Vector2(21.06, 9.09), Vector2(21.27, 8.12),
			Vector2(22.13, 6.0), Vector2(22.17, 5.32), Vector2(22.08, 4.54), Vector2(22.25, 3.85),
			Vector2(22.22, 3.5), Vector2(22.47, 3.15), Vector2(22.27, 2.59), Vector2(22.11, 2.45),
			Vector2(21.9, 2.45), Vector2(20.4, 4.67), Vector2(19.74, 4.92), Vector2(19.68, 5.04),
			Vector2(18.97, 5.4), Vector2(18.69, 5.31), Vector2(12.14, 5.1), Vector2(9.79, 4.77),
		],
	},
}

## Currents and shipping lanes. Spread is possible both ways; weight is 0-1 before the
## per-kind multiplier in balance.gd.
const ROUTES := [
	{"a": "western", "b": "central", "kind": "current", "weight": 0.8},
	{"a": "central", "b": "adriatic", "kind": "shipping", "weight": 0.6},
	{"a": "central", "b": "aegean", "kind": "shipping", "weight": 0.5},
	{"a": "central", "b": "levant", "kind": "current", "weight": 0.7},
	{"a": "aegean", "b": "marmara", "kind": "current", "weight": 0.9},
	{"a": "marmara", "b": "blacksea", "kind": "current", "weight": 0.9},
	{"a": "aegean", "b": "antalya", "kind": "current", "weight": 0.6},
	{"a": "levant", "b": "antalya", "kind": "current", "weight": 0.8},
	{"a": "levant", "b": "aegean", "kind": "shipping", "weight": 0.5},
]

var id: String = ""
var name_key: String = ""
var polygon: PackedVector2Array = PackedVector2Array()
var anchor: Vector2 = Vector2.ZERO
var coastal_pop: float = 0.0

var pollution: float = 0.0
var coral_health: float = 0.0
var seagrass: float = 0.0
var fish_stock: float = 0.0
var awareness: float = 0.0
var protection: float = 0.0


func _init(region_id: String) -> void:
	id = region_id
	var def: Dictionary = DEFS[region_id]
	name_key = def["name_key"]
	coastal_pop = def["coastal_pop"]
	anchor = def["anchor"]
	polygon = polygon_of(region_id)
	reset()


func reset() -> void:
	var start: Dictionary = B.REGION_START[id]
	pollution = start["pollution"]
	coral_health = start["coral_health"]
	seagrass = start["seagrass"]
	fish_stock = start["fish_stock"]
	awareness = start["awareness"]
	protection = start["protection"]


func clamp_all() -> void:
	pollution = clampf(pollution, 0.0, 100.0)
	coral_health = clampf(coral_health, 0.0, 100.0)
	seagrass = clampf(seagrass, 0.0, 100.0)
	fish_stock = clampf(fish_stock, 0.0, 100.0)
	awareness = clampf(awareness, 0.0, 100.0)
	protection = clampf(protection, 0.0, 100.0)


## 0 = pristine, 100 = collapsed.
func crisis_level() -> float:
	var c: float = pollution * B.CRISIS_W_POLLUTION \
		+ (100.0 - coral_health) * B.CRISIS_W_CORAL \
		+ (100.0 - seagrass) * B.CRISIS_W_SEAGRASS \
		+ (100.0 - fish_stock) * B.CRISIS_W_FISH
	return clampf(c, 0.0, 100.0)


func health() -> float:
	return 100.0 - crisis_level()


## "healthy" | "stressed" | "critical" | "collapsed"
func status() -> String:
	var c: float = crisis_level()
	if c >= B.STATUS_COLLAPSED:
		return "collapsed"
	if c >= B.STATUS_CRITICAL:
		return "critical"
	if c >= B.STATUS_STRESSED:
		return "stressed"
	return "healthy"


func to_dict() -> Dictionary:
	return {
		"id": id,
		"name_key": name_key,
		"pollution": pollution,
		"coral_health": coral_health,
		"seagrass": seagrass,
		"fish_stock": fish_stock,
		"awareness": awareness,
		"protection": protection,
		"coastal_pop": coastal_pop,
		"crisis": crisis_level(),
		"health": health(),
		"status": status(),
	}


static func polygon_of(region_id: String) -> PackedVector2Array:
	var def: Dictionary = DEFS[region_id]
	var pts: Array = def["polygon"]
	var poly := PackedVector2Array()
	for p in pts:
		poly.append(p)
	return poly


static func anchor_of(region_id: String) -> Vector2:
	var def: Dictionary = DEFS[region_id]
	return def["anchor"]


static func name_key_of(region_id: String) -> String:
	var def: Dictionary = DEFS[region_id]
	return def["name_key"]


## [{"id": String, "kind": String, "weight": float}] for every route touching region_id.
static func neighbors_of(region_id: String) -> Array:
	var result: Array = []
	for r in ROUTES:
		var route: Dictionary = r
		var a: String = route["a"]
		var b: String = route["b"]
		if a == region_id:
			result.append({"id": b, "kind": route["kind"], "weight": route["weight"]})
		elif b == region_id:
			result.append({"id": a, "kind": route["kind"], "weight": route["weight"]})
	return result


## Region id containing the map-plane point, or "" for none.
static func region_at(point: Vector2) -> String:
	for rid in IDS:
		var region_id: String = rid
		if Geometry2D.is_point_in_polygon(point, polygon_of(region_id)):
			return region_id
	return ""


static func centroid(poly: PackedVector2Array) -> Vector2:
	if poly.is_empty():
		return Vector2.ZERO
	var sum := Vector2.ZERO
	for p in poly:
		sum += p
	return sum / float(poly.size())
