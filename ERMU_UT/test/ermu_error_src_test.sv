// =============================================================================
//  ERMU Error Source Test — Inject key error sources, verify ESSj + response
//  288 sources: sample boundaries + per-category representatives
// =============================================================================

class ermu_error_src_test extends ermu_base_test;

    `uvm_component_utils(ermu_error_src_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        uvm_status_e   st;
        uvm_reg_data_t rd;
        int src_ids[];
        ermu_simple_input_seq in_seq;

        phase.raise_objection(this);
        wait_reset_release();
        `uvm_info("ERR_SRC", "=== ERMU Error Source Test Start ===", UVM_NONE)

        // ---- Init ----
        env.reg_block.CFGLOCK.write(st, 32'h0000_BC00, UVM_FRONTDOOR, env.reg_block.reg_map);
        for (int y = 0; y < 4; y++)
            env.reg_block.EOyC[y].write(st, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map);

        // ---- Configure all sources to LPI0 response ----
        for (int p = 0; p < 36; p++)
            env.reg_block.ERC[p].write(st, {8{3'h2}}, UVM_FRONTDOOR, env.reg_block.reg_map);

        // ---- Select test sources: valid (implemented) IDs only ----
        //   Must have physical err_src_id bus pin
        src_ids = '{
            8, 12,              // first external, WDT/IWDT boundary
            16, 27,             // CSU range
            64, 65,             // ESS2 first valid (TPU0-1)
            72, 81, 82, 90,     // ESS2: SPU, PPU, DPU1
            96, 100, 104,       // ESS3: PFU, DFU, SRAMC
            108, 112, 116,      // ESS3: CREC, FREC, ETH
            128, 132, 136, 143, // ESS4: MREC, EMS, SBUS, DMA0
            160, 175, 191,      // ESS5: SFC boundaries
            192, 203,           // ESS6: SFC range
            256, 262,           // ESS8: Processor0
            272, 278            // ESS8: Processor1
        };

        // Guard: filter out any reserved IDs
        for (int ii = 0; ii < src_ids.size(); ii++) begin
            if (!env.reg_block.is_valid_source(src_ids[ii])) begin
                `uvm_error("ERR_SRC", $sformatf("ID=%0d is RESERVED (no bus pin)!", src_ids[ii]))
                src_ids[ii] = 8;  // fallback to first valid
            end
        end

        `uvm_info("ERR_SRC", $sformatf("Testing %0d error sources...", src_ids.size()), UVM_NONE)

        foreach (src_ids[i]) begin
            int id = src_ids[i];
            int g = id / 32;
            int k = id % 32;

            // Inject error
            in_seq = ermu_simple_input_seq::type_id::create("in_seq");
            in_seq.src_id = id;
            in_seq.pulse_duration = 5;
            in_seq.start(env.virt_sqr.input_sqr);
            #5000;

            // Verify ESS status (with reserved-bit mask)
            env.reg_block.ESS[g].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
            check_ess_masked(g, k, rd);

            // Clear error
            env.reg_block.ESSC[g].write(st, 32'h1 << k, UVM_FRONTDOOR, env.reg_block.reg_map);
            #1000;

            // Verify cleared
            env.reg_block.ESS[g].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
            if (rd[k] != 1'b0)
                `uvm_warning("ERR_SRC", $sformatf("ID=%0d: ESS not cleared!", id))
        end

        `uvm_info("ERR_SRC", "=== ERMU Error Source Test End ===", UVM_NONE)
        phase.drop_objection(this);
    endtask

endclass : ermu_error_src_test
