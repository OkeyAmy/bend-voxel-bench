# Bend2 Field Notes

A living record of what building a real voxel game and benchmark in Bend2
taught us: what works, what's missing, what bites, and how it compares with
the tools people use today. Bend 2.0.27 on Linux x86_64 (i7-8665U, 4 cores /
8 threads, no GPU), September 2026. The newest notes are at the bottom of
each section.

## 1. What Bend2 is (in one paragraph)

Python-looking syntax, Haskell/Lean semantics (pure functions, dependent
types, proofs), Rust-like resource rules (values are used once unless marked
`+`), and a compiler that turns everything into one C file running in
parallel on CPU cores (or on the GPU through CUDA/Metal). There is no garbage
collector: a value is freed the moment it's taken apart. Parallelism is
written as two calls side by side (`a b = f(x) g(y)`), and a `!` after a call
sends that whole call tree to the GPU.

## 2. Measured so far

| What | Bend | Reference | Notes |
|---|---|---|---|
| Luanti mapgen v7 terrain, 100 mapchunks, 1 thread | 1,350 ms | Luanti C++: 131 ms | Same output, 100 % identical blocks. Bend is about 10× slower |
| Same, 8 threads | 530 ms | — | Bend's own speedup is 2.5× (4 cores + hyperthreads) |
| Voxel renderer, 1 mapchunk, 640 × 480, 8 threads | 2.2 ms build + 9.8 ms draw | — | About 80 FPS, all on CPU, no graphics card |
| Same, 3 × 3 mapchunks | 21 ms + 41 ms | — | About 16 FPS, so it needs culling and LOD (Plan 2a Task 4) |
| Renderer in the engine, mesh cached, 1 mapchunk, 640 × 480 | 1 ms build + 10 ms draw | — | Caching world-space quads leaves only projection per frame |
| Same at 1280 × 720 | 2 ms + 13 ms (≈ 66 FPS) | — | 3× the pixels costs +4 ms: triangles, not pixels, set the cost |
| 3 × 3 mapchunks with border faces, 640 × 480 | 14 ms build + 62 ms draw (≈ 13 FPS), 30,916 triangles | — | Needs culling and LOD next |
| **5 × 5 streamed world, 1280 × 720, 8 threads (battery)** | baseline 52 ms/frame → **30 ms** (G2 met) | — | View culling 52 → 35 ms; far mapchunks at half resolution → 30 ms; merging step fronts made it *slower* (see trap 14) |
| Game frame with the race panel, 1280 × 720, 8 threads | 31–32 FPS (7 ms build + 25 ms draw) | — | New mapchunk while flying: 28 ms to generate and mesh |
| Same with fog (on AC power) | 20 ms/frame ≈ 50 FPS | — | Fog also hides the world edge and the LOD seams |
| Race button: regenerate the 25 mapchunks around you | 585 ms generate + mesh (8 threads) | Luanti C++ terrain only: 32.7 ms | Not the same work, so it was replaced by the live race below |
| **Live race (G), 100 mapchunks at −30112, 29968, AC, load 1.6** | 1 thread 1,321 ms, 8 threads 501 ms | **Luanti C++ 1 thread 130.6 ms** | Same work, same moment, 100 % same blocks. Bend is 10× slower on one thread |
| Streaming: 600 frames flying 1,200 blocks (generate + mesh, no render) | 101 mapchunks loaded, 30 kept, 2.5 s total, peak 16 MB | — | No garbage collector, yet memory stays flat: a dropped mapchunk is freed the moment it's no longer referenced |
| Slash Boss 3D demo, 1920 × 1200 | 28.5 ms/frame (8 threads), 98 ms (1 thread) | — | Bend's own demo on this laptop |
| Build time of a 3,200-line Bend program | about 20 s | — | clang compile of the generated C |
| Law gate: `bend engine/PROOF.bend` (7 laws, one with an 8-case list proof) | 1 s | — | Prints `All terms check.`; runs before every game build (`harness/build.ts`) and in `tests/laws.test.ts` |

