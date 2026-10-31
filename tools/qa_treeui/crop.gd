extends SceneTree
## Temporary QA helper (tree UI module): crops and upscales a region of a screenshot.
## Args after --: <in.png> <out.png> <x> <y> <w> <h> <scale>

func _init() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://" + a[0]))
	var r := Rect2i(a[2].to_int(), a[3].to_int(), a[4].to_int(), a[5].to_int())
	var c: Image = img.get_region(r)
	var s: int = a[6].to_int()
	c.resize(r.size.x * s, r.size.y * s, Image.INTERPOLATE_NEAREST)
	c.save_png(ProjectSettings.globalize_path("res://" + a[1]))
	quit()
