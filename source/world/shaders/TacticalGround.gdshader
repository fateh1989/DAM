shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

uniform vec3 grass_deep : source_color = vec3(0.16, 0.31, 0.09);
uniform vec3 grass_mid : source_color = vec3(0.29, 0.47, 0.16);
uniform vec3 dry_grass : source_color = vec3(0.60, 0.51, 0.28);
uniform vec3 warm_soil : source_color = vec3(0.39, 0.27, 0.16);
uniform vec3 pale_soil : source_color = vec3(0.58, 0.45, 0.27);
uniform vec3 rock : source_color = vec3(0.37, 0.36, 0.31);
uniform float detail_lod : hint_range(0.0, 1.0) = 1.0;

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
	float n = noise2(p) * 0.56;
	n += noise2(p * 2.03 + vec2(13.2, 7.7)) * 0.27;
	n += noise2(p * 4.11 + vec2(4.9, 21.1)) * 0.12;
	n += noise2(p * 8.07 + vec2(31.4, 2.6)) * 0.05;
	return n;
}

void vertex() {
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// UV spans Syria, but only provides deterministic continuity. The visual
	// terrain itself is deliberately fictional/art-directed.
	float macro = fbm(UV * 650.0);
	float broad = fbm(UV * 1850.0 + vec2(17.0, 8.0));
	float detail_near = fbm(UV * 7200.0 + vec2(4.0, 29.0));
	float detail_far = fbm(UV * 3200.0 + vec2(4.0, 29.0));
	float detail = mix(detail_far, detail_near, detail_lod);

	float green = smoothstep(0.36, 0.69, macro + broad * 0.28);
	float dry = smoothstep(0.48, 0.78, broad);
	float soil_patch = smoothstep(0.64, 0.88, detail + broad * 0.16);

	vec3 ground = mix(dry_grass, grass_mid, green);
	ground = mix(ground, grass_deep, smoothstep(0.62, 0.84, macro) * 0.55);
	ground = mix(ground, pale_soil, dry * (1.0 - green) * 0.42);
	ground = mix(ground, warm_soil, soil_patch * 0.46);

	float slope = 1.0 - clamp(abs(world_normal.y), 0.0, 1.0);
	float rock_mask = smoothstep(0.18, 0.48, slope);
	ground = mix(ground, rock, rock_mask * 0.68);

	float micro = 0.92 + detail * 0.16;
	ALBEDO = ground * micro;
	ROUGHNESS = 0.96;
	SPECULAR = 0.12;
}
