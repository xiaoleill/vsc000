# IMC Merge Script — Merges all coverage databases from regression
# Works regardless of IMC's working directory

set sim_dir [file normalize [file join [file dirname [info script]] .. sim]]
set cov_dir [file join $sim_dir cov_results]
set db_list [list]

foreach dir [glob -nocomplain [file join $cov_dir * scope *]] {
    if {[file isdirectory $dir]} {
        lappend db_list $dir
    }
}

if {[llength $db_list] > 0} {
    puts "Merging [llength $db_list] databases from $cov_dir ..."
    set out_dir [file join $sim_dir merged]
    file mkdir $out_dir
    eval merge $db_list -out $out_dir -overwrite
    puts "Merge complete: $out_dir"
} else {
    puts "ERROR: No scope/ directories found under $cov_dir/"
}
