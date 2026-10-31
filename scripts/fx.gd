extends Control
## FX: screen-space data bubble layer over the 3D map. Pooled clickable Science (turquoise)
## and Political Support (amber) bubbles float at map.unproject_region(region) plus a stable
## offset chosen clear of the map labels, bob and glow; a click calls GameState.collect_bubble
## -> pop burst, a floating "+N" and a spark flying to the resource counter. Expiry fades out.

const MapBuilder := preload("res://scripts/map_builder.gd")
const UITheme := preload("res://scripts/ui_theme.gd")
const Icons := preload("res://scripts/icons.gd")
const RegionData := preload("res://scripts/region.gd")

## Screen area bubbles may use at 1920x1080: the map between the HUD panels (docs 11.9).
const MAP_RECT := Rect2(380.0, 112.0, 1100.0, 920.0)
const HIT_RADIUS := 28.0
const RADIUS := {"science": 21.0, "political": 23.0, "budget": 23.0}
const ICON_PX := 24.0
const PING_PERIOD := 2.6         # seconds between sonar pings of a waiting bubble
## Candidate rings around a region anchor (screen px, [rx, ry]); the spawn picks the nearest
## spot clear of every map label, the other bubbles and the HUD (see _choose_offset).
const RINGS := [[64.0, 54.0], [96.0, 78.0], [132.0, 104.0]]
const RING_STEPS := 12
## Map labels as seen at the gameplay framing: the name (1-2 lines, wraps at ~21 chars)
## sits above the anchor, the status word below it. Antalya's label is nudged east and the
## hero "ANTALYA · COP31" beacon label floats above the gulf.
const LABEL_CHAR_W := 11.7
const LABEL_WRAP_CHARS := 21
const LABEL_LINE_H := 25.0
const LABEL_NUDGE := {"antalya": Vector2(44.0, -4.0)}
const HERO_LABEL_OFFSET := Vector2(29.0, -115.0)
const HERO_LABEL_SIZE := Vector2(196.0, 30.0)
## HUD top bar resource icons: distance from the right screen edge (right-aligned row).
const COUNTER_FROM_RIGHT := {"budget": 594.0, "political": 392.0, "science": 190.0}
const COUNTER_Y := 96.0          # comets end just under the top bar, below the counter
const BURST_TIME := 1.25
const COMET_TIME := 0.6
const DYING_TIME := 0.7
const STALE_TIME := 0.25

var map: MapBuilder = null   # set by main.gd before the first game; used to project bubbles

var _recs: Dictionary = {}   # bubble id -> record Dictionary (see _on_bubble_spawned)
var _pool: Array = []        # idle bubble Controls
var _bursts: Array = []      # {"pos", "t", "col", "text", "label", "seed"}
var _comets: Array = []      # {"from", "to", "t", "col"}
var _arrivals: Array = []    # {"pos", "t", "col"}
var _tick: int = 0
var _time: float = 0.0
var _had_effects: bool = false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.randomize()
	EventBus.bubble_spawned.connect(_on_bubble_spawned)
	EventBus.bubble_expired.connect(_on_bubble_expired)
	EventBus.bubble_collected.connect(_on_bubble_collected)
	EventBus.tick_done.connect(_on_tick_done)
	EventBus.language_changed.connect(_on_language_changed)


## Removes every bubble immediately (new game, main menu, game over).
func clear_all() -> void:
	for id in _recs.keys():
		var rec: Dictionary = _recs[id]
		_park(rec["node"])
	_recs.clear()
	_bursts.clear()
	_comets.clear()
	_arrivals.clear()
	queue_redraw()


# --- Bubble lifecycle -----------------------------------------------------------------------

func _on_bubble_spawned(bubble: Dictionary) -> void:
	var id: int = int(bubble.get("id", -1))
	if id < 0:
		return
	if _recs.has(id):
		_release(id)
	var kind: String = str(bubble.get("kind", "science"))
	var region: String = str(bubble.get("region", ""))
	var node: Control = _acquire()
	node.set_meta("bid", id)
	var ic: Icons = node.get_child(0) as Icons
	var tint: Color = _tint(kind)
	if ic != null:
		ic.icon_id = _bubble_icon(kind)
		ic.color = tint.lerp(Color.WHITE, 0.6)
	var rec: Dictionary = {
		"id": id,
		"kind": kind,
		"region": region,
		"amount": float(bubble.get("amount", 0.0)),
		"ttl": maxi(int(bubble.get("ttl", 1)), 1),
		"born": _tick,
		"node": node,
		"tint": tint,
		"radius": float(RADIUS.get(kind, 21.0)),
		"offset": _choose_offset(region, float(RADIUS.get(kind, 21.0))),
		"phase": _rng.randf_range(0.0, TAU),
		"age": 0.0,
		"appear": 0.0,
		"state": "alive",
		"fade": 0.0,
		"hover": 0.0,
		"hovered": false,
		"life": 1.0,
		"bob": 0.0,
		"pos": Vector2.ZERO,
	}
	_recs[id] = rec
	_place(rec, 0.0)


