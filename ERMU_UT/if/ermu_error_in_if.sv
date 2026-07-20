// =============================================================================
//  ERMU Error Source Input Interface
//  280 external error source signals: err_src_id[279:0]
//  ID mapping: err_src_id[i] → real error ID = i + 8 (driver handles offset)
//    err_src_id[0]   → ID=8  (WDT0_ERR) → ESS0[8]
//    err_src_id[279] → ID=287           → ESS8[31]
//  Internal errors ID 0~7 (WT timeout, reserved) are NOT on this bus
// =============================================================================

interface ermu_error_in_if(input logic clk_hrc);

    // ---- 284-bit external error source bus ----
    logic [283:0]  err_src_id;

    // ---- Clocking block for driver ----
    clocking driver_cb @(posedge clk_hrc);
        default input #1step output #1ns;
        output err_src_id;
    endclocking : driver_cb

    // ---- Clocking block for monitor ----
    clocking monitor_cb @(posedge clk_hrc);
        default input #1step;
        input err_src_id;
    endclocking : monitor_cb

    // ---- Modports ----
    modport master_mp (clocking driver_cb);
    modport monitor_mp(clocking monitor_cb);

endinterface : ermu_error_in_if
