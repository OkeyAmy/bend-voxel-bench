import Base

# Broken-proof fixture: the law is true, the proof is not finished.
law open_law:
  for x: Nat
  {Nat.add(x, 0n) == x : Nat}
