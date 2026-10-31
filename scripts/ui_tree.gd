extends Control
## UITree: the policy tree modal (T key / POLICY TREE button). Four branch columns of node
## tiles joined by glowing prerequisite links, a details pane (cost, effect, counter-evolution,
## real-world fact, ADOPT) and the crisis-adaptation strip. Time is paused while it is open.

const UITheme := preload("res://scripts/ui_theme.gd")
const Icons := preload("res://scripts/icons.gd")
const TechTree := preload("res://scripts/tech_tree.gd")

const PANEL_SIZE := Vector2(1600.0, 860.0)
const PAD := 22.0
const BODY_Y := 88.0
const STRIP_H := 126.0
const STRIP_GAP := 12.0
const DETAILS_W := 456.0
const GAP := 16.0
const COL_HEAD_H := 60.0
const TILE := Vector2(124.0, 102.0)
const TILE_ICON := 44.0
const TILE_DX := 67.0
const CHAMFER := 12.0
const ADOPT_AREA_H := 104.0
const STRIP_LEFT_W := 900.0
const MAX_CHIPS := 2
const RES_ORDER := ["budget", "political", "science"]
const RES_KEYS := {"budget": "hud.budget", "political": "hud.political", "science": "hud.science"}
const RES_COLORS := {
	"budget": Color(0.9098, 0.6392, 0.2392),
	"political": Color(0.95, 0.50, 0.36),
	"science": Color(0.42, 0.78, 1.0),
}
const SCIENCE_COL := Color(0.42, 0.78, 1.0)
const STATE_KEYS := {
	"locked": "ui.tree.state.locked",
	"available": "ui.tree.state.available",
	"affordable": "ui.tree.state.affordable",
	"adopted": "ui.tree.state.adopted",
}
const NAME_SIZES := [14, 13, 12, 11]
const DESC_SIZES := [15, 14, 13]
const FACT_SIZES := [14, 13, 12]

var _open: bool = false
var _time: float = 0.0
var _open_t: float = 9.0
var _scan: float = 1.0
var _anim: Tween = null
var _snap: Dictionary = {}
var _selected_id: String = ""
var _hover_id: String = ""
var _adopt_flash: float = 0.0
var _adopt_enabled: bool = false
var _fit_level: int = 0
var _fit_tries: int = 0
var _tr_labels: Array = []          # [[Label, key], ...] re-rendered on language_changed

# Layout roots
var _backdrop: Control
var _panel: Control
var _panel_style: StyleBoxFlat
var _canvas: Control
var _links: Control
var _details: Control
var _details_style: StyleBoxFlat
var _strip: Control
var _strip_style: StyleBoxFlat

# Header
var _count_label: Label
var _res_values: Dictionary = {}    # resource -> Label
var _close_btn: Button
var _close_row: HBoxContainer

# Columns and tiles
var _col_counts: Dictionary = {}    # branch -> Label
var _tiles: Dictionary = {}         # node id -> Control
var _tile_icons: Dictionary = {}    # node id -> Icons
var _tile_names: Dictionary = {}    # node id -> Label
var _tile_base: Dictionary = {}     # node id -> Vector2 resting position
var _tile_delay: Dictionary = {}    # node id -> float cascade delay on open
var _tile_state: Dictionary = {}    # node id -> "locked" | "available" | "affordable" | "adopted"
var _tile_hover: Dictionary = {}    # node id -> float 0..1 hover glow (tweened)
var _tile_tweens: Dictionary = {}   # node id -> Tween
var _burst: Dictionary = {}         # node id -> float 1..0 adoption flash
var _centers: Dictionary = {}       # node id -> Vector2 tile centre (canvas space)
var _link_data: Array = []          # Dictionary per prerequisite link

# Details pane
var _d_clip: Control
var _d_box: VBoxContainer
var _d_badge: PanelContainer
var _d_branch: Label
var _d_tier: Label
var _d_frame: Control
var _d_icon: Icons
var _d_name: Label
var _d_state_badge: PanelContainer
var _d_state: Label
var _d_cost_chips: Dictionary = {}  # resource -> HBoxContainer
var _d_cost_vals: Dictionary = {}   # resource -> Label
var _d_free: Label
var _d_req_rows: Array = []         # [HBoxContainer, Icons, Label]
var _d_req_none: Label
var _d_desc: Label
var _d_evo_row: HBoxContainer
var _d_evo_icon: Icons
var _d_evo_name: Label
var _d_evo_note: Label
var _d_fact: Label
var _adopt_btn: Button
var _adopt_icon: Icons
var _adopt_base: Vector2 = Vector2.ZERO
var _why: Label

# Evolution strip
var _evo_moves: Label
var _evo_limit: Label
var _evo_bars: Dictionary = {}      # branch -> Control
var _evo_vals: Dictionary = {}      # branch -> Label
var _evo_shown: Dictionary = {}     # branch -> float (animated share)
var _pressure: Dictionary = {}
var _active: Array = []
var _resist_box: HBoxContainer
var _resist_none: Label
var _resist_more: Label
var _resist_sig: String = ""

# Repeatable Science Projects
var _proj_algae_btn: Button
var _proj_algae_cost: Label
var _proj_algae_cd: Label
var _proj_drone_btn: Button
var _proj_drone_cost: Label
var _proj_drone_cd: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UITheme.build_theme()
	visible = false
	_build()
	resized.connect(_layout)
	EventBus.language_changed.connect(_on_language_changed)
	EventBus.resources_changed.connect(_on_resources_changed)
	EventBus.tick_done.connect(_on_tick_done)
	EventBus.node_adopted.connect(_on_node_adopted)
	EventBus.evolution_happened.connect(_on_evolution_changed)
	EventBus.evolution_cured.connect(_on_evolution_changed)
	EventBus.event_resolved.connect(_on_event_resolved)
	EventBus.game_started.connect(_on_game_started)
	set_process(false)


# --- Frozen public API -------------------------------------------------------------------

func open() -> void:
	if _open:
		return
	_open = true
	visible = true
	GameState.set_pause_reason("tree", true)
	EventBus.tree_toggled.emit(true)
	_hover_id = ""
	_snap = GameState.get_snapshot()
	_refresh_states()
	if _selected_id == "" or not _tiles.has(_selected_id):
		_selected_id = _default_selection()
	_refresh_all()
	_open_t = 0.0
	_apply_cascade()
	set_process(true)
	_play_open()


func close() -> void:
	if not _open:
		return
	_open = false
	GameState.set_pause_reason("tree", false)
	EventBus.tree_toggled.emit(false)
	_play_close()


func toggle() -> void:
	if _open:
		close()
	else:
		open()


func is_open() -> bool:
	return _open


# --- Small builders -------------------------------------------------------------------

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


func _spacer() -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


func _vline(h: float) -> ColorRect:
	var r := ColorRect.new()
	r.color = UITheme.LINE
	r.custom_minimum_size = Vector2(1.0, h)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Single line trimmed with an ellipsis (no clip_text: it cuts Turkish / Russian diacritics).
func _ellipsis(l: Label) -> void:
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _wrap(l: Label) -> void:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _section_head(key: String) -> Label:
	var l := _label("HeaderLabel", key)
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", UITheme.AMBER.lerp(UITheme.TEXT_DIM, 0.35))
	_ellipsis(l)
	return l


