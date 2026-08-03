shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, unshaded, fog_disabled;

uniform vec4 color_a : source_color = vec4(0.15, 1.0, 0.55, 1.0);
uniform vec4 color_b : source_color = vec4(0.2, 0.85, 1.0, 1.0);
uniform vec4 color_c : source_color = vec4(0.8, 0.3, 1.0, 1.0);
uniform float fresnel_power : hint_range(0.1, 10.0) = 3.5;
uniform float brightness : hint_range(0.0, 1.0) = 0.6;
uniform float rim_glow : hint_range(0.0, 1.5) = 0.35;
uniform float color_shift_speed : hint_range(0.0, 2.0) = 0.25;
uniform float core_darkness : hint_range(0.0, 1.0) = 0.55;

uniform float spin_speed : hint_range(-4.0, 4.0) = 0.6;
uniform float wobble_speed : hint_range(0.0, 8.0) = 1.8;
uniform float wobble_strength : hint_range(0.0, 0.4) = 0.04;
uniform float wobble_scale : hint_range(0.1, 8.0) = 2.2;
uniform float lobe_count : hint_range(0.5, 8.0) = 2.6;
uniform float lobe_speed : hint_range(0.0, 6.0) = 0.9;
uniform float lobe_strength : hint_range(0.0, 0.4) = 0.05;
uniform float breath_speed : hint_range(0.0, 6.0) = 1.1;
uniform float breath_strength : hint_range(0.0, 0.3) = 0.04;

uniform float break_amount : hint_range(0.0, 1.0) = 0.0;
uniform float splash_distance : hint_range(0.0, 3.0) = 1.1;
uniform float splash_rise : hint_range(0.0, 2.0) = 0.35;
uniform float splash_scale : hint_range(1.0, 24.0) = 7.0;
uniform float splash_flash : hint_range(0.0, 3.0) = 1.0;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float background_clamp : hint_range(0.0, 4.0) = 1.0;

const float FULL_TURN = 6.2831853;

varying float shard_seed;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

mat3 spin_around_y(float angle) {
	float s = sin(angle);
	float c = cos(angle);
	return mat3(vec3(c, 0.0, -s), vec3(0.0, 1.0, 0.0), vec3(s, 0.0, c));
}

void vertex() {
	vec3 sphere_normal = normalize(VERTEX);
	shard_seed = hash13(floor(sphere_normal * splash_scale));

	mat3 spin = spin_around_y(TIME * spin_speed);
	VERTEX = spin * VERTEX;
	NORMAL = spin * sphere_normal;

	float wave = sin(VERTEX.y * wobble_scale + TIME * wobble_speed)
		+ sin(VERTEX.x * wobble_scale * 1.3 - TIME * wobble_speed * 0.8)
		+ sin(VERTEX.z * wobble_scale * 0.7 + TIME * wobble_speed * 1.25);
	wave /= 3.0;

	float lobes = sin(NORMAL.x * lobe_count + TIME * lobe_speed)
		* sin(NORMAL.y * lobe_count + TIME * lobe_speed * 0.7)
		* sin(NORMAL.z * lobe_count + TIME * lobe_speed * 1.3);

	float breath = 1.0 + sin(TIME * breath_speed) * breath_strength;

	VERTEX = VERTEX * breath + NORMAL * (wave * wobble_strength + lobes * lobe_strength);

	VERTEX += NORMAL * break_amount * splash_distance * (0.35 + shard_seed);
	VERTEX.y += break_amount * break_amount * splash_rise;
}

void fragment() {
	if (shard_seed < break_amount) {
		discard;
	}

	vec3 world_normal = mat3(INV_VIEW_MATRIX) * NORMAL;
	float sweep = (world_normal.y * 0.5 + world_normal.x * 0.25 + TIME * color_shift_speed) * FULL_TURN;

	float weight_a = 0.5 + 0.5 * sin(sweep);
	float weight_b = 0.5 + 0.5 * sin(sweep + FULL_TURN / 3.0);
	float weight_c = 0.5 + 0.5 * sin(sweep + FULL_TURN * 2.0 / 3.0);

	vec3 tint = color_a.rgb * weight_a + color_b.rgb * weight_b + color_c.rgb * weight_c;
	tint /= weight_a + weight_b + weight_c;

	float fresnel = pow(1.0 - dot(NORMAL, VIEW), fresnel_power);
	float tear = 1.0 - smoothstep(break_amount, break_amount + 0.2, shard_seed);

	vec3 bubble_color = tint * (brightness + fresnel * rim_glow + tear * break_amount * splash_flash);
	float coverage = mix(1.0 - core_darkness, 1.0, fresnel) * (1.0 - break_amount * 0.5);
	vec3 behind = min(texture(screen_texture, SCREEN_UV).rgb, vec3(background_clamp));

	ALBEDO = mix(behind, bubble_color, coverage);
	ALPHA = 1.0;
}
