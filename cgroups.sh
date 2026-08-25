sudo bash -s <<'EOF'
cd /home/llm/sh2loop
perl harness/WorkerPool.pm --status          # primes sh2gates + sh2workers with their limits

# supervisor loops (pid files) — entering the supervisor covers its whole
# tree, including workers it (re)spawns later
for p in $(cat loop-estree.pid 2>/dev/null) \
         $(cat sh2perl/backends/sh/loop-backend-sh.pid 2>/dev/null) \
         $(cat sh2perl/backends/perl/loop-backend-perl.pid 2>/dev/null) \
         $(cat sh2perl/backends/c/loop-backend-c.pid 2>/dev/null) \
         $(cat loop-frontend-zsh-sh-go.pid 2>/dev/null) \
         $(cat loop-frontend-fish-sh-go.pid 2>/dev/null) \
         $(pgrep -f '^bash .*/run_triage_worker.sh$' || true) \
         $(pgrep -f '^bash .*/setup_backends.sh --run-backend-worker (sh|perl|c)$' || true) \
         $(pgrep -f '^bash .*/frontends/(zsh|fish)-sh-go/run_frontend_worker.sh$' || true); do
  [ -n "$p" ] || continue
  perl harness/WorkerPool.pm --enter-worker "$p"
done

perl harness/WorkerPool.pm --status          # verify: cgroup=v1(gates=… workers=…)
EOF
