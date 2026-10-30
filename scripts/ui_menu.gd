extends Control
## UIMenu: cinematic main menu over the live map, pause menu and win/lose screen, all built
## in code with fade/slide Tweens and live language switching. Emits intent signals only;
## main.gd owns the game flow.

signal start_requested()
signal resume_requested()
signal restart_requested()
signal main_menu_requested()
signal quit_requested()

const UITheme := preload("res://scripts/ui_theme.gd")
const Icons := preload("res://scripts/icons.gd")
const Charts := preload("res://scripts/charts.gd")

const BAND_H := 64.0
const COLUMN_W := 1000.0
const COLUMN_X := 140.0
const TITLE_MAX_SIZE := 84
const END_KEYS := {
	"win_health": ["end.win.title", "end.win.health.text"],
	"win_crisis": ["end.win.title", "end.win.crisis.text"],
	"lose_temperature": ["end.lose.temperature.title", "end.lose.temperature.text"],
	"lose_health": ["end.lose.health.title", "end.lose.health.text"],
	"lose_resources": ["end.lose.resources.title", "end.lose.resources.text"],
	"lose_time": ["end.lose.time.title", "end.lose.time.text"],
}

var _mode: String = ""   # "", "main", "pause", "end"
var _tr_labels: Array = []     # [[Label, key]]
var _tr_buttons: Array = []    # [[Button, key]]
var _lang_buttons: Array = []  # [[Button, code]]
var _time: float = 0.0
var _anim: Tween = null
var _title_anim: Tween = null

# Main menu
var _main_root: Control
var _main_overlay: Control
var _main_margin: MarginContainer
var _main_items: Array = []
var _title_ctrl: Control
var _title_reveal: float = 1.0
var _title_spacing: float = 6.0
var _band_t: float = 1.0
var _rule: ColorRect
var _pulse: Charts
var _clock_label: Label

# Pause menu
var _pause_root: Control
var _pause_panel: PanelContainer

# End screen
var _end_root: Control
var _end_overlay: ColorRect
var _end_panel: PanelContainer
var _end_icon: Icons
var _end_title: Label
var _end_text: Label
var _end_stat_labels: Array = []
var _end_won: bool = false
var _end_reason: String = ""
var _end_stats: Dictionary = {}
var _end_progress: float = 1.0
var _end_pulse: Charts


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UITheme.build_theme()
	_build_main()
	_build_pause()
	_build_end()
	_main_root.visible = false
	_pause_root.visible = false
	_end_root.visible = false
	visible = false
	EventBus.language_changed.connect(_on_language_changed)


# --- Builders ----------------------------------------------------------------------------

func _full_rect(parent: Control, filter: int) -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = filter
	parent.add_child(c)
	return c


func _label(variation: String, key: String = "") -> Label:
	var l := Label.new()
	l.theme_type_variation = StringName(variation)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if key != "":
		_tr_labels.append([l, key])
		l.text = I18n.t(key)
	return l


func _icon(id: String, col: Color, px: float) -> Icons:
	var ic: Icons = Icons.new()
	ic.setup(id, col, px)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return ic


func _hbox(sep: int) -> HBoxContainer:
	var b := HBoxContainer.new()
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_theme_constant_override("separation", sep)
	return b


func _vbox(sep: int) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_theme_constant_override("separation", sep)
	return b


## Themed button with translated text and a vector icon pinned to its left edge.
func _button(variation: String, icon_id: String, key: String, min_size: Vector2, icon_col: Color) -> Button:
	var btn := Button.new()
	btn.theme_type_variation = StringName(variation)
	btn.custom_minimum_size = min_size
	btn.focus_mode = Control.FOCUS_NONE
	btn.text = I18n.t(key)
	btn.clip_text = false
	_tr_buttons.append([btn, key])
	btn.mouse_entered.connect(_on_btn_hover.bind(btn, true))
	btn.mouse_exited.connect(_on_btn_hover.bind(btn, false))
	btn.button_down.connect(_on_btn_down.bind(btn))
	if icon_id != "":
		var px: float = clampf(min_size.y * 0.42, 16.0, 26.0)
		var ic := _icon(icon_id, icon_col, px)
		ic.anchor_left = 0.0
		ic.anchor_right = 0.0
		ic.anchor_top = 0.5
		ic.anchor_bottom = 0.5
		ic.offset_left = 16.0
		ic.offset_right = 16.0 + px
		ic.offset_top = -px * 0.5
		ic.offset_bottom = px * 0.5
		btn.add_child(ic)
		btn.add_theme_constant_override("h_separation", 8)
	return btn


