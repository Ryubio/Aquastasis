extends Node3D
## MapBuilder: STUB with the frozen public API (see docs/ARCHITECTURE.md "MapBuilder").
## The map module replaces this with the procedural 3D Mediterranean, sea shader,
## routes, hero marker, camera drift and polygon picking. Keep every public signature.

var camera: Camera3D


func _ready() -> void:
	camera = Camera3D.new()
	camera.position = Vector3(1.0, 26.0, 20.0)
	camera.rotation_degrees = Vector3(-55.0, 0.0, 0.0)
	camera.fov = 45.0
	add_child(camera)
	camera.make_current()


## true: cinematic idle camera, picking disabled (main menu / end screen).
func set_menu_mode(_on: bool) -> void:
	pass


## Camera shake impulse, strength 0..1.
func shake(_strength: float) -> void:
	pass


## Screen position of a region's anchor (for Phase 2 bubbles).
func unproject_region(region_id: String) -> Vector2:
	if camera == null:
		return Vector2.ZERO
	var RegionData := preload("res://scripts/region.gd")
	var a: Vector2 = RegionData.anchor_of(region_id)
	return camera.unproject_position(Vector3(a.x, 0.0, a.y))
