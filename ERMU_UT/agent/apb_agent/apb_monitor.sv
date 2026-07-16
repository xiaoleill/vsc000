// =============================================================================
//  APB Monitor — Passively monitors APB bus and publishes transactions
//  Captures both read and write transactions on the bus
// =============================================================================

class apb_monitor extends uvm_monitor;

    `uvm_component_utils(apb_monitor)

    virtual ermu_apb_if  vif;
    apb_agent_cfg                   cfg;

    uvm_analysis_port #(apb_transaction) apb_analysis_port;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        apb_analysis_port = new("apb_analysis_port", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual ermu_apb_if)::get(this, "", "apb_vif", vif))
            `uvm_fatal("APB_MON", "Virtual APB interface not found in config_db")
        if (!uvm_config_db #(apb_agent_cfg)::get(this, "", "apb_cfg", cfg))
            `uvm_fatal("APB_MON", "APB agent config not found in config_db")
    endfunction

    task run_phase(uvm_phase phase);
        forever begin
            apb_transaction tx;
            // ---- Wait for a transaction start (psel and penable) ----
            @(vif.monitor_cb);
            if (vif.monitor_cb.psel && vif.monitor_cb.penable && vif.monitor_cb.pready) begin
                tx = apb_transaction::type_id::create("tx");
                tx.paddr   = vif.monitor_cb.paddr;
                tx.pwdata  = vif.monitor_cb.pwdata;
                tx.pwrite  = vif.monitor_cb.pwrite;
                tx.pstrb   = vif.monitor_cb.pstrb;
                tx.pslverr = vif.monitor_cb.pslverr;
                if (!tx.pwrite)
                    tx.prdata = vif.monitor_cb.prdata;

                `uvm_info("APB_MON", $sformatf("Observed: %s", tx.convert2string()), UVM_HIGH)
                apb_analysis_port.write(tx);
            end
        end
    endtask

endclass : apb_monitor
