extends Control
## NewsTicker: the localized scrolling marquee in the HUD's 32 px top strip. Headlines come
## from EventBus.news and from ambient items generated out of live state (region stats and
## trends, basin indicators, tips, real Mediterranean facts). Items are kept as key + args and
## re-rendered on language_changed; tone (-1 alarming, 0 neutral, 1 hopeful) colors them.

const UITheme := preload("res://scripts/ui_theme.gd")
const Icons := preload("res://scripts/icons.gd")
const TechTree := preload("res://scripts/tech_tree.gd")

const SPEED := 92.0             # scroll speed, px per second
const GAP := 46.0               # space between two headlines (the separator sits in it)
const FONT_SIZE := 14
const CHIP_FONT_SIZE := 10
const TAG_FONT_SIZE := 12
const CHIP_PAD := 7.0
const SLANT := 14.0
const EDGE_FADE := 40.0
const QUEUE_MAX := 6
const TICKS_PER_YEAR := 50      # 1000 ticks over 2026-2046 (trend window for ambient items)
const RECENT_MAX := 9

## Ambient rotation: guarantees a mix of alarming, hopeful, basin-wide, tip and fact items.
const AMBIENT_CYCLE := ["alarm", "tip", "hope", "global", "fact", "alarm", "hope", "global", "tip", "fact"]
const TIP_KEYS := ["news.tip.bubbles", "news.tip.tree", "news.tip.keys", "news.tip.pause", "news.tip.diversify"]
const FACT_KEYS := [
	"news.fact.biodiversity", "news.fact.warming", "news.fact.plastic", "news.fact.posidonia",
	"news.fact.posidonia_loss", "news.fact.caretta", "news.fact.monk_seal", "news.fact.lionfish",
	"news.fact.mucilage", "news.fact.overfishing", "news.fact.renewal", "news.fact.barcelona",
	"news.fact.cop31",
]
const CHIP_KEYS := {"breaking": "news.chip.breaking", "good": "news.chip.good", "fact": "news.chip.fact", "tip": "news.chip.tip"}

var _queue: Array = []          # waiting: {"key", "args", "tone", "chip"}
var _items: Array = []          # on the strip: queue fields + "text", "chip_text", "text_w", "chip_w", "w", "x"
var _scroller: Control
var _overlay: Control
var _icon: Icons
var _tag_text: String = ""
var _tag_w: float = 160.0
var _time: float = 0.0
var _alarm_flash: float = 0.0
var _rng := RandomNumberGenerator.new()
var _cycle: int = 0
var _since_ambient: int = 0     # simulation headlines shown since the last ambient one
var _facts: Array = []          # shuffled deck of fact keys
var _tips_left: Array = []
var _recent: Array = []         # signatures of recent ambient items (no quick repeats)
var _snap: Dictionary = {}
var _sample_tick: int = -100000
var _crisis_prev: Dictionary = {}   # region id -> crisis about 1-2 years ago
var _crisis_cur: Dictionary = {}
var _health_prev: float = -1.0
var _health_cur: float = -1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rng.randomize()

	_scroller = Control.new()
	_scroller.name = "Scroller"
	_scroller.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroller.clip_contents = true
	_scroller.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroller.draw.connect(_draw_items)
	add_child(_scroller)

	_overlay = Control.new()
	_overlay.name = "Overlay"
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)

	_icon = Icons.new()
	_icon.setup(_icon_id("news", "globe"), UITheme.AMBER, 16.0)
	_icon.size = Vector2(16.0, 16.0)
	_overlay.add_child(_icon)

	EventBus.news.connect(_on_news)
	EventBus.tick_done.connect(_on_tick_done)
	EventBus.game_started.connect(clear)
	EventBus.language_changed.connect(_on_language_changed)
	resized.connect(_layout_tag)
	_refresh_tag()
	clear()


