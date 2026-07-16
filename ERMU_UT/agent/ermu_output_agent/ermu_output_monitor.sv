// =============================================================================
//  ERMU Output Monitor — Passively monitors all ERMU output signals
// =============================================================================

class ermu_output_monitor extends uvm_monitor;

    `uvm_component_utils(ermu_output_monitor)

    virtual ermu_error_out_if  vif;
    uvm_analysis_port #(ermu_output_transaction) output_analysis_port;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        output_analysis_port = new("output_analysis_port", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual ermu_error_out_if)::get(this, "", "err_out_vif", vif))
            `uvm_fatal("OUTPUT_MON", "Virtual error output interface not found")
    endfunction

    task run_phase(uvm_phase phase);
        ermu_output_transaction tx;
        ermu_output_transaction prev_tx;
        prev_tx = null;
        forever begin
            @(vif.monitor_cb);
            tx = ermu_output_transaction::type_id::create("tx");
            tx.eoutm    = vif.monitor_cb.eoutm_o;
            tx.eoutc    = vif.monitor_cb.eoutc_o;
            tx.hpi_irq  = vif.monitor_cb.hpi_irq_o;
            tx.lpi_irq  = vif.monitor_cb.lpi_irq_o;
            tx.srst_req = vif.monitor_cb.srst_req_o;
            tx.arst_req = vif.monitor_cb.arst_req_o;
            tx.pssr     = vif.monitor_cb.pssr_o;
            tx.ems_event = vif.monitor_cb.ems_event;
            tx.status   = vif.monitor_cb.status_o;

            // Publish only when there's a change from previous state
            if (prev_tx == null ||
                tx.eoutm != prev_tx.eoutm || tx.eoutc != prev_tx.eoutc ||
                tx.hpi_irq != prev_tx.hpi_irq || tx.lpi_irq != prev_tx.lpi_irq ||
                tx.srst_req != prev_tx.srst_req || tx.arst_req != prev_tx.arst_req ||
                tx.pssr != prev_tx.pssr || tx.ems_event != prev_tx.ems_event) begin
                `uvm_info("OUTPUT_MON", $sformatf("Change: %s", tx.convert2string()), UVM_HIGH)
                output_analysis_port.write(tx);
            end
            prev_tx = tx;
        end
    endtask

endclass : ermu_output_monitor
