extends Control
## Charts: _draw()-based data displays for the HUD and menus. One script, five kinds:
## "bar" (segmented stat bar with number tick-up and change trail), "gauge" (+1.5..+4.0 °C
## arc gauge with danger zone and animated needle), "timeline" (2026-2046), "pulse" (ECG)
## and "line" (live Sea Health vs Crisis chart over 2026-2046 with the 60% goal line).

const UITheme := preload("res://scripts/ui_theme.gd")

const TEMP_MIN := 1.5
const TEMP_MAX := 4.0

var kind: String = "bar"
var mode: String = "health"            # bar color: "health" | "inverse" | "fixed"
var fixed_color: Color = UITheme.AMBER
var min_value: float = 0.0
var max_value: float = 100.0
var markers: Array = []                # bar: values to mark (e.g. goal 60)
var value_label: Label = null          # optional label kept in sync with the tick-up
var value_format: String = "pct"       # "pct" | "int" | "temp" | "temp1"
var alert: bool = false                # bar blinks (e.g. critical value)
var pulse_health: float = 50.0         # pulse: 0-100, drives color and heart rate
var start_year: int = 2026
var end_year: int = 2046
var series: Array = []                 # line: [[tick, sea_health, crisis], ...] (GameState.get_history())
var total_ticks: int = 1000            # line: ticks from start_year to end_year
var goal_value: float = 60.0           # line: dashed goal line
var health_color: Color = UITheme.HEALTHY
var crisis_color: Color = UITheme.CRISIS

var _target: float = 0.0
var _shown: float = 0.0
var _ghost: float = 0.0
var _ghost_hold: float = 0.0
var _flash: float = 0.0
var _time: float = 0.0
var _phase: float = 0.0
var _has_value: bool = false
# Line chart live head (eases toward the latest snapshot between history samples).
var _has_head: bool = false
var _head_tick: float = 0.0
var _head_h: float = 0.0
var _head_c: float = 0.0
var _tgt_tick: float = 0.0
var _tgt_h: float = 0.0
var _tgt_c: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	EventBus.language_changed.connect(_on_language_changed)


func _on_language_changed(_lang: String) -> void:
	_update_label()   # the percent format depends on the language (tr: %60, en/ru: 60%)


func setup_bar(color_mode: String, tint: Color, height: float) -> void:
	kind = "bar"
	mode = color_mode
	fixed_color = tint
	custom_minimum_size = Vector2(60.0, height)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func setup_gauge(min_size: Vector2) -> void:
	kind = "gauge"
	min_value = TEMP_MIN
	max_value = TEMP_MAX
	value_format = "temp"
	custom_minimum_size = min_size
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not _has_value:
		_target = TEMP_MIN
		_shown = TEMP_MIN
		_ghost = TEMP_MIN


func setup_timeline(height: float) -> void:
	kind = "timeline"
	min_value = 0.0
	max_value = 1.0
	custom_minimum_size = Vector2(160.0, height)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func setup_pulse(min_size: Vector2) -> void:
	kind = "pulse"
	custom_minimum_size = min_size


func setup_line(min_size: Vector2) -> void:
	kind = "line"
	min_value = 0.0
	max_value = 100.0
	custom_minimum_size = min_size
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


## Line chart data: sampled history plus the live values of the current tick (the head of
## both lines eases toward them, so the chart grows smoothly between samples).
func set_series(points: Array, live_tick: int, live_health: float, live_crisis: float) -> void:
	series = points
	var t: float = float(maxi(live_tick, 0))
	if not _has_head or t < _tgt_tick - 0.5:
		_head_tick = t
		_head_h = live_health
		_head_c = live_crisis
		_has_head = true
	_tgt_tick = t
	_tgt_h = live_health
	_tgt_c = live_crisis
	queue_redraw()


func reset_series() -> void:
	series = []
	_has_head = false
	_head_tick = 0.0
	_tgt_tick = 0.0
	queue_redraw()


