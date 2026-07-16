# =============================================================================
#  ERMU UVM Verification — Compilation File List
#  Usage: xrun -f scripts/compile_ermu.f -top hdl_top -uvm ...
# =============================================================================

# ---- UVM 1.2 Library ----
-uvmhome CDNS-1.2
-uvm

# ---- Global include directories ----
+incdir+../if
+incdir+../env
+incdir+../agent/apb_agent
+incdir+../agent/ermu_input_agent
+incdir+../agent/ermu_output_agent
+incdir+../reg
+incdir+../seq
+incdir+../test
+incdir+../cov

# ---- DUT RTL ----
../ermu.v

# ---- Interfaces (order matters: no dependencies between them) ----
../if/ermu_clk_rst_if.sv
../if/ermu_apb_if.sv
../if/ermu_error_in_if.sv
../if/ermu_error_out_if.sv

# ---- APB Agent Package ----
../agent/apb_agent/apb_agent_pkg.sv

# ---- Register Model Package ----
../reg/ermu_reg_pkg.sv

# ---- ERMU Input Agent Package ----
../agent/ermu_input_agent/ermu_input_agent_pkg.sv

# ---- ERMU Output Agent Package ----
../agent/ermu_output_agent/ermu_output_agent_pkg.sv

# ---- Environment Package ----
../env/ermu_env_pkg.sv

# ---- Sequence Package ----
../seq/ermu_seq_pkg.sv

# ---- Test Package ----
../test/ermu_test_pkg.sv

# ---- Top-level testbench module ----
../tb/hdl_top.sv

# ---- Coverage files ----
../cov/ermu_cov_groups.sv
../cov/ermu_cross_cov.sv

# ---- Compilation options ----
-timescale 1ns/10ps
-access +rwc
-assert
-linedebug
