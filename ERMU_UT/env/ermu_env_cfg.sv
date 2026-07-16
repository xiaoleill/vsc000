// =============================================================================
//  ERMU Environment Configuration
// =============================================================================

class ermu_env_cfg extends uvm_object;

    `uvm_object_utils(ermu_env_cfg)

    // ---- Sub-configurations ----
    apb_agent_cfg                  apb_cfg;
    ermu_input_agent_cfg           input_cfg;
    ermu_output_agent_cfg          output_cfg;

    // ---- Environment switches ----
    bit         has_scoreboard;
    bit         has_coverage;
    bit         has_virtual_sequencer;

    // ---- Register model handle ----
    ermu_reg_block                 reg_block;

    function new(string name = "ermu_env_cfg");
        super.new(name);
        apb_cfg    = apb_agent_cfg::type_id::create("apb_cfg");
        input_cfg  = ermu_input_agent_cfg::type_id::create("input_cfg");
        output_cfg = ermu_output_agent_cfg::type_id::create("output_cfg");
        has_scoreboard          = 1'b1;
        has_coverage            = 1'b1;
        has_virtual_sequencer   = 1'b1;
    endfunction

endclass : ermu_env_cfg
