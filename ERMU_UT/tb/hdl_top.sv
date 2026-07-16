// =============================================================================
//  ERMU UVM Testbench — Top Level
//  Contains: DUT + interfaces + clock/reset generation + UVM entry (run_test)
//  ALL interfaces instantiated ONCE here; UVM agents get virtual IF via config_db
// =============================================================================

// ---- Interfaces (compiled once via compile_ermu.f) ----
// Defined in: ../if/ermu_clk_rst_if.sv, etc.

module hdl_top;

    import uvm_pkg::*;
    import ermu_test_pkg::*;
    import ermu_env_pkg::*;
    import ermu_seq_pkg::*;

    // ---- Parameters ----
    localparam CLK_PCLK_PERIOD   = 10000;  // pclk 100MHz  = 10ns
    localparam CLK_HRC_PERIOD    = 125000; // clk_hrc 8MHz  = 125ns
    localparam RESET_HOLD_CYCLES = 10;

    // =====================================================================
    //  Interface Instantiations (ONLY place — shared by DUT and UVM)
    // =====================================================================
    ermu_clk_rst_if    clk_rst_if();
    ermu_apb_if        apb_if     (.pclk(clk_rst_if.pclk));
    ermu_error_in_if   err_in_if  (.clk_hrc(clk_rst_if.clk_hrc));
    ermu_error_out_if  err_out_if (.clk_hrc(clk_rst_if.clk_hrc));

    // =====================================================================
    //  Clock Generation
    // =====================================================================
    initial begin
        clk_rst_if.pclk = 1'b0;
        forever #(CLK_PCLK_PERIOD/2) clk_rst_if.pclk = ~clk_rst_if.pclk;
    end

    initial begin
        clk_rst_if.clk_hrc = 1'b0;
        forever #(CLK_HRC_PERIOD/2) clk_rst_if.clk_hrc = ~clk_rst_if.clk_hrc;
    end

    // =====================================================================
    //  Reset Generation (All Active HIGH)
    // =====================================================================
    initial begin
        clk_rst_if.rst_pvs_s    = 1'b1;
        clk_rst_if.rst_pss_h2_s = 1'b1;
        clk_rst_if.rst_h2_s     = 1'b1;
        repeat(RESET_HOLD_CYCLES) @(posedge clk_rst_if.pclk);
        clk_rst_if.rst_pvs_s    = 1'b0;
        clk_rst_if.rst_pss_h2_s = 1'b0;
        clk_rst_if.rst_h2_s     = 1'b0;
    end

    // =====================================================================
    //  DUT Instantiation
    // =====================================================================
    ermu #(
        .EONUM    (4),
        .ERNUM    (288),
        .IMP_EMS  (1),
        .CCPS_BW  (8),
        .Z_NUM    (2),
        .N_NUM    (2),
        .AW       (12),
        .DW       (32)
    ) u_dut (
        .mdc_dftm_a  (1'b0),
        .scan_mode   (1'b0),
        .scan_clk    (1'b0),

        .paddr       (apb_if.paddr),
        .pwdata      (apb_if.pwdata),
        .prdata      (apb_if.prdata),
        .pwrite      (apb_if.pwrite),
        .psel        (apb_if.psel),
        .penable     (apb_if.penable),
        .pstrb       (apb_if.pstrb),
        .pready      (apb_if.pready),
        .pslverr     (apb_if.pslverr),
        .pclk        (clk_rst_if.pclk),

        .clk_hrc     (clk_rst_if.clk_hrc),
        .rst_pvs_s   (clk_rst_if.rst_pvs_s),
        .rst_pss_h2_s(clk_rst_if.rst_pss_h2_s),
        .rst_h2_s    (clk_rst_if.rst_h2_s),

        .emsp_in     (4'b0000),
        .ems_event   (err_out_if.ems_event),
        .pssr_o      (err_out_if.pssr_o),

        .eoutm_o     (err_out_if.eoutm_o),
        .eoutc_o     (err_out_if.eoutc_o),
        .hpi_irq_o   (err_out_if.hpi_irq_o),
        .lpi_irq_o   (err_out_if.lpi_irq_o),
        .srst_req_o  (err_out_if.srst_req_o),
        .arst_req_o  (err_out_if.arst_req_o),
        .status_o    (err_out_if.status_o),

        .err_src_id  (err_in_if.err_src_id)
    );

    // =====================================================================
    //  UVM Entry: set virtual interfaces → run_test
    // =====================================================================
    initial begin
        uvm_config_db #(virtual ermu_clk_rst_if)  ::set(null, "*", "clk_rst_vif", clk_rst_if);
        uvm_config_db #(virtual ermu_apb_if)      ::set(null, "*", "apb_vif",      apb_if);
        uvm_config_db #(virtual ermu_error_in_if)  ::set(null, "*", "err_in_vif",   err_in_if);
        uvm_config_db #(virtual ermu_error_out_if) ::set(null, "*", "err_out_vif",  err_out_if);
        run_test();
    end

endmodule : hdl_top
