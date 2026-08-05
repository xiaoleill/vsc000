# =============================================================================
#  FSDB Waveform Dump Script (xrun + Verdi PLI)
#  Usage: make wave_fsdb TEST=ermu_reg_test
# =============================================================================
#  Key points:
#   - xrun TCL mode requires 'call' prefix for Verdi system tasks
#   - $fsdbDumpvars(depth, scope) → call fsdbDumpvars depth scope
#   - debpli.so must be on LD_LIBRARY_PATH, loaded via -loadpli1
# =============================================================================

call fsdbDumpfile "waves/ermu.fsdb"
call fsdbDumpvars 0 hdl_top +all +mda

# Run simulation
run

puts "FSDB saved: waves/ermu.fsdb"
