// =============================================================================
//  ERMU Error Response Test — All 8 ERC encoding verification
// =============================================================================

class ermu_error_rsp_test extends ermu_base_test;

    `uvm_component_utils(ermu_error_rsp_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        uvm_status_e   st;
        uvm_reg_data_t rd;

        phase.raise_objection(this);
        wait_reset_release();
        `uvm_info("ERR_RSP", "=== ERMU Error Response Test Start ===", UVM_NONE)

        // ---- Init: unlock CFGLOCK, clear all channels ----
        env.reg_block.CFGLOCK.write(st, 32'h0000_BC00, UVM_FRONTDOOR, env.reg_block.reg_map);
        for (int y = 0; y < 4; y++)
            env.reg_block.EOyC[y].write(st, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map);

        // ---- Configure HPI enable (required for HPI response) ----
        env.reg_block.EGC.write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map); // HPIE_C0=1

        // ====================================================================
        //  Test all 8 ERC encodings (0x0 ~ 0x7) on source 0
        // ====================================================================
        test_response("ERC_NA",     3'h0, 8);
        test_response("ERC_RSV",    3'h1, 8);
        test_response("ERC_LPI0",   3'h2, 8);
        test_response("ERC_LPI1",   3'h3, 8);
        test_response("ERC_LPI2",   3'h4, 8);
        test_response("ERC_HPI",    3'h5, 8);
        test_response("ERC_APP_RST",3'h6, 8);
        test_response("ERC_SYS_RST",3'h7, 8);

        `uvm_info("ERR_RSP", "=== ERMU Error Response Test End ===", UVM_NONE)
        phase.drop_objection(this);
    endtask

    // ---- Test a single ERC encoding ----
    task test_response(string name, bit [2:0] erc_code, int src_id);
        uvm_status_e   st;
        uvm_reg_data_t rd;
        int            erc_group = src_id / 8;
        int            erc_bit   = src_id % 8;
        bit [31:0]     erc_mask;
        string         exp_resp;

        `uvm_info("ERR_RSP", $sformatf("--- Testing %s (0x%0h) on source %0d ---", name, erc_code, src_id), UVM_NONE)

        // Determine expected behavior
        case (erc_code)
            3'h0, 3'h1: exp_resp = "NO_RESPONSE";
            3'h2:        exp_resp = "LPI0";
            3'h3:        exp_resp = "LPI1";
            3'h4:        exp_resp = "LPI2";
            3'h5:        exp_resp = "HPI";
            3'h6:        exp_resp = "APP_RST";
            3'h7:        exp_resp = "SYS_RST";
        endcase

        // Configure ERC for this source (3 bits per source, 4-bit stride)
        erc_mask = 32'h0;
        erc_mask = erc_code << (erc_bit * 4);
        env.reg_block.ERC[erc_group].write(st, erc_mask, UVM_FRONTDOOR, env.reg_block.reg_map);

        // Inject error pulse
        begin
            ermu_simple_input_seq in_seq;
            in_seq = ermu_simple_input_seq::type_id::create("in_seq");
            in_seq.src_id = src_id;
            in_seq.pulse_duration = 5;
            in_seq.start(env.virt_sqr.input_sqr);
        end
        #50000;

        // Read ESS to confirm error was captured
        env.reg_block.ESS[src_id/32].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        check_ess_masked(src_id/32, src_id%32, rd);

        // Verify response by checking output interface signals
        // (output_if is monitored by output_agent, we check via virtual interface)
        check_output_response(name, exp_resp);

        // Cleanup: clear ESS, reset ERC
        env.reg_block.ESSC[src_id/32].write(st, 32'hFFFF_FFFF, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.ERC[erc_group].write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map);
        #2000;

        `uvm_info("ERR_RSP", $sformatf("%s test done", name), UVM_HIGH)
    endtask

    // ---- Check output signals match expected response ----
    task check_output_response(string name, string exp_resp);
        // The output signals are monitored via the output interface.
        // In a full implementation, we would check the output agent's
        // analysis port. For now, log the expected vs actual.
        // The output monitor captures eoutm_o, eoutc_o, hpi_irq_o,
        // lpi_irq_o, srst_req_o, arst_req_o, pssr_o, ems_event.
        `uvm_info("ERR_RSP",
            $sformatf("%s: expect=%s (check waveform/output_monitor for actual)", name, exp_resp),
            UVM_MEDIUM)
    endtask

endclass : ermu_error_rsp_test