## Drops all queued headlines and restarts the strip with the welcome line (new game).
func clear() -> void:
	_queue.clear()
	_items.clear()
	_recent.clear()
	_cycle = 0
	_since_ambient = 0
	_facts = FACT_KEYS.duplicate()
	_facts.shuffle()
	_tips_left = TIP_KEYS.duplicate()
	_snap = {}
	_sample_tick = -100000
	_crisis_prev = {}
	_crisis_cur = {}
	_health_prev = -1.0
	_health_cur = -1.0
	_alarm_flash = 0.0
	_spawn({"key": "news.welcome", "args": {}, "tone": 1, "chip": ""}, GAP)
	if _scroller != null:
		_scroller.queue_redraw()


# --- Feeding --------------------------------------------------------------------------

func _on_news(text_key: String, args: Dictionary, tone: int) -> void:
	if not I18n.has_key(text_key):
		return   # never scroll a raw key past the player (string table not filled yet)
	var t: int = clampi(tone, -1, 1)
	var chip: String = ""
	if t < 0:
		chip = "breaking"
		_alarm_flash = 1.0
	elif t > 0:
		chip = "good"
	for q in _queue:
		var queued: Dictionary = q
		if str(queued["key"]) == text_key and queued["args"] == args:
			return   # the same headline is already waiting
	_queue.append({"key": text_key, "args": args.duplicate(), "tone": t, "chip": chip})
	while _queue.size() > QUEUE_MAX:
		_queue.remove_at(0)


func _on_tick_done(snapshot: Dictionary) -> void:
	_snap = snapshot
	var tick: int = int(snapshot.get("tick", 0))
	if tick < _sample_tick:
		_sample_tick = -100000   # a new game restarted the clock
	if tick - _sample_tick < TICKS_PER_YEAR:
		return
	_sample_tick = tick
	_crisis_prev = _crisis_cur.duplicate()
	_health_prev = _health_cur
	_crisis_cur = {}
	for rid in GameState.region_ids():
		var region_id: String = rid
		var r: Dictionary = GameState.get_region(region_id)
		if not r.is_empty():
			_crisis_cur[region_id] = float(r.get("crisis", 0.0))
	_health_cur = float(snapshot.get("sea_health", 0.0))


## Simulation headlines first, but every third slot stays ambient so facts and tips keep
## flowing even while the simulation reports a lot.
func _next_item() -> Dictionary:
	if not _queue.is_empty() and _since_ambient < 2:
		_since_ambient += 1
		var q: Dictionary = _queue.pop_front()
		return q
	_since_ambient = 0
	return _ambient()


func _spawn(item: Dictionary, x: float) -> void:
	var it: Dictionary = item.duplicate()
	it["x"] = x
	_measure(it)
	_items.append(it)


## Renders the item's text in the current language and measures it.
func _measure(it: Dictionary) -> void:
	var font: Font = UITheme.mono_font()
	var chip_font: Font = UITheme.header_font()
	var text: String = _render(str(it.get("key", "")), it.get("args", {}))
	var tw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	var chip: String = str(it.get("chip", ""))
	var chip_text: String = ""
	var cw: float = 0.0
	if CHIP_KEYS.has(chip):
		chip_text = I18n.t(str(CHIP_KEYS[chip]))
		cw = chip_font.get_string_size(chip_text, HORIZONTAL_ALIGNMENT_LEFT, -1, CHIP_FONT_SIZE).x + CHIP_PAD * 2.0
	it["text"] = text
	it["text_w"] = tw
	it["chip_text"] = chip_text
	it["chip_w"] = cw
	it["w"] = tw + (cw + 10.0 if cw > 0.0 else 0.0)


## Toast convention: arg values that are i18n keys (region names...) are translated here.
func _render(text_key: String, args: Dictionary) -> String:
	var shown: Dictionary = {}
	for k in args.keys():
		var v: Variant = args[k]
		if v is String and I18n.has_key(str(v)):
			shown[k] = I18n.t(str(v))
		else:
			shown[k] = v
	return I18n.t(text_key, shown)


# --- Ambient headlines ------------------------------------------------------------------

