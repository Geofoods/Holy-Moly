shader_type canvas_item;

uniform float intensity : hint_range(0.0, 2.0) = 0.6;
uniform float smoothness : hint_range(0.0, 1.0) = 0.4;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	float dist = distance(UV, vec2(0.5));
	float vignette = smoothstep(0.5 - smoothness, 0.5 + smoothness, dist);
	float alpha = vignette * intensity * opacity;
	COLOR = vec4(0.0, 0.0, 0.0, alpha);
}