## New target value; the display ticks toward it. instant skips the animation.
func set_value(v: float, instant: bool = false) -> void:
	var nv: float = clampf(v, min_value, max_value)
	if instant or not _has_value:
		_target = nv
		_shown = nv
		_ghost = nv
		_has_value = true
		_update_label()
		queue_redraw()
		return
	if absf(nv - _target) >= (max_value - min_value) * 0.03:
		_flash = 1.0
	if absf(nv - _target) > 0.0001:
		_ghost_hold = 0.45
	_target = nv
	queue_redraw()


func get_display_value() -> float:
	return _shown


func _process(delta: float) -> void:
	_time += delta
	var dirty: bool = false
	if absf(_shown - _target) > 0.00001:
		_shown = lerpf(_shown, _target, 1.0 - exp(-delta * 5.5))
		if absf(_shown - _target) < (max_value - min_value) * 0.0008:
			_shown = _target
		_update_label()
		dirty = true
	if _ghost_hold > 0.0:
		_ghost_hold -= delta
	elif absf(_ghost - _shown) > 0.00001:
		_ghost = lerpf(_ghost, _shown, 1.0 - exp(-delta * 2.2))
		if absf(_ghost - _shown) < (max_value - min_value) * 0.002:
			_ghost = _shown
		dirty = true
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 2.5)
		dirty = true
	if kind == "pulse":
		var rate: float = lerpf(2.3, 0.85, clampf(pulse_health / 100.0, 0.0, 1.0))
		_phase += delta * rate
		dirty = true
	elif kind == "line":
		if _has_head:
			var k: float = 1.0 - exp(-delta * 7.0)
			_head_tick = lerpf(_head_tick, _tgt_tick, k)
			_head_h = lerpf(_head_h, _tgt_h, k)
			_head_c = lerpf(_head_c, _tgt_c, k)
		dirty = true
	elif kind == "gauge" or kind == "timeline" or alert:
		dirty = true
	if dirty and is_visible_in_tree():
		queue_redraw()


func _update_label() -> void:
	if value_label == null:
		return
	value_label.text = format_value(_shown, value_format)


static func format_value(v: float, fmt: String) -> String:
	match fmt:
		"pct":
			return I18n.t("fmt.pct", {"v": str(roundi(v))})
		"int":
			return str(roundi(v))
		"temp":
			return "+%.2f°C" % v
		"temp1":
			return "+%.1f°C" % v
	return str(snappedf(v, 0.1))


func _draw() -> void:
	match kind:
		"bar":
			_draw_bar()
		"gauge":
			_draw_gauge()
		"timeline":
			_draw_timeline()
		"pulse":
			_draw_pulse()
		"line":
			_draw_line_chart()


# --- Bar ---------------------------------------------------------------------------

func _bar_color(v: float) -> Color:
	var f: float = clampf((v - min_value) / maxf(max_value - min_value, 0.0001), 0.0, 1.0)
	match mode:
		"health":
			return UITheme.health_color(f)
		"inverse":
			return UITheme.health_color(1.0 - f)
	return fixed_color