func _on_bubble_expired(bubble_id: int) -> void:
	if not _recs.has(bubble_id):
		return
	_start_dying(_recs[bubble_id], "dying")


func _on_bubble_collected(bubble_id: int, kind: String, amount: float) -> void:
	if not _recs.has(bubble_id):
		return
	var rec: Dictionary = _recs[bubble_id]
	var pos: Vector2 = rec["pos"]
	var tint: Color = _tint(kind)
	_release(bubble_id)
	_bursts.append({
		"pos": pos,
		"t": 0.0,
		"col": tint,
		"text": "+" + _fmt_amount(amount),
		"kind": kind,
		"label": _res_name(kind),
		"seed": _rng.randf_range(0.0, TAU),
	})
	_comets.append({"from": pos, "to": _counter_pos(kind), "t": 0.0, "col": tint})
	queue_redraw()


func _on_tick_done(snapshot: Dictionary) -> void:
	_tick = int(snapshot.get("tick", _tick))


func _on_language_changed(_lang: String) -> void:
	for b in _bursts:
		var burst: Dictionary = b
		burst["label"] = _res_name(str(burst.get("kind", "")))
	for id in _recs.keys():
		var rec: Dictionary = _recs[id]
		var node: Control = rec["node"]
		node.queue_redraw()


func _start_dying(rec: Dictionary, state: String) -> void:
	if str(rec["state"]) != "alive":
		return
	rec["state"] = state
	rec["fade"] = 0.0
	var node: Control = rec["node"]
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.mouse_default_cursor_shape = Control.CURSOR_ARROW


func _release(id: int) -> void:
	if not _recs.has(id):
		return
	var rec: Dictionary = _recs[id]
	_recs.erase(id)
	_park(rec["node"])


func _park(node: Control) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.visible = false
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.set_meta("bid", -1)
	if not _pool.has(node):
		_pool.append(node)


func _acquire() -> Control:
	var node: Control = null
	while not _pool.is_empty() and node == null:
		var n: Control = _pool.pop_back()
		if is_instance_valid(n):
			node = n
	if node == null:
		node = Control.new()
		node.size = Vector2(HIT_RADIUS * 2.0, HIT_RADIUS * 2.0)
		node.draw.connect(_draw_bubble.bind(node))
		node.gui_input.connect(_on_bubble_input.bind(node))
		node.mouse_entered.connect(_on_bubble_hover.bind(node, true))
		node.mouse_exited.connect(_on_bubble_hover.bind(node, false))
		var ic: Icons = Icons.new()
		ic.setup("science", UITheme.BUBBLE_SCIENCE, ICON_PX)
		ic.size = Vector2(ICON_PX, ICON_PX)
		ic.position = node.size * 0.5 - ic.size * 0.5
		ic.pivot_offset = ic.size * 0.5
		node.add_child(ic)
		add_child(node)
	node.visible = true
	node.mouse_filter = Control.MOUSE_FILTER_STOP
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.tooltip_text = ""
	return node


