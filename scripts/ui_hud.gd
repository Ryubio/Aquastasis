extends Control
## UIHud: in-game HUD built in code - news ticker strip, top bar (year, timeline, speed,
## resources with net income per year), BASIN STATUS panel (bars, temperature gauge, live
## trend chart, crisis resistances, evolution pressure), REGION panel (status, six stats,
## FIELD OPERATIONS with Q/W/E hints, POLICY TREE button), toast feed and a themed hover tip.
## Driven only by EventBus.

const UITheme := preload("res://scripts/ui_theme.gd")
const Icons := preload("res://scripts/icons.gd")
const Charts := preload("res://scripts/charts.gd")
const NewsTicker := preload("res://scripts/news_ticker.gd")
const TechTree := preload("res://scripts/tech_tree.gd")

const TICKER_H := 32.0
const TOP_H := 60.0
const MARGIN := 16.0
const LEFT_W := 340.0
const RIGHT_W := 404.0
const PANEL_Y := 106.0
const TOAST_W := 340.0
const TOAST_AREA_H := 280.0
const MAX_TOASTS := 4
const TOAST_LIFE := 7.0

const RES_BLOCK_W := 186.0
const RES_ORDER := ["budget", "political", "science"]
const RES_KEYS := {"budget": "hud.budget", "political": "hud.political", "science": "hud.science"}
## Snapshot keys of the net income per tick (before spending) of each resource.
const RATE_KEYS := {"budget": "budget_rate", "political": "political_rate", "science": "science_rate"}
## Field operation hotkeys in Balance.ACTION_ORDER order (main.gd maps Q / W / E the same way).
const ACTION_HOTKEYS := ["Q", "W", "E"]
const HISTORY_EVERY := 10           # local chart samples if GameState.get_history() is empty
const NEG_INCOME_WARN_TICKS := 5    # budget income negative this long -> warning toast
const NEG_INCOME_REARM_TICKS := 60  # ... and positive this long before it may warn again
const MAX_RESIST_COUNTERS := 2
const MAX_RESIST_ROWS := 3
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
var _tip_body: RichTextLabel
var _tip_meta: Label
var _tip_owner: Control = null
var _tip_tween: Tween = null
var _tip_side: String = "left"

# Top bar
var _pulse: Charts
var _year_label: Label
var _years_left_label: Label
var _tick_bar: ProgressBar
var _tick_bar_fill: StyleBoxFlat
var _timeline: Charts
var _speed_buttons: Array = []
var _speed_icons: Array = []
var _speed_labels: Array = []
var _paused_chip: PanelContainer
var _chip_on: bool = false          # chip keeps its layout slot; only its alpha changes
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
var _region_trait_box: PanelContainer
var _region_trait_label: Label
var _bd_box: PanelContainer
var _bd_labels: Dictionary = {}
var _badge: PanelContainer
var _badge_label: Label
var _region_crisis_bar: Charts
var _stat_bars: Dictionary = {}     # data key -> Charts
var _coastal_value: Label
var _action_rows: Array = []        # Dictionary per action

# Toasts: Dictionary {root, label, key, args}
var _toasts: Array = []
var _toast_avail: float = TOAST_AREA_H   # height of the toast feed area

# Phase 2: news ticker, net income, live chart, resistances, evolution pressure, policy tree
var _ticker: NewsTicker
var _res_icons: Dictionary = {}     # key -> Icons
var _rate_labels: Dictionary = {}   # key -> Label ("+75/yr")
var _rate_values: Dictionary = {}   # key -> net income per year (float), missing = unknown
var _budget_negative: bool = false
var _neg_ticks: int = 0
var _pos_ticks: int = 0
var _neg_warned: bool = false
var _chart: Charts
var _local_hist: Array = []         # [[tick, sea_health, crisis], ...] fallback samples
var _resist_icon: Icons
var _resist_title: Label
var _resist_badge: PanelContainer
var _resist_count: Label
var _resist_list: VBoxContainer
var _resist_none: Label
var _resist_more: Label             # "Also active: N" past MAX_RESIST_ROWS
var _resist_ids: Array = []         # evolution ids currently listed
var _resist_flash: float = 0.0
var _pressure_box: PanelContainer
var _pressure_icon: Icons
var _pressure_label: Label
var _pressure_bar: Charts
var _pressure_branch: String = ""
var _tree_btn: Button
var _tree_icon: Icons
var _tree_status: Label
var _tree_open: bool = false
var _adoptable: int = 0

# Visual Juice & Screen Vignette
var _vignette: Control
var _vignette_alpha: float = 0.0
var _vignette_color: Color = UITheme.CRISIS
var _vignette_tween: Tween = null
var _floating_layer: Control

# 60-Second Onboarding Briefing
var _onboarding_box: PanelContainer
var _onboarding_timer_label: Label
var _onboarding_done_label: Label
var _onboarding_steps: Array = []       # [ { "icon": Icons, "label": Label, "key": String }, ... ]
var _onboard_steps_done: Array = [false, false, false, false]
var _onboard_time_left: float = 60.0
var _onboard_active: bool = false

# Flagship Biodiversity & Barometer (Top bar)
var _turtle_chip: PanelContainer
var _turtle_count: Label
var _seal_chip: PanelContainer
var _seal_count: Label
var _defcon_badge: PanelContainer
var _defcon_label: Label
var _defcon_level: int = 5
var _antalya_hq_chip: PanelContainer
var _antalya_hq_label: Label
var _diff_badge: PanelContainer
var _diff_badge_label: Label
var _audio_btn: Button
var _help_btn: Button

# COP31 Summit Modal
var _summit_modal: Control
var _summit_badge_panel: PanelContainer
var _summit_badge_label: Label
var _summit_title_label: Label
var _summit_desc_text: RichTextLabel
var _summit_opt_a_title: Label
var _summit_opt_a_desc: Label
var _summit_opt_a_btn: Button
var _summit_opt_b_title: Label
var _summit_opt_b_desc: Label
var _summit_opt_b_btn: Button
var _current_summit_data: Dictionary = {}

# Tactical Spotlight Briefing Modal
var _briefing_modal: Control
var _briefing_backdrop: Control
var _briefing_step: int = 1
var _briefing_step_label: Label
var _briefing_card_icon: Icons
var _briefing_card_title: Label
var _briefing_card_text: RichTextLabel
var _briefing_prev_btn: Button
var _briefing_next_btn: Button
var _briefing_skip_btn: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UITheme.build_theme()
	_build_vignette()
	_build_floating_layer()
	_build_ticker_strip()
	_build_top_bar()
	_build_left_panel()
	_build_right_panel()
	_build_toasts()
	_build_onboarding()
	_build_tactical_briefing()
	_build_summit_modal()
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
	EventBus.evolution_happened.connect(_on_evolution_happened)
	EventBus.evolution_cured.connect(_on_evolution_cured)
	EventBus.node_adopted.connect(_on_node_adopted)
	EventBus.tree_toggled.connect(_on_tree_toggled)
	EventBus.spread_happened.connect(_on_spread_happened)
	EventBus.bubble_collected.connect(_on_bubble_collected)
	EventBus.summit_triggered.connect(_on_summit_triggered)
	EventBus.tutorial_requested.connect(_show_tactical_briefing)

	_select_region(GameState.selected_region)
	_on_speed_changed(GameState.speed_index)
	_refresh_resistances(false)
	_update_tree_status()


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


func _spacer() -> Control:
	var s := Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


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


## Trims overlong single-line text with an ellipsis. No clip_text: clipping to the line box
## cuts the marks above capitals (Turkish İ/Ö/Ü/Ğ, Russian Ё), which changes the letter.
func _ellipsis(l: Label) -> void:
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
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


# --- Ticker strip (news marquee) --------------------------------------------------------

