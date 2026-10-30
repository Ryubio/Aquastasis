extends Node
## Dev tool: compiles game scripts with autoloads available and reports failures.
## Run: godot --headless --path . res://tools/check.tscn -- [res://scripts/x.gd ...]
## With no paths it checks every .gd under res://scripts. Exit code = failure count.


func _ready() -> void:
	var paths: Array = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("res://"):
			paths.append(arg)
	if paths.is_empty():
		paths = _all_scripts("res://scripts")
	var failed: int = 0
	for p in paths:
		var path: String = p
		var script := load(path) as GDScript
		if script == null or not script.can_instantiate():
			failed += 1
			print("CHECK FAIL: ", path)
		else:
			print("CHECK OK:   ", path)
	print("CHECK DONE: %d failed of %d" % [failed, paths.size()])
	get_tree().quit(failed)


func _all_scripts(dir_path: String) -> Array:
	var out: Array = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for f in dir.get_files():
		var file_name: String = f
		if file_name.ends_with(".gd"):
			out.append(dir_path.path_join(file_name))
	for d in dir.get_directories():
		out.append_array(_all_scripts(dir_path.path_join(d)))
	return out
