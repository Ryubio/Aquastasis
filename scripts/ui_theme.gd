extends RefCounted
## UITheme: shared palette and the Theme factory for the terminal / DEFCON look.
## The PALETTE section is a frozen contract also used by the 3D map (map_builder.gd);
## the UI module owns everything below it and may extend freely.

# --- PALETTE (do not rename) ------------------------------------------------------
const BG := Color(0.0431, 0.0588, 0.0980)          # #0B0F19
const BG_PANEL := Color(0.0667, 0.0941, 0.1529)    # #111827
const HEALTHY := Color(0.0980, 0.9020, 0.7569)     # #19E6C1 bioluminescent turquoise
const CRISIS := Color(1.0, 0.2314, 0.1882)         # #FF3B30 toxic red
const WARNING := Color(1.0, 0.7843, 0.2392)        # #FFC83D warning yellow
const ASH := Color(0.4196, 0.4471, 0.5020)         # #6B7280 ash grey
const AMBER := Color(0.9098, 0.6392, 0.2392)       # #E8A33D UI accent
const TERRACOTTA := Color(0.7804, 0.3569, 0.2235)  # #C75B39 UI accent
const TEXT := Color(0.847, 0.890, 0.918)           # #D8E3EA
const TEXT_DIM := Color(0.498, 0.557, 0.639)       # #7F8EA3


## Health 0-1 -> crisis red ... warning yellow ... healthy turquoise.
static func health_color(health01: float) -> Color:
	var h: float = clampf(health01, 0.0, 1.0)
	if h < 0.5:
		return CRISIS.lerp(WARNING, h * 2.0)
	return WARNING.lerp(HEALTHY, (h - 0.5) * 2.0)


# --- UI MODULE EXTENSIONS ----------------------------------------------------------
const LINE := Color(0.0980, 0.9020, 0.7569, 0.32)      # neon hairline (turquoise)
const LINE_AMBER := Color(0.9098, 0.6392, 0.2392, 0.55)
const LINE_DIM := Color(0.498, 0.557, 0.639, 0.22)
const DEEP := Color(0.0275, 0.0392, 0.0706)            # deeper than BG for insets
const CHAMFER := 10                                     # angular cut corner size (px)
const PANEL_ALPHA := 0.86

const SIZE_SMALL := 12
const SIZE_BODY := 15
const SIZE_HEADER := 14
const SIZE_VALUE := 20
const SIZE_BUTTON := 16
const SIZE_BIG_BUTTON := 20

static var _mono: Font = null
static var _mono_bold: Font = null
static var _header: Font = null
static var _theme: Theme = null


## Monospace terminal font (Consolas -> Courier New -> system monospace). Covers Latin,
## Turkish and Cyrillic; system fallback is on for any missing glyph.
static func mono_font() -> Font:
	if _mono == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Consolas", "Courier New", "monospace"])
		f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		f.allow_system_fallback = true
		_mono = f
	return _mono


static func mono_bold_font() -> Font:
	if _mono_bold == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Consolas", "Courier New", "monospace"])
		f.font_weight = 700
		f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		f.allow_system_fallback = true
		_mono_bold = f
	return _mono_bold


## Bold mono with wide letter spacing for section headers ("BASIN STATUS").
static func header_font() -> Font:
	if _header == null:
		var fv := FontVariation.new()
		fv.base_font = mono_bold_font()
		fv.set_spacing(TextServer.SPACING_GLYPH, 2)
		_header = fv
	return _header


## Godot's built-in proportional font for long body paragraphs (best Cyrillic/Turkish).
static func body_font() -> Font:
	return ThemeDB.fallback_font


static func with_alpha(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)


static func status_color(status: String) -> Color:
	match status:
		"healthy":
			return HEALTHY
		"stressed":
			return WARNING
		"critical":
			return TERRACOTTA.lerp(CRISIS, 0.5)
		"collapsed":
			return CRISIS
	return TEXT_DIM


## Toast severity: 0 info, 1 good, 2 warning, 3 alarm.
static func severity_color(severity: int) -> Color:
	match severity:
		1:
			return HEALTHY
		2:
			return WARNING
		3:
			return CRISIS
	return Color(0.55, 0.75, 0.95)


