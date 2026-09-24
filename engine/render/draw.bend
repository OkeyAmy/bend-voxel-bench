# Quads -> Bend3D screen cells: project the four corners, then two triangles.
import Base
import ./bend3d.bend as R
import ./mesh.bend as Q

def Draw.vert.go(+sp: R.Vec, +c: R.Vec) -> R.Vert:
  R.Vec{x, y, w} = sp
  R.Vec{r, g, b} = c
  R.Vert{x, y, w, r, g, b}

# fog: the colour mixes towards the horizon sky with horizontal distance,
# from none at 100 blocks to full at 200 (height above the ground doesn't count)
# v with its height set to 0
def Draw.flat(+v: R.Vec) -> R.Vec:
  R.Vec{x, _, z} = v
  R.Vec{x, 0.0, z}

def Draw.hdist(+a: R.Vec, +b: R.Vec) -> F32:
  R.Vec.len(R.Vec.sub(Draw.flat(a), Draw.flat(b)))

# fog0: where the fog starts (100 blocks; a huge value turns the fog off)
def Draw.fogged(+fog0: F32, +cam: R.Cam, +p: R.Vec, +c: R.Vec) -> R.Vec:
  R.Cam{eye, _, _, _, _, _, _, _, _, _} = cam
  +f = R.sat(((Draw.hdist(p, eye) - fog0) / 100.0 : F32))
  R.Vec.mix(c, R.Vec{0.525, 0.702, 0.902}, f)

def Draw.vert(+fog0: F32, +cam: R.Cam, +p: R.Vec, +c: R.Vec) -> R.Vert:
  Draw.vert.go(R.Cam.proj(cam, p), Draw.fogged(fog0, cam, p, c))

# a b c d as triangles (a b c) and (a c d); mode 1 keeps both windings (diag)
def Draw.tri2(+a: R.Vert, +b: R.Vert, +c: R.Vert, +d: R.Vert, +m: U32, +x1: F32, +y1: F32,
    cells: R.Cells) -> R.Cells:
  R.Mesh.raster(a, c, d, m, 1.0, x1, y1, R.Mesh.raster(a, b, c, m, 1.0, x1, y1, cells))

def Draw.pick(flip: Bool, +a: R.Vert, +b: R.Vert, +c: R.Vert, +d: R.Vert, +m: U32, +x1: F32,
    +y1: F32, cells: R.Cells) -> R.Cells:
  match flip:
    case False{}:
      Draw.tri2(a, b, c, d, m, x1, y1, cells)
    case True{}:
      Draw.tri2(a, d, c, b, m, x1, y1, cells)

def Draw.quad(+fog0: F32, +q: Q.Q, +cam: R.Cam, +m: U32, +x1: F32, +y1: F32, cells: R.Cells) -> R.Cells:
  Q.Q{+a, +b, +c, +d, +col, flip} = q
  Draw.pick(flip, Draw.vert(fog0, cam, a, col), Draw.vert(fog0, cam, b, col), Draw.vert(fog0, cam, c, col),
    Draw.vert(fog0, cam, d, col), m, x1, y1, cells)

# every quad of qs into the cells of a frame whose last pixel is (x1, y1)
def Draw.quads(qs: +List<Q.Q>, +fog0: F32, +cam: R.Cam, +m: U32, +x1: F32, +y1: F32, cells: R.Cells) -> R.Cells:
  match qs:
    case Con{+q, t}:
      Draw.quads(t, fog0, cam, m, x1, y1, Draw.quad(fog0, q, cam, m, x1, y1, cells))
    case Nil{}:
      cells

# ---- culling: is the mapchunk box (x0..x0+80, y -20..140, z0..z0+80) in view? ----

type Side is Data:
  Side{behind: Bool, left: Bool, right: Bool}

# where one corner lies against the camera's near, left and right planes
def Draw.side(+cam: R.Cam, +c: R.Vec) -> Side:
  R.Cam{eye, right, _, fwd, focal, _, _, near, w, _} = cam
  +r = R.Vec.sub(c, eye)
  +d = R.Vec.dot(r, fwd)
  +sx = R.Vec.dot(r, right)
  +k = (0.5 * U32.to_f32(w) / focal : F32)
  Side{(d < near : F32), (sx < (0.0 - k * d - 2.0) : F32), (sx > (k * d + 2.0) : F32)}

def Draw.and(+a: Side, +b: Side) -> Side:
  Side{ab, al, ar} = a
  Side{bb, bl, br} = b
  Side{(ab && bb), (al && bl), (ar && br)}

def Draw.corners(+cam: R.Cam, +x0: F32, +z0: F32, +y: F32) -> Side:
  +x1 = (x0 + 80.0 : F32)
  +z1 = (z0 + 80.0 : F32)
  Draw.and(Draw.and(Draw.side(cam, R.Vec{x0, y, z0}), Draw.side(cam, R.Vec{x1, y, z0})),
    Draw.and(Draw.side(cam, R.Vec{x0, y, z1}), Draw.side(cam, R.Vec{x1, y, z1})))

def Draw.visible.go(+s: Side) -> Bool:
  Side{b, l, r} = s
  Bool.not((b || l || r))

# the fog distance: mapchunks whose nearest point is farther are not drawn
def Draw.fog() -> F32:
  160.0

# horizontal distance from the eye to the nearest point of the mapchunk box
def Draw.dist(+cam: R.Cam, +x0: F32, +z0: F32) -> F32:
  R.Cam{eye, _, _, _, _, _, _, _, _, _} = cam
  R.Vec{ex, _, ez} = eye
  +dx = R.max(0.0, R.max((x0 - ex : F32), (ex - x0 - 80.0 : F32)))
  +dz = R.max(0.0, R.max((z0 - ez : F32), (ez - z0 - 80.0 : F32)))
  F32.sqrt((dx * dx + dz * dz : F32))

# visible unless all 8 corners are behind, or all left, or all right, or it is past the fog
def Draw.visible(+cam: R.Cam, +x0: F32, +z0: F32) -> Bool:
  (Draw.visible.go(Draw.and(Draw.corners(cam, x0, z0, (0.0 - 20.0 : F32)), Draw.corners(cam, x0, z0, 140.0)))
    && (Draw.dist(cam, x0, z0) <= Draw.fog() : F32))
