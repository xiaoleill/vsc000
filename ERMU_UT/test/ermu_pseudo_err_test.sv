// =============================================================================
//  ERMU Pseudo Error Test — PET pseudo error trigger verification
// =============================================================================

class ermu_pseudo_err_test extends ermu_base_test;

    `uvm_component_utils(ermu_pseudo_err_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        uvm_status_e   st;
        uvm_reg_data_t rd;
        int            test_sources[7];  // pre-declared for xrun compatibility

        phase.raise_objection(this);
        wait_reset_release();
        `uvm_info("PSEUDO", "=== ERMU Pseudo Error Test Start ===", UVM_NONE)

        env.reg_block.CFGLOCK.write(st, 32'h0000_BC00, UVM_FRONTDOOR, env.reg_block.reg_map);

        // Test PET on boundary sources: 0, 31, 32, 63, 283 (last external)
        test_sources[0] = 0; test_sources[1] = 31; test_sources[2] = 32;
        test_sources[3] = 63; test_sources[4] = 100; test_sources[5] = 200;
        test_sources[6] = 283;
        for (int ii = 0; ii < 7; ii++) begin
            int src = test_sources[ii];
            int j = src / 32;
            int k = src % 32;
            bit [31:0] pet_val = 32'h0;

            `uvm_info("PSEUDO", $sformatf("--- PET source %0d (ESS%0d[%0d]) ---", src, j, k), UVM_MEDIUM)
            pet_val[k] = 1'b1;
            env.reg_block.PET[j].write(st, pet_val, UVM_FRONTDOOR, env.reg_block.reg_map);
            #5000;

            env.reg_block.ESS[j].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
            if (rd[k] == 1'b1)
                `uvm_info("PSEUDO", $sformatf("PET src=%0d: ESS bit set OK", src), UVM_HIGH)
            else
                `uvm_error("PSEUDO", $sformatf("PET src=%0d: ESS bit NOT set!", src))

            env.reg_block.ESSC[j].write(st, 32'hFFFF_FFFF, UVM_FRONTDOOR, env.reg_block.reg_map);
            #2000;
        end

        // Test PET write 0 does not trigger
        `uvm_info("PSEUDO", "--- PET write 0 (no trigger) ---", UVM_NONE)
        env.reg_block.PET[0].write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map);
        #5000;
        env.reg_block.ESS[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        if (rd == 32'h0)
            `uvm_info("PSEUDO", "PET write 0: no ESS trigger OK", UVM_NONE)
        else
            `uvm_error("PSEUDO", $sformatf("PET write 0 should not trigger ESS! got 0x%08h", rd))

        // Test PET read returns 0 (WO)
        `uvm_info("PSEUDO", "--- PET read returns 0 (WO) ---", UVM_NONE)
        env.reg_block.PET[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("PSEUDO", $sformatf("PET0 read: 0x%08h (expect 0)", rd), UVM_MEDIUM);

        `uvm_info("PSEUDO", "=== ERMU Pseudo Error Test End ===", UVM_NONE)
        phase.drop_objection(this);
    endtask

endclass : ermu_pseudo_err_test
