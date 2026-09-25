# Play mode: fly over the streamed world in a 1280 x 720 window with the race panel.
#   voxel --threads 8 --gpu off -- play [seed]
# WASD move, arrows look, Q/E down/up, G runs the live race (Bend and real Luanti,
# 100 mapchunks around you, harness/live_race.ts), Esc quits.
# keys-sim runs the same input code without a window, for tests.
import Base
import ./i32.bend as I
import ./mapgen.bend as M
import ./render/bend3d.bend as R
import ./render/view.bend as V
import ./render/probe.bend as P
import ./world/world.bend as W
import ./world/stream.bend as S
import ./hud.bend as H
import ./live.bend as L
import ./render/mesh.bend as Q

# held keys as bits: 1 w, 2 a, 4 s, 8 d, 16 q, 32 e, 64 left, 128 right, 256 up, 512 down, 1024 g
def G.bit(+code: U32) -> U32:
  M.word(U32.is_eq(code, 119), 1, M.word(U32.is_eq(code, 97), 2, M.word(U32.is_eq(code, 115), 4,
  M.word(U32.is_eq(code, 100), 8, M.word(U32.is_eq(code, 113), 16, M.word(U32.is_eq(code, 101), 32,
  M.word(U32.is_eq(code, 63234), 64, M.word(U32.is_eq(code, 63235), 128,
  M.word(U32.is_eq(code, 63232), 256, M.word(U32.is_eq(code, 63233), 512,
  M.word(U32.is_eq(code, 103), 1024, 0)))))))))))

def G.set(down: Bool, +held: U32, +b: U32) -> U32:
  match down:
    case True{}:
      (held .|. b : U32)
    case False{}:
      (held .&. (4294967295 - b) : U32)

# held keys after a frame's events; 4294967295 means quit (Esc or the window closed)
def G.keys(evs: List<Event>, +held: U32) -> U32:
  match evs:
    case Nil{}:
      held
    case Con{Close{}, _}:
      4294967295
    case Con{Key{+code, down}, t}:
      G.keys(t, M.word(U32.is_eq(code, 27), 4294967295, G.set(down, held, G.bit(code))))
    case Con{_, t}:
      G.keys(t, held)

type St is Data:
  St{x: F32, y: F32, z: F32, yaw: F32, pitch: F32, held: U32}

def G.on(+held: U32, +b: U32) -> F32:
  R.pick(((held .&. b) > 0 : U32), 1.0, 0.0)

# forward (W - S) and strafe (D - A) of the held keys
def G.fw(+held: U32) -> F32:
  (G.on(held, 1) - G.on(held, 4) : F32)

def G.side(+held: U32) -> F32:
  (G.on(held, 8) - G.on(held, 2) : F32)

# where this frame's keys would take the camera, before the ground is checked
def G.rawx(+s: St) -> F32:
  St{+x, _, _, +yaw, _, +held} = s
  (x + 0.6 * (G.fw(held) * F32.sin(yaw) + G.side(held) * F32.cos(yaw)) : F32)

def G.rawy(+s: St) -> F32:
  St{_, +y, _, _, _, +held} = s
  (y + 0.6 * (G.on(held, 32) - G.on(held, 16)) : F32)

def G.rawz(+s: St) -> F32:
  St{_, _, +z, +yaw, _, +held} = s
  (z + 0.6 * (G.fw(held) * F32.cos(yaw) - G.side(held) * F32.sin(yaw)) : F32)

# the ground at a column: the top of its terrain plus eye height 1.7;
# sea level (top 2) when that mapchunk isn't loaded
def G.ground.at(+m: Maybe<&2, U32>) -> F32:
  match m:
    case Some{+l}:
      (I.I32.to_f32(Q.Mesh.top(l)) + 1.7 : F32)
    case None{}:
      3.7

def G.ground(+w: +List<W.Mc>, +x: F32, +z: F32) -> F32:
  +cx = S.S.origin(x)
  +cz = S.S.origin(z)
  +i = (((I.I32.floor(z) - cz) * 80) + (I.I32.floor(x) - cx) : U32)
  G.ground.at(List.get(&2, U32, W.World.levels(w, cx, cz), U32.to_nat(i)))

# the camera never goes below the ground g (engine/LAWS.bend: ground_stops_fall)
def G.floor(+v: F32, +g: F32) -> F32:
  R.max(v, g)

def G.y(+s: St) -> F32:
  St{_, y, _, _, _, _} = s
  y

