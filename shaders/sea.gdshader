// Sea region shader: one material per extruded region mesh (top water, glowing rim band, walls).
// Healthy water is bright bioluminescent turquoise with caustics, sparkles and gentle waves;
// sick water turns dark, oily and reddish with damped waves, debris and toxic veins.
// Mesh contract (map_builder.gd): UV.x = part (0 top, 1 rim, 2 wall), UV.y = shore 0..1 (top),
// across 0..1 (rim) or depth 0..1 (wall); UV2.x = wave weight, UV2.y = distance along the edge.
shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;

uniform float health : hint_range(0.0, 1.0) = 0.6;
uniform float pollution : hint_range(0.0, 1.0) = 0.4;
uniform float highlight : hint_range(0.0, 1.0) = 0.0;
uniform float selected : hint_range(0.0, 1.0) = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float pulse : hint_range(0.0, 1.0) = 0.0;
uniform float coral : hint_range(0.0, 1.0) = 0.6;
uniform float seagrass : hint_range(0.0, 1.0) = 0.6;
uniform float wave_phase = 0.0;
uniform float seed = 0.0;
uniform vec2 anchor = vec2(0.0, 0.0);
uniform vec3 healthy_color : source_color = vec3(0.098, 0.902, 0.757);
uniform vec3 crisis_color : source_color = vec3(1.0, 0.231, 0.188);
uniform vec3 warning_color : source_color = vec3(1.0, 0.784, 0.239);
uniform vec3 accent_color : source_color = vec3(0.91, 0.639, 0.239);
uniform vec3 pulse_color : source_color = vec3(0.098, 0.902, 0.757);

varying vec3 wpos;
varying float v_part;
varying float v_extra;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

// Remaps raw health so the typical 0.3..0.8 game range spans the whole visual range.
float vis_health() {
	return smoothstep(0.28, 0.78, health);
}

float wave_amp(float vh) {
	return mix(0.015, 0.09, vh);
}

float waves(vec2 p, float t, float amp) {
	return amp * (sin(p.x * 0.9 + t * 1.3) * 0.45
		+ sin(p.y * 1.3 - t * 1.05 + p.x * 0.35) * 0.35
		+ sin((p.x - p.y) * 2.1 + t * 1.9) * 0.2);
}

vec3 status_color(float vh) {
	vec3 low = mix(crisis_color, warning_color, clamp(vh * 2.0, 0.0, 1.0));
	return mix(low, healthy_color, clamp(vh * 2.0 - 1.0, 0.0, 1.0));
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_part = UV.x;
	v_extra = UV.y;
	float vh = vis_health();
	VERTEX.y += waves(wpos.xz, wave_phase, wave_amp(vh)) * UV2.x;
}