func _draw_bar() -> void:
	var w: float = size.x
	var h: float = size.y
	if w < 4.0 or h < 2.0:
		return
	var span: float = maxf(max_value - min_value, 0.0001)
	draw_rect(Rect2(Vector2.ZERO, size), UITheme.with_alpha(UITheme.DEEP, 0.85))
	draw_rect(Rect2(Vector2(0.5, 0.5), size - Vector2.ONE), UITheme.LINE_DIM, false, 1.0)
	var col: Color = _bar_color(_shown)
	if alert:
		col = col.lerp(Color.WHITE, 0.35 * (0.5 + 0.5 * sin(_time * 9.0)))
	var seg_w: float = 5.0 if h < 11.0 else 6.0
	var gap: float = 2.0
	var inner_w: float = w - 4.0
	var count: int = maxi(4, int(floor((inner_w + gap) / (seg_w + gap))))
	seg_w = (inner_w + gap) / float(count) - gap
	var f_shown: float = (_shown - min_value) / span
	var f_ghost: float = (_ghost - min_value) / span
	var lit_end: float = f_shown * float(count)
	var lit_w: float = clampf(f_shown, 0.0, 1.0) * inner_w
	if lit_w > 1.0:
		draw_rect(Rect2(Vector2(1.0, -1.0), Vector2(lit_w + 2.0, h + 2.0)), UITheme.with_alpha(col, 0.10 + 0.25 * _flash))
	for i in count:
		var x: float = 2.0 + float(i) * (seg_w + gap)
		var r := Rect2(Vector2(x, 2.0), Vector2(seg_w, h - 4.0))
		var center: float = float(i) + 0.5
		if center <= lit_end:
			var c: Color = col
			if center > lit_end - 1.0:
				c = col.lerp(Color.WHITE, 0.45)
			draw_rect(r, c)
		elif center <= f_ghost * float(count):
			draw_rect(r, UITheme.with_alpha(Color.WHITE, 0.35))
		else:
			draw_rect(r, UITheme.with_alpha(col, 0.11))
	for m in markers:
		var mv: float = m
		var mx: float = 2.0 + clampf((mv - min_value) / span, 0.0, 1.0) * inner_w
		draw_line(Vector2(mx, -3.0), Vector2(mx, h + 3.0), UITheme.AMBER, 1.5, true)
		draw_colored_polygon(PackedVector2Array([Vector2(mx - 4.0, -5.0), Vector2(mx + 4.0, -5.0), Vector2(mx, -1.0)]), UITheme.AMBER)


# --- Temperature gauge ---------------------------------------------------------------

func _temp_angle(t: float, a0: float, a1: float) -> float:
	return lerpf(a0, a1, clampf((t - TEMP_MIN) / (TEMP_MAX - TEMP_MIN), 0.0, 1.0))


static func temp_color(t: float) -> Color:
	if t < 2.0:
		return UITheme.HEALTHY
	if t < 2.5:
		return UITheme.HEALTHY.lerp(UITheme.WARNING, (t - 2.0) / 0.5)
	if t < 3.0:
		return UITheme.WARNING
	if t < 3.5:
		return UITheme.WARNING.lerp(UITheme.CRISIS, (t - 3.0) / 0.5)
	return UITheme.CRISIS


