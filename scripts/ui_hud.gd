extends Control
## UIHud: in-game HUD built in code - ticker strip reserve, top bar (year, timeline, speed,
## resources), BASIN STATUS panel (bars + temperature gauge), REGION panel (status, six
## stats, FIELD OPERATIONS), toast feed and a themed hover tip. Driven only by EventBus.

const UITheme := preload("res://scripts/ui_theme.gd")
const Icons := preload("res://scripts/icons.gd")
const Charts := preload("res://scripts/charts.gd")

const TICKER_H := 32.0
const TOP_H := 60.0
const MARGIN := 16.0
const LEFT_W := 340.0
const RIGHT_W := 404.0
const PANEL_Y := 106.0
const TOAST_W := 340.0
const MAX_TOASTS := 4
const TOAST_LIFE := 7.0

const RES_ORDER := ["budget", "political", "science"]
const RES_KEYS := {"budget": "hud.budget", "political": "hud.political", "science": "hud.science"}
const RES_COLORS := {
	"budget": Color(0.9098, 0.6392, 0.2392),
	"political": Color(0.95, 0.50, 0.36),
	"science": Color(0.42, 0.78, 1.0),
}
const AWARE_COLOR := Color(0.42, 0.78, 1.0)
const SPEED_ICONS := ["pause", "play", "fast", "faster"]
const SPEED_TEXT := ["", "1x", "2x", "4x"]
const SPEED_KEYS := ["hud.speed.pause", "hud.speed.x1", "hud.speed.x2", "hud.speed.x4"]
## Region stat rows: [data key, i18n key, icon, bar mode]
const STAT_ROWS := [
	["pollution", "hud.region.pollution", "pollution", "inverse"],
	["coral_health", "hud.region.coral", "coral", "health"],
	["seagrass", "hud.region.seagrass", "seagrass", "health"],
	["fish_stock", "hud.region.fish", "fish", "health"],
	["awareness", "hud.region.awareness", "awareness", "aware"],
	["protection", "hud.region.protection", "protection", "protect"],
]

var _tr_labels: Array = []          # [[Label, key], ...] re-rendered on language_changed
var _snap: Dictionary = {}
var _selected: String = ""
var _region: Dictionary = {}
var _region_status: String = ""
var _is_shown: bool = false
var _anim: Tween = null
var _time: float = 0.0

# Layout roots
var _ticker_strip: Control
var _top_bar: PanelContainer
var _left_panel: PanelContainer
var _right_panel: PanelContainer
var _toast_box: VBoxContainer
var _tip_panel: PanelContainer
var _tip_title: Label
var _tip_body: Label
var _tip_meta: Label
var _tip_owner: Control = null
var _tip_tween: Tween = null
var _tip_side: String = "left"

# Top bar
var _pulse: Charts
var _year_label: Label
var _years_left_label: Label
var _timeline: Charts
var _speed_buttons: Array = []
var _paused_chip: PanelContainer
var _res_labels: Dictionary = {}    # key -> value Label
var _res_shown: Dictionary = {}
var _res_target: Dictionary = {}

# Basin panel
var _sea_bar: Charts
var _crisis_bar: Charts
var _aware_bar: Charts
var _gauge: Charts
var _live_dot: Icons

# Region panel
var _right_bracket_color: Color = UITheme.TEXT_DIM
var _hint_box: HBoxContainer
var _hint_icon: Icons
var _details: VBoxContainer
var _region_name: Label
var _badge: PanelContainer
var _badge_label: Label
var _region_crisis_bar: Charts
var _stat_bars: Dictionary = {}     # data key -> Charts
var _coastal_value: Label
var _action_rows: Array = []        # Dictionary per action

# Toasts: Dictionary {root, label, key, args}
var _toasts: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UITheme.build_theme()
	_build_ticker_strip()
	_build_top_bar()
	_build_left_panel()
	_build_right_panel()
	_build_toasts()
	_build_tip()
	visible = false

	EventBus.game_started.connect(_on_game_started)
	EventBus.tick_done.connect(_on_tick_done)
	EventBus.region_changed.connect(_on_region_changed)
	EventBus.resources_changed.connect(_on_resources_changed)
	EventBus.region_selected.connect(_on_region_selected)
	EventBus.speed_changed.connect(_on_speed_changed)
	EventBus.paused_changed.connect(_on_paused_changed)
	EventBus.toast.connect(_on_toast)
	EventBus.action_performed.connect(_on_action_performed)
	EventBus.language_changed.connect(_on_language_changed)

	_select_region(GameState.selected_region)
	_on_speed_changed(GameState.speed_index)


# --- Small builders ------------------------------------------------------------------

func _label(variation: String, key: String = "") -> Label:
	var l := Label.new()
	l.theme_type_variation = StringName(variation)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if key != "":
		_tr(l, key)
	return l


func _tr(l: Label, key: String) -> void:
	_tr_labels.append([l, key])
	l.text = I18n.t(key)


func _icon(id: String, col: Color, px: float) -> Icons:
	var ic: Icons = Icons.new()
	ic.setup(id, col, px)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return ic


func _hbox(sep: int = 8) -> HBoxContainer:
	var b := HBoxContainer.new()
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_theme_constant_override("separation", sep)
	return b


func _vbox(sep: int = 6) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_theme_constant_override("separation", sep)
	return b


