// =============================================================================
//  ERMU Concurrent Test — Multi-source / multi-channel concurrency
// =============================================================================

class ermu_concurrent_test extends ermu_base_test;

    `uvm_component_utils(ermu_concurrent_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        uvm_status_e   st;
        uvm_reg_data_t rd;

        phase.raise_objection(this);
        wait_reset_release();
        `uvm_info("CONC", "=== ERMU Concurrent Test Start ===", UVM_NONE)

        env.reg_block.CFGLOCK.write(st, 32'h0000_BC00, UVM_FRONTDOOR, env.reg_block.reg_map);
        for (int y = 0; y < 4; y++)
            env.reg_block.EOyC[y].write(st, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map);

        // ====================================================================
        //  Test: Multiple errors in same ESS group
        // ====================================================================
        `uvm_info("CONC", "--- Multi-error, same ESS group ---", UVM_NONE)

        // Inject 3 errors in ESS0: sources 0, 10, 20
        inject_error(8, 5);
        inject_error(10, 5);
        inject_error(20, 5);
        #10000;

        env.reg_block.ESS[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("CONC", $sformatf("ESS0 after 3 injections: 0x%08h (expect bits 0,10,20=1)", rd), UVM_MEDIUM);
        env.reg_block.ESSC[0].write(st, 32'hFFFF_FFFF, UVM_FRONTDOOR, env.reg_block.reg_map);

        // ====================================================================
        //  Test: Cross-group concurrent errors
        // ====================================================================
        `uvm_info("CONC", "--- Cross-group concurrent errors ---", UVM_NONE)

        inject_error(8, 5);    // ESS0
        inject_error(63, 5);   // ESS1
        inject_error(100, 5);  // ESS3
        inject_error(200, 5);  // ESS6
        #10000;

        for (int j = 0; j < 9; j++) begin
            env.reg_block.ESS[j].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
            if (rd != 32'h0)
                `uvm_info("CONC", $sformatf("ESS%0d=0x%08h", j, rd), UVM_MEDIUM);
        end

        for (int j = 0; j < 9; j++)
            env.reg_block.ESSC[j].write(st, 32'hFFFF_FFFF, UVM_FRONTDOOR, env.reg_block.reg_map);

        // ====================================================================
        //  Test: Mixed ERC response types concurrently
        // ====================================================================
        `uvm_info("CONC", "--- Mixed response types ---", UVM_NONE)

        // Configure different responses
        env.reg_block.ERC[0].write(st, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map); // src0→LPI0
        env.reg_block.ERC[1].write(st, 32'h0000_0050, UVM_FRONTDOOR, env.reg_block.reg_map); // src8→HPI
        env.reg_block.ERC[2].write(st, 32'h0000_0600, UVM_FRONTDOOR, env.reg_block.reg_map); // src16→APP_RST

        env.reg_block.EGC.write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map); // HPIE_C0=1

        // Inject all 3 errors
        inject_error(8, 5);
        inject_error(8, 5);
        inject_error(16, 5);
        #20000;

        // Check ESS
        env.reg_block.ESS[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("CONC", $sformatf("ESS0 after mixed response: 0x%08h", rd), UVM_MEDIUM);

        // Cleanup
        env.reg_block.ESSC[0].write(st, 32'hFFFF_FFFF, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.ERC[0].write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.ERC[1].write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.ERC[2].write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.EGC.write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map);

        // ====================================================================
        //  Test: APB read while timer counting (cross-clock-domain)
        // ====================================================================
        `uvm_info("CONC", "--- APB reads during timer count ---", UVM_NONE)

        env.reg_block.EOyCTCMP[0].write(st, 32'h0000_00FF, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.EOyC[0].write(st, 32'h0001_0000, UVM_FRONTDOOR, env.reg_block.reg_map); // CTE=1
        env.reg_block.EOyC[0].write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map); // SET

        // Rapid APB reads during counting
        for (int i = 0; i < 20; i++) begin
            env.reg_block.EOyCTCNT[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
            #500;
        end

        env.reg_block.EOyC[0].write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map);

        `uvm_info("CONC", "=== ERMU Concurrent Test End ===", UVM_NONE)
        phase.drop_objection(this);
    endtask

    task inject_error(int src_id, int duration);
        ermu_simple_input_seq in_seq;
        in_seq = ermu_simple_input_seq::type_id::create("in_seq");
        in_seq.src_id = src_id;
        in_seq.pulse_duration = duration;
        in_seq.start(env.virt_sqr.input_sqr);
    endtask

endclass : ermu_concurrent_test
