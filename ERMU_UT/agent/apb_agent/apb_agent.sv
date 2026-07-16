// =============================================================================
//  APB Agent — Encapsulates APB driver, monitor, sequencer, and coverage
// =============================================================================

class apb_agent extends uvm_agent;

    `uvm_component_utils(apb_agent)

    apb_agent_cfg                       cfg;
    apb_sequencer                       sequencer;
    apb_driver                          driver;
    apb_monitor                         monitor;
    apb_coverage                        coverage;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db #(apb_agent_cfg)::get(this, "", "apb_cfg", cfg))
            `uvm_fatal("APB_AGENT", "APB agent config not found in config_db")

        // Monitor is always built
        monitor = apb_monitor::type_id::create("monitor", this);

        // Driver and sequencer only when active
        if (cfg.active) begin
            sequencer = apb_sequencer::type_id::create("sequencer", this);
            driver    = apb_driver::type_id::create("driver", this);
        end

        // Coverage collector
        if (cfg.coverage_en) begin
            coverage = apb_coverage::type_id::create("coverage", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // Monitor analysis port → coverage
        if (cfg.coverage_en) begin
            monitor.apb_analysis_port.connect(coverage.analysis_export);
        end

        // Driver ← sequencer
        if (cfg.active) begin
            driver.seq_item_port.connect(sequencer.seq_item_export);
        end
    endfunction

endclass : apb_agent
