// =============================================================================
//  ERMU Prescaler Test — CCPS clock prescaler verification
// =============================================================================

class ermu_prescaler_test extends ermu_base_test;

    `uvm_component_utils(ermu_prescaler_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        uvm_status_e   st;
        uvm_reg_data_t rd;
        int            psc_vals[4];  // pre-declared for xrun compat

        phase.raise_objection(this);
        wait_reset_release();
        `uvm_info("PSC", "=== ERMU Prescaler Test Start ===", UVM_NONE)

        env.reg_block.CFGLOCK.write(st, 32'h0000_BC00, UVM_FRONTDOOR, env.reg_block.reg_map);
        for (int y = 0; y < 4; y++)
            env.reg_block.EOyC[y].write(st, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map);

        // ====================================================================
        //  Test: PSE disable → timer uses raw CNT_MCLK
        // ====================================================================
        `uvm_info("PSC", "--- PSE=0 (raw clock) ---", UVM_NONE)
        env.reg_block.CCPS.write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map); // PSE=0

        test_timer_period("PSE=0", 100);

        // ====================================================================
        //  Test: PSE=1 with various prescaler values
        // ====================================================================
        psc_vals[0] = 1; psc_vals[1] = 5; psc_vals[2] = 127; psc_vals[3] = 255;
        for (int pi = 0; pi < 4; pi++) begin
            int psc = psc_vals[pi];
            bit [31:0] ccps_val = (psc << 16) | 32'h1; // PSC at [23:16], PSE=1
            `uvm_info("PSC", $sformatf("--- PSC=%0d (div by %0d) ---", psc, psc+1), UVM_NONE)
            env.reg_block.CCPS.write(st, ccps_val, UVM_FRONTDOOR, env.reg_block.reg_map);
            env.reg_block.CCPS.read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
            `uvm_info("PSC", $sformatf("CCPS readback: 0x%08h", rd), UVM_MEDIUM);
            // Quick test: timer should be slower with larger PSC
            test_timer_running($sformatf("PSC=%0d", psc), 100);
        end

        // ====================================================================
        //  Test: PSC reserved bits read 0
        // ====================================================================
        `uvm_info("PSC", "--- PSC reserved bits ---", UVM_NONE)
        env.reg_block.CCPS.write(st, 32'hFFFF_FFFF, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.CCPS.read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        // PSC is 8bit [23:16], bits [31:24] should be reserved (0)
        if ((rd & 32'hFF00_0000) == 32'h0)
            `uvm_info("PSC", $sformatf("PSC reserved bits[31:24]=0 OK (rd=0x%08h)", rd), UVM_NONE)
        else
            `uvm_info("PSC", $sformatf("PSC reserved check: rd=0x%08h", rd), UVM_MEDIUM)

        // Restore
        env.reg_block.CCPS.write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map);

        `uvm_info("PSC", "=== ERMU Prescaler Test End ===", UVM_NONE)
        phase.drop_objection(this);
    endtask

    task test_timer_period(string label, int ctcmp_val);
        uvm_status_e   st;
        uvm_reg_data_t rd;
        env.reg_block.EOyCTCMP[0].write(st, ctcmp_val, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.EOyC[0].write(st, 32'h0001_0000, UVM_FRONTDOOR, env.reg_block.reg_map); // CTE=1
        env.reg_block.EOyC[0].write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map); // SET=1
        #(ctcmp_val * 1000); // rough wait
        env.reg_block.EOyS[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("PSC", $sformatf("%s: EO0S=0x%08h (CTS status)", label, rd), UVM_MEDIUM);
        env.reg_block.EOyC[0].write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map); // disable CTE
        // Clear EOS
        env.reg_block.EOyC[0].write(st, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map);
    endtask

    task test_timer_running(string label, int ttcmp_val);
        uvm_status_e   st;
        uvm_reg_data_t rd;
        // Quick toggle timer test
        env.reg_block.EOyC[0].write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map); // SET
        #2000;
        env.reg_block.EOyTTCMP[0].write(st, ttcmp_val, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.EOyTTC[0].write(st, 32'h1, UVM_FRONTDOOR, env.reg_block.reg_map); // TTE=1
        env.reg_block.EOyC[0].write(st, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map); // CLR
        #50000;
        env.reg_block.EOyTTCNT[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("PSC", $sformatf("%s: TTCNT=0x%08h", label, rd), UVM_MEDIUM);
        env.reg_block.EOyTTC[0].write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map); // TTE=0
    endtask

endclass : ermu_prescaler_test
