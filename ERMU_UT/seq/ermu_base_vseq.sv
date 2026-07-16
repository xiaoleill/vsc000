// =============================================================================
//  ERMU Base Virtual Sequence
//  Handles CFGLOCK unlock + EOS clear. body() calls init_ermu().
//  Start on the virtual sequencer: base_seq.start(virt_sqr);
// =============================================================================

class ermu_base_vseq extends uvm_sequence;

    `uvm_object_utils(ermu_base_vseq)

    ermu_reg_block    reg_block;
    ermu_env_cfg      env_cfg;

    function new(string name = "ermu_base_vseq");
        super.new(name);
    endfunction

    // ---- Load handles from config_db before body() ----
    task pre_body();
        if (reg_block == null) begin
            if (!uvm_config_db #(ermu_reg_block)::get(null, "", "reg_block", reg_block))
                `uvm_fatal("BASE_VSEQ", "Register block not found in config_db")
        end
        if (env_cfg == null) begin
            if (!uvm_config_db #(ermu_env_cfg)::get(null, "", "env_cfg", env_cfg))
                `uvm_fatal("BASE_VSEQ", "Environment config not found in config_db")
        end
    endtask

    // ---- Main body: called by start() ----
    task body();
        init_ermu();
    endtask

    // ---- Unlock CFGLOCK ----
    task unlock_cfglock();
        uvm_status_e    status;
        uvm_reg_data_t  val;
        `uvm_info("BASE_VSEQ", "Unlocking CFGLOCK (write key=0xBC)...", UVM_MEDIUM)
        reg_block.CFGLOCK.write(status, 32'h0000_BC00, UVM_FRONTDOOR, reg_block.reg_map);
        reg_block.CFGLOCK.read(status, val, UVM_FRONTDOOR, reg_block.reg_map);
        if (val[0] == 1'b1)
            `uvm_error("BASE_VSEQ", "CFGLOCK unlock failed")
        else
            `uvm_info("BASE_VSEQ", "CFGLOCK unlocked", UVM_MEDIUM)
    endtask

    // ---- Clear EOS on all 4 channels (default = 1 after reset) ----
    task clear_all_eos();
        uvm_status_e status;
        `uvm_info("BASE_VSEQ", "Clearing EOS on all channels...", UVM_MEDIUM)
        for (int y = 0; y < 4; y++) begin
            reg_block.EOyC[y].write(status, 32'h0000_0002, UVM_FRONTDOOR, reg_block.reg_map);
        end
        #1000;
    endtask

    // ---- Standard init: unlock + clear EOS ----
    task init_ermu();
        unlock_cfglock();
        clear_all_eos();
    endtask

endclass : ermu_base_vseq
