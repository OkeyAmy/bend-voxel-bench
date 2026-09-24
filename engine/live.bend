# The live race: run harness/live_race.ts for the 100 mapchunks around (x, z)
# through Proc.run, then read its result file.
import Base
import ./i32.bend as I
import ./hud.bend as H
import ./sys/proc.bend as P

def Live.text(+code: U32, r: Result<&1, &1, U32 & String, String>) -> IO(H.LiveR):
  match r:
    case Done{txt}:
      IO.pure(H.LiveR, H.Hud.live(code, txt))
    case Fail{_}:
      IO.pure(H.LiveR, H.Hud.live(code, ""))

def Live.got(+code: U32, fr: File & Result<&1, &1, U32 & String, String>) -> IO(H.LiveR):
  (f, r) = fr
  do IO<H.LiveR>:
    File.close(f)
    Live.text(code, r)

def Live.opened(+code: U32, r: Result<&1, &1, U32 & String, File>) -> IO(H.LiveR):
  match r:
    case Done{f}:
      do IO<H.LiveR>:
        fr : File & Result<&1, &1, U32 & String, String> <- File.read(f, 65536)
        Live.got(code, fr)
    case Fail{_}:
      IO.pure(H.LiveR, H.Hud.live(code, ""))

# run the race (the program pauses meanwhile), print its exit code, read the result
def Live.run(+seed: U32, +x: U32, +z: U32) -> IO(H.LiveR):
  do IO<H.LiveR>:
    +code : U32 <- P.Proc.run("mkdir -p out; rm -f out/live_race.txt; node harness/live_race.ts " ++ I.I32.show(seed) ++ " "
      ++ I.I32.show(x) ++ " " ++ I.I32.show(z) ++ " > out/live_race.log 2>&1")
    IO.print("live_race exit " ++ U32.show(code))
    r : Result<&1, &1, U32 & String, File> <- File.open("out/live_race.txt", "r")
    Live.opened(code, r)