## Keyboard hint chip ("Esc") drawn like a small key.
func _keycap(key_text: String, accent: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := UITheme.panel_box(UITheme.with_alpha(accent, 0.7), UITheme.with_alpha(UITheme.DEEP, 0.85), 1, Color(0, 0, 0, 0), 0, 3)
	sb.border_width_bottom = 2
	sb.content_margin_left = 5.0
	sb.content_margin_right = 5.0
	sb.content_margin_top = 0.0
	sb.content_margin_bottom = 0.0
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := _label("SmallLabel")
	l.text = key_text
	l.add_theme_font_override("font", UITheme.mono_bold_font())
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", accent.lerp(Color.WHITE, 0.35))
	p.add_child(l)
	return p


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


# --- Data helpers -----------------------------------------------------------------------

func _branch_color(branch: String) -> Color:
	var info: Dictionary = TechTree.BRANCH_INFO.get(branch, {})
	match str(info.get("color", "")):
		"healthy":
			return UITheme.HEALTHY
		"amber":
			return UITheme.AMBER
		"science":
			return SCIENCE_COL
		"terracotta":
			return UITheme.TERRACOTTA.lightened(0.14)
	return UITheme.TEXT_DIM


func _branch_of(node_id: String) -> String:
	var def: Dictionary = TechTree.node_def(node_id)
	return str(def.get("branch", ""))


func _branch_index(node_id: String) -> int:
	return maxi(TechTree.BRANCHES.find(_branch_of(node_id)), 0)


func _node_color(node_id: String) -> Color:
	return _branch_color(_branch_of(node_id))


func _tier_count(branch: String, tier: int) -> int:
	var n: int = 0
	for d in TechTree.branch_nodes(branch):
		var def: Dictionary = d
		if int(def.get("tier", 0)) == tier:
			n += 1
	return n


func _canvas_w() -> float:
	return PANEL_SIZE.x - PAD * 2.0 - GAP - DETAILS_W


func _body_h() -> float:
	return PANEL_SIZE.y - BODY_Y - PAD - STRIP_H - STRIP_GAP


func _tier_y(tier: int) -> float:
	var top: float = COL_HEAD_H + 6.0
	var area: float = _body_h() - top - 4.0
	return top + area * ((float(tier) - 0.5) / 4.0)


## "locked" | "available" (prerequisites met, cannot pay yet) | "affordable" | "adopted".
func _vis_state(node_id: String) -> String:
	var st: String = GameState.node_state(node_id)
	if st == "adopted":
		return "adopted"
	if st == "available":
		return "affordable" if GameState.can_adopt(node_id) else "available"
	return "locked"


func _state_of(node_id: String) -> String:
	var st: String = _tile_state.get(node_id, "locked")
	return st


func _cost_of(node_id: String) -> Dictionary:
	var c: Dictionary = GameState.node_cost(node_id)
	if c.is_empty():
		var def: Dictionary = TechTree.node_def(node_id)
		c = def.get("cost", {})
	return c


func _pct(v01: float) -> String:
	return I18n.t("fmt.pct", {"v": str(int(roundf(clampf(v01, 0.0, 1.0) * 100.0)))})


func _shown_id() -> String:
	if _hover_id != "" and _tiles.has(_hover_id):
		return _hover_id
	return _selected_id


func _default_selection() -> String:
	var first_available: String = ""
	for n in TechTree.all_nodes():
		var def: Dictionary = n
		var id: String = str(def.get("id", ""))
		var st: String = _state_of(id)
		if st == "affordable":
			return id
		if st == "available" and first_available == "":
			first_available = id
	if first_available != "":
		return first_available
	var nodes: Array = TechTree.all_nodes()
	if nodes.is_empty():
		return ""
	var first: Dictionary = nodes[0]
	return str(first.get("id", ""))


func _branch_resistant(branch: String) -> bool:
	for e in TechTree.all_evolutions():
		var def: Dictionary = e
		if str(def.get("trigger", "")) == "branch" and str(def.get("branch", "")) == branch:
			if _active.has(str(def.get("id", ""))):
				return true
	return false


func _chamfer_pts(r: Rect2, cut: float) -> PackedVector2Array:
	return PackedVector2Array([
		r.position + Vector2(cut, 0.0),
		Vector2(r.end.x, r.position.y),
		Vector2(r.end.x, r.end.y - cut),
		r.end - Vector2(cut, 0.0),
		Vector2(r.position.x, r.end.y),
		r.position + Vector2(0.0, cut),
	])


func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts.duplicate()
	if out.size() > 0:
		out.append(out[0])
	return out


# --- Build ------------------------------------------------------------------------------

func _build() -> void:
	_backdrop = Control.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.draw.connect(_draw_backdrop)
	_backdrop.gui_input.connect(_on_backdrop_input)
	add_child(_backdrop)

	_panel_style = UITheme.panel_box(UITheme.LINE_AMBER, UITheme.with_alpha(UITheme.BG_PANEL, 0.97), 1, UITheme.with_alpha(UITheme.AMBER, 0.14), 24, 18)
	_details_style = UITheme.panel_box(UITheme.LINE_DIM, UITheme.with_alpha(UITheme.DEEP, 0.78), 1, Color(0, 0, 0, 0), 0, 10)
	_strip_style = UITheme.panel_box(UITheme.LINE_DIM, UITheme.with_alpha(UITheme.DEEP, 0.78), 1, Color(0, 0, 0, 0), 0, 10)

	_panel = Control.new()
	_panel.size = PANEL_SIZE
	_panel.pivot_offset = PANEL_SIZE * 0.5
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.draw.connect(_draw_panel)
	add_child(_panel)

	_build_header()
	_build_canvas()
	_build_details()
	_build_strip()
	_layout()


func _layout() -> void:
	if _panel == null:
		return
	_panel.position = ((size - PANEL_SIZE) * 0.5).floor()
	_backdrop.queue_redraw()


func _build_header() -> void:
	var row := _hbox(14)
	row.position = Vector2(PAD, 18.0)
	row.size = Vector2(PANEL_SIZE.x - PAD * 2.0, 52.0)
	_panel.add_child(row)
	row.add_child(_icon("tree", UITheme.AMBER, 40.0))

	var titles := _vbox(0)
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(titles)
	var title := _label("TitleLabel", "ui.tree.title")
	title.add_theme_font_override("font", UITheme.header_font())
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", UITheme.AMBER.lerp(Color.WHITE, 0.2))
	_ellipsis(title)
	titles.add_child(title)
	var sub := _label("DimLabel", "ui.tree.subtitle")
	sub.add_theme_font_size_override("font_size", 13)
	_ellipsis(sub)
	titles.add_child(sub)

	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_stylebox_override("panel", UITheme.badge_box(UITheme.HEALTHY))
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_count_label = _label("BadgeLabel")
	_count_label.add_theme_color_override("font_color", UITheme.HEALTHY.lerp(Color.WHITE, 0.4))
	badge.add_child(_count_label)
	row.add_child(badge)
	row.add_child(_vline(36.0))

	for r in RES_ORDER:
		var res: String = r
		var col: Color = RES_COLORS[res]
		var blk := _hbox(8)
		blk.add_child(_icon(res, col, 26.0))
		var vb := _vbox(0)
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		var val := _label("ValueLabel")
		val.add_theme_font_size_override("font_size", 19)
		val.add_theme_color_override("font_color", col.lerp(Color.WHITE, 0.3))
		vb.add_child(val)
		vb.add_child(_label("DimLabel", str(RES_KEYS[res])))
		blk.add_child(vb)
		row.add_child(blk)
		_res_values[res] = val
	row.add_child(_vline(36.0))

	_close_btn = Button.new()
	_close_btn.theme_type_variation = &"GhostButton"
	_close_btn.custom_minimum_size = Vector2(150.0, 42.0)
	_close_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_wire_button(_close_btn)
	_close_btn.pressed.connect(close)
	row.add_child(_close_btn)
	_close_row = _hbox(8)
	_close_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_close_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_close_row.add_child(_icon("close", UITheme.TEXT, 14.0))
	var cl := _label("SmallLabel", "ui.tree.close")
	cl.add_theme_font_override("font", UITheme.mono_bold_font())
	_close_row.add_child(cl)
	_close_row.add_child(_keycap("Esc", UITheme.TEXT_DIM))
	_close_btn.add_child(_close_row)


func _build_canvas() -> void:
	var cw: float = _canvas_w()
	_canvas = Control.new()
	_canvas.position = Vector2(PAD, BODY_Y)
	_canvas.size = Vector2(cw, _body_h())
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_canvas)
	_panel.add_child(_canvas)

	_links = Control.new()
	_links.position = Vector2.ZERO
	_links.size = _canvas.size
	_links.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_links.draw.connect(_draw_links)
	_canvas.add_child(_links)

	var colw: float = cw / 4.0
	for i in TechTree.BRANCHES.size():
		var branch: String = TechTree.BRANCHES[i]
		var info: Dictionary = TechTree.BRANCH_INFO.get(branch, {})
		var col: Color = _branch_color(branch)
		var head := _hbox(10)
		head.position = Vector2(colw * float(i) + 12.0, 8.0)
		head.size = Vector2(colw - 24.0, COL_HEAD_H - 16.0)
		_canvas.add_child(head)
		head.add_child(_icon(str(info.get("icon", "branch_" + branch)), col, 32.0))
		var txt := _vbox(2)
		txt.alignment = BoxContainer.ALIGNMENT_CENTER
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(txt)
		var nm := _label("HeaderLabel", str(info.get("name_key", "")))
		nm.add_theme_font_size_override("font_size", 13)
		nm.add_theme_color_override("font_color", col.lerp(Color.WHITE, 0.2))
		_ellipsis(nm)
		txt.add_child(nm)
		var sub := _hbox(6)
		txt.add_child(sub)
		var cnt := _label("DimLabel")
		sub.add_child(cnt)
		_col_counts[branch] = cnt
		var uses: Dictionary = {}
		for d in TechTree.branch_nodes(branch):
			var def: Dictionary = d
			var cost: Dictionary = def.get("cost", {})
			for r in RES_ORDER:
				var res: String = r
				if float(cost.get(res, 0.0)) > 0.0:
					uses[res] = true
		sub.add_child(_spacer())
		for r2 in RES_ORDER:
			var res2: String = r2
			if uses.has(res2):
				sub.add_child(_icon(res2, RES_COLORS[res2], 14.0))

	for n in TechTree.all_nodes():
		var def2: Dictionary = n
		_make_tile(def2)
	_build_links()


func _make_tile(def: Dictionary) -> void:
	var id: String = str(def.get("id", ""))
	var branch: String = str(def.get("branch", ""))
	var bi: int = maxi(TechTree.BRANCHES.find(branch), 0)
	var tier: int = clampi(int(def.get("tier", 1)), 1, 4)
	var slot: int = int(def.get("slot", 0))
	var colw: float = _canvas_w() / 4.0
	var cx: float = colw * (float(bi) + 0.5)
	if _tier_count(branch, tier) > 1:
		cx += -TILE_DX if slot == 0 else TILE_DX
	var center := Vector2(cx, _tier_y(tier))
	_centers[id] = center

	var tile := Control.new()
	tile.size = TILE
	tile.position = (center - TILE * 0.5).floor()
	tile.pivot_offset = TILE * 0.5
	tile.mouse_filter = Control.MOUSE_FILTER_STOP
	tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tile.draw.connect(_draw_tile.bind(id))
	tile.mouse_entered.connect(_on_tile_hover.bind(id, true))
	tile.mouse_exited.connect(_on_tile_hover.bind(id, false))
	tile.gui_input.connect(_on_tile_input.bind(id))
	_canvas.add_child(tile)
	_tiles[id] = tile
	_tile_base[id] = tile.position
	_tile_delay[id] = 0.06 + float(tier - 1) * 0.07 + float(bi) * 0.03 + float(slot) * 0.015
	_tile_hover[id] = 0.0
	_tile_state[id] = "locked"

	var ic: Icons = Icons.new()
	ic.setup(str(def.get("icon", "")), UITheme.ASH, TILE_ICON)
	ic.size = Vector2(TILE_ICON, TILE_ICON)
	ic.position = Vector2(floorf((TILE.x - TILE_ICON) * 0.5), 9.0)
	tile.add_child(ic)
	_tile_icons[id] = ic

	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.position = Vector2(6.0, 57.0)
	l.size = Vector2(TILE.x - 12.0, TILE.y - 61.0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.max_lines_visible = 2
	l.add_theme_font_override("font", UITheme.body_font())
	l.add_theme_constant_override("line_spacing", 0)
	tile.add_child(l)
	_tile_names[id] = l
	_fit_tile_name(id)


## Picks the largest font size that keeps the policy name within two lines.
func _fit_tile_name(id: String) -> void:
	var l: Label = _tile_names[id]
	var def: Dictionary = TechTree.node_def(id)
	var text: String = I18n.t(str(def.get("name_key", "")))
	l.text = text
	var font: Font = UITheme.body_font()
	var width: float = TILE.x - 14.0
	var chosen: int = int(NAME_SIZES[NAME_SIZES.size() - 1])
	for s in NAME_SIZES:
		var fs: int = s
		var sz: Vector2 = font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, width, fs)
		var lh: float = maxf(font.get_height(fs), 1.0)
		if int(roundf(sz.y / lh)) <= 2:
			chosen = fs
			break
	l.add_theme_font_size_override("font_size", chosen)


func _build_links() -> void:
	_link_data.clear()
	var colw: float = _canvas_w() / 4.0
	for n in TechTree.all_nodes():
		var def: Dictionary = n
		var id: String = str(def.get("id", ""))
		if not _centers.has(id):
			continue
		var reqs: Array = def.get("requires", [])
		for r in reqs:
			var rid: String = str(r)
			if not _centers.has(rid):
				continue
			var a: Vector2 = _centers[rid]
			var b: Vector2 = _centers[id]
			var cross: bool = _branch_of(rid) != _branch_of(id)
			var pts := PackedVector2Array()
			if cross:
				# Circuit-trace routing through the gutter between the two columns.
				var dir: float = signf(b.x - a.x)
				if dir == 0.0:
					dir = 1.0
				var gx: float = colw * float(maxi(_branch_index(rid), _branch_index(id)))
				var path: Array = [
					a + Vector2(dir * TILE.x * 0.5, 0.0),
					Vector2(gx, a.y),
					Vector2(gx, b.y),
					b - Vector2(dir * TILE.x * 0.5, 0.0),
				]
				pts = _rounded_path(path, 12.0)
			else:
				var p0: Vector2 = a + Vector2(0.0, TILE.y * 0.5)
				var p3: Vector2 = b - Vector2(0.0, TILE.y * 0.5)
				var dy: float = (p3.y - p0.y) * 0.6
				pts = _bezier(p0, p0 + Vector2(0.0, dy), p3 - Vector2(0.0, dy), p3, 22)
			var cum := PackedFloat32Array()
			cum.append(0.0)
			var total: float = 0.0
			for i in range(1, pts.size()):
				total += pts[i - 1].distance_to(pts[i])
				cum.append(total)
			_link_data.append({
				"from": rid, "to": id, "pts": pts, "cum": cum, "total": total, "cross": cross,
				"dashes": _dash_pairs(pts, cum, total, 5.0, 5.0),
			})


