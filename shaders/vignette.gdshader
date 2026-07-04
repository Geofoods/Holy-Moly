shader_type canvas_item;

uniform float inner_radius : hint_range(0.0, 1.0) = 0.25;
uniform float outer_radius : hint_range(0.0, 1.5) = 0.55;
uniform float darkness : hint_range(0.0, 1.0) = 0.95;

void fragment() {
	vec2 center = UV - vec2(0.5);
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	center.x *= aspect;
	float dist = length(center);
	float vignette = smoothstep(inner_radius, outer_radius, dist);
	COLOR = vec4(0.0, 0.0, 0.0, vignette * darkness);
}
