shader_type canvas_item;

uniform float bolt_mix : hint_range(0.0, 1.0) = 0.0;
uniform vec3 bolt_shadow : source_color = vec3(0.055, 0.22, 0.29);
uniform vec3 bolt_mid : source_color = vec3(0.12, 0.72, 0.82);
uniform vec3 bolt_light : source_color = vec3(0.82, 1.0, 1.0);


void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	float high = max(pixel.r, max(pixel.g, pixel.b));
	float low = min(pixel.r, min(pixel.g, pixel.b));
	float saturation = high - low;
	float warm = smoothstep(0.03, 0.2, pixel.r - pixel.b);
	float colored = smoothstep(0.08, 0.28, saturation);
	float visible_color = smoothstep(0.12, 0.28, high);
	float lightness = dot(pixel.rgb, vec3(0.299, 0.587, 0.114));
	// The mechanic's coat and cap use the dark warm ramp. Skin and brass
	// highlights share the hue but live above this luminance range, so this
	// extra mask keeps the face and hands intact during the power swap.
	float fabric_range = 1.0 - smoothstep(0.48, 0.61, lightness);
	float cloth_mask = warm * colored * visible_color * fabric_range * pixel.a * bolt_mix;
	vec3 powered_color = mix(bolt_shadow, bolt_mid, smoothstep(0.12, 0.48, lightness));
	powered_color = mix(powered_color, bolt_light, smoothstep(0.5, 0.82, lightness));
	pixel.rgb = mix(pixel.rgb, powered_color, cloth_mask);
	COLOR = pixel * COLOR;
}