func _bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n + 1:
		var t: float = float(i) / float(n)
		var u: float = 1.0 - t
		out.append(p0 * (u * u * u) + p1 * (3.0 * u * u * t) + p2 * (3.0 * u * t * t) + p3 * (t * t * t))
	return out


func _rounded_path(path: Array, radius: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var first: Vector2 = path[0]
	out.append(first)
	for i in range(1, path.size() - 1):
		var prev: Vector2 = path[i - 1]
		var p: Vector2 = path[i]
		var nxt: Vector2 = path[i + 1]
		var r: float = minf(radius, minf(p.distance_to(prev), p.distance_to(nxt)) * 0.5)
		var a: Vector2 = p + (prev - p).normalized() * r
		var b: Vector2 = p + (nxt - p).normalized() * r
		for k in 7:
			var t: float = float(k) / 6.0
			out.append(a.lerp(p, t).lerp(p.lerp(b, t), t))
	var last: Vector2 = path[path.size() - 1]
	out.append(last)
	return out


func _point_at(pts: PackedVector2Array, cum: PackedFloat32Array, d: float) -> Vector2:
	if pts.size() == 0:
		return Vector2.ZERO
	if d <= 0.0:
		return pts[0]
	for i in range(1, pts.size()):
		if cum[i] >= d:
			var seg: float = cum[i] - cum[i - 1]
			var t: float = (d - cum[i - 1]) / seg if seg > 0.0001 else 0.0
			return pts[i - 1].lerp(pts[i], t)
	return pts[pts.size() - 1]


## Dash segments along a path as start/end pairs (for one draw_multiline call).
func _dash_pairs(pts: PackedVector2Array, cum: PackedFloat32Array, total: float, dash: float, gap: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var d: float = 0.0
	while d < total:
		var e: float = minf(d + dash, total)
		out.append(_point_at(pts, cum, d))
		out.append(_point_at(pts, cum, e))
		d += dash + gap
	return out


func _build_details() -> void:
	var bh: float = _body_h()
	_details = Control.new()
	_details.position = Vector2(PAD + _canvas_w() + GAP, BODY_Y)
	_details.size = Vector2(DETAILS_W, bh)
	_details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_details.draw.connect(_draw_details_frame)
	_panel.add_child(_details)

	var inner_w: float = DETAILS_W - 36.0
	_d_clip = Control.new()
	_d_clip.position = Vector2(18.0, 16.0)
	_d_clip.size = Vector2(inner_w, bh - 16.0 - ADOPT_AREA_H - 10.0)
	_d_clip.clip_contents = true
	_d_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_details.add_child(_d_clip)

	_d_box = _vbox(8)
	_d_box.position = Vector2.ZERO
	_d_box.size = Vector2(inner_w, 0.0)
	_d_clip.add_child(_d_box)

	# Branch badge + tier
	var top := _hbox(8)
	_d_box.add_child(top)
	_d_badge = PanelContainer.new()
	_d_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_d_badge)
	_d_branch = _label("BadgeLabel")
	_d_badge.add_child(_d_branch)
	top.add_child(_spacer())
	_d_tier = _label("DimLabel")
	top.add_child(_d_tier)

	# Icon frame + name + state
	var name_row := _hbox(14)
	_d_box.add_child(name_row)
	_d_frame = Control.new()
	_d_frame.custom_minimum_size = Vector2(76.0, 76.0)
	_d_frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_d_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_d_frame.pivot_offset = Vector2(38.0, 38.0)
	_d_frame.draw.connect(_draw_detail_frame_icon)
	name_row.add_child(_d_frame)
	_d_icon = Icons.new()
	_d_icon.setup("", UITheme.TEXT, 52.0)
	_d_icon.position = Vector2(12.0, 12.0)
	_d_icon.size = Vector2(52.0, 52.0)
	_d_frame.add_child(_d_icon)
	var nv := _vbox(6)
	nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nv.alignment = BoxContainer.ALIGNMENT_CENTER
	name_row.add_child(nv)
	_d_name = _label("RegionLabel")
	_d_name.add_theme_font_size_override("font_size", 20)
	_wrap(_d_name)
	nv.add_child(_d_name)
	var st_row := _hbox(6)
	nv.add_child(st_row)
	_d_state_badge = PanelContainer.new()
	_d_state_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	st_row.add_child(_d_state_badge)
	_d_state = _label("BadgeLabel")
	_d_state_badge.add_child(_d_state)

	var sep := HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_d_box.add_child(sep)

	# Cost | Requires
	var cr := _hbox(16)
	_d_box.add_child(cr)
	var cost_col := _vbox(5)
	cost_col.custom_minimum_size = Vector2(150.0, 0.0)
	cr.add_child(cost_col)
	cost_col.add_child(_section_head("ui.tree.cost"))
	var chips := _hbox(12)
	cost_col.add_child(chips)
	for r in RES_ORDER:
		var res: String = r
		var chip := _hbox(4)
		chip.add_child(_icon(res, RES_COLORS[res], 18.0))
		var v := _label("ValueLabel")
		v.add_theme_font_size_override("font_size", 17)
		chip.add_child(v)
		chips.add_child(chip)
		_d_cost_chips[res] = chip
		_d_cost_vals[res] = v
	_d_free = _label("SmallLabel", "ui.tree.free")
	_d_free.add_theme_color_override("font_color", UITheme.HEALTHY)
	chips.add_child(_d_free)
	cr.add_child(_vline(40.0))
	var req_col := _vbox(3)
	req_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cr.add_child(req_col)
	req_col.add_child(_section_head("ui.tree.requires"))
	_d_req_none = _label("SmallLabel", "ui.tree.requires_none")
	_d_req_none.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	_wrap(_d_req_none)
	req_col.add_child(_d_req_none)
	for i in 3:
		var rrow := _hbox(6)
		var ric: Icons = _icon("lock", UITheme.ASH, 14.0)
		rrow.add_child(ric)
		var rl := _label("SmallLabel")
		_wrap(rl)
		rrow.add_child(rl)
		req_col.add_child(rrow)
		_d_req_rows.append([rrow, ric, rl])

	# Effect
	_d_box.add_child(_section_head("ui.tree.effect"))
	_d_desc = _label("BodyLabel")
	_wrap(_d_desc)
	_d_box.add_child(_d_desc)

	# Counter evolution
	_d_box.add_child(_section_head("ui.tree.counters"))
	_d_evo_row = _hbox(10)
	_d_box.add_child(_d_evo_row)
	_d_evo_icon = _icon("evolution", UITheme.CRISIS, 30.0)
	_d_evo_row.add_child(_d_evo_icon)
	var ev := _vbox(1)
	ev.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_d_evo_row.add_child(ev)
	_d_evo_name = _label("SmallLabel")
	_d_evo_name.add_theme_font_override("font", UITheme.mono_bold_font())
	_d_evo_name.add_theme_font_size_override("font_size", 14)
	_wrap(_d_evo_name)
	ev.add_child(_d_evo_name)
	_d_evo_note = _label("BodyDimLabel")
	_d_evo_note.add_theme_font_size_override("font_size", 13)
	_wrap(_d_evo_note)
	ev.add_child(_d_evo_note)

	# Real-world fact
	var fact := PanelContainer.new()
	fact.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fact.add_theme_stylebox_override("panel", UITheme.stripe_box(UITheme.AMBER, 0.6))
	_d_box.add_child(fact)
	var fv := _vbox(4)
	fact.add_child(fv)
	var fh := _hbox(8)
	fv.add_child(fh)
	fh.add_child(_icon("globe", UITheme.AMBER, 16.0))
	var fl := _label("HeaderLabel", "ui.tree.real_world")
	fl.add_theme_font_size_override("font_size", 12)
	fh.add_child(fl)
	_d_fact = _label("BodyDimLabel")
	_d_fact.add_theme_color_override("font_color", UITheme.TEXT.lerp(UITheme.TEXT_DIM, 0.3))
	_wrap(_d_fact)
	fv.add_child(_d_fact)

	# ADOPT button + reason line (outside the clip so it is always visible)
	_adopt_btn = Button.new()
	_adopt_btn.theme_type_variation = &"PrimaryButton"
	_adopt_btn.position = Vector2(18.0, bh - ADOPT_AREA_H)
	_adopt_btn.size = Vector2(inner_w, 54.0)
	_adopt_btn.pivot_offset = _adopt_btn.size * 0.5
	_adopt_btn.clip_text = false
	_adopt_btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_adopt_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_wire_button(_adopt_btn)
	_adopt_btn.pressed.connect(_on_adopt_pressed)
	_details.add_child(_adopt_btn)
	_adopt_base = _adopt_btn.position
	_adopt_icon = Icons.new()
	_adopt_icon.setup("check", UITheme.HEALTHY, 22.0)
	_adopt_icon.position = Vector2(18.0, 16.0)
	_adopt_icon.size = Vector2(22.0, 22.0)
	_adopt_btn.add_child(_adopt_icon)

	_why = _label("BodyDimLabel")
	_why.add_theme_font_size_override("font_size", 13)
	_why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_why.max_lines_visible = 2
	_why.position = Vector2(18.0, bh - ADOPT_AREA_H + 60.0)
	_why.size = Vector2(inner_w, 38.0)
	_details.add_child(_why)


func _build_strip() -> void:
	_strip = Control.new()
	_strip.position = Vector2(PAD, PANEL_SIZE.y - PAD - STRIP_H)
	_strip.size = Vector2(PANEL_SIZE.x - PAD * 2.0, STRIP_H)
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip.draw.connect(_draw_strip)
	_panel.add_child(_strip)

	var head := _hbox(10)
	head.position = Vector2(16.0, 10.0)
	head.size = Vector2(STRIP_LEFT_W - 32.0, 24.0)
	_strip.add_child(head)
	head.add_child(_icon("evolution", UITheme.WARNING, 20.0))
	var t := _label("HeaderLabel", "ui.tree.evo.title")
	t.add_theme_color_override("font_color", UITheme.WARNING)
	head.add_child(t)
	_evo_moves = _label("DimLabel")
	_ellipsis(_evo_moves)
	head.add_child(_evo_moves)
	_evo_limit = _label("DimLabel")
	_evo_limit.add_theme_color_override("font_color", UITheme.CRISIS.lerp(UITheme.TEXT, 0.35))
	head.add_child(_evo_limit)

	var hint := _label("BodyDimLabel", "ui.tree.evo.hint")
	hint.add_theme_font_size_override("font_size", 13)
	hint.position = Vector2(16.0, 36.0)
	hint.size = Vector2(STRIP_LEFT_W - 32.0, 20.0)
	hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_strip.add_child(hint)

	var bars := _hbox(18)
	bars.position = Vector2(16.0, 64.0)
	bars.size = Vector2(STRIP_LEFT_W - 32.0, 48.0)
	_strip.add_child(bars)
	for b in TechTree.BRANCHES:
		var branch: String = b
		var info: Dictionary = TechTree.BRANCH_INFO.get(branch, {})
		var col: Color = _branch_color(branch)
		var blk := _vbox(5)
		blk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bars.add_child(blk)
		var top := _hbox(6)
		blk.add_child(top)
		top.add_child(_icon(str(info.get("icon", "branch_" + branch)), col, 16.0))
		var nm := _label("SmallLabel", str(info.get("name_key", "")))
		nm.add_theme_font_size_override("font_size", 12)
		nm.add_theme_color_override("font_color", col.lerp(Color.WHITE, 0.35))
		_ellipsis(nm)
		top.add_child(nm)
		var val := _label("SmallLabel")
		val.add_theme_font_override("font", UITheme.mono_bold_font())
		val.add_theme_font_size_override("font_size", 12)
		top.add_child(val)
		_evo_vals[branch] = val
		var bar := Control.new()
		bar.custom_minimum_size = Vector2(0.0, 14.0)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.draw.connect(_draw_evo_bar.bind(branch))
		blk.add_child(bar)
		_evo_bars[branch] = bar
		_evo_shown[branch] = 0.0

	var rx: float = STRIP_LEFT_W + 18.0
	var rw: float = _strip.size.x - rx - 16.0
	var resist_w: float = 310.0
	var proj_x: float = rx + resist_w + 14.0
	var proj_w: float = rw - resist_w - 14.0

	var rhead := _hbox(10)
	rhead.position = Vector2(rx, 10.0)
	rhead.size = Vector2(resist_w, 24.0)
	_strip.add_child(rhead)
	rhead.add_child(_icon("crisis", UITheme.CRISIS, 18.0))
	var rt := _label("HeaderLabel", "ui.tree.evo.resist_title")
	rt.add_theme_color_override("font_color", UITheme.CRISIS.lerp(Color.WHITE, 0.15))
	_ellipsis(rt)
	rhead.add_child(rt)
	_resist_more = _label("DimLabel")
	rhead.add_child(_resist_more)

	_resist_box = _hbox(12)
	_resist_box.position = Vector2(rx, 40.0)
	_resist_box.size = Vector2(resist_w, 74.0)
	_strip.add_child(_resist_box)

	_resist_none = _label("BodyDimLabel", "ui.tree.evo.none")
	_resist_none.add_theme_font_size_override("font_size", 13)
	_resist_none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_resist_none.max_lines_visible = 3
	_resist_none.position = Vector2(rx, 44.0)
	_resist_none.size = Vector2(resist_w, 60.0)
	_strip.add_child(_resist_none)

	# Repeatable Science Projects
	var phead := _hbox(8)
	phead.position = Vector2(proj_x, 10.0)
	phead.size = Vector2(proj_w, 24.0)
	_strip.add_child(phead)
	phead.add_child(_icon("satellite", SCIENCE_COL, 18.0))
	var pt := _label("HeaderLabel", "tree.projects.title")
	pt.add_theme_font_size_override("font_size", 12)
	pt.add_theme_color_override("font_color", SCIENCE_COL.lerp(Color.WHITE, 0.2))
	_ellipsis(pt)
	phead.add_child(pt)

	var proj_col := _vbox(5)
	proj_col.position = Vector2(proj_x, 38.0)
	proj_col.size = Vector2(proj_w, 76.0)
	_strip.add_child(proj_col)

	_proj_algae_btn = Button.new()
	_proj_algae_btn.custom_minimum_size = Vector2(proj_w, 34.0)
	_proj_algae_btn.theme_type_variation = &"ChipButton"
	_proj_algae_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_proj_algae_btn.tooltip_text = I18n.t("project.bio_algae.desc")
	_proj_algae_btn.pressed.connect(_on_bio_algae_pressed)
	proj_col.add_child(_proj_algae_btn)
	var a_row := _hbox(6)
	a_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	a_row.offset_left = 6.0
	a_row.offset_right = -6.0
	_proj_algae_btn.add_child(a_row)
	a_row.add_child(_icon("posidonia", SCIENCE_COL, 16.0))
	var a_title := _label("SmallLabel", "project.bio_algae.name")
	a_title.add_theme_font_size_override("font_size", 11)
	a_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ellipsis(a_title)
	a_row.add_child(a_title)
	_proj_algae_cost = _label("SmallLabel")
	_proj_algae_cost.text = "40🧪 25💰"
	_proj_algae_cost.add_theme_font_override("font", UITheme.mono_bold_font())
	_proj_algae_cost.add_theme_font_size_override("font_size", 11)
	_proj_algae_cost.add_theme_color_override("font_color", SCIENCE_COL)
	a_row.add_child(_proj_algae_cost)
	_proj_algae_cd = _label("SmallLabel")
	_proj_algae_cd.add_theme_font_size_override("font_size", 11)
	a_row.add_child(_proj_algae_cd)

	_proj_drone_btn = Button.new()
	_proj_drone_btn.custom_minimum_size = Vector2(proj_w, 34.0)
	_proj_drone_btn.theme_type_variation = &"ChipButton"
	_proj_drone_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_proj_drone_btn.tooltip_text = I18n.t("project.drone_swarm.desc")
	_proj_drone_btn.pressed.connect(_on_drone_swarm_pressed)
	proj_col.add_child(_proj_drone_btn)
	var d_row := _hbox(6)
	d_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	d_row.offset_left = 6.0
	d_row.offset_right = -6.0
	_proj_drone_btn.add_child(d_row)
	d_row.add_child(_icon("cleanup", SCIENCE_COL, 16.0))
	var d_title := _label("SmallLabel", "project.drone_swarm.name")
	d_title.add_theme_font_size_override("font_size", 11)
	d_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ellipsis(d_title)
	d_row.add_child(d_title)
	_proj_drone_cost = _label("SmallLabel")
	_proj_drone_cost.text = "30🧪 20💰"
	_proj_drone_cost.add_theme_font_override("font", UITheme.mono_bold_font())
	_proj_drone_cost.add_theme_font_size_override("font_size", 11)
	_proj_drone_cost.add_theme_color_override("font_color", SCIENCE_COL)
	d_row.add_child(_proj_drone_cost)
	_proj_drone_cd = _label("SmallLabel")
	_proj_drone_cd.add_theme_font_size_override("font_size", 11)
	d_row.add_child(_proj_drone_cd)


# --- Refresh ----------------------------------------------------------------------------

func _refresh_all() -> void:
	_snap = GameState.get_snapshot()
	_refresh_states()
	_refresh_header()
	_refresh_details()
	_refresh_strip()
	_canvas.queue_redraw()


func _refresh_states() -> void:
	for k in _tiles:
		var id: String = k
		var st: String = _vis_state(id)
		_tile_state[id] = st
		var col: Color = _node_color(id)
		var ic: Icons = _tile_icons[id]
		var l: Label = _tile_names[id]
		match st:
			"adopted":
				ic.color = col.lerp(Color.WHITE, 0.25)
				l.add_theme_color_override("font_color", col.lerp(Color.WHITE, 0.6))
			"affordable":
				ic.color = col
				l.add_theme_color_override("font_color", UITheme.TEXT)
			"available":
				ic.color = UITheme.with_alpha(col, 0.7)
				l.add_theme_color_override("font_color", UITheme.with_alpha(UITheme.TEXT, 0.8))
			_:
				ic.color = UITheme.with_alpha(UITheme.ASH, 0.75)
				l.add_theme_color_override("font_color", UITheme.with_alpha(UITheme.TEXT_DIM, 0.75))
		var tile: Control = _tiles[id]
		tile.queue_redraw()
	_links.queue_redraw()


func _refresh_header() -> void:
	var adopted: int = 0
	var per_branch: Dictionary = {}
	for k in _tiles:
		var id: String = k
		var branch: String = _branch_of(id)
		if not per_branch.has(branch):
			per_branch[branch] = [0, 0]
		var pair: Array = per_branch[branch]
		pair[1] = int(pair[1]) + 1
		if _state_of(id) == "adopted":
			adopted += 1
			pair[0] = int(pair[0]) + 1
	_count_label.text = I18n.t("ui.tree.adopted_count", {"n": str(adopted), "total": str(_tiles.size())})
	for b in _col_counts:
		var branch2: String = b
		var lab: Label = _col_counts[branch2]
		var pr: Array = per_branch.get(branch2, [0, 0])
		lab.text = I18n.t("ui.tree.adopted_count", {"n": str(pr[0]), "total": str(pr[1])})
	for r in RES_ORDER:
		var res: String = r
		var val: Label = _res_values[res]
		val.text = str(int(floorf(float(_snap.get(res, 0.0)))))


func _refresh_details() -> void:
	var id: String = _shown_id()
	var def: Dictionary = TechTree.node_def(id)
	if def.is_empty():
		_d_box.visible = false
		_adopt_btn.disabled = true
		_why.text = ""
		_details.queue_redraw()
		return
	_d_box.visible = true
	var branch: String = str(def.get("branch", ""))
	var info: Dictionary = TechTree.BRANCH_INFO.get(branch, {})
	var col: Color = _branch_color(branch)
	var st: String = _state_of(id)
	var ramp: float = GameState.node_ramp(id)

	_d_badge.add_theme_stylebox_override("panel", UITheme.badge_box(col))
	_d_branch.text = I18n.t(str(info.get("name_key", "")))
	_d_branch.add_theme_color_override("font_color", col.lerp(Color.WHITE, 0.45))
	_d_tier.text = I18n.t("ui.tree.tier", {"n": str(int(def.get("tier", 1)))})

	_d_icon.icon_id = str(def.get("icon", ""))
	match st:
		"adopted":
			_d_icon.color = col.lerp(Color.WHITE, 0.3)
		"affordable":
			_d_icon.color = col
		"available":
			_d_icon.color = UITheme.with_alpha(col, 0.75)
		_:
			_d_icon.color = UITheme.ASH.lerp(col, 0.25)
	_d_name.text = I18n.t(str(def.get("name_key", "")))
	_d_name.add_theme_color_override("font_color", col.lerp(Color.WHITE, 0.55) if st == "adopted" else UITheme.TEXT)

	var st_col: Color = UITheme.ASH
	var st_text: String = I18n.t(str(STATE_KEYS.get(st, "ui.tree.state.locked")))
	match st:
		"adopted":
			st_col = UITheme.HEALTHY
			if ramp < 0.999:
				st_text = I18n.t("ui.tree.state.ramping", {"pct": _pct(ramp)})
		"affordable":
			st_col = col
		"available":
			st_col = UITheme.WARNING
	_d_state_badge.add_theme_stylebox_override("panel", UITheme.badge_box(st_col))
	_d_state.text = st_text
	_d_state.add_theme_color_override("font_color", st_col.lerp(Color.WHITE, 0.4))

	var cost: Dictionary = _cost_of(id)
	var any_cost: bool = false
	for r in RES_ORDER:
		var res: String = r
		var v: float = float(cost.get(res, 0.0))
		var chip: HBoxContainer = _d_cost_chips[res]
		chip.visible = v > 0.0
		if v > 0.0:
			any_cost = true
			var have: float = float(_snap.get(res, 0.0))
			var lab: Label = _d_cost_vals[res]
			lab.text = str(int(roundf(v)))
			var short: bool = st != "adopted" and not _snap.is_empty() and have < v
			var rc: Color = RES_COLORS[res]
			lab.add_theme_color_override("font_color", UITheme.CRISIS.lerp(Color.WHITE, 0.2) if short else rc.lerp(Color.WHITE, 0.3))
	_d_free.visible = not any_cost

	var reqs: Array = def.get("requires", [])
	_d_req_none.visible = reqs.is_empty()
	for i in _d_req_rows.size():
		var row: Array = _d_req_rows[i]
		var box: HBoxContainer = row[0]
		var ric: Icons = row[1]
		var rl: Label = row[2]
		if i < reqs.size():
			box.visible = true
			var rid: String = str(reqs[i])
			var rdef: Dictionary = TechTree.node_def(rid)
			var ok: bool = _state_of(rid) == "adopted"
			ric.icon_id = "check" if ok else "lock"
			ric.color = UITheme.HEALTHY if ok else UITheme.ASH
			rl.text = I18n.t(str(rdef.get("name_key", rid)))
			rl.add_theme_color_override("font_color", UITheme.TEXT if ok else UITheme.TEXT_DIM)
		else:
			box.visible = false

	_d_desc.text = _format_node_details_text(def)

	var counters: Array = def.get("counters", [])
	var evo_id: String = str(counters[0]) if not counters.is_empty() else ""
	var edef: Dictionary = TechTree.evolution_def(evo_id)
	_d_evo_row.visible = not edef.is_empty()
	if not edef.is_empty():
		var active: bool = GameState.active_evolutions().has(evo_id)
		_d_evo_icon.icon_id = str(edef.get("icon", "evolution"))
		_d_evo_name.text = I18n.t(str(edef.get("name_key", "")))
		var note_key: String = "ui.tree.counter.prevent"
		var note_col: Color = UITheme.TEXT_DIM
		var icon_col: Color = UITheme.TERRACOTTA.lightened(0.1)
		if st == "adopted":
			note_key = "ui.tree.counter.immune"
			note_col = UITheme.HEALTHY.lerp(UITheme.TEXT, 0.3)
			icon_col = UITheme.ASH
		elif active:
			note_key = "ui.tree.counter.active"
			note_col = UITheme.CRISIS.lerp(Color.WHITE, 0.3)
			icon_col = UITheme.CRISIS
		_d_evo_icon.color = icon_col
		_d_evo_name.add_theme_color_override("font_color", icon_col.lerp(Color.WHITE, 0.4))
		_d_evo_note.text = I18n.t(note_key)
		_d_evo_note.add_theme_color_override("font_color", note_col)

	_d_fact.text = I18n.t(str(def.get("fact_key", "")))
	_refresh_adopt(st, ramp)
	_details.queue_redraw()
	_d_frame.queue_redraw()
	_d_box.size = Vector2(_d_clip.size.x, 0.0)
	_fit_level = 0
	_fit_tries = 0
	_apply_detail_fonts()
	_fit_details.call_deferred()


func _apply_detail_fonts() -> void:
	var lvl: int = clampi(_fit_level, 0, DESC_SIZES.size() - 1)
	_d_desc.add_theme_font_size_override("font_size", int(DESC_SIZES[lvl]))
	_d_fact.add_theme_font_size_override("font_size", int(FACT_SIZES[lvl]))


## Steps the body text down a size when a long (e.g. Russian) text would not fit the pane.
func _fit_details() -> void:
	if not is_instance_valid(_d_box) or not _d_box.visible:
		return
	if _d_desc.size.x < 100.0 and _fit_tries < 3:
		_fit_tries += 1
		_fit_details.call_deferred()
		return
	if _d_box.get_combined_minimum_size().y > _d_clip.size.y and _fit_level < DESC_SIZES.size() - 1:
		_fit_level += 1
		_apply_detail_fonts()
		_fit_details.call_deferred()


func _refresh_adopt(st: String, ramp: float) -> void:
	var can: bool = st == "affordable"
	var why_key: String = "ui.tree.why.ready"
	var why_args: Dictionary = {}
	var why_col: Color = UITheme.TEXT_DIM
	var text_key: String = "ui.tree.adopt"
	var icon_id: String = "check"
	var icon_col: Color = UITheme.HEALTHY.lerp(Color.WHITE, 0.3)
	_adopt_btn.remove_theme_stylebox_override("disabled")
	_adopt_btn.remove_theme_color_override("font_disabled_color")
	if not GameState.running or _snap.is_empty():
		can = false
		why_key = "ui.tree.why.no_game"
		icon_col = UITheme.ASH
	elif st == "adopted":
		text_key = "ui.tree.adopted_button"
		icon_col = UITheme.HEALTHY
		why_col = UITheme.HEALTHY.lerp(UITheme.TEXT, 0.35)
		if ramp < 0.999:
			why_key = "ui.tree.why.ramping"
			why_args = {"pct": _pct(ramp)}
		else:
			why_key = "ui.tree.why.done"
		var done_box := UITheme.panel_box(UITheme.with_alpha(UITheme.HEALTHY, 0.55), UITheme.with_alpha(UITheme.BG_PANEL.lerp(UITheme.HEALTHY, 0.1), 0.9), 1, UITheme.with_alpha(UITheme.HEALTHY, 0.12), 6, 8)
		_adopt_btn.add_theme_stylebox_override("disabled", done_box)
		_adopt_btn.add_theme_color_override("font_disabled_color", UITheme.HEALTHY.lerp(Color.WHITE, 0.45))
	elif st == "locked":
		text_key = "ui.tree.locked_button"
		icon_id = "lock"
		icon_col = UITheme.ASH
		why_key = "ui.tree.why.locked"
		why_col = UITheme.WARNING.lerp(UITheme.TEXT_DIM, 0.4)
	elif st == "available":
		icon_col = UITheme.ASH
		why_col = UITheme.WARNING.lerp(UITheme.TEXT, 0.2)
		why_key = "ui.tree.why.event" if GameState.has_pause_reason("event") else "ui.tree.why.cost"
	_adopt_btn.text = I18n.t(text_key)
	_adopt_btn.disabled = not can
	if _adopt_enabled and not can:
		UITheme.reset_fx(_adopt_btn)
	_adopt_enabled = can
	_adopt_icon.icon_id = icon_id
	_adopt_icon.color = icon_col
	_why.text = I18n.t(why_key, why_args)
	_why.add_theme_color_override("font_color", why_col)


func _refresh_strip() -> void:
	_pressure = GameState.evolution_pressure()
	_active = GameState.active_evolutions()
	var thr: float = clampf(float(_pressure.get("threshold", 1.0)), 0.05, 1.0)
	var moves: int = int(_pressure.get("moves", 0))
	var min_moves: int = int(_pressure.get("min_moves", 0))
	_evo_moves.text = I18n.t("ui.tree.evo.moves", {"n": str(moves), "m": str(min_moves)})
	_evo_limit.text = I18n.t("ui.tree.evo.limit", {"pct": _pct(thr)})
	var shares: Dictionary = _pressure.get("shares", {})
	for b in TechTree.BRANCHES:
		var branch: String = b
		var val: Label = _evo_vals[branch]
		var share: float = clampf(float(shares.get(branch, 0.0)), 0.0, 1.0)
		if _branch_resistant(branch):
			val.text = I18n.t("ui.tree.evo.active_tag")
			val.add_theme_color_override("font_color", UITheme.CRISIS.lerp(Color.WHITE, 0.25))
		else:
			val.text = _pct(share)
			var vc: Color = UITheme.TEXT_DIM
			if share >= thr:
				vc = UITheme.CRISIS
			elif share >= thr * 0.75:
				vc = UITheme.WARNING
			val.add_theme_color_override("font_color", vc)
		var bar: Control = _evo_bars[branch]
		bar.queue_redraw()
	var sig: String = I18n.lang + "|" + ",".join(PackedStringArray(_active))
	for k in _tiles:
		var id: String = k
		sig += "|" + _state_of(id).substr(0, 2)
	if sig != _resist_sig:
		_resist_sig = sig
		_rebuild_resist_chips()
	_refresh_projects()
	_strip.queue_redraw()


func _refresh_projects() -> void:
	if _proj_algae_btn == null or _proj_drone_btn == null:
		return
	var can_a: bool = GameState.can_perform_project("bio_algae")
	var cd_a: int = GameState.project_cooldown_left_ticks("bio_algae")
	_proj_algae_btn.disabled = not can_a
	if cd_a > 0:
		_proj_algae_cd.text = I18n.t("tree.projects.cooldown", {"n": str(cd_a)})
		_proj_algae_cd.add_theme_color_override("font_color", UITheme.WARNING)
	else:
		_proj_algae_cd.text = I18n.t("tree.projects.ready")
		_proj_algae_cd.add_theme_color_override("font_color", UITheme.HEALTHY if can_a else UITheme.ASH)

	var can_d: bool = GameState.can_perform_project("drone_swarm")
	var cd_d: int = GameState.project_cooldown_left_ticks("drone_swarm")
	_proj_drone_btn.disabled = not can_d
	if cd_d > 0:
		_proj_drone_cd.text = I18n.t("tree.projects.cooldown", {"n": str(cd_d)})
		_proj_drone_cd.add_theme_color_override("font_color", UITheme.WARNING)
	else:
		_proj_drone_cd.text = I18n.t("tree.projects.ready")
		_proj_drone_cd.add_theme_color_override("font_color", UITheme.HEALTHY if can_d else UITheme.ASH)


func _on_bio_algae_pressed() -> void:
	if GameState.perform_project("bio_algae"):
		_refresh_all()


func _on_drone_swarm_pressed() -> void:
	if GameState.perform_project("drone_swarm"):
		_refresh_all()


func _rebuild_resist_chips() -> void:
	for c in _resist_box.get_children():
		var child: Node = c
		_resist_box.remove_child(child)
		child.queue_free()
	var shown: int = mini(_active.size(), MAX_CHIPS)
	for i in shown:
		_resist_box.add_child(_resist_chip(str(_active[i])))
	_resist_none.visible = _active.is_empty()
	if _active.size() > shown:
		_resist_more.text = I18n.t("ui.tree.evo.more", {"n": str(_active.size() - shown)})
	else:
		_resist_more.text = ""


func _resist_chip(evo_id: String) -> PanelContainer:
	var def: Dictionary = TechTree.evolution_def(evo_id)
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", UITheme.stripe_box(UITheme.CRISIS, 0.8))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := _hbox(10)
	p.add_child(row)
	row.add_child(_icon(str(def.get("icon", "evolution")), UITheme.CRISIS.lerp(Color.WHITE, 0.15), 30.0))
	var col := _vbox(4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var nm := _label("SmallLabel")
	nm.text = I18n.t(str(def.get("name_key", evo_id)))
	nm.add_theme_font_override("font", UITheme.mono_bold_font())
	nm.add_theme_color_override("font_color", UITheme.CRISIS.lerp(Color.WHITE, 0.45))
	_ellipsis(nm)
	col.add_child(nm)
	var cure := _hbox(5)
	col.add_child(cure)
	var cl := _label("DimLabel")
	cl.text = I18n.t("ui.tree.evo.cure")
	cure.add_child(cl)
	for nid in TechTree.counters_of(evo_id):
		cure.add_child(_counter_button(str(nid)))

	var can_synth: bool = GameState.can_synthesize_counter(evo_id)
	var synth_btn := Button.new()
	synth_btn.text = I18n.t("tree.counter_synth.btn", {"cost": "30"})
	synth_btn.theme_type_variation = &"ChipButton"
	synth_btn.focus_mode = Control.FOCUS_NONE
	synth_btn.disabled = not can_synth
	synth_btn.tooltip_text = I18n.t("tree.counter_synth.tip")
	synth_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if can_synth else Control.CURSOR_ARROW
	synth_btn.pressed.connect(func() -> void:
		if GameState.synthesize_counter(evo_id):
			_refresh_all()
	)
	cure.add_child(synth_btn)
	return p


func _format_node_details_text(def: Dictionary) -> String:
	var desc: String = I18n.t(str(def.get("desc_key", "")))
	var lines := [desc]
	var bullets: Array = []
	for eff in def.get("effects", []):
		var op: String = str(eff.get("op", ""))
		var val: float = float(eff.get("value", 0.0))
		match op:
			"region":
				var stat: String = str(eff.get("stat", ""))
				bullets.append("• +%d %s" % [int(val), stat.capitalize()])
			"mul":
				var k: String = str(eff.get("key", "")).replace("_mult", "").replace("_", " ")
				var pct: int = roundi((val - 1.0) * 100.0)
				var sgn: String = "+" if pct > 0 else ""
				bullets.append("• %s: %s%d%%" % [k.capitalize(), sgn, pct])
			"add":
				var k: String = str(eff.get("key", "")).replace("_", " ")
				bullets.append("• %s: +%.1f" % [k.capitalize(), val])
	if not bullets.is_empty():
		lines.append("")
		lines.append_array(bullets)
	if def.get("requires", []).size() > 1:
		lines.append("• Sinerji / Synergy: Çapraz dal entegrasyonu")
	return "\n".join(lines)


## Small icon button for a counter policy: hover previews it, click selects it in the tree.
func _counter_button(node_id: String) -> Button:
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(28.0, 28.0)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var col: Color = _node_color(node_id)
	var st: String = _state_of(node_id)
	var normal := UITheme.panel_box(UITheme.with_alpha(col, 0.5), UITheme.with_alpha(UITheme.DEEP, 0.85), 1, Color(0, 0, 0, 0), 0, 4)
	var hover := UITheme.panel_box(col, UITheme.with_alpha(UITheme.BG_PANEL.lerp(col, 0.22), 0.95), 1, UITheme.with_alpha(col, 0.3), 5, 4)
	for sb in [normal, hover]:
		var box: StyleBoxFlat = sb
		box.content_margin_left = 2.0
		box.content_margin_right = 2.0
		box.content_margin_top = 2.0
		box.content_margin_bottom = 2.0
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("hover_pressed", hover)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var def: Dictionary = TechTree.node_def(node_id)
	var ic_col: Color = col
	if st == "locked":
		ic_col = UITheme.with_alpha(UITheme.ASH, 0.85)
	elif st == "adopted":
		ic_col = col.lerp(Color.WHITE, 0.3)
	var ic: Icons = Icons.new()
	ic.setup(str(def.get("icon", "")), ic_col, 20.0)
	ic.position = Vector2(4.0, 4.0)
	ic.size = Vector2(20.0, 20.0)
	btn.add_child(ic)
	btn.mouse_entered.connect(_on_counter_hover.bind(btn, node_id, true))
	btn.mouse_exited.connect(_on_counter_hover.bind(btn, node_id, false))
	btn.pressed.connect(_select.bind(node_id))
	return btn


# --- Interaction -------------------------------------------------------------------------

func _on_backdrop_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
		close()


func _on_tile_hover(id: String, on: bool) -> void:
	if on:
		_hover_id = id
	elif _hover_id == id:
		_hover_id = ""
	_tween_tile(id, on)
	_refresh_details()
	_links.queue_redraw()


func _on_counter_hover(btn: Button, node_id: String, on: bool) -> void:
	UITheme.hover_fx(btn, on)
	if on:
		_hover_id = node_id
		_tween_tile(node_id, true)
	elif _hover_id == node_id:
		_hover_id = ""
		_tween_tile(node_id, false)
	_refresh_details()


func _tween_tile(id: String, on: bool) -> void:
	if not _tiles.has(id):
		return
	var tile: Control = _tiles[id]
	if _tile_tweens.has(id):
		var old: Tween = _tile_tweens[id]
		if old != null and old.is_valid():
			old.kill()
	var tw := tile.create_tween()
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.set_ease(Tween.EASE_OUT)
	var s: float = 1.07 if on else 1.0
	tw.tween_property(tile, "scale", Vector2(s, s), 0.16)
	var from: float = float(_tile_hover.get(id, 0.0))
	tw.tween_method(_set_tile_hover.bind(id), from, 1.0 if on else 0.0, 0.16)
	_tile_tweens[id] = tw


func _set_tile_hover(v: float, id: String) -> void:
	_tile_hover[id] = v
	if _tiles.has(id):
		var tile: Control = _tiles[id]
		tile.queue_redraw()


func _on_tile_input(event: InputEvent, id: String) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.double_click:
		_selected_id = id
		_try_adopt(id)
	else:
		_select(id)


func _select(id: String) -> void:
	if not _tiles.has(id):
		return
	_selected_id = id
	var tile: Control = _tiles[id]
	var tw := tile.create_tween()
	tw.set_trans(Tween.TRANS_BACK)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(tile, "scale", Vector2(0.95, 0.95), 0.05)
	tw.tween_property(tile, "scale", Vector2(1.07, 1.07) if _hover_id == id else Vector2.ONE, 0.22)
	_refresh_details()
	_links.queue_redraw()


func _on_adopt_pressed() -> void:
	_try_adopt(_selected_id)


func _try_adopt(id: String) -> void:
	if id == "" or not _tiles.has(id):
		return
	if GameState.adopt_node(id):
		_burst[id] = 1.0
		_adopt_flash = 1.0
		var fr := _d_frame.create_tween()
		fr.set_trans(Tween.TRANS_BACK)
		fr.set_ease(Tween.EASE_OUT)
		fr.tween_property(_d_frame, "scale", Vector2(1.18, 1.18), 0.1)
		fr.tween_property(_d_frame, "scale", Vector2.ONE, 0.32)
		_refresh_all()
	else:
		_shake(_tiles[id], _tile_base[id])
		if _state_of(id) != "adopted":
			_shake(_adopt_btn, _adopt_base)
			_why.text = I18n.t("ui.tree.adopt_failed") if _state_of(id) == "affordable" else _why.text
			_why.add_theme_color_override("font_color", UITheme.CRISIS.lerp(Color.WHITE, 0.25))


func _shake(ctrl: Control, base: Vector2) -> void:
	var tw := ctrl.create_tween()
	var amp: float = 7.0
	for i in 4:
		var dx: float = amp * (1.0 - float(i) * 0.22) * (1.0 if i % 2 == 0 else -1.0)
		tw.tween_property(ctrl, "position", base + Vector2(dx, 0.0), 0.04)
	tw.tween_property(ctrl, "position", base, 0.05)


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
		_try_adopt(_selected_id)
		get_viewport().set_input_as_handled()


# --- EventBus ----------------------------------------------------------------------------

func _on_resources_changed(_budget: float, _political: float, _science: float) -> void:
	if _open:
		_refresh_all()


func _on_tick_done(_snapshot: Dictionary) -> void:
	if _open:
		_refresh_all()


func _on_node_adopted(node_id: String) -> void:
	if _open:
		_burst[node_id] = 1.0
		_refresh_all()


func _on_evolution_changed(_evolution_id: String) -> void:
	if _open:
		_refresh_all()


func _on_event_resolved(_event_id: String, _choice_index: int) -> void:
	if _open:
		_refresh_all()


func _on_game_started() -> void:
	_selected_id = ""
	_hover_id = ""
	_burst.clear()
	_resist_sig = ""
	for b in _evo_shown:
		_evo_shown[b] = 0.0
	if _open:
		_refresh_all()


func _on_language_changed(_lang: String) -> void:
	for pair in _tr_labels:
		var item: Array = pair
		var l: Label = item[0]
		l.text = I18n.t(str(item[1]))
	for k in _tiles:
		_fit_tile_name(str(k))
	_resist_sig = ""
	_close_btn.custom_minimum_size = Vector2(150.0, 42.0)
	_fit_close_button.call_deferred()
	if _open:
		_refresh_all()


func _fit_close_button() -> void:
	var need: float = _close_row.get_combined_minimum_size().x + 28.0
	_close_btn.custom_minimum_size = Vector2(maxf(150.0, need), 42.0)


# --- Animation ---------------------------------------------------------------------------

func _play_open() -> void:
	if _anim != null and _anim.is_valid():
		_anim.kill()
	_backdrop.modulate = Color(1, 1, 1, 0)
	_panel.modulate = Color(1, 1, 1, 0)
	_panel.scale = Vector2(0.965, 0.965)
	_scan = 0.0
	_backdrop.queue_redraw()
	_anim = create_tween()
	_anim.set_parallel(true)
	_anim.tween_property(_backdrop, "modulate:a", 1.0, 0.22)
	_anim.tween_property(_panel, "modulate:a", 1.0, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_anim.tween_property(_panel, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_anim.tween_method(_set_scan, 0.0, 1.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_fit_close_button.call_deferred()


func _play_close() -> void:
	if _anim != null and _anim.is_valid():
		_anim.kill()
	_anim = create_tween()
	_anim.set_parallel(true)
	_anim.tween_property(_backdrop, "modulate:a", 0.0, 0.18)
	_anim.tween_property(_panel, "modulate:a", 0.0, 0.16)
	_anim.tween_property(_panel, "scale", Vector2(0.975, 0.975), 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_anim.chain().tween_callback(_finish_close)


func _finish_close() -> void:
	if _open:
		return
	visible = false
	set_process(false)
	_hover_id = ""
	for k in _tiles:
		var id: String = k
		var tile: Control = _tiles[id]
		tile.scale = Vector2.ONE
		tile.position = _tile_base[id]
		_tile_hover[id] = 0.0
	UITheme.reset_fx(_adopt_btn)
	UITheme.reset_fx(_close_btn)
	_adopt_btn.position = _adopt_base


func _set_scan(v: float) -> void:
	_scan = v
	_panel.queue_redraw()


## Tiles fade and drop in tier by tier for a short moment after opening.
func _apply_cascade() -> void:
	for k in _tiles:
		var id: String = k
		var tile: Control = _tiles[id]
		var base: Vector2 = _tile_base[id]
		var appear: float = clampf((_open_t - float(_tile_delay[id])) / 0.22, 0.0, 1.0)
		var e: float = 1.0 - pow(1.0 - appear, 3.0)
		tile.modulate = Color(1, 1, 1, e)
		tile.position = base + Vector2(0.0, (1.0 - e) * 10.0)


func _process(delta: float) -> void:
	_time += delta
	if _open_t < 1.2:
		_open_t += delta
		_apply_cascade()
	var done: Array = []
	for k in _burst:
		var id: String = k
		var v: float = float(_burst[id]) - delta * 1.3
		if v <= 0.0:
			done.append(id)
		else:
			_burst[id] = v
	for d in done:
		_burst.erase(d)
	if _adopt_flash > 0.0:
		_adopt_flash = maxf(0.0, _adopt_flash - delta * 1.4)
		_details.queue_redraw()
	var shares: Dictionary = _pressure.get("shares", {})
	for b in _evo_shown:
		var branch: String = b
		var target: float = clampf(float(shares.get(branch, 0.0)), 0.0, 1.0)
		var cur: float = float(_evo_shown[branch])
		if absf(target - cur) > 0.001:
			_evo_shown[branch] = lerpf(cur, target, minf(1.0, delta * 6.0))
			var bar: Control = _evo_bars[branch]
			bar.queue_redraw()
	_links.queue_redraw()
	for k2 in _tiles:
		var tile: Control = _tiles[k2]
		tile.queue_redraw()
	_d_frame.queue_redraw()
	if not _active.is_empty():
		_strip.queue_redraw()


# --- Drawing -----------------------------------------------------------------------------

func _draw_backdrop() -> void:
	var w: float = _backdrop.size.x
	var h: float = _backdrop.size.y
	_backdrop.draw_rect(Rect2(0.0, 0.0, w, h), UITheme.with_alpha(UITheme.BG, 0.8))
	var y: float = 0.0
	while y < h:
		_backdrop.draw_line(Vector2(0.0, y), Vector2(w, y), Color(1, 1, 1, 0.014), 1.0)
		y += 4.0
	var edge: float = 220.0
	var dark := Color(0, 0, 0, 0.55)
	var clear := Color(0, 0, 0, 0)
	_backdrop.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, edge), Vector2(0, edge)]), PackedColorArray([dark, dark, clear, clear]))
	_backdrop.draw_polygon(PackedVector2Array([Vector2(0, h - edge), Vector2(w, h - edge), Vector2(w, h), Vector2(0, h)]), PackedColorArray([clear, clear, dark, dark]))
	_backdrop.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(edge, 0), Vector2(edge, h), Vector2(0, h)]), PackedColorArray([dark, clear, clear, dark]))
	_backdrop.draw_polygon(PackedVector2Array([Vector2(w - edge, 0), Vector2(w, 0), Vector2(w, h), Vector2(w - edge, h)]), PackedColorArray([clear, dark, dark, clear]))


