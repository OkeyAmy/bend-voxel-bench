# The race panel: live frame timings next to the race results against Luanti.
# The race numbers come from out/race.txt (written by harness/hud_export.ts):
# "key value" lines, per-mapchunk terrain times in whole microseconds.
# Bend3D's font has capitals, digits and % / + . , ' - only.
import Base
import ./render/bend3d.bend as R
import ./i32.bend as I

# the race button's state: st 0 idle, 1 racing, 2 done; n mapchunks loaded; sum of their ms
type RaceSt is Data:
  RaceSt{st: U32, n: U32, sum: U32}

type Race is Data:
  Race{ok: Bool, luanti: U32, b1: U32, b8: U32, par: U32, commit: String}

# a live race's result (out/live_race.txt); ms values x 10; has: a race has run
# load: x 100, or 4294967295 when unknown
type LiveR is Data:
  LiveR{has: Bool, code: U32, ok: Bool, b1: U32, b8: U32, l1: U32, par: U32, power: String, load: U32,
    x0: U32, z0: U32, gov: String}

def Hud.nolive() -> LiveR:
  LiveR{False{}, 0, False{}, 0, 0, 0, 0, "", 0, 0, 0, ""}

# the font has capitals only
def Hud.upper(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{h, t}:
      SCon{Char.to_upper(h), Hud.upper(t)}

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

# a live race's file after the race exited with `code`
def Hud.live(+code: U32, +txt: String) -> LiveR:
  +ls = String.lines(txt)
  LiveR{True{}, code, (U32.is_eq(code, 0) && U32.is_eq(Hud.num(ls, "ok"), 1)), Hud.num(ls, "bend1_ms10"),
    Hud.num(ls, "bend8_ms10"), Hud.num(ls, "luanti1_ms10"), Hud.num(ls, "parity_pct"), Hud.val(ls, "power"),
    Maybe.default(&2, U32, U32.read(Hud.val(ls, "load100")), 4294967295),
    Maybe.default(&2, U32, I.I32.read(Hud.val(ls, "x0")), 0),
    Maybe.default(&2, U32, I.I32.read(Hud.val(ls, "z0")), 0), Hud.val(ls, "governor")}

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

# the stored race (out/race.txt), labelled with its commit so it can't pass as live
def Hud.race.go(ok: Bool, +lu: U32, +b1: U32, +b8: U32, +par: U32, +commit: String, +x1: F32, +y1: F32,
    cells: R.Cells) -> R.Cells:
  match ok:
    case True{}:
      Hud.line(84.0, "SAME BLOCKS AS LUANTI " ++ Hud.pct(par) ++ " %  - PRESS G FOR A LIVE RACE HERE", x1, y1,
        Hud.line(60.0, "STORED RACE " ++ Hud.upper(commit) ++ "  PER MAPCHUNK  BEND " ++ Hud.ms1(b1) ++ " MS  8T "
          ++ Hud.ms1(b8) ++ " MS  LUANTI C++ " ++ Hud.ms1(lu) ++ " MS", x1, y1, cells))
    case False{}:
      Hud.line(60.0, "LUANTI - RUN THE RACE FIRST", x1, y1, cells)

def Hud.race(+race: Race, +x1: F32, +y1: F32, cells: R.Cells) -> R.Cells:
  Race{ok, +lu, +b1, +b8, +par, +commit} = race
  Hud.race.go(ok, lu, b1, b8, par, commit, x1, y1, cells)

def Hud.load100.go(unknown: Bool, +v: U32) -> String:
  match unknown:
    case True{}:
      "UNKNOWN"
    case False{}:
      Hud.pct(v)

# load x 100 as "1.62", or UNKNOWN
def Hud.load100(+v: U32) -> String:
  Hud.load100.go(U32.is_eq(v, 4294967295), v)

# ms x 10 as "13.5"
def Hud.ms10(+v: U32) -> String:
  U32.show((v / 10 : U32)) ++ "." ++ U32.show((v % 10 : U32))

def Hud.power.go(ac: Bool, bat: Bool) -> String:
  match ac bat:
    case True{} _:
      "AC POWER"
    case False{} True{}:
      "ON BATTERY"
    case False{} False{}:
      "POWER UNKNOWN"

def Hud.power(+p: String) -> String:
  Hud.power.go(String.eq(p, "ac"), String.eq(p, "battery"))

def Hud.live.lines(ok: Bool, +lv: LiveR, +x1: F32, +y1: F32, cells: R.Cells) -> R.Cells:
  match ok:
    case True{}:
      LiveR{_, _, _, +b1, +b8, +l1, +par, +pw, +load, +x0, +z0, +gov} = lv
      Hud.line(84.0, "TERRAIN, 100 MAPCHUNKS  SAME BLOCKS " ++ Hud.pct(par) ++ " %  " ++ Hud.power(pw)
        ++ "  LOAD " ++ Hud.load100(load) ++ "  " ++ Hud.upper(gov), x1, y1,
        Hud.line(60.0, "LIVE RACE AT " ++ I.I32.show(x0) ++ "," ++ I.I32.show(z0) ++ "  BEND 1T " ++ Hud.ms10(b1)
          ++ " MS  8T " ++ Hud.ms10(b8) ++ " MS  LUANTI C++ 1T " ++ Hud.ms10(l1) ++ " MS", x1, y1, cells))
    case False{}:
      Hud.line(60.0, "LIVE RACE FAILED - SEE OUT/LIVE_RACE.LOG", x1, y1, cells)

def Hud.races.go(has: Bool, ok: Bool, +race: Race, +lv: LiveR, +x1: F32, +y1: F32, cells: R.Cells) -> R.Cells:
  match has:
    case True{}:
      Hud.live.lines(ok, lv, x1, y1, cells)
    case False{}:
      Hud.race(race, x1, y1, cells)

# the race lines: the live race once one has run, else the stored race
def Hud.races(+race: Race, +lv: LiveR, +x1: F32, +y1: F32, cells: R.Cells) -> R.Cells:
  LiveR{has, _, ok, _, _, _, _, _, _, _, _, _} = lv
  Hud.races.go(has, ok, race, lv, x1, y1, cells)

def Hud.load.go(none: Bool, +ms: U32) -> String:
  match none:
    case True{}:
      "-"
    case False{}:
      U32.show(ms) ++ " MS"

# the last load in ms, or "-" before the first one (4294967295)
def Hud.load(+ms: U32) -> String:
  Hud.load.go(U32.is_eq(ms, 4294967295), ms)

def Hud.button.go(on: Bool, +rs: RaceSt, +lu: U32, +x1: F32, +y1: F32, cells: R.Cells) -> R.Cells:
  match on:
    case False{}:
      cells
    case True{}:
      RaceSt{_, +n, +sum} = rs
      Hud.line(108.0, "RACE " ++ U32.show(n) ++ "/25  BEND GEN+MESH " ++ U32.show(sum)
        ++ " MS  LUANTI C++ TERRAIN " ++ Hud.ms1((lu * 25 : U32)) ++ " MS", x1, y1, cells)

# the race button's line, once it has been pressed
def Hud.button(+rs: RaceSt, +race: Race, +x1: F32, +y1: F32, cells: R.Cells) -> R.Cells:
  RaceSt{+st, _, _} = rs
  Race{_, +lu, _, _, _, _} = race
  Hud.button.go((st > 0 : U32), rs, lu, x1, y1, cells)

# the panel: frame ms, build and draw ms, the last new mapchunk's gen + mesh ms,
# the race line, the parity line, and the race button's line
def Hud.draw(+race: Race, +lv: LiveR, +rs: RaceSt, +frame: U32, +build: U32, +draw: U32, +load: U32, +x1: F32,
    +y1: F32, cells: R.Cells) -> R.Cells:
  +fps = (1000 / R.word((frame > 0 : U32), frame, 1) : U32)
  +c1 = R.Quad.put(10.0, 10.0, 10.0, 136.0, 900.0, 136.0, 900.0, 10.0, 2000.0, 2765136, 0, 1.0,
    x1, y1, cells)
  +c2 = Hud.line(12.0, "FPS " ++ U32.show(fps) ++ "  BUILD " ++ U32.show(build) ++ " MS  DRAW "
    ++ U32.show(draw) ++ " MS", x1, y1, c1)
  +c3 = Hud.line(36.0, "NEW MAPCHUNK GEN+MESH " ++ Hud.load(load), x1, y1, c2)
  Hud.button(rs, race, x1, y1, Hud.races(race, lv, x1, y1, c3))
