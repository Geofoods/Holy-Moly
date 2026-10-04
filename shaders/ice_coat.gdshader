shader_type canvas_item;

uniform sampler2D frost : filter_linear, repeat_enable;
uniform vec2 tile = vec2(3.0, 2.0);
uniform float strength : hint_range(0.0, 1.0) = 0.45;

void fragment() {
	vec3 frost_color = texture(frost, UV * tile).rgb;
	// Screen keeps the goblin's own shading underneath the frost, so it still
	// reads as a goblin rather than a flat blue cut-out.
	vec3 frosted = 1.0 - (1.0 - COLOR.rgb) * (1.0 - frost_color);
	// Only rgb is written, which leaves the sprite's alpha - and therefore its
	// silhouette - untouched.
	COLOR.rgb = mix(COLOR.rgb, frosted, strength);
}