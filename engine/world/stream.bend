# Streaming: keep the 5 x 5 mapchunks around the player loaded.
# Each step drops mapchunks more than 3 away on either axis, then loads at most
# one missing wanted mapchunk: the nearest (by offset distance, ties by z then x).
import Base
import ../i32.bend as I
import ./world.bend as W

type S.Off is Data:
  S.Off{dx: U32, dz: U32}

# the 25 offsets (in blocks) nearest first: sorted by dx^2 + dz^2, then dz, then dx
def S.order() -> +List<S.Off>:
  [S.Off{0, 0},
    S.Off{0, (0 - 80 : U32)},
    S.Off{(0 - 80 : U32), 0},
    S.Off{80, 0},
    S.Off{0, 80},
    S.Off{(0 - 80 : U32), (0 - 80 : U32)},
    S.Off{80, (0 - 80 : U32)},
    S.Off{(0 - 80 : U32), 80},
    S.Off{80, 80},
    S.Off{0, (0 - 160 : U32)},
    S.Off{(0 - 160 : U32), 0},
    S.Off{160, 0},
    S.Off{0, 160},
    S.Off{(0 - 80 : U32), (0 - 160 : U32)},
    S.Off{80, (0 - 160 : U32)},
    S.Off{(0 - 160 : U32), (0 - 80 : U32)},
    S.Off{160, (0 - 80 : U32)},
    S.Off{(0 - 160 : U32), 80},
    S.Off{160, 80},
    S.Off{(0 - 80 : U32), 160},
    S.Off{80, 160},
    S.Off{(0 - 160 : U32), (0 - 160 : U32)},
    S.Off{160, (0 - 160 : U32)},
    S.Off{(0 - 160 : U32), 160},
    S.Off{160, 160}]

# origin of the mapchunk holding coordinate p: floor((p + 32) / 80) * 80 - 32
def S.origin(+p: F32) -> U32:
  ((I.I32.floor(((p + 32.0) / 80.0 : F32)) * 80) - 32 : U32)

def S.loaded(w: +List<W.Mc>, +x: U32, +z: U32) -> Bool:
  match w:
    case Con{+m, t}:
      (W.World.at(m, x, z) || S.loaded(t, x, z))
    case Nil{}:
      False{}

def S.missing.pick(hit: Bool, +x: U32, +z: U32, +rest: Maybe<&2, S.Off>) -> Maybe<&2, S.Off>:
  match hit:
    case True{}:
      rest
    case False{}:
      Some{S.Off{x, z}}

# the first offset whose mapchunk is not loaded, as an origin
def S.missing(os: +List<S.Off>, +w: +List<W.Mc>, +cx: U32, +cz: U32) -> Maybe<&2, S.Off>:
  match os:
    case Con{S.Off{+dx, +dz}, t}:
      S.missing.pick(S.loaded(w, (cx + dx : U32), (cz + dz : U32)), (cx + dx : U32), (cz + dz : U32),
        S.missing(t, w, cx, cz))
    case Nil{}:
      None{}

# |a - b| <= 240 as signed: within 3 mapchunks
def S.near(+a: U32, +b: U32) -> Bool:
  (I.I32.le((a - b : U32), 240) && I.I32.le((b - a : U32), 240))

def S.near.mc(+m: W.Mc, +cx: U32, +cz: U32) -> Bool:
  W.Mc{x, z, _, _, _} = m
  (S.near(x, cx) && S.near(z, cz))

def S.keep.pick(ok: Bool, +m: W.Mc, +rest: +List<W.Mc>) -> +List<W.Mc>:
  match ok:
    case True{}:
      m <> rest
    case False{}:
      rest

def S.keep(w: +List<W.Mc>, +cx: U32, +cz: U32) -> +List<W.Mc>:
  match w:
    case Con{+m, t}:
      S.keep.pick(S.near.mc(m, cx, cz), m, S.keep(t, cx, cz))
    case Nil{}:
      []

type S.Step is Data:
  S.Step{w: +List<W.Mc>, got: Maybe<&2, S.Off>}

def S.apply(+m: Maybe<&2, S.Off>, +ws: U32, +w: +List<W.Mc>) -> S.Step:
  match m:
    case Some{S.Off{+x, +z}}:
      S.Step{W.World.load(ws, x, z, w), m}
    case None{}:
      S.Step{w, m}

# one frame of streaming for a player at (px, pz)
def S.step(+ws: U32, +px: F32, +pz: F32, +w: +List<W.Mc>) -> S.Step:
  +cx = S.origin(px)
  +cz = S.origin(pz)
  +w1 = S.keep(w, cx, cz)
  S.apply(S.missing(S.order(), w1, cx, cz), ws, w1)
