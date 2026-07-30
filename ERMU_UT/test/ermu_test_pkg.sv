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
            // Global simulation timeout: 100ms (avoids infinite hang)
            uvm_root::get().set_timeout(100_000_000, 0);
            `uvm_info("BASE_TEST", "Testbench topology built (timeout=100ms)", UVM_MEDIUM)
        endfunction

        // ---- Wait for reset release (initial cold boot) ----
        task wait_reset_release();
            `uvm_info("BASE_TEST", "Waiting for reset release...", UVM_MEDIUM)
            if (clk_rst_vif.rst_h2_s == 1'b1)
                @(negedge clk_rst_vif.rst_h2_s);  // last to deassert (application reset)
            repeat(5) @(posedge clk_rst_vif.pclk);
            `uvm_info("BASE_TEST", "Reset released, DUT ready", UVM_MEDIUM)
        endtask

        // ---- Reset hierarchy (active HIGH):  ----
        //   POR (rst_pvs_s)     → cascades SYS + APP
        //   SYS (rst_pss_h2_s)  → cascades APP
        //   APP (rst_h2_s)      → independent
        //   Release order: pss_h2 first, h2 last
        localparam int RST_HOLD_CYCLES = 10;
        localparam int RST_RELEASE_GAP = 2;   // cycles between pss_h2 and h2 release

        typedef enum bit [1:0] { APP_RST=0, SYS_RST=1, POR_RST=2 } reset_level_t;

        // ---- Pulse a specific reset level (respects cascade hierarchy) ----
        task pulse_reset(reset_level_t level);
            case (level)
                POR_RST: begin
                    `uvm_info("BASE_TEST", "Pulsing POR (rst_pvs_s → cascades SYS+APP)", UVM_MEDIUM)
                    clk_rst_vif.rst_pvs_s    <= 1'b1;
                    clk_rst_vif.rst_pss_h2_s <= 1'b1;
                    clk_rst_vif.rst_h2_s     <= 1'b1;
                    repeat(RST_HOLD_CYCLES) @(posedge clk_rst_vif.pclk);
                    clk_rst_vif.rst_pvs_s    <= 1'b0;
                    clk_rst_vif.rst_pss_h2_s <= 1'b0;
                    repeat(RST_RELEASE_GAP) @(posedge clk_rst_vif.pclk);
                    clk_rst_vif.rst_h2_s     <= 1'b0;
                end
                SYS_RST: begin
                    `uvm_info("BASE_TEST", "Pulsing SYS_RST (rst_pss_h2_s → cascades APP)", UVM_MEDIUM)
                    clk_rst_vif.rst_pss_h2_s <= 1'b1;
                    clk_rst_vif.rst_h2_s     <= 1'b1;
                    repeat(RST_HOLD_CYCLES) @(posedge clk_rst_vif.pclk);
                    clk_rst_vif.rst_pss_h2_s <= 1'b0;
                    repeat(RST_RELEASE_GAP) @(posedge clk_rst_vif.pclk);
                    clk_rst_vif.rst_h2_s     <= 1'b0;
                end
                APP_RST: begin
                    `uvm_info("BASE_TEST", "Pulsing APP_RST (rst_h2_s only)", UVM_MEDIUM)
                    clk_rst_vif.rst_h2_s <= 1'b1;
                    repeat(RST_HOLD_CYCLES) @(posedge clk_rst_vif.pclk);
                    clk_rst_vif.rst_h2_s <= 1'b0;
                end
            endcase
            repeat(5) @(posedge clk_rst_vif.pclk);  // DUT stabilization
            `uvm_info("BASE_TEST", "Reset pulse complete, DUT ready", UVM_MEDIUM)
        endtask

        // ---- Check ESS with reserved-bit mask ----
        //  Reserved source IDs always read 0; mask filters them out.
        //  Pass check_bit=-1 to only verify reserved bits are 0 (no specific bit check).
        task check_ess_masked(int group, int check_bit, uvm_reg_data_t rd_val);
            bit [31:0] mask = env.reg_block.get_ess_mask(group);
            string     gname = $sformatf("ESS%0d", group);
            // Verify reserved bits are 0
            if ((rd_val & ~mask) != 32'h0) begin
                `uvm_error("BASE_TEST", $sformatf(
                    "%s: reserved bits set! rd=0x%08h mask=0x%08h non_zero=0x%08h",
                    gname, rd_val, mask, rd_val & ~mask))
            end
            // Check specific bit if requested
            if (check_bit >= 0) begin
                if (!env.reg_block.is_valid_source(group * 32 + check_bit)) begin
                    `uvm_warning("BASE_TEST", $sformatf(
                        "%s[%0d]: source ID %0d is RESERVED — cannot inject via err_src_id",
                        gname, check_bit, group * 32 + check_bit))
                end else if (rd_val[check_bit] != 1'b1) begin
                    `uvm_error("BASE_TEST", $sformatf(
                        "%s[%0d]: expected 1, got 0 (rd=0x%08h)", gname, check_bit, rd_val))
                end
            end
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
    `include "ermu_cfglock_test.sv"
    `include "ermu_error_src_test.sv"
    `include "ermu_error_rsp_test.sv"
    `include "ermu_error_mask_test.sv"
    `include "ermu_pseudo_err_test.sv"
    `include "ermu_hpi_test.sv"
    `include "ermu_output_chan_test.sv"
    `include "ermu_timer_test.sv"
    `include "ermu_prescaler_test.sv"
    `include "ermu_pssr_test.sv"
    `include "ermu_concurrent_test.sv"
    `include "ermu_reset_test.sv"
    `include "ermu_stress_test.sv"
    `include "ermu_func_full_test.sv"
    `include "ermu_error_rsp_full_test.sv"

endpackage : ermu_test_pkg