## Angular panel box: chamfered top-left / bottom-right corners, thin neon border and a
## soft outer glow (shadow). Every panel and button style is built from this.
static func panel_box(border: Color, bg: Color, border_w: int = 1, glow: Color = Color(0, 0, 0, 0), glow_size: int = 0, chamfer: int = CHAMFER) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.corner_radius_top_left = chamfer
	sb.corner_radius_bottom_right = chamfer
	sb.corner_radius_top_right = 0
	sb.corner_radius_bottom_left = 0
	sb.corner_detail = 1
	sb.anti_aliasing = true
	sb.shadow_color = glow
	sb.shadow_size = glow_size
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	return sb


static func _margins(sb: StyleBox, h: float, v: float) -> StyleBox:
	sb.content_margin_left = h
	sb.content_margin_right = h
	sb.content_margin_top = v
	sb.content_margin_bottom = v
	return sb


## Toast / badge style: dark body with a thick colored stripe on the left.
static func stripe_box(accent: Color, bg_alpha: float = 0.92) -> StyleBoxFlat:
	var sb := panel_box(with_alpha(accent, 0.55), with_alpha(BG_PANEL, bg_alpha), 1, with_alpha(accent, 0.10), 6, 6)
	sb.border_width_left = 3
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 7.0
	sb.content_margin_bottom = 7.0
	return sb


static func badge_box(accent: Color) -> StyleBoxFlat:
	var sb := panel_box(accent, with_alpha(accent, 0.14), 1, with_alpha(accent, 0.22), 5, 5)
	_margins(sb, 10.0, 3.0)
	return sb