func _vline(h: float) -> ColorRect:
	var r := ColorRect.new()
	r.color = UITheme.LINE
	r.custom_minimum_size = Vector2(1.0, h)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _panel(variation: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = StringName(variation)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	return p


func _sep() -> HSeparator:
	var s := HSeparator.new()
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


func _ellipsis(l: Label) -> void:
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.clip_text = true
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _wire_button(btn: BaseButton) -> void:
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_entered.connect(_on_btn_hover.bind(btn, true))
	btn.mouse_exited.connect(_on_btn_hover.bind(btn, false))
	btn.button_down.connect(_on_btn_down.bind(btn))


func _on_btn_hover(btn: BaseButton, on: bool) -> void:
	UITheme.hover_fx(btn, on)


func _on_btn_down(btn: BaseButton) -> void:
	if not btn.disabled:
		UITheme.press_fx(btn)


# --- Ticker strip (reserved for the Phase 2 news ticker) -------------------------------

func _build_ticker_strip() -> void:
	_ticker_strip = Control.new()
	_ticker_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ticker_strip.position = Vector2.ZERO
	_ticker_strip.size = Vector2(1920.0, TICKER_H)
	_ticker_strip.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_ticker_strip.offset_bottom = TICKER_H
	_ticker_strip.draw.connect(_draw_ticker_strip)
	add_child(_ticker_strip)


func _draw_ticker_strip() -> void:
	var w: float = _ticker_strip.size.x
	var h: float = _ticker_strip.size.y
	_ticker_strip.draw_rect(Rect2(0.0, 0.0, w, h), UITheme.with_alpha(UITheme.DEEP, 0.92))
	_ticker_strip.draw_line(Vector2(0.0, h - 0.5), Vector2(w, h - 0.5), UITheme.with_alpha(UITheme.AMBER, 0.35), 1.0)
	var step: float = 24.0
	var i: int = 0
	var x: float = 0.0
	while x < w:
		var th: float = 5.0 if i % 8 == 0 else 2.0
		_ticker_strip.draw_line(Vector2(x, h - 1.0 - th), Vector2(x, h - 1.0), UITheme.with_alpha(UITheme.TEXT_DIM, 0.25), 1.0)
		x += step
		i += 1
	var sweep: float = fmod(_time * 220.0, w + 600.0) - 300.0
	var c0: Color = UITheme.with_alpha(UITheme.HEALTHY, 0.0)
	var c1: Color = UITheme.with_alpha(UITheme.HEALTHY, 0.045)
	var pts := PackedVector2Array([Vector2(sweep - 260.0, 0.0), Vector2(sweep, 0.0), Vector2(sweep, h - 1.0), Vector2(sweep - 260.0, h - 1.0)])
	_ticker_strip.draw_polygon(pts, PackedColorArray([c0, c1, c1, c0]))
	_ticker_strip.draw_line(Vector2(sweep, 0.0), Vector2(sweep, h - 1.0), UITheme.with_alpha(UITheme.HEALTHY, 0.12), 1.0)


# --- Top bar ---------------------------------------------------------------------------

func _build_top_bar() -> void:
	_top_bar = _panel("TopBar")
	_top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_top_bar.offset_top = TICKER_H
	_top_bar.offset_bottom = TICKER_H + TOP_H
	add_child(_top_bar)
	var row := _hbox(16)
	_top_bar.add_child(row)

	# Brand: ECG pulse + title.
	var brand := _hbox(10)
	brand.custom_minimum_size = Vector2(280.0, 0.0)
	row.add_child(brand)
	_pulse = Charts.new()
	_pulse.setup_pulse(Vector2(84.0, 36.0))
	_pulse.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	brand.add_child(_pulse)
	var brand_text := _vbox(0)
	brand_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brand_text.alignment = BoxContainer.ALIGNMENT_CENTER
	brand.add_child(brand_text)
	var title := _label("HeaderLabel", "game.title")
	title.add_theme_font_size_override("font_size", 13)
	_ellipsis(title)
	brand_text.add_child(title)
	var sub := _label("DimLabel", "game.subtitle")
	sub.add_theme_font_size_override("font_size", 11)
	_ellipsis(sub)
	brand_text.add_child(sub)
	row.add_child(_vline(40.0))

	# Year block.
	var year_box := _vbox(0)
	year_box.custom_minimum_size = Vector2(170.0, 0.0)
	year_box.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(year_box)
	_year_label = _label("BigValueLabel")
	_year_label.add_theme_font_size_override("font_size", 22)
	_ellipsis(_year_label)
	year_box.add_child(_year_label)
	_years_left_label = _label("DimLabel")
	_ellipsis(_years_left_label)
	year_box.add_child(_years_left_label)

	_timeline = Charts.new()
	_timeline.setup_timeline(44.0)
	_timeline.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_timeline)
	row.add_child(_vline(40.0))

	# Speed controls.
	var speed_row := _hbox(6)
	row.add_child(speed_row)
	for i in 4:
		var btn := Button.new()
		btn.theme_type_variation = &"SpeedButton"
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(58.0, 38.0)
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_wire_button(btn)
		btn.mouse_entered.connect(_on_speed_hover.bind(btn, i))
		btn.mouse_exited.connect(_hide_tip.bind(btn))
		btn.pressed.connect(_on_speed_pressed.bind(i))
		var inner := _hbox(4)
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		btn.add_child(inner)
		var px: float = 16.0 if i == 0 else 14.0
		inner.add_child(_icon(SPEED_ICONS[i], UITheme.TEXT, px))
		var txt: String = SPEED_TEXT[i]
		if txt != "":
			var l := _label("SmallLabel")
			l.text = txt
			l.add_theme_font_size_override("font_size", 13)
			l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			inner.add_child(l)
		speed_row.add_child(btn)
		_speed_buttons.append(btn)
	_paused_chip = PanelContainer.new()
	_paused_chip.theme_type_variation = &"BadgePanel"
	_paused_chip.add_theme_stylebox_override("panel", UITheme.badge_box(UITheme.WARNING))
	_paused_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paused_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pl := _label("BadgeLabel", "ui.pause.title")
	pl.add_theme_color_override("font_color", UITheme.WARNING)
	_paused_chip.add_child(pl)
	_paused_chip.visible = false
	speed_row.add_child(_paused_chip)
	row.add_child(_vline(40.0))

	# Resources.
	for k in RES_ORDER:
		var key: String = k
		var col: Color = RES_COLORS[key]
		var block := _hbox(8)
		block.custom_minimum_size = Vector2(176.0, 0.0)
		row.add_child(block)
		block.add_child(_icon(key, col, 28.0))
		var col_box := _vbox(0)
		col_box.alignment = BoxContainer.ALIGNMENT_CENTER
		col_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		block.add_child(col_box)
		var v := _label("ValueLabel")
		v.add_theme_color_override("font_color", col.lerp(Color.WHITE, 0.25))
		v.text = "0"
		col_box.add_child(v)
		var n := _label("DimLabel", RES_KEYS[key])
		n.add_theme_font_size_override("font_size", 11)
		_ellipsis(n)
		col_box.add_child(n)
		_res_labels[key] = v
		_res_shown[key] = 0.0
		_res_target[key] = 0.0