## Stable offset from the region anchor: the closest candidate spot that stays clear of
## every map label, the other bubbles and the HUD, preferring its own region's side of the
## map (closer to its own anchor than to any other).
func _choose_offset(region: String, radius: float) -> Vector2:
	var anchors: Dictionary = {}
	for rid in RegionData.IDS:
		var region_id: String = rid
		anchors[region_id] = _anchor(region_id)
	var own: Vector2 = anchors.get(region, MAP_RECT.get_center())
	var labels: Array = _label_rects(anchors)
	var others: Array = []
	for id in _recs.keys():
		var rec: Dictionary = _recs[id]
		var other_base: Vector2 = anchors.get(str(rec["region"]), MAP_RECT.get_center())
		var other_off: Vector2 = rec["offset"]
		others.append(other_base + other_off)
	var safe: Rect2 = MAP_RECT.grow(-(radius + 16.0))
	var best := Vector2(0.0, -64.0)
	var best_score: float = INF
	for ri in RINGS.size():
		var ring: Array = RINGS[ri]
		var rx: float = ring[0]
		var ry: float = ring[1]
		for k in RING_STEPS:
			var ang: float = float(k) * TAU / float(RING_STEPS) + float(ri) * 0.26
			var off := Vector2(cos(ang) * rx, sin(ang) * ry)
			var p: Vector2 = own + off
			var score: float = off.length() * 0.03 + _rng.randf() * 0.6
			if not safe.has_point(p):
				score += 200.0
			for l in labels:
				var lr: Rect2 = l
				if lr.grow(radius + 6.0).has_point(p):
					score += 60.0
			for q in others:
				var qp: Vector2 = q
				var gap: float = radius * 2.0 + 16.0 - p.distance_to(qp)
				if gap > 0.0:
					score += 40.0 + gap
			var d_own: float = p.distance_to(own)
			for rid in anchors.keys():
				if str(rid) == region:
					continue
				var other_anchor: Vector2 = anchors[rid]
				if p.distance_to(other_anchor) < d_own:
					score += 6.0
					break
			if score < best_score:
				best_score = score
				best = off
	return best


func _label_rects(anchors: Dictionary) -> Array:
	var out: Array = []
	for rid in anchors.keys():
		var region_id: String = str(rid)
		var a: Vector2 = anchors[rid]
		var label: String = I18n.t(RegionData.name_key_of(region_id))
		var chars: int = label.length()
		var lines: int = maxi(1, ceili(float(chars) / float(LABEL_WRAP_CHARS)))
		var w: float = float(mini(chars, LABEL_WRAP_CHARS)) * LABEL_CHAR_W + 10.0
		var c: Vector2 = a + LABEL_NUDGE.get(region_id, Vector2.ZERO)
		out.append(Rect2(c.x - w * 0.5, c.y - LABEL_LINE_H * float(lines) - 2.0, w, LABEL_LINE_H * float(lines) + 22.0))
	if anchors.has(RegionData.HERO_ID):
		var h: Vector2 = anchors[RegionData.HERO_ID]
		var hc: Vector2 = h + HERO_LABEL_OFFSET
		out.append(Rect2(hc - HERO_LABEL_SIZE * 0.5, HERO_LABEL_SIZE))
	return out


# --- Input ------------------------------------------------------------------------------------

func _on_bubble_input(event: InputEvent, node: Control) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	node.accept_event()
	var id: int = int(node.get_meta("bid", -1))
	if not _recs.has(id):
		return
	var rec: Dictionary = _recs[id]
	if str(rec["state"]) != "alive":
		return
	if not GameState.collect_bubble(id) and _recs.has(id):
		# The simulation no longer knows this bubble: let it vanish quickly.
		_start_dying(_recs[id], "stale")


func _on_bubble_hover(node: Control, on: bool) -> void:
	var id: int = int(node.get_meta("bid", -1))
	if not _recs.has(id):
		return
	var rec: Dictionary = _recs[id]
	rec["hovered"] = on and str(rec["state"]) == "alive"
	if on:
		move_child(node, get_child_count() - 1)   # hovered bubble and its label draw on top


# --- Per frame ----------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	var proj: Dictionary = {}   # region -> projected anchor (one projection per region per frame)
	for id in _recs.keys():
		var rec: Dictionary = _recs[id]
		var region: String = rec["region"]
		if not proj.has(region):
			proj[region] = _anchor(region)
		var base: Vector2 = proj[region]
		_step(rec, delta)
		var state: String = rec["state"]
		var limit: float = STALE_TIME if state == "stale" else DYING_TIME
		if state != "alive" and float(rec["fade"]) >= 1.0:
			_release(int(id))
			continue
		_place_at(rec, base)
		if state != "alive":
			rec["fade"] = minf(1.0, float(rec["fade"]) + delta / limit)
	for i in range(_bursts.size() - 1, -1, -1):
		var b: Dictionary = _bursts[i]
		b["t"] = float(b["t"]) + delta
		if float(b["t"]) >= BURST_TIME:
			_bursts.remove_at(i)
	for i in range(_comets.size() - 1, -1, -1):
		var c: Dictionary = _comets[i]
		c["t"] = float(c["t"]) + delta / COMET_TIME
		if float(c["t"]) >= 1.0:
			_arrivals.append({"pos": c["to"], "t": 0.0, "col": c["col"]})
			_comets.remove_at(i)
	for i in range(_arrivals.size() - 1, -1, -1):
		var a: Dictionary = _arrivals[i]
		a["t"] = float(a["t"]) + delta / 0.45
		if float(a["t"]) >= 1.0:
			_arrivals.remove_at(i)
	var has_effects: bool = not _bursts.is_empty() or not _comets.is_empty() or not _arrivals.is_empty()
	if has_effects or _had_effects:
		queue_redraw()   # one extra frame after the last effect clears the canvas
	_had_effects = has_effects


