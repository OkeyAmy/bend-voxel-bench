# Results

## First race (2026-09-24, commit 6c3dcc9)

```
World generation (terrain) · seed 42 · x,z -32..367, y -112..207 (100 mapchunks) · Intel(R) Core(TM) i7-8665U CPU @ 1.90GHz

lane       terrain ms  min     max     spread  end-to-end ms  peak MB  terrain vs Luanti          ok runs
bend·1t    1350.0      1275.0  1382.0  8.4 %   -              28.8     0.10× slower               5/5    
luanti·1t  131.1       127.3   132.2   3.9 %   964.8          159.8    reference                  5/5    
bend·8t    530.0       522.0   547.0   4.8 %   -              37.3     n/a (Luanti: thread time)  5/5    
luanti·8t  164.9       158.9   169.0   6.3 %   752.9          227.4    reference                  5/5    

parity (bend·1t vs luanti·1t): 100.0000 % of 640000 columns identical, 0 differ
parity (bend·8t vs luanti·1t): 100.0000 % of 640000 columns identical, 0 differ
parity (luanti·8t vs luanti·1t): 100.0000 % of 640000 columns identical, 0 differ
note: terrain = noise maps + block fill per mapchunk (Luanti: MapgenV7::generateTerrain, summed over mapchunks; Bend: wall time of the whole parallel generation)
note: with more than 1 thread, Luanti's terrain number is a sum of per-mapchunk thread time, not wall time, so there is no multi-thread terrain ratio
note: Luanti end-to-end = emerge_area call to last callback (terrain, liquid step, queueing, and a re-emerge pass for cancelled blocks); Bend has no liquid step or queue, so it has no end-to-end number
note: build flags: Luanti 5.17.0 CMake Release (-O3 -funroll-loops -fomit-frame-pointer -fno-math-errno -fno-trapping-math -fno-signed-zeros) + luanti/timing.patch; Bend: bend engine/main.bend -o build/voxel (Bend's own clang flags)
```

Machine: Intel i7-8665U laptop (4 cores, 8 threads), Fedora 44, on AC power, `performance` CPU governor. Bend 2.0.27 against Luanti 5.17.0 built from source, seed 42, 100 mapchunks (51.2 million blocks), 1 warm-up plus 5 interleaved runs per lane, each run a fresh process on a fresh world. Raw data: `results/2026-09-24T12-51-03_6c3dcc9.json`.

**G1 (parity) passed on every lane.** Bend's world, at 1 and 8 threads, is identical to real Luanti's, 0 of 640,000 columns different. **G3 (spread) did not meet the strict 5 % bound.** The worst lane was 8.4 %, all lanes stayed under 10 %, and other programs were running on the laptop.

**Headline: same work, same output, both single-threaded. Bend's terrain generation takes 1,350 ms and Luanti's takes 131 ms, so Bend is about 10× slower.**

**Multi-thread: Bend goes from 1,350 ms to 530 ms with 8 threads, a 2.5× speedup on its own.** This race has no fair 8-thread Bend-vs-Luanti number:
- Luanti's terrain figure is a sum of per-mapchunk thread time, not wall time.
- Luanti's end-to-end figure also includes its liquid step, emerge queueing, and a re-emerge pass. Bend has none of those.

Earlier result files from this branch without the `6c3dcc9` commit were made before the harness checked every lane and before these columns were corrected. Use them only as raw timings.
