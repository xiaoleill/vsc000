// =============================================================================
//  ERMU Stress Test — Deep random with ERROR checks on every operation
// =============================================================================

class ermu_stress_test extends ermu_base_test;

    `uvm_component_utils(ermu_stress_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        uvm_status_e   st;
        uvm_reg_data_t rd, rp;
        int            op, src_id, erc_val, rnd, ch, zr, si, om, mv;

        uvm_root::get().set_timeout(900_000_000, 1);
        phase.raise_objection(this);
        wait_reset_release();
        `uvm_info("STRESS", "=== ERMU Deep Random Stress Start ===", UVM_NONE)

        env.reg_block.CFGLOCK.write(st, 32'h0000_BC00, UVM_FRONTDOOR, env.reg_block.reg_map);
        for (int y = 0; y < 4; y++)
            env.reg_block.EOyC[y].write(st, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.EGC.write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map);

        for (int iter = 0; iter < 200; iter++) begin
            op = ((($urandom) & 32'h7FFFFFFF) % 100) + 0;

            // ================================================================
            //  40% — Error injection: verify ESS set + clear
            // ================================================================
            if (op < 40) begin
                src_id = ((($urandom) & 32'h7FFFFFFF) % 288) + 0;
                erc_val = ((($urandom) & 32'h7FFFFFFF) % 8) + 0;
                cfg_single(src_id, erc_val[2:0]);
                if (src_id >= 8 && env.reg_block.is_valid_source(src_id))
                    inject_error(src_id, ((($urandom) & 32'h7FFFFFFF) % 10) + 1);
                else
                    pet_inject(src_id);
                #(((($urandom) & 32'h7FFFFFFF) % 4001) + 1000);
                // Verify ESS bit set before clearing
                env.reg_block.ESS[src_id/32].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
                if (rd[src_id%32] != 1'b1)
                    `uvm_error("STRESS", $sformatf("[INJ] ID=%0d ESS not set! ESS%0d=0x%08h", src_id, src_id/32, rd))
                env.reg_block.ESSC[src_id/32].write(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
                cfg_single(src_id, 3'h0);
            end

            // ================================================================
            //  15% — Clear Timer: inject error→CTCNT inc→poll CTS→cleanup
            // ================================================================
            else if (op < 55) begin
                ch = ((($urandom) & 32'h7FFFFFFF) % 4) + 0;
                env.reg_block.EOyCTCMP[ch].write(st, ((($urandom) & 32'h7FFFFFFF) % 252) + 4, UVM_FRONTDOOR, env.reg_block.reg_map);
                env.reg_block.EOyC[ch].write(st, 32'h0001_0000, UVM_FRONTDOOR, env.reg_block.reg_map); // CTE=1
                inject_error(8, 2);
                #5000;
                env.reg_block.EOyCTCNT[ch].read(st, rp, UVM_FRONTDOOR, env.reg_block.reg_map);
                #(((($urandom) & 32'h7FFFFFFF) % 10001) + 5000);
                env.reg_block.EOyCTCNT[ch].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
                if (rd <= rp)
                    `uvm_error("STRESS", $sformatf("[Clear-ch%0d] CTCNT not INC: %0d->%0d", ch, rp, rd))
                // Poll CTS
                for (int retry = 0; retry < 10; retry++) begin
                    #5000;
                    env.reg_block.EOyS[ch].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
                    if (rd[16] == 1'b0) break;
                end
                if (rd[16] != 1'b0)
                    `uvm_error("STRESS", $sformatf("[Clear-ch%0d] CTS still 1 — timer not expired", ch))
                env.reg_block.EOyC[ch].write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map);
                env.reg_block.ESSC[0].write(st, 32'hFFFF_FFFF, UVM_FRONTDOOR, env.reg_block.reg_map);
            end

            // ================================================================
            //  15% — Toggle Timer: stop any timer→CLR→TTCMP→CLR→TTE=1→TTCNT>0→stop
            // ================================================================
            else if (op < 70) begin
                ch = ((($urandom) & 32'h7FFFFFFF) % 4) + 0;
                // Kill any running clear timer on this channel
                env.reg_block.EOyC[ch].write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map); // CTE=0
                // Poll until CTS=0 (max ~50us)
                for (int retry = 0; retry < 20; retry++) begin
                    env.reg_block.EOyS[ch].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
                    if (rd[16] == 1'b0) break;
                    #2000;
                end
                // Clean ESS, then CLR → EOS=0
                for (int j = 0; j < 9; j++)
                    env.reg_block.ESSC[j].write(st, 32'hFFFF_FFFF, UVM_FRONTDOOR, env.reg_block.reg_map);
                env.reg_block.EOyC[ch].write(st, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map); // CLR
                #2000;
                // TTCMP>0 + TTE=1 → toggle starts when EOS=0
                env.reg_block.EOyTTCMP[ch].write(st, ((($urandom) & 32'h7FFFFFFF) % 255) + 1, UVM_FRONTDOOR, env.reg_block.reg_map);
                env.reg_block.EOyC[ch].write(st, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map); // CLR → EOS=0 → toggle starts
                #2000;
                env.reg_block.EOyTTC[ch].write(st, 32'h1, UVM_FRONTDOOR, env.reg_block.reg_map); // TTE=1
                // Verify EOS=0 before waiting
                env.reg_block.EOyS[ch].read(st, rp, UVM_FRONTDOOR, env.reg_block.reg_map);
                #(((($urandom) & 32'h7FFFFFFF) % 10001) + 5000);
                env.reg_block.EOyTTCNT[ch].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
                if (rd == 0)
                    `uvm_error("STRESS", $sformatf("[Toggle-ch%0d] TTCNT=0 EOS=%0b CTS=%0b — NOT counting!", ch, rp[0], rp[16]))
                env.reg_block.EOyTTC[ch].write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map);
            end

            // ================================================================
            //  10% — Wait Timer: config→trigger→verify WTS/WTCNT→stop
            // ================================================================
            else if (op < 80) begin
                zr = ((($urandom) & 32'h7FFFFFFF) % 2) + 0;
                si = ((($urandom) & 32'h7FFFFFFF) % 288) + 0;
                erc_val = ((($urandom) & 32'h7FFFFFFF) % 4) + 2; // LPI or HPI
                if (si >= 8 && env.reg_block.is_valid_source(si)) begin
                    cfg_single(si, erc_val[2:0]);
                    env.reg_block.WTzCMP[zr].write(st, ((($urandom) & 32'h7FFFFFFF) % 197) + 4, UVM_FRONTDOOR, env.reg_block.reg_map);
                    env.reg_block.WTzSE[zr].write(st, ((($urandom) & 32'h7FFFFFFF) % 8) + 0 | (((($urandom) & 32'h7FFFFFFF) % 8) + 0 << 16), UVM_FRONTDOOR, env.reg_block.reg_map);
                    env.reg_block.WTzC[zr].write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map); // WTE=1
                    inject_error(si, ((($urandom) & 32'h7FFFFFFF) % 5) + 1);
                    #5000;
                    // Verify WTS
                    env.reg_block.WTzS[zr].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
                    if (rd[0] != 1'b1)
                        `uvm_error("STRESS", $sformatf("[Wait-z%0d] WTS=%0b — NOT started!", zr, rd[0]))
                    // Verify WTCNT > 0
                    env.reg_block.WTzCNT[zr].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
                    if (rd == 0)
                        `uvm_error("STRESS", $sformatf("[Wait-z%0d] WTCNT=0", zr))
                    #(((($urandom) & 32'h7FFFFFFF) % 10001) + 5000);
                    env.reg_block.WTzC[zr].write(st, 32'h0001_0000, UVM_FRONTDOOR, env.reg_block.reg_map); // STP
                    cfg_single(si, 3'h0);
                    rd_ess_and_clear(si);
                end
            end

            // ================================================================
            //  5% — Output Mask: write→read→verify→restore
            // ================================================================
            else if (op < 85) begin
                ch = ((($urandom) & 32'h7FFFFFFF) % 4) + 0;
                om = ((($urandom) & 32'h7FFFFFFF) % 9) + 0;
                mv = (($urandom) & 32'h7FFFFFFF);
                env.reg_block.EOyOM[ch][om].write(st, mv, UVM_FRONTDOOR, env.reg_block.reg_map);
                #1000;
                env.reg_block.EOyOM[ch][om].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
                if (rd != mv)
                    `uvm_error("STRESS", $sformatf("[OM] ch%0d[%0d] write 0x%08h read 0x%08h", ch, om, mv, rd))
                env.reg_block.EOyOM[ch][om].write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map);
            end

            // ================================================================
            //  5% — EMS: enable→set→verify EMSS→clear→verify
            // ================================================================
            else if (op < 90) begin
                env.reg_block.EMSC.write(st, 32'h0001_0000, UVM_FRONTDOOR, env.reg_block.reg_map); // EMSEN=1
                #1000;
                env.reg_block.EMSC.write(st, 32'h0001_0001, UVM_FRONTDOOR, env.reg_block.reg_map); // EMSEN+EMSSET
                #2000;
                env.reg_block.EMSS.read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
                if (rd[0] != 1'b1)
                    `uvm_error("STRESS", $sformatf("[EMS] EMSS=%0b after SET — expect 1", rd[0]))
                env.reg_block.EMSC.write(st, 32'h0001_0002, UVM_FRONTDOOR, env.reg_block.reg_map); // EMSCLR
                #2000;
                env.reg_block.EMSS.read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
                if (rd[0] != 1'b0)
                    `uvm_error("STRESS", $sformatf("[EMS] EMSS=%0b after CLR — expect 0", rd[0]))
                env.reg_block.EMSC.write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map);
            end

            // ================================================================
            //  5% — CCPS: random PSC→write→read→verify→restore
            // ================================================================
            else if (op < 95) begin
                rnd = (((($urandom) & 32'h7FFFFFFF) % 256) + 0 << 16) | 32'h1; // PSC + PSE=1
                env.reg_block.CCPS.write(st, rnd, UVM_FRONTDOOR, env.reg_block.reg_map);
                #1000;
                env.reg_block.CCPS.read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
                // Verify PSC field preserved (ignore reserved bits)
                if ((rd & 32'h00FF_0000) != (rnd & 32'h00FF_0000))
                    `uvm_error("STRESS", $sformatf("[CCPS] write 0x%08h read 0x%08h", rnd, rd))
                env.reg_block.CCPS.write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map);
            end

            // ================================================================
            //  5% — Register sweep: read ESS, EOS, EGC
            // ================================================================
            else begin
                for (int j = 0; j < 9; j++) begin
                    env.reg_block.ESS[j].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
                    if (rd != 32'h0)
                        env.reg_block.ESSC[j].write(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
                end
                ch = ((($urandom) & 32'h7FFFFFFF) % 4) + 0;
                env.reg_block.EOyS[ch].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
                env.reg_block.EGC.read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
            end

            // CFGLOCK toggle every 30 iterations
            if ((iter % 30) == 0 && iter > 0) begin
                env.reg_block.CFGLOCK.write(st, 32'h0000_0000, UVM_FRONTDOOR, env.reg_block.reg_map);
                #100;
                env.reg_block.CFGLOCK.write(st, 32'h0000_BC00, UVM_FRONTDOOR, env.reg_block.reg_map);
            end

            if ((iter % 25) == 0)
                `uvm_info("STRESS", $sformatf("Iter %0d/200", iter), UVM_MEDIUM)
        end

        // Final cleanup
        for (int j = 0; j < 9; j++) begin
            env.reg_block.ESS[j].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
            if (rd != 32'h0) env.reg_block.ESSC[j].write(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
            env.reg_block.ERC[j].write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map);
        end
        for (int y = 0; y < 4; y++) begin
            env.reg_block.EOyC[y].write(st, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map);
            for (int m = 0; m < 9; m++)
                env.reg_block.EOyOM[y][m].write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map);
        end
        env.reg_block.WTzC[0].write(st, 32'h0001_0000, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.WTzC[1].write(st, 32'h0001_0000, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.EGC.write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map);

        `uvm_info("STRESS", "=== ERMU Deep Random Stress End ===", UVM_NONE)
        phase.drop_objection(this);
    endtask

    task cfg_single(int src_id, bit [2:0] erc);
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

    task pet_inject(int src_id);
        uvm_status_e st; int j, k; bit [31:0] pv;
        j = src_id / 32; k = src_id % 32;
        pv = 32'h0; pv[k] = 1'b1;
        env.reg_block.PET[j].write(st, pv, UVM_FRONTDOOR, env.reg_block.reg_map);
    endtask

    task rd_ess_and_clear(int src_id);
        uvm_status_e st; uvm_reg_data_t rd;
        int j = src_id / 32;
        env.reg_block.ESS[j].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        if (rd != 32'h0)
            env.reg_block.ESSC[j].write(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
    endtask

endclass : ermu_stress_test
