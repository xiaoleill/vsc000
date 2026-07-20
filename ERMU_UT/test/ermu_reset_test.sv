// =============================================================================
//  ERMU Reset Test — Reset behavior matrix across reset types
// =============================================================================

class ermu_reset_test extends ermu_base_test;

    `uvm_component_utils(ermu_reset_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        uvm_status_e   st;
        uvm_reg_data_t rd;

        phase.raise_objection(this);
        wait_reset_release();
        `uvm_info("RST", "=== ERMU Reset Test Start ===", UVM_NONE)

        // ====================================================================
        //  Test: Application Reset (rst_h2_s) during operation
        // ====================================================================
        `uvm_info("RST", "--- Application Reset ---", UVM_NONE)

        env.reg_block.CFGLOCK.write(st, 32'h0000_BC00, UVM_FRONTDOOR, env.reg_block.reg_map);
        // Write some config before reset
        env.reg_block.EOyCTCMP[0].write(st, 32'h0000_00AA, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.EOyC[0].write(st, 32'h0001_0000, UVM_FRONTDOOR, env.reg_block.reg_map); // CTE=1
        env.reg_block.EOyC[0].write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map); // SET=1

        pulse_reset(APP_RST);

        // Check register state after APP_RST
        env.reg_block.EOyCTCMP[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("RST", $sformatf("After APP_RST: CTCMP=0x%08h", rd), UVM_MEDIUM);
        env.reg_block.EOyS[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("RST", $sformatf("After APP_RST: EO0S=0x%08h", rd), UVM_MEDIUM);
        env.reg_block.CFGLOCK.read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("RST", $sformatf("After APP_RST: CFGLOCK=0x%08h", rd), UVM_MEDIUM);

        // ====================================================================
        //  Test: System Reset (rst_pss_h2_s) during operation
        // ====================================================================
        `uvm_info("RST", "--- System Reset ---", UVM_NONE)

        env.reg_block.CFGLOCK.write(st, 32'h0000_BC00, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.EOyCTCMP[0].write(st, 32'h0000_00BB, UVM_FRONTDOOR, env.reg_block.reg_map);

        pulse_reset(SYS_RST);

        env.reg_block.EOyCTCMP[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("RST", $sformatf("After SYS_RST: CTCMP=0x%08h (expect reset value)", rd), UVM_MEDIUM);
        env.reg_block.CFGLOCK.read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("RST", $sformatf("After SYS_RST: CFGLOCK=0x%08h (expect 0x1 locked)", rd), UVM_MEDIUM);

        // ====================================================================
        //  Test: Reset release order variation
        // ====================================================================
        `uvm_info("RST", "--- Reset release order (h2 first) ---", UVM_NONE)

        // Assert all resets
        clk_rst_vif.rst_h2_s     <= 1'b1;
        clk_rst_vif.rst_pss_h2_s <= 1'b1;
        clk_rst_vif.rst_pvs_s    <= 1'b1;
        repeat(10) @(posedge clk_rst_vif.pclk);

        // Release h2 first
        clk_rst_vif.rst_h2_s <= 1'b0;
        repeat(5) @(posedge clk_rst_vif.pclk);
        clk_rst_vif.rst_pss_h2_s <= 1'b0;
        repeat(5) @(posedge clk_rst_vif.pclk);
        clk_rst_vif.rst_pvs_s <= 1'b0;
        repeat(10) @(posedge clk_rst_vif.pclk);

        // Verify basic register access works
        env.reg_block.CFGLOCK.read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("RST", $sformatf("After staggered release: CFGLOCK=0x%08h", rd), UVM_MEDIUM);

        // ====================================================================
        //  Test: Minimum reset pulse width
        // ====================================================================
        `uvm_info("RST", "--- Min reset pulse width ---", UVM_NONE)

        env.reg_block.CFGLOCK.write(st, 32'h0000_BC00, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.EOyCTCMP[0].write(st, 32'h0000_00CC, UVM_FRONTDOOR, env.reg_block.reg_map);

        // Brief reset pulse (2 cycles)
        clk_rst_vif.rst_h2_s <= 1'b1;
        repeat(2) @(posedge clk_rst_vif.pclk);
        clk_rst_vif.rst_h2_s <= 1'b0;
        repeat(10) @(posedge clk_rst_vif.pclk);

        env.reg_block.EOyCTCMP[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("RST", $sformatf("After 2-cycle reset pulse: CTCMP=0x%08h", rd), UVM_MEDIUM);

        `uvm_info("RST", "=== ERMU Reset Test End ===", UVM_NONE)
        phase.drop_objection(this);
    endtask

endclass : ermu_reset_test
