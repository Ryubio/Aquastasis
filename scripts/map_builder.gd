extends Node3D
## MapBuilder: builds the procedural 3D Mediterranean in code (deep-sea grid floor, raised land
## slabs with glowing coastlines, 8 extruded sea regions with the sea shader, route arcs, the
## Antalya hero beacon, labels), drives the camera (drift, parallax, shake) and polygon picking.

const RegionData := preload("res://scripts/region.gd")
const UITheme := preload("res://scripts/ui_theme.gd")
const SEA_SHADER := preload("res://shaders/sea.gdshader")
const ROUTE_SHADER := preload("res://shaders/route.gdshader")
const GRID_SHADER := preload("res://shaders/grid.gdshader")

# --- Layout (map plane: x = east, z = south; see region.gd) ------------------------------
const SEA_Y := 0.0
const LAND_Y := 0.16
const FLOOR_Y := -0.55
const WALL_BOTTOM_Y := -0.54
const TOP_STEP := 0.45            # interior grid spacing of the subdivided water surface
const RIM_WIDTH := 0.1
const RIM_LIFT := 0.015
const COAST_WIDTH := 0.075
const FAR_X := 38.0               # land outline points beyond these bounds are off-map closures:
const FAR_Y := 22.0               # edges touching them get no wall and no coastline glow
const HERO_POS := Vector2(16.72, 2.86)
const ROUTE_END_GAP := 1.1        # route arcs start this far from the anchors (labels sit there)
const BURST_TIME := 0.75          # seconds a spread comet needs to travel a route

# --- Motion ---------------------------------------------------------------------------------
const SMOOTH_RATE := 2.2          # 1/s, uniforms follow region_changed targets
const HOVER_RATE := 10.0
const SHAKE_TIME := 0.4
const SHAKE_UNITS := 0.55
const CAM_FOV := 42.0
const GAME_TARGET := Vector3(2.66, 0.0, 0.93)   # frames the basin between the HUD panels
const GAME_DIST := 55.9
const GAME_PITCH := 57.0
const MENU_TARGET := Vector3(2.4, 0.0, 1.9)     # wider cinematic framing, no panels
const MENU_DIST := 42.0
const MENU_PITCH := 50.0

# --- Labels ---------------------------------------------------------------------------------
const LABEL_PIXEL := 0.036
const NAME_FONT_SIZE := 22
const STATUS_FONT_SIZE := 15
const LABEL_LIFT := 0.35
const LABEL_PICK_PAD := 6.0       # font pixels of extra clickable margin around a label
## Label offset from the region anchor (map units): keeps "Antalya Gulf" off the hero ring.
const LABEL_OFFSET := {"antalya": Vector2(1.6, 0.2)}

## Render-only outline refinements: extra water merged into a region's mesh, outline and
## picking (the simulation never uses polygon area). The eastern Black Sea basin beyond the
## region's straight cut at x ~21 would otherwise show the bare sea floor between the coasts.
## Every new edge lies 0.1-0.2 units under the europe/asia land slabs.
const REGION_EXTENSIONS := {
	"blacksea": [
		Vector2(20.4, -3.75), Vector2(21.0, -3.55), Vector2(21.9, -3.4), Vector2(22.35, -2.85),
		Vector2(23.5, -2.6), Vector2(24.4, -2.42), Vector2(25.7, -2.47), Vector2(26.5, -2.5),
		Vector2(27.85, -3.35), Vector2(27.7, -4.5), Vector2(26.6, -5.45), Vector2(25.1, -6.75),
		Vector2(23.6, -7.55), Vector2(22.6, -8.45), Vector2(21.45, -8.25), Vector2(20.5, -7.5),
	],
}

const BEACON_SHADER_CODE := """
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;
uniform vec3 color : source_color = vec3(0.91, 0.64, 0.24);
uniform int mode = 0;
uniform float energy = 1.0;
uniform float half_height = 1.0;
varying float local_y;
void vertex() {
	local_y = VERTEX.y;
}
void fragment() {
	vec3 c = vec3(0.0);
	if (mode == 0) {
		float h = clamp((local_y + half_height) / (2.0 * half_height), 0.0, 1.0);
		float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
		float fade = pow(1.0 - h, 1.7) * smoothstep(0.0, 0.03, h);
		float flicker = 0.88 + 0.12 * sin(TIME * 11.0 + h * 25.0);
		float bands = 0.78 + 0.22 * sin(h * 42.0 - TIME * 5.0);
		c = color * energy * fade * pow(facing, 1.6) * flicker * bands;
	} else if (mode == 2) {
		vec2 q = UV - vec2(0.5);
		float rq = length(q) * 2.0;
		float tw = 0.75 + 0.25 * sin(TIME * (1.3 + UV2.x * 2.0) + UV2.x * 40.0);
		c = color * energy * UV2.y * (exp(-rq * rq * 30.0) * 2.2 + exp(-rq * 4.5) * 0.3) * tw * step(rq, 1.0);
	} else {
		vec2 d = UV - vec2(0.5);
		float r = length(d) * 2.0;
		float rings = 0.0;
		for (int i = 0; i < 3; i++) {
			float ph = fract(TIME * 0.42 + float(i) / 3.0);
			rings += smoothstep(0.035, 0.0, abs(r - ph)) * (1.0 - ph) * (1.0 - ph);
		}
		float inner = smoothstep(0.2, 0.185, r) * smoothstep(0.155, 0.17, r);
		float core = exp(-r * 14.0);
		float ticks = step(0.9, fract(atan(d.y, d.x) / 6.2831 * 24.0)) * smoothstep(0.3, 0.28, r) * smoothstep(0.24, 0.26, r);
		c = color * energy * (rings * 1.6 + inner * 1.4 + core * 2.5 + ticks * 0.9) * step(r, 1.0);
	}
	ALBEDO = c;
}
"""

