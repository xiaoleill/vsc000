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

        // ---- Select test sources: boundaries + one per category ----
        src_ids = '{
            0, 1, 2, 3,        // WT errors (internal, but IDs 0-3 are in ESS0)
            8, 9,               // SWDT, WDT
            11,                  // Flash ECC correctable (category boundary)
            19,                  // Last SRAM CERR
            23, 28,              // SRAM FERR first/last
            32, 33,              // Cache ECC
            36, 38, 42, 44,     // CAN ECC (CERR first, FERR first)
            48, 49,              // PKE ECC
            51, 55,              // DMPU bus errors (first/last)
            57, 58,              // DMA errors
            60, 61,              // FPU, FCM
            63, 127, 191, 255,  // Group boundaries
            283                  // Last external source
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

            // Verify ESS status
            env.reg_block.ESS[g].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
            if (rd[k] != 1'b1)
                `uvm_error("ERR_SRC", $sformatf("ID=%0d (group=%0d bit=%0d): ESS not set! ESS[%0d]=0x%08h", id, g, k, g, rd))
            else
                `uvm_info("ERR_SRC", $sformatf("ID=%0d: ESS set OK", id), UVM_HIGH)

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
