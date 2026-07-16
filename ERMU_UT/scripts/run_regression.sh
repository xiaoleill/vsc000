#!/bin/bash
# =============================================================================
#  ERMU UVM Regression Runner
#  Runs all tests with multiple seeds, collects IMC coverage
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJ_DIR="$(dirname "$SCRIPT_DIR")"

TESTS=(
    "ermu_smoke_test"
    "ermu_reg_test"
    "ermu_cfglock_test"
    "ermu_error_src_test"
    "ermu_error_rsp_test"
    "ermu_error_mask_test"
    "ermu_pseudo_err_test"
    "ermu_hpi_test"
    "ermu_output_chan_test"
    "ermu_timer_test"
    "ermu_prescaler_test"
    "ermu_pssr_test"
    "ermu_concurrent_test"
    "ermu_reset_test"
    "ermu_stress_test"
    "ermu_func_full_test"
)

SEEDS=(1 42 123 999 2048)

cd "$PROJ_DIR"
mkdir -p log cov_results

for test in "${TESTS[@]}"; do
    for seed in "${SEEDS[@]}"; do
        echo "Running: $test seed=$seed"
        xrun \
            -f scripts/compile_ermu.f \
            -uvmhome CDNS-1.2 -uvm \
            +UVM_TESTNAME="$test" \
            +UVM_VERBOSITY=UVM_LOW \
            -seed "$seed" \
            -coverage all -covoverwrite \
            -covtest "${test}_s${seed}" \
            -covfile cov/cov_config.tcl \
            -covdir "cov_results/${test}_s${seed}" \
            -top hdl_top \
            -log "log/${test}_s${seed}.log" \
            -timescale 1ns/10ps \
            -xmlibdirname "xcelium.d/${test}_s${seed}" \
            > "log/${test}_s${seed}.stdout" 2>&1 &

        # Limit concurrent jobs (adjust as needed)
        while [ $(jobs -r | wc -l) -ge 4 ]; do
            sleep 5
        done
    done
done

wait
echo "============================================="
echo " Regression complete!"
echo "============================================="
echo " Merging coverage..."
imc -batch -exec scripts/imc_merge.tcl
imc -batch -exec scripts/imc_report.tcl
echo " Coverage reports generated in cov_results/"
