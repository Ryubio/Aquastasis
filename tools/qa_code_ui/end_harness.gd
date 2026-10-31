extends Node
## QA harness (code_ui): drives main.gd to the end screen and dumps font/label diagnostics.

const MainScript := preload("res://scripts/main.gd")
const UITheme := preload("res://scripts/ui_theme.gd")

var main_node: Node
var frame: int = 0
var langs: Array = ["en", "ru", "tr"]
var step: int = 0

func _ready() -> void:
	main_node = MainScript.new()
	add_child(main_node)

func _stats() -> Dictionary:
	return {"sea_health": 31.0, "temperature": 2.84, "year_int": 2039, "actions_used": 27, "reason": "lose_resources"}

func _process(_d: float) -> void:
	frame += 1
	if frame == 10 or frame == 80 or frame == 150:
		var lg: String = langs[step]
		step += 1
		I18n.lang = lg
		EventBus.language_changed.emit(lg)
		main_node.call("_on_game_over", false, "lose_resources", _stats())
	if frame == 22 or frame == 92 or frame == 162 or frame == 70 or frame == 140 or frame == 210:
		_dump()

func _dump() -> void:
	var menu: Control = main_node.get("menu")
	var lbl: Label = menu.get("_end_title")
	var f: Font = lbl.get_theme_font("font")
	var fs: int = lbl.get_theme_font_size("font_size")
	var sf := UITheme.mono_bold_font() as SystemFont
	print("DUMP f=", frame, " lang=", I18n.lang, " text='", lbl.text, "' vis_ratio=", lbl.visible_ratio, " vis_chars=", lbl.visible_characters, " lines=", lbl.get_line_count(), " size=", lbl.size, " font=", f, " same_as_bold=", f == sf, " fs=", fs, " str_w=", f.get_string_size(lbl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, " panel=", (menu.get("_end_panel") as Control).size, " behavior=", lbl.visible_characters_behavior)
	print("  font_name=", f.get_font_name(), " style=", f.get_font_style_name(), " weight=", f.get_font_weight(), " fallbacks=", f.fallbacks.size())
