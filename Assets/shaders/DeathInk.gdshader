shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

// The ink of one death. Every face of the map around the burst gets a quad of
// this material, and all of them read the same shape out of the world position,
// so the ink runs over the floor and up the walls as one piece instead of
// falling apart into single stickers. What a quad shows is only the part of
// that shape its own face happens to cut through
uniform vec4 ink_color : source_color = vec4(0.85, 0.06, 0.2, 1.0);
uniform vec3 ink_center;
uniform float ink_radius = 1.7;
uniform float ink_seed = 0.0;
uniform float ink_fade = 1.0;
uniform float ink_grow = 1.0;

group_uniforms Shape;

// How far the outline is pushed around, 0 leaves a clean ball of paint
uniform float edge_noise : hint_range(0.0, 1.0) = 0.42;

// How far the ink is pulled downward, it has run before it dried
uniform float sag : hint_range(0.0, 0.8) = 0.3;

// Single blobs thrown clear of the main pool
uniform int droplets : hint_range(0, 12) = 6;

// A second, much finer octave torn into the outline. Only the top splatter
// setting pays for it, it is another noise lookup for every pixel of the mark
uniform float edge_detail : hint_range(0.0, 1.0) = 0.0;

group_uniforms Body;

// How thick the paint lies on the surface in meters, this is what the light is
// bent over. It is not moved geometry, the quad stays flat
uniform float ink_thickness : hint_range(0.0, 0.3) = 0.06;

// How wide the rounded bead along the outline is in meters. Narrow gives a
// sharp lip that catches a hard highlight, wide gives a soft mound
uniform float bead_width : hint_range(0.02, 1.5) = 0.3;

// A slow swell over the surface, the paint did not dry as a level sheet. This
// goes into the height the normal is built from, so anything fine grained here
// turns into flickering highlights instead of body
uniform float surface_detail : hint_range(0.0, 1.0) = 0.25;
uniform float detail_scale : hint_range(0.5, 20.0) = 3.0;

// Multiplies the whole relief, past 1 the paint reads thicker than it is
uniform float bump_strength : hint_range(0.0, 8.0) = 3.0;

group_uniforms Light;

// The ink lights itself off this direction on top of whatever the level does,
// so the body of it reads in a corridor with no lamp in it
uniform vec3 shade_direction = vec3(0.35, 1.0, 0.25);
uniform float shade_depth : hint_range(0.0, 1.0) = 0.55;
uniform float gloss : hint_range(0.0, 4.0) = 1.4;
uniform float gloss_sharpness : hint_range(2.0, 128.0) = 28.0;

group_uniforms Color;

uniform float rim_boost : hint_range(0.0, 6.0) = 1.8;
uniform float emission_strength : hint_range(0.0, 4.0) = 0.85;
uniform float aged_darkness : hint_range(0.0, 1.0) = 0.7;

varying vec3 world_pos;
varying vec3 face_normal;
varying vec3 face_tangent;
varying vec3 face_binormal;

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

float hash13(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.11, 0.17, 0.13));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise3(vec3 p) {
	vec3 cell = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);

	return mix(
		mix(mix(hash13(cell), hash13(cell + vec3(1.0, 0.0, 0.0)), f.x),
			mix(hash13(cell + vec3(0.0, 1.0, 0.0)), hash13(cell + vec3(1.0, 1.0, 0.0)), f.x), f.y),
		mix(mix(hash13(cell + vec3(0.0, 0.0, 1.0)), hash13(cell + vec3(1.0, 0.0, 1.0)), f.x),
			mix(hash13(cell + vec3(0.0, 1.0, 1.0)), hash13(cell + vec3(1.0, 1.0, 1.0)), f.x), f.y),
		f.z);
}

// Melts two parts into one instead of cutting one against the other. A blob
// that merely overlaps the pool would leave a hard notch where the two meet
float smooth_union(float a, float b, float k) {
	float h = clamp(0.5 + 0.5 * (a - b) / k, 0.0, 1.0);
	return mix(b, a, h) + k * h * (1.0 - h);
}

