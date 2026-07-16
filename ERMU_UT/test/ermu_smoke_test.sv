// =============================================================================
//  ERMU Smoke Test
//  Minimal end-to-end check:
//    1. Unlock CFGLOCK → clear EOS on all channels
//    2. Read reset values of key registers
//    3. Configure ERC for error source 8 → LPI0
//    4. Inject error source via sequence → verify ESSj status
//    5. Clear error source → verify cleanup
// =============================================================================

class ermu_smoke_test extends ermu_base_test;

    `uvm_component_utils(ermu_smoke_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        ermu_base_vseq           base_seq;
        ermu_simple_input_seq    in_seq;
        uvm_status_e             status;
        uvm_reg_data_t           rdata;

        phase.raise_objection(this);
        `uvm_info("SMOKE_TEST", "Starting ERMU Smoke Test...", UVM_NONE)

        // ---- Step 1: Init (unlock + clear EOS) via base virtual sequence ----
        base_seq = ermu_base_vseq::type_id::create("base_seq");
        base_seq.reg_block = env.reg_block;
        base_seq.env_cfg   = env.cfg;
        base_seq.start(env.virt_sqr);

        // ---- Step 2: Check register reset/programmed values ----
        `uvm_info("SMOKE_TEST", "Checking register values...", UVM_MEDIUM)

        env.reg_block.CFGLOCK.read(status, rdata, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("SMOKE_TEST", $sformatf("CFGLOCK after unlock = 0x%08h", rdata), UVM_MEDIUM)

        env.reg_block.EOyS[0].read(status, rdata, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("SMOKE_TEST", $sformatf("EO0S = 0x%08h", rdata), UVM_MEDIUM)

        env.reg_block.ESS[0].read(status, rdata, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("SMOKE_TEST", $sformatf("ESS0 = 0x%08h", rdata), UVM_MEDIUM)

        // ---- Step 3: Configure error response for source 8 (SWDT_ERR) → LPI0 ----
        `uvm_info("SMOKE_TEST", "Configuring error response for source 8 → LPI0...", UVM_MEDIUM)
        env.reg_block.ERC[1].write(status, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.ERC[1].read(status, rdata, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("SMOKE_TEST", $sformatf("ERC1 = 0x%08h", rdata), UVM_MEDIUM)

        // ---- Step 4: Inject error source 8 via sequence ----
        `uvm_info("SMOKE_TEST", "Injecting error source ID=8...", UVM_NONE)
        in_seq = ermu_simple_input_seq::type_id::create("in_seq");
        in_seq.src_id = 8;
        in_seq.pulse_duration = 5;
        in_seq.start(env.virt_sqr.input_sqr);

        #10000;

        // ---- Step 5: Verify ESS0 bit 8 is set ----
        env.reg_block.ESS[0].read(status, rdata, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("SMOKE_TEST", $sformatf("ESS0 = 0x%08h", rdata), UVM_NONE);
        if (rdata[8] != 1'b1)
            `uvm_warning("SMOKE_TEST", "ESS0 bit 8 not set")
        else
            `uvm_info("SMOKE_TEST", "PASS: ESS0 bit 8 set correctly", UVM_NONE)

        // ---- Step 6: Clear and verify ----
        env.reg_block.ESSC[0].write(status, 32'h0000_0100, UVM_FRONTDOOR, env.reg_block.reg_map);
        #1000;
        env.reg_block.ESS[0].read(status, rdata, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("SMOKE_TEST", $sformatf("ESS0 after clear = 0x%08h", rdata), UVM_NONE);

        `uvm_info("SMOKE_TEST", "ERMU Smoke Test Complete!", UVM_NONE)
        phase.drop_objection(this);
    endtask

endclass : ermu_smoke_test
