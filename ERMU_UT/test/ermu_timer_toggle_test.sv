// =============================================================================
//  ERMU Timer Toggle Coverage Test
//  Covers: CMP/CNT bit-level toggle (0x0000/0xFFFF/0x5555/0xAAAA)
//          Clear Timer CTS state transitions
// =============================================================================

class ermu_timer_toggle_test extends ermu_base_test;

    `uvm_component_utils(ermu_timer_toggle_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        uvm_status_e   st;
        uvm_reg_data_t rd;
        bit [31:0]     patterns[6];
        int            i;

        phase.raise_objection(this);
        wait_reset_release();
        `uvm_info("TTOG", "=== ERMU Timer Bit-Toggle + CTS State Test Start ===", UVM_NONE)

        env.reg_block.CFGLOCK.write(st, 32'h0000_BC00, UVM_FRONTDOOR, env.reg_block.reg_map);
        for (int y = 0; y < 4; y++)
            env.reg_block.EOyC[y].write(st, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map);

        // ================================================================
        //  1. CTCMP bit-toggle patterns: force all 16 bits to flip
        // ================================================================
        `uvm_info("TTOG", "--- 1. CTCMP bit-toggle patterns ---", UVM_NONE)
        patterns[0]=32'h0; patterns[1]=32'h0000_FFFF; patterns[2]=32'h0;
        patterns[3]=32'h0000_5555; patterns[4]=32'h0000_AAAA; patterns[5]=32'h0;
        for (i = 0; i < 6; i++) begin
            env.reg_block.EOyCTCMP[0].write(st, patterns[i], UVM_FRONTDOOR, env.reg_block.reg_map);
            env.reg_block.EOyCTCMP[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
            `uvm_info("TTOG", $sformatf("CTCMP write 0x%04h -> read 0x%04h", patterns[i], rd), UVM_HIGH)
        end

        // ================================================================
        //  2. TTCMP bit-toggle patterns
        // ================================================================
        `uvm_info("TTOG", "--- 2. TTCMP bit-toggle patterns ---", UVM_NONE)
        foreach (patterns[i]) begin
            env.reg_block.EOyTTCMP[0].write(st, patterns[i], UVM_FRONTDOOR, env.reg_block.reg_map);
            env.reg_block.EOyTTCMP[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
            `uvm_info("TTOG", $sformatf("TTCMP write 0x%04h -> read 0x%04h", patterns[i], rd), UVM_HIGH)
        end

        // ================================================================
        //  3. WTzCMP bit-toggle patterns (both timers)
        // ================================================================
        `uvm_info("TTOG", "--- 3. WTzCMP bit-toggle patterns ---", UVM_NONE)
        foreach (patterns[i]) begin
            env.reg_block.WTzCMP[0].write(st, patterns[i], UVM_FRONTDOOR, env.reg_block.reg_map);
            env.reg_block.WTzCMP[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
            env.reg_block.WTzCMP[1].write(st, patterns[i], UVM_FRONTDOOR, env.reg_block.reg_map);
            env.reg_block.WTzCMP[1].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        end

        // ================================================================
        //  4. Clear Timer CTS state machine: all transitions
        // ================================================================
        `uvm_info("TTOG", "--- 4. CTS state machine ---", UVM_NONE)

        // State A: IDLE (CTS=0, CTE=0)
        env.reg_block.EOyC[0].write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.EOyS[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("TTOG", $sformatf("IDLE state: EO0S=0x%08h (CTS=%0b EOS=%0b)", rd, rd[16], rd[0]), UVM_MEDIUM);

        // Transition A→B: IDLE→COUNTING ((spec:TTCMP->CLR->TTE) + CTE=1)
        env.reg_block.EOyCTCMP[0].write(st, 32'h0000_0064, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.EOyC[0].write(st, 32'h0001_0000, UVM_FRONTDOOR, env.reg_block.reg_map); // CTE=1 (error triggers timer)
        // Trigger counter with error injection
        inject_error(8, 2);
        #2000;
        env.reg_block.EOyS[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("TTOG", $sformatf("IDLE->COUNTING: EO0S=0x%08h (expect CTS=1,EOS=1)", rd), UVM_MEDIUM);

        // State B: COUNTING — try CLR (should be blocked by CTS=1)
        if (rd[16] == 1'b1) begin
            env.reg_block.EOyC[0].write(st, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map); // CLR
            #2000;
            env.reg_block.EOyS[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
            `uvm_info("TTOG", $sformatf("COUNTING+CLR attempt: EO0S=0x%08h (expect EOS=1,CLR blocked)", rd), UVM_MEDIUM);
        end
        // Wait for match → transition B→A: COUNTING→IDLE
        #30000;
        env.reg_block.EOyS[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("TTOG", $sformatf("COUNTING->IDLE (match): EO0S=0x%08h (expect CTS=0)", rd), UVM_MEDIUM);

        // After CTS=0, CLR should work
        env.reg_block.EOyC[0].write(st, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map); // CLR
        #2000;
        env.reg_block.EOyS[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("TTOG", $sformatf("After match+CLR: EO0S=0x%08h (expect CTS=0,EOS=0)", rd), UVM_MEDIUM);

        // Transition A→B again, then new error restart (COUNTING→COUNTING)
        `uvm_info("TTOG", "--- 4b. COUNTING->COUNTING (new error restart) ---", UVM_NONE)
        env.reg_block.EOyCTCMP[0].write(st, 32'h0000_00C8, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.EOyC[0].write(st, 32'h0001_0000, UVM_FRONTDOOR, env.reg_block.reg_map); // CTE=1 (error triggers timer)
        // Trigger counter with error injection
        inject_error(8, 2);
        #5000; // let it count a bit
        // Inject new error while counting → counter should restart
        inject_error(8, 3);
        #3000;
        env.reg_block.EOyCTCNT[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("TTOG", $sformatf("After error restart: CTCNT=0x%04h (expect low, just restarted)", rd), UVM_MEDIUM);
        #30000;
        env.reg_block.EOyC[0].write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.ESSC[0].write(st, 32'hFFFF_FFFF, UVM_FRONTDOOR, env.reg_block.reg_map);

        // ================================================================
        //  5. CTCNT/TTCNT/WTCNT read during counting (bit visibility)
        // ================================================================
        `uvm_info("TTOG", "--- 5. CNT reads during counting ---", UVM_NONE)
        env.reg_block.EOyCTCMP[0].write(st, 32'h0000_00FF, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.EOyC[0].write(st, 32'h0001_0000, UVM_FRONTDOOR, env.reg_block.reg_map); // CTE=1 (error triggers timer)
        // Trigger counter with error injection
        inject_error(8, 2);
        for (i = 0; i < 5; i++) begin
            #2000;
            env.reg_block.EOyCTCNT[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
            `uvm_info("TTOG", $sformatf("CTCNT snapshot %0d: 0x%04h", i, rd), UVM_HIGH)
        end
        env.reg_block.EOyC[0].write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map);

        // Cleanup
        for (int j = 0; j < 9; j++)
            env.reg_block.ESSC[j].write(st, 32'hFFFF_FFFF, UVM_FRONTDOOR, env.reg_block.reg_map);

        `uvm_info("TTOG", "=== ERMU Timer Bit-Toggle + CTS State Test End ===", UVM_NONE)
        phase.drop_objection(this);
    endtask

    task inject_error(int src_id, int duration);
        ermu_simple_input_seq in_seq;
        in_seq = ermu_simple_input_seq::type_id::create("in_seq");
        in_seq.src_id = src_id;
        in_seq.pulse_duration = duration;
        in_seq.start(env.virt_sqr.input_sqr);
    endtask

endclass : ermu_timer_toggle_test
