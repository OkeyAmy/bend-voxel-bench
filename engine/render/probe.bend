# Headless render probe:
#   voxel -- render <scene> <frames> <w> <h> <out.ppm> [diag]
# Prints "frame_ms_median N build_ms_median N draw_ms_median N tris N" and
# writes the last frame as a PPM. Sizes: 640 480 or 1280 720.
import Base
import ../i32.bend as I
import ../mapgen.bend as M
import ./bend3d.bend as R
import ./mesh.bend as Q
import ./draw.bend as D
import ./view.bend as V
import ../world/world.bend as W

# scene hills1: seed 0, the mapchunk at (-31952, -31952), seen from its corner
def P.hills1() -> +List<Q.Q>:
  Q.Mesh.chunk(M.M.heights(0, (0.0 - 31952.0 : F32), (0.0 - 31952.0 : F32)),
    (0 - 31952 : U32), (0 - 31952 : U32), [], [])

# scene hills3: seed 123456789, 3 x 3 mapchunks around (-30032, 29968), loaded
# north-west first so each one finds its west and north neighbours
def P.world3() -> +List<W.Mc>:
  +s = {123456789 : U32}
  W.World.load(s, (0 - 29952 : U32), 30048, W.World.load(s, (0 - 30032 : U32), 30048,
    W.World.load(s, (0 - 30112 : U32), 30048, W.World.load(s, (0 - 29952 : U32), 29968,
    W.World.load(s, (0 - 30032 : U32), 29968, W.World.load(s, (0 - 30112 : U32), 29968,
    W.World.load(s, (0 - 29952 : U32), 29888, W.World.load(s, (0 - 30032 : U32), 29888,
    W.World.load(s, (0 - 30112 : U32), 29888, [])))))))))

# every loaded mapchunk's quads in one list
def P.flat(w: +List<W.Mc>) -> +List<Q.Q>:
  match w:
    case Con{W.Mc{_, _, _, +qs}, t}:
      List.append(&2, Q.Q, qs, P.flat(t))
    case Nil{}:
      []

def P.scene(three: Bool) -> +List<Q.Q>:
  match three:
    case True{}:
      P.flat(P.world3())
    case False{}:
      P.hills1()

def P.cam.pick(three: Bool, +i: U32, +w: U32, +h: U32) -> R.Cam:
  match three:
    case True{}:
      V.V.cam((0.0 - 30130.0 : F32), 60.0, 29870.0, (0.785 + 0.01 * U32.to_f32(i) : F32),
        (0.0 - 0.35 : F32), w, h)
    case False{}:
      V.V.cam((0.0 - 31965.0 : F32), 48.0, (0.0 - 31965.0 : F32),
        (0.785 + 0.01 * U32.to_f32(i) : F32), (0.0 - 0.42 : F32), w, h)

def P.le(a: Nat, b: Nat) -> Bool:
  Nat.is_le(a, b)

def P.median(+xs: +List<Nat>) -> Nat:
  Maybe.default(&2, Nat, List.get(&2, Nat, List.sort(~Nat, ~P.le, xs),
    Nat.div(List.length(&2, Nat, xs), 2n)), 0n)

def P.sum2(bs: +List<Nat>, ds: +List<Nat>) -> +List<Nat>:
  match bs ds:
    case Con{+b, bt} Con{+d, dt}:
      Nat.add(b, d) <> P.sum2(bt, dt)
    case _ _:
      []

def P.report(+bs: +List<Nat>, +ds: +List<Nat>, +tris: Nat) -> String:
  "frame_ms_median " ++ Nat.show(P.median(P.sum2(bs, ds))) ++ " build_ms_median "
    ++ Nat.show(P.median(bs)) ++ " draw_ms_median " ++ Nat.show(P.median(ds)) ++ " tris "
    ++ Nat.show(tris)

type Run is Data:
  Run{w: U32, h: U32, m: U32, three: Bool}

def P.w(+r: Run) -> U32:
  Run{w, _, _, _} = r
  w

def P.h(+r: Run) -> U32:
  Run{_, h, _, _} = r
  h

def P.m(+r: Run) -> U32:
  Run{_, _, m, _} = r
  m

def P.three(+r: Run) -> Bool:
  Run{_, _, _, t} = r
  t

@unsafe
def P.loop(k: Nat, +qs: +List<Q.Q>, +run: Run, +i: U32, last: Image & R.Cells, +bs: +List<Nat>,
    +ds: +List<Nat>, path: String) -> IO(Unit):
  match k:
    case 0n:
      (old, used) = last
      do IO<Unit>:
        IO.print(P.report(bs, ds, Nat.mul(2n, List.length(&2, Q.Q, qs))))
        V.V.ppm(old, P.w(run), P.h(run), path)
    case 1n+p:
      (old, used) = last
      +w = P.w(run)
      +h = P.h(run)
      do IO<Unit>:
        +t0 : Nat <- IO.now()
        _ : R.Cells = R.Cells.drop(4n, used)
        cells : R.Cells = D.Draw.quads(qs, P.cam.pick(P.three(run), i, w, h), P.m(run), U32.to_f32((w - 1 : U32)),
          U32.to_f32((h - 1 : U32)), R.CNil{})
        +t1 : Nat <- IO.now()
        drawn : Image & R.Cells <- IO.pure(Image & R.Cells, V.V.frame(U32.is_eq(w, 1280), cells, old))
        +t2 : Nat <- IO.now()
        P.loop(p, qs, run, (i + 1 : U32), drawn, Nat.sub(t1, t0) <> bs, Nat.sub(t2, t1) <> ds, path)

def P.arg(xs: +List<String>, n: Nat) -> String:
  Maybe.default(&2, String, List.get(&2, String, xs, n), "")

def P.num(xs: +List<String>, n: Nat) -> U32:
  Maybe.default(&2, U32, U32.read(P.arg(xs, n)), 0)

def P.size_ok(+w: U32, +h: U32) -> Bool:
  ((U32.is_eq(w, 640) && U32.is_eq(h, 480)) || (U32.is_eq(w, 1280) && U32.is_eq(h, 720)))

@unsafe
def P.go(ok: Bool, +args: +List<String>) -> IO(Unit):
  match ok:
    case False{}:
      IO.die(Unit, 2, "usage: voxel -- render hills1|hills3 <frames> <640 480|1280 720> <out.ppm> [diag]")
    case True{}:
      +three = String.eq(P.arg(args, 1n), "hills3")
      P.loop(U32.to_nat(P.num(args, 2n)), P.scene(three),
        Run{P.num(args, 3n), P.num(args, 4n), M.word(String.eq(P.arg(args, 6n), "diag"), 1, 0),
          three}, 0, (Pix{0}, R.CNil{}), [], [], P.arg(args, 5n))

# args: ["render", scene, frames, w, h, out, diag?]
@unsafe
def P.run(+args: +List<String>) -> IO(Unit):
  P.go(((String.eq(P.arg(args, 1n), "hills1") || String.eq(P.arg(args, 1n), "hills3")) && P.size_ok(P.num(args, 3n), P.num(args, 4n))
    && (P.num(args, 2n) > 0 : U32)), args)
