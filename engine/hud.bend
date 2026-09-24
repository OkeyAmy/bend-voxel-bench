# The race panel: live frame timings next to the race results against Luanti.
# The race numbers come from out/race.txt (written by harness/hud_export.ts):
# "key value" lines, per-mapchunk terrain times in whole microseconds.
# Bend3D's font has capitals, digits and % / + . , ' - only.
import Base
import ./render/bend3d.bend as R

type Race is Data:
  Race{ok: Bool, luanti: U32, b1: U32, b8: U32, par: U32, commit: String}

def Hud.none() -> Race:
  Race{False{}, 0, 0, 0, 0, ""}

# the text after "key " on the line that starts with it, else ""
def Hud.val.pick(hit: Bool, +l: String, +key: String, +rest: String) -> String:
  match hit:
    case True{}:
      String.drop(l, Nat.add(String.length(key), 1n))
    case False{}:
      rest

def Hud.val(ls: +List<String>, +key: String) -> String:
  match ls:
    case Con{+l, t}:
      Hud.val.pick(String.starts_with(l, key ++ " "), l, key, Hud.val(t, key))
    case Nil{}:
      ""

def Hud.num(+ls: +List<String>, +key: String) -> U32:
  Maybe.default(&2, U32, U32.read(Hud.val(ls, key)), 0)

def Hud.parse(+txt: String) -> Race:
  +ls = String.lines(txt)
  +lu = Hud.num(ls, "luanti_us_per_mapchunk")
  Race{(lu > 0 : U32), lu, Hud.num(ls, "bend1_us_per_mapchunk"), Hud.num(ls, "bend8_us_per_mapchunk"),
    Hud.num(ls, "parity_pct"), Hud.val(ls, "commit")}

def Hud.text(r: Result<&1, &1, U32 & String, String>) -> IO(Race):
  match r:
    case Done{txt}:
      IO.pure(Race, Hud.parse(txt))
    case Fail{_}:
      IO.pure(Race, Hud.none())

def Hud.got(fr: File & Result<&1, &1, U32 & String, String>) -> IO(Race):
  (f, r) = fr
  do IO<Race>:
    File.close(f)
    Hud.text(r)

def Hud.opened(r: Result<&1, &1, U32 & String, File>) -> IO(Race):
  match r:
    case Done{f}:
      do IO<Race>:
        fr : File & Result<&1, &1, U32 & String, String> <- File.read(f, 65536)
        Hud.got(fr)
    case Fail{_}:
      IO.pure(Race, Hud.none())

# the race numbers, or Race{False, ...} when the file is missing or unreadable
def Hud.read(path: String) -> IO(Race):
  do IO<Race>:
    r : Result<&1, &1, U32 & String, File> <- File.open(path, "r")
    Hud.opened(r)

# ---- drawing ----

# microseconds as milliseconds with one decimal: 13500 -> "13.5"
def Hud.ms1(+us: U32) -> String:
  U32.show((us / 1000 : U32)) ++ "." ++ U32.show((us / 100 % 10 : U32))

# percent x 100 as "100.00"
def Hud.pct(+p: U32) -> String:
  +c = (p % 100 : U32)
  U32.show((p / 100 : U32)) ++ "." ++ U32.show((c / 10 : U32)) ++ U32.show((c % 10 : U32))

def Hud.line(+y: F32, s: String, +x1: F32, +y1: F32, cells: R.Cells) -> R.Cells:
  R.Text.put(20.0, y, 18.0, 0, 16777215, s, x1, y1, cells)

def Hud.race.go(ok: Bool, +lu: U32, +b1: U32, +b8: U32, +par: U32, +x1: F32, +y1: F32,
    cells: R.Cells) -> R.Cells:
  match ok:
    case True{}:
      Hud.line(84.0, "SAME BLOCKS AS LUANTI " ++ Hud.pct(par) ++ " %", x1, y1,
        Hud.line(60.0, "RACE PER MAPCHUNK  BEND " ++ Hud.ms1(b1) ++ " MS  8T " ++ Hud.ms1(b8)
          ++ " MS  LUANTI C++ " ++ Hud.ms1(lu) ++ " MS", x1, y1, cells))
    case False{}:
      Hud.line(60.0, "LUANTI - RUN THE RACE FIRST", x1, y1, cells)

def Hud.race(+race: Race, +x1: F32, +y1: F32, cells: R.Cells) -> R.Cells:
  Race{ok, +lu, +b1, +b8, +par, _} = race
  Hud.race.go(ok, lu, b1, b8, par, x1, y1, cells)

def Hud.load.go(none: Bool, +ms: U32) -> String:
  match none:
    case True{}:
      "-"
    case False{}:
      U32.show(ms) ++ " MS"

# the last load in ms, or "-" before the first one (4294967295)
def Hud.load(+ms: U32) -> String:
  Hud.load.go(U32.is_eq(ms, 4294967295), ms)

# the panel: frame ms, build and draw ms, the last new mapchunk's gen + mesh ms,
# then the race line and the parity line
def Hud.draw(+race: Race, +frame: U32, +build: U32, +draw: U32, +load: U32, +x1: F32, +y1: F32,
    cells: R.Cells) -> R.Cells:
  +fps = (1000 / R.word((frame > 0 : U32), frame, 1) : U32)
  +c1 = R.Quad.put(10.0, 10.0, 10.0, 112.0, 760.0, 112.0, 760.0, 10.0, 2000.0, 2765136, 0, 1.0,
    x1, y1, cells)
  +c2 = Hud.line(12.0, "FPS " ++ U32.show(fps) ++ "  BUILD " ++ U32.show(build) ++ " MS  DRAW "
    ++ U32.show(draw) ++ " MS", x1, y1, c1)
  +c3 = Hud.line(36.0, "NEW MAPCHUNK GEN+MESH " ++ Hud.load(load), x1, y1, c2)
  Hud.race(race, x1, y1, c3)
