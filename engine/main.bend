# Bend Voxel Bench entry point.
#   bend engine/main.bend -o build/voxel
#   ./build/voxel --threads 8 -- mapgen 42 out/dump.txt
#   ./build/voxel --threads 8 --gpu off -- render hills1 30 640 480 out/frame.ppm
import Base
import ./bench.bend as B
import ./render/probe.bend as P

# IO.args gives a one-use list; rebuild it as a reusable one
def share(xs: List<String>) -> +List<String>:
  match xs:
    case Con{h, t}:
      h <> share(t)
    case Nil{}:
      []

def mode(render: Bool, +xs: +List<String>) -> IO(Unit):
  match render:
    case True{}:
      P.P.run(xs)
    case False{}:
      B.B.run(xs)

def main() -> IO(Unit):
  do IO<Unit>:
    xs0 : List<String> <- IO.args()
    +xs : +List<String> = share(xs0)
    mode(String.eq(Maybe.default(&2, String, List.get(&2, String, xs, 0n), ""), "render"), xs)