func _build_ticker_strip() -> void:
	_ticker_strip = Control.new()
	_ticker_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ticker_strip.position = Vector2.ZERO
	_ticker_strip.size = Vector2(1920.0, TICKER_H)
	_ticker_strip.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_ticker_strip.offset_bottom = TICKER_H
	_ticker_strip.draw.connect(_draw_ticker_strip)
	add_child(_ticker_strip)
	_ticker = NewsTicker.new()
	_ticker.name = "NewsTicker"
	_ticker_strip.add_child(_ticker)


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
	brand.custom_minimum_size = Vector2(400.0, 0.0)
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
	var year_box := _vbox(2)
	year_box.custom_minimum_size = Vector2(170.0, 0.0)
	year_box.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(year_box)
	_year_label = _label("BigValueLabel")
	_year_label.add_theme_font_size_override("font_size", 20)
	_ellipsis(_year_label)
	year_box.add_child(_year_label)
	_tick_bar = ProgressBar.new()
	_tick_bar.custom_minimum_size = Vector2(154.0, 5.0)
	_tick_bar.min_value = 0.0
	_tick_bar.max_value = 1.0
	_tick_bar.step = 0.0
	_tick_bar.value = 0.0
	_tick_bar.show_percentage = false
	_tick_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tb_bg: StyleBoxFlat = UITheme.panel_box(UITheme.LINE_DIM, UITheme.with_alpha(UITheme.DEEP, 0.9), 1, Color(0, 0, 0, 0), 0, 2)
	tb_bg.content_margin_left = 0.0
	tb_bg.content_margin_right = 0.0
	tb_bg.content_margin_top = 0.0
	tb_bg.content_margin_bottom = 0.0
	_tick_bar_fill = UITheme.panel_box(UITheme.HEALTHY, UITheme.with_alpha(UITheme.HEALTHY, 0.85), 0, UITheme.with_alpha(UITheme.HEALTHY, 0.35), 4, 2)
	_tick_bar_fill.content_margin_left = 0.0
	_tick_bar_fill.content_margin_right = 0.0
	_tick_bar_fill.content_margin_top = 0.0
	_tick_bar_fill.content_margin_bottom = 0.0
	_tick_bar.add_theme_stylebox_override("background", tb_bg)
	_tick_bar.add_theme_stylebox_override("fill", _tick_bar_fill)
	year_box.add_child(_tick_bar)
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
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.custom_minimum_size = Vector2(58.0, 38.0)
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_wire_button(btn)
		btn.mouse_entered.connect(_on_speed_hover.bind(btn, i))
		btn.mouse_exited.connect(_hide_tip.bind(btn))
		btn.pressed.connect(_on_speed_pressed.bind(i))
		var inner := _hbox(4)
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		btn.add_child(inner)
		var px: float = 16.0 if i == 0 else 14.0
		var ic: Icons = _icon(SPEED_ICONS[i], UITheme.TEXT, px)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(ic)
		_speed_icons.append(ic)
		var txt: String = SPEED_TEXT[i]
		var spd_label: Label = null
		if txt != "":
			var l := _label("SmallLabel")
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			l.text = txt
			l.add_theme_font_override("font", UITheme.mono_bold_font())
			l.add_theme_font_size_override("font_size", 13)
			l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			inner.add_child(l)
			spd_label = l
		_speed_labels.append(spd_label)
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
	# Always laid out (alpha 0 while running): toggling visible would resize the expanding
	# timeline and slide the speed buttons out from under the cursor on every pause.
	_paused_chip.modulate.a = 0.0
	speed_row.add_child(_paused_chip)
	row.add_child(_vline(40.0))

	# Resources: icon, tick-up value, net income per year, name. Hover explains the rate.
	for k in RES_ORDER:
		var key: String = k
		var col: Color = RES_COLORS[key]
		var block := _hbox(8)
		block.custom_minimum_size = Vector2(RES_BLOCK_W, 0.0)
		block.mouse_filter = Control.MOUSE_FILTER_PASS
		block.mouse_entered.connect(_on_res_hover.bind(block, key))
		block.mouse_exited.connect(_hide_tip.bind(block))
		row.add_child(block)
		var res_icon := _icon(key, col, 28.0)
		block.add_child(res_icon)
		_res_icons[key] = res_icon
		var col_box := _vbox(0)
		col_box.alignment = BoxContainer.ALIGNMENT_CENTER
		col_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		block.add_child(col_box)
		var val_row := _hbox(7)
		col_box.add_child(val_row)
		var v := _label("ValueLabel")
		v.add_theme_color_override("font_color", col.lerp(Color.WHITE, 0.25))
		v.text = "0"
		val_row.add_child(v)
		var rate := _label("SmallLabel")
		rate.add_theme_font_override("font", UITheme.mono_bold_font())
		rate.add_theme_font_size_override("font_size", 12)
		rate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rate.visible = false
		val_row.add_child(rate)
		_rate_labels[key] = rate
		var n := _label("DimLabel", RES_KEYS[key])
		n.add_theme_font_size_override("font_size", 11)
		_ellipsis(n)
		col_box.add_child(n)
		_res_labels[key] = v
		_res_shown[key] = 0.0
		_res_target[key] = 0.0

	row.add_child(_vline(40.0))

	# Flagship Biodiversity (Turtles & Monk Seals)
	var bio_box := _hbox(10)
	bio_box.mouse_filter = Control.MOUSE_FILTER_PASS
	bio_box.mouse_entered.connect(_on_species_hover.bind(bio_box))
	bio_box.mouse_exited.connect(_hide_tip.bind(bio_box))
	row.add_child(bio_box)

	_turtle_chip = PanelContainer.new()
	_turtle_chip.theme_type_variation = &"BadgePanel"
	_turtle_chip.add_theme_stylebox_override("panel", UITheme.badge_box(UITheme.HEALTHY))
	_turtle_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var turtle_inner := _hbox(4)
	_turtle_chip.add_child(turtle_inner)
	var t_ico := _label("BadgeLabel")
	t_ico.text = "🐢"
	turtle_inner.add_child(t_ico)
	_turtle_count = _label("SmallLabel")
	_turtle_count.add_theme_font_override("font", UITheme.mono_bold_font())
	_turtle_count.add_theme_color_override("font_color", UITheme.HEALTHY.lerp(Color.WHITE, 0.25))
	_turtle_count.text = "0"
	turtle_inner.add_child(_turtle_count)
	bio_box.add_child(_turtle_chip)

	_seal_chip = PanelContainer.new()
	_seal_chip.theme_type_variation = &"BadgePanel"
	_seal_chip.add_theme_stylebox_override("panel", UITheme.badge_box(UITheme.SCIENCE_BLUE))
	_seal_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var seal_inner := _hbox(4)
	_seal_chip.add_child(seal_inner)
	var s_ico := _label("BadgeLabel")
	s_ico.text = "🦭"
	seal_inner.add_child(s_ico)
	_seal_count = _label("SmallLabel")
	_seal_count.add_theme_font_override("font", UITheme.mono_bold_font())
	_seal_count.add_theme_color_override("font_color", UITheme.SCIENCE_BLUE.lerp(Color.WHITE, 0.25))
	_seal_count.text = "0"
	seal_inner.add_child(_seal_count)
	bio_box.add_child(_seal_chip)

	row.add_child(_vline(40.0))

	# Tactical Readiness (DEFCON & Antalya HQ & Difficulty)
	var tac_box := _hbox(8)
	row.add_child(tac_box)

	_defcon_badge = PanelContainer.new()
	_defcon_badge.theme_type_variation = &"BadgePanel"
	_defcon_badge.add_theme_stylebox_override("panel", UITheme.badge_box(UITheme.HEALTHY))
	_defcon_badge.mouse_filter = Control.MOUSE_FILTER_PASS
	_defcon_badge.mouse_entered.connect(_on_defcon_hover.bind(_defcon_badge))
	_defcon_badge.mouse_exited.connect(_hide_tip.bind(_defcon_badge))
	_defcon_label = _label("BadgeLabel")
	_defcon_label.add_theme_font_override("font", UITheme.mono_bold_font())
	_defcon_label.add_theme_color_override("font_color", UITheme.HEALTHY)
	_defcon_label.text = "DEFCON 5"
	_defcon_badge.add_child(_defcon_label)
	tac_box.add_child(_defcon_badge)

	_antalya_hq_chip = PanelContainer.new()
	_antalya_hq_chip.theme_type_variation = &"BadgePanel"
	_antalya_hq_chip.add_theme_stylebox_override("panel", UITheme.badge_box(UITheme.AMBER))
	_antalya_hq_chip.mouse_filter = Control.MOUSE_FILTER_PASS
	_antalya_hq_chip.mouse_entered.connect(_on_hq_hover.bind(_antalya_hq_chip))
	_antalya_hq_chip.mouse_exited.connect(_hide_tip.bind(_antalya_hq_chip))
	_antalya_hq_label = _label("BadgeLabel")
	_antalya_hq_label.add_theme_font_override("font", UITheme.mono_bold_font())
	_antalya_hq_label.add_theme_color_override("font_color", UITheme.AMBER)
	_antalya_hq_label.text = "HQ: 100%"
	_antalya_hq_chip.add_child(_antalya_hq_label)
	tac_box.add_child(_antalya_hq_chip)

	_diff_badge = PanelContainer.new()
	_diff_badge.theme_type_variation = &"BadgePanel"
	_diff_badge.add_theme_stylebox_override("panel", UITheme.badge_box(UITheme.LINE_DIM))
	_diff_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_diff_badge_label = _label("BadgeLabel")
	_diff_badge_label.add_theme_font_override("font", UITheme.mono_bold_font())
	_diff_badge_label.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	_diff_badge_label.text = "COMMANDER"
	_diff_badge.add_child(_diff_badge_label)
	tac_box.add_child(_diff_badge)

	row.add_child(_vline(40.0))

	# Audio Mute & Help Buttons
	var util_box := _hbox(6)
	row.add_child(util_box)

	_audio_btn = Button.new()
	_audio_btn.theme_type_variation = &"SpeedButton"
	_audio_btn.custom_minimum_size = Vector2(42.0, 38.0)
	_audio_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_audio_btn.text = "🔊"
	_audio_btn.pressed.connect(_on_audio_toggle)
	_audio_btn.mouse_entered.connect(_on_audio_hover.bind(_audio_btn))
	_audio_btn.mouse_exited.connect(_hide_tip.bind(_audio_btn))
	util_box.add_child(_audio_btn)

	_help_btn = Button.new()
	_help_btn.theme_type_variation = &"SpeedButton"
	_help_btn.custom_minimum_size = Vector2(42.0, 38.0)
	_help_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_help_btn.text = "❓"
	_help_btn.pressed.connect(_show_tactical_briefing)
	_help_btn.mouse_entered.connect(_on_help_hover.bind(_help_btn))
	_help_btn.mouse_exited.connect(_hide_tip.bind(_help_btn))
	util_box.add_child(_help_btn)


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
	_gauge.setup_gauge(Vector2(280.0, 158.0))
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
	col.add_child(_sep())
	_build_chart_section(col)
	col.add_child(_sep())
	_build_resist_section(col)


## LIVE TREND: legend (wraps for long languages) and the Sea Health vs Crisis line chart.
func _build_chart_section(col: VBoxContainer) -> void:
	var head := _hbox(8)
	col.add_child(head)
	head.add_child(_icon("clock", UITheme.AMBER, 16.0))
	var title := _label("HeaderLabel", "hud.chart.title")
	_ellipsis(title)
	head.add_child(title)
	var legend := HFlowContainer.new()
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	legend.add_theme_constant_override("h_separation", 14)
	legend.add_theme_constant_override("v_separation", 2)
	col.add_child(legend)
	_legend_item(legend, UITheme.HEALTHY, false, "hud.chart.health")
	_legend_item(legend, UITheme.CRISIS, false, "hud.chart.crisis")
	_legend_item(legend, UITheme.AMBER, true, "hud.chart.goal")
	var inset := _panel("InsetPanel")
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inset.add_theme_stylebox_override("panel", _inset_box(6.0, 6.0))
	col.add_child(inset)
	_chart = Charts.new()
	_chart.setup_line(Vector2(260.0, 104.0))
	_chart.total_ticks = Balance.TOTAL_TICKS
	_chart.start_year = Balance.START_YEAR
	_chart.end_year = Balance.END_YEAR
	_chart.goal_value = Balance.WIN_SEA_HEALTH
	inset.add_child(_chart)


func _inset_box(h: float, v: float) -> StyleBoxFlat:
	var sb := UITheme.panel_box(UITheme.LINE_DIM, UITheme.with_alpha(UITheme.DEEP, 0.75), 1, Color(0, 0, 0, 0), 0, 6)
	sb.content_margin_left = h
	sb.content_margin_right = h
	sb.content_margin_top = v
	sb.content_margin_bottom = v
	return sb


func _legend_item(parent: Control, col: Color, dashed: bool, key: String) -> void:
	var item := _hbox(5)
	parent.add_child(item)
	var sw := Control.new()
	sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sw.custom_minimum_size = Vector2(16.0, 10.0)
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sw.draw.connect(_draw_swatch.bind(sw, col, dashed))
	item.add_child(sw)
	var l := _label("DimLabel", key)
	l.add_theme_font_size_override("font_size", 11)
	item.add_child(l)


