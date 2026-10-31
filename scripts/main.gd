extends Node
## Main: composition root. Builds the 3D map, HUD and menus in code, routes the game flow
## (main menu -> playing -> pause -> game over) and owns the global hotkeys.
## Optional user args after "--": --autostart  --speed=<0..3>  --select=<region_id>

const MapBuilder := preload("res://scripts/map_builder.gd")
const UIHud := preload("res://scripts/ui_hud.gd")
const UIMenu := preload("res://scripts/ui_menu.gd")

var map: MapBuilder
var hud: UIHud
var menu: UIMenu


func _ready() -> void:
	map = MapBuilder.new()
	map.name = "Map"
	add_child(map)

	var hud_layer := CanvasLayer.new()
	hud_layer.name = "HUDLayer"
	hud_layer.layer = 1
	add_child(hud_layer)
	hud = UIHud.new()
	hud.name = "HUD"
	hud_layer.add_child(hud)

	var menu_layer := CanvasLayer.new()
	menu_layer.name = "MenuLayer"
	menu_layer.layer = 5
	add_child(menu_layer)
	menu = UIMenu.new()
	menu.name = "Menu"
	menu_layer.add_child(menu)

	menu.start_requested.connect(_start_game)
	menu.resume_requested.connect(_resume)
	menu.restart_requested.connect(_start_game)
	menu.main_menu_requested.connect(_to_main_menu)
	menu.quit_requested.connect(_quit)
	EventBus.game_over.connect(_on_game_over)

	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--autostart"):
		_start_game()
		for arg in args:
			if arg.begins_with("--speed="):
				GameState.set_speed(clampi(arg.trim_prefix("--speed=").to_int(), 0, 3))
			elif arg.begins_with("--select="):
				EventBus.region_selected.emit(arg.trim_prefix("--select="))
	else:
		_to_main_menu()


func _start_game() -> void:
	_clear_selection()
	menu.hide_all()
	map.set_menu_mode(false)
	hud.show_hud()
	GameState.new_game()
	GameState.set_speed(1)


func _to_main_menu() -> void:
	GameState.stop_game()
	_clear_selection()
	hud.hide_hud()
	map.set_menu_mode(true)
	menu.show_main()


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
	_clear_selection()
	hud.hide_hud()
	map.set_menu_mode(true)
	menu.show_end(won, reason, stats)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_ESCAPE:
			if not GameState.running:
				return
			if menu.is_pause_open():
				_resume()
			elif not menu.is_open():
				_open_pause()
		KEY_SPACE:
			if GameState.running and not menu.is_open():
				GameState.toggle_pause()
		KEY_1:
			if GameState.running and not menu.is_open():
				GameState.set_speed(1)
		KEY_2:
			if GameState.running and not menu.is_open():
				GameState.set_speed(2)
		KEY_3:
			if GameState.running and not menu.is_open():
				GameState.set_speed(3)
		_:
			return
	get_viewport().set_input_as_handled()
