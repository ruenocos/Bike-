shader_type sky;
// Bike! anime pop sky (sky/). One material per biome (sky/looks/*.tres),
// every look is a set of the uniforms below, so tune it in the Inspector:
// open a look .tres, or select WorldEnvironment > Environment > Sky > Sky
// Material in sky/sky_preview.tscn and watch it change.
// Layers, back to front: gradient (optionally posterized into hard bands),
// stars, sun + halo ring, far megastructures (silhouettes painted into the
// sky, unreachable, no geometry), the cumulus wall on the horizon, and the
// cel clouds overhead. The sun's position comes from the scene's
// DirectionalLight3D, so the halo, cloud shading and structure rims always
// agree with the light on the ground.
// Angles are in degrees. Azimuth 0 = straight down the stage (-Z), positive
// to the right (+X).
render_mode use_debanding;

group_uniforms Painted;
/// A painted 360 panorama (equirect, horizon in the middle) under
/// everything else. Empty = the procedural gradient + clouds below.
uniform sampler2D panorama : source_color, filter_linear, repeat_enable;
uniform bool use_panorama = false;
/// Where the painted sun sits in the image (deg, 0 = left edge). The image
/// turns so that spot lines up with the scene's sun.
uniform float panorama_sun_u : hint_range(0.0, 360.0, 0.1) = 0.0;
/// Extra turn on top (deg), e.g. for an image without a visible sun.
uniform float panorama_turn : hint_range(-180.0, 180.0, 0.5) = 0.0;
/// Lifts the image so its horizon sits this many deg lower/higher.
uniform float panorama_horizon : hint_range(-10.0, 10.0, 0.1) = 0.0;
uniform vec3 panorama_tint : source_color = vec3(1.0);
uniform float panorama_exposure : hint_range(0.0, 3.0, 0.01) = 1.0;
uniform float panorama_saturation : hint_range(0.0, 2.0, 0.01) = 1.0;
uniform float panorama_contrast : hint_range(0.0, 2.0, 0.01) = 1.0;
/// Blend the gradient colours below over the image (0 = image only), to
/// push a biome's mood without a new picture.
uniform float panorama_grade : hint_range(0.0, 1.0, 0.01) = 0.0;

group_uniforms Gradient;
uniform vec3 zenith_color : source_color = vec3(0.12, 0.2, 0.55);
uniform vec3 upper_color : source_color = vec3(0.45, 0.42, 0.78);
uniform vec3 horizon_color : source_color = vec3(1.0, 0.68, 0.55);
/// A thin hot line right on the horizon.
uniform vec3 glow_color : source_color = vec3(1.0, 0.86, 0.6);
uniform vec3 ground_color : source_color = vec3(0.93, 0.72, 0.56);
/// Elevation (deg) where the upper colour is pure.
uniform float upper_elevation : hint_range(1.0, 89.0, 0.5) = 30.0;
/// Elevation (deg) where the horizon colour starts to blend up.
uniform float horizon_elevation : hint_range(0.0, 45.0, 0.5) = 6.0;
uniform float glow_elevation : hint_range(0.0, 20.0, 0.1) = 2.5;
/// 0 = smooth gradient; N = posterized into N hard bands (anime pop).
uniform float bands : hint_range(0.0, 16.0, 1.0) = 0.0;
/// Softness of the band steps (0 = razor sharp).
uniform float band_softness : hint_range(0.0, 0.5, 0.01) = 0.06;
/// The horizon toward the sun warms up to this colour.
uniform vec3 sun_side_color : source_color = vec3(1.0, 0.55, 0.35);
uniform float sun_side_strength : hint_range(0.0, 1.0, 0.01) = 0.5;
/// How wide (deg of azimuth) the warm side is.
uniform float sun_side_width : hint_range(10.0, 180.0, 1.0) = 80.0;

