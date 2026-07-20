// =============================================================================
//  ERMU Output Channel Test — 4-channel independent & parallel operation
// =============================================================================

class ermu_output_chan_test extends ermu_base_test;

    `uvm_component_utils(ermu_output_chan_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        uvm_status_e   st;
        uvm_reg_data_t rd;

        phase.raise_objection(this);
        wait_reset_release();
        `uvm_info("OCHAN", "=== ERMU Output Channel Test Start ===", UVM_NONE)

        env.reg_block.CFGLOCK.write(st, 32'h0000_BC00, UVM_FRONTDOOR, env.reg_block.reg_map);
        for (int y = 0; y < 4; y++)
            env.reg_block.EOyC[y].write(st, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map);

        // ====================================================================
        //  Test: Each channel independently sets/clears EOS
        // ====================================================================
        `uvm_info("OCHAN", "--- Independent EOS control ---", UVM_NONE)

        // Channel 0: SET, Channel 1: CLR, Channel 2: SET, Channel 3: CLR
        env.reg_block.EOyC[0].write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map); // SET ch0
        env.reg_block.EOyC[2].write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map); // SET ch2
        #2000;

        for (int y = 0; y < 4; y++) begin
            env.reg_block.EOyS[y].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
            `uvm_info("OCHAN", $sformatf("Ch%0d: EO%0dS=0x%08h", y, y, rd), UVM_MEDIUM);
        end

        // ====================================================================
        //  Test: Independent per-channel error response (different ERC per channel via ESS routing)
        // ====================================================================
        `uvm_info("OCHAN", "--- Error output per channel ---", UVM_NONE)

        // Inject error → all unmasked channels should see it
        inject_error(10, 5);
        #10000;

        for (int y = 0; y < 4; y++) begin
            env.reg_block.EOyS[y].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
            `uvm_info("OCHAN", $sformatf("After error src10: Ch%0d EO%0dS=0x%08h", y, y, rd), UVM_MEDIUM);
        end

        // Cleanup
        env.reg_block.ESSC[0].write(st, 32'hFFFF_FFFF, UVM_FRONTDOOR, env.reg_block.reg_map);
        for (int y = 0; y < 4; y++) begin
            env.reg_block.EOyC[y].write(st, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map); // CLR
        end

        // ====================================================================
        //  Test: Per-channel mask isolation
        // ====================================================================
        `uvm_info("OCHAN", "--- Per-channel mask isolation ---", UVM_NONE)

        // Mask source 20 on ch0 and ch1, but not ch2 and ch3
        env.reg_block.EOyOM[0][0].write(st, 32'h0010_0000, UVM_FRONTDOOR, env.reg_block.reg_map); // ch0 mask src20
        env.reg_block.EOyOM[1][0].write(st, 32'h0010_0000, UVM_FRONTDOOR, env.reg_block.reg_map); // ch1 mask src20

        inject_error(20, 5);
        #10000;

        for (int y = 0; y < 4; y++) begin
            env.reg_block.EOyS[y].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
            `uvm_info("OCHAN", $sformatf("Ch%0d EO%0dS=0x%08h (expect ch0/1 masked, ch2/3 EOS=1)", y, y, rd), UVM_MEDIUM);
        end

        // Cleanup
        env.reg_block.ESSC[0].write(st, 32'hFFFF_FFFF, UVM_FRONTDOOR, env.reg_block.reg_map);
        for (int y = 0; y < 4; y++) begin
            env.reg_block.EOyOM[y][0].write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map);
            env.reg_block.EOyC[y].write(st, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map);
        end

        `uvm_info("OCHAN", "=== ERMU Output Channel Test End ===", UVM_NONE)
        phase.drop_objection(this);
    endtask

    task inject_error(int src_id, int duration);
        ermu_simple_input_seq in_seq;
        in_seq = ermu_simple_input_seq::type_id::create("in_seq");
        in_seq.src_id = src_id;
        in_seq.pulse_duration = duration;
        in_seq.start(env.virt_sqr.input_sqr);
    endtask

endclass : ermu_output_chan_test