# one frame of flying, stopped by the ground g: 0.6 blocks per frame,
# 0.04 rad of turn, 0.03 rad of pitch up to +-1.4
def G.move(+s: St, +g: F32) -> St:
  St{_, _, _, +yaw, +pitch, +held} = s
  St{G.rawx(s), G.floor(G.rawy(s), g), G.rawz(s),
    (yaw + 0.04 * (G.on(held, 128) - G.on(held, 64)) : F32),
    R.clamp((pitch + 0.03 * (G.on(held, 256) - G.on(held, 512)) : F32), (0.0 - 1.4 : F32), 1.4), held}

# one frame in the world w: the ground is the column under where the keys lead
def G.step(+s: St, +w: +List<W.Mc>) -> St:
  G.move(s, G.ground(w, G.rawx(s), G.rawz(s)))

def G.held(+s: St) -> U32:
  St{_, _, _, _, _, held} = s
  held

def G.with(+s: St, +h: U32) -> St:
  St{x, y, z, yaw, pitch, _} = s
  St{x, y, z, yaw, pitch, h}

def G.cam(+s: St) -> R.Cam:
  St{x, y, z, yaw, pitch, _} = s
  V.V.cam(x, y, z, yaw, pitch, 1280, 720)

def G.x(+s: St) -> F32:
  St{x, _, _, _, _, _} = s
  x

def G.z(+s: St) -> F32:
  St{_, _, z, _, _, _} = s
  z

# ---- keys-sim: the input code without a window ----

def G.code(+k: String) -> U32:
  M.word(String.eq(k, "w"), 119, M.word(String.eq(k, "a"), 97, M.word(String.eq(k, "s"), 115,
  M.word(String.eq(k, "d"), 100, M.word(String.eq(k, "q"), 113, M.word(String.eq(k, "e"), 101,
  M.word(String.eq(k, "left"), 63234, M.word(String.eq(k, "right"), 63235,
  M.word(String.eq(k, "up"), 63232, M.word(String.eq(k, "down"), 63233,
  M.word(String.eq(k, "g"), 103, M.word(String.eq(k, "esc"), 27, 0))))))))))))

def G.events(ks: +List<String>) -> List<Event>:
  match ks:
    case Con{+k, t}:
      Key{G.code(k), True{}} <> G.events(t)
    case Nil{}:
      []

def G.fly(k: Nat, +s: St) -> St:
  match k:
    case 0n:
      s
    case 1n+p:
      G.fly(p, G.step(s, []))

def G.show(+s: St) -> String:
  St{x, y, z, yaw, pitch, _} = s
  "state " ++ F32.show(x) ++ " " ++ F32.show(y) ++ " " ++ F32.show(z) ++ " " ++ F32.show(yaw) ++ " "
    ++ F32.show(pitch)

def G.sim.go(quit: Bool, +h: U32, +frames: Nat) -> IO(Unit):
  match quit:
    case True{}:
      IO.print("quit")
    case False{}:
      IO.print(G.show(G.fly(frames, St{0.0, 60.0, 0.0, 0.0, 0.0, h})))

# args: ["keys-sim", frames, key...]
def G.sim(+args: +List<String>) -> IO(Unit):
  +h = G.keys(G.events(List.drop(&2, String, args, 2n)), 0)
  G.sim.go(U32.is_eq(h, 4294967295), h,
    U32.to_nat(Maybe.default(&2, U32, U32.read(Maybe.default(&2, String, List.get(&2, String, args, 1n), "0")), 0)))

# ---- the window ----

# G pressed this frame (runs the live race before the next frame) (down now, not last frame) starts a race
def G.pressed(+prev: U32, +now: U32) -> Bool:
  (((now .&. 1024) > 0 : U32) && ((prev .&. 1024) < 1 : U32))

# the banner on the frame shown while the live race runs
def G.banner(on: Bool, cells: R.Cells) -> R.Cells:
  match on:
    case True{}:
      H.Hud.line(108.0, "RACE RUNNING - BEND AND LUANTI, 100 MAPCHUNKS HERE", 1279.0, 719.0, cells)
    case False{}:
      cells