# --- Basin status (left) ----------------------------------------------------------------

func _build_left_panel() -> void:
	_left_panel = _panel("HudPanel")
	_left_panel.position = Vector2(MARGIN, PANEL_Y)
	_left_panel.custom_minimum_size = Vector2(LEFT_W, 0.0)
	_left_panel.size = Vector2(LEFT_W, 0.0)
	_left_panel.draw.connect(_on_left_panel_draw)
	add_child(_left_panel)
	var col := _vbox(8)
	_left_panel.add_child(col)

	var head := _hbox(8)
	col.add_child(head)
	head.add_child(_icon("sea_health", UITheme.AMBER, 18.0))
	var title := _label("HeaderLabel", "hud.global_title")
	_ellipsis(title)
	head.add_child(title)
	_live_dot = _icon("target", UITheme.HEALTHY, 12.0)
	head.add_child(_live_dot)
	col.add_child(_sep())

	_sea_bar = _stat_block(col, "sea_health", "hud.sea_health", "health", UITheme.HEALTHY, 12.0)
	_sea_bar.markers = [60.0]
	_crisis_bar = _stat_block(col, "crisis", "hud.crisis", "inverse", UITheme.CRISIS, 12.0)
	_aware_bar = _stat_block(col, "awareness", "hud.awareness", "fixed", AWARE_COLOR, 12.0)
	col.add_child(_sep())

	var th := _hbox(8)
	col.add_child(th)
	th.add_child(_icon("temperature", UITheme.WARNING, 18.0))
	var tl := _label("SmallLabel", "hud.temperature")
	_ellipsis(tl)
	th.add_child(tl)
	var inset := _panel("InsetPanel")
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(inset)
	_gauge = Charts.new()
	_gauge.setup_gauge(Vector2(280.0, 176.0))
	inset.add_child(_gauge)
	_gauge.set_value(1.5, true)

	var limit := _hbox(8)
	col.add_child(limit)
	limit.add_child(_icon("warning", UITheme.CRISIS, 14.0))
	var ll := _label("DimLabel", "hud.temp_limit")
	ll.add_theme_color_override("font_color", UITheme.with_alpha(UITheme.CRISIS, 0.85))
	_ellipsis(ll)
	limit.add_child(ll)

	var goal := _hbox(8)
	col.add_child(goal)
	goal.add_child(_icon("target", UITheme.AMBER, 16.0))
	var gl := _label("SmallLabel", "hud.goal")
	gl.add_theme_color_override("font_color", UITheme.AMBER.lerp(UITheme.TEXT, 0.35))
	gl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gl.custom_minimum_size = Vector2(200.0, 0.0)
	goal.add_child(gl)


## Icon + name + tick-up value, then a segmented bar. Returns the bar.
func _stat_block(parent: Control, icon_id: String, key: String, bar_mode: String, tint: Color, bar_h: float) -> Charts:
	var box := _vbox(4)
	parent.add_child(box)
	var row := _hbox(8)
	box.add_child(row)
	row.add_child(_icon(icon_id, tint, 18.0))
	var name_l := _label("SmallLabel", key)
	_ellipsis(name_l)
	row.add_child(name_l)
	var val := _label("ValueLabel")
	val.add_theme_font_size_override("font_size", 18)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.custom_minimum_size = Vector2(58.0, 0.0)
	row.add_child(val)
	var bar: Charts = Charts.new()
	bar.setup_bar(bar_mode, tint, bar_h)
	bar.value_label = val
	bar.value_format = "pct"
	box.add_child(bar)
	bar.set_value(0.0, true)
	return bar


func _on_left_panel_draw() -> void:
	UITheme.draw_brackets(_left_panel, Rect2(Vector2(-4.0, -4.0), _left_panel.size + Vector2(8.0, 8.0)), UITheme.AMBER, 16.0, 2.0)


# --- Region panel (right) ------------------------------------------------------------------

