// =============================================================================
//  ERMU Input Agent — Error source injection agent
// =============================================================================

class ermu_input_agent extends uvm_agent;

    `uvm_component_utils(ermu_input_agent)

    ermu_input_agent_cfg        cfg;
    ermu_input_sequencer        sequencer;
    ermu_input_driver           driver;
    ermu_input_monitor          monitor;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(ermu_input_agent_cfg)::get(this, "", "input_cfg", cfg))
            `uvm_fatal("INPUT_AGT", "Input agent config not found")
        monitor = ermu_input_monitor::type_id::create("monitor", this);
        if (cfg.active) begin
            sequencer = ermu_input_sequencer::type_id::create("sequencer", this);
            driver    = ermu_input_driver::type_id::create("driver", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        if (cfg.active) begin
            driver.seq_item_port.connect(sequencer.seq_item_export);
        end
    endfunction

endclass : ermu_input_agent