func _on_btn_hover(btn: BaseButton, on: bool) -> void:
	UITheme.hover_fx(btn, on)


func _on_btn_down(btn: BaseButton) -> void:
	UITheme.press_fx(btn)


func _lang_row(parent: Control) -> void:
	var row := _hbox(8)
	parent.add_child(row)
	row.add_child(_icon("globe", UITheme.HEALTHY, 20.0))
	var l := _label("DimLabel", "ui.menu.language")
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.custom_minimum_size = Vector2(0.0, 0.0)
	row.add_child(l)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(6.0, 0.0)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	for c in I18n.LANGS:
		var code: String = c
		var b := Button.new()
		b.theme_type_variation = &"ChipButton"
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.text = I18n.lang_name(code)
		b.custom_minimum_size = Vector2(104.0, 36.0)
		b.mouse_entered.connect(_on_btn_hover.bind(b, true))
		b.mouse_exited.connect(_on_btn_hover.bind(b, false))
		b.button_down.connect(_on_btn_down.bind(b))
		b.pressed.connect(_on_lang_pressed.bind(code))
		row.add_child(b)
		_lang_buttons.append([b, code])
	_sync_lang_buttons()


func _sync_lang_buttons() -> void:
	for pair in _lang_buttons:
		var p: Array = pair
		var b: Button = p[0]
		var code: String = p[1]
		b.set_pressed_no_signal(code == I18n.lang)
		b.text = I18n.lang_name(code)


func _bracket_draw(panel: Control, col: Color) -> void:
	UITheme.draw_brackets(panel, Rect2(Vector2(-6.0, -6.0), panel.size + Vector2(12.0, 12.0)), col, 22.0, 2.0)


# --- Main menu ---------------------------------------------------------------------------

