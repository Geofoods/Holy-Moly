shader_type canvas_item;

uniform vec2 depth_min = vec2(0.0, 0.0);
uniform vec2 depth_max = vec2(1.0, 1.0);
uniform float fade_start : hint_range(0.0, 1.0) = 0.25;
uniform float min_brightness : hint_range(0.0, 1.0) = 0.25;

varying float depth_t;

void vertex() {
	float span_x = max(depth_max.x - depth_min.x, 1.0);
	float span_y = max(depth_max.y - depth_min.y, 1.0);
	vec2 local = VERTEX;
	vec2 t = (local - depth_min) / vec2(span_x, span_y);
	depth_t = clamp(t.x, 0.0, 1.0);
}

void fragment() {
	float fade = smoothstep(fade_start, 1.0, depth_t);
	float brightness = mix(1.0, min_brightness, fade);
	COLOR.rgb *= brightness;
}