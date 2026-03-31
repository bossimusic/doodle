shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.38, 0.22, 0.07, 1.0);
uniform float outline_left : hint_range(0.0, 10.0) = 4.0;
uniform float outline_right : hint_range(0.0, 10.0) = 2.0;
uniform float outline_top_bottom : hint_range(0.0, 10.0) = 3.0;

void fragment() {
	vec4 current = texture(TEXTURE, UV);
	if (current.a < 0.5) {
		vec2 ps = TEXTURE_PIXEL_SIZE;
		float alpha = 0.0;
		float max_d = max(max(outline_left, outline_right), outline_top_bottom);
		for (float x = -max_d; x <= max_d; x += 1.0) {
			for (float y = -max_d; y <= max_d; y += 1.0) {
				// x > 0 means sample is rightward → contributes to LEFT edge outline
				// x < 0 means sample is leftward → contributes to RIGHT edge outline
				float x_limit = (x > 0.0) ? outline_left : outline_right;
				if (abs(x) <= x_limit && abs(y) <= outline_top_bottom) {
					alpha = max(alpha, texture(TEXTURE, UV + vec2(x, y) * ps).a);
				}
			}
		}
		COLOR = vec4(outline_color.rgb, alpha * outline_color.a);
	} else {
		COLOR = current;
	}
}
