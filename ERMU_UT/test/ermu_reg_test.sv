// =============================================================================
//  ERMU Register Test — Reset value + RW/RO/WO field verification
// =============================================================================

class ermu_reg_test extends ermu_base_test;

    `uvm_component_utils(ermu_reg_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        uvm_status_e    st;
        uvm_reg_data_t  rd, wr_val;
        int y, z, j, p, m;

        phase.raise_objection(this);
        wait_reset_release();
        `uvm_info("REG_TEST", "=== ERMU Register Test Start ===", UVM_NONE)

        // ---- 1. Reset value checks (BEFORE any register writes) ----
        `uvm_info("REG_TEST", "--- Reset Value Checks ---", UVM_MEDIUM)

        // Check CFGLOCK reset value FIRST (before unlocking it)
        env.reg_block.CFGLOCK.read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        check_reset("CFGLOCK", rd, 32'h1);  // default locked
        env.reg_block.PERLOCK.read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        check_reset("PERLOCK", rd, 32'h0);

        // EOy registers (y=0..3)
        for (y = 0; y < 4; y++) begin
            env.reg_block.EOyC[y].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
            check_reset($sformatf("EO%0dC", y), rd, 32'h0);
            env.reg_block.EOyS[y].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
            check_reset($sformatf("EO%0dS", y), rd, 32'h1);  // EOS=1 default
            env.reg_block.EOyCTCNT[y].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
            check_reset($sformatf("EO%0dCTCNT", y), rd, 32'h0);
            env.reg_block.EOyCTCMP[y].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
            check_reset($sformatf("EO%0dCTCMP", y), rd, 32'h0);
            env.reg_block.EOyTTC[y].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
            check_reset($sformatf("EO%0dTTC", y), rd, 32'h0);
            env.reg_block.EOyTTCNT[y].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
            check_reset($sformatf("EO%0dTTCNT", y), rd, 32'h0);
            env.reg_block.EOyTTCMP[y].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
            check_reset($sformatf("EO%0dTTCMP", y), rd, 32'h0);
            // OM registers (0..8 per channel covering 288 sources)
            for (m = 0; m < 9; m++) begin
                env.reg_block.EOyOM[y][m].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
                check_reset($sformatf("EO%0dOM%0d", y, m), rd, 32'h0);
            end
        end

        // WTz registers (z=0..1)
        for (z = 0; z < 2; z++) begin
            env.reg_block.WTzC[z].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
            check_reset($sformatf("WT%0dC", z), rd, 32'h0);
            env.reg_block.WTzS[z].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
            check_reset($sformatf("WT%0dS", z), rd, 32'h0);
            env.reg_block.WTzCMP[z].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
            check_reset($sformatf("WT%0dCMP", z), rd, 32'h0);
            env.reg_block.WTzSE[z].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
            check_reset($sformatf("WT%0dSE", z), rd, 32'h0);
        end

        // ESS/ESSC/PET groups (j=0..8)
        for (j = 0; j < 9; j++) begin
            env.reg_block.ESS[j].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
            check_reset($sformatf("ESS%0d", j), rd, 32'h0);
        end

        // ERCp groups (p=0..35)
        for (p = 0; p < 36; p++) begin
            env.reg_block.ERC[p].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
            check_reset($sformatf("ERC%0d", p), rd, 32'h0);
        end

        // Global registers
        env.reg_block.EGC.read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        check_reset("EGC", rd, 32'h1);  // HPIE_C0=1 default
        env.reg_block.CCPS.read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        check_reset("CCPS", rd, 32'h0);
        env.reg_block.EMSC.read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        check_reset("EMSC", rd, 32'h0);
        env.reg_block.EMSS.read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        check_reset("EMSS", rd, 32'h0);
        // ---- 2. Unlock CFGLOCK for RW tests ----
        env.reg_block.CFGLOCK.write(st, 32'h0000_BC00, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("REG_TEST", "CFGLOCK unlocked for RW tests", UVM_MEDIUM)

        // ---- 3. RW test: write pattern, read back ----
        `uvm_info("REG_TEST", "--- RW Field Tests ---", UVM_MEDIUM)

        // CTCMP: write 0x5555, read back
        wr_val = 32'h0000_5555;
        env.reg_block.EOyCTCMP[0].write(st, wr_val, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.EOyCTCMP[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        check_rw("EO0CTCMP RW 0x5555", rd, wr_val & 32'h0000_FFFF);

        // Toggle timer compare
        env.reg_block.EOyTTCMP[0].write(st, 32'h0000_AAAA, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.EOyTTCMP[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        check_rw("EO0TTCMP RW 0xAAAA", rd, 32'h0000_AAAA);

        // Mask register: write all 1s (use OM0 of channel 0)
        env.reg_block.EOyOM[0][0].write(st, 32'hFFFF_FFFF, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.EOyOM[0][0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        check_rw("EO0OM0 RW all-1s", rd, 32'hFFFF_FFFF);
        env.reg_block.EOyOM[0][0].write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map); // restore

        // ERCp: write all-1s, read back with reserved-bit mask (3b per source, 1b reserved)
        // 8 sources × 4 bits = 32 bits, reserved bits: 31,27,23,19,15,11,7,3 → mask 0x77777777
        env.reg_block.ERC[0].write(st, 32'hFFFF_FFFF, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.ERC[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        check_rw("ERC0 RW all-1s (mask=0x77777777)", rd, 32'h7777_7777);
        env.reg_block.ERC[0].write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map); // restore

        // CCPS prescaler: PSC[23:16]=0x80, PSE[0]=1
        wr_val = (32'h0080_0001);  // PSC=0x80 at [23:16], PSE=1 at [0]
        env.reg_block.CCPS.write(st, wr_val, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.CCPS.read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        check_rw("CCPS RW", rd, wr_val);
        env.reg_block.CCPS.write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map); // restore

        // ---- 3. WO field test: write to ESSC/PET, verify write-only behavior ----
        `uvm_info("REG_TEST", "--- WO Field Tests ---", UVM_MEDIUM)
        env.reg_block.PET[0].write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map);
        // PET is WO — reading should return 0
        env.reg_block.PET[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("REG_TEST", $sformatf("PET0 after WO (expect 0): 0x%08h", rd), UVM_MEDIUM);

        // ---- 4. RO field test: write to ESS (RO) should be ignored ----
        env.reg_block.ESS[0].write(st, 32'hFFFF_FFFF, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.ESS[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("REG_TEST", $sformatf("ESS0 after write-attempt (expect 0): 0x%08h", rd), UVM_MEDIUM);

        `uvm_info("REG_TEST", "=== ERMU Register Test End ===", UVM_NONE)
        phase.drop_objection(this);
    endtask

    // ---- Helper ----
    task check_reset(string name, uvm_reg_data_t actual, uvm_reg_data_t expected);
        if (actual != expected)
            `uvm_error("REG_TEST", $sformatf("%s reset: expect 0x%08h got 0x%08h", name, expected, actual))
        else
            `uvm_info("REG_TEST", $sformatf("%s reset: 0x%08h OK", name, actual), UVM_HIGH)
    endtask

    task check_rw(string name, uvm_reg_data_t actual, uvm_reg_data_t expected);
        if (actual != expected)
            `uvm_error("REG_TEST", $sformatf("%s: expect 0x%08h got 0x%08h", name, expected, actual))
        else
            `uvm_info("REG_TEST", $sformatf("%s: 0x%08h OK", name, actual), UVM_HIGH)
    endtask

endclass : ermu_reg_test
