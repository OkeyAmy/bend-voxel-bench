# Camera, sky, frame (one bang) and PPM dump.
import Base
import ../mapgen.bend as M
import ./bend3d.bend as R

# the eye and its basis from yaw and pitch (as Bend's Fly demo); focal 0.8125 w
def V.cam(+ex: F32, +ey: F32, +ez: F32, +yaw: F32, +pitch: F32, +w: U32, +h: U32) -> R.Cam:
  +sy = F32.sin(yaw)
  +cy = F32.cos(yaw)
  +sp = F32.sin(pitch)
  +cp = F32.cos(pitch)
  R.Cam{R.Vec{ex, ey, ez}, R.Vec{cy, 0.0, (0.0 - sy : F32)},
    R.Vec{(0.0 - sp * sy : F32), cp, (0.0 - sp * cy : F32)},
    R.Vec{(sy * cp : F32), sp, (cy * cp : F32)}, (0.8125 * U32.to_f32(w) : F32),
    (0.5 * U32.to_f32(w) : F32), (0.5 * U32.to_f32(h) : F32), 0.1, w, h}

# sky: a blue gradient by row (over 720 rows), one colour per 16-px tile
def V.sky_of(+x: U32, +y: U32, +h: U32) -> U32:
  +t = R.sat((U32.to_f32(y) / 720.0 : F32))
  R.pack((0.35 + 0.35 * t : F32), (0.55 + 0.3 * t : F32), (0.95 - 0.1 * t : F32))

def V.sky_flat(+s: U32, +x: U32, +y: U32, +h: U32) -> Bool:
  False{}

def V.sky_col(per: Bool, +x: U32, +s: U32) -> U32:
  s

def V.sky_at(+x: U32, +y: U32, +s: U32) -> U32:
  s

# frame sizes are compile-time constants of Bend3D (its Hook.dim templates)
def V.w640() -> U32:
  640

def V.h480() -> U32:
  480

def V.w1280() -> U32:
  1280

def V.h720() -> U32:
  720

def V.frame640(cells: R.Cells, old: Image) -> Image & R.Cells:
  R.Frame.show(~U32, ~V.sky_of, ~V.sky_flat, ~V.sky_col, ~V.sky_at, ~V.w640, ~V.h480, cells, old)

def V.frame1280(cells: R.Cells, old: Image) -> Image & R.Cells:
  R.Frame.show(~U32, ~V.sky_of, ~V.sky_flat, ~V.sky_col, ~V.sky_at, ~V.w1280, ~V.h720, cells, old)

def V.frame(big: Bool, cells: R.Cells, old: Image) -> Image & R.Cells:
  match big:
    case True{}:
      V.frame1280(cells, old)
    case False{}:
      V.frame640(cells, old)

# ---- PPM ----

def V.pick4(right: Bool, low: Bool, +a: Image, +b: Image, +c: Image, +d: Image) -> Image:
  match right low:
    case False{} False{}:
      a
    case True{} False{}:
      b
    case False{} True{}:
      c
    case True{} True{}:
      d

# the colour at (x, y) of an image covering an s-square (Bend3D's root is 2048)
def V.px(k: Nat, +img: Image, +x: U32, +y: U32, +s: U32) -> U32:
  match k img:
    case _ Pix{+c}:
      c
    case 0n _:
      0
    case 1n+p Qua{+a, +b, +c, +d}:
      +h = (s / 2 : U32)
      +right = (x >= h : U32)
      +low = (y >= h : U32)
      V.px(p, V.pick4(right, low, a, b, c, d), (x - M.word(right, h, 0) : U32),
        (y - M.word(low, h, 0) : U32), h)

# pixels x .. x+k of row y as "r g b " text, right-nested (linear cost)
def V.row(k: Nat, +img: Image, +x: U32, +y: U32) -> String:
  match k:
    case 0n:
      "\n"
    case 1n+p:
      +c = V.px(12n, img, x, y, 2048)
      U32.show((c / 65536 % 256 : U32)) ++ " " ++ U32.show((c / 256 % 256 : U32)) ++ " "
        ++ U32.show((c % 256 : U32)) ++ " " ++ V.row(p, img, (x + 1 : U32), y)

def V.keep(fw: File & Result<&1, &1, U32 & String, Unit>) -> IO(File):
  (f, r) = fw
  IO.pure(File, f)

def V.rows(k: Nat, +img: Image, +w: Nat, +y: U32, f: File) -> IO(File):
  match k:
    case 0n:
      IO.pure(File, f)
    case 1n+p:
      do IO<File>:
        fw : File & Result<&1, &1, U32 & String, Unit> <- File.write(f, V.row(w, img, 0, y))
        f2 : File <- V.keep(fw)
        V.rows(p, img, w, (y + 1 : U32), f2)

def V.ppm(+img: Image, +w: U32, +h: U32, path: String) -> IO(Unit):
  do IO<Unit>:
    f : File <- IO.try(File, File.open(path, "w"))
    fw : File & Result<&1, &1, U32 & String, Unit> <- File.write(f,
      "P3\n" ++ U32.show(w) ++ " " ++ U32.show(h) ++ "\n255\n")
    f2 : File <- V.keep(fw)
    f3 : File <- V.rows(U32.to_nat(h), img, U32.to_nat(w), 0, f2)
    File.close(f3)
