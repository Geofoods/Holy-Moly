shader_type canvas_item;
render_mode blend_mix;

// Polished-metal shine for the Golden Shovel. The sprite is already carrying the
// weapon's icon_color by the time this runs, so the job here is not to recolour
// it but to make it read as metal: a broad sheen across the top, a narrow
// specular band sweeping the blade, and a slow breath on the whole thing. Only
// COLOR.rgb is written, so the silhouette - and the swing trail's alpha - is
// left exactly as the sprite author drew it.

uniform vec3 sheen_color : source_color = vec3(1.0, 0.95, 0.7);
uniform float sheen_strength : hint_range(0.0, 1.0) = 0.55;
uniform float glint_width : hint_range(0.01, 1.0) = 0.18;
uniform float glint_speed : hint_range(0.0, 4.0) = 0.35;
uniform float pulse_rate : hint_range(0.0, 4.0) = 1.1;
uniform float pulse_amount : hint_range(0.0, 1.0) = 0.18;

void fragment() {
	// Diagonal, so the band sweeps corner to corner across the blade instead of
	// sliding straight down it.
	float diag = UV.x * 0.7 + UV.y * 0.3;
	// Triangular wrap rather than a plain fract distance: abs() of this is
	// continuous across the seam, so the band runs off one edge and back in
	// through the other without a second, mirrored glint appearing at the wrap.
	float band = abs(fract(diag - TIME * glint_speed + 0.5) - 0.5);
	float glint = 1.0 - smoothstep(0.0, glint_width, band);

	// Broad sheen over the upper half, as if lit from above. Written as an
	// ascending ramp subtracted from 1 rather than a descending smoothstep, whose
	// result GLSL leaves undefined when edge0 >= edge1.
	float sheen = (1.0 - smoothstep(0.0, 0.75, UV.y)) * 0.6;

	float pulse = 1.0 + sin(TIME * pulse_rate) * pulse_amount;

	vec3 lit = COLOR.rgb * pulse;
	lit += sheen_color * (sheen + glint) * sheen_strength;
	COLOR.rgb = clamp(lit, vec3(0.0), vec3(1.0));
}
