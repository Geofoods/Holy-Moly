shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float smoothness : hint_range(0.0, 0.1) = 0.02;
uniform vec2 center = vec2(0.5, 0.5);

void fragment() {
	vec2 aspect = vec2(1.0, SCREEN_PIXEL_SIZE.x / SCREEN_PIXEL_SIZE.y);
	float dist = distance(UV * aspect, center * aspect);
	float max_dist = distance(vec2(0.0, 0.0) * aspect, vec2(0.5, 0.5) * aspect);
	float radius = (1.0 - progress) * max_dist * 1.2;
	float alpha = smoothstep(radius, radius + smoothness, dist);
	COLOR = vec4(0.0, 0.0, 0.0, alpha);
}