func _step(rec: Dictionary, delta: float) -> void:
	rec["age"] = float(rec["age"]) + delta
	rec["appear"] = minf(1.0, float(rec["appear"]) + delta / 0.55)
	var hover_goal: float = 1.0 if bool(rec["hovered"]) else 0.0
	rec["hover"] = lerpf(float(rec["hover"]), hover_goal, 1.0 - exp(-delta * 14.0))
	var ttl: int = int(rec["ttl"])
	var lived: int = maxi(_tick - int(rec["born"]), 0)
	var life_goal: float = clampf(1.0 - float(lived) / float(ttl), 0.0, 1.0)
	rec["life"] = lerpf(float(rec["life"]), life_goal, 1.0 - exp(-delta * 6.0))


func _place(rec: Dictionary, delta: float) -> void:
	_step(rec, delta)
	_place_at(rec, _anchor(str(rec["region"])))


func _place_at(rec: Dictionary, base: Vector2) -> void:
	var age: float = rec["age"]
	var ph: float = rec["phase"]
	var off: Vector2 = rec["offset"]
	var drift := Vector2(sin(age * 0.7 + ph) * 6.0, cos(age * 0.53 + ph * 1.3) * 3.0)
	var appear: float = rec["appear"]
	var rise: float = (1.0 - _ease_out(appear)) * 26.0
	var bob: float = sin(age * 2.1 + ph) * 4.0 + rise + float(rec["fade"]) * 16.0
	rec["bob"] = bob
	var p: Vector2 = base + off + drift + Vector2(0.0, bob)
	var r: float = float(rec["radius"]) + 14.0
	p.x = clampf(p.x, MAP_RECT.position.x + r, MAP_RECT.end.x - r)
	p.y = clampf(p.y, MAP_RECT.position.y + r, MAP_RECT.end.y - r)
	rec["pos"] = p
	var node: Control = rec["node"]
	node.position = p - node.size * 0.5
	var ic: Icons = node.get_child(0) as Icons
	if ic != null:
		var vis: Dictionary = _visual(rec)
		var s: float = vis["scale"]
		ic.scale = Vector2(s, s)
		ic.modulate = Color(1.0, 1.0, 1.0, float(vis["alpha"]))
	node.queue_redraw()


## Shared look parameters of a bubble this frame: {"scale", "alpha", "urgent"}.
func _visual(rec: Dictionary) -> Dictionary:
	var appear: float = rec["appear"]
	var fade: float = rec["fade"]
	var hover: float = rec["hover"]
	var life: float = rec["life"]
	var urgent: float = clampf((0.3 - life) / 0.3, 0.0, 1.0)
	var blink: float = 1.0 - urgent * 0.5 * (0.5 + 0.5 * sin(float(rec["age"]) * 13.0))
	var a: float = clampf(appear * 1.8, 0.0, 1.0) * (1.0 - fade) * blink
	var s: float = _back_ease(appear) * (1.0 + 0.16 * hover) * (1.0 - 0.4 * fade)
	if str(rec["state"]) == "stale":
		s *= 1.0 + 0.3 * fade
	return {"scale": s, "alpha": a, "urgent": urgent}


func _anchor(region: String) -> Vector2:
	if map != null and is_instance_valid(map):
		var v: Vector2 = map.unproject_region(region)
		if v != Vector2.ZERO:
			return v
	return MAP_RECT.get_center()


func _counter_pos(kind: String) -> Vector2:
	var vw: float = get_viewport_rect().size.x
	var from_right: float = float(COUNTER_FROM_RIGHT.get(kind, 178.0))
	return Vector2(vw - from_right, COUNTER_Y)


