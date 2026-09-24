# Prints the F32 bits of the four mapgen v7 terrain noise maps for one mapchunk,
# one line per point in row-major order: persist base alt height_select.
#   ./build/noise_golden -- <seed> <x> <z>
import Base
import ../i32.bend as I
import ../noise.bend as Z

def out(ps: +List<F32>, bs: +List<F32>, as: +List<F32>, hs: +List<F32>) -> IO(Unit):
  match ps bs as hs:
    case Con{+p, pt} Con{+b, bt} Con{+a, at} Con{+h, ht}:
      do IO<Unit>:
        IO.print(U32.show(F32.bits(p)) ++ " " ++ U32.show(F32.bits(b)) ++ " "
          ++ U32.show(F32.bits(a)) ++ " " ++ U32.show(F32.bits(h)))
        out(pt, bt, at, ht)
    case _ _ _ _:
      IO.pure(Unit, Unit{})

def run(+ws: U32, +ox: F32, +oz: F32) -> IO(Unit):
  +pm = Z.N.map2d(Z.NP{0.6, 0.1, 2000.0, 539, 3n, 0.6, 2.0}, ws, 80n, 80n, ox, oz,
    List.replicate(F32, 6400n, 0.6))
  +hb = Z.N.map2d(Z.NP{4.0, 70.0, 600.0, 82341, 5n, 0.6, 2.0}, ws, 80n, 80n, ox, oz, pm)
  +ha = Z.N.map2d(Z.NP{4.0, 25.0, 600.0, 5934, 5n, 0.6, 2.0}, ws, 80n, 80n, ox, oz, pm)
  +hh = Z.N.map2d(Z.NP{(0.0 - 8.0 : F32), 16.0, 500.0, 4213, 6n, 0.7, 2.0}, ws, 80n, 80n,
    ox, oz, List.replicate(F32, 6400n, 0.7))
  out(List.reverse(&2, F32, pm), List.reverse(&2, F32, hb), List.reverse(&2, F32, ha),
    List.reverse(&2, F32, hh))

def share(xs: List<String>) -> +List<String>:
  match xs:
    case Con{h, t}:
      h <> share(t)
    case Nil{}:
      []

def arg(xs: +List<String>, n: Nat) -> U32:
  Maybe.default(&2, U32, I.I32.read(Maybe.default(&2, String, List.get(&2, String, xs, n), "0")), 0)

def main() -> IO(Unit):
  do IO<Unit>:
    xs0 : List<String> <- IO.args()
    +xs : +List<String> = share(xs0)
    run(arg(xs, 0n), I.I32.to_f32(arg(xs, 1n)), I.I32.to_f32(arg(xs, 2n)))
