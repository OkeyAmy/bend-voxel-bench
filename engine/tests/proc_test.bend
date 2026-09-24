# Runs two commands through Proc.run and prints their exit codes.
#   ./build/proc_test -- <dir>
import Base
import ../sys/proc.bend as P

def dir(xs: List<String>) -> String:
  match xs:
    case Con{h, _}:
      h
    case Nil{}:
      "/tmp"

def main() -> IO(Unit):
  do IO<Unit>:
    xs : List<String> <- IO.args()
    +d : String = dir(xs)
    a : U32 <- P.Proc.run("exit 3")
    IO.print("code " ++ U32.show(a))
    b : U32 <- P.Proc.run("touch " ++ d ++ "/made")
    IO.print("code " ++ U32.show(b))
