// =============================================================================
//  ERMU Timer Full Test — Deep coverage of Clear/Toggle/Wait timers
//  Covers: restart on new error, write-protect, boundary values, multi-HPI/LPI
// =============================================================================

class ermu_timer_full_test extends ermu_base_test;

    `uvm_component_utils(ermu_timer_full_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        uvm_status_e   st;
        uvm_reg_data_t rd, rd2;

        phase.raise_objection(this);
        wait_reset_release();
        `uvm_info("TIMFULL", "=== ERMU Timer Full Test Start ===", UVM_NONE)

        env.reg_block.CFGLOCK.write(st, 32'h0000_BC00, UVM_FRONTDOOR, env.reg_block.reg_map);
        for (int y = 0; y < 4; y++)
            env.reg_block.EOyC[y].write(st, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.EGC.write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map);

        // ================================================================
        //  1. Clear Timer: restart on new error + write-protect scenarios
        // ================================================================
        `uvm_info("TIMFULL", "--- 1. Clear Timer: restart on new error ---", UVM_NONE)

        // Start clear timer
        env.reg_block.EOyCTCMP[0].write(st, 32'h0000_00C8, UVM_FRONTDOOR, env.reg_block.reg_map); // CTCMP=200
        env.reg_block.EOyC[0].write(st, 32'h0001_0000, UVM_FRONTDOOR, env.reg_block.reg_map); // CTE=1 (error triggers timer)
        // Trigger counter with error injection
        inject_error(8, 2);
        #10000; // Let it count a bit

        // Read CTCNT to verify it's counting
        env.reg_block.EOyCTCNT[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("TIMFULL", $sformatf("CTCNT after 10us: 0x%08h (expect 0, toggle stopped)", rd), UVM_MEDIUM);

        // Inject second error to trigger counter restart
        inject_error(8, 3);
        #3000;
        env.reg_block.EOyCTCNT[0].read(st, rd2, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("TIMFULL", $sformatf("CTCNT after 2nd error: 0x%08h (expect < prev)", rd2), UVM_MEDIUM);

        // Wait for timer expiry
        #30000;
        env.reg_block.EOyS[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("TIMFULL", $sformatf("EO0S after wait: 0x%08h", rd), UVM_MEDIUM);

        // Software CLR after CTS=0
        if (rd[16] == 1'b0) begin
            env.reg_block.EOyC[0].write(st, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map);
        end
        env.reg_block.EOyC[0].write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.ESSC[0].write(st, 32'hFFFF_FFFF, UVM_FRONTDOOR, env.reg_block.reg_map);

        // ---- Clear Timer: write CTCMP when CTE=1 (should be ignored) ----
        `uvm_info("TIMFULL", "--- 1b. Write CTCMP while CTE=1 ---", UVM_NONE)
        env.reg_block.EOyCTCMP[0].write(st, 32'h0000_0064, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.EOyC[0].write(st, 32'h0001_0000, UVM_FRONTDOOR, env.reg_block.reg_map); // CTE=1 (error triggers timer)
        // Trigger counter with error injection
        inject_error(8, 2);
        #5000;
        env.reg_block.EOyCTCMP[0].write(st, 32'h0000_00FF, UVM_FRONTDOOR, env.reg_block.reg_map); // try change, should be ignored
        env.reg_block.EOyCTCMP[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("TIMFULL", $sformatf("CTCMP after write while CTE=1: 0x%08h (expect 0x64)", rd), UVM_MEDIUM);
        #20000;
        env.reg_block.EOyC[0].write(st, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map); // CLR
        env.reg_block.EOyC[0].write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map);

        // ================================================================
        //  2. Toggle Timer: boundary + write-protect + per-channel
        // ================================================================
        `uvm_info("TIMFULL", "--- 2. Toggle Timer: boundaries ---", UVM_NONE)

        // ---- TTCMP=0 boundary ----
        env.reg_block.EOyC[0].write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map); // SET
        #2000;
        env.reg_block.EOyTTCMP[0].write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map); // TTCMP=0
        env.reg_block.EOyTTC[0].write(st, 32'h1, UVM_FRONTDOOR, env.reg_block.reg_map); // TTE=1
        env.reg_block.EOyC[0].write(st, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map); // CLR → start toggle
        #10000;
        env.reg_block.EOyTTCNT[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("TIMFULL", $sformatf("TTCNT with TTCMP=0: 0x%08h", rd), UVM_MEDIUM);
        env.reg_block.EOyTTC[0].write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map); // TTE=0

        // ---- Write TTCMP while TTE=1 (should be ignored) ----
        `uvm_info("TIMFULL", "--- 2b. Write TTCMP while TTE=1 ---", UVM_NONE)
        env.reg_block.EOyC[0].write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map); // SET
        #2000;
        env.reg_block.EOyTTCMP[0].write(st, 32'h0000_0032, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.EOyTTC[0].write(st, 32'h1, UVM_FRONTDOOR, env.reg_block.reg_map); // TTE=1
        env.reg_block.EOyC[0].write(st, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map); // CLR
        #5000;
        env.reg_block.EOyTTCMP[0].write(st, 32'h0000_00AA, UVM_FRONTDOOR, env.reg_block.reg_map); // try change, should be ignored
        env.reg_block.EOyTTCMP[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("TIMFULL", $sformatf("TTCMP after write while TTE=1: 0x%08h (expect 0x32)", rd), UVM_MEDIUM);
        env.reg_block.EOyTTC[0].write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map); // TTE=0

        // ---- TTCMP max boundary ----
        `uvm_info("TIMFULL", "--- 2c. TTCMP=0xFFFF boundary ---", UVM_NONE)
        env.reg_block.EOyC[0].write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map); // SET
        #2000;
        env.reg_block.EOyTTCMP[0].write(st, 32'h0000_FFFF, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.EOyTTC[0].write(st, 32'h1, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.EOyC[0].write(st, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map);
        #5000;
        env.reg_block.EOyTTCNT[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("TIMFULL", $sformatf("TTCNT with TTCMP=0xFFFF: 0x%08h (expect 0, toggle stopped)", rd), UVM_MEDIUM);
        env.reg_block.EOyTTC[0].write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map);

        // ---- Per-channel toggle (channel 1 independent) ----
        `uvm_info("TIMFULL", "--- 2d. Channel 1 toggle independent ---", UVM_NONE)
        env.reg_block.EOyC[1].write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map); // SET ch1
        #2000;
        env.reg_block.EOyTTCMP[1].write(st, 32'h0000_0032, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.EOyTTC[1].write(st, 32'h1, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.EOyC[1].write(st, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map); // CLR ch1
        #10000;
        env.reg_block.EOyTTCNT[1].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("TIMFULL", $sformatf("Ch1 TTCNT: 0x%08h", rd), UVM_MEDIUM);
        env.reg_block.EOyTTC[1].write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map);

        // ================================================================
        //  3. Wait Timer: multi-start + STP + write-protect + boundaries
        // ================================================================
        `uvm_info("TIMFULL", "--- 3. Wait Timer: multi-HPI/LPI start ---", UVM_NONE)

        // ---- LPI0+HPI0 both enabled ----
        cfg_single(8, 3'h2); // source 8 → LPI0
        env.reg_block.WTzCMP[0].write(st, 32'h0000_00C8, UVM_FRONTDOOR, env.reg_block.reg_map); // WTCMP=200
        env.reg_block.WTzSE[0].write(st, 32'h0001_0001, UVM_FRONTDOOR, env.reg_block.reg_map); // HPI0=1, LPI0=1
        env.reg_block.WTzC[0].write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map); // WTE=1
        inject_error(8, 3);
        #40000;
        env.reg_block.WTzS[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("TIMFULL", $sformatf("WT0S after LPI trigger: 0x%08h", rd), UVM_MEDIUM);
        env.reg_block.WTzC[0].write(st, 32'h0001_0000, UVM_FRONTDOOR, env.reg_block.reg_map); // STP
        cfg_single(8, 3'h0);

        // ---- WTzSE all LPI bits ----
        `uvm_info("TIMFULL", "--- 3b. WTzSE all LPI bits ---", UVM_NONE)
        env.reg_block.WTzCMP[0].write(st, 32'h0000_00C8, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.WTzSE[0].write(st, 32'h0000_0007, UVM_FRONTDOOR, env.reg_block.reg_map); // LPI0+LPI1+LPI2
        env.reg_block.WTzC[0].write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map); // WTE=1
        cfg_single(8, 3'h3); // source 8 → LPI1
        inject_error(8, 3);
        #40000;
        env.reg_block.WTzS[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("TIMFULL", $sformatf("WT0S after LPI1 trigger: 0x%08h", rd), UVM_MEDIUM);
        env.reg_block.WTzC[0].write(st, 32'h0001_0000, UVM_FRONTDOOR, env.reg_block.reg_map); // STP
        cfg_single(8, 3'h0);

        // ---- Write WTzCMP while WTE=1 (should be ignored) ----
        `uvm_info("TIMFULL", "--- 3c. Write WTzCMP while WTE=1 ---", UVM_NONE)
        env.reg_block.WTzCMP[0].write(st, 32'h0000_0064, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.WTzSE[0].write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map); // LPI0=1
        env.reg_block.WTzC[0].write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map); // WTE=1
        env.reg_block.WTzCMP[0].write(st, 32'h0000_00FF, UVM_FRONTDOOR, env.reg_block.reg_map); // try change, should be ignored
        env.reg_block.WTzCMP[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("TIMFULL", $sformatf("WTzCMP after write while WTE=1: 0x%08h (expect 0x64)", rd), UVM_MEDIUM);
        env.reg_block.WTzC[0].write(st, 32'h0001_0000, UVM_FRONTDOOR, env.reg_block.reg_map); // STP

        // ---- WTzCMP=1 forbidden ----
        `uvm_info("TIMFULL", "--- 3d. WTzCMP=1 forbidden ---", UVM_NONE)
        env.reg_block.WTzC[0].write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map); // WTE=0
        env.reg_block.WTzCMP[0].write(st, 32'h1, UVM_FRONTDOOR, env.reg_block.reg_map); // try CMP=1
        env.reg_block.WTzCMP[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("TIMFULL", $sformatf("WTzCMP after write 1: 0x%08h (expect !=1)", rd), UVM_MEDIUM);

        // ---- Wait timer 1 independent test ----
        `uvm_info("TIMFULL", "--- 3e. Wait timer 1 ---", UVM_NONE)
        cfg_single(16, 3'h2); // source 16 → LPI0
        env.reg_block.WTzCMP[1].write(st, 32'h0000_0064, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.WTzSE[1].write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.WTzC[1].write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map); // WTE=1
        inject_error(16, 3);
        #20000;
        env.reg_block.WTzS[1].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("TIMFULL", $sformatf("WT1S: 0x%08h", rd), UVM_MEDIUM);
        env.reg_block.WTzC[1].write(st, 32'h0001_0000, UVM_FRONTDOOR, env.reg_block.reg_map); // STP
        cfg_single(16, 3'h0);

        // ================================================================
        //  4. Cleanup
        // ================================================================
        for (int j = 0; j < 9; j++)
            env.reg_block.ESSC[j].write(st, 32'hFFFF_FFFF, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.EGC.write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map);

        `uvm_info("TIMFULL", "=== ERMU Timer Full Test End ===", UVM_NONE)
        phase.drop_objection(this);
    endtask

    task cfg_single(int src_id, bit [2:0] erc);
        uvm_status_e st;
        int p = src_id / 8;
        int e = src_id % 8;
        bit [31:0] val;
        env.reg_block.ERC[p].read(st, val, UVM_FRONTDOOR, env.reg_block.reg_map);
        val = (val & ~(32'h7 << (e*4))) | (erc << (e*4));
        env.reg_block.ERC[p].write(st, val, UVM_FRONTDOOR, env.reg_block.reg_map);
    endtask

    task inject_error(int src_id, int duration);
        ermu_simple_input_seq in_seq;
        in_seq = ermu_simple_input_seq::type_id::create("in_seq");
        in_seq.src_id = src_id;
        in_seq.pulse_duration = duration;
        in_seq.start(env.virt_sqr.input_sqr);
    endtask

endclass : ermu_timer_full_test