group_uniforms Sun;
uniform vec3 sun_disc_color : source_color = vec3(1.0, 0.97, 0.85);
uniform float sun_size : hint_range(0.0, 20.0, 0.1) = 3.5;
uniform float sun_edge : hint_range(0.0, 2.0, 0.01) = 0.15;
uniform vec3 halo_color : source_color = vec3(1.0, 0.8, 0.55);
uniform float halo_size : hint_range(0.0, 90.0, 0.5) = 22.0;
uniform float halo_strength : hint_range(0.0, 2.0, 0.01) = 0.6;
/// The anime lens ring around the sun.
uniform float ring_radius : hint_range(0.0, 60.0, 0.5) = 9.0;
uniform float ring_width : hint_range(0.0, 5.0, 0.05) = 0.6;
uniform float ring_strength : hint_range(0.0, 1.0, 0.01) = 0.25;

group_uniforms Stars;
uniform float star_density : hint_range(0.0, 0.05, 0.0005) = 0.0;
uniform float star_brightness : hint_range(0.0, 3.0, 0.05) = 1.0;
/// Stars fade out below this elevation (deg).
uniform float star_fade_elevation : hint_range(0.0, 60.0, 0.5) = 15.0;

group_uniforms Clouds;
/// Seamless noise (sky/cloud_noise.tres). Its red channel = cloud density.
uniform sampler2D cloud_noise : filter_linear_mipmap, repeat_enable;
uniform float cloud_coverage : hint_range(0.0, 1.0, 0.01) = 0.4;
uniform float cloud_scale : hint_range(0.01, 2.0, 0.01) = 0.25;
/// Stretch along the stage (x) / across (y): > 1 = streaky cirrus.
uniform vec2 cloud_stretch = vec2(1.0, 1.0);
uniform vec2 cloud_wind = vec2(0.004, 0.002);
/// Edge softness (0 = hard cel edge).
uniform float cloud_softness : hint_range(0.0, 0.3, 0.005) = 0.02;
uniform vec3 cloud_light : source_color = vec3(1.0, 0.95, 0.9);
uniform vec3 cloud_shadow : source_color = vec3(0.62, 0.55, 0.8);
/// How far toward the sun to look for the shadow side.
uniform float cloud_shade_offset : hint_range(0.0, 0.2, 0.002) = 0.04;
/// Bright rim right at the edge (silver lining).
uniform vec3 cloud_rim_color : source_color = vec3(1.0, 1.0, 0.95);
uniform float cloud_rim_width : hint_range(0.0, 0.2, 0.005) = 0.03;
uniform float cloud_rim_strength : hint_range(0.0, 1.0, 0.01) = 0.5;
/// Ink line around clouds (0 = none).
uniform float cloud_outline : hint_range(0.0, 0.1, 0.002) = 0.0;
uniform vec3 cloud_outline_color : source_color = vec3(0.3, 0.25, 0.45);
/// Clouds thin out toward the horizon below this elevation (deg).
uniform float cloud_horizon_fade : hint_range(0.5, 45.0, 0.5) = 8.0;
/// Far clouds take on the horizon colour.
uniform float cloud_haze : hint_range(0.0, 1.0, 0.01) = 0.5;

group_uniforms CloudWall;
/// Towering cumulus on the horizon, all around. Height in deg (0 = off).
uniform float wall_height : hint_range(0.0, 40.0, 0.25) = 9.0;
/// How much the height varies around the horizon.
uniform float wall_variation : hint_range(0.0, 1.0, 0.01) = 0.7;
/// Width of one big puff (deg of azimuth).
uniform float wall_puff_size : hint_range(1.0, 40.0, 0.25) = 9.0;
uniform vec3 wall_light : source_color = vec3(1.0, 0.85, 0.7);
uniform vec3 wall_shadow : source_color = vec3(0.7, 0.55, 0.75);
/// Bottom of the wall sinks into this (usually the horizon colour).
uniform vec3 wall_base : source_color = vec3(1.0, 0.75, 0.62);
/// Elevation (deg) over which the base melts into haze.
uniform float wall_base_fade : hint_range(0.1, 20.0, 0.1) = 4.0;
uniform float wall_outline : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform vec3 wall_outline_color : source_color = vec3(0.4, 0.3, 0.45);
uniform float wall_seed : hint_range(0.0, 100.0, 1.0) = 3.0;