// Positive inside the ink. It is one ball around the burst with its outline
// pushed around by noise, sagging downward, with a few blobs thrown clear of it
float ink_field(vec3 p) {
	float radius = ink_radius * ink_grow;
	vec3 rel = p - ink_center;

	if (rel.y < 0.0) {
		rel.y *= 1.0 - sag;
	}

	vec3 sample_pos = rel / max(radius, 0.001);
	float warp = (noise3(sample_pos * 2.4 + vec3(ink_seed)) - 0.5) * 0.75
		+ (noise3(sample_pos * 6.5 + vec3(ink_seed * 3.0)) - 0.5) * 0.28;

	if (edge_detail > 0.0) {
		warp += (noise3(sample_pos * 15.0 + vec3(ink_seed * 5.0)) - 0.5) * 0.16 * edge_detail;
	}

	float field = radius * (0.92 + warp * edge_noise) - length(rel);

	// The same warp runs over the blobs, a ball cut by a wall would otherwise
	// show up as a flawless circle sitting next to a torn up pool
	for (int i = 0; i < droplets; i++) {
		float n = ink_seed * 13.0 + float(i) * 5.31;
		vec3 dir = normalize(vec3(hash11(n), hash11(n + 1.7), hash11(n + 3.3)) - vec3(0.5));
		vec3 center = dir * radius * (0.85 + hash11(n + 5.1) * 0.4);
		float edge = radius * (0.09 + hash11(n + 7.7) * 0.13) * (1.0 + warp * edge_noise * 1.8);
		field = smooth_union(field, edge - length(rel - center), radius * 0.06);
	}

	return field;
}

// How high the paint stands over the surface at that point. The square root
// pulls the edge up steeply and levels off inside, which is how a puddle sits:
// a rounded bead all along the outline and a flat sheet in the middle
float ink_height(vec3 p, float field) {
	float bead = sqrt(clamp(field / bead_width, 0.0, 1.0));

	if (surface_detail <= 0.0) {
		return bead * ink_thickness;
	}

	float detail = (noise3(p * detail_scale) - 0.5) * surface_detail;
	return (bead + detail * bead) * ink_thickness;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	face_normal = normalize((MODEL_MATRIX * vec4(0.0, 0.0, 1.0, 0.0)).xyz);
	face_tangent = normalize((MODEL_MATRIX * vec4(1.0, 0.0, 0.0, 0.0)).xyz);
	face_binormal = normalize((MODEL_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
}

// The relief comes out of the screen derivatives of the height: how much the
// height changes over one pixel, against how much the world position changes
// over that same pixel, is the slope of the paint. That costs two derivatives
// instead of a second pass over the whole shape.
//
// Old ink is dried down toward black instead of going see through, a surface
// you can look through would read as a hole in the map
void fragment() {
	float field = ink_field(world_pos);
	float height = ink_height(world_pos, field);

	vec3 step_x = dFdx(world_pos);
	vec3 step_y = dFdy(world_pos);
	float rise_x = dFdx(height);
	float rise_y = dFdy(height);
	float aa = max(fwidth(field), 0.001);

	float alpha = smoothstep(-aa, aa, field);
	if (alpha < 0.004) {
		discard;
	}

	// The two steps span the surface, solving against them turns the pair of
	// screen slopes back into one slope along the face itself
	float ax = dot(step_x, face_tangent);
	float ay = dot(step_x, face_binormal);
	float bx = dot(step_y, face_tangent);
	float by = dot(step_y, face_binormal);
	float det = ax * by - ay * bx;

	vec2 slope = vec2(0.0);
	if (abs(det) > 1e-9) {
		slope = vec2(by * rise_x - ay * rise_y, ax * rise_y - bx * rise_x) / det;
	}

	vec3 normal = normalize(face_normal
		- (face_tangent * slope.x + face_binormal * slope.y) * bump_strength);

	// The glint is held to where the paint actually curves. Over the flat middle
	// the half vector lines up across the whole pool at once and the mark blows
	// out into one white blob
	float curve = clamp(length(slope) * bump_strength * 4.0, 0.0, 1.0);
	vec3 to_light = normalize(shade_direction);
	vec3 to_eye = normalize(CAMERA_POSITION_WORLD - world_pos);
	float lambert = mix(1.0, dot(normal, to_light) * 0.5 + 0.5, shade_depth);
	float spec = min(pow(max(dot(normal, normalize(to_light + to_eye)), 0.0), gloss_sharpness) * gloss * curve, 1.5);

	float thick = smoothstep(0.0, ink_radius * 0.22, field);
	float rim = 1.0 - smoothstep(0.0, ink_radius * 0.07, field);
	float age = mix(1.0 - aged_darkness, 1.0, ink_fade);

	NORMAL = normalize((VIEW_MATRIX * vec4(normal, 0.0)).xyz);
	ALBEDO = mix(mix(ink_color.rgb, vec3(1.0), 0.3), ink_color.rgb * 0.55, thick) * age * lambert;
	EMISSION = ink_color.rgb * emission_strength * age * (0.3 + rim * rim_boost) * lambert
		+ mix(ink_color.rgb, vec3(1.0), 0.6) * spec * age;
	ROUGHNESS = 0.14;
	SPECULAR = 0.7;
	ALPHA = alpha * ink_color.a;
}