func _build_right_panel() -> void:
	_right_panel = _panel("HudPanel")
	_right_panel.position = Vector2(1920.0 - MARGIN - RIGHT_W, PANEL_Y)
	_right_panel.custom_minimum_size = Vector2(RIGHT_W, 0.0)
	_right_panel.size = Vector2(RIGHT_W, 0.0)
	_right_panel.draw.connect(_on_right_panel_draw)
	add_child(_right_panel)
	var col := _vbox(8)
	_right_panel.add_child(col)

	var head := _hbox(8)
	col.add_child(head)
	head.add_child(_icon("crosshair", UITheme.AMBER, 18.0))
	var title := _label("HeaderLabel", "hud.region_title")
	_ellipsis(title)
	head.add_child(title)
	_badge = PanelContainer.new()
	_badge.theme_type_variation = &"BadgePanel"
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_badge_label = _label("BadgeLabel")
	_badge.add_child(_badge_label)
	head.add_child(_badge)
	col.add_child(_sep())

	_hint_box = _hbox(14)
	col.add_child(_hint_box)
	_hint_icon = _icon("crosshair", UITheme.HEALTHY, 36.0)
	_hint_box.add_child(_hint_icon)
	var hint := _label("BodyLabel", "hud.region.none")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.custom_minimum_size = Vector2(220.0, 0.0)
	_hint_box.add_child(hint)

	_details = _vbox(8)
	col.add_child(_details)
	_region_name = _label("RegionLabel")
	_region_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_region_name.custom_minimum_size = Vector2(280.0, 0.0)
	_details.add_child(_region_name)
	_region_crisis_bar = _stat_block(_details, "crisis", "hud.region.crisis", "inverse", UITheme.CRISIS, 14.0)
	var inset := _panel("InsetPanel")
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_details.add_child(inset)
	var rows := _vbox(5)
	inset.add_child(rows)
	for rd in STAT_ROWS:
		var d: Array = rd
		var data_key: String = d[0]
		var key: String = d[1]
		var icon_id: String = d[2]
		var bar_mode: String = d[3]
		var tint: Color = _stat_tint(data_key)
		var m: String = bar_mode
		if bar_mode == "aware" or bar_mode == "protect":
			m = "fixed"
		_stat_bars[data_key] = _small_stat(rows, icon_id, key, m, tint)
	var cp := _hbox(8)
	_details.add_child(cp)
	cp.add_child(_icon("population", UITheme.TEXT_DIM, 16.0))
	var cpl := _label("DimLabel", "hud.region.coastal_pop")
	_ellipsis(cpl)
	cp.add_child(cpl)
	_coastal_value = _label("SmallLabel")
	_coastal_value.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	cp.add_child(_coastal_value)

	col.add_child(_sep())
	var ops_head := _hbox(8)
	col.add_child(ops_head)
	ops_head.add_child(_icon("patrol", UITheme.AMBER, 18.0))
	var ops_title := _label("HeaderLabel", "hud.actions_title")
	_ellipsis(ops_title)
	ops_head.add_child(ops_title)
	for a in Balance.ACTION_ORDER:
		_build_action_row(col, str(a))


func _stat_tint(data_key: String) -> Color:
	match data_key:
		"pollution":
			return UITheme.TERRACOTTA.lightened(0.15)
		"coral_health":
			return Color(1.0, 0.56, 0.58)
		"seagrass":
			return UITheme.HEALTHY
		"fish_stock":
			return Color(0.55, 0.82, 0.95)
		"awareness":
			return AWARE_COLOR
		"protection":
			return UITheme.AMBER
	return UITheme.TEXT


func _small_stat(parent: Control, icon_id: String, key: String, bar_mode: String, tint: Color) -> Charts:
	var box := _vbox(3)
	parent.add_child(box)
	var row := _hbox(8)
	box.add_child(row)
	row.add_child(_icon(icon_id, tint, 16.0))
	var name_l := _label("SmallLabel", key)
	_ellipsis(name_l)
	row.add_child(name_l)
	var val := _label("SmallLabel")
	val.add_theme_font_override("font", UITheme.mono_bold_font())
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.custom_minimum_size = Vector2(46.0, 0.0)
	row.add_child(val)
	var bar: Charts = Charts.new()
	bar.setup_bar(bar_mode, tint, 8.0)
	bar.value_label = val
	box.add_child(bar)
	bar.set_value(0.0, true)
	return bar


