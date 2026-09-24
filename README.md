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
| G | the live race: Bend and real Luanti generate the 100 mapchunks around you, right now (about 30 s; the game waits) |
| Esc | quit |

## The panel

```
FPS 55  BUILD 5 MS  DRAW 13 MS
NEW MAPCHUNK GEN+MESH 16 MS
LIVE RACE AT -30112,29968  BEND 1T 1321.0 MS  8T 501.0 MS  LUANTI C++ 1T 130.6 MS
TERRAIN, 100 MAPCHUNKS  SAME BLOCKS 100.00 %  AC POWER  LOAD 1.62
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

Before your first G, the race lines show the stored race from `out/race.txt`.
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