func _draw_swatch(sw: Control, col: Color, dashed: bool) -> void:
	var y: float = roundf(sw.size.y * 0.5)
	if dashed:
		UITheme.dashed_line(sw, Vector2(0.0, y), Vector2(sw.size.x, y), col, 1.5, 4.0, 3.0)
		return
	sw.draw_line(Vector2(0.0, y), Vector2(sw.size.x, y), UITheme.with_alpha(col, 0.25), 5.0, true)
	sw.draw_line(Vector2(0.0, y), Vector2(sw.size.x, y), col, 2.0, true)


## CRISIS RESISTANCES: active evolutions with their counter policies, plus the pressure
## warning that appears before a one-sided strategy provokes a new one.
func _build_resist_section(col: VBoxContainer) -> void:
	var head := _hbox(8)
	col.add_child(head)
	_resist_icon = _icon(_icon_or("evolution", "crisis"), UITheme.TERRACOTTA.lerp(UITheme.CRISIS, 0.4), 16.0)
	head.add_child(_resist_icon)
	_resist_title = _label("HeaderLabel", "hud.resist.title")
	_ellipsis(_resist_title)
	head.add_child(_resist_title)
	_resist_badge = PanelContainer.new()
	_resist_badge.theme_type_variation = &"BadgePanel"
	_resist_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resist_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_resist_count = _label("BadgeLabel")
	_resist_count.text = "0"
	_resist_badge.add_child(_resist_count)
	head.add_child(_resist_badge)

	_resist_list = _vbox(6)
	col.add_child(_resist_list)
	_resist_none = _label("DimLabel", "hud.resist.none")
	_resist_none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_resist_none.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_resist_none.custom_minimum_size = Vector2(220.0, 0.0)
	_resist_list.add_child(_resist_none)

	_resist_more = _label("DimLabel")
	_resist_more.visible = false
	_resist_list.add_child(_resist_more)

	_pressure_box = PanelContainer.new()
	_pressure_box.mouse_filter = Control.MOUSE_FILTER_STOP
	_pressure_box.add_theme_stylebox_override("panel", UITheme.stripe_box(UITheme.WARNING, 0.75))
	_pressure_box.visible = false
	_pressure_box.mouse_entered.connect(_on_pressure_hover)
	_pressure_box.mouse_exited.connect(_hide_tip.bind(_pressure_box))
	col.add_child(_pressure_box)
	var pcol := _vbox(5)
	_pressure_box.add_child(pcol)
	var prow := _hbox(8)
	pcol.add_child(prow)
	_pressure_icon = _icon("warning", UITheme.WARNING, 16.0)
	prow.add_child(_pressure_icon)
	_pressure_label = _label("SmallLabel")
	_pressure_label.add_theme_color_override("font_color", UITheme.WARNING.lerp(Color.WHITE, 0.3))
	_pressure_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pressure_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pressure_label.custom_minimum_size = Vector2(200.0, 0.0)
	prow.add_child(_pressure_label)
	_pressure_bar = Charts.new()
	_pressure_bar.setup_bar("fixed", UITheme.WARNING, 8.0)
	pcol.add_child(_pressure_bar)
	_pressure_bar.set_value(0.0, true)


func _on_pressure_hover() -> void:
	_show_tip(_pressure_box, _pressure_label.text, I18n.t("hud.pressure.hint"), "", "right_of")


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

	_region_trait_box = PanelContainer.new()
	_region_trait_box.theme_type_variation = &"BadgePanel"
	_region_trait_box.add_theme_stylebox_override("panel", UITheme.badge_box(UITheme.WARNING))
	_region_trait_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_region_trait_box.visible = false
	_details.add_child(_region_trait_box)
	var trait_row := _hbox(6)
	_region_trait_box.add_child(trait_row)
	trait_row.add_child(_icon("alert", UITheme.WARNING, 14.0))
	_region_trait_label = _label("BadgeLabel")
	_region_trait_label.add_theme_color_override("font_color", UITheme.WARNING.lerp(Color.WHITE, 0.25))
	_ellipsis(_region_trait_label)
	trait_row.add_child(_region_trait_label)

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

	# Monthly Dynamics Breakdown
	_bd_box = _panel("InsetPanel")
	_bd_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bd_box.visible = false
	_details.add_child(_bd_box)
	var bd_col := _vbox(3)
	_bd_box.add_child(bd_col)
	var bd_head := _hbox(6)
	bd_col.add_child(bd_head)
	bd_head.add_child(_icon("trend_down", UITheme.AMBER, 14.0))
	var bd_title := _label("HeaderLabel", "hud.breakdown.title")
	bd_title.add_theme_font_size_override("font_size", 10)
	bd_title.add_theme_color_override("font_color", UITheme.AMBER.lerp(Color.WHITE, 0.2))
	bd_head.add_child(bd_title)

	var bd_items := [
		["shipping", "hud.breakdown.shipping", UITheme.CRISIS],
		["currents", "hud.breakdown.currents", UITheme.WARNING],
		["coastal", "hud.breakdown.coastal", UITheme.WARNING],
		["heat", "hud.breakdown.heat", UITheme.CRISIS],
		["shield", "hud.breakdown.shield", UITheme.HEALTHY],
		["net", "hud.breakdown.net", UITheme.TEXT],
	]
	for item in bd_items:
		var k: String = item[0]
		var name_key: String = item[1]
		var col_hint: Color = item[2]
		var row := _hbox(4)
		bd_col.add_child(row)
		var lbl := _label("DimLabel", name_key)
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_ellipsis(lbl)
		row.add_child(lbl)
		var val_l := _label("SmallLabel")
		val_l.add_theme_font_override("font", UITheme.mono_bold_font())
		val_l.add_theme_font_size_override("font_size", 10)
		val_l.add_theme_color_override("font_color", col_hint)
		row.add_child(val_l)
		_bd_labels[k] = val_l

	col.add_child(_sep())
	var ops_head := _hbox(8)
	col.add_child(ops_head)
	ops_head.add_child(_icon("patrol", UITheme.AMBER, 18.0))
	var ops_title := _label("HeaderLabel", "hud.actions_title")
	_ellipsis(ops_title)
	ops_head.add_child(ops_title)
	for a in Balance.ACTION_ORDER:
		_build_action_row(col, str(a))
	col.add_child(_sep())
	_build_tree_button(col)


## POLICY TREE button: opens the tree (main.gd decides), shows how many policies are
## adoptable right now and the T hotkey; pressed while the tree is open.
func _build_tree_button(col: VBoxContainer) -> void:
	_tree_btn = Button.new()
	_tree_btn.toggle_mode = true
	_tree_btn.custom_minimum_size = Vector2(0.0, 60.0)
	_wire_button(_tree_btn)
	_tree_btn.mouse_entered.connect(_on_tree_hover)
	_tree_btn.mouse_exited.connect(_hide_tip.bind(_tree_btn))
	_tree_btn.pressed.connect(_on_tree_pressed)
	col.add_child(_tree_btn)
	var row := _hbox(12)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12.0
	row.offset_right = -12.0
	row.offset_top = 6.0
	row.offset_bottom = -6.0
	_tree_btn.add_child(row)
	_tree_icon = _icon(_icon_or("tree", "globe"), UITheme.AMBER, 36.0)
	row.add_child(_tree_icon)
	var mid := _vbox(2)
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(mid)
	var title := _label("HeaderLabel", "hud.tree.button")
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", UITheme.AMBER.lerp(Color.WHITE, 0.25))
	_ellipsis(title)
	mid.add_child(title)
	_tree_status = _label("DimLabel")
	_ellipsis(_tree_status)
	mid.add_child(_tree_status)
	row.add_child(_keycap("T", UITheme.AMBER))


## Keyboard hint chip ("Q", "T") drawn like a small key.
func _keycap(key_text: String, accent: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", UITheme.keycap_box(accent))
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := _label("SmallLabel")
	l.text = key_text
	l.add_theme_font_override("font", UITheme.mono_bold_font())
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", accent.lerp(Color.WHITE, 0.35))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(10.0, 0.0)
	p.add_child(l)
	return p


## preferred if icons.gd draws it already, else a known icon (new ids land in Phase 2).
func _icon_or(preferred: String, fallback: String) -> String:
	return preferred if Icons.IDS.has(preferred) else fallback


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
	var name_row := _hbox(7)
	mid.add_child(name_row)
	var idx: int = Balance.ACTION_ORDER.find(action_id)
	var hotkey: String = ""
	var cap: PanelContainer = null
	if idx >= 0 and idx < ACTION_HOTKEYS.size():
		hotkey = ACTION_HOTKEYS[idx]
		cap = _keycap(hotkey, UITheme.HEALTHY)
		name_row.add_child(cap)
	var name_l := _label("SmallLabel")
	name_l.add_theme_font_override("font", UITheme.mono_bold_font())
	name_l.add_theme_font_size_override("font_size", 15)
	_ellipsis(name_l)
	name_row.add_child(name_l)
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
		"keycap": cap,
		"hotkey": hotkey,
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
	_toast_box.position = Vector2(MARGIN + LEFT_W + 18.0, 1080.0 - 20.0 - TOAST_AREA_H)
	_toast_box.size = Vector2(TOAST_W, 396.0)
	add_child(_toast_box)
	_left_panel.resized.connect(_layout_toasts)


## The toast feed sits in the empty bottom-left corner of the map, right of the BASIN
## STATUS column (which grows with the chart and resistances), clear of the sea regions.
func _layout_toasts() -> void:
	var vh: float = get_viewport_rect().size.y
	_toast_avail = TOAST_AREA_H
	_toast_box.position = Vector2(MARGIN + LEFT_W + 18.0, vh - 20.0 - _toast_avail)
	_toast_box.size = Vector2(TOAST_W, _toast_avail)


## The taller BASIN STATUS panel leaves less room: drop the oldest toast while the feed
## would overflow the screen bottom (one per frame; the freed node leaves next frame).
func _guard_toasts() -> void:
	if _toasts.size() <= 1:
		return
	if _toast_box.get_combined_minimum_size().y <= _toast_avail + 1.0:
		return
	var oldest: Dictionary = _toasts[0]
	var root: Control = oldest["root"]
	_drop_toast(root)
	if is_instance_valid(root) and root.get_parent() == _toast_box:
		_toast_box.remove_child(root)
	_layout_toasts()


# --- Visual Juice: screen vignette & floating feedback ------------------------------------

func _build_vignette() -> void:
	_vignette = Control.new()
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.draw.connect(_draw_vignette)
	add_child(_vignette)


func _draw_vignette() -> void:
	if _vignette_alpha <= 0.005:
		return
	var vp: Vector2 = get_viewport_rect().size
	var w: float = vp.x
	var h: float = vp.y
	var d: float = 200.0
	var col := Color(_vignette_color.r, _vignette_color.g, _vignette_color.b, _vignette_alpha)
	var trans := Color(_vignette_color.r, _vignette_color.g, _vignette_color.b, 0.0)

	_vignette.draw_polygon(
		PackedVector2Array([Vector2(0.0, 0.0), Vector2(w, 0.0), Vector2(w, d), Vector2(0.0, d)]),
		PackedColorArray([col, col, trans, trans])
	)
	_vignette.draw_polygon(
		PackedVector2Array([Vector2(0.0, h), Vector2(w, h), Vector2(w, h - d), Vector2(0.0, h - d)]),
		PackedColorArray([col, col, trans, trans])
	)
	_vignette.draw_polygon(
		PackedVector2Array([Vector2(0.0, 0.0), Vector2(d, 0.0), Vector2(d, h), Vector2(0.0, h)]),
		PackedColorArray([col, trans, trans, col])
	)
	_vignette.draw_polygon(
		PackedVector2Array([Vector2(w, 0.0), Vector2(w - d, 0.0), Vector2(w - d, h), Vector2(w, h)]),
		PackedColorArray([col, trans, trans, col])
	)


func _flash_vignette(col: Color, peak: float = 0.45, duration: float = 1.0) -> void:
	if _vignette == null:
		return
	_vignette_color = col
	_vignette_alpha = peak
	_vignette.queue_redraw()
	if _vignette_tween != null and _vignette_tween.is_valid():
		_vignette_tween.kill()
	_vignette_tween = create_tween()
	_vignette_tween.set_trans(Tween.TRANS_QUAD)
	_vignette_tween.set_ease(Tween.EASE_OUT)
	_vignette_tween.tween_property(self, "_vignette_alpha", 0.0, duration)


func _build_floating_layer() -> void:
	_floating_layer = Control.new()
	_floating_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_floating_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_floating_layer.z_index = 8
	add_child(_floating_layer)


func _spawn_floating_text(text: String, col: Color, global_pos: Vector2, rise: float = 36.0, duration: float = 1.1) -> void:
	if not is_instance_valid(_floating_layer):
		return
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UITheme.mono_bold_font())
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.global_position = global_pos
	_floating_layer.add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_QUAD)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "global_position:y", global_pos.y - rise, duration)
	tw.tween_property(l, "modulate:a", 0.0, duration).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(l.queue_free)


