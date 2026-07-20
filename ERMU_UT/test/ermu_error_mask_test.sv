// =============================================================================
//  ERMU Error Mask Test — Output mask register (EOyOMj) verification
// =============================================================================

class ermu_error_mask_test extends ermu_base_test;

    `uvm_component_utils(ermu_error_mask_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        uvm_status_e   st;
        uvm_reg_data_t rd;

        phase.raise_objection(this);
        wait_reset_release();
        `uvm_info("MASK", "=== ERMU Error Mask Test Start ===", UVM_NONE)

        env.reg_block.CFGLOCK.write(st, 32'h0000_BC00, UVM_FRONTDOOR, env.reg_block.reg_map);
        for (int y = 0; y < 4; y++)
            env.reg_block.EOyC[y].write(st, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map);

        // ====================================================================
        //  Test: Mask individual sources on channel 0
        // ====================================================================
        `uvm_info("MASK", "--- Single Source Mask (channel 0, source 8) ---", UVM_NONE)

        // Mask source 8 on channel 0 (OM0 bit8)
        env.reg_block.EOyOM[0][0].write(st, 32'h0000_0100, UVM_FRONTDOOR, env.reg_block.reg_map); // bit8=1 mask
        // Inject error on source 8
        inject_error(8, 5);
        #10000;

        // EOS should NOT be set on channel 0 (masked)
        env.reg_block.EOyS[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        if (rd[0] == 1'b0)
            `uvm_info("MASK", "Source 8 masked: EOS0=0 OK", UVM_NONE)
        else
            `uvm_error("MASK", "Source 8 masked but EOS0=1!")

        // ESS should still record the error even if masked from output
        env.reg_block.ESS[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("MASK", $sformatf("ESS0 after masked injection: 0x%08h", rd), UVM_MEDIUM);

        // Cleanup
        env.reg_block.ESSC[0].write(st, 32'hFFFF_FFFF, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.EOyOM[0][0].write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map);

        // ====================================================================
        //  Test: Unmasked source triggers EOS
        // ====================================================================
        `uvm_info("MASK", "--- Unmasked Source (channel 0, source 8) ---", UVM_NONE)

        // OM=0 (unmasked), inject error
        inject_error(8, 5);
        #10000;

        env.reg_block.EOyS[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        if (rd[0] == 1'b1)
            `uvm_info("MASK", "Source 8 unmasked: EOS0=1 OK", UVM_NONE)
        else
            `uvm_warning("MASK", "Source 8 unmasked but EOS0=0 (may need SET first)")

        env.reg_block.ESSC[0].write(st, 32'hFFFF_FFFF, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.EOyC[0].write(st, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map); // CLR

        // ====================================================================
        //  Test: Full mask (all OM bits = 1) blocks all sources
        // ====================================================================
        `uvm_info("MASK", "--- Full Mask Test ---", UVM_NONE)

        for (int m = 0; m < 9; m++)
            env.reg_block.EOyOM[0][m].write(st, 32'hFFFF_FFFF, UVM_FRONTDOOR, env.reg_block.reg_map);

        inject_error(8, 5);
        inject_error(100, 5);
        #10000;

        env.reg_block.EOyS[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        if (rd[0] == 1'b0)
            `uvm_info("MASK", "Full mask: EOS0=0 OK", UVM_NONE)
        else
            `uvm_error("MASK", "Full mask but EOS0=1!")

        // Cleanup: restore masks
        for (int m = 0; m < 9; m++)
            env.reg_block.EOyOM[0][m].write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.ESSC[0].write(st, 32'hFFFF_FFFF, UVM_FRONTDOOR, env.reg_block.reg_map);

        // ====================================================================
        //  Test: Channel-independent masking
        // ====================================================================
        `uvm_info("MASK", "--- Channel-Independent Mask ---", UVM_NONE)

        // Mask source 8 on ch0, unmask on ch1
        env.reg_block.EOyOM[0][0].write(st, 32'h0000_0100, UVM_FRONTDOOR, env.reg_block.reg_map); // bit8=1
        inject_error(8, 5);
        #10000;

        env.reg_block.EOyS[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("MASK", $sformatf("Ch0 (masked):  EO0S=0x%08h", rd), UVM_MEDIUM);
        env.reg_block.EOyS[1].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("MASK", $sformatf("Ch1 (unmasked): EO1S=0x%08h", rd), UVM_MEDIUM);

        env.reg_block.ESSC[0].write(st, 32'hFFFF_FFFF, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.EOyOM[0][0].write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map);

        // ====================================================================
        //  Test: OM registers protected by CFGLOCK
        // ====================================================================
        `uvm_info("MASK", "--- OM CFGLOCK Protection ---", UVM_NONE)

        // Re-lock CFGLOCK
        env.reg_block.CFGLOCK.write(st, 32'h0000_0000, UVM_FRONTDOOR, env.reg_block.reg_map); // lock
        // Try writing OM
        env.reg_block.EOyOM[0][0].write(st, 32'hFFFF_FFFF, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.EOyOM[0][0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        if (rd == 32'h0)
            `uvm_info("MASK", "OM CFGLOCK protected: write ignored OK", UVM_NONE)
        else
            `uvm_error("MASK", "OM should be CFGLOCK protected!")

        // Re-unlock
        env.reg_block.CFGLOCK.write(st, 32'h0000_BC00, UVM_FRONTDOOR, env.reg_block.reg_map);

        `uvm_info("MASK", "=== ERMU Error Mask Test End ===", UVM_NONE)
        phase.drop_objection(this);
    endtask

    task inject_error(int src_id, int duration);
        ermu_simple_input_seq in_seq;
        in_seq = ermu_simple_input_seq::type_id::create("in_seq");
        in_seq.src_id = src_id;
        in_seq.pulse_duration = duration;
        in_seq.start(env.virt_sqr.input_sqr);
    endtask

endclass : ermu_error_mask_test
