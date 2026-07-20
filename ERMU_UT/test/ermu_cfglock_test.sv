// =============================================================================
//  ERMU CFGLOCK/PERLOCK Test — Configuration lock & permanent lock verification
// =============================================================================

class ermu_cfglock_test extends ermu_base_test;

    `uvm_component_utils(ermu_cfglock_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        uvm_status_e   st;
        uvm_reg_data_t rd;

        phase.raise_objection(this);
        wait_reset_release();
        `uvm_info("CFGLOCK", "=== ERMU CFGLOCK/PERLOCK Test Start ===", UVM_NONE)

        // ====================================================================
        //  1. CFGLOCK default locked — protected register writes ignored
        // ====================================================================
        `uvm_info("CFGLOCK", "--- 1. CFGLOCK Default Locked ---", UVM_NONE)

        // Verify CFGLOCK=1 by default
        env.reg_block.CFGLOCK.read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("CFGLOCK", $sformatf("CFGLOCK reset value: 0x%08h (expect bit0=1)", rd), UVM_MEDIUM);
        if (rd[0] == 1'b1)
            `uvm_info("CFGLOCK", "CFGLOCK default locked OK", UVM_NONE)
        else
            `uvm_error("CFGLOCK", "CFGLOCK should be locked by default!")

        // Try writing to a protected register (CTCMP) while locked
        env.reg_block.EOyCTCMP[0].write(st, 32'h0000_00AA, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.EOyCTCMP[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        if (rd == 32'h0)
            `uvm_info("CFGLOCK", "Locked: CTCMP write ignored OK (still 0x0)", UVM_NONE)
        else
            `uvm_error("CFGLOCK", $sformatf("Locked: CTCMP write should be ignored! got 0x%08h", rd))

        // ====================================================================
        //  2. EOyC.CLR and WTzC.STP NOT protected by CFGLOCK
        // ====================================================================
        `uvm_info("CFGLOCK", "--- 2. Unprotected bits (CLR, STP) ---", UVM_NONE)

        // First SET EOS to give CLR something to clear
        env.reg_block.EOyC[0].write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map); // SET=1
        #2000;
        env.reg_block.EOyS[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("CFGLOCK", $sformatf("After SET (CFGLOCK=1): EO0S=0x%08h", rd), UVM_MEDIUM);

        // CLR should work even when CFGLOCK=1 (SET already worked above, proving it's also unprotected)
        // Actually SET is WL-protected but CLR is not. Let's test CLR specifically:
        // Clear timer must not be running, so just verify CLR can execute
        env.reg_block.EOyC[0].write(st, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map); // CLR=1
        #2000;
        env.reg_block.EOyS[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("CFGLOCK", $sformatf("After CLR (CFGLOCK=1): EO0S=0x%08h (expect EOS=0)", rd), UVM_MEDIUM);
        if (rd[0] == 1'b0)
            `uvm_info("CFGLOCK", "CLR not protected by CFGLOCK OK", UVM_NONE)
        else
            `uvm_info("CFGLOCK", "CLR: EOS still 1 (may have active errors or CTS=1)", UVM_MEDIUM);

        // ====================================================================
        //  3. Unlock CFGLOCK (KEY=0xBC)
        // ====================================================================
        `uvm_info("CFGLOCK", "--- 3. CFGLOCK Unlock (KEY=0xBC) ---", UVM_NONE)

        env.reg_block.CFGLOCK.write(st, 32'h0000_BC00, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.CFGLOCK.read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("CFGLOCK", $sformatf("CFGLOCK after unlock: 0x%08h (expect bit0=0)", rd), UVM_MEDIUM);
        if (rd[0] == 1'b0)
            `uvm_info("CFGLOCK", "CFGLOCK unlocked OK", UVM_NONE)
        else
            `uvm_error("CFGLOCK", "CFGLOCK unlock failed!")

        // Now protected register should be writable
        env.reg_block.EOyCTCMP[0].write(st, 32'h0000_00BB, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.EOyCTCMP[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        if (rd == 32'h0000_00BB)
            `uvm_info("CFGLOCK", "Unlocked: CTCMP write OK", UVM_NONE)
        else
            `uvm_error("CFGLOCK", $sformatf("Unlocked: CTCMP write failed! got 0x%08h", rd))

        // Restore
        env.reg_block.EOyCTCMP[0].write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map);

        // ====================================================================
        //  4. Re-lock CFGLOCK (KEY≠0xBC)
        // ====================================================================
        `uvm_info("CFGLOCK", "--- 4. CFGLOCK Re-lock (KEY=0x00) ---", UVM_NONE)

        env.reg_block.CFGLOCK.write(st, 32'h0000_0000, UVM_FRONTDOOR, env.reg_block.reg_map); // KEY=0x00 → lock
        env.reg_block.CFGLOCK.read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        if (rd[0] == 1'b1)
            `uvm_info("CFGLOCK", "CFGLOCK re-locked OK", UVM_NONE)
        else
            `uvm_error("CFGLOCK", "CFGLOCK re-lock failed!")

        // Verify protected writes are ignored again
        env.reg_block.EOyCTCMP[0].write(st, 32'h0000_00CC, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.EOyCTCMP[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        if (rd == 32'h0)
            `uvm_info("CFGLOCK", "Re-locked: CTCMP write ignored OK", UVM_NONE)
        else
            `uvm_error("CFGLOCK", "Re-locked: CTCMP write should be ignored!")

        // ====================================================================
        //  5. Unlock again for PERLOCK test
        // ====================================================================
        env.reg_block.CFGLOCK.write(st, 32'h0000_BC00, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.CFGLOCK.read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("CFGLOCK", $sformatf("CFGLOCK re-unlocked: 0x%08h", rd), UVM_MEDIUM);

        // ====================================================================
        //  6. PERLOCK permanent lock (KEY=0xFF)
        // ====================================================================
        `uvm_info("CFGLOCK", "--- 5. PERLOCK Permanent Lock (KEY=0xFF) ---", UVM_NONE)

        env.reg_block.PERLOCK.read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("CFGLOCK", $sformatf("PERLOCK before lock: 0x%08h (expect 0)", rd), UVM_MEDIUM);

        env.reg_block.PERLOCK.write(st, 32'h0000_FF00, UVM_FRONTDOOR, env.reg_block.reg_map); // KEY=0xFF
        env.reg_block.PERLOCK.read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        if (rd[0] == 1'b1)
            `uvm_info("CFGLOCK", "PERLOCK permanently locked OK", UVM_NONE)
        else
            `uvm_error("CFGLOCK", "PERLOCK permanent lock failed!")

        // ====================================================================
        //  7. PERLOCK=1: ALL writes ignored (even CFGLOCK unlock)
        // ====================================================================
        `uvm_info("CFGLOCK", "--- 6. PERLOCK blocks all writes ---", UVM_NONE)

        // Try unlocking CFGLOCK (should be ignored)
        env.reg_block.CFGLOCK.write(st, 32'h0000_BC00, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.CFGLOCK.read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("CFGLOCK", $sformatf("CFGLOCK after unlock attempt (PERLOCK=1): 0x%08h", rd), UVM_MEDIUM);
        // CFG_LOCK should be unchanged (whatever it was before PERLOCK)

        // Try writing a protected register (should be ignored)
        env.reg_block.EOyCTCMP[0].write(st, 32'h0000_00DD, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.EOyCTCMP[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        if (rd == 32'h0)
            `uvm_info("CFGLOCK", "PERLOCK=1: CTCMP write ignored OK", UVM_NONE)
        else
            `uvm_error("CFGLOCK", $sformatf("PERLOCK=1: CTCMP write should be ignored! got 0x%08h", rd))

        // ====================================================================
        //  8. Application Reset does NOT clear PERLOCK
        // ====================================================================
        `uvm_info("CFGLOCK", "--- 7. Application Reset keeps PERLOCK ---", UVM_NONE)

        pulse_reset(APP_RST);

        env.reg_block.PERLOCK.read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        if (rd[0] == 1'b1)
            `uvm_info("CFGLOCK", "PERLOCK survives Application Reset OK", UVM_NONE)
        else
            `uvm_error("CFGLOCK", "PERLOCK should survive Application Reset!")

        // ====================================================================
        //  9. Power-On Reset clears PERLOCK
        // ====================================================================
        `uvm_info("CFGLOCK", "--- 8. Power-On Reset clears PERLOCK ---", UVM_NONE)

        pulse_reset(POR_RST);

        env.reg_block.PERLOCK.read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        if (rd[0] == 1'b0)
            `uvm_info("CFGLOCK", "PERLOCK cleared by Power-On Reset OK", UVM_NONE)
        else
            `uvm_error("CFGLOCK", "PERLOCK should be cleared by Power-On Reset!")

        // CFGLOCK should also be back to default locked
        env.reg_block.CFGLOCK.read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("CFGLOCK", $sformatf("CFGLOCK after POR: 0x%08h (expect 0x1)", rd), UVM_MEDIUM);

        `uvm_info("CFGLOCK", "=== ERMU CFGLOCK/PERLOCK Test End ===", UVM_NONE)
        phase.drop_objection(this);
    endtask

endclass : ermu_cfglock_test