func _build_action_row(parent: Control, action_id: String) -> void:
	var def: Dictionary = Balance.ACTIONS[action_id]
	var btn := Button.new()
	btn.theme_type_variation = &"ActionButton"
	btn.custom_minimum_size = Vector2(0.0, 66.0)
	_wire_button(btn)
	btn.mouse_entered.connect(_on_action_hover.bind(btn, action_id))
	btn.mouse_exited.connect(_hide_tip.bind(btn))
	btn.pressed.connect(_on_action_pressed.bind(action_id))
	parent.add_child(btn)

	var row := _hbox(10)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10.0
	row.offset_right = -12.0
	row.offset_top = 5.0
	row.offset_bottom = -9.0
	btn.add_child(row)
	var ic := _icon(str(def.get("icon", action_id)), UITheme.HEALTHY, 40.0)
	row.add_child(ic)
	var mid := _vbox(2)
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(mid)
	var name_l := _label("SmallLabel")
	name_l.add_theme_font_override("font", UITheme.mono_bold_font())
	name_l.add_theme_font_size_override("font_size", 15)
	_ellipsis(name_l)
	mid.add_child(name_l)
	var status_l := _label("DimLabel")
	_ellipsis(status_l)
	mid.add_child(status_l)
	var cost_box := _vbox(2)
	cost_box.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(cost_box)
	var cost_labels: Dictionary = {}
	var cost: Dictionary = def.get("cost", {})
	for ck in RES_ORDER:
		var res_key: String = ck
		if not cost.has(res_key):
			continue
		var line := _hbox(4)
		line.alignment = BoxContainer.ALIGNMENT_END
		cost_box.add_child(line)
		var cl := _label("SmallLabel")
		cl.add_theme_font_override("font", UITheme.mono_bold_font())
		cl.text = str(roundi(float(cost[res_key])))
		cl.add_theme_color_override("font_color", RES_COLORS[res_key])
		line.add_child(cl)
		line.add_child(_icon(res_key, RES_COLORS[res_key], 14.0))
		cost_labels[res_key] = cl

	var cd_bg := ColorRect.new()
	cd_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cd_bg.color = UITheme.with_alpha(UITheme.DEEP, 0.8)
	cd_bg.anchor_left = 0.0
	cd_bg.anchor_right = 1.0
	cd_bg.anchor_top = 1.0
	cd_bg.anchor_bottom = 1.0
	cd_bg.offset_left = 10.0
	cd_bg.offset_right = -10.0
	cd_bg.offset_top = -6.0
	cd_bg.offset_bottom = -3.0
	btn.add_child(cd_bg)
	var cd_fill := ColorRect.new()
	cd_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cd_fill.color = UITheme.AMBER
	cd_fill.anchor_left = 0.0
	cd_fill.anchor_top = 0.0
	cd_fill.anchor_bottom = 1.0
	cd_fill.anchor_right = 0.0
	cd_bg.add_child(cd_fill)

	_action_rows.append({
		"id": action_id,
		"button": btn,
		"icon": ic,
		"name": name_l,
		"status": status_l,
		"cost": cost_labels,
		"cd": cd_fill,
		"name_key": str(def.get("name_key", "")),
		"desc_key": str(def.get("desc_key", "")),
	})
	name_l.text = I18n.t(str(def.get("name_key", "")))


func _on_right_panel_draw() -> void:
	var c: Color = _right_bracket_color
	if _region_status == "critical" or _region_status == "collapsed":
		c = UITheme.with_alpha(c, 0.55 + 0.45 * (0.5 + 0.5 * sin(_time * 6.0)))
	UITheme.draw_brackets(_right_panel, Rect2(Vector2(-4.0, -4.0), _right_panel.size + Vector2(8.0, 8.0)), c, 16.0, 2.0)


# --- Toasts and tip ---------------------------------------------------------------------------

func _build_toasts() -> void:
	_toast_box = _vbox(8)
	_toast_box.alignment = BoxContainer.ALIGNMENT_END
	_toast_box.position = Vector2(MARGIN, 660.0)
	_toast_box.size = Vector2(TOAST_W, 396.0)
	add_child(_toast_box)
	_left_panel.resized.connect(_layout_toasts)


func _layout_toasts() -> void:
	var vh: float = get_viewport_rect().size.y
	var top: float = _left_panel.position.y + _left_panel.size.y + 14.0
	_toast_box.position = Vector2(MARGIN, top)
	_toast_box.size = Vector2(TOAST_W, maxf(vh - top - 20.0, 120.0))


func _build_tip() -> void:
	_tip_panel = PanelContainer.new()
	_tip_panel.theme_type_variation = &"TipPanel"
	_tip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_panel.custom_minimum_size = Vector2(300.0, 0.0)
	_tip_panel.visible = false
	_tip_panel.z_index = 10
	add_child(_tip_panel)
	var col := _vbox(5)
	_tip_panel.add_child(col)
	_tip_title = _label("TipTitleLabel")
	_tip_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_title.custom_minimum_size = Vector2(272.0, 0.0)
	col.add_child(_tip_title)
	_tip_body = _label("BodyLabel")
	_tip_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_body.custom_minimum_size = Vector2(272.0, 0.0)
	col.add_child(_tip_body)
	_tip_meta = _label("DimLabel")
	_tip_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_meta.custom_minimum_size = Vector2(272.0, 0.0)
	col.add_child(_tip_meta)


func _show_tip(owner_ctrl: Control, title: String, body: String, meta: String, side: String) -> void:
	_tip_owner = owner_ctrl
	_tip_side = side
	_tip_title.text = title
	_tip_body.text = body
	_tip_body.visible = body != ""
	_tip_meta.text = meta
	_tip_meta.visible = meta != ""
	_tip_panel.size = Vector2(300.0, 40.0)
	_tip_panel.reset_size()
	_tip_panel.visible = true
	_place_tip()
	if _tip_tween != null and _tip_tween.is_valid():
		_tip_tween.kill()
	_tip_panel.modulate.a = 0.0
	_tip_tween = _tip_panel.create_tween()
	_tip_tween.tween_property(_tip_panel, "modulate:a", 1.0, 0.14)


func _place_tip() -> void:
	if _tip_owner == null or not is_instance_valid(_tip_owner):
		return
	var vs: Vector2 = get_viewport_rect().size
	_tip_panel.reset_size()
	var ts: Vector2 = _tip_panel.size
	var op: Vector2 = _tip_owner.global_position
	var osz: Vector2 = _tip_owner.size
	var p := Vector2.ZERO
	if _tip_side == "below":
		p = Vector2(op.x + osz.x * 0.5 - ts.x * 0.5, op.y + osz.y + 10.0)
	else:
		p = Vector2(_right_panel.position.x - ts.x - 14.0, op.y)
	p.x = clampf(p.x, 8.0, vs.x - ts.x - 8.0)
	p.y = clampf(p.y, 8.0, vs.y - ts.y - 8.0)
	_tip_panel.position = p