# --- 60-Second Onboarding Briefing --------------------------------------------------------

func _build_onboarding() -> void:
	_onboarding_box = PanelContainer.new()
	_onboarding_box.theme_type_variation = &"HudPanel"
	_onboarding_box.custom_minimum_size = Vector2(360.0, 0.0)
	_onboarding_box.position = Vector2(MARGIN + LEFT_W + 24.0, PANEL_Y)
	_onboarding_box.visible = false
	add_child(_onboarding_box)

	var col := _vbox(6)
	_onboarding_box.add_child(col)

	var head := _hbox(8)
	col.add_child(head)
	head.add_child(_icon("crosshair", UITheme.AMBER, 16.0))
	var title_l := _label("HeaderLabel", "onboarding.title")
	title_l.add_theme_color_override("font_color", UITheme.AMBER)
	title_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_l)

	_onboarding_timer_label = _label("SmallLabel")
	_onboarding_timer_label.add_theme_font_override("font", UITheme.mono_bold_font())
	_onboarding_timer_label.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	_onboarding_timer_label.text = "60s"
	head.add_child(_onboarding_timer_label)

	var dismiss_btn := Button.new()
	dismiss_btn.theme_type_variation = &"ChipButton"
	dismiss_btn.text = "✕"
	dismiss_btn.custom_minimum_size = Vector2(22.0, 22.0)
	dismiss_btn.focus_mode = Control.FOCUS_NONE
	dismiss_btn.pressed.connect(_dismiss_onboarding)
	head.add_child(dismiss_btn)

	col.add_child(_sep())

	_onboarding_steps.clear()
	var step_keys := [
		"onboarding.step1",
		"onboarding.step2",
		"onboarding.step3",
		"onboarding.step4",
	]
	for k in step_keys:
		var key: String = k
		var row := _hbox(8)
		col.add_child(row)
		var ic := _icon("target", UITheme.TEXT_DIM, 14.0)
		row.add_child(ic)
		var sl := _label("BodyLabel", key)
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sl.custom_minimum_size = Vector2(300.0, 0.0)
		row.add_child(sl)
		_onboarding_steps.append({"icon": ic, "label": sl, "key": key})

	_onboarding_done_label = _label("HeaderLabel", "onboarding.done")
	_onboarding_done_label.add_theme_color_override("font_color", UITheme.HEALTHY)
	_onboarding_done_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_onboarding_done_label.visible = false
	col.add_child(_onboarding_done_label)


func _start_onboarding() -> void:
	_onboard_active = true
	_onboard_time_left = 60.0
	_onboard_steps_done = [false, false, false, false]
	if _onboarding_box != null:
		_onboarding_box.visible = true
		_onboarding_box.modulate.a = 1.0
	if _onboarding_done_label != null:
		_onboarding_done_label.visible = false
	_update_onboarding_ui()


func _dismiss_onboarding() -> void:
	if not _onboard_active:
		return
	_onboard_active = false
	if _onboarding_box != null:
		var tw := create_tween()
		tw.tween_property(_onboarding_box, "modulate:a", 0.0, 0.4)
		tw.tween_callback(func() -> void:
			if _onboarding_box != null:
				_onboarding_box.visible = false
		)


func _complete_onboarding_step(idx: int) -> void:
	if not _onboard_active or idx < 0 or idx >= _onboard_steps_done.size():
		return
	if bool(_onboard_steps_done[idx]):
		return
	_onboard_steps_done[idx] = true
	_update_onboarding_ui()

	var all_done: bool = true
	for s in _onboard_steps_done:
		if not bool(s):
			all_done = false
			break
	if all_done:
		_on_all_onboarding_done()


func _update_onboarding_ui() -> void:
	for i in range(mini(_onboarding_steps.size(), _onboard_steps_done.size())):
		var d: Dictionary = _onboarding_steps[i]
		var done: bool = bool(_onboard_steps_done[i])
		var ic: Icons = d["icon"]
		var lb: Label = d["label"]
		if done:
			ic.set_icon("check", UITheme.HEALTHY, 14.0)
			lb.add_theme_color_override("font_color", UITheme.HEALTHY)
		else:
			ic.set_icon("target", UITheme.TEXT_DIM, 14.0)
			lb.add_theme_color_override("font_color", UITheme.TEXT)


func _on_all_onboarding_done() -> void:
	if _onboarding_done_label != null:
		_onboarding_done_label.visible = true
	_flash_vignette(UITheme.HEALTHY, 0.35, 1.0)
	var tw := create_tween()
	tw.tween_interval(2.5)
	tw.tween_property(_onboarding_box, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func() -> void:
		_onboard_active = false
		if _onboarding_box != null:
			_onboarding_box.visible = false
	)


# --- 5-Step Guided Spotlight Tutorial ---------------------------------------------------

