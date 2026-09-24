# Prints the 6400 surface levels (signed) of one mapchunk, row-major.
#   ./build/level_golden -- <seed> <x> <z>
import Base
import ../i32.bend as I
import ../mapgen.bend as M

def out(ls: +List<U32>) -> IO(Unit):
  match ls:
    case Con{+l, t}:
      do IO<Unit>:
        IO.print(I.I32.show(l))
        out(t)
    case Nil{}:
      IO.pure(Unit, Unit{})

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
    out(M.M.heights(arg(xs, 0n), I.I32.to_f32(arg(xs, 1n)), I.I32.to_f32(arg(xs, 2n))))