func _hide_tip(owner_ctrl: Control) -> void:
	if owner_ctrl != _tip_owner:
		return
	_hide_tip_now()


func _hide_tip_now() -> void:
	_tip_owner = null
	if _tip_tween != null and _tip_tween.is_valid():
		_tip_tween.kill()
	_tip_panel.visible = false


func _on_speed_hover(btn: Button, index: int) -> void:
	var meta: String = ""
	if index > 0:
		meta = "[" + str(index) + "]"
	_show_tip(btn, I18n.t(SPEED_KEYS[index]), "", meta, "below")


func _on_action_hover(btn: Button, action_id: String) -> void:
	var def: Dictionary = Balance.ACTIONS[action_id]
	var cost: Dictionary = def.get("cost", {})
	var parts := PackedStringArray()
	for ck in RES_ORDER:
		var res_key: String = ck
		if cost.has(res_key):
			parts.append(str(roundi(float(cost[res_key]))) + " " + I18n.t(RES_KEYS[res_key]))
	var meta: String = I18n.t("hud.cost") + ": " + ", ".join(parts)
	_show_tip(btn, I18n.t(str(def.get("name_key", ""))), I18n.t(str(def.get("desc_key", ""))), meta, "left")


func _toast_text(text_key: String, args: Dictionary) -> String:
	var shown: Dictionary = {}
	for k in args.keys():
		var v: Variant = args[k]
		if v is String and I18n.has_key(str(v)):
			shown[k] = I18n.t(str(v))
		else:
			shown[k] = v
	return I18n.t(text_key, shown)


func _on_toast(text_key: String, args: Dictionary, severity: int) -> void:
	if not _is_shown:
		return
	var sev: int = clampi(severity, 0, 3)
	var col: Color = UITheme.severity_color(sev)
	var root := MarginContainer.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_theme_constant_override("margin_left", 40)
	root.add_theme_constant_override("margin_right", 0)
	root.add_theme_constant_override("margin_top", 0)
	root.add_theme_constant_override("margin_bottom", 0)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"ToastPanel"
	panel.add_theme_stylebox_override("panel", UITheme.stripe_box(col))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	var row := _hbox(10)
	panel.add_child(row)
	var icon_ids: Array = ["info", "check", "warning", "crisis"]
	row.add_child(_icon(str(icon_ids[sev]), col, 18.0))
	var l := _label("SmallLabel")
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(220.0, 0.0)
	l.text = _toast_text(text_key, args)
	if sev == 3:
		l.add_theme_color_override("font_color", UITheme.CRISIS.lerp(Color.WHITE, 0.5))
	elif sev == 1:
		l.add_theme_color_override("font_color", UITheme.HEALTHY.lerp(Color.WHITE, 0.55))
	row.add_child(l)
	_toast_box.add_child(root)
	root.modulate.a = 0.0
	_toasts.append({"root": root, "label": l, "key": text_key, "args": args})
	while _toasts.size() > MAX_TOASTS:
		var oldest: Dictionary = _toasts[0]
		_drop_toast(oldest["root"])

	var tw := root.create_tween()
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(root, "modulate:a", 1.0, 0.3)
	tw.tween_method(_set_toast_margin.bind(root), 40.0, 0.0, 0.4)
	tw.chain().tween_interval(TOAST_LIFE)
	tw.chain().tween_property(root, "modulate:a", 0.0, 0.6)
	tw.chain().tween_callback(_drop_toast.bind(root))
	if sev >= 2:
		var blink := panel.create_tween()
		blink.set_loops(3 if sev == 3 else 1)
		blink.tween_property(panel, "self_modulate", Color(1.8, 1.8, 1.8, 1.0), 0.08)
		blink.tween_property(panel, "self_modulate", Color.WHITE, 0.22)


func _set_toast_margin(v: float, root: MarginContainer) -> void:
	if is_instance_valid(root):
		root.add_theme_constant_override("margin_left", int(v))


func _drop_toast(root: Control) -> void:
	for i in range(_toasts.size() - 1, -1, -1):
		var rec: Dictionary = _toasts[i]
		if rec["root"] == root:
			_toasts.remove_at(i)
	if is_instance_valid(root):
		root.queue_free()


func _clear_toasts() -> void:
	for rec in _toasts:
		var r: Dictionary = rec
		var node: Control = r["root"]
		if is_instance_valid(node):
			node.queue_free()
	_toasts.clear()


# --- Public API (frozen) --------------------------------------------------------------------

func show_hud() -> void:
	_is_shown = true
	visible = true
	_kill_anim()
	var vs: Vector2 = get_viewport_rect().size
	_top_bar.position.y = -TOP_H - 8.0
	_left_panel.position = Vector2(-LEFT_W - 60.0, PANEL_Y)
	_right_panel.position = Vector2(vs.x + 60.0, PANEL_Y)
	modulate.a = 0.0
	_anim = create_tween()
	_anim.set_parallel(true)
	_anim.set_trans(Tween.TRANS_CUBIC)
	_anim.set_ease(Tween.EASE_OUT)
	_anim.tween_property(self, "modulate:a", 1.0, 0.4)
	_anim.tween_property(_top_bar, "position:y", TICKER_H, 0.5)
	_anim.tween_property(_left_panel, "position:x", MARGIN, 0.65).set_delay(0.1)
	_anim.tween_property(_right_panel, "position:x", vs.x - MARGIN - RIGHT_W, 0.65).set_delay(0.2)
	_refresh_actions()


