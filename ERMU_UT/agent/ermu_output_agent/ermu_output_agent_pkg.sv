// =============================================================================
//  ERMU Output Agent Package — Monitors EOUT/HPI/LPI/RST/PSSR/EMS/status
// =============================================================================

package ermu_output_agent_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    `include "ermu_output_transaction.sv"
    `include "ermu_output_agent_cfg.sv"
    `include "ermu_output_monitor.sv"
    `include "ermu_output_coverage.sv"
    `include "ermu_output_agent.sv"

endpackage : ermu_output_agent_pkg