## Builds (once) and returns the shared Theme.
static func build_theme() -> Theme:
	if _theme != null:
		return _theme
	var th := Theme.new()
	th.default_font = mono_font()
	th.default_font_size = SIZE_BODY

	# --- Labels -----------------------------------------------------------------
	th.set_color("font_color", "Label", TEXT)
	th.set_color("font_shadow_color", "Label", Color(0.0, 0.0, 0.0, 0.55))
	th.set_constant("shadow_offset_x", "Label", 1)
	th.set_constant("shadow_offset_y", "Label", 1)
	th.set_constant("line_spacing", "Label", 2)
	_label_variation(th, "TitleLabel", mono_bold_font(), 30, TEXT)
	_label_variation(th, "HeaderLabel", header_font(), SIZE_HEADER, AMBER)
	_label_variation(th, "BodyLabel", body_font(), 16, TEXT)
	_label_variation(th, "BodyDimLabel", body_font(), 15, TEXT_DIM)
	_label_variation(th, "DimLabel", mono_font(), SIZE_SMALL, TEXT_DIM)
	_label_variation(th, "SmallLabel", mono_font(), 13, TEXT)
	_label_variation(th, "ValueLabel", mono_bold_font(), SIZE_VALUE, TEXT)
	_label_variation(th, "BigValueLabel", mono_bold_font(), 26, AMBER)
	_label_variation(th, "RegionLabel", mono_bold_font(), 22, TEXT)
	_label_variation(th, "BadgeLabel", header_font(), 12, TEXT)
	_label_variation(th, "TipTitleLabel", mono_bold_font(), 15, HEALTHY)

	# --- Containers ---------------------------------------------------------------
	th.set_constant("separation", "VBoxContainer", 6)
	th.set_constant("separation", "HBoxContainer", 8)
	th.set_constant("h_separation", "GridContainer", 8)
	th.set_constant("v_separation", "GridContainer", 6)
	var sep := StyleBoxLine.new()
	sep.color = LINE
	sep.thickness = 1
	th.set_stylebox("separator", "HSeparator", sep)
	th.set_constant("separation", "HSeparator", 10)

	# --- Panels -------------------------------------------------------------------
	var hud_panel := panel_box(LINE, with_alpha(BG_PANEL, PANEL_ALPHA), 1, with_alpha(HEALTHY, 0.07), 10)
	_margins(hud_panel, 16.0, 12.0)
	th.set_stylebox("panel", "PanelContainer", hud_panel)
	th.set_type_variation("HudPanel", "PanelContainer")
	th.set_stylebox("panel", "HudPanel", hud_panel)

	var top_bar := StyleBoxFlat.new()
	top_bar.bg_color = with_alpha(BG, 0.90)
	top_bar.border_color = LINE_AMBER
	top_bar.border_width_bottom = 1
	top_bar.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	top_bar.shadow_size = 12
	_margins(top_bar, 18.0, 6.0)
	th.set_type_variation("TopBar", "PanelContainer")
	th.set_stylebox("panel", "TopBar", top_bar)

	var inset := panel_box(LINE_DIM, with_alpha(DEEP, 0.75), 1, Color(0, 0, 0, 0), 0, 6)
	_margins(inset, 10.0, 8.0)
	th.set_type_variation("InsetPanel", "PanelContainer")
	th.set_stylebox("panel", "InsetPanel", inset)

	var menu_panel := panel_box(LINE_AMBER, with_alpha(BG_PANEL, 0.94), 1, with_alpha(AMBER, 0.12), 18, 16)
	_margins(menu_panel, 36.0, 28.0)
	th.set_type_variation("MenuPanel", "PanelContainer")
	th.set_stylebox("panel", "MenuPanel", menu_panel)

	var tip := panel_box(with_alpha(HEALTHY, 0.65), with_alpha(DEEP, 0.96), 1, with_alpha(HEALTHY, 0.18), 8, 8)
	_margins(tip, 12.0, 9.0)
	th.set_type_variation("TipPanel", "PanelContainer")
	th.set_stylebox("panel", "TipPanel", tip)
	th.set_stylebox("panel", "TooltipPanel", tip.duplicate())
	th.set_color("font_color", "TooltipLabel", TEXT)
	th.set_font("font", "TooltipLabel", body_font())
	th.set_font_size("font_size", "TooltipLabel", 15)

	th.set_type_variation("ToastPanel", "PanelContainer")
	th.set_stylebox("panel", "ToastPanel", stripe_box(HEALTHY))
	th.set_type_variation("BadgePanel", "PanelContainer")
	th.set_stylebox("panel", "BadgePanel", badge_box(TEXT_DIM))

	# --- Buttons ------------------------------------------------------------------
	_button_set(th, "Button", AMBER, SIZE_BUTTON, 16.0, 9.0)
	_button_set(th, "PrimaryButton", HEALTHY, SIZE_BIG_BUTTON, 28.0, 13.0)
	var prim := panel_box(with_alpha(HEALTHY, 0.75), with_alpha(BG_PANEL.lerp(HEALTHY, 0.12), 0.9), 1, with_alpha(HEALTHY, 0.16), 6, 8)
	_margins(prim, 28.0, 13.0)
	th.set_stylebox("normal", "PrimaryButton", prim)
	th.set_color("font_color", "PrimaryButton", HEALTHY.lerp(Color.WHITE, 0.6))
	_button_set(th, "DangerButton", TERRACOTTA, SIZE_BUTTON, 16.0, 9.0)
	_button_set(th, "ChipButton", HEALTHY, 14, 12.0, 6.0)
	_button_set(th, "SpeedButton", AMBER, 14, 10.0, 6.0)
	_button_set(th, "ActionButton", HEALTHY, 15, 10.0, 8.0)
	_ghost_button(th)

	# --- Progress bar (fallback; HUD bars are drawn by charts.gd) ---------------------
	var pb_bg := panel_box(LINE_DIM, with_alpha(DEEP, 0.9), 1, Color(0, 0, 0, 0), 0, 3)
	_margins(pb_bg, 0.0, 0.0)
	var pb_fill := panel_box(AMBER, with_alpha(AMBER, 0.75), 0, with_alpha(AMBER, 0.3), 4, 3)
	_margins(pb_fill, 0.0, 0.0)
	th.set_stylebox("background", "ProgressBar", pb_bg)
	th.set_stylebox("fill", "ProgressBar", pb_fill)
	th.set_color("font_color", "ProgressBar", TEXT)
	th.set_font_size("font_size", "ProgressBar", SIZE_SMALL)

	_theme = th
	return th


static func _label_variation(th: Theme, variation: String, font: Font, font_size: int, color: Color) -> void:
	th.set_type_variation(variation, "Label")
	th.set_font("font", variation, font)
	th.set_font_size("font_size", variation, font_size)
	th.set_color("font_color", variation, color)