func _build_main() -> void:
	_main_root = _full_rect(self, Control.MOUSE_FILTER_STOP)
	_main_overlay = _full_rect(_main_root, Control.MOUSE_FILTER_IGNORE)
	_main_overlay.draw.connect(_draw_main_overlay)

	_main_margin = MarginContainer.new()
	_main_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_main_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_main_margin.add_theme_constant_override("margin_left", int(COLUMN_X))
	_main_margin.add_theme_constant_override("margin_top", int(BAND_H + 40.0))
	_main_margin.add_theme_constant_override("margin_bottom", int(BAND_H + 40.0))
	_main_margin.add_theme_constant_override("margin_right", 0)
	_main_root.add_child(_main_margin)
	var col := _vbox(14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.custom_minimum_size = Vector2(COLUMN_W, 0.0)
	_main_margin.add_child(col)

	var top_row := _hbox(14)
	col.add_child(top_row)
	_pulse = Charts.new()
	_pulse.setup_pulse(Vector2(260.0, 40.0))
	_pulse.pulse_health = 38.0
	top_row.add_child(_pulse)
	var coords := _label("DimLabel")
	coords.text = "36.8969° · 30.7133°"
	coords.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coords.add_theme_color_override("font_color", UITheme.with_alpha(UITheme.HEALTHY, 0.7))
	top_row.add_child(coords)
	_main_items.append(top_row)

	_title_ctrl = Control.new()
	_title_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_ctrl.custom_minimum_size = Vector2(COLUMN_W, 104.0)
	_title_ctrl.draw.connect(_draw_title)
	col.add_child(_title_ctrl)

	_rule = ColorRect.new()
	_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rule.color = UITheme.AMBER
	_rule.custom_minimum_size = Vector2(520.0, 2.0)
	_rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(_rule)

	var sub := _label("HeaderLabel", "game.subtitle")
	sub.add_theme_font_size_override("font_size", 22)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(sub)
	_main_items.append(sub)

	var tag := _label("BodyLabel", "ui.menu.tagline")
	tag.add_theme_font_size_override("font_size", 24)
	tag.add_theme_color_override("font_color", UITheme.TEXT)
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tag.custom_minimum_size = Vector2(880.0, 0.0)
	tag.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(tag)
	_main_items.append(tag)

	var brief_box := _hbox(14)
	col.add_child(brief_box)
	var brief_line := ColorRect.new()
	brief_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brief_line.color = UITheme.with_alpha(UITheme.HEALTHY, 0.6)
	brief_line.custom_minimum_size = Vector2(2.0, 0.0)
	brief_box.add_child(brief_line)
	var brief := _label("BodyDimLabel", "ui.menu.briefing")
	brief.add_theme_font_size_override("font_size", 17)
	brief.add_theme_color_override("font_color", UITheme.TEXT.lerp(UITheme.TEXT_DIM, 0.45))
	brief.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	brief.custom_minimum_size = Vector2(760.0, 0.0)
	brief_box.add_child(brief)
	_main_items.append(brief_box)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0.0, 12.0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(gap)

	var buttons := _hbox(16)
	col.add_child(buttons)
	var start := _button("PrimaryButton", "play", "ui.menu.start", Vector2(340.0, 60.0), UITheme.HEALTHY)
	start.pressed.connect(_on_start_pressed)
	buttons.add_child(start)
	var quit := _button("GhostButton", "power", "ui.menu.quit", Vector2(190.0, 60.0), UITheme.TEXT_DIM)
	quit.pressed.connect(_on_quit_pressed)
	buttons.add_child(quit)
	_main_items.append(buttons)

	var lang_holder := _vbox(0)
	col.add_child(lang_holder)
	_lang_row(lang_holder)
	_main_items.append(lang_holder)

	# Letterbox band texts.
	var event_line := _label("DimLabel", "ui.menu.event_line")
	event_line.add_theme_font_size_override("font_size", 13)
	event_line.add_theme_color_override("font_color", UITheme.AMBER.lerp(UITheme.TEXT_DIM, 0.35))
	event_line.position = Vector2(COLUMN_X, 22.0)
	event_line.size = Vector2(1100.0, 22.0)
	event_line.clip_text = true
	event_line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_main_root.add_child(event_line)

	_clock_label = _label("DimLabel")
	_clock_label.add_theme_font_size_override("font_size", 13)
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_clock_label.anchor_left = 1.0
	_clock_label.anchor_right = 1.0
	_clock_label.offset_left = -520.0
	_clock_label.offset_right = -COLUMN_X
	_clock_label.offset_top = 22.0
	_clock_label.offset_bottom = 44.0
	_main_root.add_child(_clock_label)

	var controls := _label("DimLabel", "ui.menu.controls")
	controls.add_theme_font_size_override("font_size", 13)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.anchor_left = 0.0
	controls.anchor_right = 1.0
	controls.anchor_top = 1.0
	controls.anchor_bottom = 1.0
	controls.offset_left = COLUMN_X
	controls.offset_right = -COLUMN_X
	controls.offset_top = -BAND_H + 10.0
	controls.offset_bottom = -10.0
	controls.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_main_root.add_child(controls)


func _grad_quad(ci: CanvasItem, r: Rect2, c0: Color, c1: Color, horizontal: bool) -> void:
	var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	var cols := PackedColorArray()
	if horizontal:
		cols = PackedColorArray([c0, c1, c1, c0])
	else:
		cols = PackedColorArray([c0, c0, c1, c1])
	ci.draw_polygon(pts, cols)


func _draw_main_overlay() -> void:
	var ci: Control = _main_overlay
	var s: Vector2 = ci.size
	var bg: Color = UITheme.BG
	ci.draw_rect(Rect2(Vector2.ZERO, s), UITheme.with_alpha(bg, 0.22))
	_grad_quad(ci, Rect2(0.0, 0.0, s.x * 0.7, s.y), UITheme.with_alpha(bg, 0.95), UITheme.with_alpha(bg, 0.0), true)
	_grad_quad(ci, Rect2(0.0, 0.0, s.x * 0.36, s.y), UITheme.with_alpha(bg, 0.55), UITheme.with_alpha(bg, 0.0), true)
	_grad_quad(ci, Rect2(0.0, BAND_H, s.x, 200.0), UITheme.with_alpha(bg, 0.75), UITheme.with_alpha(bg, 0.0), false)
	_grad_quad(ci, Rect2(0.0, s.y - BAND_H - 220.0, s.x, 220.0), UITheme.with_alpha(bg, 0.0), UITheme.with_alpha(bg, 0.85), false)
	var bh: float = BAND_H * _band_t
	ci.draw_rect(Rect2(0.0, 0.0, s.x, bh), UITheme.DEEP)
	ci.draw_rect(Rect2(0.0, s.y - bh, s.x, bh), UITheme.DEEP)
	ci.draw_line(Vector2(0.0, bh), Vector2(s.x, bh), UITheme.with_alpha(UITheme.AMBER, 0.45), 1.0)
	ci.draw_line(Vector2(0.0, s.y - bh), Vector2(s.x, s.y - bh), UITheme.with_alpha(UITheme.AMBER, 0.45), 1.0)
	# Scale ticks on the bands (tactical ruler).
	var x: float = 0.0
	var i: int = 0
	while x < s.x:
		var th: float = 8.0 if i % 10 == 0 else 3.0
		ci.draw_line(Vector2(x, bh), Vector2(x, bh + th), UITheme.with_alpha(UITheme.AMBER, 0.3), 1.0)
		ci.draw_line(Vector2(x, s.y - bh), Vector2(x, s.y - bh - th), UITheme.with_alpha(UITheme.AMBER, 0.3), 1.0)
		x += 16.0
		i += 1
	var frame := Rect2(28.0, bh + 24.0, s.x - 56.0, s.y - bh * 2.0 - 48.0)
	UITheme.draw_brackets(ci, frame, UITheme.with_alpha(UITheme.AMBER, 0.55 * _band_t), 34.0, 2.0)
	# Slow scanning beam across the map side.
	var sweep: float = fmod(_time * 0.08, 1.0)
	var sx: float = lerpf(s.x * 0.45, s.x - 40.0, sweep)
	_grad_quad(ci, Rect2(sx - 60.0, bh, 60.0, s.y - bh * 2.0), UITheme.with_alpha(UITheme.HEALTHY, 0.0), UITheme.with_alpha(UITheme.HEALTHY, 0.025), true)
	ci.draw_line(Vector2(sx, bh), Vector2(sx, s.y - bh), UITheme.with_alpha(UITheme.HEALTHY, 0.09), 1.0)


func _draw_title() -> void:
	var text: String = I18n.t("game.title")
	var n: int = text.length()
	if n == 0:
		return
	var font: Font = UITheme.mono_bold_font()
	var avail: float = _title_ctrl.size.x
	var fs: int = TITLE_MAX_SIZE
	var spacing: float = _title_spacing
	var natural: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + spacing * float(n - 1)
	if natural > avail and natural > 0.0:
		var nat_no_space: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		fs = maxi(28, int(floor(float(fs) * (avail - spacing * float(n - 1)) / maxf(nat_no_space, 1.0))))
	var ascent: float = font.get_ascent(fs)
	var base_y: float = (_title_ctrl.size.y - font.get_height(fs)) * 0.5 + ascent
	var x: float = 0.0
	var warm: Color = UITheme.TEXT.lerp(UITheme.AMBER, 0.18)
	for i in n:
		var ch: String = text[i]
		var w: float = font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var a: float = clampf(_title_reveal * float(n + 6) - float(i), 0.0, 1.0)
		if a > 0.0 and ch != " ":
			var flick: float = 1.0
			var noise: float = sin(_time * 7.3 + float(i) * 12.9) * sin(_time * 3.1 + float(i) * 4.7)
			if noise > 0.975:
				flick = 0.78
			var pos := Vector2(x, base_y - (1.0 - a) * 18.0)
			_title_ctrl.draw_char_outline(font, pos, ch, fs, 14, UITheme.with_alpha(UITheme.AMBER, 0.07 * a * flick))
			_title_ctrl.draw_char_outline(font, pos, ch, fs, 6, UITheme.with_alpha(UITheme.AMBER, 0.16 * a * flick))
			_title_ctrl.draw_char(font, pos, ch, fs, UITheme.with_alpha(warm, a * flick))
		x += w + spacing


# --- Pause menu --------------------------------------------------------------------------

func _build_pause() -> void:
	_pause_root = _full_rect(self, Control.MOUSE_FILTER_STOP)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.color = UITheme.with_alpha(UITheme.BG, 0.66)
	_pause_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_root.add_child(center)
	_pause_panel = PanelContainer.new()
	_pause_panel.theme_type_variation = &"MenuPanel"
	_pause_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_panel.custom_minimum_size = Vector2(500.0, 0.0)
	_pause_panel.draw.connect(_bracket_draw.bind(_pause_panel, UITheme.AMBER))
	center.add_child(_pause_panel)
	var col := _vbox(12)
	_pause_panel.add_child(col)

	var head := _hbox(14)
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(head)
	head.add_child(_icon("pause", UITheme.AMBER, 30.0))
	var t := _label("TitleLabel", "ui.pause.title")
	t.add_theme_color_override("font_color", UITheme.AMBER)
	head.add_child(t)
	var sep := HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(sep)

	var resume := _button("PrimaryButton", "play", "ui.pause.resume", Vector2(0.0, 56.0), UITheme.HEALTHY)
	resume.pressed.connect(_on_resume_pressed)
	col.add_child(resume)
	var restart := _button("Button", "restart", "ui.pause.restart", Vector2(0.0, 48.0), UITheme.AMBER)
	restart.pressed.connect(_on_restart_pressed)
	col.add_child(restart)

	var lang_box := _vbox(8)
	col.add_child(lang_box)
	var lang_head := _hbox(8)
	lang_box.add_child(lang_head)
	lang_head.add_child(_icon("globe", UITheme.HEALTHY, 18.0))
	lang_head.add_child(_label("DimLabel", "ui.menu.language"))
	var chips := _hbox(8)
	lang_box.add_child(chips)
	for c in I18n.LANGS:
		var code: String = c
		var b := Button.new()
		b.theme_type_variation = &"ChipButton"
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.text = I18n.lang_name(code)
		b.custom_minimum_size = Vector2(0.0, 36.0)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.mouse_entered.connect(_on_btn_hover.bind(b, true))
		b.mouse_exited.connect(_on_btn_hover.bind(b, false))
		b.button_down.connect(_on_btn_down.bind(b))
		b.pressed.connect(_on_lang_pressed.bind(code))
		chips.add_child(b)
		_lang_buttons.append([b, code])
	_sync_lang_buttons()

	var sep2 := HSeparator.new()
	sep2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(sep2)
	var main_menu := _button("GhostButton", "home", "ui.pause.main_menu", Vector2(0.0, 46.0), UITheme.TEXT_DIM)
	main_menu.pressed.connect(_on_main_menu_pressed)
	col.add_child(main_menu)
	var quit := _button("DangerButton", "power", "ui.pause.quit", Vector2(0.0, 46.0), UITheme.TERRACOTTA)
	quit.pressed.connect(_on_quit_pressed)
	col.add_child(quit)


# --- End screen ---------------------------------------------------------------------------

func _build_end() -> void:
	_end_root = _full_rect(self, Control.MOUSE_FILTER_STOP)
	_end_overlay = ColorRect.new()
	_end_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_end_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end_overlay.color = UITheme.with_alpha(UITheme.BG, 0.74)
	_end_root.add_child(_end_overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end_root.add_child(center)
	_end_panel = PanelContainer.new()
	_end_panel.theme_type_variation = &"MenuPanel"
	_end_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_end_panel.custom_minimum_size = Vector2(780.0, 0.0)
	_end_panel.draw.connect(_on_end_panel_draw)
	center.add_child(_end_panel)
	var col := _vbox(14)
	_end_panel.add_child(col)

	var game_name := _label("HeaderLabel", "game.title")
	game_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_name.add_theme_color_override("font_color", UITheme.with_alpha(UITheme.AMBER, 0.75))
	game_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(game_name)
	_end_icon = _icon("sea_health", UITheme.HEALTHY, 64.0)
	_end_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_end_icon)
	_end_title = _label("TitleLabel")
	_end_title.add_theme_font_size_override("font_size", 54)
	_end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_end_title)
	_end_pulse = Charts.new()
	_end_pulse.setup_pulse(Vector2(680.0, 52.0))
	_end_pulse.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_end_pulse)
	_end_text = _label("BodyLabel")
	_end_text.add_theme_font_size_override("font_size", 19)
	_end_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_end_text.custom_minimum_size = Vector2(680.0, 0.0)
	col.add_child(_end_text)
	var sep := HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(sep)

	var inset := PanelContainer.new()
	inset.theme_type_variation = &"InsetPanel"
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(inset)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 10)
	inset.add_child(grid)
	var stat_icons: Array = [["sea_health", UITheme.HEALTHY], ["temperature", UITheme.WARNING], ["clock", UITheme.AMBER], ["check", Color(0.42, 0.78, 1.0)]]
	for si in stat_icons:
		var s: Array = si
		var row := _hbox(10)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(row)
		var ic_col: Color = s[1]
		row.add_child(_icon(str(s[0]), ic_col, 22.0))
		var l := _label("SmallLabel")
		l.add_theme_font_size_override("font_size", 16)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.custom_minimum_size = Vector2(280.0, 0.0)
		row.add_child(l)
		_end_stat_labels.append(l)

	var buttons := _hbox(16)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(buttons)
	var again := _button("PrimaryButton", "restart", "end.play_again", Vector2(300.0, 58.0), UITheme.HEALTHY)
	again.pressed.connect(_on_restart_pressed)
	buttons.add_child(again)
	var to_menu := _button("GhostButton", "home", "end.main_menu", Vector2(240.0, 58.0), UITheme.TEXT_DIM)
	to_menu.pressed.connect(_on_main_menu_pressed)
	buttons.add_child(to_menu)