func _draw_panel() -> void:
	var r := Rect2(Vector2.ZERO, PANEL_SIZE)
	_panel.draw_style_box(_panel_style, r)
	var y: float = BODY_Y - 12.0
	_panel.draw_line(Vector2(PAD, y), Vector2(PANEL_SIZE.x - PAD, y), UITheme.with_alpha(UITheme.AMBER, 0.28), 1.0)
	_panel.draw_rect(Rect2(PAD, y - 1.5, 90.0, 3.0), UITheme.with_alpha(UITheme.AMBER, 0.85))
	for i in 12:
		var x: float = PANEL_SIZE.x - PAD - float(i) * 9.0
		_panel.draw_line(Vector2(x, y - 4.0), Vector2(x, y), UITheme.with_alpha(UITheme.AMBER, 0.35), 1.0)
	UITheme.draw_brackets(_panel, Rect2(Vector2(-6.0, -6.0), PANEL_SIZE + Vector2(12.0, 12.0)), UITheme.AMBER, 24.0, 2.0)
	if _scan < 1.0:
		var sy: float = _scan * PANEL_SIZE.y
		var a: float = 1.0 - _scan
		_panel.draw_rect(Rect2(2.0, sy - 18.0, PANEL_SIZE.x - 4.0, 18.0), UITheme.with_alpha(UITheme.HEALTHY, 0.05 * a))
		_panel.draw_line(Vector2(2.0, sy), Vector2(PANEL_SIZE.x - 2.0, sy), UITheme.with_alpha(UITheme.HEALTHY, 0.55 * a), 1.5)


