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

    task drive_error(ermu_input_transaction tx);
        // Pulse the specific error source bit
        vif.driver_cb.err_src_id[tx.src_id] <= 1'b1;
        repeat(tx.pulse_duration) @(vif.driver_cb);
        vif.driver_cb.err_src_id[tx.src_id] <= 1'b0;
    endtask

endclass : ermu_input_driver
