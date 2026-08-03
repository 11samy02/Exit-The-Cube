shader_type canvas_item;
render_mode unshaded;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float flip : hint_range(0.0, 1.0) = 0.0;
uniform vec2 cells = vec2(32.0, 18.0);
uniform vec4 fill_color : source_color = vec4(0.02, 0.02, 0.04, 1.0);
uniform vec4 edge_color : source_color = vec4(0.2, 0.85, 1.0, 1.0);
uniform float edge_width : hint_range(0.0, 0.5) = 0.06;
uniform float sweep_spread : hint_range(0.0, 1.0) = 0.6;
uniform float spin : hint_range(0.0, 4.0) = 1.2;

mat2 turn(float angle) {
	float s = sin(angle);
	float c = cos(angle);
	return mat2(vec2(c, -s), vec2(s, c));
}

void fragment() {
	vec2 grid = UV * cells;
	vec2 cell = floor(grid);
	vec2 local = fract(grid) - 0.5;

	float sweep = (cell.x + cell.y) / (cells.x + cells.y - 2.0);
	float delay = mix(sweep, 1.0 - sweep, flip) * sweep_spread;
	float grow = clamp((progress - delay) / max(1.0 - sweep_spread, 0.001), 0.0, 1.0);

	local = turn((1.0 - grow) * spin) * local;

	float radius = grow * 1.5;
	float square = max(abs(local.x), abs(local.y)) * 2.0;
	float alpha = 1.0 - smoothstep(radius - 0.04, radius, square);
	float edge = smoothstep(radius - edge_width, radius, square) * alpha;

	COLOR = vec4(mix(fill_color.rgb, edge_color.rgb, edge), fill_color.a * alpha);
}