# one frame: (the live race if G was pressed last frame), stream, draw world and
# panel (host), then the frame (one bang)
@unsafe
def G.loop(window: Window, +ws: U32, +s: St, +prev: U32, +w: +List<W.Mc>, +race: H.Race,
    +lv: H.LiveR, +pend: Bool, +lb: U32, +ld: U32, +ll: U32, last: Image & R.Cells) -> IO(Unit):
  (old, used) = last
  do IO<Unit>:
    +lv2 : H.LiveR <- P.P.live(pend, lv, ws, I.I32.floor(G.x(s)), I.I32.floor(G.z(s)))
    +t0 : Nat <- IO.now()
    _ : R.Cells = R.Cells.drop(4n, used)
    +go : Bool = G.pressed(prev, G.held(s))
    +st : S.S.Step = S.S.step(ws, G.x(s), G.z(s), w)
    +tA : Nat <- IO.now()
    +ms : U32 = U32.from_nat(Nat.sub(tA, t0))
    +ll2 : U32 = P.P.got(st, ms, ll)
    +wn : +List<W.Mc> = P.P.stw(st)
    cells : R.Cells = G.banner(go, P.P.hud(True{}, race, lv2, H.RaceSt{0, 0, 0}, lb, ld, ll2, 1279.0, 719.0,
      P.P.draw(wn, 100.0, G.cam(s), 0, 1279.0, 719.0, R.CNil{})))
    +t1 : Nat <- IO.now()
    drawn : Image & R.Cells <- IO.pure(Image & R.Cells, V.V.frame1280(cells, old))
    +t2 : Nat <- IO.now()
    G.shown(drawn, window, ws, s, wn, race, lv2, go, U32.from_nat(Nat.sub(t1, t0)),
      U32.from_nat(Nat.sub(t2, t1)), ll2)

# show the frame and read this frame's key events
@unsafe
def G.shown(drawn: Image & R.Cells, window: Window, +ws: U32, +s: St, +w: +List<W.Mc>, +race: H.Race,
    +lv: H.LiveR, +pend: Bool, +lb: U32, +ld: U32, +ll: U32) -> IO(Unit):
  (image, cells) = drawn
  do IO<Unit>:
    shown : Window & Image & List<Event> <- Window.frame(window, image)
    G.next(shown, cells, ws, s, w, race, lv, pend, lb, ld, ll)

@unsafe
def G.next.go(quit: Bool, window: Window, image: Image, cells: R.Cells, +ws: U32, +s: St, +h: U32,
    +w: +List<W.Mc>, +race: H.Race, +lv: H.LiveR, +pend: Bool, +lb: U32, +ld: U32, +ll: U32) -> IO(Unit):
  match quit:
    case True{}:
      Window.close(window)
    case False{}:
      G.loop(window, ws, G.step(G.with(s, h), w), G.held(s), w, race, lv, pend, lb, ld, ll, (image, cells))

@unsafe
def G.next(shown: Window & Image & List<Event>, cells: R.Cells, +ws: U32, +s: St, +w: +List<W.Mc>,
    +race: H.Race, +lv: H.LiveR, +pend: Bool, +lb: U32, +ld: U32, +ll: U32) -> IO(Unit):
  (window, image, evs) = shown
  +h = G.keys(evs, G.held(s))
  G.next.go(U32.is_eq(h, 4294967295), window, image, cells, ws, s, h, w, race, lv, pend, lb, ld, ll)

def G.seed(+args: +List<String>) -> U32:
  Maybe.default(&2, U32, I.I32.read(Maybe.default(&2, String, List.get(&2, String, args, 1n), "")), 123456789)

def G.start.go(cliffs: Bool) -> St:
  match cliffs:
    case True{}:
      St{(0.0 - 30100.0 : F32), 70.0, 29990.0, 1.5708, (0.0 - 0.3 : F32), 0}
    case False{}:
      St{0.0, 60.0, 0.0, 0.0, (0.0 - 0.3 : F32), 0}

# the cliffs of seed 123456789 by default, else the origin of the given seed
def G.start(+ws: U32) -> St:
  G.start.go(U32.is_eq(ws, 123456789))

# args: ["play", seed?]
@unsafe
def G.play(+args: +List<String>) -> IO(Unit):
  +ws = G.seed(args)
  do IO<Unit>:
    +race : H.Race <- H.Hud.read("out/race.txt")
    window : Window <- IO.try(Window, Window.open("Bend Voxel Bench - race against Luanti", 1280, 720))
    G.loop(window, ws, G.start(ws), 0, [], race, H.Hud.nolive(), False{}, 0, 0, 4294967295, (Pix{0}, R.CNil{}))