## Hand-authored stylized land (x = lon - 14, y = (39 - lat) * 1.3; straits slightly widened to
## match the region polygons). Points far outside the map close the continents off-screen.
const LAND := [
	# europe
	[
		Vector2(-44.0, -46.8), Vector2(-19.0, -16.9), Vector2(-18.5, -12.22), Vector2(-16.2, -10.66), Vector2(-15.2, -9.1),
		Vector2(-15.5, -5.85), Vector2(-17.8, -5.79), Vector2(-22.0, -6.11), Vector2(-23.3, -5.46), Vector2(-22.9, -3.9),
		Vector2(-22.7, -2.86), Vector2(-23.0, -1.3), Vector2(-23.5, 0.26), Vector2(-22.8, 1.3), Vector2(-23.0, 2.6),
		Vector2(-21.9, 2.6), Vector2(-21.4, 2.34), Vector2(-20.3, 3.25), Vector2(-19.6, 3.7), Vector2(-19.35, 3.6),
		Vector2(-18.4, 2.99), Vector2(-17.5, 2.96), Vector2(-16.45, 2.82), Vector2(-16.2, 2.96), Vector2(-15.6, 2.21),
		Vector2(-14.98, 1.82), Vector2(-14.7, 1.78), Vector2(-14.48, 0.84), Vector2(-13.77, 0.35), Vector2(-14.33, -0.61),
		Vector2(-14.0, -1.3), Vector2(-13.13, -2.21), Vector2(-12.75, -2.73), Vector2(-11.83, -3.09), Vector2(-10.8, -3.77),
		Vector2(-10.7, -4.29), Vector2(-10.95, -4.81), Vector2(-10.9, -5.39), Vector2(-10.3, -5.72), Vector2(-9.4, -5.72),
		Vector2(-8.63, -5.59), Vector2(-8.07, -5.33), Vector2(-7.36, -5.55), Vector2(-6.73, -6.11), Vector2(-5.8, -6.37),
		Vector2(-5.07, -7.02), Vector2(-4.2, -6.63), Vector2(-3.7, -5.91), Vector2(-3.5, -5.14), Vector2(-2.8, -4.42),
		Vector2(-2.2, -4.03), Vector2(-1.7, -3.51), Vector2(-1.0, -2.93), Vector2(-0.5, -2.89), Vector2(0.0, -2.47),
		Vector2(0.25, -2.38), Vector2(0.4, -2.08), Vector2(0.8, -2.14), Vector2(0.95, -1.62), Vector2(1.6, -1.39),
		Vector2(1.8, -0.78), Vector2(2.0, -0.46), Vector2(2.1, 0.06), Vector2(1.83, 0.49), Vector2(1.74, 0.98),
		Vector2(1.7, 1.37), Vector2(2.06, 1.4), Vector2(2.5, 0.78), Vector2(2.6, 0.26), Vector2(3.13, -0.1),
		Vector2(3.15, -0.52), Vector2(2.5, -0.98), Vector2(2.9, -1.69), Vector2(3.24, -1.91), Vector2(3.9, -1.69),
		Vector2(3.99, -1.38), Vector2(4.36, -1.04), Vector2(4.49, -1.49), Vector2(3.94, -2.13), Vector2(2.87, -2.77),
		Vector2(2.0, -3.19), Vector2(1.92, -3.42), Vector2(2.18, -3.74), Vector2(1.6, -3.8), Vector2(0.99, -3.9),
		Vector2(0.21, -4.5), Vector2(-0.15, -5.07), Vector2(-0.48, -6.01), Vector2(-1.43, -6.58), Vector2(-1.7, -7.15),
		Vector2(-1.5, -7.74), Vector2(-1.67, -8.37), Vector2(-0.9, -8.71), Vector2(-0.23, -8.64), Vector2(-0.4, -7.93),
		Vector2(-0.15, -7.63), Vector2(0.2, -8.06), Vector2(0.44, -8.23), Vector2(0.9, -7.67), Vector2(1.23, -6.66),
		Vector2(1.9, -5.98), Vector2(2.44, -5.86), Vector2(3.4, -5.2), Vector2(4.09, -4.74), Vector2(4.6, -4.42),
		Vector2(5.1, -4.03), Vector2(5.5, -3.51), Vector2(5.45, -3.02), Vector2(5.4, -2.47), Vector2(5.49, -1.91),
		Vector2(5.4, -1.69), Vector2(6.0, -1.13), Vector2(6.2, -0.65), Vector2(6.75, 0.05), Vector2(7.1, 0.78),
		Vector2(7.7, 0.98), Vector2(7.15, 1.43), Vector2(7.6, 2.34), Vector2(7.67, 2.73), Vector2(8.0, 2.86),
		Vector2(8.48, 3.41), Vector2(8.56, 2.93), Vector2(8.8, 3.12), Vector2(9.2, 3.33), Vector2(9.05, 3.0),
		Vector2(8.86, 2.38), Vector2(8.8, 1.86), Vector2(9.15, 2.14), Vector2(9.5, 2.08), Vector2(9.0, 1.43),
		Vector2(9.64, 1.38), Vector2(10.03, 1.76), Vector2(10.0, 1.3), Vector2(10.6, 1.3), Vector2(10.2, 0.65),
		Vector2(9.5, 0.0), Vector2(9.0, -0.06), Vector2(9.2, -0.13), Vector2(9.2, -0.78), Vector2(8.6, -1.43),
		Vector2(8.6, -1.95), Vector2(8.94, -2.12), Vector2(9.3, -1.56), Vector2(9.7, -1.24), Vector2(10.0, -1.43),
		Vector2(10.4, -1.49), Vector2(9.9, -2.08), Vector2(10.4, -2.51), Vector2(11.3, -2.57), Vector2(11.88, -2.41),
		Vector2(12.08, -2.24), Vector2(12.45, -2.15), Vector2(12.2, -2.08), Vector2(12.15, -1.4), Vector2(12.5, -1.75),
		Vector2(12.75, -2.0), Vector2(13.1, -2.45), Vector2(13.5, -2.85), Vector2(14.25, -2.98), Vector2(14.95, -2.92),
		Vector2(15.0, -3.15), Vector2(15.05, -3.45), Vector2(14.7, -3.6), Vector2(14.1, -3.95), Vector2(13.9, -4.68),
		Vector2(13.95, -5.46), Vector2(14.6, -6.24), Vector2(14.65, -6.76), Vector2(15.6, -7.8), Vector2(16.2, -8.84),
		Vector2(16.7, -9.75), Vector2(17.8, -9.88), Vector2(18.5, -9.23), Vector2(19.5, -8.97), Vector2(18.5, -8.32),
		Vector2(19.5, -7.28), Vector2(20.1, -7.02), Vector2(21.4, -7.8), Vector2(22.6, -8.32), Vector2(23.5, -7.41),
		Vector2(23.8, -7.28), Vector2(25.0, -6.63), Vector2(25.7, -5.98), Vector2(26.5, -5.33), Vector2(27.5, -4.42),
		Vector2(27.65, -3.38), Vector2(61.0, -3.38), Vector2(61.0, -46.8),
	],
	# asia / africa
	[
		Vector2(27.65, -3.38), Vector2(26.5, -2.64), Vector2(25.7, -2.6), Vector2(24.4, -2.54), Vector2(23.5, -2.73),
		Vector2(22.33, -2.98), Vector2(21.9, -3.51), Vector2(21.15, -3.93), Vector2(20.0, -3.87), Vector2(19.3, -3.9),
		Vector2(18.4, -3.58), Vector2(17.8, -3.6), Vector2(17.4, -3.45), Vector2(16.6, -3.4), Vector2(15.9, -3.45),
		Vector2(15.3, -3.55), Vector2(15.27, -3.15), Vector2(15.2, -2.88), Vector2(15.6, -2.68), Vector2(16.15, -2.55),
		Vector2(15.65, -2.35), Vector2(15.2, -2.2), Vector2(15.15, -1.85), Vector2(14.8, -1.6), Vector2(14.0, -1.5),
		Vector2(13.85, -1.75), Vector2(13.35, -1.62), Vector2(12.85, -1.75), Vector2(12.55, -1.45), Vector2(12.25, -1.15),
		Vector2(12.15, -0.65), Vector2(12.9, -0.71), Vector2(12.7, -0.39), Vector2(12.85, 0.06), Vector2(13.15, 0.75),
		Vector2(12.4, 0.52), Vector2(12.3, 0.88), Vector2(12.8, 1.04), Vector2(13.25, 1.49), Vector2(13.3, 2.08),
		Vector2(13.4, 2.56), Vector2(14.0, 2.6), Vector2(13.4, 2.99), Vector2(14.27, 2.79), Vector2(15.1, 3.06),
		Vector2(15.65, 3.64), Vector2(16.4, 3.51), Vector2(16.7, 2.76), Vector2(17.4, 2.93), Vector2(18.0, 3.21),
		Vector2(18.83, 3.87), Vector2(19.9, 3.44), Vector2(20.63, 2.86), Vector2(21.4, 3.16), Vector2(22.0, 2.73),
		Vector2(22.17, 3.15), Vector2(21.9, 3.38), Vector2(21.95, 3.81), Vector2(21.78, 4.52), Vector2(21.87, 5.33),
		Vector2(21.84, 5.93), Vector2(21.5, 6.63), Vector2(21.2, 7.45), Vector2(20.98, 8.03), Vector2(20.77, 9.0),
		Vector2(20.45, 9.72), Vector2(19.8, 10.23), Vector2(18.3, 10.05), Vector2(17.8, 9.75), Vector2(16.4, 9.79),
		Vector2(15.9, 10.14), Vector2(14.95, 10.62), Vector2(13.25, 9.94), Vector2(11.15, 9.62), Vector2(9.95, 9.0),
		Vector2(8.64, 8.1), Vector2(8.0, 7.93), Vector2(6.07, 8.94), Vector2(6.1, 10.59), Vector2(5.0, 11.31),
		Vector2(2.6, 10.14), Vector2(1.5, 9.75), Vector2(1.2, 8.61), Vector2(0.3, 8.26), Vector2(-0.82, 7.93),
		Vector2(-1.92, 7.89), Vector2(-3.1, 6.76), Vector2(-3.9, 6.66), Vector2(-3.24, 5.54), Vector2(-2.94, 4.55),
		Vector2(-3.36, 4.12), Vector2(-3.4, 3.38), Vector2(-2.95, 2.5), Vector2(-3.8, 2.86), Vector2(-4.13, 2.25),
		Vector2(-5.25, 2.66), Vector2(-6.23, 2.73), Vector2(-7.1, 2.76), Vector2(-8.92, 2.93), Vector2(-10.95, 2.9),
		Vector2(-12.7, 3.25), Vector2(-14.64, 4.29), Vector2(-15.9, 5.07), Vector2(-16.94, 4.81), Vector2(-17.93, 4.88),
		Vector2(-19.36, 4.46), Vector2(-19.3, 4.12), Vector2(-19.8, 4.24), Vector2(-19.92, 4.17), Vector2(-20.15, 4.94),
		Vector2(-20.85, 6.5), Vector2(-21.6, 7.02), Vector2(-23.6, 11.05), Vector2(-23.8, 13.0), Vector2(-27.0, 14.95),
		Vector2(-30.0, 22.1), Vector2(-44.0, 50.7), Vector2(61.0, 50.7), Vector2(61.0, -3.38),
	],
	# sicily
	[
		Vector2(-1.57, 1.56), Vector2(-1.4, 1.17), Vector2(-0.65, 1.13), Vector2(0.0, 1.26), Vector2(1.0, 1.11),
		Vector2(1.45, 0.98), Vector2(1.1, 1.95), Vector2(1.3, 2.47), Vector2(1.1, 3.02), Vector2(0.5, 2.93),
		Vector2(-0.1, 2.47), Vector2(-0.9, 1.95), Vector2(-1.4, 1.76),
	],
	# sardinia
	[
		Vector2(-4.85, -2.93), Vector2(-4.4, -2.47), Vector2(-4.25, -1.3), Vector2(-4.4, -0.26), Vector2(-4.9, -0.26),
		Vector2(-5.6, 0.13), Vector2(-5.6, -0.52), Vector2(-5.5, -1.17), Vector2(-5.6, -1.95), Vector2(-5.8, -2.54),
		Vector2(-5.2, -2.54),
	],
	# corsica
	[
		Vector2(-4.6, -5.2), Vector2(-4.45, -4.68), Vector2(-4.45, -4.03), Vector2(-4.75, -3.12), Vector2(-5.2, -3.38),
		Vector2(-5.4, -3.77), Vector2(-5.4, -4.29), Vector2(-5.3, -4.68), Vector2(-4.7, -4.81),
	],
	# mallorca
	[
		Vector2(-11.65, -0.78), Vector2(-10.8, -1.24), Vector2(-10.55, -0.91), Vector2(-10.8, -0.46), Vector2(-11.25, -0.52),
		Vector2(-11.35, -0.71),
	],
	# menorca
	[
		Vector2(-10.2, -1.36), Vector2(-9.7, -1.17), Vector2(-9.9, -1.07), Vector2(-10.15, -1.2),
	],
	# ibiza
	[
		Vector2(-12.8, 0.03), Vector2(-12.4, -0.13), Vector2(-12.45, 0.19), Vector2(-12.7, 0.19),
	],
	# crete
	[
		Vector2(9.55, 4.42), Vector2(10.0, 4.55), Vector2(11.15, 4.74), Vector2(12.3, 4.81), Vector2(12.15, 5.2),
		Vector2(11.0, 5.26), Vector2(10.0, 4.94), Vector2(9.55, 4.88),
	],
	# cyprus
	[
		Vector2(18.3, 5.14), Vector2(18.9, 4.68), Vector2(19.3, 4.74), Vector2(20.6, 4.29), Vector2(20.0, 5.07),
		Vector2(19.9, 5.26), Vector2(19.0, 5.72), Vector2(18.4, 5.53),
	],
	# rhodes
	[
		Vector2(14.22, 3.31), Vector2(14.25, 3.77), Vector2(13.75, 4.03), Vector2(13.7, 3.64),
	],
	# lesbos
	[
		Vector2(11.85, -0.46), Vector2(12.4, -0.49), Vector2(12.6, -0.06), Vector2(12.1, -0.13),
	],
	# chios
	[
		Vector2(12.0, 0.55), Vector2(12.15, 0.59), Vector2(12.15, 0.98), Vector2(11.95, 0.91),
	],
	# samos
	[
		Vector2(12.6, 1.56), Vector2(13.05, 1.62), Vector2(12.95, 1.76), Vector2(12.6, 1.69),
	],
	# naxos
	[
		Vector2(11.35, 2.41), Vector2(11.6, 2.41), Vector2(11.55, 2.66), Vector2(11.35, 2.63),
	],
	# andros
	[
		Vector2(10.7, 1.33), Vector2(10.95, 1.46), Vector2(10.85, 1.59), Vector2(10.65, 1.49),
	],
	# kefalonia
	[
		Vector2(6.4, 0.78), Vector2(6.7, 0.91), Vector2(6.5, 1.17), Vector2(6.35, 1.04),
	],
	# corfu
	[
		Vector2(5.65, -1.04), Vector2(5.95, -0.98), Vector2(5.95, -0.59), Vector2(5.8, -0.71),
	],
	# malta
	[
		Vector2(0.2, 3.8), Vector2(0.57, 4.06), Vector2(0.4, 4.12),
	],
]

