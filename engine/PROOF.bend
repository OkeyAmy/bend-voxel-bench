# PROOF.bend — a proof for every law in LAWS.bend. Gate: `bend engine/PROOF.bend`
# must print "All terms check." Anything left as ?TODO or provably false fails here.
import Base
import ./LAWS.bend as Laws
import ./mapgen.bend as M
import ./i32.bend as I
import ./render/bend3d.bend as R
import ./game.bend as G

def Laws.add_zero(x):
  match x:
    case 0n:
      {==}
    case 1n+p:
      %Laws.add_zero(p) : {1n+Nat.add(p, 0n) == 1n+_ : Nat}
      {==}

def Laws.word_true(a, b):
  {==}

def Laws.pick_true(a, b):
  {==}

def Laws.pack_zero(y, s, acc, sh):
  {==}

def Laws.block_def(y, s):
  {==}

def Laws.block_stone(y, s, e):
  %e : {M.word(_, 1, M.word(I.I32.le(y, 1), 2, 0)) == 1 : U32}
  {==}

def pred_nat(x: Nat) -> Nat:
  match x:
    case 0n:
      0n
    case 1n+p:
      p

def len_peel(p: Nat, q: Nat, e: {1n+p == 1n+q : Nat}) -> {p == q : Nat}:
  Equal.cong(Nat, Nat, pred_nat, 1n+p, 1n+q, e)

def Laws.levels_length(bs, as2, hs, el, er):
  match bs as2 hs:
    case Con{+b, +bt} Con{+a, +at} Con{+h, +ht}:
      %Laws.levels_length(bt, at, ht, len_peel(List.length(&2, F32, bt), List.length(&2, F32, at), el),
        len_peel(List.length(&2, F32, at), List.length(&2, F32, ht), er)) :
        {1n+List.length(&2, U32, M.M.levels(bt, at, ht)) == 1n+_ : Nat}
      {==}
    case Con{+b, +bt} Con{+a, +at} Nil{}:
      %er : {_ == 1n+List.length(&2, F32, bt) : Nat}
      %el : {_ == 1n+List.length(&2, F32, bt) : Nat}
      {==}
    case Con{+b, +bt} Nil{} Con{+h, +ht}:
      %el : {_ == 1n+List.length(&2, F32, bt) : Nat}
      {==}
    case Con{+b, +bt} Nil{} Nil{}:
      %el : {_ == 1n+List.length(&2, F32, bt) : Nat}
      {==}
    case Nil{} Con{+a, +at} Con{+h, +ht}:
      {==}
    case Nil{} Con{+a, +at} Nil{}:
      {==}
    case Nil{} Nil{} Con{+h, +ht}:
      {==}
    case Nil{} Nil{} Nil{}:
      {==}

# G.move takes the state apart, so first split s into its six fields; then
# G.y(G.move(s)) computes to G.floor(G.rawy(s)) = pick(rawy < 2, 2, rawy).
# Rewrite the comparison with the hypothesis, and pick reduces.
def Laws.floor_stops_dive(s, below):
  match s:
    case G.St{x, y, z, yaw, pitch, held}:
      %below : {R.pick(_, 2.0, G.G.rawy(G.St{x, y, z, yaw, pitch, held})) == 2.0 : F32}
      {==}

def Laws.floor_keeps_height(s, above):
  match s:
    case G.St{x, y, z, yaw, pitch, held}:
      %above : {R.pick(_, 2.0, G.G.rawy(G.St{x, y, z, yaw, pitch, held}))
        == G.G.rawy(G.St{x, y, z, yaw, pitch, held}) : F32}
      {==}