func hide_hud() -> void:
	_is_shown = false
	_hide_tip_now()
	_kill_anim()
	if not visible:
		return
	var vs: Vector2 = get_viewport_rect().size
	_anim = create_tween()
	_anim.set_parallel(true)
	_anim.set_trans(Tween.TRANS_CUBIC)
	_anim.set_ease(Tween.EASE_IN)
	_anim.tween_property(self, "modulate:a", 0.0, 0.35)
	_anim.tween_property(_top_bar, "position:y", -TOP_H - 8.0, 0.35)
	_anim.tween_property(_left_panel, "position:x", -LEFT_W - 60.0, 0.4)
	_anim.tween_property(_right_panel, "position:x", vs.x + 60.0, 0.4)
	_anim.chain().tween_callback(_finish_hide)


func _finish_hide() -> void:
	if not _is_shown:
		visible = false
		_clear_toasts()


func _kill_anim() -> void:
	if _anim != null and _anim.is_valid():
		_anim.kill()
	_anim = null


# --- EventBus handlers -------------------------------------------------------------------------

func _on_game_started() -> void:
	_clear_toasts()
	_snap = GameState.get_snapshot()
	_update_time_labels()
	_select_region(GameState.selected_region)


func _on_tick_done(snapshot: Dictionary) -> void:
	_snap = snapshot
	_update_time_labels()
	_timeline.set_value(float(snapshot.get("progress", 0.0)))
	var sh: float = float(snapshot.get("sea_health", 0.0))
	_sea_bar.set_value(sh)
	_sea_bar.alert = sh < 20.0
	var cr: float = float(snapshot.get("crisis", 0.0))
	_crisis_bar.set_value(cr)
	_crisis_bar.alert = cr >= 75.0
	_aware_bar.set_value(float(snapshot.get("awareness", 0.0)))
	_gauge.set_value(float(snapshot.get("temperature", Charts.TEMP_MIN)))
	_pulse.pulse_health = sh
	_refresh_actions()


func _update_time_labels() -> void:
	var y: int = int(_snap.get("year_int", Balance.START_YEAR))
	var left: int = int(_snap.get("years_left", Balance.END_YEAR - Balance.START_YEAR))
	_year_label.text = I18n.t("hud.year", {"year": str(y)})
	_years_left_label.text = I18n.t("hud.years_left", {"n": str(left)})


func _on_resources_changed(budget: float, political: float, science: float) -> void:
	var values: Dictionary = {"budget": budget, "political": political, "science": science}
	for k in RES_ORDER:
		var key: String = k
		var nv: float = values[key]
		var old: float = _res_target[key]
		_res_target[key] = nv
		var l: Label = _res_labels[key]
		if nv < old - 0.5:
			_flash_label(l, UITheme.CRISIS)
		elif nv > old + 4.0:
			_flash_label(l, UITheme.HEALTHY)
	_refresh_actions()


func _flash_label(l: Label, col: Color) -> void:
	l.modulate = col.lerp(Color.WHITE, 0.25)
	var tw := l.create_tween()
	tw.tween_property(l, "modulate", Color.WHITE, 0.6)


func _on_region_selected(region_id: String) -> void:
	_select_region(region_id)


func _select_region(region_id: String) -> void:
	_selected = region_id
	_region = {}
	if region_id != "":
		_region = GameState.get_region(region_id)
	var has: bool = not _region.is_empty()
	_hint_box.visible = not has
	_details.visible = has
	_badge.visible = has
	_region_status = ""
	if has:
		_update_region(_region, true)
		_details.modulate.a = 0.0
		var tw := _details.create_tween()
		tw.tween_property(_details, "modulate:a", 1.0, 0.3)
	else:
		_right_bracket_color = UITheme.TEXT_DIM
	_refresh_actions()
	_right_panel.queue_redraw()
	call_deferred("_shrink_panels")


func _shrink_panels() -> void:
	_right_panel.reset_size()
	_left_panel.reset_size()
	_layout_toasts()


func _on_region_changed(region_id: String, data: Dictionary) -> void:
	if region_id == _selected and _selected != "":
		_update_region(data, false)


func _update_region(data: Dictionary, force: bool) -> void:
	_region = data
	_region_name.text = I18n.t(str(data.get("name_key", "")))
	var st: String = str(data.get("status", "healthy"))
	if st != _region_status or force:
		var changed: bool = _region_status != "" and st != _region_status
		_region_status = st
		var sc: Color = UITheme.status_color(st)
		_badge_label.text = I18n.t("hud.status." + st)
		_badge.add_theme_stylebox_override("panel", UITheme.badge_box(sc))
		_badge_label.add_theme_color_override("font_color", sc.lerp(Color.WHITE, 0.25))
		_right_bracket_color = sc
		_right_panel.queue_redraw()
		if changed:
			_badge.pivot_offset = _badge.size * 0.5
			_badge.scale = Vector2(1.25, 1.25)
			var tw := _badge.create_tween()
			tw.set_trans(Tween.TRANS_BACK)
			tw.set_ease(Tween.EASE_OUT)
			tw.tween_property(_badge, "scale", Vector2.ONE, 0.35)
	_region_crisis_bar.set_value(float(data.get("crisis", 0.0)))
	_region_crisis_bar.alert = st == "collapsed"
	for k in _stat_bars.keys():
		var key: String = k
		var bar: Charts = _stat_bars[key]
		bar.set_value(float(data.get(key, 0.0)))
	_coastal_value.text = str(roundi(float(data.get("coastal_pop", 0.0)) * 100.0)) + "%"


