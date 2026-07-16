// =============================================================================
//  APB Agent Package — Groups all APB agent classes
// =============================================================================

package apb_agent_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    `include "apb_transaction.sv"
    `include "apb_agent_cfg.sv"
    `include "apb_coverage.sv"
    `include "apb_sequencer.sv"
    `include "apb_driver.sv"
    `include "apb_monitor.sv"
    `include "apb_agent.sv"

endpackage : apb_agent_pkg
