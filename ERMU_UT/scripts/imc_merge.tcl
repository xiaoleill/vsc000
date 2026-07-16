# =============================================================================
#  IMC Merge Script — Merges all coverage databases from regression
#  Run from: ERMU_UT/sim/
#  Usage: imc -batch -exec ../scripts/imc_merge.tcl
# =============================================================================

# Merge all per-test coverage databases under cov_results/
# Each test creates: cov_results/<test>/cov_work/scope
if {[glob -nocomplain cov_results/*/cov_work/scope] ne ""} {
    merge cov_results/*/cov_work/scope -out cov_results/merged_cov -overwrite
    puts "IMC merge complete: cov_results/merged_cov"
} else {
    # Try older merged location
    if {[glob -nocomplain cov_results/merged_cov] ne ""} {
        puts "Using existing merged coverage: cov_results/merged_cov"
    } else {
        puts "WARNING: No coverage databases found to merge."
        puts "Run 'make cov_test TEST=<name>' first to generate coverage data."
    }
}
