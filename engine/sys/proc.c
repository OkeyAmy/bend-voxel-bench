// Proc.run: system(cmd) on a helper thread through io_work (see bend guide effects).
#include <stdlib.h>
#include <sys/wait.h>

static void proc_run_call(IoWork* w) {
  int rc = system((const char*)w->data);
  w->word = (rc != -1 && WIFEXITED(rc)) ? (u32)WEXITSTATUS(rc) : 255;
}

static Term proc_run_pack(Env e, IoWork* w) {
  free(w->data);
  return (Term)(u32)w->word;
}

Term proc_run_run(Env e, Term* f, IoWork* w) {
  w->data = io_cstr(e, f[0], &w->size);
  return io_work(w, proc_run_call, proc_run_pack);
}

static void __attribute__((constructor)) proc_run_use(void) {
  io_eff(CID_PROC_RUN, proc_run_run, 0);
}