## Full state set for one button family. accent drives border, glow and text tint.
static func _button_set(th: Theme, type_name: String, accent: Color, font_size: int, mh: float, mv: float) -> void:
	if type_name != "Button":
		th.set_type_variation(type_name, "Button")
	var normal := panel_box(with_alpha(accent, 0.45), with_alpha(BG_PANEL, 0.80), 1, Color(0, 0, 0, 0), 0, 8)
	var hover := panel_box(accent, with_alpha(BG_PANEL.lerp(accent, 0.16), 0.92), 1, with_alpha(accent, 0.30), 7, 8)
	var pressed := panel_box(accent, with_alpha(BG_PANEL.lerp(accent, 0.38), 0.95), 2, with_alpha(accent, 0.40), 9, 8)
	var hover_pressed := panel_box(accent.lightened(0.2), with_alpha(BG_PANEL.lerp(accent, 0.46), 0.95), 2, with_alpha(accent, 0.50), 11, 8)
	var disabled := panel_box(with_alpha(ASH, 0.25), with_alpha(BG, 0.70), 1, Color(0, 0, 0, 0), 0, 8)
	for sb in [normal, hover, pressed, hover_pressed, disabled]:
		var box: StyleBox = sb
		_margins(box, mh, mv)
	th.set_stylebox("normal", type_name, normal)
	th.set_stylebox("hover", type_name, hover)
	th.set_stylebox("pressed", type_name, pressed)
	th.set_stylebox("hover_pressed", type_name, hover_pressed)
	th.set_stylebox("disabled", type_name, disabled)
	th.set_stylebox("focus", type_name, StyleBoxEmpty.new())
	th.set_font("font", type_name, mono_bold_font())
	th.set_font_size("font_size", type_name, font_size)
	var bright: Color = accent.lerp(Color.WHITE, 0.55)
	th.set_color("font_color", type_name, TEXT)
	th.set_color("font_hover_color", type_name, bright)
	th.set_color("font_pressed_color", type_name, Color.WHITE)
	th.set_color("font_hover_pressed_color", type_name, Color.WHITE)
	th.set_color("font_focus_color", type_name, TEXT)
	th.set_color("font_disabled_color", type_name, with_alpha(TEXT_DIM, 0.55))
	th.set_color("icon_normal_color", type_name, TEXT)
	th.set_color("icon_hover_color", type_name, bright)
	th.set_color("icon_pressed_color", type_name, Color.WHITE)
	th.set_color("icon_disabled_color", type_name, with_alpha(TEXT_DIM, 0.5))
	th.set_constant("h_separation", type_name, 8)


## Low-key secondary button (Quit, Main Menu): no fill until hovered.
static func _ghost_button(th: Theme) -> void:
	_button_set(th, "GhostButton", TEXT_DIM, SIZE_BUTTON, 16.0, 9.0)
	var normal := panel_box(with_alpha(TEXT_DIM, 0.28), with_alpha(BG, 0.35), 1, Color(0, 0, 0, 0), 0, 8)
	_margins(normal, 16.0, 9.0)
	th.set_stylebox("normal", "GhostButton", normal)
	th.set_color("font_color", "GhostButton", TEXT_DIM)
	th.set_color("font_hover_color", "GhostButton", TEXT)


# --- Juice helpers (callers connect signals to their own methods, then call these) ----

## Hover in/out: gentle scale + brighten, Tween-driven. Ignored for disabled buttons.
static func hover_fx(ctrl: Control, on: bool) -> void:
	if ctrl == null or not ctrl.is_inside_tree():
		return
	var btn := ctrl as BaseButton
	if on and btn != null and btn.disabled:
		return
	_kill_fx(ctrl)
	ctrl.pivot_offset = ctrl.size * 0.5
	var s: float = 1.035 if on else 1.0
	var m: Color = Color(1.14, 1.14, 1.14, 1.0) if on else Color.WHITE
	var tw := ctrl.create_tween()
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(ctrl, "scale", Vector2(s, s), 0.16)
	tw.tween_property(ctrl, "modulate", m, 0.16)
	ctrl.set_meta("fx_tween", tw)


