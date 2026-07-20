// =============================================================================
//  ERMU Functional Full Test — End-to-end application flow verification
// =============================================================================

class ermu_func_full_test extends ermu_base_test;

    `uvm_component_utils(ermu_func_full_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        uvm_status_e   st;
        uvm_reg_data_t rd;

        phase.raise_objection(this);
        wait_reset_release();
        `uvm_info("FULL", "=== ERMU Full Function Test Start ===", UVM_NONE)

        // ====================================================================
        //  Step 1: Check ESS status (simulate system error handler entry)
        // ====================================================================
        `uvm_info("FULL", "--- Step 1: Read all ESS ---", UVM_NONE)
        for (int j = 0; j < 9; j++) begin
            env.reg_block.ESS[j].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
            `uvm_info("FULL", $sformatf("ESS%0d=0x%08h", j, rd), UVM_HIGH);
        end

        // ====================================================================
        //  Step 2: Clear EOS on all channels
        // ====================================================================
        `uvm_info("FULL", "--- Step 2: Clear EOS ---", UVM_NONE)
        for (int y = 0; y < 4; y++) begin
            env.reg_block.EOyC[y].write(st, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map);
            #1000;
            env.reg_block.EOyS[y].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
            `uvm_info("FULL", $sformatf("EO%0dS=0x%08h", y, rd), UVM_HIGH);
        end

        // ====================================================================
        //  Step 3: Unlock CFGLOCK and configure
        // ====================================================================
        `uvm_info("FULL", "--- Step 3: Unlock + configure ---", UVM_NONE)
        env.reg_block.CFGLOCK.write(st, 32'h0000_BC00, UVM_FRONTDOOR, env.reg_block.reg_map);

        // ====================================================================
        //  Step 4: Configure output masks (unmask critical sources)
        // ====================================================================
        `uvm_info("FULL", "--- Step 4: Configure masks ---", UVM_NONE)
        // Channel 0: unmask all; Channel 1-3: mask all
        env.reg_block.EOyOM[0][0].write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map);
        for (int y = 1; y < 4; y++)
            for (int m = 0; m < 9; m++)
                env.reg_block.EOyOM[y][m].write(st, 32'hFFFF_FFFF, UVM_FRONTDOOR, env.reg_block.reg_map);

        // ====================================================================
        //  Step 5: Configure error responses
        // ====================================================================
        `uvm_info("FULL", "--- Step 5: Configure error responses ---", UVM_NONE)

        // Source 0 (WT0 error): HPI
        env.reg_block.ERC[0].write(st, 32'h0000_0005, UVM_FRONTDOOR, env.reg_block.reg_map); // src0→HPI
        // Sources 8-15: LPI0
        env.reg_block.ERC[1].write(st, {8{3'h2}}, UVM_FRONTDOOR, env.reg_block.reg_map); // LPI0

        env.reg_block.EGC.write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map); // HPIE_C0=1

        // ====================================================================
        //  Step 6: Configure timers
        // ====================================================================
        `uvm_info("FULL", "--- Step 6: Configure timers ---", UVM_NONE)

        // Channel 0: clear timer 100 cycles
        env.reg_block.EOyCTCMP[0].write(st, 32'h0000_0064, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.EOyC[0].write(st, 32'h0001_0000, UVM_FRONTDOOR, env.reg_block.reg_map); // CTE=1

        // Wait timer 0: 200 cycles, triggered by LPI0
        env.reg_block.WTzCMP[0].write(st, 32'h0000_00C8, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.WTzSE[0].write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map); // LPI0=1
        env.reg_block.WTzC[0].write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map);   // WTE=1

        // ====================================================================
        //  Step 7: Inject an error and observe full pipeline
        // ====================================================================
        `uvm_info("FULL", "--- Step 7: Inject error + observe ---", UVM_NONE)

        inject_error(12, 5);  // source 12 → LPI0 response
        #50000;

        // Check ESS
        env.reg_block.ESS[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("FULL", $sformatf("ESS0 after injection: 0x%08h (expect bit12=1)", rd), UVM_MEDIUM);

        // Check EOS
        env.reg_block.EOyS[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("FULL", $sformatf("EO0S: 0x%08h", rd), UVM_MEDIUM);

        // Check wait timer
        env.reg_block.WTzS[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("FULL", $sformatf("WT0S: 0x%08h", rd), UVM_MEDIUM);

        // Wait for clear timer + try software clear
        #100000;
        env.reg_block.EOyS[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        if (rd[16] == 1'b0) begin
            env.reg_block.EOyC[0].write(st, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map); // CLR after CTS=0
            #2000;
            env.reg_block.EOyS[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
            `uvm_info("FULL", $sformatf("After software CLR: EO0S=0x%08h", rd), UVM_MEDIUM);
        end

        // ====================================================================
        //  Step 8: Cleanup
        // ====================================================================
        `uvm_info("FULL", "--- Step 8: Cleanup ---", UVM_NONE)

        for (int j = 0; j < 9; j++) begin
            env.reg_block.ESS[j].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
            if (rd != 32'h0)
                env.reg_block.ESSC[j].write(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        end

        for (int y = 0; y < 4; y++) begin
            for (int m = 0; m < 9; m++)
                env.reg_block.EOyOM[y][m].write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map);
            env.reg_block.EOyC[y].write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map);
            env.reg_block.EOyC[y].write(st, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map);
        end

        for (int p = 0; p < 36; p++)
            env.reg_block.ERC[p].write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map);

        env.reg_block.WTzC[0].write(st, 32'h0001_0000, UVM_FRONTDOOR, env.reg_block.reg_map); // STP
        env.reg_block.EGC.write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map);

        // Re-lock
        env.reg_block.CFGLOCK.write(st, 32'h0000_0000, UVM_FRONTDOOR, env.reg_block.reg_map);

        `uvm_info("FULL", "=== ERMU Full Function Test End ===", UVM_NONE)
        phase.drop_objection(this);
    endtask

    task inject_error(int src_id, int duration);
        ermu_simple_input_seq in_seq;
        in_seq = ermu_simple_input_seq::type_id::create("in_seq");
        in_seq.src_id = src_id;
        in_seq.pulse_duration = duration;
        in_seq.start(env.virt_sqr.input_sqr);
    endtask

endclass : ermu_func_full_test
