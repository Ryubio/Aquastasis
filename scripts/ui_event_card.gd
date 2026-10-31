extends Control
## UIEventCard: two-choice decision card modal (oil spill, heatwave, COP31 summits, ...).
## Opens on EventBus.event_triggered, pauses simulation until resolved via
## GameState.resolve_event(choice_index), and resumes time cleanly without locking input.

const UITheme := preload("res://scripts/ui_theme.gd")
const Icons := preload("res://scripts/icons.gd")
const Events := preload("res://scripts/events.gd")

const CARD_W := 760.0
const RES_ORDER := ["budget", "political", "science"]
const RES_KEYS := {"budget": "hud.budget", "political": "hud.political", "science": "hud.science"}
const RES_COLORS := {
	"budget": Color(0.9098, 0.6392, 0.2392),
	"political": Color(0.95, 0.50, 0.36),
	"science": Color(0.42, 0.78, 1.0),
}

var _backdrop: ColorRect
var _card: PanelContainer
var _icon: Icons
var _kind_badge: PanelContainer
var _kind_label: Label
var _region_badge: PanelContainer
var _region_label: Label
var _paused_label: Label
var _title_label: Label
var _text_label: Label
var _hint_label: Label
var _choice_btns: Array = []
var _choice_titles: Array = []
var _choice_tones: Array = []
var _choice_tone_badges: Array = []
var _choice_costs: Array = []
var _res_labels: Dictionary = {}
var _event_id: String = ""
var _region_id: String = ""
var _open: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UITheme.build_theme()
	visible = false
	_build()
	resized.connect(_layout)
	EventBus.event_triggered.connect(_on_event_triggered)
	EventBus.event_resolved.connect(_on_event_resolved)
	EventBus.language_changed.connect(_on_language_changed)
	EventBus.resources_changed.connect(_on_resources_changed)
	EventBus.game_started.connect(_on_game_started)


func is_open() -> bool:
	return _open and visible


