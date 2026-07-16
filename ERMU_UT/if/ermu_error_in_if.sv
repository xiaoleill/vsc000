// =============================================================================
//  ERMU Error Source Input Interface
//  284 external error source signals: err_src_id[283:0]
//  Internal WT errors (ID 284~287) are generated inside DUT
//  Asserting err_src_id[i]=1 indicates error source i is active
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
