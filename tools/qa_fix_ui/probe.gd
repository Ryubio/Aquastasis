extends Node
## Temporary QA harness for the ui fixer (deleted after verification). Runs main.tscn and
## probes the HUD/menu fixes. Modes (user arg): --qa=layout (headless numbers),
## --qa=render (GPU captures into shots/fix_ui/), --qa=intro (title intro frame times).

const RegionData := preload("res://scripts/region.gd")
const OUT := "res://shots/fix_ui/"

var main: Node
var mode: String = "layout"
var lang0: String = "en"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var s: String = a
		if s.begins_with("--qa="):
			mode = s.trim_prefix("--qa=")
		elif s.begins_with("--lang="):
			lang0 = s.trim_prefix("--lang=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	if mode == "intro":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		_set_lang(lang0)
	main = load("res://main.tscn").instantiate()
	add_child(main)
	await _frames(4)
	match mode:
		"layout":
			await _layout()
		"render":
			await _render()
		"intro":
			await _intro()
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _set_lang(code: String) -> void:
	I18n.lang = code
	EventBus.language_changed.emit(code)


func _rect(c: Control) -> Rect2:
	return Rect2(c.global_position, c.size)


func _speed_state(hud: Node) -> String:
	var xs: Array = []
	for b in hud._speed_buttons:
		var btn: Control = b
		xs.append(int(btn.global_position.x))
	return "speed_x=%s timeline_w=%d chip_w=%d chip_a=%.2f" % [str(xs), int(hud._timeline.size.x), int(hud._paused_chip.size.x), hud._paused_chip.modulate.a]


func _region_hits(r: Rect2) -> Array:
	var hits: Array = []
	var map: Node = main.map
	for id in RegionData.IDS:
		var rid: String = id
		var poly: PackedVector2Array = RegionData.polygon_of(rid)
		var screen := PackedVector2Array()
		for p in poly:
			var v: Vector2 = p
			screen.append(map.camera.unproject_position(Vector3(v.x, 0.0, v.y)))
		var hit: bool = false
		for sp in screen:
			if r.has_point(sp):
				hit = true
		for corner in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.get_center()]:
			if Geometry2D.is_point_in_polygon(corner, screen):
				hit = true
		if hit:
			hits.append(rid)
	return hits


func _layout() -> void:
	var hud: Node = main.hud
	var menu: Node = main.menu
	await _wait(1.2)
	# 1) Pause chip: speed buttons must not move between running and paused.
	for code in ["en", "tr", "ru"]:
		_set_lang(code)
		GameState.set_speed(1)
		await _frames(6)
		var run_s: String = _speed_state(hud)
		GameState.set_speed(0)
		await _frames(6)
		var pause_s: String = _speed_state(hud)
		GameState.set_speed(1)
		await _frames(6)
		print("QA_FIX pause %s running: %s" % [code, run_s])
		print("QA_FIX pause %s paused : %s" % [code, pause_s])
		print("QA_FIX pause %s same_x=%s" % [code, str(run_s.get_slice(" ", 0) == pause_s.get_slice(" ", 0))])

	# 2) Action tooltip placement and hide on press.
	EventBus.region_selected.emit("antalya")
	await _frames(6)
	for code in ["en", "tr", "ru"]:
		_set_lang(code)
		await _frames(6)
		for r in hud._action_rows:
			var row: Dictionary = r
			var btn: Button = row["button"]
			var id: String = row["id"]
			hud._on_action_hover(btn, id)
			await _frames(3)
			var tr: Rect2 = _rect(hud._tip_panel)
			var pr: Rect2 = _rect(hud._right_panel)
			var br: Rect2 = _rect(btn)
			print("QA_FIX tip %s %s tip=%s panel=%s covers_panel=%s covers_btn=%s regions_hit=%s" % [code, id, str(tr), str(pr), str(tr.intersects(pr)), str(tr.intersects(br)), str(_region_hits(tr))])
			btn.pressed.emit()
			await _frames(2)
			print("QA_FIX tip %s %s after_press visible=%s" % [code, id, str(hud._tip_panel.visible)])
			hud._hide_tip(btn)

	# 3) Cooldown seconds at 4x.
	_set_lang("en")
	GameState.set_speed(3)
	await _frames(3)
	var ok: bool = GameState.perform_action("patrol", "antalya")
	var t0: int = Time.get_ticks_msec()
	await _frames(1)
	var st: Label = null
	for r in hud._action_rows:
		var row: Dictionary = r
		if str(row["id"]) == "patrol":
			st = row["status"]
	print("QA_FIX cd 4x performed=%s t=0.00 '%s'" % [str(ok), st.text])
	var last: String = st.text
	while Time.get_ticks_msec() - t0 < 6000:
		await _frames(1)
		if st.text != last:
			last = st.text
			print("QA_FIX cd 4x t=%.2f '%s'" % [float(Time.get_ticks_msec() - t0) / 1000.0, last])
		if last == I18n.t("hud.action.ready") or last == I18n.t("hud.action.no_funds"):
			break
	GameState.set_speed(1)

	# 4) Percent format follows the language (tr: %60).
	for code in ["tr", "en", "ru", "tr"]:
		_set_lang(code)
		await _frames(3)
		var stat_l: Label = hud._stat_bars["pollution"].value_label
		print("QA_FIX pct %s sea=%s crisis=%s pollution=%s coastal=%s" % [code, hud._sea_bar.value_label.text, hud._crisis_bar.value_label.text, stat_l.text, hud._coastal_value.text])

	# 5) End screen: values and layout stability.
	GameState.set_speed(0)
	var base: Dictionary = GameState.get_snapshot()
	var cases: Array = [[false, "lose_health", 9.97], [false, "lose_time", 59.7], [true, "win_health", 60.4], [false, "lose_temperature", 33.5]]
	for code in ["en", "tr", "ru"]:
		_set_lang(code)
		for cs in cases:
			var c: Array = cs
			var stats: Dictionary = base.duplicate()
			stats["sea_health"] = float(c[2])
			stats["reason"] = str(c[1])
			stats["year_int"] = 2046 if str(c[1]) != "lose_health" else 2043
			GameState.stop_game()
			main._on_game_over(bool(c[0]), str(c[1]), stats)
			var ys: Array = []
			for f in 75:
				await get_tree().process_frame
				ys.append(int(menu._end_panel.global_position.y))
			await _wait(1.6)
			var lbl0: Label = menu._end_stat_labels[0]
			var distinct: Dictionary = {}
			for i in range(3, ys.size()):
				distinct[ys[i]] = true
			print("QA_FIX end %s %s sh=%.2f text='%s' stat0='%s' panel_y_after_f3=%s" % [code, str(c[1]), float(c[2]), menu._end_text.text, lbl0.text, str(distinct.keys())])
	main._start_game()
	await _frames(4)


