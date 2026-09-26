shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform vec3 dry_grass : source_color = vec3(0.46, 0.42, 0.23);
uniform vec3 scrub_green : source_color = vec3(0.26, 0.34, 0.16);
uniform vec3 warm_soil : source_color = vec3(0.42, 0.30, 0.18);
uniform vec3 pale_soil : source_color = vec3(0.57, 0.46, 0.29);
uniform vec3 rock_color : source_color = vec3(0.36, 0.35, 0.31);

varying vec3 world_pos;
varying vec3 world_normal;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float n = noise2(p) * 0.58;
	n += noise2(p * 2.07 + vec2(11.0, 4.0)) * 0.27;
	n += noise2(p * 4.17 + vec2(3.0, 19.0)) * 0.15;
	return n;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float macro = fbm(world_pos.xz * 0.0010);
	float detail = fbm(world_pos.xz * 0.0045 + vec2(8.0, 17.0));
	float green_mask = smoothstep(0.40, 0.72, macro + detail * 0.12);
	float soil_mask = smoothstep(0.58, 0.82, detail + macro * 0.18);
	vec3 ground = mix(dry_grass, scrub_green, green_mask * 0.68);
	ground = mix(ground, pale_soil, (1.0 - green_mask) * 0.32);
	ground = mix(ground, warm_soil, soil_mask * 0.38);
	float slope = 1.0 - clamp(abs(world_normal.y), 0.0, 1.0);
	float rock_mask = smoothstep(0.12, 0.38, slope);
	ground = mix(ground, rock_color, rock_mask * 0.72);
	ALBEDO = ground * (0.92 + detail * 0.14);
	ROUGHNESS = 0.97;
	SPECULAR = 0.08;
}
