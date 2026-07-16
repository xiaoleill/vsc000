# =============================================================================
#  Waveform Dump Script for Debug
#  Run from: ERMU_UT/sim/
#  Usage: include via xrun -input ../scripts/dump_waves.tcl
#  or:    make wave TEST=<test_name>
# =============================================================================

# Create SHM database (SimVision format)
database -open waves/ermu_waves -shm -default

# Probe all signals in the design
probe -create -all -depth all hdl_top

# Run simulation
run

# Close database
database -close

puts "Waveform saved to: waves/ermu_waves"
puts "Open with: simvision waves/ermu_waves &"