group_uniforms Structures;
/// Far alien megastructures, painted on the horizon behind the cloud wall.
uniform vec3 structure_color : source_color = vec3(0.55, 0.5, 0.7);
/// Lit edge on the sun side.
uniform vec3 structure_rim : source_color = vec3(1.0, 0.82, 0.65);
uniform float structure_rim_width : hint_range(0.0, 2.0, 0.01) = 0.35;
/// How much the haze swallows them toward their base.
uniform float structure_haze : hint_range(0.0, 1.0, 0.01) = 0.45;
/// Glowing seams / lights on the structures.
uniform vec3 structure_glow : source_color = vec3(1.0, 0.95, 0.7);
uniform float structure_glow_strength : hint_range(0.0, 3.0, 0.05) = 0.0;
/// Ring arch: x = azimuth, y = centre elevation, z = radius (deg). z 0 = off.
uniform vec3 ring = vec3(-38.0, 6.0, 26.0);
uniform float ring_thickness : hint_range(0.1, 10.0, 0.05) = 1.6;
/// Tilt: < 1 squashes it into an ellipse seen at an angle.
uniform float ring_aspect : hint_range(0.05, 1.0, 0.01) = 0.55;
/// Spire: x = azimuth, y = height, z = base width (deg). y 0 = off.
uniform vec3 spire = vec3(31.0, 34.0, 2.2);
/// Floating shards: x = azimuth, y = elevation, z = spread (deg).
uniform vec3 shards = vec3(55.0, 20.0, 18.0);
uniform float shard_count : hint_range(0.0, 12.0, 1.0) = 0.0;
uniform float shard_size : hint_range(0.2, 10.0, 0.1) = 2.5;
/// Slow bob of the shards (deg per second-ish).
uniform float shard_bob : hint_range(0.0, 2.0, 0.01) = 0.3;

group_uniforms Output;
/// Final push on the whole sky (the AgX tonemap mutes bright colours).
uniform float sky_saturation : hint_range(0.0, 2.0, 0.01) = 1.0;
uniform float sky_exposure : hint_range(0.0, 3.0, 0.01) = 1.0;

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

// Signed difference of two azimuths in [-180, 180].
float az_delta(float a, float b) {
	return mod(a - b + 540.0, 360.0) - 180.0;
}

// Gradient position 0 (horizon) .. 1 (zenith) as three blended stops.
vec3 gradient(float el) {
	float t_up = clamp((el - horizon_elevation) / max(upper_elevation - horizon_elevation, 0.01), 0.0, 1.0);
	float t_top = clamp((el - upper_elevation) / max(90.0 - upper_elevation, 0.01), 0.0, 1.0);
	if (bands > 0.5) {
		// Posterize: hard steps with a little softness.
		float s = t_up * bands;
		float f = fract(s);
		t_up = (floor(s) + smoothstep(0.5 - band_softness, 0.5 + band_softness, f)) / bands;
		s = t_top * bands;
		f = fract(s);
		t_top = (floor(s) + smoothstep(0.5 - band_softness, 0.5 + band_softness, f)) / bands;
	}
	vec3 c = mix(horizon_color, upper_color, t_up);
	c = mix(c, zenith_color, t_top);
	return c;
}

// The cumulus wall: big puffs (half discs) along the horizon with a second
// row of smaller puffs on top. Returns (coverage, lit 0..1, edge 0..1).
vec3 cloud_wall(float az, float el, float sun_az, float sun_el) {
	if (wall_height <= 0.0) {
		return vec3(0.0);
	}
	float best = -1e9;
	float lit = 0.0;
	float size = wall_puff_size;
	for (int layer = 0; layer < 2; layer++) {
		float w = layer == 0 ? size : size * 0.45;
		float cell = floor(az / w);
		for (int i = -2; i <= 2; i++) {
			float id = cell + float(i);
			float h0 = hash11(id * 1.37 + wall_seed * 17.0 + float(layer) * 91.0);
			float h1 = hash11(id * 3.11 + wall_seed * 5.0 + float(layer) * 23.0);
			float cx = (id + 0.5 + (h0 - 0.5) * 0.6) * w;
			float r = w * mix(0.7, 1.25, h1);
			// Overall height of the wall here (slow wave around the horizon).
			float base_h = wall_height * (1.0 - wall_variation * (0.5 + 0.5 * sin(cx * 0.031 + wall_seed) * sin(cx * 0.017 + 1.7 + wall_seed * 0.5)));
			float cy = layer == 0 ? base_h - r * 0.9 : base_h + r * 0.05 - r * 0.9 + w * 0.6 * h0;
			if (layer == 1 && h1 < 0.35) {
				continue;
			}
			vec2 d = vec2(az - cx, el - cy);
			float sd = r - length(d);
			if (sd > best) {
				best = sd;
				vec2 n = normalize(d + vec2(0.0001));
				// Light from the sun's side of the horizon, and from above.
				float side = clamp(az_delta(sun_az, cx) / 40.0, -1.0, 1.0);
				vec2 l = normalize(vec2(side, 0.6 + 0.02 * sun_el));
				lit = dot(n, l);
			}
		}
	}
	// Fill below the puffs: everything under the wall's base line.
	float cov = smoothstep(-0.12, 0.12, best);
	float edge = 1.0 - smoothstep(0.0, 0.9, best);
	return vec3(cov, step(0.05, lit), edge);
}

