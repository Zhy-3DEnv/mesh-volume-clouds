shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert_wrap, specular_disabled, fog_disabled;

group_uniforms Appearance;
uniform vec4 albedo : source_color = vec4(0.97, 0.98, 1.0, 0.92);
uniform vec4 underside_color : source_color = vec4(0.62, 0.68, 0.78, 1.0);
uniform float density : hint_range(0.2, 3.0) = 1.35;
uniform float soft_edge : hint_range(0.4, 4.0) = 1.65;
uniform float edge_erosion : hint_range(0.0, 1.5) = 0.85;
uniform float fluff : hint_range(0.0, 1.5) = 0.9;
uniform float center_fill : hint_range(0.0, 1.0) = 0.72;

group_uniforms Lighting;
uniform float light_wrap : hint_range(0.0, 1.0) = 0.78;
uniform float translucency : hint_range(0.0, 1.5) = 0.85;
uniform float silver_lining : hint_range(0.0, 2.0) = 0.9;
uniform float ambient_boost : hint_range(0.0, 1.5) = 0.62;
uniform vec3 sun_direction = vec3(0.35, 0.65, -0.5);

group_uniforms Animation;
uniform float displacement_amp : hint_range(0.0, 1.5) = 0.38;
uniform float displacement_scale : hint_range(0.2, 6.0) = 1.55;
uniform float displacement_speed : hint_range(0.0, 1.5) = 0.08;
uniform float secondary_amp : hint_range(0.0, 1.0) = 0.55;
uniform float detail_scale : hint_range(0.5, 12.0) = 3.2;

varying float v_macro;
varying float v_height_bias;
varying vec3 v_world_pos;
varying vec3 v_local_pos;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float value_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash13(i);
	float n100 = hash13(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash13(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash13(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash13(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash13(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash13(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash13(i + vec3(1.0, 1.0, 1.0));
	float nx00 = mix(n000, n100, f.x);
	float nx10 = mix(n010, n110, f.x);
	float nx01 = mix(n001, n101, f.x);
	float nx11 = mix(n011, n111, f.x);
	float nxy0 = mix(nx00, nx10, f.y);
	float nxy1 = mix(nx01, nx11, f.y);
	return mix(nxy0, nxy1, f.z);
}

float fbm(vec3 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 4; i++) {
		s += value_noise(p) * a;
		p = p * 2.07 + 19.7;
		a *= 0.5;
	}
	return s;
}

// Worley-ish cellular for billowy cloud cells.
float cellular(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float md = 1.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			for (int z = -1; z <= 1; z++) {
				vec3 g = vec3(float(x), float(y), float(z));
				vec3 o = vec3(hash13(i + g), hash13(i + g + 19.1), hash13(i + g + 47.2));
				vec3 r = g + o - f;
				md = min(md, dot(r, r));
			}
		}
	}
	return 1.0 - clamp(md * 1.7, 0.0, 1.0);
}

void vertex() {
	v_local_pos = VERTEX;
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	float n1 = fbm(VERTEX * displacement_scale + vec3(TIME * displacement_speed, 0.0, TIME * displacement_speed * 0.55));
	float n2 = fbm(VERTEX * (displacement_scale * 2.2) - vec3(TIME * displacement_speed * 0.7));
	float cell = cellular(VERTEX * (displacement_scale * 0.85) + vec3(TIME * displacement_speed * 0.2));
	float d = (n1 * (1.0 - secondary_amp) + n2 * secondary_amp) * 2.0 - 1.0;
	d = mix(d, d * 0.65 + (cell * 2.0 - 1.0) * 0.35, 0.55);

	// Prefer outward + slight upward puff so shapes feel cotton-like.
	vec3 displace_n = normalize(NORMAL * 0.85 + vec3(0.0, 0.4, 0.0));
	VERTEX += displace_n * d * displacement_amp;

	v_macro = clamp(n1 * 0.65 + cell * 0.35, 0.0, 1.0);
	v_height_bias = clamp(NORMAL.y * 0.5 + 0.5, 0.0, 1.0);
}

void fragment() {
	vec3 N = normalize(NORMAL);
	vec3 V = normalize(VIEW);
	vec3 L = normalize(sun_direction);

	float ndv = clamp(abs(dot(N, V)), 0.0, 1.0);
	// Soft silhouette: thick in the middle, wispy at grazing angles.
	float thickness = pow(ndv, soft_edge);
	thickness = mix(thickness, smoothstep(0.05, 0.95, thickness), 0.35);

	// World-space detail noise breaks the perfect sphere outline.
	vec3 wp = v_world_pos * 0.0015;
	float detail = fbm(wp * detail_scale + vec3(TIME * displacement_speed * 0.15));
	float detail2 = value_noise(wp * (detail_scale * 2.3) + v_local_pos);
	float macro = mix(v_macro, detail, 0.4);

	// Erode edges into ragged cloud scallops.
	float edge_mask = mix(1.0, mix(0.2, 1.05, detail * mix(0.45, 1.0, detail2)), edge_erosion);
	float fluff_mask = mix(1.0, mix(0.38, 1.2, macro), fluff);

	float body = mix(center_fill, 1.0, thickness);
	float a = albedo.a * density * body * edge_mask * fluff_mask;
	// Keep a soft core so clouds don't go hollow, but let edges dissolve.
	a = clamp(a, 0.0, 1.0);
	a = smoothstep(0.02, 0.92, a);
	ALPHA = a;

	// Top lit white / cooler shaded underside.
	vec3 base_col = mix(underside_color.rgb, albedo.rgb, mix(0.35, 1.0, v_height_bias));
	base_col = mix(base_col, albedo.rgb, macro * 0.25);

	float ndl = clamp(dot(N, L) * (1.0 - light_wrap) + light_wrap, 0.0, 1.0);
	float powder = 1.0 - exp(-thickness * 2.2);
	float backlit = pow(clamp(dot(N, -L), 0.0, 1.0), 1.15) * translucency * (0.35 + 0.65 * (1.0 - thickness));
	float rim = pow(1.0 - ndv, 2.0) * ndl * silver_lining;

	vec3 lit = base_col * (ambient_boost + ndl * powder * (1.1 - ambient_boost * 0.25));
	lit += base_col * backlit;
	lit += vec3(1.0, 0.98, 0.95) * rim * 0.85;
	// Slight warm sun face / cool shadow variation.
	lit = mix(lit * vec3(0.9, 0.93, 1.02), lit * vec3(1.03, 1.01, 0.98), ndl);

	ALBEDO = lit;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	EMISSION = lit * rim * 0.08;
}
