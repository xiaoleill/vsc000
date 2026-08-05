// =============================================================================
//  ERMU Timer Corner Case Test — Coverage gap filler
//  Targets: ch2/ch3 paths, WTzCNT reads, WTzSE multi-HPI, CCPS+timer
// =============================================================================

class ermu_timer_corner_test extends ermu_base_test;

    `uvm_component_utils(ermu_timer_corner_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        uvm_status_e   st;
        uvm_reg_data_t rd;

        phase.raise_objection(this);
        wait_reset_release();
        `uvm_info("TCRNR", "=== ERMU Timer Corner Case Test Start ===", UVM_NONE)

        env.reg_block.CFGLOCK.write(st, 32'h0000_BC00, UVM_FRONTDOOR, env.reg_block.reg_map);
        for (int y = 0; y < 4; y++)
            env.reg_block.EOyC[y].write(st, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.EGC.write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map);

        // ================================================================
        //  1. Clear Timer: ch2 + ch3 independent
        // ================================================================
        `uvm_info("TCRNR", "--- 1. Clear Timer ch2 ---", UVM_NONE)
        env.reg_block.EOyCTCMP[2].write(st, 32'h0000_0032, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.EOyC[2].write(st, 32'h0001_0000, UVM_FRONTDOOR, env.reg_block.reg_map); // CTE=1 (error triggers timer)
        // Trigger counter with error injection
        inject_error(8, 2);
        #10000;
        env.reg_block.EOyS[2].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("TCRNR", $sformatf("Ch2 EO2S=0x%08h", rd), UVM_MEDIUM);
        if (rd[16] == 1'b0) env.reg_block.EOyC[2].write(st, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.EOyC[2].write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map);

        `uvm_info("TCRNR", "--- 1b. Clear Timer ch3 ---", UVM_NONE)
        env.reg_block.EOyCTCMP[3].write(st, 32'h0000_0032, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.EOyC[3].write(st, 32'h0001_0001, UVM_FRONTDOOR, env.reg_block.reg_map);
        #10000;
        env.reg_block.EOyS[3].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("TCRNR", $sformatf("Ch3 EO3S=0x%08h", rd), UVM_MEDIUM);
        if (rd[16] == 1'b0) env.reg_block.EOyC[3].write(st, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.EOyC[3].write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map);

        // ================================================================
        //  2. Toggle Timer: ch2 + ch3
        // ================================================================
        `uvm_info("TCRNR", "--- 2. Toggle Timer ch2 ---", UVM_NONE)
        env.reg_block.EOyC[2].write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map); // SET
        #2000;
        env.reg_block.EOyTTCMP[2].write(st, 32'h0000_0014, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.EOyTTC[2].write(st, 32'h1, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.EOyC[2].write(st, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map); // CLR
        #10000;
        env.reg_block.EOyTTCNT[2].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("TCRNR", $sformatf("Ch2 TTCNT=0x%08h", rd), UVM_MEDIUM);
        env.reg_block.EOyTTC[2].write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map);

        `uvm_info("TCRNR", "--- 2b. Toggle Timer ch3 ---", UVM_NONE)
        env.reg_block.EOyC[3].write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map); // SET
        #2000;
        env.reg_block.EOyTTCMP[3].write(st, 32'h0000_0014, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.EOyTTC[3].write(st, 32'h1, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.EOyC[3].write(st, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map); // CLR
        #10000;
        env.reg_block.EOyTTCNT[3].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("TCRNR", $sformatf("Ch3 TTCNT=0x%08h", rd), UVM_MEDIUM);
        env.reg_block.EOyTTC[3].write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map);

        // ================================================================
        //  3. Wait Timer: read WTzCNT during counting + multi-HPI
        // ================================================================
        `uvm_info("TCRNR", "--- 3. Wait Timer: WTzCNT read + multi-HPI ---", UVM_NONE)
        cfg_single(8, 3'h2);  // LPI0
        cfg_single(16, 3'h5); // HPI
        env.reg_block.WTzCMP[0].write(st, 32'h0000_00C8, UVM_FRONTDOOR, env.reg_block.reg_map);
        // HPI0 + HPI1 + LPI0 all enabled
        env.reg_block.WTzSE[0].write(st, 32'h0003_0001, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.WTzC[0].write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map); // WTE=1
        inject_error(8, 3);  // LPI0 triggers WT
        #5000;
        // Read WTzCNT mid-count
        env.reg_block.WTzCNT[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("TCRNR", $sformatf("WT0CNT mid-count: 0x%08h (expect 0, toggle stopped)", rd), UVM_MEDIUM);
        #30000;
        env.reg_block.WTzC[0].write(st, 32'h0001_0000, UVM_FRONTDOOR, env.reg_block.reg_map); // STP
        cfg_single(8, 3'h0);
        cfg_single(16, 3'h0);

        // ================================================================
        //  4. HPI multi-bit independent trigger
        // ================================================================
        `uvm_info("TCRNR", "--- 4. HPI0+HPI1 both trigger WTz ---", UVM_NONE)
        cfg_single(8, 3'h5); // HPI
        env.reg_block.WTzCMP[0].write(st, 32'h0000_004B, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.WTzSE[0].write(st, 32'h0003_0000, UVM_FRONTDOOR, env.reg_block.reg_map); // HPI0+HPI1
        env.reg_block.WTzC[0].write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map);
        inject_error(8, 3);
        #30000;
        env.reg_block.WTzS[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("TCRNR", $sformatf("WT0S after HPI trigger: 0x%08h", rd), UVM_MEDIUM);
        env.reg_block.WTzC[0].write(st, 32'h0001_0000, UVM_FRONTDOOR, env.reg_block.reg_map);
        cfg_single(8, 3'h0);

        // ================================================================
        //  5. CCPS prescaler + timer interaction
        // ================================================================
        `uvm_info("TCRNR", "--- 5. CCPS PSE=1 + Clear Timer ---", UVM_NONE)
        env.reg_block.CCPS.write(st, 32'h0003_0001, UVM_FRONTDOOR, env.reg_block.reg_map); // PSC=3, PSE=1
        env.reg_block.EOyCTCMP[0].write(st, 32'h0000_0032, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.EOyC[0].write(st, 32'h0001_0001, UVM_FRONTDOOR, env.reg_block.reg_map);
        #20000;
        env.reg_block.EOyS[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("TCRNR", $sformatf("PSE=1 Ch0 EO0S=0x%08h", rd), UVM_MEDIUM);
        if (rd[16] == 1'b0) env.reg_block.EOyC[0].write(st, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.EOyC[0].write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map);

        `uvm_info("TCRNR", "--- 5b. CCPS PSE=1 + Toggle Timer ---", UVM_NONE)
        env.reg_block.EOyC[0].write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map); // SET
        #2000;
        env.reg_block.EOyTTCMP[0].write(st, 32'h0000_0014, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.EOyTTC[0].write(st, 32'h1, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.EOyC[0].write(st, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map); // CLR
        #20000;
        env.reg_block.EOyTTCNT[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("TCRNR", $sformatf("PSE=1 TTCNT=0x%08h", rd), UVM_MEDIUM);
        env.reg_block.EOyTTC[0].write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.CCPS.write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map); // restore

        // Cleanup
        for (int j = 0; j < 9; j++)
            env.reg_block.ESSC[j].write(st, 32'hFFFF_FFFF, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.EGC.write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map);

        `uvm_info("TCRNR", "=== ERMU Timer Corner Case Test End ===", UVM_NONE)
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

endclass : ermu_timer_corner_test