func _draw_gauge() -> void:
	var w: float = size.x
	var h: float = size.y
	var r: float = minf((w - 56.0) * 0.5, (h - 34.0) / 1.6)
	if r < 20.0:
		return
	var c := Vector2(w * 0.5, 20.0 + r)
	var a0: float = PI * 0.8
	var a1: float = PI * 2.2
	var font: Font = UITheme.mono_font()
	var bold: Font = UITheme.mono_bold_font()
	var cur: float = _shown
	var cur_col: Color = temp_color(cur)
	var danger: float = clampf((cur - 3.0) / 1.0, 0.0, 1.0)

	# Danger zone band (3.5 -> 4.0) with hatching.
	var dz0: float = _temp_angle(3.5, a0, a1)
	var pulse_a: float = 0.35 + 0.25 * danger * (0.5 + 0.5 * sin(_time * 6.0))
	draw_arc(c, r * 1.02, dz0, a1, 24, UITheme.with_alpha(UITheme.CRISIS, pulse_a), r * 0.07, true)
	for i in 7:
		var a: float = lerpf(dz0, a1, (float(i) + 0.5) / 7.0)
		var d := Vector2(cos(a), sin(a))
		draw_line(c + d * r * 0.98, c + d * r * 1.07, UITheme.with_alpha(UITheme.CRISIS, 0.8), 1.2, true)

	# Outer hairline and segments.
	draw_arc(c, r * 1.1, a0, a1, 64, UITheme.LINE_DIM, 1.0, true)
	var segs: int = 25
	var seg_span: float = (a1 - a0) / float(segs)
	for i in segs:
		var t_mid: float = TEMP_MIN + (float(i) + 0.5) * 0.1
		var s0: float = a0 + float(i) * seg_span + seg_span * 0.12
		var s1: float = a0 + float(i + 1) * seg_span - seg_span * 0.12
		var zc: Color = temp_color(t_mid)
		if t_mid <= cur:
			draw_arc(c, r * 0.84, s0, s1, 4, UITheme.with_alpha(zc, 0.22), r * 0.24, true)
			draw_arc(c, r * 0.84, s0, s1, 4, zc, r * 0.15, true)
		else:
			draw_arc(c, r * 0.84, s0, s1, 4, UITheme.with_alpha(zc, 0.2), r * 0.15, true)
	draw_arc(c, r * 0.66, a0, a1, 64, UITheme.with_alpha(UITheme.TEXT_DIM, 0.25), 1.0, true)

	# Scale ticks and labels.
	for k in 6:
		var tv: float = TEMP_MIN + float(k) * 0.5
		var a: float = _temp_angle(tv, a0, a1)
		var d := Vector2(cos(a), sin(a))
		draw_line(c + d * r * 1.04, c + d * r * 1.16, UITheme.TEXT_DIM, 1.5, true)
		var txt: String = "+%.1f" % tv
		var fs: int = 11
		var tsz: Vector2 = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		# Push the label centre out by its own half-extent along the ray so near-horizontal
		# labels (+2.0, +3.5) clear their tick ends.
		var lp: Vector2 = c + d * (r * 1.16 + 6.0 + absf(d.x) * tsz.x * 0.5 + absf(d.y) * float(fs) * 0.5) - Vector2(tsz.x * 0.5, -float(fs) * 0.35)
		var lc: Color = UITheme.CRISIS if tv >= 4.0 else UITheme.TEXT_DIM
		draw_string(font, lp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, lc)

	# Pointer riding the ring (keeps the centre free for the readout); trembles near the limit.
	var jitter: float = sin(_time * 23.0) * 0.012 * danger + sin(_time * 7.0) * 0.004
	var na: float = _temp_angle(cur, a0, a1) + jitter
	var nd := Vector2(cos(na), sin(na))
	var tg: Vector2 = nd.orthogonal()
	var pc: Color = cur_col.lerp(Color.WHITE, 0.35)
	draw_line(c + nd * r * 0.62, c + nd * r * 1.0, UITheme.with_alpha(cur_col, 0.28), 8.0, true)
	draw_line(c + nd * r * 0.62, c + nd * r * 1.0, pc, 2.5, true)
	var tri := PackedVector2Array([c + nd * r * 1.03, c + nd * r * 1.16 + tg * r * 0.075, c + nd * r * 1.16 - tg * r * 0.075])
	draw_colored_polygon(tri, pc)
	draw_circle(c + nd * r * 0.62, 3.0, pc)

	# Digital readout in the centre.
	var big: String = format_value(cur, "temp")
	var bfs: int = int(clampf(r * 0.32, 14.0, 30.0))
	var bsz: Vector2 = bold.get_string_size(big, HORIZONTAL_ALIGNMENT_LEFT, -1, bfs)
	var bp := Vector2(c.x - bsz.x * 0.5, c.y + bfs * 0.32)
	if danger > 0.0:
		draw_circle(c, r * 0.5, UITheme.with_alpha(UITheme.CRISIS, 0.06 * danger * (0.5 + 0.5 * sin(_time * 6.0))))
	draw_string(bold, bp + Vector2(0.0, 2.0), big, HORIZONTAL_ALIGNMENT_LEFT, -1, bfs, Color(0, 0, 0, 0.6))
	draw_string(bold, bp, big, HORIZONTAL_ALIGNMENT_LEFT, -1, bfs, cur_col.lerp(Color.WHITE, 0.15 + 0.3 * _flash))
	var ld: float = clampf((cur - TEMP_MIN) / (TEMP_MAX - TEMP_MIN), 0.0, 1.0)
	var bar_w: float = bsz.x
	var by: float = bp.y + 10.0
	draw_line(Vector2(c.x - bar_w * 0.5, by), Vector2(c.x + bar_w * 0.5, by), UITheme.with_alpha(UITheme.TEXT_DIM, 0.3), 2.0)
	draw_line(Vector2(c.x - bar_w * 0.5, by), Vector2(c.x - bar_w * 0.5 + bar_w * ld, by), cur_col, 2.0)


