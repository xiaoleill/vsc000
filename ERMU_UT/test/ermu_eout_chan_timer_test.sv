// =============================================================================
//  ERMU EOUT Channel Timer Balancer — Mirror ch0 timer ops on ch1/ch2/ch3
// =============================================================================

class ermu_eout_chan_timer_test extends ermu_base_test;

    `uvm_component_utils(ermu_eout_chan_timer_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        uvm_status_e   st;
        uvm_reg_data_t rd;
        int            ch;

        phase.raise_objection(this);
        wait_reset_release();
        `uvm_info("ECHAN", "=== ERMU EOUT Channel Timer Balancer Start ===", UVM_NONE)

        env.reg_block.CFGLOCK.write(st, 32'h0000_BC00, UVM_FRONTDOOR, env.reg_block.reg_map);
        for (int y = 0; y < 4; y++)
            env.reg_block.EOyC[y].write(st, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map);

        for (ch = 1; ch < 4; ch++) begin
            `uvm_info("ECHAN", $sformatf("--- Channel %0d ---", ch), UVM_NONE)

            // ---- Clear Timer ----
            `uvm_info("ECHAN", $sformatf("  Clear Timer ch%0d", ch), UVM_MEDIUM)
            env.reg_block.EOyCTCMP[ch].write(st, 32'h0000_0064, UVM_FRONTDOOR, env.reg_block.reg_map);
            env.reg_block.EOyC[ch].write(st, 32'h0001_0000, UVM_FRONTDOOR, env.reg_block.reg_map); // CTE=1
            env.reg_block.EOyC[ch].write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map); // SET
            #2000;
            env.reg_block.EOyS[ch].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
            // Try CLR while CTS likely=1 (should be ignored)
            env.reg_block.EOyC[ch].write(st, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map);
            #2000;
            env.reg_block.EOyS[ch].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
            `uvm_info("ECHAN", $sformatf("  Ch%0d CTS test: EO%0dS=0x%08h", ch, ch, rd), UVM_MEDIUM);
            // Wait for match → CTS=0 → CLR
            #30000;
            env.reg_block.EOyC[ch].write(st, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map);
            env.reg_block.EOyC[ch].write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map);

            // ---- Toggle Timer ----
            `uvm_info("ECHAN", $sformatf("  Toggle Timer ch%0d", ch), UVM_MEDIUM)
            env.reg_block.EOyC[ch].write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map); // SET
            #2000;
            env.reg_block.EOyTTCMP[ch].write(st, 32'h0000_0032, UVM_FRONTDOOR, env.reg_block.reg_map);
            env.reg_block.EOyTTC[ch].write(st, 32'h1, UVM_FRONTDOOR, env.reg_block.reg_map); // TTE=1
            env.reg_block.EOyC[ch].write(st, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map); // CLR → start toggle
            #10000;
            env.reg_block.EOyTTCNT[ch].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
            `uvm_info("ECHAN", $sformatf("  Ch%0d TTCNT=0x%08h", ch, rd), UVM_MEDIUM);
            env.reg_block.EOyTTC[ch].write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map); // TTE=0

            // ---- CTCNT read during counting ----
            `uvm_info("ECHAN", $sformatf("  CTCNT read ch%0d", ch), UVM_MEDIUM)
            env.reg_block.EOyCTCMP[ch].write(st, 32'h0000_0080, UVM_FRONTDOOR, env.reg_block.reg_map);
            env.reg_block.EOyC[ch].write(st, 32'h0001_0000, UVM_FRONTDOOR, env.reg_block.reg_map); // CTE=1
            env.reg_block.EOyC[ch].write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map); // SET
            #5000;
            env.reg_block.EOyCTCNT[ch].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
            `uvm_info("ECHAN", $sformatf("  Ch%0d CTCNT=0x%08h", ch, rd), UVM_MEDIUM);
            #20000;
            env.reg_block.EOyC[ch].write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map);
        end

        `uvm_info("ECHAN", "=== ERMU EOUT Channel Timer Balancer End ===", UVM_NONE)
        phase.drop_objection(this);
    endtask

endclass : ermu_eout_chan_timer_test
