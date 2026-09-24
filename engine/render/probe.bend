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
import ../world/stream.bend as S
import ../hud.bend as H

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
    case Con{W.Mc{_, _, _, +qs, _}, t}:
      List.append(&2, Q.Q, qs, P.flat(t))
    case Nil{}:
      []

# scene path: seed 123456789, flying east along z = 29990 from x = -30100
def P.path.x(+i: U32) -> F32:
  (0.0 - 30100.0 + 0.6 * U32.to_f32(i) : F32)

def P.path.ws() -> U32:
  123456789

def P.stepw(+st: S.S.Step) -> +List<W.Mc>:
  S.S.Step{+w, _} = st
  w

def P.stream(+i: U32, +w: +List<W.Mc>) -> +List<W.Mc>:
  P.stepw(S.S.step(P.path.ws(), P.path.x(i), 29990.0, w))

# stream k steps at frame i's position (the pre-load before timing)
def P.prestream(k: Nat, +i: U32, +w: +List<W.Mc>) -> +List<W.Mc>:
  match k:
    case 0n:
      w
    case 1n+p:
      P.prestream(p, i, P.stream(i, w))

# scenes: 0 hills1, 1 hills3, 2 path
def P.world.pick(one: Bool, three: Bool) -> +List<W.Mc>:
  match one three:
    case True{} _:
      W.World.load(0, (0 - 31952 : U32), (0 - 31952 : U32), [])
    case False{} True{}:
      P.world3()
    case False{} False{}:
      P.prestream(40n, 0, [])

def P.world(+sc: U32) -> +List<W.Mc>:
  P.world.pick(U32.is_eq(sc, 0), U32.is_eq(sc, 1))

# the world for the next frame: only the path scene moves and streams
def P.next(path: Bool, +i: U32, +w: +List<W.Mc>) -> S.S.Step:
  match path:
    case True{}:
      S.S.step(P.path.ws(), P.path.x(i), 29990.0, w)
    case False{}:
      S.S.Step{w, None{}}

def P.got.go(+m: Maybe<&2, S.S.Off>, +ms: U32, +prev: U32) -> U32:
  match m:
    case Some{_}:
      ms
    case None{}:
      prev

def P.got(+st: S.S.Step, +ms: U32, +prev: U32) -> U32:
  S.S.Step{_, got} = st
  P.got.go(got, ms, prev)

def P.hud(on: Bool, +race: H.Race, +rs: H.RaceSt, +build: U32, +draw: U32, +load: U32, +x1: F32,
    +y1: F32, cells: R.Cells) -> R.Cells:
  match on:
    case True{}:
      H.Hud.draw(race, rs, (build + draw : U32), build, draw, load, x1, y1, cells)
    case False{}:
      cells

# every loaded mapchunk's quads into the cells
# mapchunks nearer than this get the full mesh, farther ones the half-resolution one
def P.lod() -> F32:
  100.0

def P.draw.one(vis: Bool, near: Bool, +qs: +List<Q.Q>, +far: +List<Q.Q>, +cam: R.Cam, +m: U32,
    +x1: F32, +y1: F32, cells: R.Cells) -> R.Cells:
  match vis near:
    case True{} True{}:
      D.Draw.quads(qs, cam, m, x1, y1, cells)
    case True{} False{}:
      D.Draw.quads(far, cam, m, x1, y1, cells)
    case False{} _:
      cells

# the quads of every loaded mapchunk in view into the cells
def P.draw(w: +List<W.Mc>, +cam: R.Cam, +m: U32, +x1: F32, +y1: F32, cells: R.Cells) -> R.Cells:
  match w:
    case Con{W.Mc{+x, +z, _, +qs, +far}, t}:
      P.draw(t, cam, m, x1, y1, P.draw.one(D.Draw.visible(cam, I.I32.to_f32(x), I.I32.to_f32(z)),
        (D.Draw.dist(cam, I.I32.to_f32(x), I.I32.to_f32(z)) <= P.lod() : F32), qs, far, cam, m, x1, y1, cells))
    case Nil{}:
      cells

def P.quads(w: +List<W.Mc>) -> Nat:
  match w:
    case Con{W.Mc{_, _, _, +qs, _}, t}:
      Nat.add(List.length(&2, Q.Q, qs), P.quads(t))
    case Nil{}:
      0n