// A diamond-ish floating rock; returns signed distance (deg, < 0 inside).
float shard_sd(vec2 p, float s, float seed) {
	float wobble = 0.75 + 0.5 * hash11(seed * 7.1);
	vec2 q = vec2(p.x / (s * 0.55 * wobble), p.y / s);
	// Short top point, long bottom point.
	float top = abs(q.x) + max(q.y, 0.0) * 1.6;
	float bot = abs(q.x) + max(-q.y, 0.0) * 0.6;
	return (max(top, bot) - 1.0) * s * 0.5;
}

void sky() {
	vec3 dir = EYEDIR;
	float el = degrees(asin(clamp(dir.y, -1.0, 1.0)));
	float az = degrees(atan(dir.x, -dir.z));

	vec3 sun_dir = LIGHT0_ENABLED ? LIGHT0_DIRECTION : normalize(vec3(0.3, 0.3, -1.0));
	float sun_el = degrees(asin(clamp(sun_dir.y, -1.0, 1.0)));
	float sun_az = degrees(atan(sun_dir.x, -sun_dir.z));
	float sun_angle = degrees(acos(clamp(dot(dir, sun_dir), -1.0, 1.0)));

	// --- Gradient
	vec3 col = gradient(max(el, 0.0));
	// Stars only show through the dark, empty parts of a painted sky.
	float star_mask = 1.0;
	float sun_side = exp(-pow(az_delta(az, sun_az) / sun_side_width, 2.0));
	float low = 1.0 - smoothstep(0.0, upper_elevation, max(el, 0.0));
	col = mix(col, sun_side_color, sun_side * low * sun_side_strength);
	col = mix(col, glow_color, (1.0 - smoothstep(0.0, glow_elevation, abs(el))) * (0.6 + 0.4 * sun_side));
	if (el < 0.0) {
		col = mix(col, ground_color, smoothstep(0.0, 2.0, -el));
	}

	if (use_panorama) {
		float u = (az - sun_az + panorama_sun_u + panorama_turn) / 360.0;
		float v = 0.5 - (el - panorama_horizon) / 180.0;
		vec3 p = texture(panorama, vec2(u, clamp(v, 0.001, 0.999))).rgb;
		float l = dot(p, vec3(0.299, 0.587, 0.114));
		p = mix(vec3(l), p, panorama_saturation);
		p = (p - 0.5) * panorama_contrast + 0.5;
		p = max(p * panorama_tint * panorama_exposure, vec3(0.0));
		p = mix(p, p * col * 1.6, panorama_grade);
		col = el < 0.0 ? mix(p, col, smoothstep(0.0, 2.0, -el)) : p;
		star_mask = 1.0 - smoothstep(0.18, 0.35, dot(p, vec3(0.299, 0.587, 0.114)));
	}

	// --- Stars
	if (star_density > 0.0 && el > 0.0 && !AT_CUBEMAP_PASS) {
		vec3 cell = floor(dir * 420.0);
		float h = hash31(cell);
		if (h > 1.0 - star_density) {
			vec3 centre = (cell + 0.5) / 420.0;
			float d = length(dir - normalize(centre)) * 420.0;
			float twinkle = 0.7 + 0.3 * sin(TIME * (2.0 + h * 5.0) + h * 40.0);
			float s = (1.0 - smoothstep(0.0, 0.9, d)) * twinkle * star_brightness;
			col += vec3(s) * smoothstep(0.0, star_fade_elevation, el) * star_mask;
		}
	}

	// --- Sun: halo, lens ring, disc
	col += halo_color * halo_strength * exp(-sun_angle / max(halo_size * 0.35, 0.01)) * 0.8;
	col = mix(col, halo_color, ring_strength * (1.0 - smoothstep(0.0, ring_width, abs(sun_angle - ring_radius))));
	float disc = 1.0 - smoothstep(sun_size - sun_edge, sun_size + sun_edge, sun_angle);
	col = mix(col, sun_disc_color, disc);

	// --- Structures (far, behind the cloud wall). Two-tone cel: the half
	// facing the sun is lifted toward the rim colour, its edge gets a hard
	// rim line, and the base sinks into the horizon haze.
	float haze_t = 1.0 - smoothstep(0.0, 18.0, el);
	vec3 haze_col = mix(horizon_color, sun_side_color, sun_side * sun_side_strength);
	vec3 s_dark = mix(structure_color, haze_col, structure_haze * haze_t);
	vec3 s_lit = mix(s_dark, structure_rim, 0.35);
	// +1 when the sun is to the right of this point, -1 to the left.
	float sun_right = sign(az_delta(sun_az, az) + 0.0001);
	// Ring arch, in panels.
	if (ring.z > 0.0) {
		vec2 p = vec2(az_delta(az, ring.x) / ring_aspect, el - ring.y);
		float d = length(p) - ring.z;
		float inside = 1.0 - smoothstep(ring_thickness - 0.1, ring_thickness + 0.1, abs(d));
		if (inside > 0.0) {
			vec2 to_sun = normalize(vec2(az_delta(sun_az, ring.x) / ring_aspect, sun_el - ring.y) - p * 0.0 + vec2(0.0001));
			vec2 n = normalize(p + vec2(0.0001));
			// The outer skin faces away from the centre, the inner one toward it.
			float lit_body = step(0.0, dot(n, to_sun));
			vec3 c = mix(s_dark, s_lit, lit_body);
			float edge_n = sign(d);
			float rim = (1.0 - smoothstep(0.0, structure_rim_width, ring_thickness - abs(d))) * step(0.0, dot(n * edge_n, to_sun));
			c = mix(c, structure_rim, rim * 0.85);
			float ang = atan(p.y, p.x);
			float panel = 1.0 - smoothstep(0.0, 0.004, abs(fract(ang * 3.0) - 0.5) - 0.49);
			c = mix(c, s_dark * 0.8, panel * 0.6);
			float seam = 1.0 - smoothstep(0.0, 0.2, abs(d));
			float pulse = 0.7 + 0.3 * sin(TIME * 0.8 + ang * 6.0);
			c += structure_glow * structure_glow_strength * seam * pulse;
			col = mix(col, c, inside * step(-1.0, el));
		}
	}
	// Spire: tapered needle with two hub discs.
	if (spire.y > 0.0) {
		float x = az_delta(az, spire.x);
		float t = clamp(el / spire.y, 0.0, 1.0);
		float half_w = spire.z * 0.5 * pow(1.0 - t, 1.2) + 0.1;
		float disc_t = 0.0;
		for (int k = 0; k < 2; k++) {
			float at = k == 0 ? 0.42 : 0.7;
			float wd = spire.z * (k == 0 ? 1.7 : 1.15);
			float hgt = spire.y * 0.028;
			float dy = (el - at * spire.y) / hgt;
			// Lens-shaped disc: widest in the middle.
			float lens = wd * sqrt(max(1.0 - dy * dy, 0.0));
			disc_t = max(disc_t, step(abs(dy), 1.0) * step(abs(x), lens));
		}
		float inside = max((1.0 - smoothstep(half_w - 0.08, half_w + 0.08, abs(x))) * step(el, spire.y), disc_t) * step(-1.0, el);
		if (inside > 0.0) {
			float lit_body = step(0.0, x * sun_right);
			vec3 c = mix(s_dark, s_lit, lit_body);
			float rim = step(half_w - structure_rim_width, x * sun_right) * (1.0 - disc_t);
			c = mix(c, structure_rim, rim * 0.85);
			float lights = step(0.6, fract(t * 18.0)) * (1.0 - smoothstep(0.0, 0.2, abs(x))) * (1.0 - disc_t);
			c += structure_glow * structure_glow_strength * (lights + disc_t * 0.25);
			col = mix(col, c, inside);
		}
	}
	// Floating shards.
	for (int i = 0; i < 12; i++) {
		if (float(i) >= shard_count) {
			break;
		}
		float fi = float(i);
		float h0 = hash11(fi * 4.17 + 2.0);
		float h1 = hash11(fi * 9.31 + 5.0);
		vec2 c0 = vec2(shards.x + (h0 - 0.5) * 2.0 * shards.z, shards.y + (h1 - 0.5) * shards.z * 0.6);
		c0.y += sin(TIME * 0.25 + fi * 1.9) * shard_bob;
		float s = shard_size * mix(0.4, 1.3, hash11(fi * 1.7 + 11.0)) * (1.0 - 0.4 * fi / max(shard_count, 1.0));
		vec2 p = vec2(az_delta(az, c0.x), el - c0.y);
		float d = shard_sd(p, s, fi);
		float inside = 1.0 - smoothstep(-0.08, 0.08, d);
		if (inside > 0.0) {
			float lit_body = step(0.0, p.x * sun_right);
			vec3 c = mix(s_dark, s_lit, lit_body);
			float rim = step(-structure_rim_width, d) * lit_body;
			c = mix(c, structure_rim, rim * 0.85);
			c += structure_glow * structure_glow_strength * (1.0 - smoothstep(0.0, 0.2, abs(p.y + s * 0.15))) * 0.6;
			col = mix(col, c, inside);
		}
	}

	// --- Cloud wall on the horizon
	vec3 wall = cloud_wall(az, el, sun_az, sun_el);
	if (wall.x > 0.0) {
		vec3 c = mix(wall_shadow, wall_light, wall.y);
		c = mix(c, mix(wall_light, sun_side_color, 0.5), sun_side * 0.35 * wall.y);
		c = mix(wall_base, c, smoothstep(0.0, wall_base_fade, el));
		c = mix(c, wall_outline_color, wall_outline * (1.0 - smoothstep(0.0, 0.18, 1.0 - wall.z)) * step(0.0, el));
		col = mix(col, c, wall.x);
	}

	// --- Overhead cel clouds
	if (cloud_coverage > 0.0 && el > 0.0) {
		vec2 uv = dir.xz / (dir.y + 0.12);
		uv = uv / cloud_stretch * cloud_scale + TIME * cloud_wind;
		float n = texture(cloud_noise, uv).r;
		vec2 sun_step = normalize(sun_dir.xz + vec2(0.0001)) * cloud_shade_offset;
		float n_sun = texture(cloud_noise, uv + sun_step).r;
		float thr = 1.0 - cloud_coverage;
		float mask = smoothstep(thr - cloud_softness, thr + cloud_softness, n);
		mask *= smoothstep(0.0, cloud_horizon_fade, el);
		if (mask > 0.0) {
			// Thicker toward the sun = this side is in shadow.
			float shade = smoothstep(-0.01 - cloud_softness, 0.01 + cloud_softness, n_sun - n);
			vec3 c = mix(cloud_light, cloud_shadow, shade);
			float rim = (1.0 - smoothstep(thr, thr + cloud_rim_width, n)) * (1.0 - shade);
			c = mix(c, cloud_rim_color, rim * cloud_rim_strength);
			float ink = cloud_outline > 0.0 ? 1.0 - smoothstep(thr + cloud_outline * 0.5, thr + cloud_outline, n) : 0.0;
			c = mix(c, cloud_outline_color, ink);
			c = mix(c, haze_col, cloud_haze * (1.0 - smoothstep(0.0, 35.0, el)));
			col = mix(col, c, mask);
		}
	}

	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	COLOR = max(mix(vec3(lum), col, sky_saturation), vec3(0.0)) * sky_exposure;
}
