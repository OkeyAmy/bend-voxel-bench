# Results

## First race (2026-09-24)

```
World generation (terrain) · seed 42 · x,z -32..367, y -112..207 (100 mapchunks) · Intel(R) Core(TM) i7-8665U CPU @ 1.90GHz

lane       terrain ms  min     max     spread  end-to-end ms  peak MB  terrain vs Luanti  ok runs
bend·1t    1301.0      1296.0  1366.0  5.4 %   1301.0         28.7     0.10× slower       5/5    
luanti·1t  131.4       127.3   133.0   4.5 %   971.2          159.6    reference          5/5    
bend·8t    534.0       520.0   565.0   8.7 %   534.0          37.4     0.32× slower       5/5    
luanti·8t  172.6       160.8   175.7   9.3 %   766.6          226.0    reference          5/5    

parity (bend·1t vs luanti·1t): 100.0000 % of 640000 columns identical, 0 differ
note: terrain = noise maps + block fill per mapchunk (Luanti: MapgenV7::generateTerrain, summed over mapchunks; Bend: wall time of the whole parallel generation)
```

Machine: Intel i7-8665U laptop (4 cores, 8 threads), Fedora 44, on AC power, `performance` CPU governor. Bend 2.0.27 against Luanti 5.17.0 built from source, seed 42, 100 mapchunks (51.2 million blocks), 1 warm-up plus 5 interleaved runs per lane, each run a fresh process on a fresh world.

**G1 (parity) passed.** Bend's world is identical to real Luanti's, 0 of 640,000 columns different. **G3 (spread) did not meet the strict 5 % bound.** The worst lane was 9.3 % in this run and 7.9 % in a second run (`results/2026-09-24T12-41-37_*.json`), with medians within 4 % of this one. Both runs stay under the 10 % bound. The laptop had other programs running (load average about 2 before the race), which is the likely cause.

**Headline: same work, same output, both single-threaded. Bend's terrain generation takes 1,301 ms and Luanti's takes 131 ms, so Bend is about 10× slower.** With 8 threads, compare end-to-end times instead of the terrain column, because Luanti's terrain sum is thread time. Bend finishes in 534 ms against Luanti's 767 ms. That comparison isn't clean: Luanti's end-to-end also covers its liquid step, emerge queueing, and a second pass for blocks that another thread was already generating. Bend's 2.4× speedup from 1 to 8 threads is its own measured result on this machine.
