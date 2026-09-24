# Headless world-generation bench: the 5 x 4 x 5 Luanti mapchunks with node
# origins x, z in -32 .. 288 and y in -112 .. 128 (step 80), so the area is
# x, z -32 .. 367 and y -112 .. 207. Generated in parallel as one fork tree of
# 128 leaves (100 used), timed, then dumped.
import Base
import ./i32.bend as I
import ./mapgen.bend as M

type Tree is Type:
  TNil{}
  TLeaf{c: M.Chunk}
  TNode{l: Tree, r: Tree}

# leaf i -> mapchunk cx = i % 5, cz = i / 5 % 5, cy = i / 25, from origin (ox, -112, oz)
def B.leaf(hit: Bool, +ws: U32, +ox: U32, +oz: U32, +i: U32) -> Tree:
  match hit:
    case True{}:
      TLeaf{M.M.chunk(ws, ((80 * (i % 5)) + ox : U32), ((80 * (i / 25)) - 112 : U32),
        ((80 * ((i / 5) % 5)) + oz : U32))}
    case False{}:
      TNil{}

# 2^d leaves from leaf i; leaves at n or past are empty
def B.gen(+d: Nat, +ws: U32, +ox: U32, +oz: U32, +i: U32, +n: U32) -> Tree:
  match d:
    case 0n:
      B.leaf((i < n : U32), ws, ox, oz, i)
    case 1n+p:
      +half = U32.shln(1, p)
      l r = B.gen(p, ws, ox, oz, i, n) B.gen(p, ws, ox, oz, (i + half : U32), n)
      TNode{l, r}

# ---- dump: per column, the stone and water block counts in the mapchunk ----

def D.nib(k: Nat, +w: U32, +st: U32, +wa: U32) -> U32:
  match k:
    case 0n:
      ((st * 256) + wa : U32)
    case 1n+p:
      +b = (w % 16 : U32)
      D.nib(p, (w / 16 : U32), (st + M.word(U32.is_eq(b, 1), 1, 0) : U32),
        (wa + M.word(U32.is_eq(b, 2), 1, 0) : U32))

# words i .. i+k of a column: sum of (stone * 256 + water) per word
def D.col(k: Nat, aw: Array<U32> & U32, +i: U32, +acc: U32) -> Array<U32> & U32:
  match k:
    case 0n:
      (a, w) = aw
      (a, (acc + D.nib(8n, w, 0, 0) : U32))
    case 1n+p:
      (a, w) = aw
      D.col(p, a[(i + 1 : U32)], (i + 1 : U32), (acc + D.nib(8n, w, 0, 0) : U32))

# " stone water" for the column just counted and every column after it.
# Right-nested ++ (short left side), so the cost stays linear.
def D.cols(k: Nat, ac: Array<U32> & U32, +i: U32) -> String:
  match k:
    case 0n:
      (a, +c) = ac
      " " ++ U32.show((c / 256 : U32)) ++ " " ++ U32.show((c % 256 : U32))
    case 1n+p:
      (a, +c) = ac
      " " ++ U32.show((c / 256 : U32)) ++ " " ++ U32.show((c % 256 : U32))
        ++ D.cols(p, D.col(9n, a[(i + 10 : U32)], (i + 10 : U32), 0), (i + 10 : U32))

def D.keep(fw: File & Result<&1, &1, U32 & String, Unit>) -> IO(File):
  (f, r) = fw
  IO.pure(File, f)

# one line per mapchunk: "x y z" (signed) then 6400 " stone water" pairs
def D.write(t: Tree, f: File) -> IO(File):
  match t:
    case TNil{}:
      IO.pure(File, f)
    case TLeaf{M.Chunk{x, y, z, a}}:
      do IO<File>:
        fw : File & Result<&1, &1, U32 & String, Unit> <- File.write(f,
          I.I32.show(x) ++ " " ++ I.I32.show(y) ++ " " ++ I.I32.show(z)
            ++ D.cols(6399n, D.col(9n, a[0], 0, 0), 0) ++ "\n")
        D.keep(fw)
    case TNode{l, r}:
      do IO<File>:
        f2 : File <- D.write(l, f)
        D.write(r, f2)

def B.mapgen(+ws: U32, +ox: U32, +oz: U32, path: String) -> IO(Unit):
  do IO<Unit>:
    +t0 : Nat <- IO.now()
    tree : Tree = B.gen(7n, ws, ox, oz, 0, 100)
    +t1 : Nat <- IO.now()
    IO.print("mapgen_ms " ++ Nat.show(Nat.sub(t1, t0)))
    f : File <- IO.try(File, File.open(path, "w"))
    f2 : File <- D.write(tree, f)
    File.close(f2)

# origin argument n (a mapchunk-aligned x or z), -32 by default
def B.origin(+args: +List<String>, n: Nat) -> U32:
  Maybe.default(&2, U32, I.I32.read(Maybe.default(&2, String, List.get(&2, String, args, n), "-32")), (0 - 32 : U32))

def B.run.seed(s: Maybe<&2, U32>, +ox: U32, +oz: U32, path: String) -> IO(Unit):
  match s:
    case Some{+ws}:
      B.mapgen(ws, ox, oz, path)
    case None{}:
      IO.die(Unit, 2, "seed must be an integer")

def B.run.mode(ok: Bool, +args: +List<String>) -> IO(Unit):
  match ok:
    case True{}:
      B.run.seed(I.I32.read(Maybe.default(&2, String, List.get(&2, String, args, 1n), "")),
        B.origin(args, 3n), B.origin(args, 4n),
        Maybe.default(&2, String, List.get(&2, String, args, 2n), "mapgen_dump.txt"))
    case False{}:
      IO.die(Unit, 2, "usage: voxel [--threads N] -- mapgen <seed> <dump-path> [x0 z0]")

# args: ["mapgen", seed, dump-path]
def B.run(+args: +List<String>) -> IO(Unit):
  B.run.mode(String.eq(Maybe.default(&2, String, List.get(&2, String, args, 0n), ""), "mapgen"),
    args)
