// =============================================================================
//  ERMU Clock & Reset Interface
//  Dual clock domain: pclk (APB bus) + clk_hrc (timer counter)
//  All resets are ACTIVE HIGH
// =============================================================================

interface ermu_clk_rst_if;

    // ---- Clocks ----
    logic        pclk;              // APB bus clock
    logic        clk_hrc;           // Counter clock (HRC = 8MHz typical)

    // ---- Resets (all active HIGH) ----
    logic        rst_pvs_s;         // Power-on & voltage detect reset
    logic        rst_pss_h2_s;      // Power-on / system / standby reset
    logic        rst_h2_s;          // Application reset

endinterface : ermu_clk_rst_if
