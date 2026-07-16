# =============================================================================
#  IMC Report Script — Generate line/toggle/condition coverage reports
#  Run from: ERMU_UT/sim/
#  Usage: imc -batch -exec ../scripts/imc_report.tcl
# =============================================================================

set cov_db "cov_results/merged_cov"

# Check if merged database exists
if {[file exists $cov_db]} {
    load $cov_db
} else {
    puts "ERROR: Merged coverage database not found: $cov_db"
    puts "Run 'make cov_merge' first."
    exit 1
}

# ---- Text report with detail ----
report -out cov_results/ermu_coverage_report.txt -detail
puts "Text report: cov_results/ermu_coverage_report.txt"

# ---- HTML report ----
report -type html -out cov_results/ermu_coverage_report.html
puts "HTML report: cov_results/ermu_coverage_report.html"

# ---- Metrics summary ----
report -type metrics -out cov_results/ermu_metrics.txt \
    -metrics line -metrics toggle -metrics condition
puts "Metrics:     cov_results/ermu_metrics.txt"

# ---- Grade against goals ----
puts ""
puts "=========================================="
puts " Grading against goals:"
puts "   Line      >= 95%"
puts "   Toggle    >= 90%"
puts "   Condition >= 95%"
puts "=========================================="
grade -line 95 -toggle 90 -condition 95

puts ""
puts "IMC reports generated in cov_results/"
