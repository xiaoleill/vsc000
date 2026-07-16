// =============================================================================
//  APB Driver — Standard APB protocol implementation
//
//  APB transfer timing (each step = 1 pclk cycle):
//    IDLE  → SETUP (psel=1, penable=0) 1 cycle
//          → ACCESS (penable=1)         1+ cycles (wait for pready)
//          → IDLE  (psel=0, penable=0)
//
//  Clock edge sequence within drive_transaction:
//    E0: psel<=1, penable<=0 (SETUP drive) → @(cb)
//    E1: penable<=1 (ACCESS drive)         → @(cb) → pready check
//    E2+: wait for pready=1                → @(cb) each cycle
//    Capture: pready=1 at current edge     → read prdata
//    Cleanup: psel<=0, penable<=0          → @(cb)
// =============================================================================

class apb_driver extends uvm_driver #(apb_transaction);

    `uvm_component_utils(apb_driver)

    virtual ermu_apb_if  vif;
    apb_agent_cfg        cfg;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual ermu_apb_if)::get(this, "", "apb_vif", vif))
            `uvm_fatal("APB_DRV", "Virtual APB interface not found in config_db")
        if (!uvm_config_db #(apb_agent_cfg)::get(this, "", "apb_cfg", cfg))
            `uvm_fatal("APB_DRV", "APB agent config not found in config_db")
    endfunction

    task run_phase(uvm_phase phase);
        vif.driver_cb.psel    <= 1'b0;
        vif.driver_cb.penable <= 1'b0;
        @(vif.driver_cb);

        forever begin
            apb_transaction tx;
            seq_item_port.get_next_item(tx);
            `uvm_info("APB_DRV", $sformatf("Driving: %s", tx.convert2string()), UVM_HIGH)
            drive_transaction(tx);
            seq_item_port.item_done();
        end
    endtask

    // ---- Standard APB transfer: SETUP → ACCESS (+wait) → IDLE ----
    task drive_transaction(apb_transaction tx);
        // ---- Sync to clock edge (critical for 1st transaction after idle) ----
        @(vif.driver_cb);

        // ============================================================
        //  E0: SETUP phase (psel=1, penable=0)
        // ============================================================
        vif.driver_cb.psel    <= 1'b1;
        vif.driver_cb.penable <= 1'b0;
        vif.driver_cb.paddr   <= tx.paddr;
        vif.driver_cb.pwdata  <= tx.pwdata;
        vif.driver_cb.pwrite  <= tx.pwrite;
        vif.driver_cb.pstrb   <= (tx.pwrite) ? 4'b1111 : tx.pstrb;
        @(vif.driver_cb);
        //  Between E0 and E1: psel=1, penable=0 (SETUP visible on bus)

        // ============================================================
        //  E1: ACCESS phase begins (penable=1)
        // ============================================================
        vif.driver_cb.penable <= 1'b1;
        @(vif.driver_cb);
        //  penable is now 1 on bus. DUT may assert pready immediately
        //  (zero wait) or keep it low (wait states).

        // ============================================================
        //  E2+: Wait for pready
        // ============================================================
        while (vif.driver_cb.pready !== 1'b1)
            @(vif.driver_cb);

        // ---- pready=1 at the edge just passed → capture read data ----
        if (!tx.pwrite) begin
            tx.prdata  = vif.driver_cb.prdata;
            tx.pslverr = vif.driver_cb.pslverr;
        end

        // ============================================================
        //  Return to IDLE
        // ============================================================
        vif.driver_cb.psel    <= 1'b0;
        vif.driver_cb.penable <= 1'b0;
        @(vif.driver_cb);

        `uvm_info("APB_DRV",
                  $sformatf("Done: paddr=0x%03h %s data=0x%08h",
                            tx.paddr, tx.pwrite ? "WR" : "RD",
                            tx.pwrite ? tx.pwdata : tx.prdata),
                  UVM_DEBUG)
    endtask

endclass : apb_driver
