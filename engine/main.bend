# Bend Voxel Bench entry point.
#   bend engine/main.bend -o build/voxel
#   ./build/voxel --threads 8 -- mapgen 42 out/dump.txt
#   ./build/voxel --threads 8 --gpu off -- render hills1 30 640 480 out/frame.ppm
#   ./build/voxel --threads 8 --gpu off -- play [seed]
import Base
import ./bench.bend as B
import ./render/probe.bend as P
import ./world/stream_cli.bend as SC
import ./game.bend as G

# IO.args gives a one-use list; rebuild it as a reusable one
def share(xs: List<String>) -> +List<String>:
  match xs:
    case Con{h, t}:
      h <> share(t)
    case Nil{}:
      []

def mode.play(play: Bool, +xs: +List<String>) -> IO(Unit):
  match play:
    case True{}:
      G.G.play(xs)
    case False{}:
      B.B.run(xs)

def mode.keys(keys: Bool, +xs: +List<String>) -> IO(Unit):
  match keys:
    case True{}:
      G.G.sim(xs)
    case False{}:
      mode.play(String.eq(Maybe.default(&2, String, List.get(&2, String, xs, 0n), ""), "play"), xs)

def mode.stream(stream: Bool, +xs: +List<String>) -> IO(Unit):
  match stream:
    case True{}:
      SC.SC.run(xs)
    case False{}:
      mode.keys(String.eq(Maybe.default(&2, String, List.get(&2, String, xs, 0n), ""), "keys-sim"), xs)

def mode(render: Bool, +xs: +List<String>) -> IO(Unit):
  match render:
    case True{}:
      P.P.run(xs)
    case False{}:
      mode.stream(String.eq(Maybe.default(&2, String, List.get(&2, String, xs, 0n), ""), "stream-order"), xs)

def main() -> IO(Unit):
  do IO<Unit>:
    xs0 : List<String> <- IO.args()
    +xs : +List<String> = share(xs0)
    mode(String.eq(Maybe.default(&2, String, List.get(&2, String, xs, 0n), ""), "render"), xs)