## Coastal (z = 1 major, 0 minor) and inland (z = 2) city lights: x, y in map coordinates.
const CITY_LIGHTS := [
	Vector3(-19.4, 3.73, 1), Vector3(-18.42, 2.96, 1), Vector3(-16.46, 2.81, 1), Vector3(-14.98, 1.82, 1),
	Vector3(-14.48, 0.84, 1), Vector3(-14.38, -0.61, 1), Vector3(-11.83, -3.09, 1), Vector3(-10.8, -5.64, 0),
	Vector3(-8.63, -5.59, 1), Vector3(-8.07, -5.36, 0), Vector3(-6.73, -6.11, 1), Vector3(-5.07, -7.03, 1),
	Vector3(-3.7, -5.91, 0), Vector3(-1.7, -3.58, 1), Vector3(0.25, -2.41, 1), Vector3(-0.64, 1.14, 1),
	Vector3(1.09, 1.95, 0), Vector3(2.87, -2.76, 1), Vector3(-1.67, -8.37, 1), Vector3(-0.23, -8.64, 0),
	Vector3(2.44, -5.86, 0), Vector3(4.09, -4.74, 0), Vector3(5.45, -3.02, 0), Vector3(9.66, 1.35, 1),
	Vector3(8.94, -2.13, 1), Vector3(13.14, 0.75, 1), Vector3(14.98, -2.61, 1), Vector3(15.06, -1.55, 0),
	Vector3(16.7, 2.74, 1), Vector3(18.0, 3.19, 0), Vector3(20.63, 2.86, 1), Vector3(22.17, 3.13, 0),
	Vector3(21.78, 4.52, 0), Vector3(21.5, 6.64, 1), Vector3(20.99, 8.07, 0), Vector3(20.78, 9.0, 1),
	Vector3(20.46, 9.75, 0), Vector3(18.3, 10.06, 0), Vector3(15.92, 10.14, 1), Vector3(6.07, 8.94, 1),
	Vector3(-0.81, 7.94, 1), Vector3(-3.82, 2.86, 1), Vector3(-3.24, 5.54, 0), Vector3(-10.94, 2.93, 1),
	Vector3(-14.63, 4.29, 1), Vector3(-19.8, 4.21, 0), Vector3(0.51, 4.03, 0), Vector3(11.13, 4.76, 0),
	Vector3(19.36, 4.98, 0), Vector3(13.91, -5.47, 0), Vector3(14.63, -6.72, 0), Vector3(16.73, -9.72, 1),
	Vector3(19.52, -7.28, 0), Vector3(22.33, -2.98, 0), Vector3(13.47, -4.55, 0), Vector3(-5.26, -3.8, 0),
	Vector3(-4.89, -0.29, 0), Vector3(-11.35, -0.74, 0), Vector3(13.43, 2.55, 0), Vector3(7.73, 0.98, 0),
	Vector3(17.8, -3.19, 0), Vector3(12.4, -1.49, 0), Vector3(17.24, 11.65, 2), Vector3(22.3, 7.14, 2),
	Vector3(18.86, -1.21, 2), Vector3(-17.7, -1.85, 2), Vector3(-9.17, -8.79, 2), Vector3(-4.81, -8.4, 2),
	Vector3(9.32, -4.81, 2), Vector3(12.1, -7.06, 2), Vector3(6.46, -7.53, 2), Vector3(1.98, -8.85, 2),
	Vector3(-2.75, -6.2, 2), Vector3(21.93, 9.17, 2), Vector3(15.0, 1.56, 2), Vector3(16.5, -1.04, 2),
	Vector3(-14.89, -3.44, 2), Vector3(-12.56, -5.98, 2),
]


class RegionView extends RefCounted:
	var id: String = ""
	var anchor: Vector2 = Vector2.ZERO
	var poly: PackedVector2Array = PackedVector2Array()    # rendered outline (may be extended)
	var extended: bool = false                             # poly differs from RegionData
	var mat: ShaderMaterial = null
	var name_label: Label3D = null
	var status_label: Label3D = null
	var name_size: Vector2 = Vector2.ZERO                  # label text size in world units
	var status_size: Vector2 = Vector2.ZERO
	var outline_mi: MeshInstance3D = null
	var outline_mat: ShaderMaterial = null
	var health: float = 0.5
	var health_goal: float = 0.5
	var pollution: float = 0.5
	var pollution_goal: float = 0.5
	var coral: float = 0.5
	var coral_goal: float = 0.5
	var grass: float = 0.5
	var grass_goal: float = 0.5
	var crisis: float = 50.0
	var crisis_goal: float = 50.0
	var protection: float = 0.0
	var protection_goal: float = 0.0
	var status: String = ""
	var highlight: float = 0.0
	var selected: float = 0.0
	var flash: float = 0.0
	var pulse: float = 0.0
	var wave_phase: float = 0.0


class RouteView extends RefCounted:
	var a: String = ""
	var b: String = ""
	var kind: String = "current"
	var mat: ShaderMaterial = null
	var phase: float = 0.0
	var dir: float = 1.0
	var danger: float = 0.0
	var calm: float = 0.0
	var flash: float = 0.0
	var burst: float = -1.0
	var burst_dir: float = 1.0


var camera: Camera3D

var _built: bool = false
var _menu_mode: bool = true
var _time: float = 0.0
var _views: Dictionary = {}        # region id -> RegionView
var _routes: Array = []            # RouteView
var _hovered: String = ""
var _selected: String = ""
var _pending_flashes: Array = []   # [[seconds_left: float, region_id: String], ...]
var _label_font: SystemFont = null
var _hero_label: Label3D = null
var _label_alpha: float = 0.0
var _hero_alpha: float = 1.0
var _end_open: bool = false        # menu mode is showing the end screen (hero label hidden)

var _cam_target: Vector3 = MENU_TARGET
var _cam_dist: float = MENU_DIST
var _cam_pitch: float = MENU_PITCH
var _snap_camera: bool = true
var _parallax: Vector2 = Vector2.ZERO
var _shake: float = 0.0
var _shake_peak: float = 0.0

var _mouse_pos: Vector2 = Vector2.ZERO
var _mouse_on_map: bool = false
var _motion_pending: bool = false
var _motion_reached_map: bool = false


func _ready() -> void:
	_label_font = SystemFont.new()
	_label_font.font_names = PackedStringArray(["Consolas", "Courier New", "monospace"])
	_label_font.font_weight = 600
	_build_environment()
	_build_camera()
	_build_floor()
	_build_land()
	_build_regions()
	_build_routes()
	_build_hero()
	_build_labels()
	_connect_bus()
	for rid in RegionData.IDS:
		var region_id: String = rid
		var start: RegionData = RegionData.new(region_id)
		_apply_region_data(region_id, start.to_dict(), true)
	_selected = GameState.selected_region
	_built = true
	_label_alpha = 0.0 if _menu_mode else 1.0
	_update_regions(0.0)
	_update_routes(0.0)
	_update_labels(0.0)
	_update_camera(0.0)


# =====================================================================================
# Public API (frozen)
# =====================================================================================

## true: cinematic idle camera, picking disabled (main menu / end screen).
func set_menu_mode(on: bool) -> void:
	if not on or _menu_mode:
		# Gameplay, or menu mode asked again while already on (end screen -> main menu):
		# the end screen is gone, so the hero label may show again.
		_end_open = false
	_menu_mode = on
	if on:
		_mouse_on_map = false
		_set_hover("")
		_clear_selection()
	if _time <= 0.0:
		# Nothing rendered yet (startup / --autostart): jump straight to the framing.
		_snap_camera = true
		_label_alpha = 0.0 if on else 1.0


## Camera shake impulse, strength 0..1 (decays over ~0.4 s).
func shake(strength: float) -> void:
	var s: float = clampf(strength, 0.0, 1.5)
	if s > _shake:
		_shake = s
		_shake_peak = s


## Screen position of a region's anchor (for Phase 2 bubbles).
func unproject_region(region_id: String) -> Vector2:
	if camera == null or not camera.is_inside_tree() or not RegionData.DEFS.has(region_id):
		return Vector2.ZERO
	var a: Vector2 = RegionData.anchor_of(region_id)
	return camera.unproject_position(Vector3(a.x, SEA_Y, a.y))


# =====================================================================================
# Scene construction
# =====================================================================================

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = UITheme.BG
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.4, 0.52)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_normalized = false
	env.glow_intensity = 0.85
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 0.95
	env.glow_hdr_scale = 2.0
	env.set_glow_level(0, 0.0)
	env.set_glow_level(1, 0.55)
	env.set_glow_level(2, 0.8)
	env.set_glow_level(3, 0.6)
	env.set_glow_level(4, 0.35)
	env.set_glow_level(5, 0.15)
	env.set_glow_level(6, 0.0)
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.12
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)

	# Sun from the north so wave normals throw glints back toward the camera.
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-58.0, 180.0, 0.0)
	sun.light_color = Color(1.0, 0.93, 0.82)
	sun.light_energy = 0.55
	sun.shadow_enabled = false
	add_child(sun)


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "MapCamera"
	camera.fov = CAM_FOV
	camera.near = 1.0
	camera.far = 400.0
	add_child(camera)
	camera.make_current()


