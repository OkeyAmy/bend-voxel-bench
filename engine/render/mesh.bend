# Voxel mesher: one mapchunk's surface levels -> world-space quads, built once
# and cached. Tops of equal level are merged along each row. Side faces sit
# between neighbouring columns of different top, with flip = "the current
# column is not the higher one". That winding was found by rendering all four
# choices and counting sky pixels showing through (docs/bend-notes.md).
import Base
import ../i32.bend as I
import ../mapgen.bend as M
import ./bend3d.bend as R

# a world-space quad a b c d with its colour; flip reverses its winding
type Q is Data:
  Q{a: R.Vec, b: R.Vec, c: R.Vec, d: R.Vec, col: R.Vec, flip: Bool}

# top of a column: water (level <= 0) sits at 2, land at level + 1
def Mesh.top(+l: U32) -> U32:
  M.word(I.I32.le(l, 0), 2, (l + 1 : U32))

# water, sand, grass, rock, snow
def Mesh.colour(+l: U32) -> R.Vec:
  R.Vec.rgb(M.word(I.I32.le(l, 0), 3242182,
    M.word(I.I32.le(l, 3), 14010232, M.word(I.I32.le(l, 22), 6068802,
      M.word(I.I32.le(l, 40), 8421504, 15790320)))))

def Mesh.f(+x: U32) -> F32:
  I.I32.to_f32(x)

# side face on the plane X = x between columns of level lp (x - 1) and l (x)
def Mesh.xside(same: Bool, +x: U32, +z: U32, +lp: U32, +l: U32, qs: +List<Q>) -> +List<Q>:
  match same:
    case True{}:
      qs
    case False{}:
      +tp = Mesh.top(lp)
      +t = Mesh.top(l)
      +curhi = I.I32.le(tp, t)
      +hi = Mesh.f(M.word(curhi, t, tp))
      +lo = Mesh.f(M.word(curhi, tp, t))
      Q{R.Vec{Mesh.f(x), lo, Mesh.f(z)}, R.Vec{Mesh.f(x), hi, Mesh.f(z)},
        R.Vec{Mesh.f(x), hi, Mesh.f((z + 1 : U32))}, R.Vec{Mesh.f(x), lo, Mesh.f((z + 1 : U32))},
        R.Vec.scale(Mesh.colour(M.word(curhi, l, lp)), 0.75), Bool.not(curhi)} <> qs

# side face on the plane Z = z between columns of level lu (z - 1) and l (z)
def Mesh.zside(same: Bool, +x: U32, +z: U32, +lu: U32, +l: U32, qs: +List<Q>) -> +List<Q>:
  match same:
    case True{}:
      qs
    case False{}:
      +tu = Mesh.top(lu)
      +t = Mesh.top(l)
      +curhi = I.I32.le(tu, t)
      +hi = Mesh.f(M.word(curhi, t, tu))
      +lo = Mesh.f(M.word(curhi, tu, t))
      Q{R.Vec{Mesh.f(x), lo, Mesh.f(z)}, R.Vec{Mesh.f((x + 1 : U32)), lo, Mesh.f(z)},
        R.Vec{Mesh.f((x + 1 : U32)), hi, Mesh.f(z)}, R.Vec{Mesh.f(x), hi, Mesh.f(z)},
        R.Vec.scale(Mesh.colour(M.word(curhi, l, lu)), 0.6), Bool.not(curhi)} <> qs

# top face of the run of columns [rs, x) at level l
def Mesh.run(+rs: U32, +x: U32, +z: U32, +l: U32, qs: +List<Q>) -> +List<Q>:
  +t = Mesh.f(Mesh.top(l))
  Q{R.Vec{Mesh.f(rs), t, Mesh.f(z)}, R.Vec{Mesh.f(x), t, Mesh.f(z)},
    R.Vec{Mesh.f(x), t, Mesh.f((z + 1 : U32))}, R.Vec{Mesh.f(rs), t, Mesh.f((z + 1 : U32))},
    Mesh.colour(l), False{}} <> qs

def Mesh.flush(same: Bool, +rs: U32, +x: U32, +z: U32, +l: U32, qs: +List<Q>) -> +List<Q>:
  match same:
    case True{}:
      qs
    case False{}:
      Mesh.run(rs, x, z, l, qs)

def Mesh.sides(+x: U32, +z: U32, +lp: U32, +lu: U32, +l: U32, qs: +List<Q>) -> +List<Q>:
  Mesh.zside(U32.is_eq(Mesh.top(lu), Mesh.top(l)), x, z, lu, l,
    Mesh.xside(U32.is_eq(Mesh.top(lp), Mesh.top(l)), x, z, lp, l, qs))

# one row against the row before it (ups); lp = the level to the left,
# rs = where the current run of equal tops started
def Mesh.row(ups: +List<U32>, cur: +List<U32>, +x: U32, +z: U32, +lp: U32, +rs: U32,
    qs: +List<Q>) -> +List<Q>:
  match ups cur:
    case Con{+lu, ut} Con{+l, ct}:
      +same = U32.is_eq(Mesh.top(l), Mesh.top(lp))
      Mesh.row(ut, ct, (x + 1 : U32), z, l, M.word(same, rs, x),
        Mesh.flush(same, rs, x, z, lp, Mesh.sides(x, z, lp, lu, l, qs)))
    case _ _:
      Mesh.run(rs, x, z, lp, qs)

# the head of xs, or d when xs is empty
def Mesh.head(xs: +List<U32>, +d: U32) -> U32:
  match xs:
    case Con{+h, _}:
      h
    case Nil{}:
      d

# xs, or d when xs is empty
def Mesh.or(xs: +List<U32>, +d: +List<U32>) -> +List<U32>:
  match xs:
    case Nil{}:
      d
    case Con{+h, +t}:
      h <> t

# k rows from ls; ups is the row before, west the levels left of each row
def Mesh.rows(k: Nat, ups: +List<U32>, +ls: +List<U32>, +west: +List<U32>, +x0: U32, +z: U32,
    qs: +List<Q>) -> +List<Q>:
  match k:
    case 0n:
      qs
    case 1n+p:
      +cur = List.take(&2, U32, ls, 80n)
      +lp = Mesh.head(west, Mesh.head(cur, 0))
      Mesh.rows(p, cur, List.drop(&2, U32, ls, 80n), List.drop(&2, U32, west, 1n), x0,
        (z + 1 : U32), Mesh.row(ups, cur, x0, z, lp, x0, qs))

# The quads of the mapchunk at node origin (x0, z0) from its 6400 levels
# (row-major, z outer). west: the 80 levels of column x0 - 1 (one per row);
# north: the 80 levels of row z0 - 1; [] when that neighbour is not loaded,
# and then that border gets no faces.
def Mesh.chunk(+ls: +List<U32>, +x0: U32, +z0: U32, +west: +List<U32>, +north: +List<U32>) -> +List<Q>:
  Mesh.rows(80n, Mesh.or(north, List.take(&2, U32, ls, 80n)), ls, west, x0, z0, [])