## 3. What works well

- **Exact float maths.** The Luanti noise port matched C++ **bit for bit** on the first run. Bend's F32 follows C's operation order, and nothing fuses operations behind your back.
- **Parallelism is one line.** `l r = B.gen(p, ...) B.gen(p, ...)` split 100 mapchunks across all cores with no threads, locks or pools.
- **Strict evaluation.** Work between two `IO.now()` calls really happens there, so timing is honest.
- **A CPU-only 3D renderer that's actually usable.** Bend3D rasterises triangles into a quadtree image in parallel.
- **Clear compile errors.** They name the rule and show the line.

## 4. Gaps compared with what people use today

| Need | Bend 2.0.27 | What people use now |
|---|---|---|
| Signed integers | none: two's complement by hand (`engine/i32.bend`) | C/C++/Rust/Go have `int` |
| Bit shifts by a constant | `x >> 13n` unrolls into 13 one-bit steps. Divide by 8192 instead | a single CPU instruction everywhere |
| Negative number literals | not parsed: write `(0.0 - 8.0 : F32)` | `-8.0` |
| Arrays | a binary tree (`ALeaf`/`ANode`). Access is a tree walk, and an array can't be shared across parallel calls | flat memory in C/Rust; `Vec` |
| Mutual recursion | not allowed. A def may only call defs above it | allowed everywhere |
| Type inference | almost none: annotate constructors and literals | Rust/TS/Haskell infer most types |
| GPU drawing | none: you compute every pixel yourself (Bend3D) | OpenGL/Vulkan/Metal via engines |
| Windowing | a minimal X11 window with key/mouse events. No pointer capture, no resize | SDL, GLFW, winit |
| JSON, HTTP, TLS | not in the standard library | built in or one package away |
| Package ecosystem | BendHub is days old | npm, crates.io, PyPI |
| Stability | 23+ releases in the first week, no ABI stability | stable releases |
| Running another program | none in Base. `IO.spawn` starts a Bend task, not an OS process. We wrote a custom effect, `Proc.run(cmd)` (`engine/sys/proc.c`, about 20 lines of C, using `system()` on a helper thread) | Python `subprocess`, Node `child_process`, Rust `std::process::Command`, C `posix_spawn` |
| Vector maths | Bend3D has `add`, `sub`, `scale` (by a number), `dot`, `cross`, `len`, `unit`, `mix`, but no component-wise `mul` | GLM `a * b`, Unity `Vector3.Scale`, Godot `a * b`, three.js `multiply`, glam `a * b`, numpy `a * b` |

## 5. Traps (each one cost us time)

1. **You can't `match` on a computed value.** Give it its own function that matches on a parameter.
2. **A `let` can't come before a `match` on a parameter.** Match first, then destructure inside each case.
3. **Reusable parameters are `+name: T`, not `name: +T`.**
4. **`a ++ b` costs the length of `a`.** Building a long string left-first turned a 0.2 s dump into 60 s. Build right-nested.
5. **`IO.args()` returns a one-use list.** Rebuild it to read an argument twice.
6. **Rendering winding matters.** Bend3D drops triangles facing away (clockwise on screen). We found the right winding by rendering all four choices and counting sky pixels showing through, not by reasoning.
7. **Host-side parallel forks don't always help.** Building 9 mapchunk meshes in parallel made the build 10 % faster, but drawing 50 % slower. Merging the per-fork triangle lists costs time, and a smaller task doesn't pay for its fork.
8. **The draw cost scales with triangle count, not pixel count.** Going from 1920 × 1200 to 1280 × 720 cut the boss demo only from 28.5 to 24 ms, and merging equal block tops cut our frame 3×.

9. **Frame sizes are compile-time.** Bend3D's `Frame.show` takes the width and height as `~` templates, so each screen size is its own compiled function (`V.frame640`, `V.frame1280`). You can't pick a size at runtime without writing a branch per size.
10. **Comparator arguments for `List.sort` must be plain, not `+`.** `def le(a: Nat, b: Nat)`: a `+a` parameter changes the function's type and the template no longer fits.

