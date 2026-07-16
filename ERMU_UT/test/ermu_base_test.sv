// =============================================================================
//  ERMU Base Test — Builds environment, sets default config
// =============================================================================

class ermu_base_test extends uvm_test;

    `uvm_component_utils(ermu_base_test)

    ermu_env          env;
    ermu_env_cfg      env_cfg;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // ---- Create and configure environment config ----
        env_cfg = ermu_env_cfg::type_id::create("env_cfg");
        env_cfg.apb_cfg.active    = 1'b1;
        env_cfg.apb_cfg.coverage_en = 1'b1;
        env_cfg.input_cfg.active   = 1'b1;
        env_cfg.input_cfg.coverage_en = 1'b0;
        env_cfg.output_cfg.coverage_en = 1'b1;

        // ---- Set configs into config_db ----
        uvm_config_db #(ermu_env_cfg)::set(this, "*", "env_cfg", env_cfg);

        // ---- Build environment ----
        env = ermu_env::type_id::create("env", this);
    endfunction

    function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        `uvm_info("BASE_TEST", "Testbench topology:\n" + this.sprint(), UVM_MEDIUM)
    endfunction

endclass : ermu_base_test
