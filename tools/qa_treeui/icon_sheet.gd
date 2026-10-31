extends SceneTree
## Temporary QA harness (tree UI module): renders every icon id at 64 and 28 px into a PNG.
## Run: godot --path . -s res://tools/qa_treeui/icon_sheet.gd -- shots/treeui/icons.png [first_id_index]

const Icons := preload("res://scripts/icons.gd")
const UITheme := preload("res://scripts/ui_theme.gd")

var _frames: int = 0
var _out: String = "shots/treeui/icons.png"


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	var start: int = 0
	if args.size() > 1:
		start = args[1].to_int()
	root.size = Vector2i(1920, 1080)
	var bg := ColorRect.new()
	bg.color = UITheme.BG_PANEL
	bg.size = Vector2(1920, 1080)
	root.add_child(bg)
	var cols: int = 12
	var cell := Vector2(158, 128)
	var colors: Array = [UITheme.HEALTHY, UITheme.AMBER, Color(0.42, 0.78, 1.0), UITheme.TERRACOTTA.lightened(0.15), UITheme.CRISIS]
	var ids: Array = Icons.IDS.slice(start)
	ids.append("unknown_id_fallback")
	for i in ids.size():
		var id: String = ids[i]
		var cx: int = i % cols
		var cy: int = i / cols
		var origin := Vector2(10 + cx * cell.x, 10 + cy * cell.y)
		if origin.y > 1000:
			break
		var col: Color = colors[i % colors.size()]
		var big: Icons = Icons.new()
		big.setup(id, col, 64.0)
		big.size = Vector2(64, 64)
		big.position = origin
		root.add_child(big)
		var small: Icons = Icons.new()
		small.setup(id, col, 28.0)
		small.size = Vector2(28, 28)
		small.position = origin + Vector2(76, 18)
		root.add_child(small)
		var tiny: Icons = Icons.new()
		tiny.setup(id, col, 18.0)
		tiny.size = Vector2(18, 18)
		tiny.position = origin + Vector2(116, 23)
		root.add_child(tiny)
		var l := Label.new()
		l.text = id
		l.position = origin + Vector2(0, 70)
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", UITheme.TEXT_DIM)
		root.add_child(l)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames == 4:
		var img: Image = root.get_texture().get_image()
		var path: String = ProjectSettings.globalize_path("res://" + _out)
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		img.save_png(path)
		print("ICON SHEET -> ", path)
		quit()