11. **A type error can freeze the whole computer.** To print "cannot infer", the checker expands the offending term in full, and a term that uses a value twice per step doubles at every step. A 17-line file needs 6.8 MB of error text at `n = 18` and passes 2 GB at `n = 22`. In our game a missing annotation on `+w1 = Mc{...} <> w` froze the laptop and it had to be hard-rebooted. The checker has no work limit (Lean has `maxHeartbeats`, TypeScript and Rust have depth limits). Filed as **bendlang/bend#1041**. What we do now: every `bend` call runs under `systemd-run --user --scope -p MemoryMax=4G -p MemorySwapMax=0 -- timeout ...` (see `harness/build.ts`), and a cons in a `let` gets a type annotation on the whole expression.

12. **A module's identity is the spelling of its import path.** If `render/probe.bend` imports `./mesh.bend` and `world/world.bend` imports `../render/mesh.bend`, then checking `probe.bend` on its own fails with "one namespace per file ... is both 'mesh' and '../render/mesh'", because `render/../render` isn't collapsed. Checking from the program root (`engine/main.bend`) works. Check whole programs from their root.

13. **Types inside a module carry the module's alias.** A type named `S.Off` in `stream.bend`, imported `as S`, is `S.S.Off` outside. Name types without the prefix, or expect the double name.

14. **Fewer triangles isn't always faster in Bend3D.** Merging step fronts into long strips cut triangles 16 % but made frames 11 % slower. Bend3D sorts each triangle into every 64-px screen cell its box touches, so a long thin strip lands in many cells. Big *square-ish* savings help (half-resolution far land: −20 %); long slivers hurt. That's the shaders guide's warning about slivers, measured.
15. **Measure on AC power.** On battery the laptop gave 38–39 ms for the same frame that ran 35 ms earlier. Always record the power state with a benchmark.