func _refresh_actions() -> void:
	var has_region: bool = _selected != "" and GameState.running and not _region.is_empty()
	for r in _action_rows:
		var row: Dictionary = r
		var id: String = row["id"]
		var btn: Button = row["button"]
		var status_l: Label = row["status"]
		var ic: Icons = row["icon"]
		var cd_fill: ColorRect = row["cd"]
		var cd_left: float = 0.0
		var cd_frac: float = 0.0
		if has_region:
			cd_left = GameState.action_cooldown_left(id, _selected)
			cd_frac = GameState.action_cooldown_fraction(id, _selected)
		var afford: bool = GameState.can_afford(id)
		var can: bool = has_region and GameState.can_perform(id, _selected)
		var key: String = "hud.action.ready"
		var args: Dictionary = {}
		var scol: Color = UITheme.HEALTHY
		if not has_region:
			key = "hud.action.select_region"
			scol = UITheme.TEXT_DIM
		elif cd_left > 0.0:
			key = "hud.action.cooldown"
			args = {"n": str(ceili(cd_left))}
			scol = UITheme.AMBER
		elif not afford:
			key = "hud.action.no_funds"
			scol = UITheme.CRISIS
		elif not can:
			key = "hud.action.select_region"
			scol = UITheme.TEXT_DIM
		status_l.text = I18n.t(key, args)
		status_l.add_theme_color_override("font_color", scol)
		if btn.disabled == can:
			btn.disabled = not can
			if btn.disabled:
				UITheme.reset_fx(btn)
		ic.color = UITheme.HEALTHY if can else UITheme.with_alpha(UITheme.TEXT_DIM, 0.55)
		cd_fill.anchor_right = clampf(cd_frac, 0.0, 1.0)
		var cost: Dictionary = GameState.action_cost(id)
		var cost_labels: Dictionary = row["cost"]
		for ck in cost_labels.keys():
			var res_key: String = ck
			var cl: Label = cost_labels[res_key]
			var need: float = float(cost.get(res_key, 0.0))
			var have: float = float(_res_target.get(res_key, 0.0))
			var base: Color = RES_COLORS[res_key]
			cl.add_theme_color_override("font_color", base if have >= need else UITheme.CRISIS)


func _on_action_pressed(action_id: String) -> void:
	if _selected == "":
		return
	GameState.perform_action(action_id, _selected)


func _on_action_performed(action_id: String, region_id: String) -> void:
	if region_id != _selected:
		return
	for r in _action_rows:
		var row: Dictionary = r
		if str(row["id"]) != action_id:
			continue
		var btn: Button = row["button"]
		btn.self_modulate = Color(0.7, 1.9, 1.7, 1.0)
		var tw := btn.create_tween()
		tw.tween_property(btn, "self_modulate", Color.WHITE, 0.6)
	_right_bracket_color = UITheme.HEALTHY
	_right_panel.queue_redraw()


func _on_speed_pressed(index: int) -> void:
	if not GameState.running:
		_on_speed_changed(GameState.speed_index)
		return
	if index == 0 and GameState.speed_index == 0:
		GameState.toggle_pause()
	else:
		GameState.set_speed(index)


func _on_speed_changed(speed_index: int) -> void:
	for i in _speed_buttons.size():
		var btn: Button = _speed_buttons[i]
		btn.set_pressed_no_signal(i == speed_index)
	_paused_chip.visible = speed_index == 0 and GameState.running


func _on_paused_changed(_paused: bool) -> void:
	_paused_chip.visible = GameState.speed_index == 0 and GameState.running


func _on_language_changed(_lang: String) -> void:
	for pair in _tr_labels:
		var p: Array = pair
		var l: Label = p[0]
		var key: String = p[1]
		if is_instance_valid(l):
			l.text = I18n.t(key)
	_update_time_labels()
	if not _region.is_empty():
		_update_region(_region, true)
	for r in _action_rows:
		var row: Dictionary = r
		var name_l: Label = row["name"]
		name_l.text = I18n.t(str(row["name_key"]))
	_refresh_actions()
	for rec in _toasts:
		var t: Dictionary = rec
		var tl: Label = t["label"]
		if is_instance_valid(tl):
			tl.text = _toast_text(str(t["key"]), t["args"])
	_hide_tip_now()
	call_deferred("_shrink_panels")


# --- Per-frame juice ----------------------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	if not visible:
		return
	for k in RES_ORDER:
		var key: String = k
		var shown: float = _res_shown[key]
		var target: float = _res_target[key]
		if absf(shown - target) > 0.01:
			shown = lerpf(shown, target, 1.0 - exp(-delta * 6.0))
			if absf(shown - target) < 0.5:
				shown = target
			_res_shown[key] = shown
			var l: Label = _res_labels[key]
			l.text = str(roundi(shown))
	_ticker_strip.queue_redraw()
	if _paused_chip.visible:
		_paused_chip.modulate.a = 0.55 + 0.45 * (0.5 + 0.5 * sin(_time * 5.0))
	_live_dot.modulate.a = 0.35 + 0.65 * (0.5 + 0.5 * sin(_time * 3.0))
	if _hint_box.visible:
		_hint_icon.pivot_offset = _hint_icon.size * 0.5
		_hint_icon.rotation = _time * 0.8
		_hint_icon.scale = Vector2.ONE * (1.0 + 0.08 * sin(_time * 3.0))
	if _region_status == "critical" or _region_status == "collapsed":
		_badge.modulate.a = 0.6 + 0.4 * (0.5 + 0.5 * sin(_time * 6.0))
		_right_panel.queue_redraw()
	else:
		_badge.modulate.a = 1.0
	if _tip_panel.visible:
		_place_tip()
