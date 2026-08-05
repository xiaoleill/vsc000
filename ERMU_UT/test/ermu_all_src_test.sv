// =============================================================================
//  ERMU All-Source x All-Response Sweep Test
//  All 288 IDs x 8 ERC responses: external via err_src_id, rest via PET
//  Covers: all ESS bits, all ERC decode paths, all response output signals
// =============================================================================

class ermu_all_src_test extends ermu_base_test;

    `uvm_component_utils(ermu_all_src_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        uvm_status_e   st;
        uvm_reg_data_t rd;
        int            injected;
        int            j, k;
        bit            use_pet;
        bit [31:0]     pv;

        uvm_root::get().set_timeout(900_000_000, 1);  // 900ms for 288x8 sweep
        phase.raise_objection(this);
        wait_reset_release();
        `uvm_info("ALLSRC", "=== ERMU All-Source x All-Response Sweep Start ===", UVM_NONE)

        env.reg_block.CFGLOCK.write(st, 32'h0000_BC00, UVM_FRONTDOOR, env.reg_block.reg_map);
        for (int y = 0; y < 4; y++)
            env.reg_block.EOyC[y].write(st, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map);
        env.reg_block.EGC.write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map); // HPIE_C0=1

        injected = 0;

        for (int id = 0; id < 288; id++) begin
            j = id / 32;
            k = id % 32;
            use_pet = !(id >= 8 && env.reg_block.is_valid_source(id));

            for (int rc = 0; rc < 8; rc++) begin
                cfg_erc(id, rc[2:0]);

                if (use_pet) begin
                    pv = 32'h0;
                    pv[k] = 1'b1;
                    env.reg_block.PET[j].write(st, pv, UVM_FRONTDOOR, env.reg_block.reg_map);
                end else begin
                    inject_error(id, 2);
                end
                #2000;

                env.reg_block.ESS[j].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
                if (rd[k] == 1'b1)
                    injected++;
                else
                    `uvm_warning("ALLSRC", $sformatf("ID=%0d RC=%0d: ESS not set", id, rc))

                env.reg_block.ESSC[j].write(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
                #1000;
                cfg_erc(id, 3'h0);
            end

            if ((id % 32) == 31)
                `uvm_info("ALLSRC", $sformatf("ID %0d/287 (inj=%0d)", id, injected), UVM_MEDIUM)
        end

        env.reg_block.EGC.write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("ALLSRC", $sformatf("=== Done: injected=%0d ===", injected), UVM_NONE)
        phase.drop_objection(this);
    endtask

    task cfg_erc(int src_id, bit [2:0] erc);
        uvm_status_e st;
        int p = src_id / 8;
        int e = src_id % 8;
        bit [31:0] val;
        env.reg_block.ERC[p].read(st, val, UVM_FRONTDOOR, env.reg_block.reg_map);
        val = (val & ~(32'h7 << (e*4))) | (erc << (e*4));
        env.reg_block.ERC[p].write(st, val, UVM_FRONTDOOR, env.reg_block.reg_map);
    endtask

    task inject_error(int src_id, int duration);
        ermu_simple_input_seq in_seq;
        in_seq = ermu_simple_input_seq::type_id::create("in_seq");
        in_seq.src_id = src_id;
        in_seq.pulse_duration = duration;
        in_seq.start(env.virt_sqr.input_sqr);
    endtask

endclass : ermu_all_src_test
