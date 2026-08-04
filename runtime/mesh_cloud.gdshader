shader_type spatial;
// 实体风格云：顶点柏林动画 + 场景光照 + 边缘光 + 受光面提亮。
// 不写 ALPHA，保持不透明管线。
render_mode depth_draw_opaque, cull_back, specular_disabled;

group_uniforms Appearance;
/** 云的顶面/亮部固有色。与 Underside Color 按高度混合，再经场景光照调制。 */
uniform vec4 albedo : source_color = vec4(1.0, 1.0, 1.0, 1.0);
/** 凹处/谷底固有色（不是场景投射阴影色）。由 Cavity Strength 控制混入强度。 */
uniform vec4 shadow_color : source_color = vec4(0.78, 0.8, 0.96, 1.0);
/** 云的底面/朝下固有色。与 Albedo 按法线朝上程度做垂直渐变。 */
uniform vec4 underside_color : source_color = vec4(0.82, 0.84, 0.97, 1.0);
/** 凹处染色强度。越大，谷底越偏向 Shadow Color。 */
uniform float cavity_strength : hint_range(0.0, 1.0) = 0.22;
/** 顶底色渐变权重。越大越偏向 Albedo（顶亮），越小越偏向 Underside Color（底暗）。 */
uniform float height_blend : hint_range(0.0, 1.0) = 0.55;
/** 固有色整体提亮倍率，不影响光照方向计算。 */
uniform float brightness : hint_range(0.8, 1.6) = 1.08;

group_uniforms Lighting;
/** 漫反射亮度倍数。>1 让迎光面更亮（自定义柔光，非标准兰伯特）。 */
uniform float lit_boost : hint_range(0.5, 3.0) = 1.65;
/** 光照包裹。越大背光侧越亮，阴影越软，更像棉花糖。 */
uniform float light_wrap : hint_range(0.0, 1.0) = 0.55;
/** 场景环境光（Environment Ambient / 天空 irradiance）权重。0=关闭，1=引擎默认，>1 加强。 */
uniform float ambient_strength : hint_range(0.0, 3.0) = 1.0;
/** Fresnel 边缘光（银边）颜色，以自发光方式叠加。 */
uniform vec4 rim_color : source_color = vec4(1.0, 0.98, 0.96, 1.0);
/** 边缘光强度。0 关闭轮廓提亮。 */
uniform float rim_strength : hint_range(0.0, 2.5) = 0.55;
/** 边缘光锐度。越大越贴外轮廓，越小过渡更宽。 */
uniform float rim_power : hint_range(0.5, 8.0) = 2.8;
/** 边缘光随朝上/受光倾向的偏置。越大银边越集中在亮部轮廓。 */
uniform float rim_lit_bias : hint_range(0.0, 1.0) = 0.35;
/** 位移后按噪声梯度扰动法线。关闭则沿用网格插值法线（通常更柔和好看）。 */
uniform bool soft_displace_normals = false;

group_uniforms ShapeNoise;
/** 顶点位移幅度（相对局部尺寸）。过大易出现硬折轮廓，需更密网格。 */
uniform float noise_amp : hint_range(0.0, 0.4) = 0.12;
/** 噪声空间频率。越大起伏越碎、越密。 */
uniform float noise_scale : hint_range(0.2, 4.0) = 1.4;
/** 噪声动画速度（沿时间漂移）。0 为静止形变。 */
uniform float noise_speed : hint_range(0.0, 1.5) = 0.35;
/** 第二层细节噪声混入比例。越大表面细节越多。 */
uniform float noise_detail : hint_range(0.0, 1.0) = 0.35;
/** 额外时间偏移（加在引擎 TIME 上）。一般保持 0，供脚本驱动相位。 */
uniform float anim_time = 0.0;

instance uniform vec3 noise_offset = vec3(0.0);

varying float v_height_bias;
varying float v_cavity_term;

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

float perlin_fbm(vec3 p) {
	float a = 0.55;
	float s = 0.0;
	for (int i = 0; i < 3; i++) {
		s += value_noise(p) * a;
		p = p * 2.02 + 17.3;
		a *= 0.5;
	}
	return s;
}

float displacement_field(vec3 sample_p) {
	float n1 = perlin_fbm(sample_p);
	float n2 = perlin_fbm(sample_p * 1.7 + vec3(4.2, 1.7, 9.1));
	return mix(n1, n2, noise_detail) * 2.0 - 1.0;
}

void vertex() {
	vec3 nrm = normalize(NORMAL);
	float local_size = max(length(VERTEX), 0.05);
	vec3 unit_p = VERTEX / local_size;
	float t = TIME + anim_time;
	vec3 sample_p = unit_p * noise_scale + noise_offset
			+ vec3(t * noise_speed, t * noise_speed * 0.37, t * noise_speed * 0.18);
	float d = displacement_field(sample_p);
	vec3 displace_n = normalize(nrm * 0.92 + vec3(0.0, 0.22, 0.0));
	VERTEX += displace_n * d * noise_amp * local_size;

	if (soft_displace_normals) {
		// 用噪声场有限差分平滑扰动法线（顶点插值，避免片元 dFdx 硬面）。
		float eps = 0.12;
		vec3 grad = vec3(
				displacement_field(sample_p + vec3(eps, 0.0, 0.0)) - d,
				displacement_field(sample_p + vec3(0.0, eps, 0.0)) - d,
				displacement_field(sample_p + vec3(0.0, 0.0, eps)) - d
		) / eps;
		vec3 grad_t = grad - nrm * dot(grad, nrm);
		NORMAL = normalize(nrm - grad_t * (noise_amp * 1.6));
	}

	v_height_bias = clamp(nrm.y * 0.5 + 0.5, 0.0, 1.0);
	v_cavity_term = clamp((1.0 - nrm.y) * 0.55 + max(-d, 0.0) * 0.25, 0.0, 1.0);
}

void fragment() {
	float hb = mix(1.0 - height_blend, 1.0, v_height_bias);
	vec3 col = mix(underside_color.rgb, albedo.rgb, hb);
	col = mix(col, mix(col, shadow_color.rgb, 0.7), v_cavity_term * cavity_strength);
	col *= brightness;

	ALBEDO = col;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;

	// 缩放场景环境光：mix(env, 0, 1-strength) = env * strength（strength>1 时 alpha 为负仍可加强）。
	IRRADIANCE = vec4(vec3(0.0), 1.0 - ambient_strength);

	// Fresnel 边缘光（轮廓提亮）。
	float ndv = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	float rim = pow(1.0 - ndv, rim_power) * rim_strength;
	// 略偏亮部：迎光轮廓更像银边。
	float facing_up = mix(1.0, mix(0.55, 1.25, v_height_bias), rim_lit_bias);
	EMISSION = rim_color.rgb * rim * facing_up;
}

void light() {
	// 柔和漫反射 + 受光面提亮；环境光由 IRRADIANCE × ambient_strength 控制。
	float ndl = dot(NORMAL, LIGHT);
	float diff = clamp(ndl * (1.0 - light_wrap) + light_wrap, 0.0, 1.0);
	// 迎光侧额外抬一点，让「收光」更亮。
	float lit_term = mix(diff, pow(diff, 0.85), 0.65);
	DIFFUSE_LIGHT += lit_term * ATTENUATION * LIGHT_COLOR * lit_boost;
}
