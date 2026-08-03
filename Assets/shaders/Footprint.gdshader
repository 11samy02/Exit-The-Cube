shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

// One print a cube left after walking through wet paint. Every print of the
// level is one instance of the same quad, its color and how much paint was left
// on the cube come in per instance, so the whole trail is a single draw call.
//
// The cube has no feet, so a print is what a cube leaves: a rounded square,
// pressed down harder in the middle and frayed along the edge
uniform float corner_roundness : hint_range(2.0, 12.0) = 3.4;
uniform float edge_fray : hint_range(0.0, 0.3) = 0.08;
uniform float softness : hint_range(0.001, 0.2) = 0.03;
uniform float emission_strength : hint_range(0.0, 4.0) = 0.7;
uniform float rim_boost : hint_range(0.0, 4.0) = 1.2;

varying vec3 print_color;
varying float print_paint;

float hash12(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float noise2(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);

	return mix(
		mix(hash12(cell), hash12(cell + vec2(1.0, 0.0)), f.x),
		mix(hash12(cell + vec2(0.0, 1.0)), hash12(cell + vec2(1.0, 1.0)), f.x),
		f.y);
}

void vertex() {
	print_color = COLOR.rgb;
	print_paint = COLOR.a;
}

// A print that is still soaked stands out sharp, one at the end of the trail is
// barely more than a smudge
void fragment() {
	vec2 p = UV - vec2(0.5);
	float box = pow(pow(abs(p.x), corner_roundness) + pow(abs(p.y), corner_roundness), 1.0 / corner_roundness);
	float field = 0.44 - box + (noise2(UV * 7.0) - 0.5) * edge_fray;

	float alpha = smoothstep(0.0, softness, field) * print_paint;
	if (alpha < 0.004) {
		discard;
	}

	float middle = smoothstep(0.0, 0.18, field);
	float rim = 1.0 - middle;

	ALBEDO = mix(mix(print_color, vec3(1.0), 0.25), print_color * 0.6, middle);
	EMISSION = print_color * emission_strength * print_paint * (0.25 + rim * rim_boost);
	ROUGHNESS = 0.2;
	SPECULAR = 0.6;
	ALPHA = alpha;
}
