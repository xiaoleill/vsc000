// =============================================================================
//  ERMU Input Agent Package — Drives err_src_id[283:0] into DUT
// =============================================================================

package ermu_input_agent_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // ---- Forward declarations ----
    typedef class ermu_input_transaction;
    typedef class ermu_input_agent_cfg;
    typedef class ermu_input_sequencer;
    typedef class ermu_input_driver;
    typedef class ermu_input_monitor;
    typedef class ermu_input_agent;

    `include "ermu_input_transaction.sv"
    `include "ermu_input_agent_cfg.sv"
    `include "ermu_input_sequencer.sv"
    `include "ermu_input_driver.sv"
    `include "ermu_input_monitor.sv"
    `include "ermu_input_agent.sv"

endpackage : ermu_input_agent_pkg
