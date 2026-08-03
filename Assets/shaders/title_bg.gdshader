shader_type canvas_item;

// Endless grid running towards a glowing horizon, the backdrop of the title
// screen. Same violet the map sky is painted in, so the menu and the level do
// not look like two different games.

uniform vec4 sky_top : source_color = vec4(0.006, 0.0, 0.024, 1.0);
uniform vec4 sky_bottom : source_color = vec4(0.09, 0.012, 0.2, 1.0);
uniform vec4 grid_color : source_color = vec4(0.42, 0.18, 1.0, 1.0);
uniform vec4 glow_color : source_color = vec4(0.0, 0.85, 1.0, 1.0);

uniform float horizon : hint_range(0.2, 0.9) = 0.58;
uniform float speed = 0.6;
uniform float lane_width = 6.0;
uniform float grid_depth = 0.6;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.06;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.55;

// One anti aliased line per grid cell. Towards the horizon the cells get
// smaller than a pixel, the second term fades them out before they turn into
// a flat wash
float grid_line(float v) {
	float w = fwidth(v);
	float f = fract(v);
	float d = min(f, 1.0 - f);
	float line = 1.0 - smoothstep(w * 0.6, w * 1.8, d);
	return line * (1.0 - smoothstep(0.12, 0.3, w));
}

void fragment() {
	vec2 uv = UV;
	vec3 col = mix(sky_top.rgb, sky_bottom.rgb, smoothstep(0.0, 1.0, uv.y));

	float below = uv.y - horizon;
	if (below > 0.001) {
		float depth = grid_depth / below;
		float lanes = (uv.x - 0.5) * depth * lane_width;
		float rows = depth - TIME * speed;
		float lines = max(grid_line(lanes), grid_line(rows));
		col += grid_color.rgb * lines * smoothstep(0.0, 0.05, below);
	}

	float band = exp(-abs(uv.y - horizon) * 26.0);
	col += glow_color.rgb * band * 0.4;
	col += grid_color.rgb * exp(-abs(uv.y - horizon) * 9.0) * 0.05;

	float scan = sin(uv.y * 900.0) * 0.5 + 0.5;
	col *= 1.0 - scan * scanline_strength;

	float vig = length((uv - 0.5) * vec2(1.15, 1.0));
	col *= mix(1.0, smoothstep(0.85, 0.15, vig), vignette_strength);

	COLOR = vec4(col, 1.0);
}