def P.cam.pick(three: Bool, path: Bool, +i: U32, +w: U32, +h: U32) -> R.Cam:
  match three path:
    case _ True{}:
      V.V.cam(P.path.x(i), 70.0, 29990.0, 1.5708, (0.0 - 0.3 : F32), w, h)
    case True{} False{}:
      V.V.cam((0.0 - 30130.0 : F32), 60.0, 29870.0, (0.785 + 0.01 * U32.to_f32(i) : F32),
        (0.0 - 0.35 : F32), w, h)
    case False{} False{}:
      V.V.cam((0.0 - 31965.0 : F32), 48.0, (0.0 - 31965.0 : F32),
        (0.785 + 0.01 * U32.to_f32(i) : F32), (0.0 - 0.42 : F32), w, h)

def P.cam(+sc: U32, +i: U32, +w: U32, +h: U32) -> R.Cam:
  P.cam.pick(U32.is_eq(sc, 1), U32.is_eq(sc, 2), i, w, h)

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

# race button: drop the world at frame 10, then time the refill of 25 mapchunks
def P.rs.go(go: Bool, +r: H.RaceSt) -> H.RaceSt:
  match go:
    case True{}:
      H.RaceSt{1, 0, 0}
    case False{}:
      r

def P.rs.w(go: Bool, +w: +List<W.Mc>) -> +List<W.Mc>:
  match go:
    case True{}:
      []
    case False{}:
      w

def P.rs.idle(+r: H.RaceSt) -> Bool:
  H.RaceSt{st, _, _} = r
  U32.is_eq(st, 0)

def P.loaded(+st: S.S.Step) -> Bool:
  S.S.Step{_, got} = st
  Maybe.is_some(&2, S.S.Off, got)

def P.rs.fin(done: Bool, +n: U32, +sum: U32) -> IO(H.RaceSt):
  match done:
    case True{}:
      do IO<H.RaceSt>:
        IO.print("race_done mapchunks " ++ U32.show(n) ++ " bend_ms " ++ U32.show(sum))
        return H.RaceSt{2, n, sum}
    case False{}:
      IO.pure(H.RaceSt, H.RaceSt{1, n, sum})

def P.rs.count(counting: Bool, +r: H.RaceSt, +ms: U32) -> IO(H.RaceSt):
  match counting:
    case True{}:
      H.RaceSt{_, +n, +sum} = r
      do IO<H.RaceSt>:
        IO.print("race_load " ++ U32.show(ms))
        P.rs.fin(U32.is_eq((n + 1 : U32), 25), (n + 1 : U32), (sum + ms : U32))
    case False{}:
      IO.pure(H.RaceSt, r)

# after a frame's streaming step: count the load if the race is running
def P.rs.after(+r: H.RaceSt, +loaded: Bool, +ms: U32) -> IO(H.RaceSt):
  H.RaceSt{+st, _, _} = r
  P.rs.count((U32.is_eq(st, 1) && loaded), r, ms)

type Run is Data:
  Run{w: U32, h: U32, m: U32, sc: U32, hud: Bool, race: H.Race, btn: Bool}

def P.w(+r: Run) -> U32:
  Run{w, _, _, _, _, _, _} = r
  w

def P.h(+r: Run) -> U32:
  Run{_, h, _, _, _, _, _} = r
  h

def P.m(+r: Run) -> U32:
  Run{_, _, m, _, _, _, _} = r
  m

def P.sc(+r: Run) -> U32:
  Run{_, _, _, t, _, _, _} = r
  t

def P.hudon(+r: Run) -> Bool:
  Run{_, _, _, _, on, _, _} = r
  on

def P.race(+r: Run) -> H.Race:
  Run{_, _, _, _, _, race, _} = r
  race

def P.btn(+r: Run) -> Bool:
  Run{_, _, _, _, _, _, b} = r
  b

def P.stw(+st: S.S.Step) -> +List<W.Mc>:
  S.S.Step{w, _} = st
  w

