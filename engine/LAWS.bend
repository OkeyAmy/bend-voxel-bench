# LAWS.bend — equational claims about the engine, checked by PROOF.bend.
# Gate: `bend engine/PROOF.bend` must print "All terms check."; the game build runs it too.
# Every law below is proven by `def Laws.<name>` in PROOF.bend.

import Base
import ./mapgen.bend as M
import ./i32.bend as I
import ./render/bend3d.bend as R
import ./game.bend as G
import ./world/world.bend as W

# Convention example from the Bend guide.
law add_zero:
  for x: Nat
  {Nat.add(x, 0n) == x : Nat}

# --- L1: selectors and the pack base case (engine/mapgen.bend) ---

law word_true:
  for a: U32
  for b: U32
  {M.word(True{}, a, b) == a : U32}

law pick_true:
  for a: F32
  for b: F32
  {M.pick(True{}, a, b) == a : F32}

law pack_zero:
  for y: U32
  for s: U32
  for acc: U32
  for sh: U32
  {M.M.pack(0n, y, s, acc, sh) == acc : U32}

# --- L2: the block encoding, stone rule (M.block in engine/mapgen.bend) ---

law block_def:
  for y: U32
  for s: U32
  {M.M.block(y, s) == M.word(I.I32.le(y, s), 1, M.word(I.I32.le(y, 1), 2, 0)) : U32}

law block_stone:
  for y: U32
  for s: U32
  for e: {True{} == I.I32.le(y, s) : Bool}
  {M.M.block(y, s) == 1 : U32}

# --- L3: levels keeps its length when the three lists agree (M.levels) ---

law levels_length:
  for bs: List<&2, F32>
  for as2: List<&2, F32>
  for hs: List<&2, F32>
  for el: {List.length(&2, F32, bs) == List.length(&2, F32, as2) : Nat}
  for er: {List.length(&2, F32, as2) == List.length(&2, F32, hs) : Nat}
  {List.length(&2, U32, M.M.levels(bs, as2, hs)) == List.length(&2, F32, bs) : Nat}

# --- L4: the camera never goes below the ground under it ---
# G.step(s, w) is one frame of movement in the world w. G.ground(w, x, z) is the
# top of the terrain column at (x, z) plus eye height (sea level when that
# mapchunk isn't loaded). G.rawx/rawy/rawz are where the keys would take the
# camera before the ground is checked. So: fly into a hill and you stop on it;
# anywhere above the ground, your height is untouched.

law ground_stops_fall:
  for s: G.St
  for w: List<&2, W.Mc>
  for below: {True{} == F32.is_lt(G.G.rawy(s), G.G.ground(w, G.G.rawx(s), G.G.rawz(s))) : Bool}
  {G.G.y(G.G.step(s, w)) == G.G.ground(w, G.G.rawx(s), G.G.rawz(s)) : F32}

law ground_keeps_height:
  for s: G.St
  for w: List<&2, W.Mc>
  for above: {False{} == F32.is_lt(G.G.rawy(s), G.G.ground(w, G.G.rawx(s), G.G.rawz(s))) : Bool}
  {G.G.y(G.G.step(s, w)) == G.G.rawy(s) : F32}
