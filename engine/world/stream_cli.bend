# voxel -- stream-order <seed> <px> <pz> <frames> <speed-tenths>
# The player flies along +x at speed/10 blocks per frame; every frame runs one
# streaming step. Prints "load <frame> <x> <z>" per load, then "loaded <n>".
import Base
import ../i32.bend as I
import ./world.bend as W
import ./stream.bend as S

def SC.print(+m: Maybe<&2, S.S.Off>, +f: U32) -> IO(Unit):
  match m:
    case Some{S.S.Off{+x, +z}}:
      IO.print("load " ++ U32.show(f) ++ " " ++ I.I32.show(x) ++ " " ++ I.I32.show(z))
    case None{}:
      IO.pure(Unit, Unit{})

def SC.after(+st: S.S.Step, +f: U32) -> IO(+List<W.Mc>):
  S.S.Step{+w, +got} = st
  do IO<+List<W.Mc>>:
    SC.print(got, f)
    return w

def SC.loop(k: Nat, +ws: U32, +px: F32, +pz: F32, +v: F32, +f: U32, +w: +List<W.Mc>) -> IO(Unit):
  match k:
    case 0n:
      IO.print("loaded " ++ Nat.show(W.World.count(w)))
    case 1n+p:
      do IO<Unit>:
        +w2 : +List<W.Mc> <- SC.after(S.S.step(ws, px, pz, w), f)
        SC.loop(p, ws, (px + v : F32), pz, v, (f + 1 : U32), w2)

def SC.arg(xs: +List<String>, n: Nat) -> U32:
  Maybe.default(&2, U32, I.I32.read(Maybe.default(&2, String, List.get(&2, String, xs, n), "0")), 0)

# args: ["stream-order", seed, px, pz, frames, speed-tenths]
def SC.run(+args: +List<String>) -> IO(Unit):
  SC.loop(U32.to_nat(SC.arg(args, 4n)), SC.arg(args, 1n), I.I32.to_f32(SC.arg(args, 2n)),
    I.I32.to_f32(SC.arg(args, 3n)), (U32.to_f32(SC.arg(args, 5n)) / 10.0 : F32), 0, [])
