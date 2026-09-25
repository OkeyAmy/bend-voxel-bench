# Bend Voxel Bench

We wanted to learn [Bend2](https://github.com/bendlang/bend) (HigherOrderCO,
September 2026) by writing something real in it. Bend2 says two things about
itself: it runs about as fast as C on one core, and its proof checker stops
mistakes (including an AI's) from getting into the code. We tried both.

We ported the terrain generator of [Luanti](https://www.luanti.org), a C++ voxel
game, to Bend, put a small world you can fly around on top of it, and timed Bend
against the real Luanti. Then we gave the game rules (laws) and tried to break them.

- Our notes on Bend, with the traps we hit: [`docs/bend-notes.md`](docs/bend-notes.md)
- Race results: [`RESULTS.md`](RESULTS.md) and `results/*.json`

## What we found, in short

| Question | Answer |
|---|---|
| Can Bend match C++ exactly? | Yes. Luanti's noise and terrain ported to Bend give **bit-identical** worlds (100 % of blocks) |
| How fast is it? | Terrain for 100 mapchunks: **Bend 1,653 ms on 1 thread vs Luanti C++ 161 ms**, about 10× slower (race 2, laptop at load 2.26). Bend speeds itself up about 2.2× on 8 threads |
| Can it run a 3D game on a CPU only? | Yes. A 5 × 5-mapchunk world at 1280 × 720 runs at about 50 FPS on a 2019 laptop CPU (Bend3D, no GPU) |
| What's hard? | No signed integers, arrays are trees, few type inferences, a tiny font, no way to start programs (we wrote a C effect), and a type checker with no work limit that froze the machine once ([bendlang/bend#1041](https://github.com/bendlang/bend/issues/1041)) |
| Does the proof checker stop bad changes? | It stops code that disagrees with the laws. 13 laws check in about 1 s, and changes that let you fall through the ground or walk through walls don't build. It doesn't stop anyone from editing the laws themselves, and nothing about floats can be proven. See [What we learned about laws](#what-we-learned-about-laws) |

Everything runs on Linux x86_64 on the CPU. No graphics card is needed.

## What the numbers mean

Every table in [`RESULTS.md`](RESULTS.md) is one job done twice, by two programs:
turn seed `42` into terrain for the same 100 mapchunks, 640,000 columns, 51.2
million blocks. Both sides do exactly that job: compute the noise, then fill every
block with stone, water or air. Nothing else is timed: no lighting, no liquids, no
drawing, no window.

| Column | In plain words |
|---|---|
| `terrain ms` | How long the job took, in milliseconds, the **middle** of the runs (the median), so one lucky or unlucky run can't decide the answer. Lower is faster. |
| `min` / `max` | The quickest and the slowest of the runs. |
| `spread` | How much the runs disagreed with each other: `(max − min) ÷ min`, in percent. Under about 5 % means the laptop was left alone. Above that, something else was using the CPU and the times wobble. |
| `end-to-end ms` | Luanti only: from the moment the game asks for that area until the last block arrives, including its liquid step, its emerge queue, and a second pass for blocks another thread had already started. Bend has none of those, so its cell is a dash. |
| `peak MB` | The most memory the program used, in megabytes. |
| `terrain vs Luanti` | The comparison. `reference` means "this row is the number the others are divided by". `0.10× slower` means Luanti's time ÷ Bend's time = 0.10, in words, Bend takes about **ten times as long**. `n/a` on the 8-thread rows is deliberate: there Luanti's figure is a **sum of per-thread time**, not the wall clock, so dividing it by Bend's wall clock would compare two different things. |
| `ok runs` | How many runs finished correctly. Only runs that pass feed the statistics; a run that failed, timed out, or produced the wrong world never counts as a time. |
| `parity … 640000 columns identical, 0 differ` | Correctness, not speed. Every column of Bend's world is compared with Luanti's, block by block. `100.0000 %` and `0 differ` means Bend built **exactly** the world the C++ game builds. |
| `power ac, governor performance, load 2.26` | The conditions when it ran: plugged into the wall, CPU allowed to run at full speed, and `load` = how many processes wanted a CPU on average (8 would mean all eight threads were busy). Wide spreads with a high load are the machine's fault, not the program's. |

Two things the table deliberately never does: it never divides Bend's wall clock by
Luanti's multi-thread sum (different quantities), and it never puts Bend's FPS next
to Luanti's, because Luanti draws on a graphics card and Bend draws on the CPU.
The full checklist is in [`docs/bend-notes.md`](docs/bend-notes.md) §6b.

## Play

Run everything from the repo root. The game looks for `harness/` and `out/` there.

```sh
curl -fsSL https://bend-lang.com/install.sh | sh   # Bend 2.0.27 is the pinned version
bend engine/PROOF.bend                             # the game's laws must prove themselves (1 s)
bend engine/main.bend -o build/voxel               # about 30 s the first time
./build/voxel --threads 8 --gpu off -- play        # the cliffs of seed 123456789
./build/voxel --threads 8 --gpu off -- play 42
```

The live race (G) also needs Node 22 and Luanti built once with `./luanti/build.sh`.

| Key | Does |
|---|---|
| W A S D | move forward, left, back, right (walls two or more blocks high stop you) |
| arrows | look around |
| Q / E | down / up |
| G | the live race: Bend and real Luanti generate the 100 mapchunks around you, right now (about 30 s; the game waits) |
| Esc | quit |

## The panel

An example of what it looks like (numbers from an earlier run; the race you run
today will print its own):

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

## What we learned about laws

`engine/LAWS.bend` holds the rules, written as `law`s. `engine/PROOF.bend` has one
proof per law. The check is:

```sh
bend engine/PROOF.bend                 # prints "All terms check." when every proof holds
```

`harness/build.ts` runs it before building the game, so a failed check means no game.
`tests/laws.test.ts` runs it too.

What the 13 laws cover now:

- terrain: the block selectors, the stone rule, packing at index 0, and `M.levels`
  keeping its list length
- movement: you stop on the ground under you and don't go below it; a column two
  or more blocks above you is a wall, and walking into it leaves you where you were;
  on open ground the keys still move you

What we learned by using them:

1. A law does nothing while you play. It's checked when you build, for every
   possible input at once, and then thrown away. The game runs at the same speed.
2. Writing a law doesn't change the game. When we added the wall laws before the
   code, the check refused ("4 TODOs found", then a failed proof) until the code
   did what the laws said. After that the walls worked.
3. The check compares the laws with the code. It doesn't care who wrote either.
4. A new feature can break an old law. Adding walls made the old ground law false
   (it looked at the ground where the keys lead, and at a wall you don't go there),
   so we had to decide what it should say now.
5. It can be got around. We tried three things on copies of the engine:
   - removing the wall code and deleting the wall laws passes the check
   - removing the wall code without running the check still builds the game,
     because nothing but `PROOF.bend` reads the laws
   - changing "one block" to "1000 blocks" in both the code and the law passes

   So the laws file is the thing to guard. Review every change to it, and run the
   check in CI so nothing merges without it.
6. Write the "it still works" law too. The wall laws alone would be satisfied by a
   camera that never moves, so there are also laws saying open ground lets you move.
7. Floats can't be proven. Even `1.0 + 2.0 == 3.0` is refused, so the noise maths
   and the 0.6 blocks-per-frame speed are outside the laws. The laws only cover
   choices like "stay or move".
8. Proving that `heights` returns 6400 levels ran past the 4 GB cap in 13 s. It
   would need smaller facts proven first.

## Layout

| Path | What |
|---|---|
| `engine/noise.bend`, `engine/mapgen.bend` | Luanti 5.17.0 noise and mapgen v7, ported (LGPL-2.1+) |
| `engine/bench.bend` | the headless world-generation race |
| `engine/world/` | loaded mapchunks and streaming around the player |
| `engine/render/` | mesher, culling, level of detail, fog, Bend3D (Apache-2.0) |
| `engine/hud.bend`, `engine/game.bend` | the panel and the window |
| `engine/LAWS.bend`, `engine/PROOF.bend` | law statements and their proofs (the `bend engine/PROOF.bend` gate) |
| `harness/` | the race runner (Node 22), Luanti lane, dump verifier |
| `luanti/` | the pinned Luanti build, timing patch and probe mod |