func _ambient() -> Dictionary:
	if not GameState.running or _snap.is_empty():
		return _fact_item()
	for _attempt in AMBIENT_CYCLE.size():
		var cat: String = AMBIENT_CYCLE[_cycle % AMBIENT_CYCLE.size()]
		_cycle += 1
		var item: Dictionary = {}
		match cat:
			"alarm":
				item = _region_item(false)
			"hope":
				item = _region_item(true)
			"global":
				item = _global_item()
			"tip":
				item = _tip_item()
			"fact":
				item = _fact_item()
		if not item.is_empty():
			return item
	return _fact_item()


## Adds a region headline candidate [score, key, region name key, value] when ok.
func _cand(list: Array, ok: bool, score: float, key: String, name_key: String, value: float) -> void:
	if ok:
		list.append([score, key, name_key, value])


func _region_item(hopeful: bool) -> Dictionary:
	var cands: Array = []
	for rid in GameState.region_ids():
		var region_id: String = rid
		var r: Dictionary = GameState.get_region(region_id)
		if r.is_empty():
			continue
		var nk: String = str(r.get("name_key", ""))
		var crisis: float = float(r.get("crisis", 0.0))
		var pollution: float = float(r.get("pollution", 0.0))
		var coral: float = float(r.get("coral_health", 0.0))
		var seagrass: float = float(r.get("seagrass", 0.0))
		var fish: float = float(r.get("fish_stock", 0.0))
		var protection: float = float(r.get("protection", 0.0))
		var awareness: float = float(r.get("awareness", 0.0))
		var trend: float = 0.0
		if _crisis_prev.has(region_id):
			trend = crisis - float(_crisis_prev[region_id])
		if hopeful:
			_cand(cands, crisis <= 35.0, 45.0 - crisis, "news.amb.clean", nk, crisis)
			_cand(cands, seagrass >= 60.0, seagrass - 45.0, "news.amb.seagrass_good", nk, seagrass)
			_cand(cands, fish >= 55.0, fish - 40.0, "news.amb.fish_good", nk, fish)
			_cand(cands, coral >= 62.0, coral - 45.0, "news.amb.coral_good", nk, coral)
			_cand(cands, protection >= 40.0, protection - 20.0, "news.amb.protected", nk, protection)
			_cand(cands, awareness >= 40.0, awareness - 20.0, "news.amb.aware", nk, awareness)
			_cand(cands, trend <= -3.0, 30.0 - trend * 4.0, "news.amb.improving", nk, crisis)
		else:
			_cand(cands, str(r.get("status", "")) == "collapsed", 100.0 + crisis, "news.amb.collapse", nk, crisis)
			_cand(cands, pollution >= 55.0, pollution, "news.amb.pollution", nk, pollution)
			_cand(cands, coral <= 42.0, 100.0 - coral, "news.amb.coral", nk, coral)
			_cand(cands, seagrass <= 42.0, 100.0 - seagrass, "news.amb.seagrass", nk, seagrass)
			_cand(cands, fish <= 36.0, 100.0 - fish, "news.amb.fish", nk, fish)
			_cand(cands, trend >= 3.0, 60.0 + trend * 4.0, "news.amb.worsening", nk, crisis)
	if cands.is_empty():
		return {}
	cands.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	var top: int = mini(4, cands.size())
	var start: int = _rng.randi_range(0, top - 1)
	for i in top:
		var c: Array = cands[(start + i) % top]
		var sig: String = str(c[1]) + "|" + str(c[2])
		if _recent.has(sig):
			continue
		_remember(sig)
		var args: Dictionary = {"region": str(c[2]), "v": str(roundi(float(c[3])))}
		return {"key": str(c[1]), "args": args, "tone": 1 if hopeful else -1, "chip": ""}
	return {}


