// =============================================================================
//  ERMU Output Agent Configuration
// =============================================================================

class ermu_output_agent_cfg extends uvm_object;

    `uvm_object_utils(ermu_output_agent_cfg)

    bit         coverage_en;

    function new(string name = "ermu_output_agent_cfg");
        super.new(name);
        coverage_en = 1'b1;
    endfunction

endclass : ermu_output_agent_cfg
