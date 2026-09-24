# Port of Luanti 5.17.0 MapgenV7 base terrain (src/mapgen/mapgen_v7.cpp:
# generateTerrain, baseTerrainLevelFromMap), with mountains, ridges,
# floatlands, caverns, caves, dungeons, decorations, biomes and ores off.
# LGPL-2.1-or-later.
import Base
import ./i32.bend as I
import ./noise.bend as Z

def pick(c: Bool, +a: F32, +b: F32) -> F32:
  match c:
    case True{}:
      a
    case False{}:
      b

def word(c: Bool, +a: U32, +b: U32) -> U32:
  match c:
    case True{}:
      a
    case False{}:
      b

# baseTerrainLevelFromMap, then the (s16) conversion in generateTerrain
def M.level(+hb: F32, +ha: F32, +h: F32) -> U32:
  +hs = pick((h < 0.0 : F32), 0.0, pick((h > 1.0 : F32), 1.0, h))
  +lvl = pick((ha > hb : F32), ha, ((hb * hs) + (ha * (1.0 - hs)) : F32))
  I.I32.trunc(lvl)

# Block ids, 4 bits each: 0 air, 1 stone, 2 water (water_level = 1)
def M.block(+y: U32, +s: U32) -> U32:
  word(I.I32.le(y, s), 1, word(I.I32.le(y, 1), 2, 0))

# 8 blocks from y upwards in one word, block b at bits 4b .. 4b+3
def M.pack(k: Nat, +y: U32, +s: U32, +acc: U32, +sh: U32) -> U32:
  match k:
    case 0n:
      acc
    case 1n+p:
      M.pack(p, (y + 1 : U32), s, (acc + (M.block(y, s) * sh) : U32), (sh * 16 : U32))

# one column (80 blocks = 10 words) at word index i
def M.column(k: Nat, a: Array<U32>, +i: U32, +y: U32, +s: U32) -> Array<U32>:
  match k:
    case 0n:
      a
    case 1n+p:
      a[i] <- M.pack(8n, y, s, 0, 1)
      M.column(p, a, (i + 1 : U32), (y + 8 : U32), s)

# a mapchunk's blocks from its 6400 surface levels (row-major: z outer, x inner)
def M.fill(hs: +List<U32>, a: Array<U32>, +i: U32, +ymin: U32) -> Array<U32>:
  match hs:
    case Con{+s, t}:
      M.fill(t, M.column(10n, a, i, ymin, s), (i + 10 : U32), ymin)
    case Nil{}:
      a

def M.levels(bs: +List<F32>, as: +List<F32>, hs: +List<F32>) -> +List<U32>:
  match bs as hs:
    case Con{+b, bt} Con{+a, at} Con{+h, ht}:
      M.level(b, a, h) <> M.levels(bt, at, ht)
    case _ _ _:
      []

# the 6400 surface levels of the mapchunk at node origin (x, z), row-major
def M.heights(+ws: U32, +x: F32, +z: F32) -> +List<U32>:
  +pm = Z.N.map2d(Z.NP{0.6, 0.1, 2000.0, 539, 3n, 0.6, 2.0}, ws, 80n, 80n, x, z,
    List.replicate(F32, 6400n, 0.6))
  +hb = Z.N.map2d(Z.NP{4.0, 70.0, 600.0, 82341, 5n, 0.6, 2.0}, ws, 80n, 80n, x, z, pm)
  +ha = Z.N.map2d(Z.NP{4.0, 25.0, 600.0, 5934, 5n, 0.6, 2.0}, ws, 80n, 80n, x, z, pm)
  +hh = Z.N.map2d(Z.NP{(0.0 - 8.0 : F32), 16.0, 500.0, 4213, 6n, 0.7, 2.0}, ws, 80n, 80n,
    x, z, List.replicate(F32, 6400n, 0.7))
  List.reverse(&2, U32, M.levels(hb, ha, hh))

# One 80x80x80 mapchunk at node origin (x, y, z), two's complement.
# blocks: 64000 words used of 65536, word (z*80 + x)*10 + k holds y+8k .. y+8k+7.
type Chunk is Type:
  Chunk{x: U32, y: U32, z: U32, blocks: Array<U32>}

# MapgenV7::generateTerrain for one mapchunk: 4 noise maps, then the blocks
def M.chunk(+ws: U32, +x: U32, +y: U32, +z: U32) -> Chunk:
  Chunk{x, y, z, M.fill(M.heights(ws, I.I32.to_f32(x), I.I32.to_f32(z)),
    [0 : U32^16n], 0, y)}
