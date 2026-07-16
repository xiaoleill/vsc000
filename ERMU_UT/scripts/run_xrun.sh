#!/bin/bash
# =============================================================================
#  ERMU UVM Single Test Runner
#  Usage: ./scripts/run_xrun.sh <test_name> [seed]
# =============================================================================

TEST_NAME=${1:-"ermu_smoke_test"}
SEED=${2:-"random"}
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJ_DIR="$(dirname "$SCRIPT_DIR")"

echo "============================================="
echo " ERMU UVM Simulation"
echo " Test : $TEST_NAME"
echo " Seed : $SEED"
echo "============================================="

cd "$PROJ_DIR"

xrun \
    -f scripts/compile_ermu.f \
    -uvmhome CDNS-1.2 \
    -uvm \
    +UVM_TESTNAME="$TEST_NAME" \
    +UVM_VERBOSITY=UVM_MEDIUM \
    -seed "$SEED" \
    -coverage all \
    -covoverwrite \
    -covtest "$TEST_NAME" \
    -covfile cov/cov_config.tcl \
    -covdir "cov_results/${TEST_NAME}" \
    -top hdl_top \
    -log "log/${TEST_NAME}.log" \
    -linedebug \
    -access +rwc \
    -timescale 1ns/10ps

echo "Simulation complete. Log: log/${TEST_NAME}.log"
