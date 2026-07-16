// =============================================================================
//  ERMU UVM Environment — Top-level container
//  Instantiates: APB agent, input agent, output agent, register model,
//                 scoreboard, coverage, virtual sequencer
// =============================================================================

class ermu_env extends uvm_env;

    `uvm_component_utils(ermu_env)

    ermu_env_cfg                    cfg;

    // ---- Agents ----
    apb_agent                       apb_agt;
    ermu_input_agent                input_agt;
    ermu_output_agent               output_agt;

    // ---- Register Model ----
    ermu_reg_block                  reg_block;
    ermu_reg2apb_adapter            reg2apb;
    uvm_reg_predictor #(apb_transaction)  reg_predictor;

    // ---- Scoreboard & Coverage ----
    ermu_scoreboard                 scoreboard;
    ermu_coverage                   coverage;

    // ---- Virtual Sequencer ----
    ermu_virtual_sequencer          virt_sqr;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // ---- Get configuration ----
        if (!uvm_config_db #(ermu_env_cfg)::get(this, "", "env_cfg", cfg))
            `uvm_fatal("ENV", "Environment config not found in config_db")

        // ---- Set sub-configs into config_db for agents (use "*" so driver/monitor find them) ----
        uvm_config_db #(apb_agent_cfg)::set(this, "*", "apb_cfg", cfg.apb_cfg);
        uvm_config_db #(ermu_input_agent_cfg)::set(this, "*", "input_cfg", cfg.input_cfg);
        uvm_config_db #(ermu_output_agent_cfg)::set(this, "*", "output_cfg", cfg.output_cfg);

        // ---- Build agents ----
        apb_agt    = apb_agent::type_id::create("apb_agt", this);
        input_agt  = ermu_input_agent::type_id::create("input_agt", this);
        output_agt = ermu_output_agent::type_id::create("output_agt", this);

        // ---- Build register model ----
        reg_block  = ermu_reg_block::type_id::create("reg_block");
        reg_block.build();
        reg2apb    = ermu_reg2apb_adapter::type_id::create("reg2apb");
        reg_predictor = uvm_reg_predictor #(apb_transaction)::type_id::create("reg_predictor", this);

        // Store reg_block in config_db for sequences
        uvm_config_db #(ermu_reg_block)::set(this, "*", "reg_block", reg_block);

        // ---- Build scoreboard ----
        if (cfg.has_scoreboard) begin
            scoreboard = ermu_scoreboard::type_id::create("scoreboard", this);
        end

        // ---- Build coverage ----
        if (cfg.has_coverage) begin
            coverage = ermu_coverage::type_id::create("coverage", this);
        end

        // ---- Build virtual sequencer ----
        if (cfg.has_virtual_sequencer) begin
            virt_sqr = ermu_virtual_sequencer::type_id::create("virt_sqr", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // ---- Connect register model to APB agent ----
        reg_block.reg_map.set_sequencer(apb_agt.sequencer, reg2apb);
        reg_block.reg_map.set_auto_predict(1);  // Enable auto-prediction

        // ---- Connect APB monitor to register predictor ----
        apb_agt.monitor.apb_analysis_port.connect(reg_predictor.bus_in);
        reg_predictor.map    = reg_block.reg_map;
        reg_predictor.adapter = reg2apb;

        // ---- Connect analysis ports to scoreboard ----
        if (cfg.has_scoreboard) begin
            apb_agt.monitor.apb_analysis_port.connect(scoreboard.apb_export);
            input_agt.monitor.input_analysis_port.connect(scoreboard.input_export);
            output_agt.monitor.output_analysis_port.connect(scoreboard.output_export);
        end

        // ---- Connect virtual sequencer handles ----
        if (cfg.has_virtual_sequencer) begin
            virt_sqr.apb_sqr    = apb_agt.sequencer;
            virt_sqr.input_sqr  = input_agt.sequencer;
        end
    endfunction

endclass : ermu_env
