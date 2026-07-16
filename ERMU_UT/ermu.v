module ermu
#(
    parameter EONUM   = 4,   // Emergency output number
    parameter ERNUM   = 288, // Error source count
    parameter IMP_EMS = 1,
    parameter CCPS_BW = 8,
    parameter Z_NUM   = 2,
    parameter N_NUM   = 2,
    parameter AW      = 12,  // Address width
    parameter DW      = 32   // Data width
)
(
    // ---- Scan / DFT ----
    input  wire mdc_dftm_a,
    input  wire scan_mode,
    input  wire scan_clk,

    // ---- APB interface ----
    output reg  [DW-1:0] prdata,
    output reg           pready,
    output wire          pslverr,
    input  wire [AW-1:0] paddr,
    input  wire [DW-1:0] pwdata,
    input  wire          pwrite,
    input  wire          psel,
    input  wire          penable,
    input  wire [3:0]    pstrb,
    input  wire          pclk,   // module clock

    // ---- Clock & Reset ----
    input  wire clk_hrc,          // count clock
    input  wire rst_pvs_s,        // power on reset & voltage detect reset, high active
    input  wire rst_pss_h2_s,     // power on reset, system reset, standby reset, high active
    input  wire rst_h2_s,         // application reset, high active

    // ---- Emergency stop ----
    input  wire [3:0] emsp_in,    // emergency stop port input
    output wire       ems_event,  // emergency stop event (error ID 132)
    output wire       pssr_o,     // port safe state request

    // ---- Outputs ----
    output wire [EONUM-1:0] eoutm_o,
    output wire [EONUM-1:0] eoutc_o,
    output wire [N_NUM-1:0] hpi_irq_o,
    output wire [2:0]       lpi_irq_o,
    output wire             srst_req_o,
    output wire             arst_req_o,
    output wire [31:0]      status_o,

    // ---- Error source input ----
    input  wire [ERNUM-5:0] err_src_id
);

    // (Module body not shown in original images)

endmodule