# --- Timeline (top bar) ----------------------------------------------------------------

func _draw_timeline() -> void:
	var w: float = size.x
	var h: float = size.y
	if w < 40.0:
		return
	var font: Font = UITheme.mono_font()
	var x0: float = 18.0
	var x1: float = w - 18.0
	var y: float = h * 0.36
	var p: float = clampf(_shown, 0.0, 1.0)
	var px: float = lerpf(x0, x1, p)
	var years: int = maxi(end_year - start_year, 1)
	draw_line(Vector2(x0, y), Vector2(x1, y), UITheme.with_alpha(UITheme.TEXT_DIM, 0.35), 2.0, true)
	draw_line(Vector2(x0, y), Vector2(px, y), UITheme.with_alpha(UITheme.AMBER, 0.28), 8.0, true)
	draw_line(Vector2(x0, y), Vector2(px, y), UITheme.AMBER, 2.5, true)
	for i in years + 1:
		var tx: float = lerpf(x0, x1, float(i) / float(years))
		var major: bool = i % 5 == 0
		var th: float = 6.0 if major else 3.0
		var tc: Color = UITheme.AMBER if tx <= px else UITheme.with_alpha(UITheme.TEXT_DIM, 0.6)
		draw_line(Vector2(tx, y - th), Vector2(tx, y + th), tc, 1.5 if major else 1.0, true)
		if major:
			var txt: String = str(start_year + i)
			var fs: int = 11
			var tsz: Vector2 = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			var lc: Color = UITheme.TEXT if tx <= px + 1.0 else UITheme.TEXT_DIM
			draw_string(font, Vector2(tx - tsz.x * 0.5, y + 10.0 + fs), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, lc)
	# Playhead: glowing diamond with a scanning halo.
	var halo: float = 0.5 + 0.5 * sin(_time * 4.0)
	draw_circle(Vector2(px, y), 9.0 + 3.0 * halo, UITheme.with_alpha(UITheme.AMBER, 0.12 + 0.1 * halo))
	var dm := PackedVector2Array([Vector2(px, y - 7.0), Vector2(px + 6.0, y), Vector2(px, y + 7.0), Vector2(px - 6.0, y)])
	draw_colored_polygon(dm, UITheme.WARNING)
	dm.append(dm[0])
	draw_polyline(dm, Color.WHITE, 1.0, true)


# --- Pulse (ECG trace) ----------------------------------------------------------------

static func _ecg(f: float) -> float:
	if f < 0.10:
		return 0.0
	if f < 0.20:
		return 0.12 * sin((f - 0.10) / 0.10 * PI)
	if f < 0.30:
		return 0.0
	if f < 0.33:
		return -0.18 * (f - 0.30) / 0.03
	if f < 0.36:
		return lerpf(-0.18, 1.0, (f - 0.33) / 0.03)
	if f < 0.40:
		return lerpf(1.0, -0.35, (f - 0.36) / 0.04)
	if f < 0.43:
		return lerpf(-0.35, 0.0, (f - 0.40) / 0.03)
	if f < 0.55:
		return 0.0
	if f < 0.72:
		return 0.24 * sin((f - 0.55) / 0.17 * PI)
	return 0.0


func _draw_pulse() -> void:
	var w: float = size.x
	var h: float = size.y
	if w < 10.0 or h < 6.0:
		return
	var col: Color = UITheme.health_color(pulse_health / 100.0)
	var mid: float = h * 0.58
	var amp: float = h * 0.42
	for gx in range(0, int(w), 12):
		draw_line(Vector2(float(gx), 0.0), Vector2(float(gx), h), UITheme.with_alpha(col, 0.05), 1.0)
	draw_line(Vector2(0.0, mid), Vector2(w, mid), UITheme.with_alpha(col, 0.10), 1.0)
	var n: int = maxi(24, int(w / 2.0))
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var glow_cols := PackedColorArray()
	var cycles: float = maxf(1.5, w / 140.0)
	for i in n + 1:
		var t: float = float(i) / float(n)
		var ph: float = t * cycles + _phase
		var f: float = ph - floor(ph)
		pts.append(Vector2(t * w, mid - _ecg(f) * amp))
		var a: float = pow(t, 1.6)
		cols.append(UITheme.with_alpha(col, 0.15 + 0.85 * a))
		glow_cols.append(UITheme.with_alpha(col, 0.18 * a))
	draw_polyline_colors(pts, glow_cols, 5.0, true)
	draw_polyline_colors(pts, cols, 1.6, true)
	var head: Vector2 = pts[pts.size() - 1]
	draw_circle(head, 4.0, UITheme.with_alpha(col, 0.3))
	draw_circle(head, 2.0, col.lerp(Color.WHITE, 0.5))


