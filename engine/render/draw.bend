# Quads -> Bend3D screen cells: project the four corners, then two triangles.
import Base
import ./bend3d.bend as R
import ./mesh.bend as Q

def Draw.vert.go(+sp: R.Vec, +c: R.Vec) -> R.Vert:
  R.Vec{x, y, w} = sp
  R.Vec{r, g, b} = c
  R.Vert{x, y, w, r, g, b}

def Draw.vert(+cam: R.Cam, +p: R.Vec, +c: R.Vec) -> R.Vert:
  Draw.vert.go(R.Cam.proj(cam, p), c)

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

def Draw.quad(+q: Q.Q, +cam: R.Cam, +m: U32, +x1: F32, +y1: F32, cells: R.Cells) -> R.Cells:
  Q.Q{+a, +b, +c, +d, +col, flip} = q
  Draw.pick(flip, Draw.vert(cam, a, col), Draw.vert(cam, b, col), Draw.vert(cam, c, col),
    Draw.vert(cam, d, col), m, x1, y1, cells)

# every quad of qs into the cells of a frame whose last pixel is (x1, y1)
def Draw.quads(qs: +List<Q.Q>, +cam: R.Cam, +m: U32, +x1: F32, +y1: F32, cells: R.Cells) -> R.Cells:
  match qs:
    case Con{+q, t}:
      Draw.quads(t, cam, m, x1, y1, Draw.quad(q, cam, m, x1, y1, cells))
    case Nil{}:
      cells
