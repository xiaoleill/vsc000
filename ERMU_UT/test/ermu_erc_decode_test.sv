// =============================================================================
//  ERMU ERC Decode Test — Deep coverage of ECpEG decode + LPI/HPI/RSV outputs
//  Targets: ECpEG 13% -> 80%+, LPI/RSV 5% -> 80%+
//  Strategy: sweep all 8 ERC codes across all 8 positions in an ERC register
// =============================================================================

class ermu_erc_decode_test extends ermu_base_test;

    `uvm_component_utils(ermu_erc_decode_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        uvm_status_e   st;
        uvm_reg_data_t rd;
        int            src_base[8];
        int            lpi_srcs[7];
        int            na_srcs[8];
        int            pos, ci, idx, s;
        bit [2:0]      codes[8];
        bit [2:0]      lpi;
        bit [31:0]     erc_val;

        phase.raise_objection(this);
        wait_reset_release();
        `uvm_info("ERCDEC", "=== ERMU ERC Decode Test Start ===", UVM_NONE)

        env.reg_block.CFGLOCK.write(st, 32'h0000_BC00, UVM_FRONTDOOR, env.reg_block.reg_map);
        for (int y = 0; y < 4; y++)
            env.reg_block.EOyC[y].write(st, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map);
        // Enable HPI routing
        env.reg_block.EGC.write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map);

        // ================================================================
        //  1. Sweep all 8 ERC codes at all 8 positions in ERC[0]
        // ================================================================
        `uvm_info("ERCDEC", "--- 1. ERC code x position sweep (ERC[0], 8x8) ---", UVM_NONE)
        codes[0]=3'h0; codes[1]=3'h1; codes[2]=3'h2; codes[3]=3'h3;
        codes[4]=3'h4; codes[5]=3'h5; codes[6]=3'h6; codes[7]=3'h7;
        src_base[0]=8; src_base[1]=9; src_base[2]=10; src_base[3]=11;
        src_base[4]=12; src_base[5]=16; src_base[6]=17; src_base[7]=18;
        for (pos = 0; pos < 8; pos++) begin
            for (ci = 0; ci < 8; ci++) begin
                s = src_base[ci] + pos * 8;
                if (s > 287 || !env.reg_block.is_valid_source(s)) continue;
                erc_val = codes[ci] << (pos * 4);
                env.reg_block.ERC[s/8].write(st, erc_val, UVM_FRONTDOOR, env.reg_block.reg_map);
                inject_error(s, 3);
                #5000;
                env.reg_block.ESS[s/32].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
                env.reg_block.ESSC[s/32].write(st, 32'hFFFF_FFFF, UVM_FRONTDOOR, env.reg_block.reg_map);
                env.reg_block.ERC[s/8].write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map);
            end
        end

        // ================================================================
        //  2. LPI0/1/2 coverage: inject on multiple valid sources
        // ================================================================
        `uvm_info("ERCDEC", "--- 2. LPI0/LPI1/LPI2 on distributed sources ---", UVM_NONE)
        lpi_srcs[0]=8; lpi_srcs[1]=64; lpi_srcs[2]=96; lpi_srcs[3]=128;
        lpi_srcs[4]=160; lpi_srcs[5]=192; lpi_srcs[6]=256;
        for (idx = 0; idx < 7; idx++) begin
            s = lpi_srcs[idx];
            if (!env.reg_block.is_valid_source(s)) continue;
            for (lpi = 3'h2; lpi <= 3'h4; lpi++) begin
                cfg_single(s, lpi);
                inject_error(s, 3);
                #5000;
                env.reg_block.ESS[s/32].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
                env.reg_block.ESSC[s/32].write(st, 32'hFFFF_FFFF, UVM_FRONTDOOR, env.reg_block.reg_map);
                cfg_single(s, 3'h0);
                #1000;
            end
        end

        // ================================================================
        //  3. NA/RSV coverage: exercise the no-response path
        // ================================================================
        `uvm_info("ERCDEC", "--- 3. NA(0x0) and RSV(0x1) sweep ---", UVM_NONE)
        na_srcs[0]=8; na_srcs[1]=16; na_srcs[2]=64; na_srcs[3]=96;
        na_srcs[4]=128; na_srcs[5]=160; na_srcs[6]=192; na_srcs[7]=256;
        for (idx = 0; idx < 8; idx++) begin
            s = na_srcs[idx];
            if (!env.reg_block.is_valid_source(s)) continue;
            // NA
            cfg_single(s, 3'h0);
            inject_error(s, 3);
            #5000;
            env.reg_block.ESS[s/32].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
            env.reg_block.ESSC[s/32].write(st, 32'hFFFF_FFFF, UVM_FRONTDOOR, env.reg_block.reg_map);
            // RSV
            cfg_single(s, 3'h1);
            inject_error(s, 3);
            #5000;
            env.reg_block.ESS[s/32].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
            env.reg_block.ESSC[s/32].write(st, 32'hFFFF_FFFF, UVM_FRONTDOOR, env.reg_block.reg_map);
            cfg_single(s, 3'h0);
        end

        // ================================================================
        //  4. Multi-source LPI concurrency (Multi-source same-LPI concurrency)
        // ================================================================
        `uvm_info("ERCDEC", "--- 4. Multi-source LPI0 concurrency ---", UVM_NONE)
        cfg_single(8, 3'h2);
        cfg_single(16, 3'h2);
        cfg_single(96, 3'h2);
        inject_error(8, 3);
        inject_error(16, 3);
        inject_error(96, 3);
        #10000;
        for (int j = 0; j < 9; j++) begin
            env.reg_block.ESS[j].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
            if (rd != 32'h0)
                env.reg_block.ESSC[j].write(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        end
        cfg_single(8, 3'h0); cfg_single(16, 3'h0); cfg_single(96, 3'h0);

        // ================================================================
        //  5. RSV response should NOT assert any output
        // ================================================================
        `uvm_info("ERCDEC", "--- 5. RSV produces no output ---", UVM_NONE)
        cfg_single(8, 3'h1);
        inject_error(8, 5);
        #10000;
        env.reg_block.ESS[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.ESSC[0].write(st, 32'hFFFF_FFFF, UVM_FRONTDOOR, env.reg_block.reg_map);
        cfg_single(8, 3'h0);

        // Cleanup
        env.reg_block.EGC.write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map);

        `uvm_info("ERCDEC", "=== ERMU ERC Decode Test End ===", UVM_NONE)
        phase.drop_objection(this);
    endtask

    // ---- Write specific ERC code to a single source ----
    task cfg_single(int src_id, bit [2:0] erc);
        uvm_status_e st;
        int p = src_id / 8;
        int e = src_id % 8;
        bit [31:0] val;
        env.reg_block.ERC[p].read(st, val, UVM_FRONTDOOR, env.reg_block.reg_map);
        val = val & ~(32'h7 << (e*4));
        val = val | (erc << (e*4));
        env.reg_block.ERC[p].write(st, val, UVM_FRONTDOOR, env.reg_block.reg_map);
    endtask

    task inject_error(int src_id, int duration);
        ermu_simple_input_seq in_seq;
        in_seq = ermu_simple_input_seq::type_id::create("in_seq");
        in_seq.src_id = src_id;
        in_seq.pulse_duration = duration;
        in_seq.start(env.virt_sqr.input_sqr);
    endtask

endclass : ermu_erc_decode_test