func _draw_canvas() -> void:
	var w: float = _canvas.size.x
	var h: float = _canvas.size.y
	var colw: float = w / 4.0
	for t in 4:
		var ty: float = _tier_y(t + 1)
		_dash(_canvas, Vector2(6.0, ty), Vector2(w - 6.0, ty), Color(1, 1, 1, 0.035), 1.0, 2.0, 7.0)
	for i in TechTree.BRANCHES.size():
		var branch: String = TechTree.BRANCHES[i]
		var col: Color = _branch_color(branch)
		var x0: float = colw * float(i)
		_canvas.draw_rect(Rect2(x0 + 3.0, 0.0, colw - 6.0, h), UITheme.with_alpha(col, 0.028))
		var top_c: Color = UITheme.with_alpha(col, 0.13)
		var bot_c: Color = UITheme.with_alpha(col, 0.0)
		_canvas.draw_polygon(PackedVector2Array([
			Vector2(x0 + 3.0, 0.0), Vector2(x0 + colw - 3.0, 0.0),
			Vector2(x0 + colw - 3.0, COL_HEAD_H), Vector2(x0 + 3.0, COL_HEAD_H)]),
			PackedColorArray([top_c, top_c, bot_c, bot_c]))
		_canvas.draw_line(Vector2(x0 + 3.0, COL_HEAD_H - 2.0), Vector2(x0 + colw - 3.0, COL_HEAD_H - 2.0), UITheme.with_alpha(col, 0.55), 1.0)
		_canvas.draw_rect(Rect2(x0 + 3.0, COL_HEAD_H - 4.0, 28.0, 4.0), UITheme.with_alpha(col, 0.9))
		if i > 0:
			_dash(_canvas, Vector2(x0, 4.0), Vector2(x0, h - 4.0), UITheme.with_alpha(UITheme.TEXT_DIM, 0.16), 1.0, 4.0, 5.0)


