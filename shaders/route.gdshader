// Route arc shader: glowing HDR tube for currents (smooth flowing bands) and shipping
// lanes (dashed), with light packets travelling along the arc, a red pulse when the route
// carries crisis, a flash and a bright comet ("burst") when the crisis spreads along it.
// Mesh contract (map_builder.gd): UV.x = 0..1 along the arc, UV.y = 0..1 around the tube.
shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never;

uniform vec3 color : source_color = vec3(0.098, 0.902, 0.757);
uniform vec3 hot_color : source_color = vec3(1.0, 0.231, 0.188);
uniform float kind = 0.0;          // 0 = current, 1 = shipping lane
uniform float danger = 0.0;        // 0..1 crisis carried along this route
uniform float phase = 0.0;         // packet scroll, integrated by the script (sign = direction)
uniform float length_units = 10.0; // arc length in world units
uniform float flash = 0.0;         // 0..1 spread flash
uniform float burst = -1.0;        // comet head position 0..1 along the arc, < 0 = none
uniform float burst_dir = 1.0;     // +1 comet travels toward UV.x = 1, -1 toward 0
uniform float intensity = 1.0;
uniform float closed = 0.0;        // 1 = closed loop (selection marquee): no end fade

void fragment() {
	float u = UV.x;
	float s = u * length_units;
	float ends = mix(smoothstep(0.0, 0.07, u) * smoothstep(1.0, 0.93, u), 1.0, closed);
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float core = 0.25 + 0.75 * pow(facing, 2.0);

	float body;
	float spacing;
	if (kind < 0.5) {
		float flow = 0.5 + 0.5 * sin(6.2831 * (s / 1.7 - phase * 1.4));
		body = 0.4 + 0.35 * flow;
		spacing = 3.4;
	} else {
		float dash = smoothstep(0.38, 0.46, fract(s / 0.6 - phase * 0.8)) * (1.0 - smoothstep(0.86, 0.94, fract(s / 0.6 - phase * 0.8)));
		body = 0.08 + 0.62 * dash;
		spacing = 2.3;
	}
	float k = fract(s / spacing - phase);
	float packet = pow(k, 16.0) * 3.2 + smoothstep(0.975, 1.0, k) * 2.2;

	float pulse = danger * (0.5 + 0.5 * sin(TIME * 6.0 - s * 1.1));
	vec3 col = mix(color, hot_color, smoothstep(0.0, 0.55, danger));
	float b = (body + packet) * intensity + pulse * 0.9;

	float comet = 0.0;
	if (burst >= 0.0) {
		float behind = (burst - u) * burst_dir * length_units;
		comet = exp(min(behind, 0.0) * 10.0) * exp(-max(behind, 0.0) * 1.4);
	}

	// Mixed (not additive) so a red route stays red over bright turquoise water; HDR colour
	// above 1.0 still feeds the glow.
	float a = clamp(b * core, 0.0, 1.0);
	vec3 c = col * (0.3 + b * 0.9);
	vec3 comet_col = mix(hot_color, vec3(1.0), 0.45) * 4.0;
	c = mix(c, comet_col, clamp(comet, 0.0, 1.0));
	a = max(a, clamp(comet, 0.0, 1.0));
	c += mix(col, vec3(1.0), 0.3) * flash * 1.8;
	a = max(a, flash * core * 0.9);
	ALBEDO = c;
	ALPHA = clamp(a * ends, 0.0, 1.0);
}
