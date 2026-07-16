// =============================================================================
//  ERMU Output Agent — Passive monitoring of DUT outputs
// =============================================================================

class ermu_output_agent extends uvm_agent;

    `uvm_component_utils(ermu_output_agent)

    ermu_output_agent_cfg       cfg;
    ermu_output_monitor         monitor;
    ermu_output_coverage        coverage;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(ermu_output_agent_cfg)::get(this, "", "output_cfg", cfg))
            `uvm_fatal("OUTPUT_AGT", "Output agent config not found")
        monitor = ermu_output_monitor::type_id::create("monitor", this);
        if (cfg.coverage_en) begin
            coverage = ermu_output_coverage::type_id::create("coverage", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        if (cfg.coverage_en) begin
            monitor.output_analysis_port.connect(coverage.analysis_export);
        end
    endfunction

endclass : ermu_output_agent
