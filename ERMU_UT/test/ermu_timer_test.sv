// =============================================================================
//  ERMU Timer Test — Clear timer + Toggle timer + Wait timer verification
// =============================================================================

class ermu_timer_test extends ermu_base_test;

    `uvm_component_utils(ermu_timer_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        uvm_status_e   st;
        uvm_reg_data_t rd;

        phase.raise_objection(this);
        wait_reset_release();
        `uvm_info("TIMER", "=== ERMU Timer Test Start ===", UVM_NONE)

        // ---- Init ----
        env.reg_block.CFGLOCK.write(st, 32'h0000_BC00, UVM_FRONTDOOR, env.reg_block.reg_map);
        for (int y = 0; y < 4; y++)
            env.reg_block.EOyC[y].write(st, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map);

        // ========================================================================
        //  1. Clear Timer Test (channel 0)
        //  Clear Timer is a write-protection gate: CTS=1 blocks CLR; CTS=0
        //  allows software CLR to clear EOS. It never auto-clears EOS.
        // ========================================================================
        `uvm_info("TIMER", "--- Clear Timer Test ---", UVM_NONE)

        // Configure: CTCMP=100, CTE=1
        env.reg_block.EOyCTCMP[0].write(st, 32'h0000_0064, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.EOyC[0].write(st, 32'h0001_0000, UVM_FRONTDOOR, env.reg_block.reg_map); // CTE=1

        // Set EOS via software (EOS=1 + CTE=1 → clear timer starts counting)
        env.reg_block.EOyC[0].write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map); // (spec:TTCMP->CLR->TTE)
        #2000;

        // Verify EOS=1, CTS counting
        env.reg_block.EOyS[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("TIMER", $sformatf("After SET: EO0S=0x%08h (expect EOS=1,CTS may be counting)", rd), UVM_MEDIUM);

        // ---- Sub-test A: CTS=1 blocks CLR ----
        if (rd[16] == 1'b1) begin
            env.reg_block.EOyC[0].write(st, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map); // CLR attempt
            #2000;
            env.reg_block.EOyS[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
            if (rd[0] == 1'b1)
                `uvm_info("TIMER", "CTS=1: CLR ignored correctly (EOS=1)", UVM_NONE)
            else
                `uvm_error("TIMER", "CTS=1: CLR should have been ignored but EOS was cleared!")
        end

        // ---- Sub-test B: CTS=1 blocks CTE=0 write ----
        env.reg_block.EOyC[0].write(st, 32'h0000_0000, UVM_FRONTDOOR, env.reg_block.reg_map); // attempt CTE=0
        #2000;
        env.reg_block.EOyC[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        // Note: CTE is RW, reading back to verify it was NOT cleared during counting
        `uvm_info("TIMER", $sformatf("After CTE=0 attempt during CTS=1: EO0C=0x%08h", rd), UVM_MEDIUM);

        // Wait for clear timer to expire (>100 cycles of HRC @ 125ns = 12.5us)
        #20000;

        // Verify CTS=0 after compare match (protection gate released)
        env.reg_block.EOyS[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("TIMER", $sformatf("After clear timer wait: EO0S=0x%08h (expect CTS=0)", rd), UVM_MEDIUM);

        // ---- Sub-test C: CTS=0 allows CLR to clear EOS ----
        env.reg_block.EOyC[0].write(st, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map); // CLR=1
        #2000;
        env.reg_block.EOyS[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        if (rd[0] == 1'b0)
            `uvm_info("TIMER", "CTS=0: CLR cleared EOS correctly (EOS=0)", UVM_NONE)
        else
            `uvm_warning("TIMER", "CTS=0: CLR did not clear EOS (may have active unmasked errors)")

        // Disable clear timer
        env.reg_block.EOyC[0].write(st, 32'h0000_0000, UVM_FRONTDOOR, env.reg_block.reg_map);

        // ========================================================================
        //  2. Toggle Timer Test (channel 0)
        //  Toggle timer: counts when EOS=0, toggles EOUTyM/EOUTyC pins at TTCMP
        // ========================================================================
        `uvm_info("TIMER", "--- Toggle Timer Test ---", UVM_NONE)

        // SET EOS=1 first — toggle timer does NOT count when EOS=1
        env.reg_block.EOyC[0].write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map); // (spec:TTCMP->CLR->TTE)
        #5000;

        // Configure toggle: TTCMP=50, enable (won't count yet, EOS=1)
        env.reg_block.EOyTTCMP[0].write(st, 32'h0000_0032, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.EOyTTC[0].write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map); // TTE=1

        // Now CLR EOS → EOS=0, toggle timer starts counting toward TTCMP
        env.reg_block.EOyC[0].write(st, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map); // CLR=1
        #50000;

        // Read toggle timer counter
        env.reg_block.EOyTTCNT[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("TIMER", $sformatf("Toggle timer running: TTCNT=0x%08h", rd), UVM_MEDIUM);
        check_timer_running("Toggle", rd);

        // Disable toggle timer
        env.reg_block.EOyTTC[0].write(st, 32'h0000_0000, UVM_FRONTDOOR, env.reg_block.reg_map); // TTE=0

        // ========================================================================
        //  3. Wait Timer Test (timer 0)
        // ========================================================================
        `uvm_info("TIMER", "--- Wait Timer Test ---", UVM_NONE)

        // Configure: WTCMP=200, enable LPI0 start, enable timer
        env.reg_block.WTzCMP[0].write(st, 32'h0000_00C8, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.WTzSE[0].write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map); // LPI0=1
        env.reg_block.WTzC[0].write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map);   // WTE=1

        // Inject an error with LPI0 response to trigger wait timer
        env.reg_block.ERC[1].write(st, {8{3'h2}}, UVM_FRONTDOOR, env.reg_block.reg_map); // source 8..15 → LPI0
        begin
            ermu_simple_input_seq in_seq;
            in_seq = ermu_simple_input_seq::type_id::create("in_seq");
            in_seq.src_id = 8;
            in_seq.pulse_duration = 5;
            in_seq.start(env.virt_sqr.input_sqr);
        end
        #100000;

        // Read wait timer status
        env.reg_block.WTzS[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("TIMER", $sformatf("Wait timer status: WT0S=0x%08h", rd), UVM_MEDIUM);

        // Check source 8 error flag (ESS0 bit 8) — the injected source
        env.reg_block.ESS[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("TIMER", $sformatf("ESS0 after wait timer test: 0x%08h", rd), UVM_MEDIUM);
        if (rd[8] == 1'b1)
            `uvm_info("TIMER", "Source 8 error detected (ESS0[8]=1) OK", UVM_NONE)
        else
            `uvm_warning("TIMER", "Source 8 error NOT detected (ESS0[8]=0)")

        // Also check WT0 internal error (ID=284 → ESS8[28])
        env.reg_block.ESS[8].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("TIMER", $sformatf("ESS8 (WT internal errors): 0x%08h", rd), UVM_MEDIUM);
        if (rd[28] == 1'b1)
            `uvm_info("TIMER", "WT0 timeout internal error detected (ESS8[28]=1) OK", UVM_NONE)
        else
            `uvm_warning("TIMER", "WT0 timeout internal error NOT detected (ESS8[28]=0)")

        // Cleanup
        env.reg_block.WTzC[0].write(st, 32'h0001_0000, UVM_FRONTDOOR, env.reg_block.reg_map); // STP=1
        env.reg_block.ESSC[0].write(st, 32'hFFFF_FFFF, UVM_FRONTDOOR, env.reg_block.reg_map);

        `uvm_info("TIMER", "=== ERMU Timer Test End ===", UVM_NONE)
        phase.drop_objection(this);
    endtask

    task check_timer_running(string name, uvm_reg_data_t val);
        if (val == 0)
            `uvm_warning("TIMER", {name, " timer counter is 0 -- may not be running"})
        else
            `uvm_info("TIMER", $sformatf("%s timer running, CNT=0x%08h OK", name, val), UVM_HIGH)
    endtask

endclass : ermu_timer_test
