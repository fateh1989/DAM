shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform sampler2D global_macro_tex : source_color, filter_linear_mipmap;
uniform sampler2D macro_variation : source_color, filter_linear_mipmap;

uniform vec2 world_size_meters = vec2(500000.0, 500000.0);
uniform vec2 world_origin = vec2(0.0, 0.0);
uniform float detail_fade_start_m = 60000.0;
uniform float detail_fade_end_m = 220000.0;

varying vec3 world_pos;
varying vec3 vertex_normal;
varying vec3 local_color;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vertex_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	local_color = COLOR.rgb;
}

void fragment() {
	vec2 world_meters = world_pos.xz * 1000.0;
	vec2 global_uv = (world_meters - world_origin) / world_size_meters;

	vec3 macro_color = texture(global_macro_tex, global_uv).rgb;
	vec3 variation = texture(macro_variation, world_meters * 0.0005).rgb;

	float hillshade = dot(vertex_normal, normalize(vec3(0.5, 0.8, -0.5)));
	hillshade = smoothstep(0.2, 0.8, hillshade) * 0.6 + 0.4;

	float distance_m = length(CAMERA_POSITION_WORLD - world_pos) * 1000.0;
	float macro_weight = smoothstep(detail_fade_start_m, detail_fade_end_m, distance_m);
	vec3 terrain_color = mix(local_color, macro_color, macro_weight);

	vec3 final_color = terrain_color * variation * hillshade;
	ALBEDO = final_color;
	ROUGHNESS = 0.9;
}
