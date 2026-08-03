shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled;

uniform vec4 path_color : source_color = vec4(1.0, 0.35, 0.1, 1.0);
uniform float dash_length : hint_range(0.05, 5.0) = 0.6;
uniform float dash_ratio : hint_range(0.05, 1.0) = 0.55;
uniform float flow_speed = 1.5;
uniform float emission_strength : hint_range(0.0, 20.0) = 2.0;

// The crosses on the waypoints are drawn with the same material so they dim
// behind a wall like the route does, they only have no dashes running through
uniform bool solid = false;

// How much of the route is left where a wall stands between it and the camera.
// The line is drawn through everything on purpose, that is the point of the
// item, but a stretch that is really in sight has to read as the closer one
uniform float hidden_dim : hint_range(0.0, 1.0) = 0.14;

// How solid the hidden stretch is drawn. Under 1 the wall shows through it, so
// a route behind a corner reads as a hint instead of as a line lying on it
uniform float hidden_alpha : hint_range(0.0, 1.0) = 0.4;

// Slack on the depth compare, without it a route running along a wall flickers
// between the two brightnesses as the camera moves
uniform float depth_bias : hint_range(0.0, 1.0) = 0.06;

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;

// How far the opaque world is from the camera at that pixel. The route itself
// is drawn without a depth test, so this is the only way it can tell whether
// anything is standing in front of it
float scene_distance(vec2 screen_uv, mat4 inverse_projection) {
	vec3 ndc = vec3(screen_uv * 2.0 - 1.0, textureLod(depth_texture, screen_uv, 0.0).r);
	vec4 view = inverse_projection * vec4(ndc, 1.0);

	return -view.z / view.w;
}

// UV.x carries the distance along the route in world units, so the dashes keep
// the same size no matter how long a single segment is
void fragment() {
	float pattern = fract((UV.x - TIME * flow_speed) / dash_length);

	if (!solid && pattern > dash_ratio) {
		discard;
	}

	float wall = scene_distance(SCREEN_UV, INV_PROJECTION_MATRIX);
	float here = -VERTEX.z;
	float in_sight = step(here, wall + depth_bias);

	float head = solid ? 1.0 : 1.0 - pattern / dash_ratio;
	float seen = mix(hidden_dim, 1.0, in_sight);
	vec3 col = path_color.rgb * mix(0.35, 1.0, head) * seen;

	ALBEDO = col;
	EMISSION = col * emission_strength * head * seen;
	ALPHA = path_color.a * mix(hidden_alpha, 1.0, in_sight);
}
