# The loaded mapchunks: origin, surface levels and cached quads.
# A mapchunk owns the side faces on its west and north borders, made from the
# neighbour's edge levels; so loading a mapchunk re-meshes its east and south
# neighbours, whose west and north borders it now completes.
import Base
import ../i32.bend as I
import ../mapgen.bend as M
import ../render/mesh.bend as Q

# x, z: node origin (two's complement); ls: 6400 levels, row-major
type Mc is Data:
  Mc{x: U32, z: U32, ls: +List<U32>, qs: +List<Q.Q>}

# levels of column 79 (one per row) and of row 79
def World.col79.go(k: Nat, +ls: +List<U32>) -> +List<U32>:
  match k:
    case 0n:
      []
    case 1n+p:
      Q.Mesh.head(List.drop(&2, U32, ls, 79n), 0) <> World.col79.go(p, List.drop(&2, U32, ls, 80n))

def World.col79(+ls: +List<U32>) -> +List<U32>:
  World.col79.go(80n, ls)

def World.row79(+ls: +List<U32>) -> +List<U32>:
  List.drop(&2, U32, ls, 6320n)

def World.at(+m: Mc, +x: U32, +z: U32) -> Bool:
  Mc{mx, mz, _, _} = m
  (U32.is_eq(mx, x) && U32.is_eq(mz, z))

# the levels of the mapchunk at (x, z), [] when not loaded
def World.levels.pick(hit: Bool, +m: Mc, +rest: +List<U32>) -> +List<U32>:
  match hit:
    case True{}:
      Mc{_, _, ls, _} = m
      ls
    case False{}:
      rest

def World.levels(w: +List<Mc>, +x: U32, +z: U32) -> +List<U32>:
  match w:
    case Con{+m, t}:
      World.levels.pick(World.at(m, x, z), m, World.levels(t, x, z))
    case Nil{}:
      []

def World.col79.or(+ls: +List<U32>) -> +List<U32>:
  match ls:
    case Nil{}:
      []
    case Con{_, _}:
      World.col79(ls)

def World.north.or(+ls: +List<U32>) -> +List<U32>:
  match ls:
    case Nil{}:
      []
    case Con{_, _}:
      World.row79(ls)

# west border levels: column 79 of the mapchunk to the west; north: row 79 above
def World.west(+w: +List<Mc>, +x: U32, +z: U32) -> +List<U32>:
  World.col79.or(World.levels(w, (x - 80 : U32), z))

def World.north(+w: +List<Mc>, +x: U32, +z: U32) -> +List<U32>:
  World.north.or(World.levels(w, x, (z - 80 : U32)))

def World.mesh(+w: +List<Mc>, +x: U32, +z: U32, +ls: +List<U32>) -> +List<Q.Q>:
  Q.Mesh.chunk(ls, x, z, World.west(w, x, z), World.north(w, x, z))

# re-mesh the mapchunk at (x, z) if loaded (world-wide lookups use `all`)
def World.remesh.pick(hit: Bool, +all: +List<Mc>, +m: Mc) -> Mc:
  match hit:
    case True{}:
      Mc{x, z, ls, _} = m
      Mc{x, z, ls, World.mesh(all, x, z, ls)}
    case False{}:
      m

def World.remesh.go(ms: +List<Mc>, +all: +List<Mc>, +x: U32, +z: U32) -> +List<Mc>:
  match ms:
    case Con{+m, t}:
      World.remesh.pick(World.at(m, x, z), all, m) <> World.remesh.go(t, all, x, z)
    case Nil{}:
      []

def World.remesh(+w: +List<Mc>, +x: U32, +z: U32) -> +List<Mc>:
  World.remesh.go(w, w, x, z)

# generate the mapchunk at (x, z), mesh it, then re-mesh its east and south neighbours
def World.load(+ws: U32, +x: U32, +z: U32, +w: +List<Mc>) -> +List<Mc>:
  +ls = M.M.heights(ws, I.I32.to_f32(x), I.I32.to_f32(z))
  +w1 = {Mc{x, z, ls, World.mesh(w, x, z, ls)} <> w : +List<Mc>}
  World.remesh(World.remesh(w1, (x + 80 : U32), z), x, (z + 80 : U32))

def World.count(w: +List<Mc>) -> Nat:
  List.length(&2, Mc, w)