# --- Drawing ------------------------------------------------------------------------------------

func _draw_bubble(node: Control) -> void:
	var id: int = int(node.get_meta("bid", -1))
	if not _recs.has(id):
		return
	var rec: Dictionary = _recs[id]
	var vis: Dictionary = _visual(rec)
	var a: float = vis["alpha"]
	if a <= 0.01:
		return
	var s: float = vis["scale"]
	var urgent: float = vis["urgent"]
	var tint: Color = rec["tint"]
	var hover: float = rec["hover"]
	var age: float = rec["age"]
	var ph: float = rec["phase"]
	var c: Vector2 = node.size * 0.5
	var r0: float = rec["radius"]
	var r: float = r0 * s
	var pulse: float = 0.5 + 0.5 * sin(age * 3.0 + ph)

	# Water ripple under the bubble, kept on the sea surface while the bubble bobs.
	var wy: float = c.y + r0 + 16.0 - float(rec["bob"])
	var ring_r: float = r0 * (0.75 + 0.18 * pulse)
	var surf_a: float = a * (0.45 - 0.25 * float(rec["fade"]))
	node.draw_set_transform(Vector2(c.x, wy), 0.0, Vector2(1.0, 0.32))
	node.draw_circle(Vector2.ZERO, ring_r * 1.1, UITheme.with_alpha(tint, 0.07 * a))
	node.draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 32, UITheme.with_alpha(tint, surf_a), 2.0, true)
	var appear: float = rec["appear"]
	if appear < 1.0:
		var sr: float = r0 * (0.5 + 2.6 * _ease_out(appear))
		node.draw_arc(Vector2.ZERO, sr, 0.0, TAU, 40, UITheme.with_alpha(tint.lerp(Color.WHITE, 0.4), (1.0 - appear) * 0.9), 2.5, true)
	node.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	node.draw_line(Vector2(c.x, c.y + r + 2.0), Vector2(c.x, wy - 1.0), UITheme.with_alpha(tint, 0.18 * a), 1.0, true)

	# Sonar ping while it waits to be collected.
	if str(rec["state"]) == "alive" and appear >= 1.0:
		var ping: float = fmod(age + ph, PING_PERIOD) / PING_PERIOD
		node.draw_arc(c, r * (1.05 + 1.25 * _ease_out(ping)), 0.0, TAU, 40, UITheme.with_alpha(tint, (1.0 - ping) * 0.5 * a), 1.5, true)
	# Glow halo (stacked discs read as bloom on the dark map).
	node.draw_circle(c, r * 2.05, UITheme.with_alpha(tint, 0.06 * a))
	node.draw_circle(c, r * 1.55, UITheme.with_alpha(tint, (0.10 + 0.06 * pulse + 0.06 * hover) * a))
	node.draw_circle(c, r * 1.22, UITheme.with_alpha(tint, (0.17 + 0.1 * hover) * a))
	# Glass body: dark core, luminous tinted fill, inner glow, bright double rim.
	node.draw_circle(c, r, Color(tint.r * 0.10, tint.g * 0.14, tint.b * 0.20, 0.9 * a))
	node.draw_circle(c, r * 0.94, UITheme.with_alpha(tint, (0.30 + 0.1 * pulse + 0.12 * hover) * a))
	node.draw_circle(c + Vector2(0.0, r * 0.28), r * 0.58, UITheme.with_alpha(tint.lerp(Color.WHITE, 0.3), 0.14 * a))
	node.draw_arc(c, r, 0.0, TAU, 48, UITheme.with_alpha(tint, 0.35 * a), 6.0, true)
	node.draw_arc(c, r, 0.0, TAU, 48, UITheme.with_alpha(tint.lerp(Color.WHITE, 0.4 + 0.35 * hover), a), 2.5, true)
	node.draw_arc(c, r * 0.72, PI * 1.08, PI * 1.42, 10, UITheme.with_alpha(Color.WHITE, 0.6 * a), 2.0, true)
	node.draw_circle(c + Vector2(-r * 0.36, -r * 0.56), maxf(1.4, r * 0.09), UITheme.with_alpha(Color.WHITE, 0.85 * a))
	# Orbiting data ticks.
	var rot: float = age * 1.1 + ph
	for k in 3:
		var a0: float = rot + float(k) * TAU / 3.0
		node.draw_arc(c, r + 8.0, a0, a0 + 0.55, 6, UITheme.with_alpha(tint, 0.5 * a), 1.5, true)
	# Remaining life (turns red and blinks near expiry).
	var life: float = rec["life"]
	if life < 0.995:
		var lc: Color = tint.lerp(UITheme.CRISIS, urgent)
		node.draw_arc(c, r + 3.5, -PI * 0.5, -PI * 0.5 + TAU * life, 40, UITheme.with_alpha(lc, 0.85 * a), 2.0, true)

	# Hover label on a dark plate: "+N Science" and the click hint.
	if hover > 0.03:
		var font: Font = UITheme.mono_bold_font()
		var small: Font = UITheme.mono_font()
		var line1: String = "+" + _fmt_amount(float(rec["amount"])) + "  " + _res_name(str(rec["kind"]))
		var line2: String = I18n.t("fx.bubble.collect")
		var w1: float = font.get_string_size(line1, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		var w2: float = small.get_string_size(line2, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		var la: float = hover * a
		var box_w: float = maxf(w1, w2) + 20.0
		var box := Rect2(Vector2(roundf(c.x - box_w * 0.5), roundf(c.y - r - 18.0 - 40.0 + 6.0 * (1.0 - hover))), Vector2(roundf(box_w), 40.0))
		node.draw_rect(box, Color(UITheme.DEEP.r, UITheme.DEEP.g, UITheme.DEEP.b, 0.92 * la))
		node.draw_rect(box, UITheme.with_alpha(tint, 0.75 * la), false, 1.0)
		node.draw_line(box.position + Vector2(0.0, box.size.y), box.end, UITheme.with_alpha(tint, la), 2.0)
		_text_centered(node, font, line1, Vector2(c.x, box.position.y + 17.0), 14, UITheme.with_alpha(tint.lerp(Color.WHITE, 0.4), la))
		_text_centered(node, small, line2, Vector2(c.x, box.position.y + 32.0), 11, UITheme.with_alpha(UITheme.TEXT_DIM.lerp(Color.WHITE, 0.3), la))


func _text_centered(ci: CanvasItem, font: Font, text: String, at: Vector2, fs: int, col: Color) -> void:
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var p := Vector2(roundf(at.x - w * 0.5), roundf(at.y))
	ci.draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(UITheme.BG.r, UITheme.BG.g, UITheme.BG.b, 0.85 * col.a))
	ci.draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _draw() -> void:
	for b in _bursts:
		_draw_burst(b)
	for c in _comets:
		_draw_comet(c)
	for a in _arrivals:
		var arr: Dictionary = a
		var t: float = arr["t"]
		var col: Color = arr["col"]
		var p: Vector2 = arr["pos"]
		draw_arc(p, 6.0 + 22.0 * _ease_out(t), 0.0, TAU, 32, UITheme.with_alpha(col.lerp(Color.WHITE, 0.3), 1.0 - t), 2.0, true)
		draw_circle(p, 5.0 * (1.0 - t), UITheme.with_alpha(Color.WHITE, 0.8 * (1.0 - t)))


func _draw_burst(b: Dictionary) -> void:
	var t: float = b["t"]
	var p: Vector2 = b["pos"]
	var col: Color = b["col"]
	var bright: Color = col.lerp(Color.WHITE, 0.45)
	var seed_a: float = b["seed"]
	# Flash.
	if t < 0.28:
		var f: float = t / 0.28
		draw_circle(p, 14.0 + 34.0 * _ease_out(f), UITheme.with_alpha(col, 0.35 * (1.0 - f)))
		draw_circle(p, 10.0 + 18.0 * f, UITheme.with_alpha(Color.WHITE, 0.7 * (1.0 - f)))
	# Shock rings (wide faint glow under a crisp core).
	if t < 0.65:
		var f1: float = t / 0.65
		var rr: float = 20.0 + 64.0 * _ease_out(f1)
		draw_arc(p, rr, 0.0, TAU, 56, UITheme.with_alpha(col, 0.3 * (1.0 - f1)), 10.0 * (1.0 - f1) + 2.0, true)
		draw_arc(p, rr, 0.0, TAU, 56, UITheme.with_alpha(bright, 1.0 - f1), 3.5 - 2.5 * f1, true)
	if t < 0.45:
		var f2: float = t / 0.45
		draw_arc(p, 12.0 + 38.0 * _ease_out(f2), 0.0, TAU, 40, UITheme.with_alpha(Color.WHITE, 0.75 * (1.0 - f2)), 1.5, true)
	# Sparks.
	if t < 0.75:
		var f3: float = t / 0.75
		var dist: float = 18.0 + 56.0 * _ease_out(f3)
		var length: float = 12.0 * (1.0 - f3) + 1.5
		for i in 14:
			var ang: float = seed_a + float(i) * TAU / 14.0 + sin(float(i) * 7.3) * 0.18
			var d := Vector2(cos(ang), sin(ang))
			var dd: float = dist * (0.8 + 0.35 * absf(sin(float(i) * 3.1)))
			var sa: Vector2 = p + d * dd
			draw_line(sa, sa + d * length, UITheme.with_alpha(col, 0.35 * (1.0 - f3)), 5.0, true)
			draw_line(sa, sa + d * length, UITheme.with_alpha(bright, 1.0 - f3), 2.0, true)
	# Floating "+N" and the resource name.
	var rise: float = _ease_out(clampf(t / BURST_TIME, 0.0, 1.0))
	var ta: float = 1.0 if t < 0.65 else clampf(1.0 - (t - 0.65) / (BURST_TIME - 0.65), 0.0, 1.0)
	var pop: float = 1.0 + 0.35 * maxf(0.0, 1.0 - t / 0.18)
	var big: Font = UITheme.mono_bold_font()
	var fs: int = int(roundf(24.0 * pop))
	var ty: float = p.y - 30.0 - 46.0 * rise
	_text_centered(self, big, str(b["text"]), Vector2(p.x, ty), fs, UITheme.with_alpha(bright, ta))
	_text_centered(self, UITheme.mono_font(), str(b["label"]), Vector2(p.x, ty + 16.0), 12, UITheme.with_alpha(col, ta * 0.9))


func _draw_comet(c: Dictionary) -> void:
	var t: float = c["t"]
	var from: Vector2 = c["from"]
	var to: Vector2 = c["to"]
	var col: Color = c["col"]
	var mid: Vector2 = (from + to) * 0.5
	var side: Vector2 = (to - from).orthogonal().normalized() * from.distance_to(to) * 0.22
	var ctrl: Vector2 = mid + side
	var head_t: float = _ease_in_out(t)
	var head: Vector2 = _bezier(from, ctrl, to, head_t)
	# Tapered streak behind the head.
	var steps: int = 16
	var prev: Vector2 = head
	for k in range(1, steps + 1):
		var tk: float = clampf(head_t - float(k) * 0.012, 0.0, 1.0)
		var q: Vector2 = _bezier(from, ctrl, to, tk)
		var fall: float = 1.0 - float(k) / float(steps)
		draw_line(prev, q, UITheme.with_alpha(col, 0.22 * fall), 9.0 * fall + 1.0, true)
		draw_line(prev, q, UITheme.with_alpha(col.lerp(Color.WHITE, 0.5 * fall), 0.95 * fall), 3.0 * fall + 0.6, true)
		prev = q
	draw_circle(head, 10.0, UITheme.with_alpha(col, 0.22))
	draw_circle(head, 3.5, Color.WHITE)


static func _bezier(a: Vector2, ctrl: Vector2, b: Vector2, t: float) -> Vector2:
	return a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t)


# --- Helpers ------------------------------------------------------------------------------------

func _tint(kind: String) -> Color:
	match kind:
		"political":
			return UITheme.BUBBLE_POLITICAL
		"budget":
			return UITheme.AMBER
	return UITheme.BUBBLE_SCIENCE


func _bubble_icon(kind: String) -> String:
	var preferred: String = "bubble_" + kind
	if Icons.IDS.has(preferred):
		return preferred
	return kind if Icons.IDS.has(kind) else "science"


func _res_name(kind: String) -> String:
	var key: String = "hud." + kind
	return I18n.t(key) if I18n.has_key(key) else ""


static func _fmt_amount(v: float) -> String:
	if absf(v - roundf(v)) < 0.05:
		return str(roundi(v))
	return "%.1f" % v


static func _ease_out(t: float) -> float:
	var u: float = 1.0 - clampf(t, 0.0, 1.0)
	return 1.0 - u * u * u


static func _ease_in_out(t: float) -> float:
	var x: float = clampf(t, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


static func _back_ease(t: float) -> float:
	var x: float = clampf(t, 0.0, 1.0)
	var c1: float = 1.70158
	var c3: float = c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)