@unsafe
def P.loop(k: Nat, +qs: +List<W.Mc>, +run: Run, +i: U32, last: Image & R.Cells, +bs: +List<Nat>,
    +ds: +List<Nat>, +lb: U32, +ld: U32, +ll: U32, +rs: H.RaceSt, path: String) -> IO(Unit):
  match k:
    case 0n:
      (old, used) = last
      do IO<Unit>:
        IO.print(P.report(bs, ds, Nat.mul(2n, P.quads(qs))))
        V.V.ppm(old, P.w(run), P.h(run), path)
    case 1n+p:
      (old, used) = last
      +w = P.w(run)
      +h = P.h(run)
      do IO<Unit>:
        +t0 : Nat <- IO.now()
        _ : R.Cells = R.Cells.drop(4n, used)
        +go : Bool = (P.btn(run) && U32.is_eq(i, 10) && P.rs.idle(rs))
        +st : S.S.Step = P.next(U32.is_eq(P.sc(run), 2), i, P.rs.w(go, qs))
        +tA : Nat <- IO.now()
        +ms : U32 = U32.from_nat(Nat.sub(tA, t0))
        +ll2 : U32 = P.got(st, ms, ll)
        +rs2 : H.RaceSt <- P.rs.after(P.rs.go(go, rs), P.loaded(st), ms)
        +wn : +List<W.Mc> = P.stw(st)
        +x1 : F32 = U32.to_f32((w - 1 : U32))
        +y1 : F32 = U32.to_f32((h - 1 : U32))
        cells : R.Cells = P.hud(P.hudon(run), P.race(run), rs2, lb, ld, ll2, x1, y1,
          P.draw(wn, P.cam(P.sc(run), i, w, h), P.m(run), x1, y1, R.CNil{}))
        +t1 : Nat <- IO.now()
        drawn : Image & R.Cells <- IO.pure(Image & R.Cells, V.V.frame(U32.is_eq(w, 1280), cells, old))
        +t2 : Nat <- IO.now()
        P.loop(p, wn, run, (i + 1 : U32), drawn, Nat.sub(t1, t0) <> bs, Nat.sub(t2, t1) <> ds,
          U32.from_nat(Nat.sub(t1, t0)), U32.from_nat(Nat.sub(t2, t1)), ll2, rs2, path)

def P.arg(xs: +List<String>, n: Nat) -> String:
  Maybe.default(&2, String, List.get(&2, String, xs, n), "")

def P.num(xs: +List<String>, n: Nat) -> U32:
  Maybe.default(&2, U32, U32.read(P.arg(xs, n)), 0)

def P.size_ok(+w: U32, +h: U32) -> Bool:
  ((U32.is_eq(w, 640) && U32.is_eq(h, 480)) || (U32.is_eq(w, 1280) && U32.is_eq(h, 720)))

def P.missing.go(ok: Bool) -> IO(Unit):
  match ok:
    case True{}:
      IO.pure(Unit, Unit{})
    case False{}:
      IO.print("hud: race file missing")

def P.missing(+race: H.Race) -> IO(Unit):
  H.Race{ok, _, _, _, _, _} = race
  P.missing.go(ok)

@unsafe
def P.go(ok: Bool, +args: +List<String>) -> IO(Unit):
  match ok:
    case False{}:
      IO.die(Unit, 2, "usage: voxel -- render hills1|hills3|path <frames> <640 480|1280 720> <out.ppm> [diag]")
    case True{}:
      +sc = M.word(String.eq(P.arg(args, 1n), "hills3"), 1, M.word(String.eq(P.arg(args, 1n), "path"), 2, 0))
      do IO<Unit>:
        +race : H.Race <- H.Hud.read("out/race.txt")
        P.missing(race)
        P.loop(U32.to_nat(P.num(args, 2n)), P.world(sc),
          Run{P.num(args, 3n), P.num(args, 4n), M.word(String.eq(P.arg(args, 6n), "diag"), 1, 0),
            sc, Bool.not(String.eq(P.arg(args, 6n), "nohud")), race, String.eq(P.arg(args, 6n), "race")}, 0,
          (Pix{0}, R.CNil{}), [], [], 0, 0, 4294967295, H.RaceSt{0, 0, 0}, P.arg(args, 5n))

# args: ["render", scene, frames, w, h, out, diag?]
@unsafe
def P.run(+args: +List<String>) -> IO(Unit):
  P.go(((String.eq(P.arg(args, 1n), "hills1") || String.eq(P.arg(args, 1n), "hills3")
    || String.eq(P.arg(args, 1n), "path")) && P.size_ok(P.num(args, 3n), P.num(args, 4n))
    && (P.num(args, 2n) > 0 : U32)), args)
