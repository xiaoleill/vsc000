// =============================================================================
//  ERMU Input Monitor — Passively monitors error source bus
// =============================================================================

class ermu_input_monitor extends uvm_monitor;

    `uvm_component_utils(ermu_input_monitor)

    virtual ermu_error_in_if  vif;
    uvm_analysis_port #(ermu_input_transaction) input_analysis_port;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        input_analysis_port = new("input_analysis_port", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual ermu_error_in_if)::get(this, "", "err_in_vif", vif))
            `uvm_fatal("INPUT_MON", "Virtual error input interface not found")
    endfunction

    task run_phase(uvm_phase phase);
        forever begin
            @(vif.monitor_cb);
            if (vif.monitor_cb.err_src_id != 284'h0) begin
                ermu_input_transaction tx;
                tx = ermu_input_transaction::type_id::create("tx");
                // Find which bit(s) are set
                // err_src_id[i] → real error ID = i + 8
                for (int i = 0; i < 284; i++) begin
                    if (vif.monitor_cb.err_src_id[i]) begin
                        tx.src_id = i + 8;  // map to real error ID
                        tx.err_src_mask = vif.monitor_cb.err_src_id;
                        `uvm_info("INPUT_MON", $sformatf("Observed error src %0d", i), UVM_HIGH)
                        input_analysis_port.write(tx);
                    end
                end
            end
        end
    endtask

endclass : ermu_input_monitor
