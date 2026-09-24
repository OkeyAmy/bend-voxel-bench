# Bend Voxel Bench

**An experiment to understand [Bend2](https://github.com/bendlang/bend)**, the new
language from HigherOrderCO (released September 2026), by building something real
with it and measuring it honestly.

We ported the terrain generator of [Luanti](https://www.luanti.org) (a C++ voxel
game) to Bend, built a small flyable voxel world on top of it, and raced Bend
against real Luanti. This is not a product. It's a test bench and a learning log.

- **What we learned about Bend** (gaps, traps, measurements, comparisons with the
  tools people use today): [`docs/bend-notes.md`](docs/bend-notes.md)
- **The race results:** [`RESULTS.md`](RESULTS.md) and `results/*.json`

## What we found, in short

| Question | Answer |
|---|---|
| Can Bend match C++ exactly? | Yes. Luanti's noise and terrain ported to Bend give **bit-identical** worlds (100 % of blocks) |
| How fast is it? | Terrain for 100 mapchunks: **Bend 1,321 ms on 1 thread vs Luanti C++ 131 ms**, about 10× slower. Bend speeds itself up about 2.5× on 8 threads |
| Can it run a 3D game on a CPU only? | Yes. A 5 × 5-mapchunk world at 1280 × 720 runs at about 50 FPS on a 2019 laptop CPU (Bend3D, no GPU) |
| What's hard? | No signed integers, arrays are trees, few type inferences, a tiny font, no way to start programs (we wrote a C effect), and a type checker with no work limit that froze the machine once ([bendlang/bend#1041](https://github.com/bendlang/bend/issues/1041)) |

Everything runs on Linux x86_64 on the CPU. No graphics card is needed.

## Play

Run everything from the repo root (the game finds `harness/` and `out/` there):

```sh
curl -fsSL https://bend-lang.com/install.sh | sh   # Bend 2.0.27 is the pinned version
bend engine/main.bend -o build/voxel               # about 30 s the first time
./build/voxel --threads 8 --gpu off -- play        # the cliffs of seed 123456789
./build/voxel --threads 8 --gpu off -- play 42
```

The live race (G) also needs Node 22 and Luanti built once with `./luanti/build.sh`.

| Key | Does |
|---|---|
| W A S D | fly forward, left, back, right |
| arrows | look around |
| Q / E | down / up |
| G | the live race: Bend and real Luanti generate the 100 mapchunks around you, right now (about 30 s; the game waits) |
| Esc | quit |

## The panel

```
FPS 55  BUILD 5 MS  DRAW 13 MS
NEW MAPCHUNK GEN+MESH 16 MS
LIVE RACE AT -30272,29808  BEND 1T 1321.0 MS  8T 501.0 MS  LUANTI C++ 1T 130.6 MS
TERRAIN, 100 MAPCHUNKS  SAME BLOCKS 100.00 %  AC POWER  LOAD 1.62  PERFORMANCE
```

- **FPS, BUILD, DRAW:** each frame, the main thread turns the visible blocks into
  triangles (build), then one parallel Bend call draws the whole screen (draw).
  This is Bend only. It's never compared with Luanti, which draws on the GPU.
- **NEW MAPCHUNK:** the time to generate and mesh the last 80 × 80 piece of land
  that appeared as you flew.
- **LIVE RACE (after G):** the game runs `harness/live_race.ts` through `Proc.run`
  (a custom Bend effect, `engine/sys/`). Bend and real Luanti each generate the
  terrain of the same 100 mapchunks around you, in fresh processes, several times,
  one after the other. The median times are shown.
- **SAME BLOCKS:** every block Bend made is compared with Luanti's.
- **AC POWER, LOAD:** the conditions the race ran under. Battery power or
  background programs make the numbers slower and noisier.

Before your first G, the race lines show the stored race from `out/race.txt`,
labelled `STORED RACE <commit>` so it can't be mistaken for a live one.
To make `out/race.txt` (the stored race):

```sh
./luanti/build.sh                                  # once: Luanti 5.17.0 + timing patch
node harness/arena.ts race --runs 5 --threads 1,8  # the race (writes results/*.json)
node harness/hud_export.ts                         # results -> out/race.txt
```

## Tests

```sh
node --test --test-concurrency=1 tests/*.test.ts
```

Every `bend` call runs under a 4 GB memory cap and a timeout (`harness/build.ts`).
Bend's checker has no work limit ([bendlang/bend#1041](https://github.com/bendlang/bend/issues/1041)),
and one type error froze this laptop before the cap existed.

## Layout

| Path | What |
|---|---|
| `engine/noise.bend`, `engine/mapgen.bend` | Luanti 5.17.0 noise and mapgen v7, ported (LGPL-2.1+) |
| `engine/bench.bend` | the headless world-generation race |
| `engine/world/` | loaded mapchunks and streaming around the player |
| `engine/render/` | mesher, culling, level of detail, fog, Bend3D (Apache-2.0) |
| `engine/hud.bend`, `engine/game.bend` | the panel and the window |
| `harness/` | the race runner (Node 22), Luanti lane, dump verifier |
| `luanti/` | the pinned Luanti build, timing patch and probe mod |