func _global_item() -> Dictionary:
	var cands: Array = []   # [key, args, tone]
	var sh: float = float(_snap.get("sea_health", 0.0))
	var temp: float = float(_snap.get("temperature", 1.5))
	if _snap.has("budget_rate") and float(_snap["budget_rate"]) < 0.0:
		cands.append(["news.amb.income_negative", {}, -1])
	var active: Array = GameState.active_evolutions()
	if not active.is_empty():
		var evo_id: String = str(active[_rng.randi_range(0, active.size() - 1)])
		var def: Dictionary = TechTree.evolution_def(evo_id)
		var nk: String = str(def.get("name_key", ""))
		if nk != "" and I18n.has_key(nk):
			cands.append(["news.amb.resistance", {"name": nk}, -1])
	if _health_prev >= 0.0:
		var d: float = sh - _health_prev
		if d >= 1.0:
			cands.append(["news.amb.health_up", {"v": str(roundi(sh))}, 1])
		elif d <= -1.0:
			cands.append(["news.amb.health_down", {"v": str(roundi(sh))}, -1])
	if temp >= 2.5:
		cands.append(["news.amb.temp_high", {"v": "%.1f" % temp}, -1])
	else:
		cands.append(["news.amb.temp", {"v": "%.1f" % temp}, 0])
	if sh >= 50.0:
		cands.append(["news.amb.goal_near", {"v": str(roundi(sh))}, 1])
	else:
		cands.append(["news.amb.goal", {"n": str(int(_snap.get("years_left", 20)))}, 0])
	var spreads: int = int(_snap.get("spreads", 0))
	if spreads >= 5:
		cands.append(["news.amb.spreads", {"n": str(spreads)}, -1])
	var adopted: int = GameState.adopted_nodes().size()
	if adopted > 0:
		cands.append(["news.amb.policies", {"n": str(adopted)}, 1])
	var fresh: Array = []
	for c in cands:
		var entry: Array = c
		if not _recent.has(str(entry[0])):
			fresh.append(entry)
	if fresh.is_empty():
		return {}
	var pick: Array = fresh[0]
	if str(pick[0]) != "news.amb.income_negative":
		pick = fresh[_rng.randi_range(0, fresh.size() - 1)]
	_remember(str(pick[0]))
	var args: Dictionary = pick[1]
	return {"key": str(pick[0]), "args": args, "tone": int(pick[2]), "chip": ""}


func _tip_item() -> Dictionary:
	if _tips_left.is_empty():
		return {}
	var key: String = str(_tips_left.pop_front())
	return {"key": key, "args": {}, "tone": 0, "chip": "tip"}


func _fact_item() -> Dictionary:
	if _facts.is_empty():
		_facts = FACT_KEYS.duplicate()
		_facts.shuffle()
	var key: String = str(_facts.pop_back())
	return {"key": key, "args": {}, "tone": 0, "chip": "fact"}


func _remember(sig: String) -> void:
	_recent.append(sig)
	while _recent.size() > RECENT_MAX:
		_recent.remove_at(0)


# --- Scrolling ----------------------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	if not is_visible_in_tree():
		return
	_alarm_flash = maxf(0.0, _alarm_flash - delta * 0.7)
	var move: float = SPEED * delta
	for it in _items:
		var d: Dictionary = it
		d["x"] = float(d["x"]) - move
	while not _items.is_empty():
		var first: Dictionary = _items[0]
		if float(first["x"]) + float(first["w"]) < -GAP:
			_items.remove_at(0)
		else:
			break
	var sw: float = _scroller.size.x
	if sw > 40.0:
		for _guard in 4:
			var next_x: float = sw + GAP * 0.5
			if not _items.is_empty():
				var last: Dictionary = _items[_items.size() - 1]
				var end_x: float = float(last["x"]) + float(last["w"]) + GAP
				if end_x > sw:
					break
				next_x = maxf(end_x, sw * 0.25)
			_spawn(_next_item(), next_x)
	_scroller.queue_redraw()
	_overlay.queue_redraw()