func _on_end_panel_draw() -> void:
	var c: Color = UITheme.HEALTHY if _end_won else UITheme.CRISIS
	_bracket_draw(_end_panel, UITheme.with_alpha(c, 0.85))


func _end_keys() -> Array:
	if END_KEYS.has(_end_reason):
		var k: Array = END_KEYS[_end_reason]
		return k
	if _end_won:
		return ["end.win.title", "end.win.crisis.text"]
	return ["end.lose.time.title", "end.lose.time.text"]


func _render_end_texts() -> void:
	var keys: Array = _end_keys()
	var sh: float = float(_end_stats.get("sea_health", 0.0))
	var yr: int = int(_end_stats.get("year_int", Balance.END_YEAR))
	var args: Dictionary = {"health": str(roundi(sh)), "year": str(yr)}
	_end_title.text = I18n.t(str(keys[0]))
	_end_text.text = I18n.t(str(keys[1]), args)
	var accent: Color = UITheme.HEALTHY if _end_won else UITheme.CRISIS
	_end_title.add_theme_color_override("font_color", accent.lerp(Color.WHITE, 0.12))
	_end_icon.icon_id = "sea_health" if _end_won else "warning"
	_end_icon.color = accent
	_end_pulse.pulse_health = sh if _end_won else minf(sh, 25.0)
	var sb := UITheme.panel_box(UITheme.with_alpha(accent, 0.6), UITheme.with_alpha(UITheme.BG_PANEL, 0.95), 1, UITheme.with_alpha(accent, 0.16), 22, 16)
	sb.content_margin_left = 40.0
	sb.content_margin_right = 40.0
	sb.content_margin_top = 30.0
	sb.content_margin_bottom = 30.0
	_end_panel.add_theme_stylebox_override("panel", sb)
	_end_panel.queue_redraw()