func _grid_material(layer: int) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = GRID_SHADER
	mat.set_shader_parameter("layer", layer)
	mat.set_shader_parameter("bg_color", UITheme.BG)
	mat.set_shader_parameter("deep_color", UITheme.BG.lerp(Color(0.02, 0.08, 0.13), 0.35))
	mat.set_shader_parameter("grid_color", UITheme.HEALTHY.lerp(UITheme.TEXT_DIM, 0.55))
	mat.set_shader_parameter("land_color", UITheme.BG.lerp(UITheme.ASH, 0.24).lerp(UITheme.TERRACOTTA, 0.04))
	mat.set_shader_parameter("cliff_color", UITheme.TERRACOTTA)
	mat.set_shader_parameter("coast_color", UITheme.AMBER)
	mat.set_shader_parameter("ping_color", UITheme.AMBER)
	mat.set_shader_parameter("focus", Vector2(1.3, 1.0))
	mat.set_shader_parameter("hero", HERO_POS)
	mat.set_shader_parameter("fade_near", 17.0)
	mat.set_shader_parameter("fade_far", 34.0)
	mat.set_shader_parameter("coast_energy", 2.2)
	return mat


func _add_mesh(mesh: Mesh, mat: Material, node_name: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _build_floor() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(190.0, 140.0)
	var mi := _add_mesh(plane, _grid_material(0), "SeaFloor")
	mi.position = Vector3(2.0, FLOOR_Y, 4.0)


## All land polygons merged into one mesh (tops + cliffs) plus one coastline ribbon mesh.
func _build_land() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var coast := SurfaceTool.new()
	coast.begin(Mesh.PRIMITIVE_TRIANGLES)
	for entry in LAND:
		var pts: Array = entry
		var poly := PackedVector2Array()
		for v in pts:
			var p: Vector2 = v
			poly.append(p)
		if poly.size() < 3:
			continue
		var tris := _triangulate_points(poly)
		for i in tris.size():
			var t: Vector2 = tris[i]
			_vert(st, Vector3(t.x, LAND_Y, t.y), Vector3.UP, Vector2(0.0, 0.0), Vector2.ZERO)
		var n: int = poly.size()
		for i in n:
			var a: Vector2 = poly[i]
			var b: Vector2 = poly[(i + 1) % n]
			if _is_far(a) or _is_far(b):
				continue
			_add_wall(st, a, b, LAND_Y, WALL_BOTTOM_Y, 2.0, 0.0, 0.0, 0.0)
		_add_coastline(coast, poly)
	_add_mesh(st.commit(), _grid_material(1), "Land")
	_add_mesh(coast.commit(), _grid_material(2), "Coastline")


## Region outline as rendered and picked: RegionData's polygon, merged with its entry in
## REGION_EXTENSIONS unless region.gd already covers that water. Falls back to the plain
## polygon whenever the merge does not give exactly one outline.
func _render_polygon(region_id: String) -> PackedVector2Array:
	var poly: PackedVector2Array = RegionData.polygon_of(region_id)
	if not REGION_EXTENSIONS.has(region_id):
		return poly
	var ext_pts: Array = REGION_EXTENSIONS[region_id]
	var ext := PackedVector2Array()
	for v in ext_pts:
		var q: Vector2 = v
		ext.append(q)
	if Geometry2D.is_point_in_polygon(RegionData.centroid(ext), poly):
		return poly
	var merged: Array = Geometry2D.merge_polygons(poly, ext)
	if merged.size() != 1:
		return poly
	var out: PackedVector2Array = merged[0]
	if out.size() < 3:
		return poly
	return out


func _build_regions() -> void:
	var index: int = 0
	for rid in RegionData.IDS:
		var region_id: String = rid
		var poly: PackedVector2Array = _render_polygon(region_id)
		var mat := ShaderMaterial.new()
		mat.shader = SEA_SHADER
		mat.set_shader_parameter("healthy_color", UITheme.HEALTHY)
		mat.set_shader_parameter("crisis_color", UITheme.CRISIS)
		mat.set_shader_parameter("warning_color", UITheme.WARNING)
		mat.set_shader_parameter("accent_color", UITheme.AMBER)
		mat.set_shader_parameter("pulse_color", UITheme.HEALTHY)
		mat.set_shader_parameter("anchor", RegionData.anchor_of(region_id))
		mat.set_shader_parameter("seed", float(index) * 17.31)
		_add_mesh(_build_region_mesh(poly), mat, "Region_" + region_id)
		var rv := RegionView.new()
		rv.id = region_id
		rv.anchor = RegionData.anchor_of(region_id)
		rv.poly = poly
		rv.extended = poly != RegionData.polygon_of(region_id)
		rv.mat = mat
		# Selection / hover marquee: dashed ribbon on the region outline, drawn above the land.
		var ost := SurfaceTool.new()
		ost.begin(Mesh.PRIMITIVE_TRIANGLES)
		_add_ribbon(ost, poly, true, 0.1, LAND_Y + 0.03)
		var omat := ShaderMaterial.new()
		omat.shader = ROUTE_SHADER
		omat.set_shader_parameter("kind", 1.0)
		omat.set_shader_parameter("closed", 1.0)
		omat.set_shader_parameter("length_units", 1.0)
		omat.set_shader_parameter("hot_color", UITheme.CRISIS)
		omat.set_shader_parameter("color", UITheme.AMBER)
		rv.outline_mi = _add_mesh(ost.commit(), omat, "Outline_" + region_id)
		rv.outline_mi.visible = false
		rv.outline_mat = omat
		rv.wave_phase = float(index) * 3.7
		_views[region_id] = rv
		index += 1


## One surface per region: subdivided water top (part 0), glowing rim band (part 1) and side
## walls (part 2). The sea shader branches on UV.x; cull is disabled in the shader.
func _build_region_mesh(poly: PackedVector2Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dense := _densify(poly, TOP_STEP)
	var top: Dictionary = _top_triangles(poly, dense)
	var pts: PackedVector2Array = top["points"]
	var idx: PackedInt32Array = top["indices"]
	var shore := PackedFloat32Array()
	for i in pts.size():
		var d: float = _dist_to_edges(pts[i], poly)
		shore.append(clampf((d - 0.18) / 1.9, 0.0, 1.0))
	for k in idx.size():
		var vi: int = idx[k]
		var p: Vector2 = pts[vi]
		_vert(st, Vector3(p.x, SEA_Y, p.y), Vector3.UP, Vector2(0.0, shore[vi]), Vector2(1.0, 0.0))

	var inward := _inward_offsets(dense, RIM_WIDTH, _signed_area(poly) > 0.0)
	var m: int = dense.size()
	var along: float = 0.0
	for i in m:
		var j: int = (i + 1) % m
		var a: Vector2 = dense[i]
		var b: Vector2 = dense[j]
		var ai: Vector2 = a + inward[i]
		var bi: Vector2 = b + inward[j]
		var next_along: float = along + a.distance_to(b)
		var y: float = SEA_Y + RIM_LIFT
		_vert(st, Vector3(a.x, y, a.y), Vector3.UP, Vector2(1.0, 0.0), Vector2(1.0, along))
		_vert(st, Vector3(b.x, y, b.y), Vector3.UP, Vector2(1.0, 0.0), Vector2(1.0, next_along))
		_vert(st, Vector3(bi.x, y, bi.y), Vector3.UP, Vector2(1.0, 1.0), Vector2(1.0, next_along))
		_vert(st, Vector3(a.x, y, a.y), Vector3.UP, Vector2(1.0, 0.0), Vector2(1.0, along))
		_vert(st, Vector3(bi.x, y, bi.y), Vector3.UP, Vector2(1.0, 1.0), Vector2(1.0, next_along))
		_vert(st, Vector3(ai.x, y, ai.y), Vector3.UP, Vector2(1.0, 1.0), Vector2(1.0, along))
		_add_wall(st, a, b, SEA_Y, WALL_BOTTOM_Y, 2.0, 1.0, along, next_along)
		along = next_along
	return st.commit()


func _build_routes() -> void:
	for r in RegionData.ROUTES:
		var route: Dictionary = r
		var a_id: String = route["a"]
		var b_id: String = route["b"]
		var kind: String = route["kind"]
		var a: Vector2 = RegionData.anchor_of(a_id)
		var b: Vector2 = RegionData.anchor_of(b_id)
		var dir: Vector2 = (b - a).normalized()
		var start: Vector2 = a + dir * ROUTE_END_GAP
		var finish: Vector2 = b - dir * ROUTE_END_GAP
		var span: float = start.distance_to(finish)
		var shipping: bool = kind == "shipping"
		var lift: float = clampf(span * 0.2, 0.9, 2.8)
		var radius: float = 0.12
		if shipping:
			lift *= 0.6
			radius = 0.075
		var p0 := Vector3(start.x, 0.12, start.y)
		var p2 := Vector3(finish.x, 0.12, finish.y)
		var p1: Vector3 = (p0 + p2) * 0.5 + Vector3(0.0, lift * 2.0, 0.0)
		var length: float = _bezier_length(p0, p1, p2, 48)
		var mat := ShaderMaterial.new()
		mat.shader = ROUTE_SHADER
		mat.set_shader_parameter("hot_color", UITheme.CRISIS)
		mat.set_shader_parameter("kind", 1.0 if shipping else 0.0)
		mat.set_shader_parameter("length_units", length)
		mat.set_shader_parameter("intensity", 1.0)
		_add_mesh(_tube_mesh(p0, p1, p2, radius, 48, 7), mat, "Route_%s_%s" % [a_id, b_id])
		var rt := RouteView.new()
		rt.a = a_id
		rt.b = b_id
		rt.kind = kind
		rt.mat = mat
		rt.phase = float(_routes.size()) * 0.37
		_routes.append(rt)


func _build_hero() -> void:
	var shader := Shader.new()
	shader.code = BEACON_SHADER_CODE

	var beam := CylinderMesh.new()
	beam.top_radius = 0.06
	beam.bottom_radius = 0.09
	beam.height = 4.6
	beam.radial_segments = 16
	beam.rings = 1
	var beam_mat := _beacon_material(shader, 0, 5.0, beam.height * 0.5)
	var beam_mi := _add_mesh(beam, beam_mat, "HeroBeam")
	beam_mi.position = Vector3(HERO_POS.x, LAND_Y + beam.height * 0.5, HERO_POS.y)

	var halo := CylinderMesh.new()
	halo.top_radius = 0.3
	halo.bottom_radius = 0.42
	halo.height = 3.2
	halo.radial_segments = 20
	halo.rings = 1
	var halo_mi := _add_mesh(halo, _beacon_material(shader, 0, 0.45, halo.height * 0.5), "HeroHalo")
	halo_mi.position = Vector3(HERO_POS.x, LAND_Y + halo.height * 0.5, HERO_POS.y)

	var ring := PlaneMesh.new()
	ring.size = Vector2(4.4, 4.4)
	var ring_mi := _add_mesh(ring, _beacon_material(shader, 1, 1.6, 1.0), "HeroRing")
	ring_mi.position = Vector3(HERO_POS.x, LAND_Y + 0.03, HERO_POS.y)

	_build_city_lights(shader)

	_hero_label = _make_label(NAME_FONT_SIZE, UITheme.AMBER)
	_hero_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_hero_label.position = Vector3(HERO_POS.x + 0.9, LAND_Y + beam.height + 0.2, HERO_POS.y)
	_hero_label.text = I18n.t("map.hero_label")
	add_child(_hero_label)


## All city lights in one mesh of flat soft-dot quads on the land (one draw call).
func _build_city_lights(shader: Shader) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var index: int = 0
	for c in CITY_LIGHTS:
		var city: Vector3 = c
		var half: float = 0.3
		var bright: float = 0.65
		if city.z > 1.5:
			half = 0.24
			bright = 0.35
		elif city.z > 0.5:
			half = 0.42
			bright = 1.0
		var seed_v: float = fposmod(float(index) * 0.618, 1.0)
		var y: float = LAND_Y + 0.02
		var c0 := Vector3(city.x - half, y, city.y - half)
		var c1 := Vector3(city.x + half, y, city.y - half)
		var c2 := Vector3(city.x + half, y, city.y + half)
		var c3 := Vector3(city.x - half, y, city.y + half)
		var info := Vector2(seed_v, bright)
		_vert(st, c0, Vector3.UP, Vector2(0.0, 0.0), info)
		_vert(st, c1, Vector3.UP, Vector2(1.0, 0.0), info)
		_vert(st, c2, Vector3.UP, Vector2(1.0, 1.0), info)
		_vert(st, c0, Vector3.UP, Vector2(0.0, 0.0), info)
		_vert(st, c2, Vector3.UP, Vector2(1.0, 1.0), info)
		_vert(st, c3, Vector3.UP, Vector2(0.0, 1.0), info)
		index += 1
	var mat := _beacon_material(shader, 2, 1.6, 1.0)
	mat.set_shader_parameter("color", UITheme.AMBER.lerp(UITheme.TEXT, 0.4))
	_add_mesh(st.commit(), mat, "CityLights")


func _beacon_material(shader: Shader, mode: int, energy: float, half_height: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("color", UITheme.AMBER)
	mat.set_shader_parameter("mode", mode)
	mat.set_shader_parameter("energy", energy)
	mat.set_shader_parameter("half_height", half_height)
	return mat


func _build_labels() -> void:
	for rid in RegionData.IDS:
		var region_id: String = rid
		var rv: RegionView = _views[region_id]
		var at: Vector2 = rv.anchor
		if LABEL_OFFSET.has(region_id):
			var off: Vector2 = LABEL_OFFSET[region_id]
			at += off
		var pos := Vector3(at.x, LABEL_LIFT, at.y)
		rv.name_label = _make_label(NAME_FONT_SIZE, UITheme.TEXT)
		rv.name_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		rv.name_label.position = pos
		rv.name_label.text = I18n.t(RegionData.name_key_of(region_id))
		add_child(rv.name_label)
		rv.status_label = _make_label(STATUS_FONT_SIZE, UITheme.TEXT_DIM)
		rv.status_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		rv.status_label.position = pos
		add_child(rv.status_label)
		_measure_labels(rv)


## Text size of a Label3D in world units (autowrapped like the label, plus the outline).
func _label_size(lbl: Label3D) -> Vector2:
	if lbl == null or lbl.text == "" or _label_font == null:
		return Vector2.ZERO
	var px: Vector2 = _label_font.get_multiline_string_size(lbl.text, HORIZONTAL_ALIGNMENT_CENTER, lbl.width, lbl.font_size)
	return (px + Vector2(lbl.outline_size, lbl.outline_size)) * lbl.pixel_size


## Caches the label sizes (picking) and hands the labels' ground footprint to the sea shader,
## which keeps its selection rings out from under the text.
func _measure_labels(rv: RegionView) -> void:
	if rv.name_label == null or rv.status_label == null:
		return
	rv.name_size = _label_size(rv.name_label)
	rv.status_size = _label_size(rv.status_label)
	# Billboard text seen from the gameplay pitch: the name sits above the anchor on screen
	# (farther north on the ground), the status below it.
	var pitch: float = deg_to_rad(GAME_PITCH)
	var to_ground: float = 1.0 / sin(pitch)
	var base_z: float = rv.name_label.position.z - LABEL_LIFT * cos(pitch) / sin(pitch)
	var north: float = base_z - rv.name_size.y * to_ground
	var south: float = base_z + rv.status_size.y * to_ground
	var half_w: float = maxf(rv.name_size.x, rv.status_size.x) * 0.5
	var center := Vector2(rv.name_label.position.x, (north + south) * 0.5)
	rv.mat.set_shader_parameter("label_center", center)
	rv.mat.set_shader_parameter("label_half", Vector2(half_w, (south - north) * 0.5))


func _make_label(font_size: int, color: Color) -> Label3D:
	var lbl := Label3D.new()
	lbl.font = _label_font
	lbl.font_size = font_size
	lbl.pixel_size = LABEL_PIXEL
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.shaded = false
	lbl.double_sided = true
	lbl.fixed_size = false
	lbl.outline_size = 10
	lbl.outline_modulate = Color(UITheme.BG.r, UITheme.BG.g, UITheme.BG.b, 0.88)
	lbl.modulate = color
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.width = 280.0
	lbl.render_priority = 10
	lbl.outline_render_priority = 9
	return lbl


func _connect_bus() -> void:
	EventBus.region_changed.connect(_on_region_changed)
	EventBus.spread_happened.connect(_on_spread_happened)
	EventBus.evolution_happened.connect(_on_evolution_happened)
	EventBus.toast.connect(_on_toast)
	EventBus.action_performed.connect(_on_action_performed)
	EventBus.region_selected.connect(_on_region_selected)
	EventBus.language_changed.connect(_on_language_changed)
	EventBus.game_started.connect(_on_game_started)
	EventBus.game_over.connect(_on_game_over)


# =====================================================================================
# Geometry helpers
# =====================================================================================

func _vert(st: SurfaceTool, pos: Vector3, nrm: Vector3, uv: Vector2, uv2: Vector2) -> void:
	st.set_normal(nrm)
	st.set_uv(uv)
	st.set_uv2(uv2)
	st.add_vertex(pos)


## Vertical quad from a to b. UV.x = part, UV.y = 0 top .. 1 bottom; UV2.x = wave weight
## (top edge only), UV2.y = distance along the outline.
func _add_wall(st: SurfaceTool, a: Vector2, b: Vector2, top_y: float, bottom_y: float, part: float, wave_top: float, along_a: float, along_b: float) -> void:
	var d: Vector2 = b - a
	var nrm := Vector3(d.y, 0.0, -d.x).normalized()
	var at := Vector3(a.x, top_y, a.y)
	var bt := Vector3(b.x, top_y, b.y)
	var bb := Vector3(b.x, bottom_y, b.y)
	var ab := Vector3(a.x, bottom_y, a.y)
	_vert(st, at, nrm, Vector2(part, 0.0), Vector2(wave_top, along_a))
	_vert(st, bt, nrm, Vector2(part, 0.0), Vector2(wave_top, along_b))
	_vert(st, bb, nrm, Vector2(part, 1.0), Vector2(0.0, along_b))
	_vert(st, at, nrm, Vector2(part, 0.0), Vector2(wave_top, along_a))
	_vert(st, bb, nrm, Vector2(part, 1.0), Vector2(0.0, along_b))
	_vert(st, ab, nrm, Vector2(part, 1.0), Vector2(0.0, along_a))


func _is_far(p: Vector2) -> bool:
	return absf(p.x) > FAR_X or absf(p.y) > FAR_Y


func _signed_area(poly: PackedVector2Array) -> float:
	var s: float = 0.0
	var n: int = poly.size()
	for i in n:
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % n]
		s += a.x * b.y - b.x * a.y
	return s * 0.5


func _densify(poly: PackedVector2Array, step: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n: int = poly.size()
	for i in n:
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % n]
		var segs: int = maxi(1, ceili(a.distance_to(b) / step))
		for s in segs:
			out.append(a.lerp(b, float(s) / float(segs)))
	return out


func _dist_to_edges(p: Vector2, poly: PackedVector2Array) -> float:
	var best: float = INF
	var n: int = poly.size()
	for i in n:
		var c: Vector2 = Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % n])
		best = minf(best, p.distance_squared_to(c))
	return sqrt(best)