# --- Line chart (Sea Health vs Crisis, 2026-2046) ---------------------------------------

func _chart_pos(plot: Rect2, tick: float, v: float) -> Vector2:
	var fx: float = clampf(tick / float(maxi(total_ticks, 1)), 0.0, 1.0)
	var fy: float = clampf((v - min_value) / maxf(max_value - min_value, 0.0001), 0.0, 1.0)
	return Vector2(plot.position.x + plot.size.x * fx, plot.end.y - plot.size.y * fy)


## Points of one series (column 1 = sea health, 2 = crisis) up to the live head.
func _line_points(column: int, plot: Rect2, live_v: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var last_tick: float = -1.0
	for s in series:
		var row: Array = s
		if row.size() <= column:
			continue
		var tk: float = float(row[0])
		if _has_head and tk > _head_tick + 0.01:
			break
		if tk <= last_tick:
			continue
		pts.append(_chart_pos(plot, tk, float(row[column])))
		last_tick = tk
	if _has_head and _head_tick > last_tick + 0.01:
		pts.append(_chart_pos(plot, _head_tick, live_v))
	return pts


func _draw_line_chart() -> void:
	var w: float = size.x
	var h: float = size.y
	if w < 60.0 or h < 40.0:
		return
	var font: Font = UITheme.mono_font()
	var fs: int = 10
	var plot := Rect2(Vector2(24.0, 5.0), Vector2(w - 30.0, h - 21.0))
	var years: int = maxi(end_year - start_year, 1)
	var pulse: float = 0.5 + 0.5 * sin(_time * 4.0)

	# Backdrop, the winning zone above the goal, grid and axis labels.
	draw_rect(plot, UITheme.with_alpha(UITheme.DEEP, 0.55))
	var gy: float = _chart_pos(plot, 0.0, goal_value).y
	draw_rect(Rect2(plot.position, Vector2(plot.size.x, gy - plot.position.y)), UITheme.with_alpha(UITheme.HEALTHY, 0.045))
	for k in 5:
		var y: float = _chart_pos(plot, 0.0, float(k) * 25.0).y
		var ga: float = 0.16 if k % 2 == 0 else 0.08
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), UITheme.with_alpha(UITheme.TEXT_DIM, ga), 1.0)
	for i in 5:
		var x: float = plot.position.x + plot.size.x * float(i) / 4.0
		draw_line(Vector2(x, plot.position.y), Vector2(x, plot.end.y + 3.0), UITheme.with_alpha(UITheme.TEXT_DIM, 0.12), 1.0)
		var txt: String = str(start_year + int(roundf(float(years) * float(i) / 4.0)))
		var tw: float = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var tx: float = x - tw * 0.5
		if i == 0:
			tx = x - 2.0
		elif i == 4:
			tx = x - tw + 2.0
		draw_string(font, Vector2(tx, h - 2.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITheme.TEXT_DIM)
	_axis_label(font, fs, "100", plot.position.x, plot.position.y, UITheme.TEXT_DIM)
	_axis_label(font, fs, str(roundi(goal_value)), plot.position.x, gy, UITheme.AMBER)
	_axis_label(font, fs, "0", plot.position.x, plot.end.y, UITheme.TEXT_DIM)

	# Years still to play are shaded.
	var now_x: float = _chart_pos(plot, _head_tick if _has_head else 0.0, 0.0).x
	if now_x < plot.end.x - 1.0:
		draw_rect(Rect2(Vector2(now_x, plot.position.y), Vector2(plot.end.x - now_x, plot.size.y)), UITheme.with_alpha(UITheme.BG, 0.4))
	UITheme.dashed_line(self, Vector2(plot.position.x, gy), Vector2(plot.end.x, gy), UITheme.with_alpha(UITheme.AMBER, 0.9), 1.2, 5.0, 4.0)

	# Series: soft area fill under each line, glowing lines, pulsing heads with value tags.
	var hp: PackedVector2Array = _line_points(1, plot, _head_h)
	var cp: PackedVector2Array = _line_points(2, plot, _head_c)
	_draw_area(cp, plot.end.y, crisis_color, 0.13)
	_draw_area(hp, plot.end.y, health_color, 0.24)
	_draw_series(cp, crisis_color, 1.6)
	_draw_series(hp, health_color, 2.0)
	if _has_head:
		UITheme.dashed_line(self, Vector2(now_x, plot.position.y), Vector2(now_x, plot.end.y), UITheme.with_alpha(UITheme.AMBER, 0.4), 1.0, 2.0, 3.0)
	if hp.size() > 0 and cp.size() > 0:
		var ph: Vector2 = hp[hp.size() - 1]
		var pc: Vector2 = cp[cp.size() - 1]
		_draw_head(pc, crisis_color, pulse)
		_draw_head(ph, health_color, pulse)
		var yh: float = ph.y
		var yc: float = pc.y
		if absf(yh - yc) < 12.0:
			var mid: float = (yh + yc) * 0.5
			if yh <= yc:
				yh = mid - 6.0
				yc = mid + 6.0
			else:
				yh = mid + 6.0
				yc = mid - 6.0
		_head_tag(font, fs, str(roundi(_head_c)), Vector2(pc.x, yc), plot, crisis_color)
		_head_tag(font, fs, str(roundi(_head_h)), Vector2(ph.x, yh), plot, health_color)
	draw_rect(plot, UITheme.LINE_DIM, false, 1.0)


func _axis_label(font: Font, fs: int, txt: String, plot_left: float, y: float, col: Color) -> void:
	var tw: float = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, Vector2(plot_left - 4.0 - tw, y + float(fs) * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## Vertical gradient under a line, as one quad per segment (no polygon triangulation).
func _draw_area(pts: PackedVector2Array, base_y: float, col: Color, alpha: float) -> void:
	if pts.size() < 2:
		return
	var top: Color = UITheme.with_alpha(col, alpha)
	var bottom: Color = UITheme.with_alpha(col, 0.0)
	var colors := PackedColorArray([top, top, bottom, bottom])
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		if b.x - a.x < 0.01:
			continue
		draw_primitive(PackedVector2Array([a, b, Vector2(b.x, base_y), Vector2(a.x, base_y)]), colors, PackedVector2Array())


func _draw_series(pts: PackedVector2Array, col: Color, width: float) -> void:
	if pts.size() < 2:
		return
	draw_polyline(pts, UITheme.with_alpha(col, 0.22), width * 3.0, true)
	draw_polyline(pts, col, width, true)


func _draw_head(p: Vector2, col: Color, pulse: float) -> void:
	draw_circle(p, 5.0 + 2.5 * pulse, UITheme.with_alpha(col, 0.18 + 0.1 * pulse))
	draw_circle(p, 2.6, col.lerp(Color.WHITE, 0.45))


func _head_tag(font: Font, fs: int, txt: String, at: Vector2, plot: Rect2, col: Color) -> void:
	var tw: float = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x: float = at.x + 8.0
	if x + tw > plot.end.x - 2.0:
		x = at.x - 8.0 - tw
	var y: float = clampf(at.y + float(fs) * 0.35, plot.position.y + float(fs), plot.end.y - 2.0)
	var p := Vector2(roundf(x), roundf(y))
	draw_string_outline(font, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, UITheme.with_alpha(UITheme.DEEP, 0.9))
	draw_string(font, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col.lerp(Color.WHITE, 0.3))
