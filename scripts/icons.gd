extends Control
## Icons: every HUD / resource / action icon, vector-drawn in _draw() with antialiased
## neon strokes (no image files). Set icon_id + color (or call setup()); the icon scales to
## the control's size and stays readable from 16 to 64 px.

const UITheme := preload("res://scripts/ui_theme.gd")

const IDS := [
	"budget", "political", "science", "temperature", "sea_health", "crisis", "awareness",
	"pollution", "coral", "seagrass", "fish", "protection", "pause", "play", "fast", "faster",
	"cleanup", "patrol", "campaign", "globe", "warning", "clock", "target", "info",
	"crosshair", "restart", "home", "power", "check", "population",
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
	if _r < 2.0:
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
		_:
			_ring(Vector2.ZERO, 0.6)


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
	var shield: Array = [Vector2(0.0, -0.9), Vector2(0.74, -0.62), Vector2(0.7, 0.02)]
	shield.append_array(_quad(Vector2(0.7, 0.02), Vector2(0.56, 0.62), Vector2(0.0, 0.92), 8).slice(1))
	shield.append_array(_quad(Vector2(0.0, 0.92), Vector2(-0.56, 0.62), Vector2(-0.7, 0.02), 8).slice(1))
	shield.append(Vector2(-0.74, -0.62))
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
