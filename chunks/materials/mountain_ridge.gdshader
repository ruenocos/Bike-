shader_type spatial;
// Distant mountain range (MountainRing, v0.31 sky pass): an open cylinder
// band around the camera whose top edge is cut into sharp anime-style peaks.
// Each peak is a pair of flat faces, cel-lit: the face toward the sun is
// lifted toward `lit_color`, the other stays `peak_color`, with a hard rim
// line on the lit ridge and snow caps above `snow_line`. The base sinks into
// `haze_color` so the range melts into the sky's horizon. No fog, no scene
// lighting: it's a painted backdrop, so the sun direction comes in as a
// uniform (BiomeLook sets it).
render_mode unshaded, fog_disabled, cull_disabled;

uniform vec3 peak_color : source_color = vec3(0.36, 0.38, 0.52);
uniform vec3 lit_color : source_color = vec3(0.95, 0.75, 0.6);
/// How far the sun-facing faces move toward lit_color.
uniform float lit_amount : hint_range(0.0, 1.0, 0.01) = 0.45;
uniform vec3 haze_color : source_color = vec3(0.86, 0.66, 0.56);
/// How far up the haze reaches (0 = none, 1 = to the top).
uniform float haze_height : hint_range(0.0, 1.0, 0.01) = 0.7;
uniform vec3 rim_color : source_color = vec3(1.0, 0.88, 0.7);
uniform float rim_width : hint_range(0.0, 0.05, 0.001) = 0.006;
uniform vec3 snow_color : source_color = vec3(0.95, 0.95, 1.0);
/// Snow above this share of the band height (1 = no snow).
uniform float snow_line : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform vec3 sun_direction = vec3(0.4, 0.3, -0.8);
/// Big peaks around the ring (MountainRing count).
uniform float peaks = 46.0;
/// Lowest / highest peak, as a share of the band height.
uniform float height_min : hint_range(0.0, 1.0, 0.01) = 0.35;
uniform float height_max : hint_range(0.0, 1.0, 0.01) = 1.0;
/// Steepness of the faces (bigger = sharper, narrower peaks).
uniform float steepness : hint_range(0.5, 20.0, 0.1) = 5.0;
uniform float ring_seed = 5.0;
/// A second, taller range behind the first (0 = off): its height as a
/// share of the band, and how much more haze it takes.
uniform float back_height : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float back_haze : hint_range(0.0, 1.0, 0.01) = 0.55;
/// The front range's height as a share of the band.
uniform float front_height : hint_range(0.1, 1.0, 0.01) = 0.62;

/// Share of the band (from the bottom) that is a plain haze skirt reaching
/// far down, so the range never floats over the sea of clouds.
uniform float skirt : hint_range(0.0, 0.95, 0.01) = 0.0;

varying vec3 local_pos;
varying vec3 world_pos;

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

// Ridge height at position x (in peak cells, wraps every `period` cells)
// as the max of triangular peaks. Returns (height, side: -1 left face /
// +1 right face, peak id).
vec3 ridge(float x, float period, float hmin, float hmax, float steep, float seed) {
	float best = -1.0;
	float side = 1.0;
	float id_best = 0.0;
	float cell = floor(x);
	for (int i = -2; i <= 2; i++) {
		float id = cell + float(i);
		float wid = mod(id, period);
		float h0 = hash11(wid * 1.31 + seed * 7.7);
		float h1 = hash11(wid * 4.77 + seed * 3.1);
		float h2 = hash11(wid * 9.13 + seed * 1.9);
		float cx = id + 0.5 + (h0 - 0.5) * 0.7;
		float h = mix(hmin, hmax, h1 * h1);
		// Asymmetric slopes for a less regular skyline.
		float dx = x - cx;
		float s = steep * (dx < 0.0 ? mix(0.7, 1.3, h2) : mix(1.3, 0.7, h2));
		float v = h - abs(dx) * s * 0.1;
		if (v > best) {
			best = v;
			side = sign(dx + 0.00001);
			id_best = wid;
		}
	}
	return vec3(best, side, id_best);
}

void vertex() {
	local_pos = VERTEX;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// CylinderMesh: y from -0.5 to 0.5 (scaled by the node), so read the
	// band height from the mesh's own extent via the model scale.
	float az = atan(local_pos.x, local_pos.z) / TAU + 0.5;
	float y = (local_pos.y + 0.5 - skirt) / (1.0 - skirt);
	bool skirt_px = y < 0.0;
	y = max(y, 0.0);
	float x = az * peaks;
	float fh = back_height > 0.0 ? front_height : 1.0;
	vec3 big = ridge(x, peaks, height_min * fh, height_max * fh, steepness, ring_seed);
	// Smaller shoulders on the slopes.
	vec3 small = ridge(x * 3.0, peaks * 3.0, height_min * 0.6 * fh, height_max * 0.75 * fh, steepness * 1.1, ring_seed + 11.0);
	vec3 r = big;
	if (small.x > big.x) {
		r = small;
	}
	bool back = false;
	if (y > r.x) {
		if (back_height <= 0.0) {
			discard;
		}
		// The far range: broader peaks, offset seed.
		float nb = max(floor(peaks * 0.6), 1.0);
		float xb = az * nb;
		vec3 rb = ridge(xb, nb, height_min * back_height, back_height, steepness * 1.3, ring_seed + 31.0);
		vec3 rbs = ridge(xb * 3.0, nb * 3.0, height_min * 0.7 * back_height, back_height * 0.8, steepness * 1.2, ring_seed + 41.0);
		if (rbs.x > rb.x) {
			rb = rbs;
		}
		if (y > rb.x) {
			discard;
		}
		r = rb;
		back = true;
	}
	// Face normal: toward the camera (inward), tilted sideways by the face
	// and up a little.
	vec3 radial = normalize(vec3(local_pos.x, 0.0, local_pos.z));
	vec3 tangent = normalize(cross(vec3(0.0, 1.0, 0.0), radial));
	vec3 n_local = normalize(-radial * 0.55 + tangent * r.y * 0.75 + vec3(0.0, 0.35, 0.0));
	vec3 n = normalize((MODEL_MATRIX * vec4(n_local, 0.0)).xyz);
	float lit = step(0.05, dot(n, normalize(sun_direction)));
	vec3 c = mix(peak_color, mix(peak_color, lit_color, lit_amount), lit);
	float depth = r.x - y;
	// Snow caps, lit/shadow.
	float sl = snow_line * (back ? back_height : fh);
	float snow = step(sl, y);
	vec3 snow_c = mix(snow_color * 0.78 + peak_color * 0.12, snow_color, lit);
	c = mix(c, snow_c, snow);
	// Rim on the sun-lit ridge line.
	c = mix(c, rim_color, (1.0 - step(rim_width, depth)) * lit);
	// Haze toward the base.
	float top = back ? back_height : fh;
	float t = smoothstep(0.0, haze_height * top, y);
	if (back) {
		t *= 1.0 - back_haze;
	}
	ALBEDO = skirt_px ? haze_color : mix(haze_color, c, t);
}