16. **Bend3D's font is tiny: capitals, digits and `% / + . , ' -`.** No lowercase, no colon, no brackets, so every on-screen label has to fit that set. (Game engines ship full Unicode font rendering.)
17. **A see-through quad shows its diagonal.** Bend3D's alpha mode blends each triangle separately, so the seam between a quad's two triangles gets blended twice and shows as a dotted line. Draw UI panels opaque.
18. **Reading a file is three effects:** `File.open` → `File.read(f, max)` → `File.close`, each returning a `Result` (`Done{..}` / `Fail{..}`) to match on. There's no `read_to_string` shortcut.

19. **Fog is cheap in a CPU renderer:** mix each vertex colour towards the sky by horizontal distance, and Bend3D interpolates it across the triangle. Measure distance horizontally, though: 3D distance from a camera 70 blocks up fogged the ground right below it.

20. **Template (`~`) arguments must be closed:** a lambda passed to `List.any(~..., ~(s => String.eq(s, name)), ...)` can't mention the local `name`. Write the recursion by hand.
21. **A window handle has exactly one owner.** `Window.frame` hands it back with the image and the events, and the quit branch must be the only other place it goes. Passing it to both "close" and "next frame" is rejected.
22. **Node's test runner runs test files in parallel by default.** A benchmark test then fights the other tests for the CPU (60 ms instead of 20 ms). Run with `--test-concurrency=1`.

23. **Extending Bend's IO is easy and well documented** (`bend guide effects`): declare `def Proc.run(cmd: String) -> IO(U32)` with `import "./proc.c"` and `import "./proc.js"`, then write the C side with `io_work(w, call, pack)` so blocking work runs on a helper thread. It worked on the first try. The catch is that the C side uses runtime internals with no ABI promise, so it has to be rebuilt and re-checked on every Bend release.

## 6. Harness lessons (not Bend-specific, but found here)

- JavaScript's `String.replace` replaces only the first match. That silently sent Luanti the wrong seed, and 75 % parity exposed it.
- With several emerge threads, Luanti marks blocks another thread is already generating as "cancelled". A benchmark must re-request them before stopping the clock.
- A timeout that kills `/usr/bin/time` leaves the measured program running. Kill the process group.

## 6b. Honest benchmarking checklist (what this project does, and why)

| Rule | How it's done here |
|---|---|
| Same work on both sides | Terrain generation (noise + block fill) of the same 100 mapchunks. Known leftovers: Luanti fills 82 layers per column, Bend 80; Bend's timer includes allocating its block arrays |
| Same output, checked | Every lane's blocks are compared with Luanti's, column by column. A lane's time only counts at ≥ 99.99 % (we get 100 %) |
| Same machine, same moment | `live_race.ts` (and G in the game) runs both engines one after the other, interleaved, on this laptop, now |
| Fresh processes, no caching | Every run is a new process on a new temporary world |
| Several runs, medians, spread | 1 warm-up plus 3 (live) or 5 (`arena.ts`) runs. The table shows min, max and spread |
| Conditions recorded | Power (AC or battery), CPU governor, load average go into every result, and the panel shows them |
| No mixed quantities | No ratio between Bend's wall time and Luanti's per-thread sum. FPS is never put next to Luanti (Luanti draws on the GPU, Bend on the CPU) |
| Timers inside each engine | Bend `IO.now()` around the generation (ms), Luanti a patch around `generateTerrain` (µs). Totals over 100 mapchunks keep the ms rounding under 0.1 % |

## 7. Law-driven development (engine/LAWS.bend / engine/PROOF.bend)

Bend 2 ships the feature this project was built to understand: a proof checker.
A `law` in `LAWS.bend` states an equation over the engine's own functions; a
`def Laws.<name>` in `PROOF.bend` has to convince the checker it holds; the gate
is `bend engine/PROOF.bend` → `All terms check.` (about 1 s here). The laws live
in the game: `harness/build.ts` runs the gate before every `buildEngine()`, so a
broken proof refuses the build. `tests/laws.test.ts`
runs the gate, fails if a proof is left as `?TODO` (`tests/fixtures/laws_open/`
is the broken example), and cross-checks that every `law` has a `def Laws.<name>`.

What we prove (`engine/LAWS.bend` / `engine/PROOF.bend`):

- **L1 — selectors and pack:** `M.word(True, a, b) == a`,
  `M.pick(True, a, b) == a`, and `M.pack` at index 0 returns the accumulator.
- **L2 — the stone rule:** `M.block(y, s)` equals its `word` form, and is stone
  (1) wherever `I32.le(y, s)` holds. The evidence-binder proof works because the
  checker normalises the goal: the prop says `M.block(...)`, the `%e` annotation
  talks in `M.word(...)` terms, and the checker unfolds one to match the other.
- **L3 — `M.levels` preserves list length** when the three input lists agree.
  Eight cases: the Cons/Cons/Cons branch recurses with an induction hypothesis
  plus `len_peel` (cancels the `1n+` of a Cons using `Equal.cong` over a `pred`);
  the mismatched branches use their false `el`/`er` hypotheses by rewriting until
  the goal is `refl`.

Mechanics that cost probes (copy for next time):

1. **Imports need an alias:** `import ./LAWS.bend as Laws`, proofs named
   `def Laws.<name>`. A bare `import ./LAWS.bend` is a parse error.
2. **The double alias applies to defs too** (trap 13 is about types): a def
   declared `def M.block` inside `mapgen.bend` is `M.M.block` from outside —
   the same reason `bench.bend` calls `M.M.chunk`. Unprefixed defs
   (`def word`) stay `M.word`.
3. **List plumbing:** `List.length(&2, A, xs)` takes a usage, the element type,
   then the list; law binders must match (`for bs: List<&2, F32>`, not
   `List<F32>`); a pattern tail used twice needs `Con{+b, +bt}`; and
   `match a b c` takes exactly one pattern per scrutinee (`case _ _ _` for the
   fallback).
4. **`{==}` has a cliff.** Small structural goals close instantly; the stretch
   law `heights_len` (6400 levels through `map2d`/`octaves`/`finish`/reverse)
   type-checks as a statement but was OOM-killed at the 4 GB cap in 13 s when
   asked to prove itself. It needs length lemmas about each helper first.
5. **F32 is axiomatic, by design:** the checker refuses
   `F32.add(a, b) == F32.add(b, a)` and even literal folding
   (`1.0 + 2.0` stays `F32.add(1.0, 2.0)`), so no property of the noise maths
   can be proven.

Coverage: seven laws about mapgen and six about movement. The render code and the
streaming world have none.

**L4, the ground.** The camera doesn't go below the ground under it. The first
version used a flat floor at y = 2, and you still flew through hills. Now `G.ground`
reads the top of the terrain column (plus 1.7 eye height, or sea level 3.7 where no
mapchunk is loaded) and `G.move` keeps you at or above it. Proofs about a record have
to split it first: `G.y(G.step(s, w))` won't compute while `s` is unknown, so the
proof does `match s` into its six fields and then rewrites with the `F32.is_lt`
hypothesis.

**L5, walls.** A column two or more blocks above the camera is a wall, and walking
into it leaves x and z unchanged (`wall_stops_x/z`). Two more laws say open ground
still moves you (`open_moves_x/z`), otherwise a camera that never moves would pass.
We wrote these laws before the code. The check went:

1. laws only: `4 TODOs found`
2. proofs added, old code: failed at `wall_stops_x`, the checker computed that x
   still changes
3. wall code added: failed at the old `ground_stops_fall`, because it talked about
   the ground where the keys lead, and at a wall you stay put
4. ground laws changed to "the ground where you end up": `All terms check.`

What the laws caught (one change at a time, check run after each):

| Change | Result |
|---|---|
| mapgen: stone and water ids swapped | refused (`block_def`) |
| mapgen: blocks packed 8 bits apart instead of 4 | got through (only the empty-pack case has a law) |
| mapgen: height rounded down instead of toward zero | got through (floats, no law possible) |
| game: floor removed so you can dive underwater | refused (`floor_stops_dive`, the old flat-floor law) |
| game: floor lowered from 2 to 0 | refused (`floor_stops_dive`) |
| game: fixed height 2 instead of the ground under you | refused (`ground_stops_fall`) |
| game: wall check removed | refused (`wall_stops_x`) |

And what got around them, tried on copies of the engine:

| Change | Result |
|---|---|
| wall check removed and the wall laws and proofs deleted | `All terms check.` |
| wall check removed, game built with plain `bend engine/main.bend` | builds; only `PROOF.bend` imports the laws |
| "one block" changed to "1000 blocks" in the code and the laws | `All terms check.` |

`tests/laws.test.ts` keeps the ground and wall cases: a copy of the engine with the
change must fail the check.

Lessons:
- Laws don't run while you play. They're checked at build time for every input and
  then erased.
- The check compares laws with code. It doesn't know or care who wrote them, so the
  laws file needs its own review.
- A law only protects code the game runs. Our first floor laws were about `R.max`,
  which the game didn't call, so they protected nothing until `G.move` used it.
- A law that just restates the code (`block_def` restates `M.block`) refuses every
  change, good or bad. A useful law says what has to stay true.
- The error names the law but prints raw terms (a screen of `F32.add(...)`). That's
  enough to find which rule broke, not why.

## 8. Open questions to answer next

- Can culling and LOD bring a 5 × 5-mapchunk world to 30 FPS at 1280 × 720 on 8 CPU threads? (Plan 2a Task 4)
- How does Bend3D's text rendering cost compare with the terrain? (Plan 2a Task 5)
- GPU lane: does `!` on a GTX 1660 Ti beat 8 CPU threads for mapgen and for drawing? (Spec 5)
