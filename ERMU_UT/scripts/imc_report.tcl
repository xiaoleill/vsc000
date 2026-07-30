# IMC Report Script — Generate coverage reports (IMC 23.09 compatible)

set sim_dir [file normalize [file join [file dirname [info script]] .. sim]]
set merged_db [file join $sim_dir merged]
set cov_dir [file join $sim_dir cov_results]

if {![file exists $merged_db]} {
    puts "ERROR: Merged database not found: $merged_db"
    puts "Run 'make cov_merge' first."
    exit 1
}

load $merged_db

# Detailed text report
report -out [file join $cov_dir ermu_coverage_report.txt] -detail
puts "Text:   cov_results/ermu_coverage_report.txt"

# Coverage report — scoped to DUT
report_metrics -detail -out $cov_dir -verification_scope hdl_top.u_dut -metrics all -both
puts "HTML: cov_results/index.html"
