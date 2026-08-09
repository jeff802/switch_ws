shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 wipe_color : source_color = vec4(0.025, 0.055, 0.07, 1.0);
uniform float cell_size : hint_range(8.0, 48.0) = 20.0;


void fragment() {
	vec2 cell = floor(FRAGCOORD.xy / cell_size);
	vec2 local_uv = fract(FRAGCOORD.xy / cell_size) - vec2(0.5);
	float diagonal = clamp(UV.x * 0.68 + UV.y * 0.32, 0.0, 1.0);
	float teeth = sin(atan(local_uv.y, local_uv.x) * 8.0) * 0.035;
	float ring = smoothstep(0.48, 0.12, length(local_uv)) * 0.05;
	float stagger = mod(cell.x + cell.y, 2.0) * 0.025;
	float order = 0.05 + 0.9 * clamp(diagonal + teeth - ring + stagger, 0.0, 1.0);
	float coverage = smoothstep(order - 0.045, order + 0.045, progress);
	COLOR = vec4(wipe_color.rgb, wipe_color.a * coverage);
}
