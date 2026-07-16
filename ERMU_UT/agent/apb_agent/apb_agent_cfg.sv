// =============================================================================
//  APB Agent Configuration
// =============================================================================

class apb_agent_cfg extends uvm_object;

    `uvm_object_utils(apb_agent_cfg)

    bit         active;           // 1=active (driver+monitor), 0=passive (monitor only)
    bit         coverage_en;      // Enable APB protocol coverage
    string      agent_id;         // Agent identifier for config_db path

    function new(string name = "apb_agent_cfg");
        super.new(name);
        active      = 1'b1;       // Default: active
        coverage_en = 1'b1;
        agent_id    = "apb_agent";
    endfunction

endclass : apb_agent_cfg
