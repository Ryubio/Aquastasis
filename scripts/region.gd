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
		"anchor": Vector2(-9.0, -0.6),
		"polygon": [
			Vector2(-19.6, 3.5), Vector2(-18.4, 2.95), Vector2(-16.4, 2.8), Vector2(-15.0, 1.8),
			Vector2(-14.3, -0.5), Vector2(-11.8, -3.1), Vector2(-10.5, -5.5), Vector2(-8.7, -5.6),
			Vector2(-6.7, -6.1), Vector2(-5.1, -7.0), Vector2(-3.7, -5.9), Vector2(-1.7, -3.5),
			Vector2(0.3, -2.3), Vector2(1.6, -1.3), Vector2(1.9, 0.2), Vector2(1.5, 1.0),
			Vector2(-1.6, 1.2), Vector2(-3.0, 2.5), Vector2(-6.2, 2.7), Vector2(-11.0, 2.9),
			Vector2(-14.6, 4.3), Vector2(-17.0, 4.9), Vector2(-19.4, 4.1),
		],
	},
	"central": {
		"name_key": "region.central.name",
		"coastal_pop": 0.55,
		"anchor": Vector2(3.0, 5.4),
		"polygon": [
			Vector2(-1.5, 1.8), Vector2(0.5, 3.0), Vector2(1.1, 3.0), Vector2(1.2, 1.9),
			Vector2(2.1, 1.3), Vector2(3.1, 0.0), Vector2(3.2, -1.8), Vector2(4.5, -1.0),
			Vector2(5.0, -1.3), Vector2(5.9, -0.8), Vector2(6.0, -0.4), Vector2(7.0, 0.9),
			Vector2(7.6, 2.2), Vector2(8.4, 3.4), Vector2(8.9, 5.2), Vector2(9.0, 7.5),
			Vector2(8.5, 8.1), Vector2(6.0, 9.0), Vector2(4.5, 10.9), Vector2(2.6, 10.1),
			Vector2(1.2, 8.6), Vector2(-0.8, 7.9), Vector2(-2.0, 7.9), Vector2(-3.9, 6.6),
			Vector2(-3.2, 5.6), Vector2(-3.0, 4.2), Vector2(-2.9, 2.7),
		],
	},
	"adriatic": {
		"name_key": "region.adriatic.name",
		"coastal_pop": 0.5,
		"anchor": Vector2(2.1, -4.9),
		"polygon": [
			Vector2(-1.7, -8.3), Vector2(-0.3, -8.7), Vector2(0.5, -7.8), Vector2(2.0, -5.9),
			Vector2(4.0, -4.7), Vector2(5.5, -3.6), Vector2(5.45, -1.7), Vector2(4.4, -1.5),
			Vector2(3.0, -2.5), Vector2(2.0, -3.3), Vector2(0.2, -4.4), Vector2(-0.4, -6.0),
			Vector2(-1.6, -7.0),
		],
	},
	"aegean": {
		"name_key": "region.aegean.name",
		"coastal_pop": 0.6,
		"anchor": Vector2(10.9, 1.2),
		"polygon": [
			Vector2(8.9, -2.1), Vector2(10.5, -2.5), Vector2(12.0, -2.35), Vector2(12.2, -1.3),
			Vector2(12.7, -0.4), Vector2(12.8, 0.8), Vector2(13.2, 1.95), Vector2(13.6, 2.7),
			Vector2(14.2, 3.1), Vector2(14.2, 3.65), Vector2(12.3, 4.3), Vector2(9.5, 4.2),
			Vector2(8.9, 3.4), Vector2(9.0, 1.95), Vector2(9.5, 0.65), Vector2(8.9, -0.5),
			Vector2(8.6, -1.6),
		],
	},
	"marmara": {
		"name_key": "region.marmara.name",
		"coastal_pop": 0.95,
		"anchor": Vector2(14.6, -2.3),
		"polygon": [
			Vector2(12.9, -1.9), Vector2(13.4, -2.4), Vector2(14.3, -2.75), Vector2(15.3, -3.0),
			Vector2(16.1, -2.9), Vector2(16.4, -2.4), Vector2(15.8, -1.95), Vector2(14.9, -1.75),
			Vector2(14.0, -1.6), Vector2(13.3, -1.55),
		],
	},
	"blacksea": {
		"name_key": "region.blacksea.name",
		"coastal_pop": 0.45,
		"anchor": Vector2(17.8, -6.3),
		"polygon": [
			Vector2(14.8, -4.0), Vector2(16.0, -4.15), Vector2(17.6, -4.25), Vector2(19.2, -4.7),
			Vector2(20.8, -5.1), Vector2(21.3, -6.2), Vector2(20.6, -7.6), Vector2(18.8, -8.4),
			Vector2(16.6, -8.6), Vector2(15.2, -8.0), Vector2(14.3, -6.9), Vector2(14.0, -5.6),
			Vector2(14.2, -4.6),
		],
	},
	"antalya": {
		"name_key": "region.antalya.name",
		"coastal_pop": 0.55,
		"anchor": Vector2(17.4, 4.2),
		"polygon": [
			Vector2(14.7, 3.4), Vector2(15.1, 3.1), Vector2(15.6, 3.6), Vector2(16.2, 3.5),
			Vector2(16.55, 3.05), Vector2(16.7, 2.75), Vector2(17.3, 2.9), Vector2(17.8, 3.1),
			Vector2(18.1, 3.25), Vector2(18.5, 3.6), Vector2(18.9, 3.95), Vector2(19.9, 3.6),
			Vector2(20.6, 3.0), Vector2(21.0, 3.3), Vector2(20.8, 4.1), Vector2(19.9, 4.5),
			Vector2(18.6, 4.6), Vector2(18.0, 5.3), Vector2(16.4, 5.5), Vector2(15.0, 5.3),
			Vector2(14.6, 4.4),
		],
	},
	"levant": {
		"name_key": "region.levant.name",
		"coastal_pop": 0.85,
		"anchor": Vector2(16.0, 8.0),
		"polygon": [
			Vector2(9.6, 5.6), Vector2(12.5, 5.6), Vector2(14.6, 6.0), Vector2(17.3, 6.2),
			Vector2(18.5, 6.15), Vector2(20.6, 6.0), Vector2(21.0, 5.1), Vector2(21.3, 4.5),
			Vector2(21.3, 3.7), Vector2(22.0, 3.4), Vector2(22.2, 4.5), Vector2(21.85, 5.9),
			Vector2(21.5, 6.6), Vector2(21.0, 8.0), Vector2(20.8, 8.95), Vector2(20.4, 9.7),
			Vector2(18.3, 10.0), Vector2(16.4, 9.75), Vector2(15.9, 10.1), Vector2(14.9, 10.5),
			Vector2(13.2, 9.9), Vector2(11.2, 9.6), Vector2(10.0, 9.0), Vector2(9.6, 8.5),
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
