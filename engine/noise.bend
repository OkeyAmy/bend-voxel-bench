# Port of Luanti 5.17.0 src/noise.cpp (value noise maps). LGPL-2.1-or-later.
# Signed ints are U32 in two's complement; F32 order of operations follows C++.
import Base
import ./i32.bend as I

# ---- noise2d ----

def N.hash(+x: U32, +y: U32, +seed: U32) -> F32:
  +n0 = (((1619 * x) + (31337 * y) + (1013 * seed)) .&. 2147483647 : U32)
  +n1 = ((n0 / 8192) .^. n0 : U32)  # n >> 13 (a Nat shift unrolls into 13 steps)
  +n2 = (((n1 * ((n1 * n1 * 60493) + 19990303)) + 1376312589) .&. 2147483647 : U32)
  (1.0 - (U32.to_f32(n2) / 1073741824.0) : F32)

def N.ease(+t: F32) -> F32:
  (t * t * t * ((t * ((6.0 * t) - 15.0)) + 10.0) : F32)

def N.lerp(+a: F32, +b: F32, +t: F32) -> F32:
  (a + ((b - a) * t) : F32)

def N.bil(+v00: F32, +v10: F32, +v01: F32, +v11: F32, +u: F32, +v: F32) -> F32:
  +x = N.ease(u)
  +y = N.ease(v)
  N.lerp(N.lerp(v00, v10, x), N.lerp(v01, v11, x), y)

# ---- valueMap2D ----

type Cur is Data:
  Cur{u: F32, nx: U32, a: F32, b: F32, c: F32, d: F32}

def N.adv(wrap: Bool, +u: F32, +nx: U32, +a: F32, +b: F32, +c: F32, +d: F32,
    +x0: U32, +ya: U32, +yb: U32, +seed: U32) -> Cur:
  match wrap:
    case True{}:
      +nx1 = (nx + 1 : U32)
      Cur{(u - 1.0 : F32), nx1, b, N.hash((x0 + nx1 + 1 : U32), ya, seed),
        d, N.hash((x0 + nx1 + 1 : U32), yb, seed)}
    case False{}:
      Cur{u, nx, a, b, c, d}

# one row: sx values, prepended to acc (so acc ends up reversed)
def N.row(i: Nat, +x0: U32, +ya: U32, +yb: U32, +seed: U32, +step: F32, +v: F32,
    cur: Cur, acc: +List<F32>) -> +List<F32>:
  match i:
    case 0n:
      acc
    case 1n+p:
      Cur{+u, +nx, +a, +b, +c, +d} = cur
      +val = N.bil(a, b, c, d, u, v)
      +u1 = (u + step : F32)
      N.row(p, x0, ya, yb, seed, step, v, N.adv((u1 >= 1.0 : F32), u1, nx, a, b, c, d, x0, ya, yb, seed),
        val <> acc)

type VCur is Data:
  VCur{v: F32, ny: U32}

def N.vadv(wrap: Bool, +v: F32, +ny: U32) -> VCur:
  match wrap:
    case True{}:
      VCur{(v - 1.0 : F32), (ny + 1 : U32)}
    case False{}:
      VCur{v, ny}

def N.rows(j: Nat, +sx: Nat, +x0: U32, +y0: U32, +seed: U32, +step: F32, +ou: F32,
    vc: VCur, acc: +List<F32>) -> +List<F32>:
  match j:
    case 0n:
      acc
    case 1n+p:
      VCur{+v, +ny} = vc
      +ya = (y0 + ny : U32)
      +yb = (y0 + ny + 1 : U32)
      +cur = {Cur{ou, 0, N.hash(x0, ya, seed), N.hash((x0 + 1 : U32), ya, seed),
        N.hash(x0, yb, seed), N.hash((x0 + 1 : U32), yb, seed)} : Cur}
      +v1 = (v + step : F32)
      N.rows(p, sx, x0, y0, seed, step, ou, N.vadv((v1 >= 1.0 : F32), v1, ny),
        N.row(sx, x0, ya, yb, seed, step, v, cur, acc))

# valueMap2D: sx*sy values, REVERSED row-major order
def N.value_map(+sx: Nat, +sy: Nat, +x: F32, +y: F32, +step: F32, +seed: U32) -> +List<F32>:
  +x0 = I.I32.floor(x)
  +y0 = I.I32.floor(y)
  +u = (x - I.I32.to_f32(x0) : F32)
  +v = (y - I.I32.to_f32(y0) : F32)
  N.rows(sy, sx, x0, y0, seed, step, u, VCur{v, 0}, [])

# ---- noiseMap2D ----

type Acc is Data:
  Acc{r: F32, g: F32}

# updateResults with a gmap: r += g*val; g *= p. Keeps list order.
def N.update(accs: +List<Acc>, vals: +List<F32>, ps: +List<F32>) -> +List<Acc>:
  match accs vals ps:
    case Con{Acc{+r, +g}, at} Con{+val, vt} Con{+p, pt}:
      Acc{(r + (g * val) : F32), (g * p : F32)} <> N.update(at, vt, pt)
    case _ _ _:
      []

def N.octaves(o: Nat, +sx: Nat, +sy: Nat, +x: F32, +y: F32, +spread: F32, +lac: F32,
    +seed: U32, +f: F32, +ps: +List<F32>, accs: +List<Acc>) -> +List<Acc>:
  match o:
    case 0n:
      accs
    case 1n+p:
      vals = N.value_map(sx, sy, (x * f : F32), (y * f : F32), (f / spread : F32), seed)
      N.octaves(p, sx, sy, x, y, spread, lac, (seed + 1 : U32), (f * lac : F32), ps,
        N.update(accs, vals, ps))

def N.finish(accs: +List<Acc>, +scale: F32, +offset: F32) -> +List<F32>:
  match accs:
    case Con{Acc{+r, _}, t}:
      ((r * scale) + offset : F32) <> N.finish(t, scale, offset)
    case Nil{}:
      []

type NP is Data:
  NP{offset: F32, scale: F32, spread: F32, seed: U32, octaves: Nat, persist: F32, lac: F32}

# noiseMap2D(x, y, persist list). ps: per-point persistence (a constant list when none).
# Always applies result * scale + offset: Luanti skips it only when offset == 0 and
# scale == 1, which no mapgen v7 terrain noise has.
# Result is REVERSED row-major, like value_map.
def N.map2d(+np: NP, +wseed: U32, +sx: Nat, +sy: Nat, +x: F32, +y: F32, +ps: +List<F32>) -> +List<F32>:
  NP{+offset, +scale, +spread, +nseed, +oct, _, +lac} = np
  +init = List.replicate(Acc, Nat.mul(sx, sy), Acc{0.0, 1.0})
  N.finish(N.octaves(oct, sx, sy, (x / spread : F32), (y / spread : F32), spread, lac,
    (wseed + nseed : U32), 1.0, ps, init), scale, offset)
