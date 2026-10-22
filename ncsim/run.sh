#!/bin/bash
# usage:  ./run.sh <N> [sva] [cov] [waves]      e.g.  ./run.sh 4      ./run.sh 4 sva cov waves
N=${1:-4}; shift
for f in pe.sv systolic_matmul.sv matrix_if.sv matrix_pkg.sv top_tb.sv vectors_N$N.svh; do
  [ -f "$f" ] || { echo "MISSING FILE: $f  (all files must be in this folder: $(pwd))"; exit 1; }
done
cp vectors_N$N.svh vectors.svh
EXTRA=""; FILES="pe.sv systolic_matmul.sv matrix_if.sv matrix_pkg.sv top_tb.sv"
for o in "$@"; do
  case $o in
    sva)   [ -f matmul_sva.sv ] && FILES="$FILES matmul_sva.sv" ;;
    cov)   EXTRA="$EXTRA -coverage all -covoverwrite" ;;
    waves) EXTRA="$EXTRA +define+WAVES" ;;
  esac
done
rm -rf INCA_libs waves.shm
irun -uvm -sv -access +rwc -top top_tb +define+N_SIZE=$N +incdir+. $EXTRA $FILES \
     +UVM_TESTNAME=matrix_full_test -log run_N$N.log
echo "=== key lines from run_N$N.log ==="
grep -E "TOTAL RESULT|SCOREBOARD|FUNCTIONAL COVERAGE|UVM_ERROR :|UVM_FATAL :|ASSERT|WATCHDOG|\*E|\*F" run_N$N.log
