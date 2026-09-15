shader_type canvas_item;

uniform float blur_radius : hint_range(0.0, 6.0) = 0.0;
uniform float alpha : hint_range(0.0, 1.0) = 1.0;
uniform float brightness : hint_range(0.0, 2.0) = 1.0;

void fragment() {
	vec2 ts = TEXTURE_PIXEL_SIZE;
	vec4 col;
	if (blur_radius < 0.01) {
		col = texture(TEXTURE, UV);
	} else {
		float sigma = blur_radius;
		float s2 = sigma * sigma * 2.0;
		col = vec4(0.0);
		float total = 0.0;
		for (int j = -1; j <= 1; j++) {
			for (int i = -1; i <= 1; i++) {
				vec2 off = vec2(float(i), float(j)) * ts * sigma * 1.5;
				float dist = float(i * i) + float(j * j);
				float w = exp(-dist / s2);
				col += texture(TEXTURE, UV + off) * w;
				total += w;
			}
		}
		col /= total;
	}
	COLOR = col;
	COLOR.a *= alpha;
	COLOR.rgb *= brightness;
}