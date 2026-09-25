# Walkthrough: adding walls, law first

How a rule got into the game: "you can't walk through a wall". Each stage below
shows what changed, what the gate printed, and what that means.

The gate is one command. The game build runs it first (`harness/build.ts`), so a
failing gate means no game gets built:

```
bend engine/PROOF.bend        # always capped: systemd-run ... MemoryMax=4G ... timeout 300
```

Three files take part:

| File | What it holds | Runs while you play? |
|---|---|---|
| `engine/game.bend` | the code: what happens each frame | yes |
| `engine/LAWS.bend` | the rules: what must always be true of the code | no |
| `engine/PROOF.bend` | one proof per rule, showing the code obeys it | no |

A wall here is a terrain column more than one block above the camera. One block
higher is a step you walk up. Two or more is a wall: x and z stay where they were,
and you fly up with E to get over it.

---

## Stage A: write the laws, nothing else

Four laws went into `LAWS.bend`:

```
law wall_stops_x:
  for s: G.St                      # any camera state
  for w: List<&2, W.Mc>            # any world
  for hit: {True{} == F32.is_lt((G.G.y(s) + 1.0 : F32), G.G.ground(w, G.G.rawx(s), G.G.rawz(s))) : Bool}
                                   # "the column the keys lead to is more than 1 above me"
  {G.G.x(G.G.step(s, w)) == G.G.x(s) : F32}
                                   # "then after one frame, x is unchanged"
```

`wall_stops_z` says the same for z. `open_moves_x`/`open_moves_z` say the opposite
case: no wall means the keys do move you. Without those two, a lazy fix like
"never move at all" would satisfy the wall laws.

Gate:

```
Error: 4 TODOs found.
The code is incomplete, and not a valid proof yet.
```

**Meaning:** a law without a proof is an unpaid bill. The build is blocked, and
the game you'd play is still the old one. **A law alone changes nothing in the
game.**

## Stage B: write the proofs, keep the old code

A proof takes the state apart into its six fields (`match s`), lets the checker
compute what `G.step` does, and uses the hypothesis `hit` to settle the wall test:

```
def Laws.wall_stops_x(s, w, hit):
  match s:
    case G.St{x, y, z, yaw, pitch, held}:
      %hit : {R.pick(_, x, G.G.rawx(G.St{x, y, z, yaw, pitch, held})) == x : F32}
      {==}
```

Gate:

```
Error:
- expected : {F32.add(x, F32.mul(0.6, ...          <- what the proof claims
- observed : {render/bend3d.pick(F32.is_lt(...     <- what the code computes to
Location: LAWS.wall_stops_x
```

**Meaning:** the checker ran the old `G.step` symbolically, for every possible
state and world. It found that x becomes `x + 0.6 * ...`: you move, wall or not.
The law is false for this code, so no proof exists. Nothing is tested on
examples; it's computed for all inputs at once.

## Stage C: change the code

In `game.bend`:

```
# a wall: the column the keys lead to is more than one block above the camera
def G.wall(+s: St, +w: +List<W.Mc>) -> Bool:
  (G.y(s) + 1.0 < G.ground(w, G.rawx(s), G.rawz(s)) : F32)

# where the camera ends up: where the keys lead, or where it was at a wall
def G.nx(+s: St, +w: +List<W.Mc>) -> F32:
  R.pick(G.wall(s, w), G.x(s), G.rawx(s))
def G.nz(...)   # the same for z

def G.step(+s: St, +w: +List<W.Mc>) -> St:
  +nx = G.nx(s, w)
  +nz = G.nz(s, w)
  G.move(s, nx, nz, G.ground(w, nx, nz))
```

Gate:

```
Location: LAWS.ground_stops_fall
```

**Meaning:** the new code broke an **older** law. `ground_stops_fall` said "you
stop on the ground under where the keys lead". At a wall you don't go there any
more; you stand on the ground under where you end up. The checker noticed the old
rule no longer describes the game. That's the gate doing its job: a new feature
can't silently change an old promise.

## Stage D: restate the old law

A person decides what the rule should now say. The ground that counts is the
column under where the camera ends up:

```
law ground_stops_fall:
  for s: G.St
  for w: List<&2, W.Mc>
  for below: {True{} == F32.is_lt(G.G.rawy(s), G.G.ground(w, G.G.x(G.G.step(s, w)), G.G.z(G.G.step(s, w)))) : Bool}
  {G.G.y(G.G.step(s, w)) == G.G.ground(w, G.G.x(G.G.step(s, w)), G.G.z(G.G.step(s, w))) : F32}
```

Gate:

```
All terms check.
```

**Meaning:** all 13 laws are proven for the new code, and the build goes through.

## Stage E: an AI "fixes" it wrong later

Someone asks an AI to "let me move freely, walls are annoying", and it makes the
smallest change:

```
- R.pick(G.wall(s, w), G.x(s), G.rawx(s))
+ G.rawx(s)
```

Gate:

```
Error:
Location: LAWS.wall_stops_x
```

**Meaning:** the change can't be built. The error names the rule it breaks.
`tests/laws.test.ts` keeps this case, and the noclip case for the ground, as
permanent tests.

---

## What to take away

1. **Laws first, then code.** The failing gate is your to-do list, like a failing
   test. But a test checks a few examples; a law is checked for every input.
2. **Laws never run.** They're checked at build time and then erased. The game is
   the same speed with or without them.
3. **A new feature can break an old law.** Stage C shows that the checker makes
   you restate the old promise on purpose instead of drifting.
4. **Write the "does move" law too.** Without `open_moves_x`, "never move" would pass.
5. **Limits:** the laws are about the rule, not the numbers. Floats (F32) can't be
   reasoned about beyond rewriting, so "0.6 blocks per frame" is not proven, only
   the choice between staying and moving.
