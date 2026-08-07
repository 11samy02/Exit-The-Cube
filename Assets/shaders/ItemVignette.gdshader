shader_type canvas_item;

// The glow an item puts around the edge of the screen. In third person the cube
// itself shows what is running, in ego perspective there is no cube to look at,
// so the effect has to say so on the screen instead

uniform vec4 tint : source_color = vec4(1.0, 0.25, 0.85, 1.0);

// Where the glow starts, 0 floods the whole screen and 1 leaves only the corners
uniform float inner : hint_range(0.0, 1.0) = 0.45;

uniform float strength : hint_range(0.0, 2.0) = 0.9;

// Beats per second while the effect has time left. It picks up as the effect
// runs out, so the last seconds are felt without a number being read
uniform float pulse_speed : hint_range(0.0, 8.0) = 1.1;
uniform float pulse_depth : hint_range(0.0, 1.0) = 0.12;

// How much of the effect is left, 1 at the start and 0 at the end
uniform float life : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 offset = (UV - vec2(0.5)) * 2.0;
	float edge = smoothstep(inner, 1.3, length(offset * vec2(1.0, 1.15)));

	float rate = mix(pulse_speed * 1.6, pulse_speed, smoothstep(0.0, 0.25, life));
	float depth = mix(pulse_depth * 1.4, pulse_depth, smoothstep(0.0, 0.25, life));
	float beat = 1.0 - depth + depth * (0.5 + 0.5 * sin(TIME * rate * 6.283));

	COLOR = vec4(tint.rgb, edge * strength * beat * tint.a);
}
