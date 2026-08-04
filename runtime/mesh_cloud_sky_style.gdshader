shader_type spatial;
// Sky 风格云（吸收 Unity SkyClouds Mobile 无 Tess 思路）：
// 造型网格 + Noise/Voronoi 顶点位移 + 透明软边 + 透光。
// 不做 GPU Tessellation，面向 Mobile / VR。
render_mode blend_mix, depth_draw_opaque, cull_back, specular_disabled;

group_uniforms Appearance;
/** 云主色（对应 Unity Base Color）。 */
uniform vec4 base_color : source_color = vec4(1.0, 1.0, 1.0, 0.92);
/** 底面/背光固有色倾向。 */
uniform vec4 underside_color : source_color = vec4(0.78, 0.82, 0.95, 1.0);
/** 自发光底色（对应 Emmissive Color）。 */
uniform vec4 emissive_color : source_color = vec4(0.55, 0.63, 0.73, 0.0);
/** 噪声染色强度：越大表面越受噪声色调制。 */
uniform float noise_color_strength : hint_range(0.0, 1.0) = 0.55;
/** 3D 噪声与 Voronoi 染色的混合。1=更偏 Voronoi。 */
uniform float noise_color_mix : hint_range(0.0, 1.0) = 0.7;
/** 自发光受噪声影响比例。 */
uniform float emissive_noise : hint_range(0.0, 1.0) = 0.2;
/** 固有色整体提亮。 */
uniform float brightness : hint_range(0.6, 1.6) = 1.05;

group_uniforms SoftEdge;
/** 轮廓软边强度（Fresnel 侵蚀 Alpha）。越大边缘越虚。 */
uniform float soft_edge : hint_range(0.0, 2.0) = 1.15;
/** 软边幂次；越大越贴外轮廓。 */
uniform float soft_edge_power : hint_range(0.5, 8.0) = 2.2;
/** 噪声对 Alpha 的侵蚀（对应毛边破洞感）。 */
uniform float edge_erosion : hint_range(0.0, 1.0) = 0.35;
/** 是否启用场景深度软相交（成本较高，Quest 建议关）。 */
uniform bool depth_fade_enabled = false;
/** 与场景几何相交处的淡出距离（世界/视距近似）。 */
uniform float depth_fade_distance : hint_range(0.05, 4.0) = 0.4;

group_uniforms Lighting;
/** 漫反射提亮。 */
uniform float lit_boost : hint_range(0.3, 3.0) = 1.35;
/** 光照包裹（棉花糖柔影）。 */
uniform float light_wrap : hint_range(0.0, 1.0) = 0.62;
/** 场景环境光权重。0=关，1=默认，>1 加强。 */
uniform float ambient_strength : hint_range(0.0, 3.0) = 1.15;
/** 透光颜色（对应 Translucency Color）。 */
uniform vec4 translucency_color : source_color = vec4(1.0, 0.96, 0.9, 1.0);
/** 透光强度（背光穿透感）。 */
uniform float translucency_strength : hint_range(0.0, 3.0) = 0.85;
/** 银边/边缘光强度。 */
uniform float rim_strength : hint_range(0.0, 2.0) = 0.4;
/** 银边锐度。 */
uniform float rim_power : hint_range(0.5, 8.0) = 3.0;

group_uniforms ShapeNoise;
/** 顶点位移幅度（相对局部尺寸）。 */
uniform float noise_amp : hint_range(0.0, 0.6) = 0.22;
/** 3D 噪声空间频率。 */
uniform float noise_scale : hint_range(0.2, 8.0) = 2.4;
/** 3D 噪声位移权重。 */
uniform float noise_strength : hint_range(0.0, 1.0) = 0.35;
/** Voronoi 空间频率。 */
uniform float voronoi_scale : hint_range(0.2, 8.0) = 1.6;
/** Voronoi 位移权重。 */
uniform float voronoi_strength : hint_range(0.0, 1.0) = 0.65;
/** 噪声动画速度。 */
uniform float noise_speed : hint_range(0.0, 2.0) = 0.18;
/** Voronoi 动画速度。 */
uniform float voronoi_speed : hint_range(0.0, 2.0) = 0.06;
/** 风向（世界空间倾向，会变换到局部）。 */
uniform vec3 wind_direction = vec3(-1.0, -0.25, -0.3);
/** 风速倍率。 */
uniform float wind_speed : hint_range(0.0, 3.0) = 1.0;
/** 额外时间偏移。 */
uniform float anim_time = 0.0;

uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

instance uniform vec3 noise_offset = vec3(0.0);

varying float v_height_bias;
varying float v_noise_color;
varying float v_voronoi_color;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 33.33);
	return fract((p.x + p.y) * p.z);
}

vec3 hash33(vec3 p) {
	p = vec3(
			hash13(p),
			hash13(p + vec3(17.1, 9.2, 3.4)),
			hash13(p + vec3(5.7, 21.3, 11.8))
	);
	return p;
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
	float nxy0 = mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y);
	float nxy1 = mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y);
	return mix(nxy0, nxy1, f.z);
}

float fbm3(vec3 p) {
	float a = 0.55;
	float s = 0.0;
	for (int i = 0; i < 3; i++) {
		s += value_noise(p) * a;
		p = p * 2.02 + 17.3;
		a *= 0.5;
	}
	return s;
}