func _render_end_stats() -> void:
	var p: float = clampf(_end_progress, 0.0, 1.0)
	var sh: float = float(_end_stats.get("sea_health", 0.0))
	var temp: float = float(_end_stats.get("temperature", Charts.TEMP_MIN))
	var yr: int = int(_end_stats.get("year_int", Balance.END_YEAR))
	var acts: int = int(_end_stats.get("actions_used", 0))
	var texts: Array = [
		I18n.t("end.stat.health", {"v": str(roundi(sh * p))}),
		I18n.t("end.stat.temp", {"v": "%.2f" % lerpf(Charts.TEMP_MIN, temp, p)}),
		I18n.t("end.stat.year", {"v": str(int(round(lerpf(float(Balance.START_YEAR), float(yr), p))))}),
		I18n.t("end.stat.actions", {"v": str(roundi(float(acts) * p))}),
	]
	for i in mini(texts.size(), _end_stat_labels.size()):
		var l: Label = _end_stat_labels[i]
		l.text = str(texts[i])


func _set_end_progress(v: float) -> void:
	_end_progress = v
	_render_end_stats()


# --- Public API (frozen) --------------------------------------------------------------------

func show_main() -> void:
	_mode = "main"
	_open_root(_main_root)
	_sync_lang_buttons()
	_main_root.modulate.a = 0.0
	_band_t = 0.0
	_title_reveal = 0.0
	_title_spacing = 34.0
	_rule.scale = Vector2(0.0, 1.0)
	for it in _main_items:
		var item: Control = it
		item.modulate.a = 0.0
	_set_main_margin(COLUMN_X - 60.0)
	_anim = create_tween()
	_anim.set_parallel(true)
	_anim.set_trans(Tween.TRANS_CUBIC)
	_anim.set_ease(Tween.EASE_OUT)
	_anim.tween_property(_main_root, "modulate:a", 1.0, 0.7)
	_anim.tween_method(_set_band, 0.0, 1.0, 0.9).set_trans(Tween.TRANS_EXPO)
	_anim.tween_method(_set_main_margin, COLUMN_X - 60.0, COLUMN_X, 1.1)
	_anim.tween_method(_set_title_reveal, 0.0, 1.0, 1.4).set_delay(0.15)
	_anim.tween_method(_set_title_spacing, 34.0, 6.0, 1.7).set_delay(0.15)
	_anim.tween_property(_rule, "scale:x", 1.0, 0.8).set_delay(0.6)
	var delay: float = 0.35
	for it in _main_items:
		var item: Control = it
		_anim.tween_property(item, "modulate:a", 1.0, 0.55).set_delay(delay)
		delay += 0.12


