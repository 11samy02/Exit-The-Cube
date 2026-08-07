shader_type canvas_item;

// Swims the view about. Used by whatever leaves a cube unsteady on its feet.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;

// 0 leaves the screen exactly as it was
uniform float amount : hint_range(0.0, 1.0) = 0.0;

uniform float speed = 1.7;
uniform float sway = 0.016;
uniform vec4 tint : source_color = vec4(0.6, 0.4, 1.0, 1.0);

void fragment() {
	float t = TIME * speed;
	vec2 uv = SCREEN_UV;

	uv.x += sin(uv.y * 7.0 + t) * sway * amount;
	uv.y += cos(uv.x * 5.0 + t * 0.8) * sway * 0.7 * amount;

	// the colours drift apart a little, which is what sells it as your eyes
	// rather than as the level moving
	float split = sway * 0.35 * amount;
	vec3 seen = vec3(
		texture(screen_texture, uv + vec2(split, 0.0)).r,
		texture(screen_texture, uv).g,
		texture(screen_texture, uv - vec2(split, 0.0)).b
	);

	COLOR = vec4(mix(seen, seen * tint.rgb, 0.25 * amount), 1.0);
}
