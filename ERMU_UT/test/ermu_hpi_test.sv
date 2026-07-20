// =============================================================================
//  ERMU HPI Test — High Priority Interrupt routing verification
// =============================================================================

class ermu_hpi_test extends ermu_base_test;

    `uvm_component_utils(ermu_hpi_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        uvm_status_e   st;
        uvm_reg_data_t rd;

        phase.raise_objection(this);
        wait_reset_release();
        `uvm_info("HPI", "=== ERMU HPI Test Start ===", UVM_NONE)

        env.reg_block.CFGLOCK.write(st, 32'h0000_BC00, UVM_FRONTDOOR, env.reg_block.reg_map);
        for (int y = 0; y < 4; y++)
            env.reg_block.EOyC[y].write(st, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map);

        // ====================================================================
        //  Test: HPIE=00 — HPI disabled (no NMI even with HPI response)
        // ====================================================================
        `uvm_info("HPI", "--- HPIE=00 (HPI disabled) ---", UVM_NONE)
        env.reg_block.EGC.write(st, 32'h0000_0000, UVM_FRONTDOOR, env.reg_block.reg_map); // HPIE=00
        env.reg_block.ERC[1].write(st, 32'h0000_0005, UVM_FRONTDOOR, env.reg_block.reg_map); // src8→HPI

        inject_error(8, 5);
        #10000;
        env.reg_block.ESS[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("HPI", $sformatf("HPIE=00: ESS0=0x%08h (error captured, HPI should be silent)", rd), UVM_MEDIUM);
        env.reg_block.ESSC[0].write(st, 32'hFFFF_FFFF, UVM_FRONTDOOR, env.reg_block.reg_map);

        // ====================================================================
        //  Test: HPIE_C0=1 — HPI to Core0 only
        // ====================================================================
        `uvm_info("HPI", "--- HPIE_C0=1 (HPI to Core0) ---", UVM_NONE)
        env.reg_block.EGC.write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map); // HPIE_C0=1

        inject_error(8, 5);
        #10000;
        env.reg_block.ESS[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("HPI", $sformatf("HPIE_C0=1: ESS0=0x%08h (check hpi_irq_o[0]=1)", rd), UVM_MEDIUM);
        env.reg_block.ESSC[0].write(st, 32'hFFFF_FFFF, UVM_FRONTDOOR, env.reg_block.reg_map);

        // ====================================================================
        //  Test: HPIE_C1=1 — HPI to Core1 only
        // ====================================================================
        `uvm_info("HPI", "--- HPIE_C1=1 (HPI to Core1) ---", UVM_NONE)
        env.reg_block.EGC.write(st, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map); // HPIE_C1=1

        inject_error(8, 5);
        #10000;
        env.reg_block.ESS[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("HPI", $sformatf("HPIE_C1=1: ESS0=0x%08h (check hpi_irq_o[1]=1)", rd), UVM_MEDIUM);
        env.reg_block.ESSC[0].write(st, 32'hFFFF_FFFF, UVM_FRONTDOOR, env.reg_block.reg_map);

        // ====================================================================
        //  Test: HPIE=11 — HPI to both cores
        // ====================================================================
        `uvm_info("HPI", "--- HPIE=11 (HPI to both cores) ---", UVM_NONE)
        env.reg_block.EGC.write(st, 32'h0000_0003, UVM_FRONTDOOR, env.reg_block.reg_map); // HPIE=11

        inject_error(8, 5);
        #10000;
        env.reg_block.ESS[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("HPI", $sformatf("HPIE=11: ESS0=0x%08h (check hpi_irq_o[1:0]=11)", rd), UVM_MEDIUM);
        env.reg_block.ESSC[0].write(st, 32'hFFFF_FFFF, UVM_FRONTDOOR, env.reg_block.reg_map);

        // Cleanup
        env.reg_block.EGC.write(st, 32'h0000_0000, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.ERC[0].write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map);

        `uvm_info("HPI", "=== ERMU HPI Test End ===", UVM_NONE)
        phase.drop_objection(this);
    endtask

    task inject_error(int src_id, int duration);
        ermu_simple_input_seq in_seq;
        in_seq = ermu_simple_input_seq::type_id::create("in_seq");
        in_seq.src_id = src_id;
        in_seq.pulse_duration = duration;
        in_seq.start(env.virt_sqr.input_sqr);
    endtask

endclass : ermu_hpi_test