func _dash(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, width: float, dash: float, gap: float) -> void:
	var length: float = a.distance_to(b)
	if length < 0.5:
		return
	var dir: Vector2 = (b - a) / length
	var d: float = 0.0
	while d < length:
		var e: float = minf(d + dash, length)
		ci.draw_line(a + dir * d, a + dir * e, col, width)
		d += dash + gap


func _draw_links() -> void:
	var focus: String = _shown_id()
	for l in _link_data:
		var link: Dictionary = l
		var from_id: String = link["from"]
		var to_id: String = link["to"]
		var pts: PackedVector2Array = link["pts"]
		var cum: PackedFloat32Array = link["cum"]
		var total: float = link["total"]
		var from_on: bool = _state_of(from_id) == "adopted"
		var to_on: bool = _state_of(to_id) == "adopted"
		var hi: bool = focus != "" and (focus == from_id or focus == to_id)
		var c_from: Color = _node_color(from_id)
		var c_to: Color = _node_color(to_id)
		if from_on and to_on:
			_grad_line(pts, cum, total, c_from, c_to, 1.0, 2.4 + (0.8 if hi else 0.0), 0.2)
			for k in 3:
				var d: float = fposmod(_time * 70.0 + float(k) * total / 3.0, maxf(total, 1.0))
				var p: Vector2 = _point_at(pts, cum, d)
				var pc: Color = c_from.lerp(c_to, d / maxf(total, 1.0)).lerp(Color.WHITE, 0.5)
				_links.draw_circle(p, 6.0, UITheme.with_alpha(pc, 0.22))
				_links.draw_circle(p, 2.6, pc)
		elif from_on:
			_grad_line(pts, cum, total, c_from, c_to, 0.62 + (0.3 if hi else 0.0), 1.6 + (0.8 if hi else 0.0), 0.1)
			var d2: float = fposmod(_time * 42.0, maxf(total, 1.0))
			var p2: Vector2 = _point_at(pts, cum, d2)
			_links.draw_circle(p2, 4.5, UITheme.with_alpha(c_to, 0.18))
			_links.draw_circle(p2, 1.9, UITheme.with_alpha(c_to.lerp(Color.WHITE, 0.4), 0.85))
		else:
			var dashes: PackedVector2Array = link["dashes"]
			var dc: Color = UITheme.with_alpha(UITheme.ASH, 0.38)
			if hi:
				dc = UITheme.with_alpha(c_to, 0.7)
			if dashes.size() >= 2:
				_links.draw_multiline(dashes, dc, 1.3 if not hi else 1.8)


