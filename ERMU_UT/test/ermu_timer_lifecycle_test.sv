// =============================================================================
//  ERMU Timer Lifecycle Test — Randomized multi-seed expander
//  Randomizes: PSC, CMP, channel order per iteration
//  Each seed runs 3 iterations with different random settings
// =============================================================================

class ermu_timer_lifecycle_test extends ermu_base_test;

    `uvm_component_utils(ermu_timer_lifecycle_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        uvm_status_e   st;
        uvm_reg_data_t rd, rp;
        int            ctcmp, ttcmp, wtcmp, psc, ch, ch_order[4], z_order[2];
        int            tick_ns;   // one counter tick in ns = 125*(PSC+1) or 125

        uvm_root::get().set_timeout(500_000_000, 1);
        phase.raise_objection(this);
        wait_reset_release();

        env.reg_block.CFGLOCK.write(st, 32'h0000_BC00, UVM_FRONTDOOR, env.reg_block.reg_map);
        for (int y = 0; y < 4; y++)
            env.reg_block.EOyC[y].write(st, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.EGC.write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map);

        // ================================================================
        //  3 iterations per seed, each with new random parameters
        // ================================================================
        for (int iter = 0; iter < 3; iter++) begin
            // Random CMP: msb masked to keep values in safe range
            ctcmp = (($urandom) & 32'h7FFFFFFF) % 80 + 20;   // 20~99
            ttcmp = (($urandom) & 32'h7FFFFFFF) % 200 + 50;  // 50~249
            wtcmp = (($urandom) & 32'h7FFFFFFF) % 150 + 100;  // 100~249
            // PSC: cycle through 0(raw), 1, 5, 9 for each iteration
            psc = (iter == 0) ? 0 : (iter == 1) ? 1 : (iter == 2) ? 5 : 9;
            tick_ns = (psc > 0) ? 125 * (psc + 1) : 125;

            env.reg_block.CCPS.write(st, (psc << 16) | (psc > 0 ? 1 : 0), UVM_FRONTDOOR, env.reg_block.reg_map);

            // Shuffle channel order each iteration
            if (iter == 0) begin
                ch_order[0]=0; ch_order[1]=1; ch_order[2]=2; ch_order[3]=3;
                z_order[0]=0;  z_order[1]=1;
            end else if (iter == 1) begin
                ch_order[0]=2; ch_order[1]=0; ch_order[2]=3; ch_order[3]=1;
                z_order[0]=1;  z_order[1]=0;
            end else begin
                ch_order[0]=1; ch_order[1]=3; ch_order[2]=0; ch_order[3]=2;
                z_order[0]=0;  z_order[1]=1;
            end

            `uvm_info("TLC", $sformatf("Iter%0d: TTCMP=%0d CTCMP=%0d WTCMP=%0d PSC=%0d tick=%0dns",
                iter, ttcmp, ctcmp, wtcmp, psc, tick_ns), UVM_NONE)

            // ================================================================
            //  TOGGLE + CLEAR — each channel: Toggle first, then Clear
            // ================================================================
            for (int ci = 0; ci < 4; ci++) begin
                ch = ch_order[ci];
                `uvm_info("TLC", $sformatf("--- Toggle ch%0d TTCMP=%0d ---", ch, ttcmp), UVM_HIGH)

                env.reg_block.EOyC[ch].write(st, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map); // CLR
                #(tick_ns * 10);
                env.reg_block.EOyTTCMP[ch].write(st, ttcmp, UVM_FRONTDOOR, env.reg_block.reg_map);
                env.reg_block.EOyC[ch].write(st, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map); // CLR
                #(tick_ns * 10);
                env.reg_block.EOyS[ch].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
                env.reg_block.EOyTTC[ch].write(st, 32'h1, UVM_FRONTDOOR, env.reg_block.reg_map); // TTE=1
                #(tick_ns * ttcmp / 3);
                env.reg_block.EOyTTCNT[ch].read(st, rp, UVM_FRONTDOOR, env.reg_block.reg_map);
                if (rp == 0)
                    `uvm_error("TLC", $sformatf("[T-ch%0d] TTCNT=0 — NOT counting!", ch))
                #(tick_ns * ttcmp / 3);
                env.reg_block.EOyTTCNT[ch].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
                if (rd == rp)
                    `uvm_error("TLC", $sformatf("[T-ch%0d] TTCNT stalled", ch))
                env.reg_block.EOyTTC[ch].write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map); // stop

                `uvm_info("TLC", $sformatf("--- Clear ch%0d CTCMP=%0d ---", ch, ctcmp), UVM_HIGH)

                env.reg_block.EOyCTCMP[ch].write(st, ctcmp, UVM_FRONTDOOR, env.reg_block.reg_map);
                env.reg_block.EOyC[ch].write(st, 32'h0001_0000, UVM_FRONTDOOR, env.reg_block.reg_map); // CTE=1
                inject_error(8, 2);
                #(tick_ns * 10);
                env.reg_block.EOyCTCNT[ch].read(st, rp, UVM_FRONTDOOR, env.reg_block.reg_map);
                #(tick_ns * ctcmp / 3);
                env.reg_block.EOyCTCNT[ch].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
                if (rd <= rp)
                    `uvm_error("TLC", $sformatf("[C-ch%0d] CTCNT not INC: %0d->%0d", ch, rp, rd))
                // Poll for timeout
                for (int retry = 0; retry < 20; retry++) begin
                    #(tick_ns * ctcmp / 5);
                    env.reg_block.EOyS[ch].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
                    if (rd[16] == 1'b0) break;
                end
                env.reg_block.EOyC[ch].write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map); // CTE=0
                for (int j = 0; j < 9; j++)
                    env.reg_block.ESSC[j].write(st, 32'hFFFF_FFFF, UVM_FRONTDOOR, env.reg_block.reg_map);
                #(tick_ns * 10);
                env.reg_block.EOyC[ch].write(st, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map); // CLR
            end

            // ================================================================
            //  WAIT TIMER — z=0 then z=1 (sequential, no cross-STP)
            // ================================================================
            for (int zi = 0; zi < 2; zi++) begin
                int z = z_order[zi];
                `uvm_info("TLC", $sformatf("--- Wait z%0d WTCMP=%0d ---", z, wtcmp), UVM_HIGH)

                env.reg_block.WTzC[z].write(st, 32'h0001_0000, UVM_FRONTDOOR, env.reg_block.reg_map); // STP
                for (int j = 0; j < 9; j++)
                    env.reg_block.ESSC[j].write(st, 32'hFFFF_FFFF, UVM_FRONTDOOR, env.reg_block.reg_map);
                #(tick_ns * 10);

                cfg_erc(8, 3'h2); // LPI0
                env.reg_block.WTzCMP[z].write(st, wtcmp, UVM_FRONTDOOR, env.reg_block.reg_map);
                env.reg_block.WTzSE[z].write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map); // LPI0=1
                env.reg_block.WTzC[z].write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map); // WTE=1
                env.reg_block.WTzC[z].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
                `uvm_info("TLC", $sformatf("[W-z%0d] WTzC rdback=0x%08h", z, rd), UVM_HIGH)

                inject_error(8, 2);
                #(tick_ns * 10);
                env.reg_block.WTzS[z].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
                if (rd[0] != 1'b1)
                    `uvm_error("TLC", $sformatf("[W-z%0d] WTS=%0b — NOT started!", z, rd[0]))
                env.reg_block.WTzCNT[z].read(st, rp, UVM_FRONTDOOR, env.reg_block.reg_map);
                #(tick_ns * wtcmp / 4);
                env.reg_block.WTzCNT[z].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
                if (rd <= rp)
                    `uvm_error("TLC", $sformatf("[W-z%0d] WTCNT not INC: %0d->%0d", z, rp, rd))
                // Wait for timeout
                #(tick_ns * wtcmp * 2);
                env.reg_block.WTzS[z].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
                if (rd[0] == 1'b1)
                    `uvm_error("TLC", $sformatf("[W-z%0d] WTS still 1 — NOT stopped", z))

                env.reg_block.WTzC[z].write(st, 32'h0001_0000, UVM_FRONTDOOR, env.reg_block.reg_map); // STP
                cfg_erc(8, 3'h0);
                for (int j = 0; j < 9; j++)
                    env.reg_block.ESSC[j].write(st, 32'hFFFF_FFFF, UVM_FRONTDOOR, env.reg_block.reg_map);
            end
        end

        // ================================================================
        //  Write-protect (once per seed, at end)
        // ================================================================
        `uvm_info("TLC", "=== Write-Protect ===", UVM_NONE)
        // CTS=1 blocks CLR
        env.reg_block.EOyCTCMP[0].write(st, 32'h0000_00C8, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.EOyC[0].write(st, 32'h0001_0000, UVM_FRONTDOOR, env.reg_block.reg_map);
        inject_error(8, 2);
        #5000;
        env.reg_block.EOyC[0].write(st, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map);
        #2000;
        env.reg_block.EOyS[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("TLC", $sformatf("[WProt] CTS=1 CLR: EOS=%0b (expect 1)", rd[0]), UVM_MEDIUM)
        #40000;
        env.reg_block.EOyC[0].write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map);
        for (int j = 0; j < 9; j++)
            env.reg_block.ESSC[j].write(st, 32'hFFFF_FFFF, UVM_FRONTDOOR, env.reg_block.reg_map);

        // WTE=1 blocks CMP write
        env.reg_block.WTzCMP[0].write(st, 32'h0000_0050, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.WTzSE[0].write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.WTzC[0].write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.WTzCMP[0].write(st, 32'h0000_00FF, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.WTzCMP[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("TLC", $sformatf("[WProt] WTE=1 CMP write: 0x%04h (expect 0x50)", rd), UVM_MEDIUM)
        env.reg_block.WTzC[0].write(st, 32'h0001_0000, UVM_FRONTDOOR, env.reg_block.reg_map);

        // CMP=1 forbidden
        env.reg_block.WTzC[0].write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.WTzCMP[0].write(st, 32'h1, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.WTzCMP[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("TLC", $sformatf("[WProt] CMP=1: 0x%04h (expect !=1)", rd), UVM_MEDIUM)

        // TTE=1 blocks TTCMP write
        env.reg_block.EOyC[0].write(st, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map); // CLR
        #2000;
        env.reg_block.EOyTTCMP[0].write(st, 32'h0000_0014, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.EOyTTC[0].write(st, 32'h1, UVM_FRONTDOOR, env.reg_block.reg_map);
        #3000;
        env.reg_block.EOyTTCMP[0].write(st, 32'h0000_00FF, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.EOyTTCMP[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("TLC", $sformatf("[WProt] TTE=1 TTCMP write: 0x%04h (expect 0x14)", rd), UVM_MEDIUM)
        env.reg_block.EOyTTC[0].write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map);

        // Cleanup
        env.reg_block.CCPS.write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map);
        for (int j = 0; j < 9; j++)
            env.reg_block.ESSC[j].write(st, 32'hFFFF_FFFF, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.EGC.write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map);

        `uvm_info("TLC", "=== ERMU Timer Lifecycle Test End ===", UVM_NONE)
        phase.drop_objection(this);
    endtask

    task cfg_erc(int src_id, bit [2:0] erc);
        uvm_status_e st; int p, e; bit [31:0] val;
        p = src_id / 8; e = src_id % 8;
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

endclass : ermu_timer_lifecycle_test