func show_pause() -> void:
	_mode = "pause"
	_open_root(_pause_root)
	_sync_lang_buttons()
	_pause_root.modulate.a = 0.0
	_pause_panel.scale = Vector2(0.92, 0.92)
	_anim = create_tween()
	_anim.set_parallel(true)
	_anim.tween_property(_pause_root, "modulate:a", 1.0, 0.22)
	_anim.tween_property(_pause_panel, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func show_end(won: bool, reason: String, stats: Dictionary) -> void:
	_mode = "end"
	_end_won = won
	_end_reason = reason
	_end_stats = stats
	_end_progress = 0.0
	_render_end_texts()
	_render_end_stats()
	var tint: Color = UITheme.BG.lerp(UITheme.HEALTHY, 0.06) if won else UITheme.BG.lerp(UITheme.CRISIS, 0.12)
	_end_overlay.color = UITheme.with_alpha(tint, 0.76)
	_open_root(_end_root)
	_end_root.modulate.a = 0.0
	_end_panel.scale = Vector2(0.94, 0.94)
	_end_title.visible_ratio = 0.0
	_end_text.visible_ratio = 0.0
	_anim = create_tween()
	_anim.set_parallel(true)
	_anim.set_trans(Tween.TRANS_CUBIC)
	_anim.set_ease(Tween.EASE_OUT)
	_anim.tween_property(_end_root, "modulate:a", 1.0, 0.6)
	_anim.tween_property(_end_panel, "scale", Vector2.ONE, 0.6).set_delay(0.1)
	_anim.tween_property(_end_title, "visible_ratio", 1.0, 0.8).set_delay(0.35)
	_anim.tween_property(_end_text, "visible_ratio", 1.0, 1.1).set_delay(0.8)
	_anim.tween_method(_set_end_progress, 0.0, 1.0, 1.4).set_delay(1.0)


func hide_all() -> void:
	_mode = ""
	_kill_anim()
	_main_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not visible:
		return
	_anim = create_tween()
	_anim.tween_property(self, "modulate:a", 0.0, 0.3)
	_anim.tween_callback(_finish_hide)


func is_open() -> bool:
	return _mode != ""


func is_pause_open() -> bool:
	return _mode == "pause"


# --- Internals -------------------------------------------------------------------------------

func _open_root(root: Control) -> void:
	_kill_anim()
	visible = true
	modulate = Color.WHITE
	for r in [_main_root, _pause_root, _end_root]:
		var c: Control = r
		c.visible = c == root
		c.mouse_filter = Control.MOUSE_FILTER_STOP if c == root else Control.MOUSE_FILTER_IGNORE


func _finish_hide() -> void:
	if _mode != "":
		return
	visible = false
	_main_root.visible = false
	_pause_root.visible = false
	_end_root.visible = false


func _kill_anim() -> void:
	if _anim != null and _anim.is_valid():
		_anim.kill()
	_anim = null
	if _title_anim != null and _title_anim.is_valid():
		_title_anim.kill()
	_title_anim = null


func _set_band(v: float) -> void:
	_band_t = v
	_main_overlay.queue_redraw()


func _set_main_margin(v: float) -> void:
	_main_margin.add_theme_constant_override("margin_left", int(v))


func _set_title_reveal(v: float) -> void:
	_title_reveal = v
	_title_ctrl.queue_redraw()


func _set_title_spacing(v: float) -> void:
	_title_spacing = v
	_title_ctrl.queue_redraw()


# --- Button handlers --------------------------------------------------------------------------

func _on_start_pressed() -> void:
	if _mode == "main":
		start_requested.emit()


func _on_resume_pressed() -> void:
	if _mode == "pause":
		resume_requested.emit()


func _on_restart_pressed() -> void:
	if _mode == "pause" or _mode == "end":
		restart_requested.emit()


func _on_main_menu_pressed() -> void:
	if _mode == "pause" or _mode == "end":
		main_menu_requested.emit()


func _on_quit_pressed() -> void:
	if _mode == "main" or _mode == "pause":
		quit_requested.emit()


func _on_lang_pressed(code: String) -> void:
	I18n.set_language(code)
	_sync_lang_buttons()


func _on_language_changed(_lang: String) -> void:
	for pair in _tr_labels:
		var p: Array = pair
		var l: Label = p[0]
		var key: String = p[1]
		l.text = I18n.t(key)
	for pair in _tr_buttons:
		var p: Array = pair
		var b: Button = p[0]
		var key: String = p[1]
		b.text = I18n.t(key)
	_sync_lang_buttons()
	_title_ctrl.queue_redraw()
	if _mode == "main":
		if _title_anim != null and _title_anim.is_valid():
			_title_anim.kill()
		_title_anim = create_tween()
		_title_anim.tween_method(_set_title_reveal, 0.0, 1.0, 0.7)
	if _mode == "end":
		_render_end_texts()
		_render_end_stats()


func _process(delta: float) -> void:
	_time += delta
	if not visible:
		return
	if _main_root.visible:
		_main_overlay.queue_redraw()
		_title_ctrl.queue_redraw()
		_clock_label.text = Time.get_date_string_from_system() + "  ·  " + Time.get_time_string_from_system()
	if _pause_root.visible:
		_pause_panel.pivot_offset = _pause_panel.size * 0.5
	if _end_root.visible:
		_end_panel.pivot_offset = _end_panel.size * 0.5
		_end_icon.pivot_offset = _end_icon.size * 0.5
		_end_icon.scale = Vector2.ONE * (1.0 + 0.06 * sin(_time * 3.0))
