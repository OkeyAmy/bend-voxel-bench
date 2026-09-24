# Signed 32-bit helpers. Bend has no signed integers: an i32 is a U32 holding
# its two's complement bits, as C does.
import Base

def I32.to_f32.go(neg: Bool, +x: U32) -> F32:
  match neg:
    case True{}:
      (0.0 - U32.to_f32((0 - x : U32)) : F32)
    case False{}:
      U32.to_f32(x)

# (float)x
def I32.to_f32(+x: U32) -> F32:
  I32.to_f32.go((x >= 2147483648 : U32), x)

def I32.floor.go(neg: Bool, +f: F32) -> U32:
  match neg:
    case True{}:
      (0 - F32.to_u32((0.0 - f : F32)) : U32)
    case False{}:
      F32.to_u32(f)

# (s32)std::floor(x)
def I32.floor(+x: F32) -> U32:
  +f = F32.floor(x)
  I32.floor.go((f < 0.0 : F32), f)

# (s32)x for a C float->int conversion (truncates toward zero)
def I32.trunc(+x: F32) -> U32:
  I32.floor(F32.trunc(x))

# a <= b as signed
def I32.le(+a: U32, +b: U32) -> Bool:
  ((a .^. 2147483648) <= (b .^. 2147483648) : U32)

def I32.show.go(neg: Bool, +x: U32) -> String:
  match neg:
    case True{}:
      "-" ++ U32.show((0 - x : U32))
    case False{}:
      U32.show(x)

def I32.show(+x: U32) -> String:
  I32.show.go((x >= 2147483648 : U32), x)

def I32.read.go(neg: Bool, s: String) -> Maybe<&2, U32>:
  match neg:
    case True{}:
      Maybe.map(&2, U32, U32, +x => (0 - x : U32), U32.read(String.drop(s, 1n)))
    case False{}:
      U32.read(s)

# "-12" -> Some(two's complement), "12" -> Some(12), junk -> None
def I32.read(+s: String) -> Maybe<&2, U32>:
  I32.read.go(String.starts_with(s, "-"), s)
