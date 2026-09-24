# Bend Voxel Bench

A Luanti-style voxel world written in [Bend2](https://github.com/bendlang/bend),
raced against real [Luanti](https://www.luanti.org) (C++). The game exists so
we can learn how Bend2 works on a real program. What we learned is in
[`docs/bend-notes.md`](docs/bend-notes.md).

Everything runs on Linux x86_64 on the CPU. No graphics card is needed.

## Play

```sh
bend engine/main.bend -o build/voxel          # about 30 s the first time
./build/voxel --threads 8 --gpu off -- play   # the cliffs of seed 123456789
./build/voxel --threads 8 --gpu off -- play 42
```

| Key | Does |
|---|---|
| W A S D | fly forward, left, back, right |
| arrows | look around |
| Q / E | down / up |
| G | race: drop the 25 mapchunks around you and time Bend regenerating them |
| Esc | quit |

## The panel

```
FPS 43  BUILD 6 MS  DRAW 17 MS
NEW MAPCHUNK GEN+MESH 16 MS
RACE PER MAPCHUNK  BEND 13.5 MS  8T 5.3 MS  LUANTI C++ 1.3 MS
SAME BLOCKS AS LUANTI 100.00 %
RACE 25/25  BEND GEN+MESH 585 MS  LUANTI C++ TERRAIN 32.7 MS
```

- **FPS, BUILD, DRAW:** each frame, the main thread turns the visible blocks into
  triangles (build), then one parallel Bend call draws the whole screen (draw).
  More threads make DRAW faster: that's Bend's parallelism at work.
- **NEW MAPCHUNK:** the time to generate and mesh the last 80 × 80 piece of land
  that appeared as you flew.
- **RACE PER MAPCHUNK:** from our race against Luanti, terrain generation only,
  the same work on both sides. Bend is about 10× slower than C++ on one thread and
  speeds itself up about 2.5× on 8.
- **SAME BLOCKS AS LUANTI:** Bend's world is bit-for-bit identical to Luanti's.
- **RACE (after pressing G):** Bend's number includes meshing; Luanti's is terrain
  only, so the line says both.

The race numbers come from `out/race.txt`. Make it with:

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