void fragment() {
	vec2 p = wpos.xz;
	float t = TIME;
	float vh = vis_health();
	float sick = 1.0 - vh;
	vec3 scol = status_color(vh);
	float r = length(p - anchor);

	// Selection: thin rings drifting outward from the anchor. Action pulse: one expanding ring.
	float sel_w = fract(r * 0.22 - t * 0.35);
	float sel_ring = smoothstep(0.0, 0.03, sel_w) * (1.0 - smoothstep(0.03, 0.16, sel_w)) * selected;
	float pulse_rad = (1.0 - pulse) * 10.0;
	float pulse_ring = exp(-abs(r - pulse_rad) * 2.5) * pulse;

	if (v_part < 0.5) {
		// ---------------- water surface ----------------
		float amp = wave_amp(vh);
		float e = 0.06;
		vec2 drift = vec2(t * 0.25, t * 0.18);
		float h0 = waves(p, wave_phase, amp);
		float hx = waves(p + vec2(e, 0.0), wave_phase, amp);
		float hz = waves(p + vec2(0.0, e), wave_phase, amp);
		float rip = mix(0.004, 0.018, vh);
		float n0 = fbm(p * 2.2 + drift);
		float nx = fbm((p + vec2(e, 0.0)) * 2.2 + drift);
		float nz = fbm((p + vec2(0.0, e)) * 2.2 + drift);
		vec3 nw = normalize(vec3(-((hx - h0) + (nx - n0) * rip) / e, 1.0, -((hz - h0) + (nz - n0) * rip) / e));
		NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);

		float sh = clamp(v_extra, 0.0, 1.0);
		float shallow = 1.0 - smoothstep(0.0, 0.42, sh);
		float deep = smoothstep(0.35, 1.0, sh);

		// healthy palette: luminous shallows, turquoise body, deep teal-blue centre
		vec3 h_shallow = healthy_color * 0.75 + vec3(0.02, 0.05, 0.05);
		vec3 h_mid = healthy_color * 0.24 + vec3(0.0, 0.012, 0.05);
		vec3 h_deep = vec3(0.004, 0.045, 0.1);
		vec3 water_h = mix(mix(h_mid, h_deep, deep), h_shallow, shallow);
		// sick palette: brown sludge on the coast, rust-red body, black-oil centre
		vec3 s_shallow = vec3(0.22, 0.085, 0.03);
		vec3 s_mid = crisis_color * 0.1 + vec3(0.035, 0.014, 0.01);
		vec3 s_deep = vec3(0.026, 0.009, 0.011);
		vec3 water_s = mix(mix(s_mid, s_deep, deep), s_shallow, shallow);
		vec3 water = mix(water_s, water_h, vh);

		// caustic lines (healthy), strongest in the shallows
		vec2 q = p * 1.05;
		float c1 = fbm(q + vec2(t * 0.11, -t * 0.07));
		float c2 = fbm(q * 1.7 + vec2(-t * 0.09, t * 0.12) + c1 * 1.6);
		float caustic = pow(1.0 - abs(c2 * 2.0 - 1.0), 14.0) * (0.4 + 0.6 * c1);
		float caust_mask = vh * vh * (0.3 + 0.7 * (1.0 - deep));

		// twinkling sparkles (healthy)
		vec2 sc = p * 2.6;
		vec2 cell = floor(sc);
		vec2 f = fract(sc) - 0.5;
		float hs = hash21(cell + seed);
		vec2 off = vec2(hash21(cell + 3.1), hash21(cell + 7.7)) - 0.5;
		float sd = length(f - off * 0.6);
		float tw = pow(max(sin(t * (1.5 + hs * 3.0) + hs * 60.0), 0.0), 12.0);
		float sparkle = step(0.55, hs) * smoothstep(0.13, 0.0, sd) * tw * vh;

		// oily film with faint iridescence (sick / polluted)
		float film = fbm(p * 0.55 + vec2(t * 0.02, t * 0.015));
		float slick = smoothstep(0.42, 0.6, film) * clamp(pollution * 0.9 + sick * 0.45 - 0.2, 0.0, 1.0);
		vec3 irid = 0.5 + 0.5 * cos(6.2831 * (film * 3.0 + vec3(0.0, 0.33, 0.67)));
		vec3 oil = irid * 0.045 + vec3(0.014, 0.007, 0.006);

		// toxic veins pulsing through sick water
		float vn = fbm(p * 0.7 - vec2(t * 0.03, -t * 0.01));
		float vein = pow(1.0 - abs(vn * 2.0 - 1.0), 22.0) * sick * sick;
		float throb = 0.55 + 0.45 * sin(t * 2.4 - r * 0.6);

		// drifting debris specks (pollution)
		vec2 dc = (p + vec2(t * 0.05, t * 0.035)) * 3.4;
		vec2 dcell = floor(dc);
		vec2 dfr = fract(dc) - 0.5;
		float dh = hash21(dcell + 11.0 + seed);
		vec2 doff = (vec2(hash21(dcell + 1.3), hash21(dcell + 5.1)) - 0.5) * 0.5;
		float debris = step(1.0 - pollution * 0.3, dh) * smoothstep(0.11, 0.03, length(dfr - doff));

		// seagrass glow (recovering meadows) and bleached coral dots, both in the shallows
		vec2 gc = p * 1.9;
		vec2 gcell = floor(gc);
		vec2 gf = fract(gc) - 0.5;
		vec2 goff = (vec2(hash21(gcell + 2.3), hash21(gcell + 9.4)) - 0.5) * 0.6;
		float gd = length(gf - goff);
		float g_on = step(1.0 - seagrass * 0.45, hash21(gcell + 23.0 + seed));
		float grass = g_on * smoothstep(0.15, 0.02, gd) * (0.55 + 0.45 * sin(t * 1.3 + hash21(gcell) * 30.0));
		float c_on = step(0.62 + coral * 0.38, hash21(gcell + 71.0 + seed));
		float bleach = c_on * smoothstep(0.1, 0.02, gd) * (1.0 - g_on);
		float near_coast = 1.0 - smoothstep(0.15, 0.6, sh);

		vec3 em = water * mix(0.6, 0.85, vh);
		em += healthy_color * caustic * caust_mask * 1.4;
		em += vec3(0.85, 1.0, 1.0) * sparkle * 4.0;
		em = mix(em, oil, slick * 0.85);
		em += crisis_color * vein * throb * 0.75;
		em += vec3(0.6, 0.55, 0.5) * debris * 0.55;
		em += vec3(0.3, 1.0, 0.55) * grass * near_coast * seagrass * 1.3;
		em += vec3(0.95, 0.93, 0.88) * bleach * near_coast * (1.0 - coral) * 1.1;
		// interaction feedback
		em = em * (1.0 + highlight * 0.55) + scol * highlight * 0.035;
		em += accent_color * (sel_ring * 1.1 + selected * 0.025);
		em += pulse_color * pulse_ring * 1.8;
		em = mix(em, mix(crisis_color, vec3(1.0), 0.3) * 1.8, flash * 0.6);

		ALBEDO = water * 0.12;
		EMISSION = em;
		ROUGHNESS = clamp(mix(0.5, 0.2, vh) - slick * 0.15, 0.05, 1.0);
		SPECULAR = mix(0.05, 0.3, vh);
		METALLIC = 0.0;
	} else if (v_part < 1.5) {
		// ---------------- glowing rim band ----------------
		float along = UV2.y;
		float run = 0.78 + 0.22 * sin(along * 2.2 - t * 2.4);
		float across = 1.0 - v_extra * 0.65;
		vec3 rim = scol * (1.0 + highlight * 1.6) * run * across;
		rim = mix(rim, accent_color * 2.6 * across, selected);
		rim += mix(crisis_color, vec3(1.0), 0.4) * flash * 2.4;
		rim += pulse_color * pulse * 1.5;
		ALBEDO = vec3(0.0);
		EMISSION = rim;
		ROUGHNESS = 1.0;
		SPECULAR = 0.0;
	} else {
		// ---------------- side walls ----------------
		float k = 1.0 - clamp(v_extra, 0.0, 1.0);
		float glow = 0.06 + 0.7 * pow(k, 4.0);
		vec3 wall = scol * glow * (1.0 + highlight * 0.9);
		wall = mix(wall, accent_color * glow * 1.4, selected * 0.85);
		wall += crisis_color * flash * pow(k, 2.0) * 1.2;
		ALBEDO = vec3(0.02);
		EMISSION = wall;
		ROUGHNESS = 0.9;
		SPECULAR = 0.1;
	}
}