func _on_language_changed(_lang: String) -> void:
	_refresh_tag()
	var x: float = GAP
	if not _items.is_empty():
		var first: Dictionary = _items[0]
		x = float(first["x"])
	for it in _items:
		var d: Dictionary = it
		_measure(d)
		d["x"] = x
		x += float(d["w"]) + GAP
	_scroller.queue_redraw()
	_overlay.queue_redraw()


func _refresh_tag() -> void:
	_tag_text = I18n.t("news.tag")
	var tw: float = UITheme.header_font().get_string_size(_tag_text, HORIZONTAL_ALIGNMENT_LEFT, -1, TAG_FONT_SIZE).x
	_tag_w = 12.0 + 16.0 + 8.0 + tw + 12.0 + 7.0 + 8.0 + SLANT
	_layout_tag()


func _layout_tag() -> void:
	if _scroller == null:
		return
	_scroller.offset_left = _tag_w - SLANT
	_scroller.offset_bottom = -1.0
	_icon.position = Vector2(12.0, floorf((size.y - 1.0 - 16.0) * 0.5))


# --- Drawing --------------------------------------------------------------------------------

func _chip_color(chip: String) -> Color:
	match chip:
		"breaking":
			return UITheme.CRISIS
		"good":
			return UITheme.HEALTHY
		"fact":
			return UITheme.SCIENCE_BLUE
		"tip":
			return UITheme.WARNING
	return UITheme.AMBER


func _text_color(tone: int) -> Color:
	if tone < 0:
		return UITheme.TEXT.lerp(UITheme.CRISIS, 0.32)
	if tone > 0:
		return UITheme.TEXT.lerp(UITheme.HEALTHY, 0.28)
	return UITheme.TEXT


