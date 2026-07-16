// =============================================================================
//  ERMU APB-like Peripheral Bus Interface
//  Note: uses `pready`, includes `pstrb` and `pslverr`
//  DUT only supports Word (32-bit) write: pstrb must be 4'b1111
// =============================================================================

interface ermu_apb_if(input logic pclk);

    // ---- APB signals ----
    logic [11:0]  paddr;
    logic [31:0]  pwdata;
    logic [31:0]  prdata;
    logic         pwrite;
    logic         psel;
    logic         penable;
    logic [3:0]   pstrb;
    logic         pready;
    logic         pslverr;

    // ---- Clocking block for driver (master) ----
    clocking driver_cb @(posedge pclk);
        default input #1step output #1ns;
        output paddr, pwdata, pwrite, psel, penable, pstrb;
        input  prdata, pready, pslverr;
    endclocking : driver_cb

    // ---- Clocking block for monitor ----
    clocking monitor_cb @(posedge pclk);
        default input #1step;
        input paddr, pwdata, prdata, pwrite, psel, penable, pstrb, pready, pslverr;
    endclocking : monitor_cb

    // ---- Modports ----
    modport master_mp (clocking driver_cb);
    modport monitor_mp(clocking monitor_cb);

    // ---- Assertion: Word-only access ----
    // When psel & penable & pwrite, pstrb should be 4'b1111
    property word_write_only;
        @(posedge pclk) (psel && penable && pwrite) |-> (pstrb == 4'b1111);
    endproperty : word_write_only

    assert_word_write: assert property(word_write_only)
        else $warning("[APB_IF] Non-word write detected! pstrb = %0b", pstrb);

endinterface : ermu_apb_if
