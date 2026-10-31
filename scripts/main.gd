extends Node
## Main: composition root. Builds the 3D map, bubble FX, HUD, policy tree, event card and
## menus in code, routes the game flow (menu -> playing -> pause -> game over) and owns the
## global hotkeys. Optional user args after "--": --autostart  --speed=<0..3>
## --select=<region_id>  --tree (open the policy tree)  --event=<event_id> (force a card)

const MapBuilder := preload("res://scripts/map_builder.gd")
const UIHud := preload("res://scripts/ui_hud.gd")
const UIMenu := preload("res://scripts/ui_menu.gd")
const UITree := preload("res://scripts/ui_tree.gd")
const UIEventCard := preload("res://scripts/ui_event_card.gd")
const FX := preload("res://scripts/fx.gd")

## Q / W / E trigger the field operations on the selected region (Balance.ACTION_ORDER).
const ACTION_KEYS := {KEY_Q: 0, KEY_W: 1, KEY_E: 2}

var map: MapBuilder
var fx: FX
var hud: UIHud
var tree_ui: UITree
var event_card: UIEventCard
var menu: UIMenu


func _ready() -> void:
	map = MapBuilder.new()
	map.name = "Map"
	add_child(map)

	fx = FX.new()
	fx.name = "FX"
	fx.map = map
	_add_layer("FXLayer", 1).add_child(fx)

	hud = UIHud.new()
	hud.name = "HUD"
	_add_layer("HUDLayer", 2).add_child(hud)

	tree_ui = UITree.new()
	tree_ui.name = "PolicyTree"
	_add_layer("TreeLayer", 3).add_child(tree_ui)

	event_card = UIEventCard.new()
	event_card.name = "EventCard"
	_add_layer("EventLayer", 4).add_child(event_card)

	menu = UIMenu.new()
	menu.name = "Menu"
	_add_layer("MenuLayer", 5).add_child(menu)

	menu.start_requested.connect(_start_game)
	menu.resume_requested.connect(_resume)
	menu.restart_requested.connect(_start_game)
	menu.main_menu_requested.connect(_to_main_menu)
	menu.quit_requested.connect(_quit)
	EventBus.game_over.connect(_on_game_over)
	EventBus.tree_toggle_requested.connect(_toggle_tree)
	EventBus.event_triggered.connect(_on_event_triggered)

	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--autostart"):
		_start_game()
		for arg in args:
			if arg.begins_with("--speed="):
				GameState.set_speed(clampi(arg.trim_prefix("--speed=").to_int(), 0, 3))
			elif arg.begins_with("--select="):
				EventBus.region_selected.emit(arg.trim_prefix("--select="))
			elif arg.begins_with("--event="):
				GameState.debug_force_event(arg.trim_prefix("--event="))
		if args.has("--tree"):
			tree_ui.open()
	else:
		_to_main_menu()


func _add_layer(layer_name: String, index: int) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.name = layer_name
	layer.layer = index
	add_child(layer)
	return layer


func _start_game() -> void:
	_close_modals()
	_clear_selection()
	menu.hide_all()
	map.set_menu_mode(false)
	hud.show_hud()
	GameState.new_game()
	GameState.set_speed(1)


func _to_main_menu() -> void:
	_close_modals()
	GameState.stop_game()
	_clear_selection()
	hud.hide_hud()
	map.set_menu_mode(true)
	menu.show_main()


## Tree, event card and bubbles never survive a game boundary.
func _close_modals() -> void:
	tree_ui.close()
	event_card.close_now()
	fx.clear_all()


## Drops a region selection left over from the last game (map, HUD and GameState all
## follow region_selected), so menus and the next game start with nothing selected.
func _clear_selection() -> void:
	if GameState.selected_region != "":
		EventBus.region_selected.emit("")


func _open_pause() -> void:
	GameState.set_menu_paused(true)
	menu.show_pause()


func _resume() -> void:
	menu.hide_all()
	GameState.set_menu_paused(false)


func _quit() -> void:
	get_tree().quit()


func _on_game_over(won: bool, reason: String, stats: Dictionary) -> void:
	_close_modals()
	_clear_selection()
	hud.hide_hud()
	map.set_menu_mode(true)
	menu.show_end(won, reason, stats)


func _toggle_tree() -> void:
	if GameState.running and not menu.is_open() and not event_card.is_open():
		tree_ui.toggle()


func _on_event_triggered(_event_id: String) -> void:
	if tree_ui.is_open():
		tree_ui.close()


## True while nothing modal covers the game (menus, event card, policy tree).
func _gameplay_input() -> bool:
	return GameState.running and not menu.is_open() and not event_card.is_open() and not tree_ui.is_open()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var code: int = key.keycode if key.keycode != 0 else key.physical_keycode
	match code:
		KEY_ESCAPE:
			if not GameState.running or event_card.is_open():
				return
			if tree_ui.is_open():
				tree_ui.close()
			elif menu.is_pause_open():
				_resume()
			elif not menu.is_open():
				_open_pause()
		KEY_T:
			_toggle_tree()
		KEY_H:
			if _gameplay_input():
				EventBus.tutorial_requested.emit()
		KEY_SPACE:
			if _gameplay_input():
				GameState.toggle_pause()
		KEY_1, KEY_KP_1:
			if _gameplay_input():
				GameState.set_speed(1)
		KEY_2, KEY_KP_2:
			if _gameplay_input():
				GameState.set_speed(2)
		KEY_3, KEY_KP_3, KEY_4, KEY_KP_4:
			if _gameplay_input():
				GameState.set_speed(3)
		KEY_Q, KEY_W, KEY_E:
			if _gameplay_input() and GameState.selected_region != "":
				var action_id: String = Balance.ACTION_ORDER[int(ACTION_KEYS[code])]
				GameState.perform_action(action_id, GameState.selected_region)
		_:
			return
	get_viewport().set_input_as_handled()