func _grad_line(pts: PackedVector2Array, cum: PackedFloat32Array, total: float, c0: Color, c1: Color, alpha: float, width: float, glow_a: float) -> void:
	if pts.size() < 2:
		return
	if c0 == c1:
		_links.draw_polyline(pts, UITheme.with_alpha(c0, glow_a * alpha), width * 3.6, true)
		_links.draw_polyline(pts, UITheme.with_alpha(c0, alpha), width, true)
		return
	var glow_cols := PackedColorArray()
	var cols := PackedColorArray()
	for i in pts.size():
		var t: float = cum[i] / maxf(total, 1.0)
		var c: Color = c0.lerp(c1, t)
		glow_cols.append(UITheme.with_alpha(c, glow_a * alpha))
		cols.append(UITheme.with_alpha(c, alpha))
	_links.draw_polyline_colors(pts, glow_cols, width * 3.6, true)
	_links.draw_polyline_colors(pts, cols, width, true)


func _draw_tile(id: String) -> void:
	var tile: Control = _tiles[id]
	var st: String = _state_of(id)
	var col: Color = _node_color(id)
	var hov: float = float(_tile_hover.get(id, 0.0))
	var sel: bool = id == _selected_id
	var pulse: float = 0.5 + 0.5 * sin(_time * 3.4 + float(_tile_delay.get(id, 0.0)) * 9.0)
	var w: float = TILE.x
	var h: float = TILE.y
	var pts: PackedVector2Array = _chamfer_pts(Rect2(0.0, 0.0, w, h), CHAMFER)
	var loop: PackedVector2Array = _closed(pts)

	var fill: Color = UITheme.with_alpha(UITheme.DEEP, 0.92)
	var border: Color = UITheme.with_alpha(UITheme.ASH, 0.32)
	var bw: float = 1.0
	var glow_a: float = 0.0
	match st:
		"adopted":
			fill = UITheme.with_alpha(UITheme.BG_PANEL.lerp(col, 0.2), 0.97)
			border = col
			bw = 2.0
			glow_a = 0.12
		"affordable":
			fill = UITheme.with_alpha(UITheme.BG_PANEL.lerp(col, 0.08), 0.96)
			border = UITheme.with_alpha(col, 0.65 + 0.35 * pulse)
			bw = 1.6
			glow_a = 0.08 + 0.14 * pulse
		"available":
			fill = UITheme.with_alpha(UITheme.BG_PANEL, 0.94)
			border = UITheme.with_alpha(col, 0.42)
			bw = 1.2
	glow_a += hov * 0.16
	if sel:
		glow_a += 0.08
	if hov > 0.0:
		border = UITheme.with_alpha(border.lerp(col.lerp(Color.WHITE, 0.35), hov * 0.6), minf(1.0, border.a + hov * 0.35))
	if glow_a > 0.0:
		tile.draw_polyline(loop, UITheme.with_alpha(col, glow_a), 8.0, true)
	tile.draw_colored_polygon(pts, fill)
	if st == "adopted":
		var top_c: Color = UITheme.with_alpha(col, 0.16)
		var bot_c: Color = UITheme.with_alpha(col, 0.0)
		tile.draw_polygon(PackedVector2Array([Vector2(CHAMFER, 1.0), Vector2(w - 1.0, 1.0), Vector2(w - 1.0, h * 0.55), Vector2(1.0, h * 0.55)]), PackedColorArray([top_c, top_c, bot_c, bot_c]))
	tile.draw_polyline(loop, border, bw, true)
	tile.draw_line(Vector2(1.0, CHAMFER + 3.0), Vector2(CHAMFER + 3.0, 1.0), UITheme.with_alpha(col, 0.6 if st != "locked" else 0.25), 2.0, true)

	# State glyph, top-right corner.
	var g := Vector2(w - 15.0, 14.0)
	match st:
		"locked":
			var lc: Color = UITheme.with_alpha(UITheme.ASH, 0.8)
			tile.draw_arc(g + Vector2(0.0, -1.0), 3.6, PI, TAU, 10, lc, 1.5, true)
			tile.draw_rect(Rect2(g.x - 5.0, g.y - 1.0, 10.0, 7.0), lc)
		"affordable":
			var s: float = 4.0 + pulse * 1.5
			tile.draw_colored_polygon(PackedVector2Array([g + Vector2(0.0, -s), g + Vector2(s, 0.0), g + Vector2(0.0, s), g + Vector2(-s, 0.0)]), UITheme.with_alpha(col, 0.6 + 0.4 * pulse))
		"adopted":
			var ramp: float = GameState.node_ramp(id)
			if ramp >= 0.999:
				tile.draw_polyline(PackedVector2Array([g + Vector2(-5.0, 0.0), g + Vector2(-1.5, 3.5), g + Vector2(5.0, -4.0)]), UITheme.HEALTHY, 2.2, true)
			else:
				tile.draw_arc(g, 5.0, 0.0, TAU, 18, UITheme.with_alpha(col, 0.25), 2.0, true)
				tile.draw_arc(g, 5.0, -PI * 0.5, -PI * 0.5 + TAU * ramp, 18, UITheme.HEALTHY, 2.0, true)
			var bar_w: float = w - 24.0
			tile.draw_rect(Rect2(12.0, h - 6.0, bar_w, 2.0), UITheme.with_alpha(UITheme.DEEP, 0.9))
			tile.draw_rect(Rect2(12.0, h - 6.0, bar_w * clampf(ramp, 0.0, 1.0), 2.0), UITheme.with_alpha(UITheme.HEALTHY, 0.9))

	# Cures an active resistance: pulsing red marker, top-left.
	if st != "adopted" and not _active.is_empty():
		var def: Dictionary = TechTree.node_def(id)
		var counters: Array = def.get("counters", [])
		for e in counters:
			if _active.has(str(e)):
				var m := Vector2(18.0, 18.0)
				tile.draw_circle(m, 6.0 + pulse * 2.0, UITheme.with_alpha(UITheme.CRISIS, 0.18))
				tile.draw_circle(m, 3.2, UITheme.CRISIS)
				break

	if sel:
		UITheme.draw_brackets(tile, Rect2(-5.0, -5.0, w + 10.0, h + 10.0), col.lerp(Color.WHITE, 0.35), 12.0, 2.0)

	var b: float = float(_burst.get(id, 0.0))
	if b > 0.0:
		var grow: float = 1.0 + (1.0 - b) * 0.45
		var c := Vector2(w, h) * 0.5
		var ring := PackedVector2Array()
		for p in loop:
			var pp: Vector2 = p
			ring.append(c + (pp - c) * grow)
		tile.draw_polyline(ring, UITheme.with_alpha(UITheme.HEALTHY, b * 0.9), 2.5, true)
		tile.draw_colored_polygon(pts, UITheme.with_alpha(Color.WHITE, b * 0.28))


