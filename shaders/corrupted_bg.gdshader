shader_type canvas_item;

uniform float scanline_count : hint_range(50.0, 500.0) = 240.0;
uniform float scanline_opacity : hint_range(0.0, 1.0) = 0.18;
uniform float noise_strength : hint_range(0.0, 1.0) = 0.05;
uniform float glitch_speed : hint_range(0.0, 10.0) = 1.2;
uniform vec3 base_color : source_color = vec3(0.035, 0.05, 0.04);
uniform vec3 tint_color : source_color = vec3(0.15, 0.55, 0.3);

float rand(vec2 co) {
	return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;

	float glitch_row = floor(uv.y * 40.0);
	float tear_trigger = rand(vec2(glitch_row, floor(TIME * glitch_speed)));
	float tear = step(0.985, tear_trigger) * (rand(vec2(glitch_row, TIME)) - 0.5) * 0.06;
	uv.x += tear;

	vec3 col = base_color;
	col += tint_color * (rand(uv * 3.0) * 0.03);

	float scan = sin(uv.y * scanline_count) * 0.5 + 0.5;
	col -= scan * scanline_opacity * 0.5;

	float n = rand(uv * (TIME * 0.5 + 1.0));
	col += (n - 0.5) * noise_strength;

	float vignette = smoothstep(1.1, 0.3, distance(UV, vec2(0.5)));
	col *= mix(0.6, 1.0, vignette);

	COLOR = vec4(col, 1.0);
}
