// =============================================================================
//  ERMU Stress Test — Randomized stress with multiple seeds
// =============================================================================

class ermu_stress_test extends ermu_base_test;

    `uvm_component_utils(ermu_stress_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        uvm_status_e   st;
        uvm_reg_data_t rd;
        int            seed, src_id, erc_val, erc_idx;

        phase.raise_objection(this);
        wait_reset_release();
        `uvm_info("STRESS", "=== ERMU Stress Test Start ===", UVM_NONE)

        env.reg_block.CFGLOCK.write(st, 32'h0000_BC00, UVM_FRONTDOOR, env.reg_block.reg_map);
        for (int y = 0; y < 4; y++)
            env.reg_block.EOyC[y].write(st, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map);

        // Enable HPI for mixed response testing
        env.reg_block.EGC.write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map); // HPIE_C0=1

        // ====================================================================
        //  Random error injection loop (100 iterations)
        // ====================================================================
        for (int iter = 0; iter < 100; iter++) begin
            src_id = ($random + iter * 173) % 280 + 8;  // valid external IDs: 8~287
            erc_idx = ($random + iter) % 5;
            erc_val = (erc_idx == 0) ? 0 : (erc_idx == 1) ? 2 :
                      (erc_idx == 2) ? 3 : (erc_idx == 3) ? 4 : 5;

            // Configure random source with random ERC
            env.reg_block.ERC[src_id/8].write(st, erc_val << ((src_id % 8) * 4), UVM_FRONTDOOR, env.reg_block.reg_map);

            // Inject error
            inject_error(src_id, ($random % 10) + 1);

            // Random delay
            #(($random % 1000) + 100);

            // Occasionally read ESS and clear
            if ((iter % 10) == 0) begin
                for (int j = 0; j < 9; j++) begin
                    env.reg_block.ESS[j].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
                    if (rd != 32'h0) begin
                        env.reg_block.ESSC[j].write(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
                    end
                end
            end

            // Occasionally toggle CFGLOCK
            if ((iter % 25) == 0) begin
                env.reg_block.CFGLOCK.write(st, 32'h0000_0000, UVM_FRONTDOOR, env.reg_block.reg_map); // lock
                #100;
                env.reg_block.CFGLOCK.write(st, 32'h0000_BC00, UVM_FRONTDOOR, env.reg_block.reg_map); // unlock
            end

            if ((iter % 20) == 0)
                `uvm_info("STRESS", $sformatf("Iteration %0d/100", iter), UVM_MEDIUM);
        end

        // ====================================================================
        //  Cleanup and final check
        // ====================================================================
        `uvm_info("STRESS", "--- Cleanup all ESS ---", UVM_NONE)

        for (int j = 0; j < 9; j++) begin
            env.reg_block.ESS[j].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
            if (rd != 32'h0) begin
                env.reg_block.ESSC[j].write(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
            end
            // Reset all ERC
            env.reg_block.ERC[j].write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map);
        end

        env.reg_block.EGC.write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map);

        // Final sanity: read CFGLOCK
        env.reg_block.CFGLOCK.read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("STRESS", $sformatf("Final CFGLOCK: 0x%08h", rd), UVM_MEDIUM);

        `uvm_info("STRESS", "=== ERMU Stress Test End ===", UVM_NONE)
        phase.drop_objection(this);
    endtask

    task inject_error(int src_id, int duration);
        ermu_simple_input_seq in_seq;
        in_seq = ermu_simple_input_seq::type_id::create("in_seq");
        in_seq.src_id = src_id;
        in_seq.pulse_duration = duration;
        in_seq.start(env.virt_sqr.input_sqr);
    endtask

endclass : ermu_stress_test
