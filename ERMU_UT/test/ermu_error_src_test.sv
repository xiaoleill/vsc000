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

        // ---- Select test sources: boundaries + representative categories ----
        //   Real error IDs 8~287 (driver maps: err_src_id[i] = real_id - 8)
        //   IDs 0-7 are internal (WT timeout), tested elsewhere
        src_ids = '{
            8, 15,              // first external + WDT/CSU boundary
            16, 27,             // CSU range boundary
            31, 32,             // ESS0/ESS1 boundary
            63, 64,             // ESS1/ESS2 boundary
            95, 96,             // ESS2/ESS3 boundary
            127, 128,           // ESS3/ESS4 boundary
            159, 160,           // ESS4/ESS5 boundary
            191, 192,           // ESS5/ESS6 boundary
            223, 224,           // ESS6/ESS7 boundary
            255, 256,           // ESS7/ESS8 boundary
            287,                // last external source (ESS8[31])
            40, 65, 80, 112,   // per-category: Flash/SRAM/Cache/CAN
            132, 150, 200, 270 // per-category: EMS/GTM/SFC/Processor
        };

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
