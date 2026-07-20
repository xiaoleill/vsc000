// =============================================================================
//  ERMU Input Driver — Drives error source signals to DUT
// =============================================================================

class ermu_input_driver extends uvm_driver #(ermu_input_transaction);

    `uvm_component_utils(ermu_input_driver)

    virtual ermu_error_in_if  vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual ermu_error_in_if)::get(this, "", "err_in_vif", vif))
            `uvm_fatal("INPUT_DRV", "Virtual error input interface not found")
    endfunction

    task run_phase(uvm_phase phase);
        // Initialize to 0
        vif.driver_cb.err_src_id <= 284'h0;
        forever begin
            ermu_input_transaction tx;
            seq_item_port.get_next_item(tx);
            `uvm_info("INPUT_DRV", $sformatf("Driving: %s", tx.convert2string()), UVM_HIGH)
            drive_error(tx);
            seq_item_port.item_done();
        end
    endtask

    // err_src_id[i] maps to real error ID = i + 8
    //   err_src_id[0]   → ID=8  (WDT0_ERR) → ESS0[8]
    //   err_src_id[279] → ID=287            → ESS8[31]
    //   IDs 0~7 are internal (WT timeout); cannot be injected externally
    localparam int ERR_ID_OFFSET = 8;
    localparam int ERR_ID_MAX    = 287;   // last external ID
    localparam int ERR_ID_MIN    = 8;     // first external ID

    task drive_error(ermu_input_transaction tx);
        int ext_index = tx.src_id - ERR_ID_OFFSET;
        if (ext_index < 0 || ext_index > (ERR_ID_MAX - ERR_ID_MIN)) begin
            `uvm_error("INPUT_DRV", $sformatf(
                "src_id=%0d cannot be externally injected (range: %0d~%0d). Use PET for internal IDs.",
                tx.src_id, ERR_ID_MIN, ERR_ID_MAX))
            return;
        end
        vif.driver_cb.err_src_id[ext_index] <= 1'b1;
        repeat(tx.pulse_duration) @(vif.driver_cb);
        vif.driver_cb.err_src_id[ext_index] <= 1'b0;
    endtask

endclass : ermu_input_driver
