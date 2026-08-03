shader_type spatial;
render_mode unshaded;

uniform sampler2D color_gradient : source_color;
uniform float cycle_speed : hint_range(0.0, 5.0) = 0.5;
uniform float emission_strength : hint_range(0.0, 20.0) = 6.0;

void fragment() {
	float t = fract(TIME * cycle_speed);
	vec3 col = texture(color_gradient, vec2(t, 0.0)).rgb;

	ALBEDO = col;
	EMISSION = col * emission_strength;
}