func _draw_details_frame() -> void:
	var id: String = _shown_id()
	var col: Color = _node_color(id) if id != "" else UITheme.TEXT_DIM
	var r := Rect2(Vector2.ZERO, _details.size)
	_details_style.border_color = UITheme.with_alpha(col, 0.35)
	_details.draw_style_box(_details_style, r)
	_details.draw_rect(Rect2(10.0, 0.0, 120.0, 2.0), UITheme.with_alpha(col, 0.9))
	var sy: float = r.size.y - ADOPT_AREA_H - 8.0
	_details.draw_line(Vector2(18.0, sy), Vector2(r.size.x - 18.0, sy), UITheme.with_alpha(col, 0.22), 1.0)
	if _adopt_flash > 0.0:
		_details.draw_rect(r, UITheme.with_alpha(UITheme.HEALTHY, 0.1 * _adopt_flash))
		_details.draw_rect(r, UITheme.with_alpha(UITheme.HEALTHY, 0.7 * _adopt_flash), false, 2.0)


func _draw_detail_frame_icon() -> void:
	var id: String = _shown_id()
	var st: String = _state_of(id)
	var col: Color = _node_color(id) if id != "" else UITheme.TEXT_DIM
	var s: Vector2 = _d_frame.size
	var pts: PackedVector2Array = _chamfer_pts(Rect2(Vector2.ZERO, s), 12.0)
	var fill: Color = UITheme.with_alpha(UITheme.DEEP, 0.9)
	if st == "adopted":
		fill = UITheme.with_alpha(UITheme.BG_PANEL.lerp(col, 0.22), 0.95)
	elif st == "affordable":
		fill = UITheme.with_alpha(UITheme.BG_PANEL.lerp(col, 0.1), 0.95)
	_d_frame.draw_colored_polygon(pts, fill)
	var border_a: float = 0.35 if st == "locked" else 0.85
	_d_frame.draw_polyline(_closed(pts), UITheme.with_alpha(col, border_a), 1.5, true)
	var c: Vector2 = s * 0.5
	var rad: float = s.x * 0.5 - 4.0
	var rot: float = _time * 0.5
	for i in 8:
		var a0: float = rot + TAU * float(i) / 8.0
		_d_frame.draw_arc(c, rad, a0, a0 + TAU / 8.0 * 0.45, 6, UITheme.with_alpha(col, 0.22 if st == "locked" else 0.4), 1.2, true)


func _draw_strip() -> void:
	var r := Rect2(Vector2.ZERO, _strip.size)
	_strip.draw_style_box(_strip_style, r)
	_strip.draw_line(Vector2(STRIP_LEFT_W, 12.0), Vector2(STRIP_LEFT_W, r.size.y - 12.0), UITheme.with_alpha(UITheme.TEXT_DIM, 0.22), 1.0)
	_strip.draw_rect(Rect2(10.0, 0.0, 120.0, 2.0), UITheme.with_alpha(UITheme.WARNING, 0.85))
	if not _active.is_empty():
		var pulse: float = 0.5 + 0.5 * sin(_time * 3.0)
		_strip.draw_rect(Rect2(STRIP_LEFT_W + 1.0, 0.0, r.size.x - STRIP_LEFT_W - 11.0, 2.0), UITheme.with_alpha(UITheme.CRISIS, 0.45 + 0.4 * pulse))


func _draw_evo_bar(branch: String) -> void:
	var bar: Control = _evo_bars[branch]
	var w: float = bar.size.x
	var h: float = bar.size.y
	if w < 4.0:
		return
	var col: Color = _branch_color(branch)
	var thr: float = clampf(float(_pressure.get("threshold", 1.0)), 0.05, 1.0)
	var share: float = clampf(float(_evo_shown.get(branch, 0.0)), 0.0, 1.0)
	var warm: bool = int(_pressure.get("moves", 0)) >= int(_pressure.get("min_moves", 0))
	var resist: bool = _branch_resistant(branch)
	var fill_col: Color = col
	if resist or share >= thr:
		fill_col = UITheme.CRISIS
	elif share >= thr * 0.75:
		fill_col = UITheme.WARNING
	var a: float = 1.0 if warm else 0.5
	bar.draw_rect(Rect2(0.0, 0.0, w, h), UITheme.with_alpha(UITheme.DEEP, 0.9))
	var segs: int = 26
	var sw: float = w / float(segs)
	for i in segs:
		var on: bool = (float(i) + 0.5) / float(segs) <= share
		var c: Color = UITheme.with_alpha(fill_col, 0.95 * a) if on else UITheme.with_alpha(col, 0.08)
		bar.draw_rect(Rect2(float(i) * sw + 1.0, 2.0, sw - 2.0, h - 4.0), c)
	bar.draw_rect(Rect2(0.0, 0.0, w, h), UITheme.LINE_DIM, false, 1.0)
	if resist:
		var x: float = 0.0
		while x + h <= w:
			bar.draw_line(Vector2(x, h), Vector2(x + h, 0.0), UITheme.with_alpha(UITheme.CRISIS, 0.35), 1.0)
			x += 7.0
	var tx: float = clampf(thr * w, 1.0, w - 1.0)
	bar.draw_line(Vector2(tx, -4.0), Vector2(tx, h + 4.0), UITheme.with_alpha(UITheme.CRISIS, 0.9), 2.0)
	bar.draw_colored_polygon(PackedVector2Array([Vector2(tx - 4.0, -7.0), Vector2(tx + 4.0, -7.0), Vector2(tx, -2.0)]), UITheme.CRISIS)
