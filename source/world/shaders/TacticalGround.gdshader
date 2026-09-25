shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

uniform sampler2D global_macro_tex : source_color, filter_linear_mipmap;
uniform vec3 grass_color : source_color = vec3(0.20, 0.38, 0.12);
uniform vec3 dry_grass_color : source_color = vec3(0.60, 0.50, 0.27);
uniform vec3 soil_color : source_color = vec3(0.36, 0.25, 0.16);
uniform vec3 rock_color : source_color = vec3(0.35, 0.38, 0.40);

varying vec3 world_normal;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);

	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));

	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm2(vec2 p) {
	float n = value_noise(p);
	n += value_noise(p * 2.03 + vec2(11.7, 7.3)) * 0.50;
	n += value_noise(p * 4.07 + vec2(4.1, 19.2)) * 0.25;
	return n / 1.75;
}

void vertex() {
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// UV is geographic and continuous across every terrain tile.
	vec3 macro_color = texture(global_macro_tex, UV).rgb;

	float broad = fbm2(UV * 92.0);
	float detail = fbm2(UV * 390.0 + vec2(17.0, 9.0));

	float grass_mask = smoothstep(0.43, 0.67, broad);
	float dirt_mask = smoothstep(0.69, 0.88, detail) * (1.0 - grass_mask * 0.55);

	vec3 ground = mix(dry_grass_color, grass_color, grass_mask);
	ground = mix(ground, soil_color, dirt_mask * 0.55);

	// The country-scale macro image carries real broad landcover/geographic color
	// without exposing pixels or tile boundaries at tactical distance.
	ground = mix(ground, macro_color, 0.32);

	float slope = 1.0 - clamp(abs(world_normal.y), 0.0, 1.0);
	float rock_mask = smoothstep(0.20, 0.52, slope);
	ground = mix(ground, rock_color, rock_mask * 0.82);

	float brightness = 0.90 + detail * 0.16;
	ALBEDO = ground * brightness;
	ROUGHNESS = 0.94;
	SPECULAR = 0.18;
}