## Hides the card immediately (game over, main menu). Does not resolve the event.
func close_now() -> void:
	_open = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _build() -> void:
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.02, 0.03, 0.06, 0.76)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)

	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(CARD_W, 0.0)
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb: StyleBoxFlat = UITheme.panel_box(UITheme.LINE_AMBER, UITheme.with_alpha(UITheme.BG_PANEL, 0.97), 2, UITheme.with_alpha(UITheme.AMBER, 0.22), 24, 16)
	sb.content_margin_left = 28.0
	sb.content_margin_right = 28.0
	sb.content_margin_top = 24.0
	sb.content_margin_bottom = 24.0
	_card.add_theme_stylebox_override("panel", sb)
	add_child(_card)

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 14)
	_card.add_child(col)

	# Top bar: Kind badge + Region badge + Resources
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 10)
	col.add_child(top)

	_kind_badge = PanelContainer.new()
	_kind_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kind_badge.add_theme_stylebox_override("panel", UITheme.badge_box(UITheme.WARNING))
	_kind_label = Label.new()
	_kind_label.theme_type_variation = &"BadgeLabel"
	_kind_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kind_badge.add_child(_kind_label)
	top.add_child(_kind_badge)

	_region_badge = PanelContainer.new()
	_region_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_region_badge.add_theme_stylebox_override("panel", UITheme.badge_box(UITheme.AMBER))
	_region_label = Label.new()
	_region_label.theme_type_variation = &"BadgeLabel"
	_region_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_region_badge.add_child(_region_label)
	top.add_child(_region_badge)

	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)

	for r in RES_ORDER:
		var res_key: String = r
		var rc: Color = RES_COLORS[res_key]
		var rbox := HBoxContainer.new()
		rbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rbox.add_theme_constant_override("separation", 5)
		var ric: Icons = Icons.new()
		ric.setup(res_key, rc, 18.0)
		ric.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ric.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rbox.add_child(ric)
		var rlbl := Label.new()
		rlbl.theme_type_variation = &"SmallLabel"
		rlbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rlbl.add_theme_font_override("font", UITheme.mono_bold_font())
		rlbl.add_theme_color_override("font_color", rc.lerp(Color.WHITE, 0.3))
		rbox.add_child(rlbl)
		top.add_child(rbox)
		_res_labels[res_key] = rlbl

	# Header: Icon + Title + Paused subtitle
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override("separation", 16)
	col.add_child(head)

	_icon = Icons.new()
	_icon.setup("event", UITheme.WARNING, 48.0)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_icon)

	var tcol := VBoxContainer.new()
	tcol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tcol.add_theme_constant_override("separation", 4)
	head.add_child(tcol)

	_title_label = Label.new()
	_title_label.theme_type_variation = &"RegionLabel"
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", UITheme.AMBER.lerp(Color.WHITE, 0.25))
	tcol.add_child(_title_label)

	_paused_label = Label.new()
	_paused_label.theme_type_variation = &"DimLabel"
	_paused_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tcol.add_child(_paused_label)

	var sep := HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(sep)

	# Body text
	_text_label = Label.new()
	_text_label.theme_type_variation = &"BodyLabel"
	_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.custom_minimum_size = Vector2(CARD_W - 60.0, 0.0)
	col.add_child(_text_label)

	# Two Choice Buttons
	for i in 2:
		var btn := Button.new()
		btn.theme_type_variation = &"ActionButton"
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.custom_minimum_size = Vector2(CARD_W - 60.0, 74.0)
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_on_choice_pressed.bind(i))
		col.add_child(btn)

		var inner := VBoxContainer.new()
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inner.offset_left = 14.0
		inner.offset_right = -14.0
		inner.offset_top = 8.0
		inner.offset_bottom = -8.0
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		inner.add_theme_constant_override("separation", 4)
		btn.add_child(inner)

		var row1 := HBoxContainer.new()
		row1.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row1.add_theme_constant_override("separation", 10)
		inner.add_child(row1)

		var key_lbl := Label.new()
		key_lbl.theme_type_variation = &"BadgeLabel"
		key_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		key_lbl.text = "[" + str(i + 1) + "]"
		key_lbl.add_theme_color_override("font_color", UITheme.AMBER)
		row1.add_child(key_lbl)

		var ch_title := Label.new()
		ch_title.theme_type_variation = &"BodyLabel"
		ch_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ch_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ch_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ch_title.add_theme_font_override("font", UITheme.mono_bold_font())
		ch_title.add_theme_font_size_override("font_size", 15)
		row1.add_child(ch_title)

		var tbadge := PanelContainer.new()
		tbadge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tbadge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var tlbl := Label.new()
		tlbl.theme_type_variation = &"BadgeLabel"
		tlbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tbadge.add_child(tlbl)
		row1.add_child(tbadge)

		var cost_lbl := Label.new()
		cost_lbl.theme_type_variation = &"DimLabel"
		cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(cost_lbl)

		_choice_btns.append(btn)
		_choice_titles.append(ch_title)
		_choice_tones.append(tlbl)
		_choice_tone_badges.append(tbadge)
		_choice_costs.append(cost_lbl)

	_hint_label = Label.new()
	_hint_label.theme_type_variation = &"DimLabel"
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_hint_label)


func _layout() -> void:
	if _card == null:
		return
	_card.reset_size()
	var vs: Vector2 = get_viewport_rect().size
	_card.position = ((vs - _card.size) * 0.5).floor()


func _on_event_triggered(event_id: String) -> void:
	var cur: Dictionary = GameState.current_event()
	_event_id = str(cur.get("id", event_id))
	_region_id = str(cur.get("region", ""))
	var def: Dictionary = Events.event_def(_event_id)
	if def.is_empty():
		GameState.set_pause_reason("event", false)
		close_now()
		return
	_open = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_refresh()
	call_deferred("_layout")


func _on_event_resolved(_event_id_resolved: String, _choice_index: int) -> void:
	close_now()


func _on_game_started() -> void:
	close_now()


func _on_language_changed(_lang: String) -> void:
	if is_open():
		_refresh()
		call_deferred("_layout")


func _on_resources_changed(_b: float, _p: float, _s: float) -> void:
	if is_open():
		_refresh()


func _region_args() -> Dictionary:
	if _region_id != "":
		var rkey: String = "region." + _region_id + ".name"
		if I18n.has_key(rkey):
			return {"region": I18n.t(rkey)}
		return {"region": _region_id}
	return {"region": I18n.t("ui.card.basin_wide")}


