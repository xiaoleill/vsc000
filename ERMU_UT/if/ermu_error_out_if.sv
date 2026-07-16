// =============================================================================
//  ERMU Error Output Monitoring Interface (passive only)
//  Monitors: EOUTyM/C, HPI/LPI IRQs, reset requests, PSSR, EMS, status
//  No driver — this is a DUT-driven output interface
// =============================================================================

interface ermu_error_out_if(input logic clk_hrc);

    // ---- Error output pins ----
    logic [3:0]   eoutm_o;         // EOUTyM[3:0] master output
    logic [3:0]   eoutc_o;         // EOUTyC[3:0] complementary output

    // ---- Interrupt requests ----
    logic [1:0]   hpi_irq_o;       // High Priority Interrupt [1:0] (NMI)
    logic [2:0]   lpi_irq_o;       // Low Priority Interrupt [2:0]

    // ---- Reset requests ----
    logic         srst_req_o;      // System reset request
    logic         arst_req_o;      // Application reset request

    // ---- Port safe state & emergency stop ----
    logic         pssr_o;          // Port safe state request
    logic         ems_event;       // Emergency stop event (linked to error ID 132)

    // ---- Status output ----
    logic [31:0]  status_o;        // General status output

    // ---- Clocking block for monitor (passive — input only) ----
    clocking monitor_cb @(posedge clk_hrc);
        default input #1step;
        input eoutm_o, eoutc_o, hpi_irq_o, lpi_irq_o,
              srst_req_o, arst_req_o, pssr_o, ems_event, status_o;
    endclocking : monitor_cb

    // ---- Modports ----
    modport monitor_mp(clocking monitor_cb);

endinterface : ermu_error_out_if
