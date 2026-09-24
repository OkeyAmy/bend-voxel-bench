# Running another program. Bend's Base has no process effect (IO.spawn starts a
# Bend task, not an OS process), so this is a custom effect: `bend guide effects`.
import Base

# Run `cmd` with /bin/sh on a helper thread (the event loop keeps running) and
# answer its exit status: 0..255, or 255 when it could not start or was killed.
def Proc.run(cmd: String) -> IO(U32):
  import "./proc.c"
  import "./proc.js"
