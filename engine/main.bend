# Bend Voxel Bench entry point. Plan 1 has one mode: the mapgen bench.
#   bend engine/main.bend -o build/voxel
#   ./build/voxel --threads 8 -- mapgen 42 out/dump.txt
import Base
import ./bench.bend as B

# IO.args gives a one-use list; rebuild it as a reusable one
def share(xs: List<String>) -> +List<String>:
  match xs:
    case Con{h, t}:
      h <> share(t)
    case Nil{}:
      []

def main() -> IO(Unit):
  do IO<Unit>:
    xs : List<String> <- IO.args()
    B.B.run(share(xs))