func _refresh() -> void:
	var def: Dictionary = Events.event_def(_event_id)
	if def.is_empty():
		return
	var snap: Dictionary = GameState.get_snapshot()
	for r in RES_ORDER:
		var rkey: String = r
		var rlbl: Label = _res_labels[rkey]
		rlbl.text = str(roundi(float(snap.get(rkey, 0.0))))

	var is_summit: bool = int(def.get("at_tick", -1)) >= 0
	var kind_key: String = "ui.card.kind.summit" if is_summit else "ui.card.kind.alert"
	var kind_col: Color = UITheme.HEALTHY if is_summit else UITheme.WARNING
	_kind_badge.add_theme_stylebox_override("panel", UITheme.badge_box(kind_col))
	_kind_label.text = I18n.t(kind_key)
	_kind_label.add_theme_color_override("font_color", kind_col.lerp(Color.WHITE, 0.35))

	var args: Dictionary = _region_args()
	_region_label.text = str(args.get("region", ""))
	_region_label.add_theme_color_override("font_color", UITheme.AMBER.lerp(Color.WHITE, 0.35))

	var icon_id: String = str(def.get("icon", "event"))
	if not Icons.IDS.has(icon_id):
		icon_id = "event"
	_icon.icon_id = icon_id
	_icon.color = kind_col
	_icon.queue_redraw()

	_title_label.text = I18n.t(str(def.get("title_key", "ui.card.unknown_title")), args)
	_paused_label.text = I18n.t("ui.card.paused")
	_text_label.text = I18n.t(str(def.get("text_key", "ui.card.unknown_text")), args)
	_hint_label.text = I18n.t("ui.card.keys_choose")

	var choices: Array = def.get("choices", [])
	for i in 2:
		var btn: Button = _choice_btns[i]
		if i >= choices.size():
			btn.visible = false
			continue
		btn.visible = true
		var ch: Dictionary = choices[i]
		var can: bool = GameState.can_choose(i)
		btn.disabled = not can

		var ch_title: Label = _choice_titles[i]
		ch_title.text = I18n.t(str(ch.get("label_key", "")), args)
		ch_title.add_theme_color_override("font_color", UITheme.TEXT if can else UITheme.TEXT_DIM)

		var tone: int = int(ch.get("tone", 0))
		var tone_key: String = "ui.card.tone.neutral"
		var tone_col: Color = UITheme.AMBER
		if tone > 0:
			tone_key = "ui.card.tone.pos"
			tone_col = UITheme.HEALTHY
		elif tone < 0:
			tone_key = "ui.card.tone.neg"
			tone_col = UITheme.CRISIS
		var tbadge: PanelContainer = _choice_tone_badges[i]
		var tlbl: Label = _choice_tones[i]
		tbadge.add_theme_stylebox_override("panel", UITheme.badge_box(tone_col))
		tlbl.text = I18n.t(tone_key)
		tlbl.add_theme_color_override("font_color", tone_col.lerp(Color.WHITE, 0.35))

		var cost: Dictionary = ch.get("cost", {})
		var cost_parts := PackedStringArray()
		for r in RES_ORDER:
			var rkey: String = r
			var cval: float = float(cost.get(rkey, 0.0))
			if cval > 0.0:
				cost_parts.append(str(roundi(cval)) + " " + I18n.t(str(RES_KEYS[rkey])))
		var cost_str: String = I18n.t("ui.card.free") if cost_parts.is_empty() else ", ".join(cost_parts)
		if not can:
			cost_str += " · " + I18n.t("ui.card.cant_afford")
		var cost_lbl: Label = _choice_costs[i]
		cost_lbl.text = cost_str
		cost_lbl.add_theme_color_override("font_color", UITheme.CRISIS if not can else UITheme.TEXT_DIM)


func _on_choice_pressed(choice_index: int) -> void:
	if not is_open():
		return
	if GameState.resolve_event(choice_index):
		close_now()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var code: int = key.keycode if key.keycode != 0 else key.physical_keycode
	if code == KEY_1 or code == KEY_KP_1:
		if GameState.can_choose(0):
			_on_choice_pressed(0)
			get_viewport().set_input_as_handled()
	elif code == KEY_2 or code == KEY_KP_2:
		if GameState.can_choose(1):
			_on_choice_pressed(1)
			get_viewport().set_input_as_handled()
