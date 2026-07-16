// =============================================================================
//  ERMU Test Package
// =============================================================================

package ermu_test_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import apb_agent_pkg::*;
    import ermu_reg_pkg::*;
    import ermu_input_agent_pkg::*;
    import ermu_output_agent_pkg::*;
    import ermu_env_pkg::*;
    import ermu_seq_pkg::*;

    // ---- Base test ----
    class ermu_base_test extends uvm_test;

        `uvm_component_utils(ermu_base_test)

        ermu_env                 env;
        ermu_env_cfg             env_cfg;
        virtual ermu_clk_rst_if  clk_rst_vif;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            env_cfg = ermu_env_cfg::type_id::create("env_cfg");
            env_cfg.apb_cfg.active       = 1'b1;
            env_cfg.apb_cfg.coverage_en  = 1'b1;
            env_cfg.input_cfg.active     = 1'b1;
            env_cfg.output_cfg.coverage_en = 1'b1;
            uvm_config_db #(ermu_env_cfg)::set(this, "*", "env_cfg", env_cfg);
            env = ermu_env::type_id::create("env", this);
        endfunction

        function void end_of_elaboration_phase(uvm_phase phase);
            super.end_of_elaboration_phase(phase);
            if (!uvm_config_db #(virtual ermu_clk_rst_if)::get(this, "", "clk_rst_vif", clk_rst_vif))
                `uvm_fatal("BASE_TEST", "clk_rst_vif not found in config_db")
            `uvm_info("BASE_TEST", "Testbench topology built", UVM_MEDIUM)
        endfunction

        // ---- Wait for all resets to be released before any register access ----
        task wait_reset_release();
            `uvm_info("BASE_TEST", "Waiting for reset release...", UVM_MEDIUM)
            // Wait until all 3 reset signals are deasserted (active high → wait for 0)
            @(negedge clk_rst_vif.rst_h2_s);     // last to deassert (application reset)
            // Extra margin: wait a few pclk cycles for DUT to stabilize
            repeat(5) @(posedge clk_rst_vif.pclk);
            `uvm_info("BASE_TEST", "Reset released, DUT ready", UVM_MEDIUM)
        endtask

        task run_phase(uvm_phase phase);
            phase.raise_objection(this);
            wait_reset_release();
            `uvm_info("BASE_TEST", "Base test running", UVM_NONE)
            #100000;
            phase.drop_objection(this);
        endtask

    endclass : ermu_base_test

    // ---- Minimal smoke: just init + read CFGLOCK ----
    class ermu_smoke_test extends ermu_base_test;

        `uvm_component_utils(ermu_smoke_test)

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        task run_phase(uvm_phase phase);
            uvm_status_e    status;
            uvm_reg_data_t  rdata;

            phase.raise_objection(this);
            wait_reset_release();
            `uvm_info("SMOKE", "=== ERMU Smoke Test Start ===", UVM_NONE)

            // Unlock CFGLOCK via reg model (direct APB access, no sequence)
            env.reg_block.CFGLOCK.write(status, 32'h0000_BC00, UVM_FRONTDOOR, env.reg_block.reg_map);
            env.reg_block.CFGLOCK.read(status, rdata, UVM_FRONTDOOR, env.reg_block.reg_map);
            `uvm_info("SMOKE", $sformatf("CFGLOCK = 0x%08h (expect bit0=0)", rdata), UVM_NONE);

            // Clear EOS on channel 0
            env.reg_block.EOyC[0].write(status, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map);
            env.reg_block.EOyS[0].read(status, rdata, UVM_FRONTDOOR, env.reg_block.reg_map);
            `uvm_info("SMOKE", $sformatf("EO0S = 0x%08h", rdata), UVM_NONE);

            // Read ESS0
            env.reg_block.ESS[0].read(status, rdata, UVM_FRONTDOOR, env.reg_block.reg_map);
            `uvm_info("SMOKE", $sformatf("ESS0 = 0x%08h", rdata), UVM_NONE);

            // Read reset values of some registers
            env.reg_block.EGC.read(status, rdata, UVM_FRONTDOOR, env.reg_block.reg_map);
            `uvm_info("SMOKE", $sformatf("EGC = 0x%08h", rdata), UVM_NONE);

            env.reg_block.CCPS.read(status, rdata, UVM_FRONTDOOR, env.reg_block.reg_map);
            `uvm_info("SMOKE", $sformatf("CCPS = 0x%08h", rdata), UVM_NONE);

            `uvm_info("SMOKE", "=== ERMU Smoke Test End ===", UVM_NONE)
            phase.drop_objection(this);
        endtask

    endclass : ermu_smoke_test

    `include "ermu_reg_test.sv"
    `include "ermu_error_src_test.sv"
    `include "ermu_timer_test.sv"

endpackage : ermu_test_pkg
