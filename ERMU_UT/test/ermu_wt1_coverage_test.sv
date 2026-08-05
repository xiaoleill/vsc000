// =============================================================================
//  ERMU Wait Timer 1 Coverage Balancer — Mirror WT0 scenarios on WT1
// =============================================================================

class ermu_wt1_coverage_test extends ermu_base_test;

    `uvm_component_utils(ermu_wt1_coverage_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        uvm_status_e   st;
        uvm_reg_data_t rd;
        int            z, src_id;

        phase.raise_objection(this);
        wait_reset_release();
        `uvm_info("WT1COV", "=== ERMU WT1 Coverage Test Start ===", UVM_NONE)

        env.reg_block.CFGLOCK.write(st, 32'h0000_BC00, UVM_FRONTDOOR, env.reg_block.reg_map);
        for (int y = 0; y < 4; y++)
            env.reg_block.EOyC[y].write(st, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.EGC.write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map);

        z = 1;  // always WT1

        // ---- LPI0 trigger WT1 ----
        `uvm_info("WT1COV", "--- 1. LPI0 trigger ---", UVM_NONE)
        cfg_single(8, 3'h2);
        env.reg_block.WTzCMP[z].write(st, 32'h0000_0064, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.WTzSE[z].write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map); // LPI0=1
        env.reg_block.WTzC[z].write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map); // WTE=1
        inject_error(8, 3);
        #30000;
        env.reg_block.WTzS[z].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("WT1COV", $sformatf("WT1S after LPI0: 0x%08h", rd), UVM_MEDIUM);
        env.reg_block.WTzC[z].write(st, 32'h0001_0000, UVM_FRONTDOOR, env.reg_block.reg_map); // STP
        cfg_single(8, 3'h0);

        // ---- HPI trigger WT1 ----
        `uvm_info("WT1COV", "--- 2. HPI trigger ---", UVM_NONE)
        cfg_single(16, 3'h5);
        env.reg_block.WTzCMP[z].write(st, 32'h0000_0064, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.WTzSE[z].write(st, 32'h0001_0000, UVM_FRONTDOOR, env.reg_block.reg_map); // HPI0=1
        env.reg_block.WTzC[z].write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map);
        inject_error(16, 3);
        #30000;
        env.reg_block.WTzS[z].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("WT1COV", $sformatf("WT1S after HPI: 0x%08h", rd), UVM_MEDIUM);
        env.reg_block.WTzC[z].write(st, 32'h0001_0000, UVM_FRONTDOOR, env.reg_block.reg_map);
        cfg_single(16, 3'h0);

        // ---- LPI0+LPI1+LPI2 all enabled ----
        `uvm_info("WT1COV", "--- 3. All LPI enable bits ---", UVM_NONE)
        cfg_single(8, 3'h3); // LPI1
        env.reg_block.WTzCMP[z].write(st, 32'h0000_0064, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.WTzSE[z].write(st, 32'h0000_0007, UVM_FRONTDOOR, env.reg_block.reg_map); // LPI0+LPI1+LPI2
        env.reg_block.WTzC[z].write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map);
        inject_error(8, 3);
        #30000;
        env.reg_block.WTzS[z].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.WTzC[z].write(st, 32'h0001_0000, UVM_FRONTDOOR, env.reg_block.reg_map);
        cfg_single(8, 3'h0);

        // ---- Write CMP while WTE=1 (ignored) ----
        `uvm_info("WT1COV", "--- 4. Write CMP when WTE=1 ---", UVM_NONE)
        env.reg_block.WTzCMP[z].write(st, 32'h0000_0050, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.WTzSE[z].write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.WTzC[z].write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map); // WTE=1
        env.reg_block.WTzCMP[z].write(st, 32'h0000_00FF, UVM_FRONTDOOR, env.reg_block.reg_map); // should be ignored
        env.reg_block.WTzCMP[z].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("WT1COV", $sformatf("WT1CMP after write while WTE=1: 0x%08h (expect 0x50)", rd), UVM_MEDIUM);
        env.reg_block.WTzC[z].write(st, 32'h0001_0000, UVM_FRONTDOOR, env.reg_block.reg_map);

        // ---- WTzCNT read during counting ----
        `uvm_info("WT1COV", "--- 5. CNT read during counting ---", UVM_NONE)
        cfg_single(8, 3'h2);
        env.reg_block.WTzCMP[z].write(st, 32'h0000_00C8, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.WTzSE[z].write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.WTzC[z].write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map);
        inject_error(8, 3);
        #5000;
        env.reg_block.WTzCNT[z].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("WT1COV", $sformatf("WT1CNT: 0x%08h", rd), UVM_MEDIUM);
        env.reg_block.WTzC[z].write(st, 32'h0001_0000, UVM_FRONTDOOR, env.reg_block.reg_map);
        cfg_single(8, 3'h0);

        // ---- CMP=1 forbidden ----
        `uvm_info("WT1COV", "--- 6. CMP=1 forbidden ---", UVM_NONE)
        env.reg_block.WTzC[z].write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map); // WTE=0
        env.reg_block.WTzCMP[z].write(st, 32'h1, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.WTzCMP[z].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("WT1COV", $sformatf("WT1CMP after write 1: 0x%08h (expect !=1)", rd), UVM_MEDIUM);

        // Cleanup
        for (int j = 0; j < 9; j++)
            env.reg_block.ESSC[j].write(st, 32'hFFFF_FFFF, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.EGC.write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map);

        `uvm_info("WT1COV", "=== ERMU WT1 Coverage Test End ===", UVM_NONE)
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

endclass : ermu_wt1_coverage_test