func _shot(name_: String, region: Rect2i = Rect2i()) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	if region.size.x > 0:
		var sx: float = float(img.get_width()) / 1920.0
		var rr := Rect2i(int(region.position.x * sx), int(region.position.y * sx), int(region.size.x * sx), int(region.size.y * sx))
		img = img.get_region(rr)
	img.save_png(OUT + name_ + ".png")
	print("QA_FIX shot ", name_, " ", img.get_size())


func _stack(a: Image, b: Image) -> Image:
	var out := Image.create(a.get_width(), a.get_height() + b.get_height() + 4, false, a.get_format())
	out.fill(Color(0, 1, 1))
	out.blit_rect(a, Rect2i(Vector2i.ZERO, a.get_size()), Vector2i.ZERO)
	out.blit_rect(b, Rect2i(Vector2i.ZERO, b.get_size()), Vector2i(0, a.get_height() + 4))
	return out


func _grab(region: Rect2i) -> Image:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var sx: float = float(img.get_width()) / 1920.0
	var rr := Rect2i(int(region.position.x * sx), int(region.position.y * sx), int(region.size.x * sx), int(region.size.y * sx))
	return img.get_region(rr)


func _render() -> void:
	var hud: Node = main.hud
	var menu: Node = main.menu
	print("QA_FIX viewport ", get_viewport().get_visible_rect().size, " tex ", get_viewport().get_texture().get_size())
	# Title intro: mid and final (RU), final EN/TR.
	_set_lang("ru")
	main._to_main_menu()
	await _wait(0.45)
	var mid: Image = await _grab(Rect2i(100, 300, 1100, 260))
	await _wait(2.4)
	var fin: Image = await _grab(Rect2i(100, 300, 1100, 260))
	_stack(mid, fin).save_png(OUT + "title_ru_mid_vs_final.png")
	_set_lang("tr")
	await _wait(1.2)
	var tr_img: Image = await _grab(Rect2i(100, 300, 1100, 260))
	_set_lang("en")
	await _wait(1.2)
	var en_img: Image = await _grab(Rect2i(100, 300, 1100, 260))
	_stack(tr_img, en_img).save_png(OUT + "title_tr_en_final.png")

	# HUD: TR top bar running vs paused + gauge.
	_set_lang("tr")
	main._start_game()
	EventBus.region_selected.emit("antalya")
	await _wait(3.0)
	GameState.set_speed(1)
	await _wait(0.3)
	var run_img: Image = await _grab(Rect2i(560, 32, 1360, 62))
	GameState.set_speed(0)
	await _wait(0.4)
	var pause_img: Image = await _grab(Rect2i(560, 32, 1360, 62))
	_stack(run_img, pause_img).save_png(OUT + "topbar_tr_run_vs_pause.png")
	await _shot("left_panel_tr", Rect2i(0, 100, 380, 640))
	# Tooltip under the region panel (RU, tallest panel), hovering Marine Patrol.
	_set_lang("ru")
	await _wait(0.5)
	for r in hud._action_rows:
		var row: Dictionary = r
		if str(row["id"]) == "patrol":
			hud._on_action_hover(row["button"], "patrol")
	await _wait(0.4)
	await _shot("tip_ru_full")
	# End screen RU (lose_temperature) mid-reveal and final.
	var stats: Dictionary = GameState.get_snapshot()
	stats["sea_health"] = 9.97
	GameState.stop_game()
	main._on_game_over(false, "lose_health", stats)
	await _wait(1.3)
	var e_mid: Image = await _grab(Rect2i(500, 180, 920, 720))
	await _wait(1.8)
	var e_fin: Image = await _grab(Rect2i(500, 180, 920, 720))
	_stack(e_mid, e_fin).save_png(OUT + "end_ru_mid_vs_final.png")


func _intro() -> void:
	# Main menu shows on boot (no --autostart): time frames during the 2.2 s title intro.
	var t0: int = Time.get_ticks_usec()
	var last: int = t0
	var slow: int = 0
	var worst: float = 0.0
	var count: int = 0
	while Time.get_ticks_usec() - t0 < 2400000:
		await get_tree().process_frame
		var now: int = Time.get_ticks_usec()
		var dt: float = float(now - last) / 1000.0
		last = now
		if now - t0 > 200000:
			count += 1
			if dt > 16.7:
				slow += 1
			worst = maxf(worst, dt)
	print("QA_FIX intro %s frames=%d over16.7ms=%d worst=%.1fms" % [lang0, count, slow, worst])
