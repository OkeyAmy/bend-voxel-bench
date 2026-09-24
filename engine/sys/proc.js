// Proc.run for the JS target: the same command through /bin/sh, blocking.
function proc_run(cmd) {
  const r = require("node:child_process").spawnSync("/bin/sh", ["-c", cmd], { stdio: "inherit" });
  return (r.status === null ? 255 : r.status) >>> 0;
}
