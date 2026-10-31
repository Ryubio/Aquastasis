extends Node
## QA (temporary): validates region polygons (simple, non-overlapping, triangulable) and
## reports which polygon edges are hidden under the land layer.

const RegionData := preload("res://scripts/region.gd")
const MapBuilder := preload("res://scripts/map_builder.gd")


func _area(poly: PackedVector2Array) -> float:
	var a: float = 0.0
	for i in poly.size():
		var p: Vector2 = poly[i]
		var q: Vector2 = poly[(i + 1) % poly.size()]
		a += p.x * q.y - q.x * p.y
	return absf(a) * 0.5


func _on_land(p: Vector2) -> bool:
	for l in MapBuilder.LAND:
		var lp := PackedVector2Array()
		for v in l:
			lp.append(v)
		if Geometry2D.is_point_in_polygon(p, lp):
			return true
	return false


func _ready() -> void:
	for rid in RegionData.IDS:
		var id: String = rid
		var poly: PackedVector2Array = RegionData.polygon_of(id)
		var n: int = poly.size()
		var crossings: int = 0
		for i in n:
			for j in range(i + 2, n):
				if i == 0 and j == n - 1:
					continue
				var hit: Variant = Geometry2D.segment_intersects_segment(poly[i], poly[(i + 1) % n], poly[j], poly[(j + 1) % n])
				if hit != null:
					crossings += 1
					print("  SELF-CROSS ", id, " edge ", i, " x edge ", j)
		var tri: PackedInt32Array = Geometry2D.triangulate_polygon(poly)
		print("POLY ", id, " pts=", n, " area=%.2f" % _area(poly), " crossings=", crossings, " tris=", tri.size() / 3)
	for i in RegionData.IDS.size():
		for j in range(i + 1, RegionData.IDS.size()):
			var a: String = RegionData.IDS[i]
			var b: String = RegionData.IDS[j]
			var inter: Array = Geometry2D.intersect_polygons(RegionData.polygon_of(a), RegionData.polygon_of(b))
			if not inter.is_empty():
				var tot: float = 0.0
				for p in inter:
					tot += _area(p)
				print("  OVERLAP ", a, " x ", b, " area=%.3f" % tot)
	# Which blacksea / marmara edge samples are open water (not under land)?
	for id in ["blacksea", "marmara"]:
		var poly: PackedVector2Array = RegionData.polygon_of(id)
		var open: Array = []
		for i in poly.size():
			var a: Vector2 = poly[i]
			var b: Vector2 = poly[(i + 1) % poly.size()]
			for k in 10:
				var p: Vector2 = a.lerp(b, (float(k) + 0.5) / 10.0)
				if not _on_land(p):
					open.append(i)
					break
		print("EDGES NOT FULLY UNDER LAND ", id, ": ", open)
	# Eastern basin probe: water points that no region covers.
	var holes: int = 0
	var total: int = 0
	var y: float = -9.0
	while y <= -2.0:
		var x: float = 19.0
		while x <= 28.0:
			var p := Vector2(x, y)
			if not _on_land(p):
				total += 1
				if RegionData.region_at(p) == "":
					holes += 1
			x += 0.1
		y += 0.1
	print("EAST BASIN water samples=", total, " uncovered=", holes)
	get_tree().quit()
