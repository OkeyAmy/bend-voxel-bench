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
| Streaming: 600 frames flying 1,200 blocks (generate + mesh, no render) | 101 mapchunks loaded, 30 kept, 2.5 s total, peak 16 MB | — | No garbage collector, yet memory stays flat: a dropped mapchunk is freed the moment it's no longer referenced |
| Slash Boss 3D demo, 1920 × 1200 | 28.5 ms/frame (8 threads), 98 ms (1 thread) | — | Bend's own demo on this laptop |
| Build time of a 3,200-line Bend program | about 20 s | — | clang compile of the generated C |

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

## 6. Harness lessons (not Bend-specific, but found here)

- JavaScript's `String.replace` replaces only the first match. That silently sent Luanti the wrong seed, and 75 % parity exposed it.
- With several emerge threads, Luanti marks blocks another thread is already generating as "cancelled". A benchmark must re-request them before stopping the clock.
- A timeout that kills `/usr/bin/time` leaves the measured program running. Kill the process group.

## 7. Open questions to answer next

- Can culling and LOD bring a 5 × 5-mapchunk world to 30 FPS at 1280 × 720 on 8 CPU threads? (Plan 2a Task 4)
- How does Bend3D's text rendering cost compare with the terrain? (Plan 2a Task 5)
- GPU lane: does `!` on a GTX 1660 Ti beat 8 CPU threads for mapgen and for drawing? (Spec 5)