func _build_tactical_briefing() -> void:
	_briefing_modal = Control.new()
	_briefing_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_briefing_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_briefing_modal.visible = false
	_briefing_modal.z_index = 25
	add_child(_briefing_modal)

	_briefing_backdrop = Control.new()
	_briefing_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_briefing_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_briefing_backdrop.draw.connect(_on_briefing_backdrop_draw)
	_briefing_modal.add_child(_briefing_backdrop)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(760.0, 500.0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb: StyleBoxFlat = UITheme.panel_box(UITheme.LINE_AMBER, UITheme.with_alpha(UITheme.BG_PANEL, 0.98), 2, UITheme.with_alpha(UITheme.AMBER, 0.2), 24, 16)
	sb.content_margin_left = 32.0
	sb.content_margin_right = 32.0
	sb.content_margin_top = 28.0
	sb.content_margin_bottom = 28.0
	card.add_theme_stylebox_override("panel", sb)
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.anchor_left = 0.5
	card.anchor_top = 0.5
	card.anchor_right = 0.5
	card.anchor_bottom = 0.5
	card.offset_left = -380.0
	card.offset_top = -250.0
	card.offset_right = 380.0
	card.offset_bottom = 250.0
	_briefing_modal.add_child(card)

	var col := _vbox(16)
	card.add_child(col)

	var top := _hbox(12)
	col.add_child(top)
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", UITheme.badge_box(UITheme.AMBER))
	var badge_lbl := _label("BadgeLabel", "tut.title")
	badge.add_child(badge_lbl)
	top.add_child(badge)
	top.add_child(_spacer())
	_briefing_step_label = _label("SmallLabel")
	_briefing_step_label.add_theme_font_override("font", UITheme.mono_bold_font())
	_briefing_step_label.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	top.add_child(_briefing_step_label)

	col.add_child(_sep())

	var content_box := _vbox(12)
	content_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(content_box)

	var card_head := _hbox(12)
	content_box.add_child(card_head)
	_briefing_card_icon = _icon("sea_health", UITheme.AMBER, 34.0)
	card_head.add_child(_briefing_card_icon)
	_briefing_card_title = _label("HeaderLabel")
	_briefing_card_title.add_theme_font_size_override("font_size", 19)
	_briefing_card_title.add_theme_color_override("font_color", UITheme.AMBER.lerp(Color.WHITE, 0.25))
	card_head.add_child(_briefing_card_title)

	_briefing_card_text = RichTextLabel.new()
	_briefing_card_text.bbcode_enabled = true
	_briefing_card_text.fit_content = false
	_briefing_card_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_briefing_card_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_briefing_card_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_briefing_card_text.add_theme_font_override("normal_font", UITheme.body_font())
	_briefing_card_text.add_theme_font_override("bold_font", UITheme.mono_bold_font())
	_briefing_card_text.add_theme_font_size_override("normal_font_size", 15)
	_briefing_card_text.add_theme_font_size_override("bold_font_size", 15)
	_briefing_card_text.add_theme_color_override("default_color", UITheme.TEXT)
	content_box.add_child(_briefing_card_text)

	col.add_child(_sep())

	var btm := _hbox(12)
	col.add_child(btm)
	_briefing_skip_btn = Button.new()
	_briefing_skip_btn.theme_type_variation = &"ChipButton"
	_briefing_skip_btn.text = I18n.t("tut.btn.skip")
	_briefing_skip_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_briefing_skip_btn.pressed.connect(_close_briefing)
	btm.add_child(_briefing_skip_btn)
	btm.add_child(_spacer())

	_briefing_prev_btn = Button.new()
	_briefing_prev_btn.theme_type_variation = &"SecondaryButton"
	_briefing_prev_btn.custom_minimum_size = Vector2(100.0, 36.0)
	_briefing_prev_btn.text = I18n.t("tut.btn.prev")
	_briefing_prev_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_briefing_prev_btn.pressed.connect(_on_briefing_prev)
	btm.add_child(_briefing_prev_btn)

	_briefing_next_btn = Button.new()
	_briefing_next_btn.theme_type_variation = &"PrimaryButton"
	_briefing_next_btn.custom_minimum_size = Vector2(140.0, 36.0)
	_briefing_next_btn.text = I18n.t("tut.btn.next")
	_briefing_next_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_briefing_next_btn.pressed.connect(_on_briefing_next)
	btm.add_child(_briefing_next_btn)


func _on_briefing_backdrop_draw() -> void:
	if _briefing_backdrop == null:
		return
	var r := _briefing_backdrop.get_rect()
	_briefing_backdrop.draw_rect(r, Color(0.02, 0.03, 0.06, 0.82))
	var spot := Rect2()
	match _briefing_step:
		1: spot = Rect2(650, 300, 620, 480)
		2: spot = Rect2(650, 20, 800, 76)
		3: spot = Rect2(10, 420, 370, 300)
		4: spot = Rect2(1640, 950, 260, 90)
		5: spot = Rect2(1440, 20, 380, 76)
	if spot.size != Vector2.ZERO:
		var c := UITheme.with_alpha(UITheme.HEALTHY, 0.85)
		_briefing_backdrop.draw_rect(spot, UITheme.with_alpha(UITheme.HEALTHY, 0.08))
		_briefing_backdrop.draw_rect(spot, c, false, 2.0)
		var blen: float = 16.0
		_briefing_backdrop.draw_line(spot.position, spot.position + Vector2(blen, 0), c, 3.0)
		_briefing_backdrop.draw_line(spot.position, spot.position + Vector2(0, blen), c, 3.0)
		_briefing_backdrop.draw_line(Vector2(spot.end.x, spot.position.y), Vector2(spot.end.x - blen, spot.position.y), c, 3.0)
		_briefing_backdrop.draw_line(Vector2(spot.end.x, spot.position.y), Vector2(spot.end.x, spot.position.y + blen), c, 3.0)
		_briefing_backdrop.draw_line(spot.end, spot.end - Vector2(blen, 0), c, 3.0)
		_briefing_backdrop.draw_line(spot.end, spot.end - Vector2(0, blen), c, 3.0)
		_briefing_backdrop.draw_line(Vector2(spot.position.x, spot.end.y), Vector2(spot.position.x + blen, spot.end.y), c, 3.0)
		_briefing_backdrop.draw_line(Vector2(spot.position.x, spot.end.y), Vector2(spot.position.x, spot.end.y - blen), c, 3.0)


func _show_tactical_briefing() -> void:
	_briefing_step = 1
	_briefing_modal.visible = true
	GameState.set_pause_reason("briefing", true)
	_update_briefing_card()


func _close_briefing() -> void:
	_briefing_modal.visible = false
	GameState.set_pause_reason("briefing", false)
	_start_onboarding()


func _on_briefing_prev() -> void:
	if _briefing_step > 1:
		_briefing_step -= 1
		_update_briefing_card()


func _on_briefing_next() -> void:
	if _briefing_step < 5:
		_briefing_step += 1
		_update_briefing_card()
	else:
		_close_briefing()


func _update_briefing_card() -> void:
	_briefing_step_label.text = I18n.t("briefing.step_fmt", {"cur": str(_briefing_step), "total": "5"})
	_briefing_prev_btn.disabled = _briefing_step <= 1
	if _briefing_step >= 5:
		_briefing_next_btn.text = I18n.t("tut.btn.start")
	else:
		_briefing_next_btn.text = I18n.t("tut.btn.next")
	_briefing_skip_btn.text = I18n.t("tut.btn.skip")
	_briefing_prev_btn.text = I18n.t("tut.btn.prev")
	match _briefing_step:
		1:
			_briefing_card_icon.set_icon("sea_health", UITheme.AMBER, 34.0)
			_briefing_card_title.text = I18n.t("tut.step1.title")
			_briefing_card_text.text = I18n.t("tut.step1.body")
		2:
			_briefing_card_icon.set_icon("budget", UITheme.AMBER, 34.0)
			_briefing_card_title.text = I18n.t("tut.step2.title")
			_briefing_card_text.text = I18n.t("tut.step2.body")
		3:
			_briefing_card_icon.set_icon("clean", UITheme.HEALTHY, 34.0)
			_briefing_card_title.text = I18n.t("tut.step3.title")
			_briefing_card_text.text = I18n.t("tut.step3.body")
		4:
			_briefing_card_icon.set_icon("tree", UITheme.SCIENCE_BLUE, 34.0)
			_briefing_card_title.text = I18n.t("tut.step4.title")
			_briefing_card_text.text = I18n.t("tut.step4.body")
		5:
			_briefing_card_icon.set_icon("warning", UITheme.CRISIS, 34.0)
			_briefing_card_title.text = I18n.t("tut.step5.title")
			_briefing_card_text.text = I18n.t("tut.step5.body")
	if _briefing_backdrop != null:
		_briefing_backdrop.queue_redraw()


# --- COP31 Diplomatic Summits Modal (2031, 2036, 2041) -----------------------------------

func _build_summit_modal() -> void:
	_summit_modal = Control.new()
	_summit_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_summit_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_summit_modal.visible = false
	_summit_modal.z_index = 30
	add_child(_summit_modal)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.015, 0.025, 0.05, 0.88)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_summit_modal.add_child(backdrop)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(820.0, 520.0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb: StyleBoxFlat = UITheme.panel_box(UITheme.LINE_AMBER, UITheme.with_alpha(UITheme.BG_PANEL, 0.98), 2, UITheme.with_alpha(UITheme.AMBER, 0.25), 24, 16)
	sb.content_margin_left = 36.0
	sb.content_margin_right = 36.0
	sb.content_margin_top = 30.0
	sb.content_margin_bottom = 30.0
	card.add_theme_stylebox_override("panel", sb)
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.anchor_left = 0.5
	card.anchor_top = 0.5
	card.anchor_right = 0.5
	card.anchor_bottom = 0.5
	card.offset_left = -410.0
	card.offset_top = -260.0
	card.offset_right = 410.0
	card.offset_bottom = 260.0
	_summit_modal.add_child(card)

	var col := _vbox(16)
	card.add_child(col)

	var top := _hbox(12)
	col.add_child(top)
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", UITheme.badge_box(UITheme.AMBER))
	var badge_lbl := _label("BadgeLabel", "summit.modal.title")
	badge.add_child(badge_lbl)
	top.add_child(badge)
	top.add_child(_spacer())

	_summit_badge_panel = PanelContainer.new()
	_summit_badge_label = _label("BadgeLabel")
	_summit_badge_panel.add_child(_summit_badge_label)
	top.add_child(_summit_badge_panel)

	col.add_child(_sep())

	_summit_title_label = _label("HeaderLabel")
	_summit_title_label.add_theme_font_size_override("font_size", 22)
	_summit_title_label.add_theme_color_override("font_color", UITheme.AMBER.lerp(Color.WHITE, 0.3))
	col.add_child(_summit_title_label)

	_summit_desc_text = RichTextLabel.new()
	_summit_desc_text.bbcode_enabled = true
	_summit_desc_text.fit_content = false
	_summit_desc_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_summit_desc_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_summit_desc_text.add_theme_font_override("normal_font", UITheme.body_font())
	_summit_desc_text.add_theme_font_size_override("normal_font_size", 16)
	_summit_desc_text.add_theme_color_override("default_color", UITheme.TEXT)
	col.add_child(_summit_desc_text)

	col.add_child(_sep())

	var opt_row := _hbox(18)
	opt_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(opt_row)

	# Option A
	var card_a := PanelContainer.new()
	card_a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb_a := UITheme.panel_box(UITheme.LINE, UITheme.with_alpha(UITheme.DEEP, 0.8), 1, Color(0,0,0,0), 0, 10)
	sb_a.content_margin_left = 16.0; sb_a.content_margin_right = 16.0
	sb_a.content_margin_top = 14.0; sb_a.content_margin_bottom = 14.0
	card_a.add_theme_stylebox_override("panel", sb_a)
	opt_row.add_child(card_a)
	var col_a := _vbox(8)
	card_a.add_child(col_a)
	_summit_opt_a_title = _label("HeaderLabel")
	_summit_opt_a_title.add_theme_font_size_override("font_size", 16)
	_summit_opt_a_title.add_theme_color_override("font_color", UITheme.HEALTHY)
	col_a.add_child(_summit_opt_a_title)
	_summit_opt_a_desc = _label("SmallLabel")
	_summit_opt_a_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summit_opt_a_desc.custom_minimum_size = Vector2(0.0, 48.0)
	_summit_opt_a_desc.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	col_a.add_child(_summit_opt_a_desc)
	_summit_opt_a_btn = Button.new()
	_summit_opt_a_btn.theme_type_variation = &"PrimaryButton"
	_summit_opt_a_btn.text = I18n.t("summit.btn.ratify")
	_summit_opt_a_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_summit_opt_a_btn.pressed.connect(_on_summit_choice.bind(0))
	col_a.add_child(_summit_opt_a_btn)

	# Option B
	var card_b := PanelContainer.new()
	card_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb_b := UITheme.panel_box(UITheme.LINE_AMBER, UITheme.with_alpha(UITheme.DEEP, 0.8), 1, Color(0,0,0,0), 0, 10)
	sb_b.content_margin_left = 16.0; sb_b.content_margin_right = 16.0
	sb_b.content_margin_top = 14.0; sb_b.content_margin_bottom = 14.0
	card_b.add_theme_stylebox_override("panel", sb_b)
	opt_row.add_child(card_b)
	var col_b := _vbox(8)
	card_b.add_child(col_b)
	_summit_opt_b_title = _label("HeaderLabel")
	_summit_opt_b_title.add_theme_font_size_override("font_size", 16)
	_summit_opt_b_title.add_theme_color_override("font_color", UITheme.AMBER)
	col_b.add_child(_summit_opt_b_title)
	_summit_opt_b_desc = _label("SmallLabel")
	_summit_opt_b_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summit_opt_b_desc.custom_minimum_size = Vector2(0.0, 48.0)
	_summit_opt_b_desc.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	col_b.add_child(_summit_opt_b_desc)
	_summit_opt_b_btn = Button.new()
	_summit_opt_b_btn.theme_type_variation = &"SecondaryButton"
	_summit_opt_b_btn.text = I18n.t("summit.btn.ratify")
	_summit_opt_b_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_summit_opt_b_btn.pressed.connect(_on_summit_choice.bind(1))
	col_b.add_child(_summit_opt_b_btn)


func _on_summit_triggered(data: Dictionary) -> void:
	_current_summit_data = data
	_summit_modal.visible = true
	var passed: bool = bool(data.get("passed", true))
	var badge_col: Color = UITheme.HEALTHY if passed else UITheme.AMBER
	_summit_badge_panel.add_theme_stylebox_override("panel", UITheme.badge_box(badge_col))
	_summit_badge_label.text = I18n.t("summit.status.success" if passed else "summit.status.warning")
	_summit_badge_label.add_theme_color_override("font_color", badge_col)

	_summit_title_label.text = I18n.t(str(data.get("title_key", "")))
	_summit_desc_text.text = I18n.t(str(data.get("desc_key", "")))
	_summit_opt_a_title.text = I18n.t(str(data.get("opt_a_name", "")))
	_summit_opt_a_desc.text = I18n.t(str(data.get("opt_a_desc", "")))
	_summit_opt_b_title.text = I18n.t(str(data.get("opt_b_name", "")))
	_summit_opt_b_desc.text = I18n.t(str(data.get("opt_b_desc", "")))
	AudioSynth.play_policy_adopt()


func _on_summit_choice(choice_idx: int) -> void:
	_summit_modal.visible = false
	GameState.resolve_summit(choice_idx)
	AudioSynth.play_policy_adopt()


func _build_tip() -> void:
	_tip_panel = PanelContainer.new()
	_tip_panel.theme_type_variation = &"TipPanel"
	_tip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_panel.custom_minimum_size = Vector2(360.0, 0.0)
	_tip_panel.visible = false
	_tip_panel.z_index = 10
	add_child(_tip_panel)
	var col := _vbox(5)
	_tip_panel.add_child(col)
	_tip_title = _label("TipTitleLabel")
	_tip_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_title.custom_minimum_size = Vector2(330.0, 0.0)
	col.add_child(_tip_title)
	_tip_body = RichTextLabel.new()
	_tip_body.bbcode_enabled = true
	_tip_body.fit_content = true
	_tip_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_body.custom_minimum_size = Vector2(330.0, 0.0)
	_tip_body.add_theme_font_override("normal_font", UITheme.body_font())
	_tip_body.add_theme_font_override("bold_font", UITheme.mono_bold_font())
	_tip_body.add_theme_font_size_override("normal_font_size", 12)
	_tip_body.add_theme_font_size_override("bold_font_size", 12)
	_tip_body.add_theme_color_override("default_color", UITheme.TEXT)
	col.add_child(_tip_body)
	_tip_meta = _label("DimLabel")
	_tip_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_meta.custom_minimum_size = Vector2(330.0, 0.0)
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
	elif _tip_side == "under_panel":
		# Below the REGION panel, clear of the sea regions (east edge ~x 1465 at 1080p).
		p = Vector2(_right_panel.position.x + (_right_panel.size.x - ts.x) * 0.5, _right_panel.position.y + _right_panel.size.y + 10.0)
	elif _tip_side == "right_of":
		# Next to the BASIN STATUS panel (resistance rows).
		p = Vector2(_left_panel.position.x + _left_panel.size.x + 14.0, op.y)
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
	var meta: String = I18n.t("hud.cost_line", {"list": ", ".join(parts)})
	var idx: int = Balance.ACTION_ORDER.find(action_id)
	if idx >= 0 and idx < ACTION_HOTKEYS.size():
		meta += "\n" + I18n.t("hud.key_hint", {"key": str(ACTION_HOTKEYS[idx])})
	_show_tip(btn, I18n.t(str(def.get("name_key", ""))), I18n.t(str(def.get("desc_key", ""))), meta, "under_panel")


func _on_res_hover(block: Control, key: String) -> void:
	var title: String = I18n.t(str(RES_KEYS[key]))
	var tip_k: String = "res.%s.tip" % key
	var body: String = I18n.t(tip_k) if I18n.has_key(tip_k) else I18n.t("hud.rate.tip")
	if key == "budget" and _budget_negative:
		body += "\n\n" + I18n.t("hud.rate.tip_negative")
	var meta: String = ""
	if _rate_values.has(key):
		meta = I18n.t("hud.rate.monthly", {"v": _signed(float(_rate_values[key]))})
	_show_tip(block, title, body, meta, "below")


func _on_species_hover(block: Control) -> void:
	var title: String = I18n.t("hud.species.title")
	var body: String = I18n.t("hud.species.turtle.desc") + "\n\n" + I18n.t("hud.species.seal.desc")
	_show_tip(block, title, body, I18n.t("hud.species.tip"), "below")


func _on_defcon_hover(block: Control) -> void:
	var title: String = I18n.t("hud.defcon.title")
	var body: String = I18n.t("hud.defcon." + str(_defcon_level) + ".desc")
	var meta: String = I18n.t("hud.defcon." + str(_defcon_level))
	_show_tip(block, title, body, meta, "below")


func _on_hq_hover(block: Control) -> void:
	var title: String = I18n.t("hud.antalya_hq.title")
	var lim: int = roundi(float(_snap.get("antalya_limit", 85.0)))
	var integ: int = roundi(float(_snap.get("antalya_integrity", 100.0)))
	var body: String = I18n.t("hud.antalya_hq.desc", {"limit": str(lim), "integrity": str(integ)})
	var meta: String = "Status: %d%% Integrity" % integ
	_show_tip(block, title, body, meta, "below")


func _on_audio_hover(block: Control) -> void:
	var key: String = "hud.btn.mute_on" if AudioSynth.is_muted else "hud.btn.mute_off"
	_show_tip(block, I18n.t(key), "", "", "below")


func _on_help_hover(block: Control) -> void:
	_show_tip(block, I18n.t("hud.btn.help"), "", I18n.t("hud.key_hint", {"key": "H"}), "below")


func _on_audio_toggle() -> void:
	AudioSynth.toggle_mute()
	if _audio_btn != null:
		_audio_btn.text = "🔇" if AudioSynth.is_muted else "🔊"


func _update_defcon(level: int) -> void:
	_defcon_level = level
	if _defcon_label == null:
		return
	_defcon_label.text = "DEFCON %d" % level
	var c: Color = UITheme.HEALTHY
	match level:
		5: c = UITheme.HEALTHY
		4: c = UITheme.WARNING
		3: c = UITheme.AMBER
		2: c = UITheme.CRISIS.lerp(UITheme.AMBER, 0.4)
		1: c = UITheme.CRISIS
	_defcon_label.add_theme_color_override("font_color", c)
	_defcon_badge.add_theme_stylebox_override("panel", UITheme.badge_box(c))


func _update_antalya_hq(integrity: float, _limit: float) -> void:
	if _antalya_hq_label == null:
		return
	var i_val: int = clampi(roundi(integrity), 0, 100)
	_antalya_hq_label.text = "HQ: %d%%" % i_val
	var c: Color = UITheme.HEALTHY
	if i_val < 35:
		c = UITheme.CRISIS
	elif i_val < 65:
		c = UITheme.AMBER
	_antalya_hq_label.add_theme_color_override("font_color", c)
	_antalya_hq_chip.add_theme_stylebox_override("panel", UITheme.badge_box(c))


func _update_species(turtles: int, seals: int) -> void:
	if _turtle_count != null:
		_turtle_count.text = str(turtles)
	if _seal_count != null:
		_seal_count.text = str(seals)


func _update_difficulty_badge(diff_id: String) -> void:
	if _diff_badge_label == null:
		return
	var d_def: Dictionary = Balance.DIFFICULTIES.get(diff_id, {})
	var badge: String = str(d_def.get("badge", diff_id.to_upper()))
	_diff_badge_label.text = badge


func _on_tree_hover() -> void:
	_show_tip(_tree_btn, I18n.t("hud.tree.button"), I18n.t("hud.tree.tip"), I18n.t("hud.key_hint", {"key": "T"}), "under_panel")


func _on_resist_hover(row: Control, evo_id: String) -> void:
	var def: Dictionary = TechTree.evolution_def(evo_id)
	var desc_key: String = str(def.get("desc_key", ""))
	var body: String = I18n.t(desc_key) if desc_key != "" and I18n.has_key(desc_key) else ""
	_show_tip(row, _evo_name(evo_id), body, _counter_text(evo_id), "right_of")


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
	_local_hist.clear()
	_chart.reset_series()
	_rate_values.clear()
	_set_budget_negative(false)
	_neg_ticks = 0
	_pos_ticks = 0
	_neg_warned = false
	_resist_ids.clear()
	_refresh_resistances(false)
	_pressure_branch = ""
	_update_pressure()
	_update_tree_status()
	_update_defcon(5)
	_update_antalya_hq(100.0, float(_snap.get("antalya_limit", 85.0)))
	_update_species(int(_snap.get("turtle_nests", 0)), int(_snap.get("monk_seals", 0)))
	_update_difficulty_badge(str(_snap.get("difficulty", GameState.selected_difficulty)))
	if _audio_btn != null:
		_audio_btn.text = "🔇" if AudioSynth.is_muted else "🔊"
	_show_tactical_briefing()


func _on_tick_done(snapshot: Dictionary) -> void:
	_snap = snapshot
	_update_time_labels()
	_update_chart(snapshot)
	_update_rates(snapshot)
	_update_pressure()
	_update_tree_status()
	_update_defcon(int(snapshot.get("defcon", 5)))
	_update_antalya_hq(float(snapshot.get("antalya_integrity", 100.0)), float(snapshot.get("antalya_limit", 85.0)))
	_update_species(int(snapshot.get("turtle_nests", 0)), int(snapshot.get("monk_seals", 0)))
	_update_difficulty_badge(str(snapshot.get("difficulty", GameState.selected_difficulty)))
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
	var m: int = int(_snap.get("month_int", 1))
	var left: int = int(_snap.get("years_left", Balance.END_YEAR - Balance.START_YEAR))
	var m_str: String = "%02d" % m
	_year_label.text = I18n.t("hud.month_fmt", {"year": str(y), "month": m_str})
	_years_left_label.text = I18n.t("hud.years_left", {"n": str(left)})


# --- Phase 2: live chart, net income, resistances, pressure, policy tree ----------------------

func _update_chart(snap: Dictionary) -> void:
	if snap.is_empty():
		return
	var tick: int = int(snap.get("tick", 0))
	var sh: float = float(snap.get("sea_health", 0.0))
	var cr: float = float(snap.get("crisis", 0.0))
	var need_sample: bool = true
	if not _local_hist.is_empty():
		var last: Array = _local_hist[_local_hist.size() - 1]
		var last_tick: int = int(last[0])
		if tick < last_tick:
			_local_hist.clear()
		elif tick - last_tick < HISTORY_EVERY:
			need_sample = false
	if need_sample:
		_local_hist.append([tick, sh, cr])
	var hist: Array = GameState.get_history()
	if hist.is_empty():
		hist = _local_hist
	_chart.set_series(hist, tick, sh, cr)


static func _ticks_per_year() -> float:
	return float(Balance.TOTAL_TICKS) / float(maxi(Balance.END_YEAR - Balance.START_YEAR, 1))


static func _signed(v: float) -> String:
	var a: float = absf(v)
	var body: String = str(roundi(a)) if a >= 9.95 else "%.1f" % a
	if body == "0" or body == "0.0":
		return "0"
	return ("+" if v > 0.0 else "-") + body


## Net income per month beside each resource (snapshot *_rate keys; hidden until the
## simulation provides them). Negative budget income pulses red and warns once.
func _update_rates(snap: Dictionary, count_ticks: bool = true) -> void:
	for k in RES_ORDER:
		var key: String = k
		var rl: Label = _rate_labels[key]
		var sk: String = RATE_KEYS[key]
		if not snap.has(sk):
			rl.visible = false
			_rate_values.erase(key)
			continue
		var per_month: float = float(snap[sk])
		_rate_values[key] = per_month
		rl.visible = true
		rl.text = "(%s)" % I18n.t("hud.rate.monthly", {"v": _signed(per_month)})
		var c: Color = UITheme.TEXT_DIM
		if per_month >= 0.05:
			c = UITheme.HEALTHY.lerp(Color.WHITE, 0.2)
		elif per_month <= -0.05:
			c = UITheme.CRISIS.lerp(Color.WHITE, 0.15)
		rl.add_theme_color_override("font_color", c)
	var neg: bool = _rate_values.has("budget") and float(_rate_values["budget"]) <= -0.05
	_set_budget_negative(neg)
	if not count_ticks:
		return
	if neg:
		_neg_ticks += 1
		_pos_ticks = 0
		if _neg_ticks >= NEG_INCOME_WARN_TICKS and not _neg_warned and _is_shown:
			_neg_warned = true
			EventBus.toast.emit("hud.toast.income_negative", {}, 2)
	else:
		_neg_ticks = 0
		_pos_ticks += 1
		if _pos_ticks >= NEG_INCOME_REARM_TICKS:
			_neg_warned = false


func _set_budget_negative(on: bool) -> void:
	if on == _budget_negative:
		return
	_budget_negative = on
	if not on:
		var bl: Label = _res_labels["budget"]
		bl.self_modulate = Color.WHITE
		var rl: Label = _rate_labels["budget"]
		rl.self_modulate = Color.WHITE
		var ic: Icons = _res_icons["budget"]
		ic.self_modulate = Color.WHITE


func _evo_name(evo_id: String) -> String:
	var def: Dictionary = TechTree.evolution_def(evo_id)
	var nk: String = str(def.get("name_key", ""))
	if nk != "":
		return I18n.t(nk)
	return evo_id


## "Countered by: A, B, C" from the policy nodes that list this evolution in "counters".
func _counter_text(evo_id: String) -> String:
	var names := PackedStringArray()
	for n in TechTree.counters_of(evo_id):
		var node_def: Dictionary = TechTree.node_def(str(n))
		var nk: String = str(node_def.get("name_key", ""))
		if nk == "":
			continue
		if names.size() >= MAX_RESIST_COUNTERS:
			names.append("…")
			break
		names.append(I18n.t(nk))
	if names.is_empty():
		return I18n.t("hud.resist.counter_unknown")
	return I18n.t("hud.resist.counter", {"list": ", ".join(names)})


## Rebuilds the resistance rows from GameState.active_evolutions(); animate marks new ones.
## Shows the newest MAX_RESIST_ROWS, then an "Also active: N" line for the rest.
func _refresh_resistances(animate: bool) -> void:
	if _resist_list == null:
		return
	var ids: Array = GameState.active_evolutions()
	for child in _resist_list.get_children():
		var c: Node = child
		if c != _resist_none and c != _resist_more:
			_resist_list.remove_child(c)
			c.queue_free()
	_resist_none.visible = ids.is_empty()
	var first: int = maxi(0, ids.size() - MAX_RESIST_ROWS)
	for i in range(ids.size() - 1, first - 1, -1):
		var evo_id: String = str(ids[i])
		var fresh: bool = animate and not _resist_ids.has(evo_id)
		_build_resist_row(evo_id, fresh)
	_resist_more.visible = first > 0
	if first > 0:
		_resist_more.text = I18n.t("hud.resist.more", {"n": str(first)})
	_resist_list.move_child(_resist_more, _resist_list.get_child_count() - 1)
	_resist_ids = ids.duplicate()
	_resist_count.text = str(ids.size())
	var bc: Color = UITheme.CRISIS if not ids.is_empty() else UITheme.TEXT_DIM
	_resist_badge.add_theme_stylebox_override("panel", UITheme.badge_box(bc))
	_resist_count.add_theme_color_override("font_color", bc.lerp(Color.WHITE, 0.3))
	call_deferred("_shrink_panels")


func _build_resist_row(evo_id: String, fresh: bool) -> void:
	var def: Dictionary = TechTree.evolution_def(evo_id)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", UITheme.stripe_box(UITheme.CRISIS, 0.7))
	panel.mouse_entered.connect(_on_resist_hover.bind(panel, evo_id))
	panel.mouse_exited.connect(_hide_tip.bind(panel))
	_resist_list.add_child(panel)
	var row := _hbox(10)
	panel.add_child(row)
	var icon_id: String = str(def.get("icon", ""))
	if not Icons.IDS.has(icon_id):
		icon_id = _icon_or("evolution", "crisis")
	row.add_child(_icon(icon_id, UITheme.CRISIS.lerp(Color.WHITE, 0.15), 24.0))
	var txt := _vbox(1)
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(txt)
	var name_l := _label("SmallLabel")
	name_l.add_theme_font_override("font", UITheme.mono_bold_font())
	name_l.add_theme_color_override("font_color", UITheme.CRISIS.lerp(Color.WHITE, 0.45))
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.custom_minimum_size = Vector2(200.0, 0.0)
	name_l.text = _evo_name(evo_id)
	txt.add_child(name_l)
	var hint := _label("DimLabel")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(200.0, 0.0)
	hint.text = _counter_text(evo_id)
	txt.add_child(hint)
	if fresh:
		panel.modulate = Color(2.2, 1.4, 1.4, 0.0)
		var tw := panel.create_tween()
		tw.set_trans(Tween.TRANS_CUBIC)
		tw.set_ease(Tween.EASE_OUT)
		tw.tween_property(panel, "modulate", Color(1.6, 1.0, 1.0, 1.0), 0.25)
		tw.tween_property(panel, "modulate", Color.WHITE, 0.8)


func _branch_evolution_active(branch: String, active: Array) -> bool:
	for e in TechTree.all_evolutions():
		var def: Dictionary = e
		if str(def.get("trigger", "")) == "branch" and str(def.get("branch", "")) == branch and active.has(str(def.get("id", ""))):
			return true
	return false


func _branch_name(branch: String) -> String:
	var key: String = "hud.branch." + branch
	if I18n.has_key(key):
		return I18n.t(key)
	var info: Dictionary = TechTree.BRANCH_INFO.get(branch, {})
	return I18n.t(str(info.get("name_key", key)))


## Warns before a one-sided strategy provokes a resistance (GameState.evolution_pressure()).
func _update_pressure() -> void:
	if _pressure_box == null:
		return
	var p: Dictionary = GameState.evolution_pressure()
	var shares: Dictionary = p.get("shares", {})
	var threshold: float = float(p.get("threshold", 1.0))
	var moves: int = int(p.get("moves", 0))
	var min_moves: int = int(p.get("min_moves", 1))
	var active: Array = GameState.active_evolutions()
	var best_branch: String = ""
	var best: float = 0.0
	for b in shares.keys():
		var branch: String = str(b)
		var share: float = float(shares[b])
		if _branch_evolution_active(branch, active):
			continue
		if share > best:
			best = share
			best_branch = branch
	var need_moves: int = maxi(2, int(ceilf(float(min_moves) * 0.6)))
	var want: bool = GameState.running and best_branch != "" and threshold > 0.0 \
		and moves >= need_moves and best >= threshold * 0.8
	if want:
		_pressure_label.text = I18n.t("hud.pressure.warn", {"branch": _branch_name(best_branch)})
		_pressure_bar.markers = [threshold * 100.0]
		_pressure_bar.set_value(best * 100.0)
		_pressure_bar.alert = best >= threshold
	if want != _pressure_box.visible:
		_pressure_box.visible = want
		if want:
			_pressure_box.modulate = Color(1.8, 1.6, 1.0, 0.0)
			var tw := _pressure_box.create_tween()
			tw.tween_property(_pressure_box, "modulate", Color.WHITE, 0.5)
		call_deferred("_shrink_panels")
	_pressure_branch = best_branch if want else ""


func _count_adoptable() -> int:
	var n: int = 0
	for nd in TechTree.all_nodes():
		var def: Dictionary = nd
		if GameState.can_adopt(str(def.get("id", ""))):
			n += 1
	return n


func _update_tree_status() -> void:
	if _tree_status == null:
		return
	_adoptable = _count_adoptable() if GameState.running else 0
	if _adoptable > 0:
		_tree_status.text = I18n.t("hud.tree.available", {"n": str(_adoptable)})
		_tree_status.add_theme_color_override("font_color", UITheme.HEALTHY.lerp(Color.WHITE, 0.2))
	else:
		_tree_status.text = I18n.t("hud.tree.none")
		_tree_status.add_theme_color_override("font_color", UITheme.TEXT_DIM)


func _on_tree_pressed() -> void:
	_hide_tip_now()
	EventBus.tree_toggle_requested.emit()
	# main.gd may refuse (event card open): keep the button in step with the real state.
	_tree_btn.set_pressed_no_signal(_tree_open)


func _on_tree_toggled(is_open: bool) -> void:
	_tree_open = is_open
	_tree_btn.set_pressed_no_signal(is_open)
	_hide_tip_now()
	if not is_open:
		_update_tree_status()


func _on_node_adopted(_node_id: String) -> void:
	_update_tree_status()
	_update_pressure()
	_complete_onboarding_step(2)
	_flash_vignette(UITheme.HEALTHY, 0.40, 1.0)


func _on_evolution_happened(_evolution_id: String) -> void:
	_refresh_resistances(true)
	_update_pressure()
	_resist_flash = 1.0
	_flash_vignette(UITheme.CRISIS, 0.45, 1.2)


func _on_evolution_cured(_evolution_id: String) -> void:
	_refresh_resistances(false)
	_update_pressure()
	_flash_vignette(UITheme.HEALTHY, 0.45, 1.2)


func _on_spread_happened(_from_id: String, _to_id: String) -> void:
	_flash_vignette(UITheme.CRISIS, 0.35, 0.8)


func _on_bubble_collected(_bubble_id: int, kind: String, amount: float) -> void:
	_complete_onboarding_step(1)
	var vs: Vector2 = get_viewport_rect().size
	var pos := Vector2(vs.x * 0.5 - 40.0, vs.y * 0.45)
	var col: Color = RES_COLORS.get(kind, UITheme.HEALTHY)
	var rname: String = I18n.t("hud." + kind) if RES_KEYS.has(kind) else kind.capitalize()
	_spawn_floating_text("+%d %s" % [roundi(amount), rname], col, pos, 45.0, 1.3)


func _on_resources_changed(budget: float, political: float, science: float) -> void:
	var values: Dictionary = {"budget": budget, "political": political, "science": science}
	for k in RES_ORDER:
		var key: String = k
		var nv: float = values[key]
		var old: float = _res_target[key]
		_res_target[key] = nv
		var l: Label = _res_labels[key]
		var diff: float = nv - old
		if nv < old - 0.5:
			_flash_label(l, UITheme.CRISIS)
			if absf(diff) >= 1.0:
				_spawn_floating_text("%d" % roundi(diff), UITheme.CRISIS, l.global_position + Vector2(10.0, 24.0))
		elif nv > old + 4.0:
			_flash_label(l, UITheme.HEALTHY)
			if absf(diff) >= 1.0:
				_spawn_floating_text("+%d" % roundi(diff), UITheme.HEALTHY, l.global_position + Vector2(10.0, 24.0))
	_refresh_actions()


func _flash_label(l: Label, col: Color) -> void:
	l.modulate = col.lerp(Color.WHITE, 0.25)
	var tw := l.create_tween()
	tw.tween_property(l, "modulate", Color.WHITE, 0.6)


func _on_region_selected(region_id: String) -> void:
	_select_region(region_id)


func _select_region(region_id: String) -> void:
	_selected = region_id
	if region_id != "":
		_complete_onboarding_step(0)
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
	_coastal_value.text = I18n.t("fmt.pct", {"v": str(roundi(float(data.get("coastal_pop", 0.0)) * 100.0))})

	var trait_k: String = str(data.get("trait_key", ""))
	if trait_k != "" and I18n.has_key(trait_k):
		_region_trait_label.text = I18n.t(trait_k)
		_region_trait_box.visible = true
	else:
		_region_trait_box.visible = false

	var bd: Dictionary = data.get("breakdown", {})
	if not bd.is_empty():
		_bd_box.visible = true
		if _bd_labels.has("shipping"):
			_bd_labels["shipping"].text = "+%.1f" % float(bd.get("shipping", 0.0))
		if _bd_labels.has("currents"):
			_bd_labels["currents"].text = "+%.1f" % float(bd.get("currents", 0.0))
		if _bd_labels.has("coastal"):
			_bd_labels["coastal"].text = "+%.1f" % float(bd.get("coastal", 0.0))
		if _bd_labels.has("heat"):
			_bd_labels["heat"].text = "+%.1f" % float(bd.get("heat", 0.0))
		if _bd_labels.has("shield"):
			_bd_labels["shield"].text = "-%.1f" % float(bd.get("shield", 0.0))
		if _bd_labels.has("net"):
			var net_val: float = float(bd.get("net", 0.0))
			_bd_labels["net"].text = ("+" if net_val >= 0.0 else "") + "%.1f/ay" % net_val
			var net_col: Color = UITheme.CRISIS if net_val > 0.05 else (UITheme.HEALTHY if net_val < -0.05 else UITheme.TEXT_DIM)
			_bd_labels["net"].add_theme_color_override("font_color", net_col)
	else:
		_bd_box.visible = false


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
			# action_cooldown_left() is in 1x seconds; show real seconds at 2x / 4x.
			var mult: float = Balance.SPEEDS[GameState.speed_index]
			if mult > 0.0:
				cd_left /= mult
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
			key = "hud.action.unavailable"
			scol = UITheme.TEXT_DIM
		status_l.text = I18n.t(key, args)
		status_l.add_theme_color_override("font_color", scol)
		if btn.disabled == can:
			btn.disabled = not can
			if btn.disabled:
				UITheme.reset_fx(btn)
		ic.color = UITheme.HEALTHY if can else UITheme.with_alpha(UITheme.TEXT_DIM, 0.55)
		var cap: PanelContainer = row["keycap"]
		if cap != null:
			cap.modulate.a = 1.0 if can else 0.4
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
	_hide_tip_now()   # never leave the tip over the map while the action pulse plays
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
		var bpos: Vector2 = btn.global_position + Vector2(24.0, -8.0)
		var def: Dictionary = Balance.ACTIONS.get(action_id, {})
		var act_name: String = I18n.t(str(def.get("name_key", action_id)))
		_spawn_floating_text(act_name, UITheme.HEALTHY, bpos, 35.0, 1.1)
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
	_on_speed_changed(GameState.speed_index)


func _on_speed_changed(speed_index: int) -> void:
	for i in _speed_buttons.size():
		var btn: Button = _speed_buttons[i]
		var active: bool = i == speed_index
		btn.set_pressed_no_signal(active)
		var accent: Color = UITheme.WARNING if i == 0 else UITheme.HEALTHY
		var fg: Color = accent.lerp(Color.WHITE, 0.35) if active else UITheme.TEXT_DIM.lerp(UITheme.TEXT, 0.35)
		if active:
			var act_sb: StyleBoxFlat = UITheme.panel_box(accent, UITheme.with_alpha(UITheme.BG_PANEL.lerp(accent, 0.42), 0.96), 2, UITheme.with_alpha(accent, 0.45), 10, 8)
			act_sb.content_margin_left = 10.0
			act_sb.content_margin_right = 10.0
			act_sb.content_margin_top = 6.0
			act_sb.content_margin_bottom = 6.0
			btn.add_theme_stylebox_override("normal", act_sb)
			btn.add_theme_stylebox_override("pressed", act_sb)
			btn.add_theme_stylebox_override("hover", act_sb)
			btn.add_theme_stylebox_override("hover_pressed", act_sb)
		else:
			btn.remove_theme_stylebox_override("normal")
			btn.remove_theme_stylebox_override("pressed")
			btn.remove_theme_stylebox_override("hover")
			btn.remove_theme_stylebox_override("hover_pressed")
		if i < _speed_icons.size():
			var ic: Icons = _speed_icons[i]
			if ic != null:
				ic.color = fg
				ic.queue_redraw()
		if i < _speed_labels.size():
			var lbl: Label = _speed_labels[i]
			if lbl != null:
				lbl.add_theme_color_override("font_color", fg)
	_chip_on = speed_index == 0 and GameState.running
	if speed_index >= 1 and not GameState.is_paused():
		_complete_onboarding_step(3)


func _on_paused_changed(paused: bool) -> void:
	_on_speed_changed(GameState.speed_index)
	if not paused and GameState.speed_index >= 1:
		_complete_onboarding_step(3)


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
	_update_rates(_snap, false)
	_refresh_resistances(false)
	_update_pressure()
	_update_tree_status()
	_update_defcon(_defcon_level)
	_update_difficulty_badge(str(_snap.get("difficulty", GameState.selected_difficulty)))
	if _briefing_modal != null and _briefing_modal.visible:
		_update_briefing_card()
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
	if _tick_bar != null:
		_tick_bar.value = GameState.tick_progress()
		if _tick_bar_fill != null:
			var tcol: Color = UITheme.WARNING if GameState.is_paused() else UITheme.HEALTHY
			_tick_bar_fill.bg_color = UITheme.with_alpha(tcol, 0.85)
			_tick_bar_fill.border_color = tcol
	_paused_chip.modulate.a = (0.55 + 0.45 * (0.5 + 0.5 * sin(_time * 5.0))) if _chip_on else 0.0
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
	_guard_toasts()
	if _vignette != null and _vignette_alpha > 0.0:
		_vignette.queue_redraw()
	if _onboard_active:
		_onboard_time_left = maxf(0.0, _onboard_time_left - delta)
		if _onboarding_timer_label != null:
			_onboarding_timer_label.text = "%ds" % ceilf(_onboard_time_left)
		if _onboard_time_left <= 0.0:
			_dismiss_onboarding()
	_process_phase2(delta)


## Death-spiral pulse on the budget, attention pulses for resistances, pressure and the tree.
func _process_phase2(delta: float) -> void:
	var wave: float = 0.5 + 0.5 * sin(_time * 6.5)
	if _budget_negative:
		var hot := Color(1.0, 0.42, 0.38, 1.0)
		var bl: Label = _res_labels["budget"]
		bl.self_modulate = Color.WHITE.lerp(hot, 0.35 + 0.65 * wave)
		var rl: Label = _rate_labels["budget"]
		rl.self_modulate = Color(1.0, 1.0, 1.0, 0.55 + 0.45 * wave)
		var ic: Icons = _res_icons["budget"]
		ic.self_modulate = Color.WHITE.lerp(Color(1.6, 0.45, 0.4, 1.0), wave)
	if _resist_flash > 0.0:
		_resist_flash = maxf(0.0, _resist_flash - delta * 0.6)
		var f: float = _resist_flash * (0.5 + 0.5 * sin(_time * 14.0))
		_resist_title.self_modulate = Color.WHITE.lerp(Color(1.6, 0.5, 0.45, 1.0), f)
		_resist_icon.scale = Vector2.ONE * (1.0 + 0.3 * f)
		_resist_icon.pivot_offset = _resist_icon.size * 0.5
	else:
		_resist_title.self_modulate = Color.WHITE
		_resist_icon.scale = Vector2.ONE
	if _pressure_box.visible:
		_pressure_icon.self_modulate = Color(1.0, 1.0, 1.0, 0.45 + 0.55 * wave)
	if _adoptable > 0 and not _tree_open:
		var glow: float = 0.5 + 0.5 * sin(_time * 3.2)
		_tree_icon.self_modulate = Color.WHITE.lerp(Color(1.5, 1.35, 1.0, 1.0), glow)
	else:
		_tree_icon.self_modulate = Color.WHITE