## Press punch: quick squash then settle back to the hover scale.
static func press_fx(ctrl: Control) -> void:
	if ctrl == null or not ctrl.is_inside_tree():
		return
	_kill_fx(ctrl)
	ctrl.pivot_offset = ctrl.size * 0.5
	var tw := ctrl.create_tween()
	tw.set_trans(Tween.TRANS_BACK)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(ctrl, "scale", Vector2(0.95, 0.95), 0.05)
	tw.tween_property(ctrl, "scale", Vector2(1.035, 1.035), 0.22)
	ctrl.set_meta("fx_tween", tw)


## Resets scale/modulate instantly (e.g. after a button became disabled while hovered).
static func reset_fx(ctrl: Control) -> void:
	if ctrl == null:
		return
	_kill_fx(ctrl)
	ctrl.scale = Vector2.ONE
	ctrl.modulate = Color.WHITE


static func _kill_fx(ctrl: Control) -> void:
	if ctrl.has_meta("fx_tween"):
		var old: Tween = ctrl.get_meta("fx_tween") as Tween
		if old != null and old.is_valid():
			old.kill()


## Corner-bracket frame (call from a draw callback / _draw of `ci`).
static func draw_brackets(ci: CanvasItem, rect: Rect2, color: Color, arm: float = 14.0, width: float = 2.0) -> void:
	var p0: Vector2 = rect.position
	var p1: Vector2 = rect.position + Vector2(rect.size.x, 0.0)
	var p2: Vector2 = rect.position + rect.size
	var p3: Vector2 = rect.position + Vector2(0.0, rect.size.y)
	var glow: Color = with_alpha(color, color.a * 0.22)
	var corners: Array = [
		[p0 + Vector2(0.0, arm), p0, p0 + Vector2(arm, 0.0)],
		[p1 + Vector2(-arm, 0.0), p1, p1 + Vector2(0.0, arm)],
		[p2 + Vector2(0.0, -arm), p2, p2 + Vector2(-arm, 0.0)],
		[p3 + Vector2(arm, 0.0), p3, p3 + Vector2(0.0, -arm)],
	]
	for c in corners:
		var pts := PackedVector2Array(c)
		ci.draw_polyline(pts, glow, width * 3.0, true)
		ci.draw_polyline(pts, color, width, true)


## Neon line: wide faint glow under a crisp core.
static func glow_line(ci: CanvasItem, a: Vector2, b: Vector2, color: Color, width: float = 1.5) -> void:
	ci.draw_line(a, b, with_alpha(color, color.a * 0.18), width * 4.0, true)
	ci.draw_line(a, b, color, width, true)


# --- PHASE 2 HUD ADDITIONS (append only: ticker, bubbles, key hints) ------------------
const SCIENCE_BLUE := Color(0.42, 0.78, 1.0)
const BUBBLE_SCIENCE := Color(0.30, 0.86, 1.0)       # turquoise-blue data bubble
const BUBBLE_POLITICAL := Color(1.0, 0.72, 0.26)     # amber support bubble


## News tone: -1 alarming (red), 0 neutral (amber), 1 hopeful (turquoise).
static func tone_color(tone: int) -> Color:
	if tone < 0:
		return CRISIS
	if tone > 0:
		return HEALTHY
	return AMBER


## Small keyboard-key chip (Q / W / E / T hints): thin border, thicker bottom edge.
static func keycap_box(accent: Color) -> StyleBoxFlat:
	var sb := panel_box(with_alpha(accent, 0.7), with_alpha(DEEP, 0.85), 1, Color(0, 0, 0, 0), 0, 3)
	sb.border_width_bottom = 2
	_margins(sb, 6.0, 1.0)
	return sb


## Dashed straight line (call from a draw callback of `ci`).
static func dashed_line(ci: CanvasItem, a: Vector2, b: Vector2, color: Color, width: float = 1.0, dash: float = 5.0, gap: float = 4.0) -> void:
	var length: float = a.distance_to(b)
	if length < 0.5:
		return
	var dir: Vector2 = (b - a) / length
	var d: float = 0.0
	while d < length:
		var e: float = minf(d + dash, length)
		ci.draw_line(a + dir * d, a + dir * e, color, width, true)
		d += dash + gap
