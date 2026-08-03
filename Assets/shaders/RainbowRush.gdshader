shader_type spatial;

uniform float hue_speed = 2.5;
uniform float saturation : hint_range(0.0, 1.0) = 0.95;
uniform float body_strength = 1.4;
uniform vec4 edge_color : source_color = vec4(1.0, 0.82, 0.25, 1.0);
uniform float edge_power : hint_range(0.5, 8.0) = 3.0;
uniform float edge_strength = 8.0;
uniform float metallic_amount : hint_range(0.0, 1.0) = 0.2;
uniform float roughness_amount : hint_range(0.0, 1.0) = 0.35;

// Dropped by the effect while the duration runs out, so the whole cube
// flickers instead of just the UI ring
uniform float pulse : hint_range(0.0, 1.0) = 1.0;

vec3 hue_to_rgb(float hue) {
	vec3 ramp = abs(mod(hue * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0;
	return clamp(ramp, 0.0, 1.0);
}

void fragment() {
	vec3 body = mix(vec3(1.0), hue_to_rgb(fract(TIME * hue_speed)), saturation);
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), edge_power);

	ALBEDO = mix(body, edge_color.rgb, rim);
	METALLIC = metallic_amount;
	ROUGHNESS = roughness_amount;
	EMISSION = (body * body_strength + edge_color.rgb * rim * edge_strength) * pulse;
}