## Triangles as a flat point list (3 points each). Ear clipping first; README crash rule 1
## fallbacks: convex decomposition, then a centroid triangle fan.
func _triangulate_points(poly: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	var idx := Geometry2D.triangulate_polygon(poly)
	if idx.size() >= 3:
		for i in idx:
			out.append(poly[i])
		return out
	var parts: Array = Geometry2D.decompose_polygon_in_convex(poly)  # SAFE-FALLBACK
	for part in parts:
		var piece: PackedVector2Array = part
		for i in range(1, piece.size() - 1):
			out.append(piece[0])
			out.append(piece[i])
			out.append(piece[i + 1])
	if out.size() >= 3:
		return out
	var c: Vector2 = RegionData.centroid(poly)
	var n: int = poly.size()
	for i in n:
		out.append(c)
		out.append(poly[i])
		out.append(poly[(i + 1) % n])
	return out


## Subdivided water surface: densified outline + jittered interior grid, Delaunay, keep the
## triangles that lie inside the polygon. If the kept area does not match the polygon area
## (concave trouble), fall back to exact ear clipping of the densified outline.
## Returns {"points": PackedVector2Array, "indices": PackedInt32Array}.
func _top_triangles(poly: PackedVector2Array, dense: PackedVector2Array) -> Dictionary:
	var pts := PackedVector2Array(dense)
	var nb: int = pts.size()
	var lo: Vector2 = poly[0]
	var hi: Vector2 = poly[0]
	for p in poly:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	var counter: int = 0
	var gx: float = lo.x + TOP_STEP * 0.5
	while gx < hi.x:
		var gy: float = lo.y + TOP_STEP * 0.5
		while gy < hi.y:
			counter += 1
			var jitter := Vector2(sin(float(counter) * 12.9898), cos(float(counter) * 78.233)) * TOP_STEP * 0.12
			var q: Vector2 = Vector2(gx, gy) + jitter
			if Geometry2D.is_point_in_polygon(q, poly) and _dist_to_edges(q, poly) > TOP_STEP * 0.45:
				pts.append(q)
			gy += TOP_STEP
		gx += TOP_STEP

	var tri := Geometry2D.triangulate_delaunay(pts)
	var kept := PackedInt32Array()
	var covered: float = 0.0
	for k in range(0, tri.size() - 2, 3):
		var i0: int = tri[k]
		var i1: int = tri[k + 1]
		var i2: int = tri[k + 2]
		var a: Vector2 = pts[i0]
		var b: Vector2 = pts[i1]
		var c: Vector2 = pts[i2]
		var area: float = absf((b - a).cross(c - a)) * 0.5
		if area < 0.00001:
			continue
		if not Geometry2D.is_point_in_polygon((a + b + c) / 3.0, poly):
			continue
		if not (_edge_inside(i0, i1, pts, nb, poly) and _edge_inside(i1, i2, pts, nb, poly) and _edge_inside(i2, i0, pts, nb, poly)):
			continue
		kept.append(i0)
		kept.append(i1)
		kept.append(i2)
		covered += area
	var target: float = absf(_signed_area(poly))
	if kept.size() >= 3 and target > 0.0 and absf(covered - target) / target < 0.015:
		return {"points": pts, "indices": kept}
	var flat := _triangulate_points(dense)  # SAFE-FALLBACK
	var seq := PackedInt32Array()
	for i in flat.size():
		seq.append(i)
	return {"points": flat, "indices": seq}


## Outline edges (consecutive outline points) are always fine; any other edge must have its
## midpoint inside the polygon (rejects triangles bridging a concave notch).
func _edge_inside(i: int, j: int, pts: PackedVector2Array, nb: int, poly: PackedVector2Array) -> bool:
	if i < nb and j < nb:
		var diff: int = absi(i - j)
		if diff == 1 or diff == nb - 1:
			return true
	return Geometry2D.is_point_in_polygon((pts[i] + pts[j]) * 0.5, poly)


## Per-vertex mitred offsets pointing into the polygon interior.
func _inward_offsets(dense: PackedVector2Array, width: float, ccw: bool) -> PackedVector2Array:
	var out := PackedVector2Array()
	var m: int = dense.size()
	var sgn: float = 1.0 if ccw else -1.0
	for i in m:
		var prev: Vector2 = dense[(i - 1 + m) % m]
		var cur: Vector2 = dense[i]
		var nxt: Vector2 = dense[(i + 1) % m]
		var d0: Vector2 = (cur - prev).normalized()
		var d1: Vector2 = (nxt - cur).normalized()
		var n0: Vector2 = Vector2(-d0.y, d0.x) * sgn
		var n1: Vector2 = Vector2(-d1.y, d1.x) * sgn
		var sum: Vector2 = n0 + n1
		var nrm: Vector2 = n0
		if sum.length_squared() > 0.0001:
			nrm = sum.normalized()
		var miter: float = minf(1.0 / maxf(nrm.dot(n0), 0.45), 2.2)
		out.append(nrm * width * miter)
	return out


## Splits the outline into runs of on-map edges and lays a glowing ribbon along each run.
func _add_coastline(st: SurfaceTool, poly: PackedVector2Array) -> void:
	var n: int = poly.size()
	var coast_edge: Array = []
	var start: int = -1
	for i in n:
		var on_map: bool = not (_is_far(poly[i]) or _is_far(poly[(i + 1) % n]))
		coast_edge.append(on_map)
		if not on_map and start < 0:
			start = i
	var y: float = LAND_Y + 0.01
	if start < 0:
		_add_ribbon(st, poly, true, COAST_WIDTH, y)
		return
	var run := PackedVector2Array()
	for k in range(1, n + 1):
		var i: int = (start + k) % n
		var on_map: bool = coast_edge[i]
		if on_map:
			if run.is_empty():
				run.append(poly[i])
			run.append(poly[(i + 1) % n])
		else:
			if run.size() >= 2:
				_add_ribbon(st, run, false, COAST_WIDTH, y)
			run = PackedVector2Array()
	if run.size() >= 2:
		_add_ribbon(st, run, false, COAST_WIDTH, y)


## Flat mitred ribbon centred on a polyline. UV.x = distance along, UV.y = 0..1 across.
func _add_ribbon(st: SurfaceTool, pts: PackedVector2Array, closed: bool, width: float, y: float) -> void:
	var m: int = pts.size()
	if m < 2:
		return
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var dist := PackedFloat32Array()
	var acc: float = 0.0
	for i in m:
		var p: Vector2 = pts[i]
		var has_prev: bool = i > 0 or closed
		var has_next: bool = i < m - 1 or closed
		var n_in := Vector2.ZERO
		var n_out := Vector2.ZERO
		if has_prev:
			var d0: Vector2 = (p - pts[(i - 1 + m) % m]).normalized()
			n_in = Vector2(-d0.y, d0.x)
		if has_next:
			var d1: Vector2 = (pts[(i + 1) % m] - p).normalized()
			n_out = Vector2(-d1.y, d1.x)
		if not has_prev:
			n_in = n_out
		if not has_next:
			n_out = n_in
		var sum: Vector2 = n_in + n_out
		var nrm: Vector2 = n_in
		if sum.length_squared() > 0.0001:
			nrm = sum.normalized()
		var miter: float = minf(1.0 / maxf(nrm.dot(n_in), 0.5), 2.0)
		var off: Vector2 = nrm * width * 0.5 * miter
		left.append(p + off)
		right.append(p - off)
		if i > 0:
			acc += p.distance_to(pts[i - 1])
		dist.append(acc)
	var segs: int = m - 1
	if closed:
		segs = m
	for i in segs:
		var j: int = (i + 1) % m
		var da: float = dist[i]
		var db: float = dist[j]
		if j == 0:
			db = acc + pts[m - 1].distance_to(pts[0])
		var la: Vector2 = left[i]
		var lb: Vector2 = left[j]
		var ra: Vector2 = right[i]
		var rb: Vector2 = right[j]
		_vert(st, Vector3(la.x, y, la.y), Vector3.UP, Vector2(da, 0.0), Vector2.ZERO)
		_vert(st, Vector3(lb.x, y, lb.y), Vector3.UP, Vector2(db, 0.0), Vector2.ZERO)
		_vert(st, Vector3(rb.x, y, rb.y), Vector3.UP, Vector2(db, 1.0), Vector2.ZERO)
		_vert(st, Vector3(la.x, y, la.y), Vector3.UP, Vector2(da, 0.0), Vector2.ZERO)
		_vert(st, Vector3(rb.x, y, rb.y), Vector3.UP, Vector2(db, 1.0), Vector2.ZERO)
		_vert(st, Vector3(ra.x, y, ra.y), Vector3.UP, Vector2(da, 1.0), Vector2.ZERO)


func _bezier(p0: Vector3, p1: Vector3, p2: Vector3, t: float) -> Vector3:
	var u: float = 1.0 - t
	return p0 * (u * u) + p1 * (2.0 * u * t) + p2 * (t * t)


func _bezier_length(p0: Vector3, p1: Vector3, p2: Vector3, segments: int) -> float:
	var total: float = 0.0
	var prev: Vector3 = p0
	for i in range(1, segments + 1):
		var cur: Vector3 = _bezier(p0, p1, p2, float(i) / float(segments))
		total += prev.distance_to(cur)
		prev = cur
	return total


## Tube along a quadratic Bézier. UV.x = 0..1 along, UV.y = 0..1 around.
func _tube_mesh(p0: Vector3, p1: Vector3, p2: Vector3, radius: float, seg_len: int, seg_rad: int) -> ArrayMesh:
	var centers := PackedVector3Array()
	for i in seg_len + 1:
		centers.append(_bezier(p0, p1, p2, float(i) / float(seg_len)))
	var ring_pos := PackedVector3Array()
	var ring_nrm := PackedVector3Array()
	for i in seg_len + 1:
		var tangent: Vector3 = (centers[mini(i + 1, seg_len)] - centers[maxi(i - 1, 0)]).normalized()
		var side: Vector3 = tangent.cross(Vector3.UP).normalized()
		var up: Vector3 = side.cross(tangent).normalized()
		for k in seg_rad + 1:
			var ang: float = TAU * float(k) / float(seg_rad)
			var radial: Vector3 = side * cos(ang) + up * sin(ang)
			ring_pos.append(centers[i] + radial * radius)
			ring_nrm.append(radial)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stride: int = seg_rad + 1
	for i in seg_len:
		for k in seg_rad:
			var i00: int = i * stride + k
			var i01: int = i * stride + k + 1
			var i10: int = (i + 1) * stride + k
			var i11: int = (i + 1) * stride + k + 1
			var u0: float = float(i) / float(seg_len)
			var u1: float = float(i + 1) / float(seg_len)
			var v0: float = float(k) / float(seg_rad)
			var v1: float = float(k + 1) / float(seg_rad)
			_vert(st, ring_pos[i00], ring_nrm[i00], Vector2(u0, v0), Vector2.ZERO)
			_vert(st, ring_pos[i10], ring_nrm[i10], Vector2(u1, v0), Vector2.ZERO)
			_vert(st, ring_pos[i11], ring_nrm[i11], Vector2(u1, v1), Vector2.ZERO)
			_vert(st, ring_pos[i00], ring_nrm[i00], Vector2(u0, v0), Vector2.ZERO)
			_vert(st, ring_pos[i11], ring_nrm[i11], Vector2(u1, v1), Vector2.ZERO)
			_vert(st, ring_pos[i01], ring_nrm[i01], Vector2(u0, v1), Vector2.ZERO)
	return st.commit()


# =====================================================================================
# Per-frame update
# =====================================================================================

func _process(delta: float) -> void:
	if not _built:
		return
	_time += delta
	_update_hover()
	_update_pending_flashes(delta)
	_update_regions(delta)
	_update_routes(delta)
	_update_labels(delta)
	_update_camera(delta)


func _update_regions(delta: float) -> void:
	var k: float = 1.0 - exp(-delta * SMOOTH_RATE)
	var kh: float = 1.0 - exp(-delta * HOVER_RATE)
	if delta <= 0.0:
		k = 1.0
		kh = 1.0
	for rid in _views:
		var rv: RegionView = _views[rid]
		rv.health = lerpf(rv.health, rv.health_goal, k)
		rv.pollution = lerpf(rv.pollution, rv.pollution_goal, k)
		rv.coral = lerpf(rv.coral, rv.coral_goal, k)
		rv.grass = lerpf(rv.grass, rv.grass_goal, k)
		rv.crisis = lerpf(rv.crisis, rv.crisis_goal, k)
		rv.protection = lerpf(rv.protection, rv.protection_goal, k)
		var hover_goal: float = 1.0 if rv.id == _hovered else 0.0
		# Selection marks (walls, rim, rings) fade out in menu mode, like the outline does.
		var sel_goal: float = 1.0 if (rv.id == _selected and not _menu_mode) else 0.0
		rv.highlight = lerpf(rv.highlight, hover_goal, kh)
		rv.selected = lerpf(rv.selected, sel_goal, kh)
		rv.flash = maxf(rv.flash - delta * 1.3, 0.0)
		rv.pulse = maxf(rv.pulse - delta / 1.5, 0.0)
		var vis: float = smoothstep(0.28, 0.82, rv.health)  # same remap as vis_health() in sea.gdshader
		rv.wave_phase += delta * lerpf(0.3, 1.0, vis)
		var mat: ShaderMaterial = rv.mat
		mat.set_shader_parameter("health", rv.health)
		mat.set_shader_parameter("pollution", rv.pollution)
		mat.set_shader_parameter("coral", rv.coral)
		mat.set_shader_parameter("seagrass", rv.grass)
		mat.set_shader_parameter("highlight", rv.highlight)
		mat.set_shader_parameter("selected", rv.selected)
		mat.set_shader_parameter("flash", rv.flash)
		mat.set_shader_parameter("pulse", rv.pulse)
		mat.set_shader_parameter("wave_phase", rv.wave_phase)
		var mark: float = maxf(rv.selected, rv.highlight * 0.6) * _label_alpha
		rv.outline_mi.visible = mark > 0.01
		if rv.outline_mi.visible:
			rv.outline_mat.set_shader_parameter("intensity", mark * 2.4)
			rv.outline_mat.set_shader_parameter("color", UITheme.TEXT.lerp(UITheme.AMBER, rv.selected))
			rv.outline_mat.set_shader_parameter("phase", fposmod(_time * 0.35, 100.0))


func _update_routes(delta: float) -> void:
	var k: float = 1.0 - exp(-delta * SMOOTH_RATE)
	var kd: float = 1.0 - exp(-delta * 0.8)
	if delta <= 0.0:
		k = 1.0
		kd = 1.0
	var current_color: Color = UITheme.TEXT_DIM.lerp(UITheme.HEALTHY, 0.3)
	for item in _routes:
		var rt: RouteView = item
		var ra: RegionView = _views[rt.a]
		var rb: RegionView = _views[rt.b]
		var max_crisis: float = maxf(ra.crisis, rb.crisis)
		var carry: float = clampf((max_crisis - 42.0) / 22.0, 0.0, 1.0)
		var protect: float = (ra.protection + rb.protection) * 0.5
		var calm: float = maxf(clampf((46.0 - max_crisis) / 14.0, 0.0, 1.0), clampf((protect - 30.0) / 25.0, 0.0, 1.0) * (1.0 - carry))
		rt.danger = lerpf(rt.danger, carry, k)
		rt.calm = lerpf(rt.calm, calm, k)
		# Packets flow from the sicker end toward the healthier one (the way crisis spreads).
		var want_dir: float = 1.0 if ra.crisis >= rb.crisis else -1.0
		rt.dir = lerpf(rt.dir, want_dir, kd)
		var speed: float = 0.32 if rt.kind == "current" else 0.45
		rt.phase = fposmod(rt.phase + delta * speed * (0.6 + rt.danger * 0.8) * rt.dir, 100.0)
		rt.flash = maxf(rt.flash - delta * 1.2, 0.0)
		if rt.burst >= 0.0:
			rt.burst += delta / BURST_TIME * rt.burst_dir
			if rt.burst > 1.0 or rt.burst < 0.0:
				rt.burst = -1.0
		var base: Color = current_color if rt.kind == "current" else UITheme.AMBER
		var mat: ShaderMaterial = rt.mat
		mat.set_shader_parameter("color", base.lerp(UITheme.HEALTHY, rt.calm))
		mat.set_shader_parameter("danger", rt.danger)
		mat.set_shader_parameter("phase", rt.phase)
		mat.set_shader_parameter("flash", rt.flash)
		mat.set_shader_parameter("burst", rt.burst)
		mat.set_shader_parameter("burst_dir", rt.burst_dir)


func _update_pending_flashes(delta: float) -> void:
	var i: int = _pending_flashes.size() - 1
	while i >= 0:
		var item: Array = _pending_flashes[i]
		var left: float = float(item[0]) - delta
		if left <= 0.0:
			var region_id: String = str(item[1])
			if _views.has(region_id):
				var rv: RegionView = _views[region_id]
				rv.flash = 1.0
			_pending_flashes.remove_at(i)
		else:
			item[0] = left
		i -= 1


func _update_labels(delta: float) -> void:
	var goal: float = 0.0 if _menu_mode else 1.0
	if delta > 0.0:
		_label_alpha = move_toward(_label_alpha, goal, delta * 1.8)
	var vis: bool = _label_alpha > 0.01
	var outline := Color(UITheme.BG.r, UITheme.BG.g, UITheme.BG.b, 0.88 * _label_alpha)
	for rid in _views:
		var rv: RegionView = _views[rid]
		if rv.name_label == null or rv.status_label == null:
			continue
		rv.name_label.visible = vis
		rv.status_label.visible = vis
		if not vis:
			continue
		# Selected names go bright white (the amber marquee and rim already mark selection;
		# amber text would sink into the amber hero beacon and marquee).
		var c: Color = UITheme.TEXT.lerp(Color(1.0, 1.0, 1.0), maxf(rv.highlight, rv.selected))
		c.a = _label_alpha
		rv.name_label.modulate = c
		rv.name_label.outline_modulate = outline
		var sc: Color = _status_color(rv.status)
		sc.a = _label_alpha
		rv.status_label.modulate = sc
		rv.status_label.outline_modulate = outline

	# The hero label fades out behind the end screen (it would poke out of the end panel).
	if _hero_label != null:
		var hg: float = 0.0 if (_menu_mode and _end_open) else 1.0
		if delta > 0.0:
			_hero_alpha = move_toward(_hero_alpha, hg, delta * 1.8)
		else:
			_hero_alpha = hg
		_hero_label.visible = _hero_alpha > 0.01
		var hc: Color = UITheme.AMBER
		hc.a = _hero_alpha
		_hero_label.modulate = hc
		_hero_label.outline_modulate = Color(UITheme.BG.r, UITheme.BG.g, UITheme.BG.b, 0.88 * _hero_alpha)


func _update_camera(delta: float) -> void:
	if camera == null or not camera.is_inside_tree():
		return
	var goal_target: Vector3 = MENU_TARGET if _menu_mode else GAME_TARGET
	var goal_dist: float = MENU_DIST if _menu_mode else GAME_DIST
	var goal_pitch: float = MENU_PITCH if _menu_mode else GAME_PITCH
	if _snap_camera or delta <= 0.0:
		_cam_target = goal_target
		_cam_dist = goal_dist
		_cam_pitch = goal_pitch
		_snap_camera = false
	else:
		var k: float = 1.0 - exp(-delta * 1.5)
		_cam_target = _cam_target.lerp(goal_target, k)
		_cam_dist = lerpf(_cam_dist, goal_dist, k)
		_cam_pitch = lerpf(_cam_pitch, goal_pitch, k)

	var t: float = _time
	var drift := Vector3.ZERO
	var yaw: float = 0.0
	if _menu_mode:
		drift = Vector3(sin(t * 0.045) * 1.8, 0.0, sin(t * 0.032) * 0.8)
		yaw = sin(t * 0.027) * 5.0
	else:
		drift = Vector3(sin(t * 0.11) * 0.22, 0.0, cos(t * 0.083) * 0.16)
		yaw = sin(t * 0.07) * 0.45

	# Mouse parallax (only while the pointer is inside the window).
	var vp := get_viewport()
	var want := Vector2.ZERO
	if vp != null:
		var rect: Rect2 = vp.get_visible_rect()
		var mp: Vector2 = vp.get_mouse_position()
		if rect.size.x > 1.0 and rect.size.y > 1.0 and rect.has_point(mp):
			want = Vector2(mp.x / rect.size.x * 2.0 - 1.0, mp.y / rect.size.y * 2.0 - 1.0)
	if delta > 0.0:
		_parallax = _parallax.lerp(want, 1.0 - exp(-delta * 2.5))
	var target: Vector3 = _cam_target + drift + Vector3(_parallax.x * 0.45, 0.0, _parallax.y * 0.3)
	yaw += _parallax.x * 0.6

	var yaw_r: float = deg_to_rad(yaw)
	var pitch_r: float = deg_to_rad(_cam_pitch)
	var back := Vector3(sin(yaw_r) * cos(pitch_r), sin(pitch_r), cos(yaw_r) * cos(pitch_r))
	var pos: Vector3 = target + back * _cam_dist
	if _shake > 0.0 and _shake_peak > 0.0:
		_shake = maxf(_shake - delta * _shake_peak / SHAKE_TIME, 0.0)
		var amp: float = _shake * SHAKE_UNITS
		var jitter := Vector3(sin(t * 63.0) * cos(t * 17.0), sin(t * 47.0) * 0.5, cos(t * 53.0) * sin(t * 29.0)) * amp
		pos += jitter
		target += jitter * 0.6
	camera.look_at_from_position(pos, target, Vector3.UP)


# =====================================================================================
# Picking (no physics): camera ray -> map plane -> point in region polygon
# =====================================================================================

func _input(event: InputEvent) -> void:
	# Every motion first lands here; if the GUI consumes it, _unhandled_input never sees it
	# and the pointer is treated as being over a panel (hover cleared).
	if event is InputEventMouseMotion:
		_motion_pending = true
		_motion_reached_map = false


func _unhandled_input(event: InputEvent) -> void:
	if not _built:
		return
	var motion := event as InputEventMouseMotion
	if motion != null:
		_motion_reached_map = true
		_mouse_pos = motion.position
		return
	var button := event as InputEventMouseButton
	if button == null or not button.pressed:
		return
	if _menu_mode or GameState.menu_paused or not GameState.running:
		return
	if button.button_index == MOUSE_BUTTON_LEFT:
		_mouse_pos = button.position
		_mouse_on_map = true
		EventBus.region_selected.emit(_pick(button.position))
		get_viewport().set_input_as_handled()
	elif button.button_index == MOUSE_BUTTON_RIGHT:
		EventBus.region_selected.emit("")
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT:
		_mouse_on_map = false


func _update_hover() -> void:
	if _motion_pending:
		_motion_pending = false
		_mouse_on_map = _motion_reached_map
	if _menu_mode or GameState.menu_paused or not _mouse_on_map:
		_set_hover("")
		return
	# Re-picked every frame so the hover stays correct while the camera drifts.
	_set_hover(_pick(_mouse_pos))


func _set_hover(region_id: String) -> void:
	if region_id == _hovered:
		return
	_hovered = region_id
	EventBus.region_hovered.emit(region_id)


## Region id under a screen position, "" for land, empty sea or a ray that misses the plane.
## Region labels are drawn on top of everything, so a click on a label picks its region
## (tiny regions such as Marmara are mostly covered by their own label).
func _pick(screen_pos: Vector2) -> String:
	if camera == null or not camera.is_inside_tree():
		return ""
	var by_label: String = _pick_label(screen_pos)
	if by_label != "":
		return by_label
	var origin: Vector3 = camera.project_ray_origin(screen_pos)
	var direction: Vector3 = camera.project_ray_normal(screen_pos)
	var hit: Variant = Plane(Vector3.UP, SEA_Y).intersects_ray(origin, direction)
	if hit == null:
		return ""
	var p: Vector3 = hit
	var point := Vector2(p.x, p.z)
	var found: String = RegionData.region_at(point)
	if found != "":
		return found
	# Render-only extensions (REGION_EXTENSIONS) pick like the rest of their region.
	for rid in _views:
		var rv: RegionView = _views[rid]
		if rv.extended and Geometry2D.is_point_in_polygon(point, rv.poly):
			return rv.id
	return ""


## Region whose name/status label covers the screen position ("" if none or labels hidden).
## Labels are camera-facing billboards: name text above the label position, status below.
func _pick_label(screen_pos: Vector2) -> String:
	if _label_alpha < 0.5:
		return ""
	var bx: Vector3 = camera.global_transform.basis.x
	var by: Vector3 = camera.global_transform.basis.y
	var pad: float = LABEL_PICK_PAD * LABEL_PIXEL
	var best: String = ""
	var best_d: float = INF
	for rid in _views:
		var rv: RegionView = _views[rid]
		if rv.name_label == null or not rv.name_label.visible:
			continue
		var base: Vector3 = rv.name_label.global_position
		var name_rect: Rect2 = _billboard_rect(base, bx * (rv.name_size.x * 0.5 + pad), by * (rv.name_size.y + pad))
		var stat_rect: Rect2 = _billboard_rect(base, bx * (rv.status_size.x * 0.5 + pad), -by * (rv.status_size.y + pad))
		var hit_rect: Rect2
		if name_rect.has_point(screen_pos):
			hit_rect = name_rect
		elif stat_rect.has_point(screen_pos):
			hit_rect = stat_rect
		else:
			continue
		var d: float = hit_rect.get_center().distance_squared_to(screen_pos)
		if d < best_d:
			best_d = d
			best = rv.id
	return best


## Screen rect of a billboard quad spanning base +- half_x and base .. base + up.
func _billboard_rect(base: Vector3, half_x: Vector3, up: Vector3) -> Rect2:
	var r := Rect2(camera.unproject_position(base - half_x), Vector2.ZERO)
	r = r.expand(camera.unproject_position(base + half_x))
	r = r.expand(camera.unproject_position(base - half_x + up))
	r = r.expand(camera.unproject_position(base + half_x + up))
	return r


# =====================================================================================
# EventBus handlers
# =====================================================================================

func _apply_region_data(region_id: String, data: Dictionary, snap: bool) -> void:
	if not _views.has(region_id):
		return
	var rv: RegionView = _views[region_id]
	rv.health_goal = clampf(float(data.get("health", 50.0)) / 100.0, 0.0, 1.0)
	rv.pollution_goal = clampf(float(data.get("pollution", 50.0)) / 100.0, 0.0, 1.0)
	rv.coral_goal = clampf(float(data.get("coral_health", 50.0)) / 100.0, 0.0, 1.0)
	rv.grass_goal = clampf(float(data.get("seagrass", 50.0)) / 100.0, 0.0, 1.0)
	rv.crisis_goal = clampf(float(data.get("crisis", 50.0)), 0.0, 100.0)
	rv.protection_goal = clampf(float(data.get("protection", 0.0)), 0.0, 100.0)
	if snap:
		rv.health = rv.health_goal
		rv.pollution = rv.pollution_goal
		rv.coral = rv.coral_goal
		rv.grass = rv.grass_goal
		rv.crisis = rv.crisis_goal
		rv.protection = rv.protection_goal
	var status: String = str(data.get("status", "stressed"))
	if status != rv.status:
		rv.status = status
		_refresh_status_label(rv)


func _refresh_status_label(rv: RegionView) -> void:
	if rv.status_label == null or rv.status == "":
		return
	rv.status_label.text = I18n.t("hud.status." + rv.status)
	_measure_labels(rv)


func _status_color(status: String) -> Color:
	match status:
		"healthy":
			return UITheme.HEALTHY
		"stressed":
			return UITheme.WARNING
		"critical":
			return UITheme.CRISIS.lerp(UITheme.WARNING, 0.35)
		"collapsed":
			return UITheme.CRISIS
	return UITheme.TEXT_DIM


func _refresh_labels() -> void:
	for rid in _views:
		var rv: RegionView = _views[rid]
		if rv.name_label != null:
			rv.name_label.text = I18n.t(RegionData.name_key_of(rv.id))
		_refresh_status_label(rv)
		_measure_labels(rv)
	if _hero_label != null:
		_hero_label.text = I18n.t("map.hero_label")


func _on_region_changed(region_id: String, data: Dictionary) -> void:
	_apply_region_data(region_id, data, false)


func _on_spread_happened(from_id: String, to_id: String) -> void:
	var found: bool = false
	for item in _routes:
		var rt: RouteView = item
		if rt.a == from_id and rt.b == to_id:
			rt.burst = 0.0
			rt.burst_dir = 1.0
		elif rt.a == to_id and rt.b == from_id:
			rt.burst = 1.0
			rt.burst_dir = -1.0
		else:
			continue
		rt.flash = 1.0
		found = true
	if _views.has(from_id):
		var src: RegionView = _views[from_id]
		src.flash = maxf(src.flash, 0.35)
	if found:
		_pending_flashes.append([BURST_TIME * 0.92, to_id])
	elif _views.has(to_id):
		var dst: RegionView = _views[to_id]
		dst.flash = 1.0
	if to_id == RegionData.HERO_ID:
		shake(0.35)
	else:
		shake(0.18)


func _on_evolution_happened(_evo_id: String) -> void:
	shake(0.85)


func _on_toast(_text_key: String, _args: Dictionary, severity: int) -> void:
	if severity >= 3:
		shake(0.6)


func _on_action_performed(action_id: String, region_id: String) -> void:
	if not _views.has(region_id):
		return
	var rv: RegionView = _views[region_id]
	rv.pulse = 1.0
	var col: Color = UITheme.HEALTHY
	if action_id == "patrol":
		col = UITheme.AMBER
	elif action_id == "campaign":
		col = UITheme.WARNING.lerp(UITheme.TEXT, 0.5)
	rv.mat.set_shader_parameter("pulse_color", col)


func _on_region_selected(region_id: String) -> void:
	_selected = region_id if _views.has(region_id) else ""


## Deselects through the bus so GameState.selected_region and the HUD clear as well.
func _clear_selection() -> void:
	if _selected != "" or GameState.selected_region != "":
		EventBus.region_selected.emit("")


func _on_language_changed(_lang: String) -> void:
	_refresh_labels()


func _on_game_started() -> void:
	_end_open = false
	_pending_flashes.clear()
	for item in _routes:
		var rt: RouteView = item
		rt.burst = -1.0
		rt.flash = 0.0
	# Every game starts with nothing selected (--select=id is applied after game_started).
	_clear_selection()


func _on_game_over(_won: bool, _reason: String, _stats: Dictionary) -> void:
	_end_open = true
