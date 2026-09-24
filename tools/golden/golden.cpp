// Verbatim copies of Luanti 5.17.0 src/noise.cpp: noise2d, easeCurve (noise.h),
// linearInterpolation, biLinearInterpolation, valueMap2D, noiseMap2D, updateResults.
// Prints F32 bits of mapgen v7 terrain noise maps for one 80x80 mapchunk.
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cstdint>
typedef int32_t s32; typedef uint32_t u32;
#define NOISE_MAGIC_X    1619
#define NOISE_MAGIC_Y    31337
#define NOISE_MAGIC_SEED 1013U
float noise2d(int x, int y, s32 seed) {
	unsigned int n = (NOISE_MAGIC_X * x + NOISE_MAGIC_Y * y
			+ NOISE_MAGIC_SEED * seed) & 0x7fffffff;
	n = (n >> 13) ^ n;
	n = (n * (n * n * 60493 + 19990303) + 1376312589) & 0x7fffffff;
	return 1.f - (float)(int)n / 0x40000000;
}
inline float easeCurve(float t) { return t * t * t * (t * (6.f * t - 15.f) + 10.f); }
inline float linearInterpolation(float v0, float v1, float t) { return v0 + (v1 - v0) * t; }
inline float biLinearInterpolation(float v00, float v10, float v01, float v11, float x, float y, bool eased) {
	if (eased) { x = easeCurve(x); y = easeCurve(y); }
	float u = linearInterpolation(v00, v10, x);
	float v = linearInterpolation(v01, v11, x);
	return linearInterpolation(u, v, y);
}
struct NP { float offset, scale, spread; s32 seed; int octaves; float persist, lacunarity; };
struct Noise {
	NP np; s32 seed; u32 sx, sy; float *noise_buf, *value_buf, *persist_buf = nullptr, *result;
	Noise(NP p, s32 s, u32 x, u32 y) : np(p), seed(s), sx(x), sy(y) {
		noise_buf = new float[1 << 16]; value_buf = new float[x * y]; result = new float[x * y];
	}
#define idx(x, y) ((y) * nlx + (x))
	void valueMap2D(float x, float y, float step_x, float step_y, s32 seed) {
		float v00, v01, v10, v11, u, v, orig_u;
		u32 index, i, j, noisex, noisey; u32 nlx, nly; s32 x0, y0;
		bool eased = true;
		x0 = std::floor(x); y0 = std::floor(y);
		u = x - (float)x0; v = y - (float)y0; orig_u = u;
		nlx = (u32)(u + sx * step_x) + 2; nly = (u32)(v + sy * step_y) + 2;
		index = 0;
		for (j = 0; j != nly; j++) for (i = 0; i != nlx; i++) noise_buf[index++] = noise2d(x0 + i, y0 + j, seed);
		index = 0; noisey = 0;
		for (j = 0; j != sy; j++) {
			v00 = noise_buf[idx(0, noisey)]; v10 = noise_buf[idx(1, noisey)];
			v01 = noise_buf[idx(0, noisey + 1)]; v11 = noise_buf[idx(1, noisey + 1)];
			u = orig_u; noisex = 0;
			for (i = 0; i != sx; i++) {
				value_buf[index++] = biLinearInterpolation(v00, v10, v01, v11, u, v, eased);
				u += step_x;
				if (u >= 1.0) {
					u -= 1.0; noisex++; v00 = v10; v01 = v11;
					v10 = noise_buf[idx(noisex + 1, noisey)]; v11 = noise_buf[idx(noisex + 1, noisey + 1)];
				}
			}
			v += step_y;
			if (v >= 1.0) { v -= 1.0; noisey++; }
		}
	}
#undef idx
	void updateResults(float g, float *gmap, const float *persistence_map, size_t bufsize) {
		if (persistence_map) {
			for (size_t i = 0; i != bufsize; i++) { result[i] += gmap[i] * value_buf[i]; gmap[i] *= persistence_map[i]; }
		} else {
			for (size_t i = 0; i != bufsize; i++) result[i] += g * value_buf[i];
		}
	}
	float *noiseMap2D(float x, float y, float *persistence_map = nullptr) {
		float f = 1.0, g = 1.0; size_t bufsize = sx * sy;
		x /= np.spread; y /= np.spread;
		memset(result, 0, sizeof(float) * bufsize);
		if (persistence_map) { if (!persist_buf) persist_buf = new float[bufsize]; for (size_t i = 0; i != bufsize; i++) persist_buf[i] = 1.0; }
		for (size_t oct = 0; oct < (size_t)np.octaves; oct++) {
			valueMap2D(x * f, y * f, f / np.spread, f / np.spread, seed + np.seed + oct);
			updateResults(g, persist_buf, persistence_map, bufsize);
			f *= np.lacunarity; g *= np.persist;
		}
		if (std::fabs(np.offset - 0.f) > 0.00001 || std::fabs(np.scale - 1.f) > 0.00001)
			for (size_t i = 0; i != bufsize; i++) result[i] = result[i] * np.scale + np.offset;
		return result;
	}
};
static u32 bits(float f) { u32 b; memcpy(&b, &f, 4); return b; }
int main(int argc, char **argv) {
	s32 seed = argc > 1 ? (s32)strtoll(argv[1], 0, 10) : 42;
	float ox = argc > 2 ? atof(argv[2]) : -32, oz = argc > 3 ? atof(argv[3]) : -32;
	NP persist{0.6f, 0.1f, 2000, 539, 3, 0.6f, 2.0f}, base{4.0f, 70.0f, 600, 82341, 5, 0.6f, 2.0f},
	   alt{4.0f, 25.0f, 600, 5934, 5, 0.6f, 2.0f}, hsel{-8.0f, 16.0f, 500, 4213, 6, 0.7f, 2.0f};
	Noise np_(persist, seed, 80, 80), nb(base, seed, 80, 80), na(alt, seed, 80, 80), nh(hsel, seed, 80, 80);
	float *pm = np_.noiseMap2D(ox, oz);
	nb.noiseMap2D(ox, oz, pm); na.noiseMap2D(ox, oz, pm); nh.noiseMap2D(ox, oz);
	for (int i = 0; i < 6400; i++) {
		// baseTerrainLevelFromMap + (s16) truncation, as in MapgenV7::generateTerrain
		float hs = nh.result[i]; hs = hs < 0.0f ? 0.0f : (hs > 1.0f ? 1.0f : hs);
		float hb = nb.result[i], ha = na.result[i];
		float lvl = ha > hb ? ha : (hb * hs) + (ha * (1.0f - hs));
		printf("%u %u %u %u %d\n", bits(pm[i]), bits(hb), bits(ha), bits(nh.result[i]), (int)(short)lvl);
	}
}
