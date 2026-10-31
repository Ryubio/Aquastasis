extends Node
## Dev tool: runs the real game (main.tscn) and saves single screenshots at given frames,
## instead of --write-movie dumping every frame. main.gd still reads its own user args.
## Run: godot --path . --fixed-fps 30 res://tools/shot.tscn -- --autostart --shot=120:shots/a.png --shot=300:shots/b.png

var _shots: Array = []   # [[frame: int, path: String], ...] sorted by frame
var _frame: int = 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			var spec: String = arg.trim_prefix("--shot=")
			var sep: int = spec.find(":")
			if sep > 0:
				_shots.append([spec.substr(0, sep).to_int(), spec.substr(sep + 1)])
	_shots.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
	add_child(load("res://main.tscn").instantiate())


func _process(_delta: float) -> void:
	_frame += 1
	while not _shots.is_empty() and _frame >= int(_shots[0][0]):
		var shot: Array = _shots.pop_front()
		var path: String = ProjectSettings.globalize_path("res://" + str(shot[1]))
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png(path)
		print("SHOT ", _frame, " -> ", path)
	if _shots.is_empty():
		get_tree().quit()
