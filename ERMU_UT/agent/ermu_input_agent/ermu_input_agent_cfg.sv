// =============================================================================
//  ERMU Input Agent Configuration
// =============================================================================

class ermu_input_agent_cfg extends uvm_object;

    `uvm_object_utils(ermu_input_agent_cfg)

    bit         active;
    bit         coverage_en;

    function new(string name = "ermu_input_agent_cfg");
        super.new(name);
        active      = 1'b1;
        coverage_en = 1'b0;
    endfunction

endclass : ermu_input_agent_cfg