// 简化 3D Voronoi（取最近点距离），吸收 SkyClouds 的团块感。
float voronoi3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float md = 1.0;
	for (int z = -1; z <= 1; z++) {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec3 g = vec3(float(x), float(y), float(z));
				vec3 o = hash33(i + g);
				vec3 r = g + o - f;
				md = min(md, dot(r, r));
			}
		}
	}
	return clamp(1.0 - sqrt(md), 0.0, 1.0);
}

float voronoi_fbm(vec3 p) {
	float a = 0.55;
	float s = 0.0;
	for (int i = 0; i < 3; i++) {
		s += voronoi3(p) * a;
		p = p * 2.0 + 9.7;
		a *= 0.5;
	}
	return clamp(s, 0.0, 1.0);
}

void vertex() {
	vec3 nrm = normalize(NORMAL);
	float local_size = max(length(VERTEX), 0.05);
	vec3 unit_p = VERTEX / local_size;
	float t = TIME + anim_time;
	vec3 wind = normalize(wind_direction + vec3(0.0001));
	vec3 wind_drift = wind * (t * wind_speed);

	vec3 n_sample = unit_p * noise_scale + noise_offset
			+ wind_drift * noise_speed
			+ vec3(t * noise_speed * 0.15, t * noise_speed * 0.07, 0.0);
	vec3 v_sample = unit_p * voronoi_scale + noise_offset * 1.3
			+ wind_drift * voronoi_speed
			+ vec3(0.0, t * voronoi_speed * 0.2, t * voronoi_speed * 0.11);

	float n = fbm3(n_sample);
	float v = voronoi_fbm(v_sample);
	// SkyClouds：噪声与 Voronoi 合成后沿法线位移。
	float field = clamp(n * noise_strength + v * voronoi_strength, 0.0, 1.0);
	float d = field * 2.0 - 1.0;
	vec3 displace_n = normalize(nrm * 0.9 + wind * 0.15 + vec3(0.0, 0.12, 0.0));
	VERTEX += displace_n * d * noise_amp * local_size;

	v_height_bias = clamp(nrm.y * 0.5 + 0.5, 0.0, 1.0);
	v_noise_color = n;
	v_voronoi_color = v;
}

void fragment() {
	float n_col = mix(v_noise_color, v_voronoi_color, noise_color_mix);
	float hb = mix(0.35, 1.0, v_height_bias);
	vec3 col = mix(underside_color.rgb, base_color.rgb, hb);
	// 噪声染色：亮部略提、暗部略压。
	vec3 noise_tint = mix(vec3(1.0 - noise_color_strength), vec3(n_col), noise_color_strength);
	col *= mix(vec3(1.0), noise_tint, 0.85);
	col *= brightness;

	ALBEDO = col;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;

	IRRADIANCE = vec4(vec3(0.0), 1.0 - ambient_strength);

	float ndv = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	float fres = pow(1.0 - ndv, soft_edge_power);
	float rim = pow(1.0 - ndv, rim_power) * rim_strength;

	// Alpha：基础透明度 × 软边 × 噪声侵蚀。
	float alpha = base_color.a;
	alpha *= 1.0 - fres * soft_edge * 0.65;
	alpha *= mix(1.0, smoothstep(0.15, 0.75, n_col), edge_erosion);
	alpha = clamp(alpha, 0.0, 1.0);

	if (depth_fade_enabled) {
		float scene_depth = texture(depth_texture, SCREEN_UV).x;
		vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, scene_depth);
		vec4 view_pos = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
		view_pos.xyz /= max(view_pos.w, 1e-5);
		float z_scene = -view_pos.z;
		float z_frag = -VERTEX.z;
		float df = clamp((z_scene - z_frag) / max(depth_fade_distance, 0.001), 0.0, 1.0);
		// 平滑阶梯，接近 Unity DepthFade 的柔和过渡。
		df = df * df * (3.0 - 2.0 * df);
		alpha *= df;
	}

	ALPHA = alpha;

	vec3 emis = emissive_color.rgb * mix(1.0, n_col, emissive_noise);
	emis *= mix(1.0, 1.0 - fres, 0.35);
	EMISSION = emis + rim * mix(col, vec3(1.0), 0.5);
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float diff = clamp(ndl * (1.0 - light_wrap) + light_wrap, 0.0, 1.0);
	float lit_term = mix(diff, pow(diff, 0.85), 0.55);
	DIFFUSE_LIGHT += lit_term * ATTENUATION * LIGHT_COLOR * lit_boost;

	// 透光：光线从背面穿过（对应 SkyClouds Translucency）。
	float v_dot_l = clamp(dot(normalize(-VIEW), normalize(-LIGHT)), 0.0, 1.0);
	float scatter = pow(v_dot_l, 2.0) * (1.0 - clamp(ndl, 0.0, 1.0));
	vec3 trans = translucency_color.rgb * translucency_strength
			* (0.35 + mix(v_noise_color, v_voronoi_color, noise_color_mix) * 0.65);
	DIFFUSE_LIGHT += scatter * ATTENUATION * LIGHT_COLOR * trans;
}