func _draw_items() -> void:
	var font: Font = UITheme.mono_font()
	var chip_font: Font = UITheme.header_font()
	var w: float = _scroller.size.x
	var h: float = _scroller.size.y
	var cy: float = h * 0.5
	var asc: float = font.get_ascent(FONT_SIZE)
	var desc: float = font.get_descent(FONT_SIZE)
	var base_y: float = roundf((h - (asc + desc)) * 0.5 + asc)
	var c_asc: float = chip_font.get_ascent(CHIP_FONT_SIZE)
	var c_desc: float = chip_font.get_descent(CHIP_FONT_SIZE)
	var chip_base: float = roundf((h - (c_asc + c_desc)) * 0.5 + c_asc)
	var blink: float = 0.5 + 0.5 * sin(_time * 7.0)
	for it in _items:
		var d: Dictionary = it
		var x: float = float(d["x"])
		var iw: float = float(d["w"])
		if x - GAP > w or x + iw < -GAP:
			continue
		var tone: int = int(d["tone"])
		var tc: Color = UITheme.tone_color(tone)
		_draw_separator(Vector2(x - GAP * 0.5, cy), tc, tone)
		var tx: float = x
		var cw: float = float(d["chip_w"])
		if cw > 0.0:
			var chip: String = str(d["chip"])
			var cc: Color = _chip_color(chip)
			var fill_a: float = 0.16
			if chip == "breaking":
				fill_a = 0.18 + 0.22 * blink
			var r := Rect2(Vector2(x, cy - 8.0), Vector2(cw, 16.0))
			_scroller.draw_rect(r, UITheme.with_alpha(cc, fill_a))
			_scroller.draw_rect(r, UITheme.with_alpha(cc, 0.85), false, 1.0)
			_scroller.draw_string(chip_font, Vector2(x + CHIP_PAD, chip_base), str(d["chip_text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, CHIP_FONT_SIZE, cc.lerp(Color.WHITE, 0.35))
			tx += cw + 10.0
		_scroller.draw_string(font, Vector2(tx, base_y), str(d["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, _text_color(tone))


## Diamond separator in the gap before a headline, tinted by its tone.
func _draw_separator(c: Vector2, col: Color, tone: int) -> void:
	var pulse: float = 0.5 + 0.5 * sin(_time * 4.0 + c.x * 0.01)
	var halo_a: float = 0.12 + (0.18 * pulse if tone < 0 else 0.06)
	_scroller.draw_circle(c, 7.0, UITheme.with_alpha(col, halo_a))
	var s: float = 4.0
	var pts := PackedVector2Array([c + Vector2(0.0, -s), c + Vector2(s, 0.0), c + Vector2(0.0, s), c + Vector2(-s, 0.0)])
	_scroller.draw_colored_polygon(pts, col)
	_scroller.draw_line(c + Vector2(-16.0, 0.0), c + Vector2(-9.0, 0.0), UITheme.with_alpha(col, 0.45), 1.0, true)
	_scroller.draw_line(c + Vector2(9.0, 0.0), c + Vector2(16.0, 0.0), UITheme.with_alpha(col, 0.45), 1.0, true)


func _draw_overlay() -> void:
	var h: float = size.y - 1.0
	var w: float = size.x
	if h < 4.0 or w < 40.0:
		return
	var deep: Color = UITheme.with_alpha(UITheme.DEEP, 0.95)
	var none: Color = UITheme.with_alpha(UITheme.DEEP, 0.0)
	# Edge fades so headlines dissolve instead of being cut.
	var lx: float = _tag_w - SLANT
	_overlay.draw_primitive(PackedVector2Array([Vector2(lx, 0.0), Vector2(lx + EDGE_FADE, 0.0), Vector2(lx + EDGE_FADE, h), Vector2(lx, h)]),
		PackedColorArray([deep, none, none, deep]), PackedVector2Array())
	_overlay.draw_primitive(PackedVector2Array([Vector2(w - EDGE_FADE, 0.0), Vector2(w, 0.0), Vector2(w, h), Vector2(w - EDGE_FADE, h)]),
		PackedColorArray([none, deep, deep, none]), PackedVector2Array())
	# Tag block with a slanted right edge; flashes red on alarming news.
	var accent: Color = UITheme.AMBER.lerp(UITheme.CRISIS, _alarm_flash * (0.6 + 0.4 * sin(_time * 12.0)))
	var fill: Color = UITheme.BG_PANEL.lerp(accent, 0.17)
	var body := PackedVector2Array([Vector2(0.0, 0.0), Vector2(_tag_w, 0.0), Vector2(_tag_w - SLANT, h), Vector2(0.0, h)])
	_overlay.draw_colored_polygon(body, fill)
	_overlay.draw_line(Vector2(_tag_w, 0.0), Vector2(_tag_w - SLANT, h), UITheme.with_alpha(accent, 0.25), 5.0, true)
	_overlay.draw_line(Vector2(_tag_w, 0.0), Vector2(_tag_w - SLANT, h), accent, 1.5, true)
	_overlay.draw_line(Vector2(0.0, h - 0.5), Vector2(_tag_w - SLANT, h - 0.5), UITheme.with_alpha(accent, 0.9), 1.0)
	var font: Font = UITheme.header_font()
	var asc: float = font.get_ascent(TAG_FONT_SIZE)
	var desc: float = font.get_descent(TAG_FONT_SIZE)
	var base_y: float = roundf((h - (asc + desc)) * 0.5 + asc)
	_overlay.draw_string(font, Vector2(36.0, base_y), _tag_text, HORIZONTAL_ALIGNMENT_LEFT, -1, TAG_FONT_SIZE, accent.lerp(Color.WHITE, 0.25))
	# Live dot.
	var dot := Vector2(_tag_w - SLANT - 13.0, h * 0.5)
	var pulse: float = 0.5 + 0.5 * sin(_time * 5.0)
	_overlay.draw_circle(dot, 6.0, UITheme.with_alpha(UITheme.CRISIS, 0.14 + 0.2 * pulse))
	_overlay.draw_circle(dot, 3.0, UITheme.CRISIS.lerp(Color.WHITE, 0.25 * pulse))


func _icon_id(preferred: String, fallback: String) -> String:
	return preferred if Icons.IDS.has(preferred) else fallback
