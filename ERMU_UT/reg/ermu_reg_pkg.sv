// =============================================================================
//  ERMU UVM Register Package
//  Contains all register class definitions, reg_block, and reg2apb adapter
//  ERMU base address: 0x4006_2000 (C059 TS)
//  288 error sources: 9 ESS/ESSC/PET groups (j=0~8), 36 ERCp groups (p=0~35)
//  Wait timers: 2 (z=0~1), Error outputs: 4 (y=0~3), OM groups: 9 per channel
// =============================================================================

package ermu_reg_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // ==========================================================================
    //  Base Address
    // ==========================================================================
    localparam bit [31:0] ERMU_BASE_ADDR = 32'h4006_2000;

    // ==========================================================================
    //  Register: ERMU_EOyC — Error Output y Control Register
    //  Offset: y × 0x0080   Reset: 0x0000_0000
    // ==========================================================================
    class ermu_eoyc_reg extends uvm_reg;
        `uvm_object_utils(ermu_eoyc_reg)

        rand uvm_reg_field CTE;     // [16] Clear Timer Enable, RW
        rand uvm_reg_field CLR;     // [1]  Clear EOS, WO (read as 0)
        rand uvm_reg_field SET;     // [0]  Set EOS, WO (read as 0)
        uvm_reg_field       RSVD;   // Reserved

        function new(string name = "ermu_eoyc_reg");
            super.new(name, 32, UVM_NO_COVERAGE);
        endfunction

        virtual function void build();
            RSVD = uvm_reg_field::type_id::create("RSVD");
            RSVD.configure(this, 15, 17, "RO", 0, 15'h0, 1, 0, 1);
            CTE  = uvm_reg_field::type_id::create("CTE");
            CTE.configure (this, 1,  16, "RW", 0, 1'b0,  1, 1, 1);
            RSVD = uvm_reg_field::type_id::create("RSVD_15_2");
            RSVD.configure(this, 14, 2,  "RO", 0, 14'h0, 1, 0, 1);
            CLR  = uvm_reg_field::type_id::create("CLR");
            CLR.configure (this, 1,  1,  "WO", 0, 1'b0,  1, 1, 0); // WO: no read
            SET  = uvm_reg_field::type_id::create("SET");
            SET.configure (this, 1,  0,  "WO", 0, 1'b0,  1, 1, 0); // WO: no read
        endfunction
    endclass : ermu_eoyc_reg

    // ==========================================================================
    //  Register: ERMU_EOyS — Error Output y Status Register
    //  Offset: y × 0x0080 + 0x0004   Reset: 0x0000_0001
    // ==========================================================================
    class ermu_eoys_reg extends uvm_reg;
        `uvm_object_utils(ermu_eoys_reg)

        uvm_reg_field CTS;      // [16] Clear Timer Status, RO
        uvm_reg_field EOS;      // [0]  Error Output Status, RO (default=1!)
        uvm_reg_field RSVD;

        function new(string name = "ermu_eoys_reg");
            super.new(name, 32, UVM_NO_COVERAGE);
        endfunction

        virtual function void build();
            RSVD = uvm_reg_field::type_id::create("RSVD_31_17");
            RSVD.configure(this, 15, 17, "RO", 0, 15'h0, 1, 0, 1);
            CTS  = uvm_reg_field::type_id::create("CTS");
            CTS.configure (this, 1,  16, "RO", 0, 1'b0,  1, 1, 0);
            RSVD = uvm_reg_field::type_id::create("RSVD_15_1");
            RSVD.configure(this, 15, 1,  "RO", 0, 15'h0, 1, 0, 1);
            EOS  = uvm_reg_field::type_id::create("EOS");
            // NOTE: reset value = 1 (error output active after reset)
            EOS.configure (this, 1,  0,  "RO", 0, 1'b1,  1, 1, 0);
        endfunction
    endclass : ermu_eoys_reg

    // ==========================================================================
    //  Register: ERMU_EOyCTCNT — Error Output y Clear Timer Counter
    //  Offset: y × 0x0080 + 0x0008   Reset: 0x0000_0000
    // ==========================================================================
    class ermu_eoyctcnt_reg extends uvm_reg;
        `uvm_object_utils(ermu_eoyctcnt_reg)

        uvm_reg_field CNT;      // [15:0] Counter value, RO
        uvm_reg_field RSVD;

        function new(string name = "ermu_eoyctcnt_reg");
            super.new(name, 32, UVM_NO_COVERAGE);
        endfunction

        virtual function void build();
            RSVD = uvm_reg_field::type_id::create("RSVD");
            RSVD.configure(this, 16, 16, "RO", 0, 16'h0, 1, 0, 1);
            CNT  = uvm_reg_field::type_id::create("CNT");
            CNT.configure (this, 16, 0,  "RO", 0, 16'h0, 1, 1, 0);
        endfunction
    endclass : ermu_eoyctcnt_reg

    // ==========================================================================
    //  Register: ERMU_EOyCTCMP — Error Output y Clear Timer Compare
    //  Offset: y × 0x0080 + 0x000C   Reset: 0x0000_0000
    // ==========================================================================
    class ermu_eoyctcmp_reg extends uvm_reg;
        `uvm_object_utils(ermu_eoyctcmp_reg)

        rand uvm_reg_field CMP; // [15:0] Compare value, RW
        uvm_reg_field       RSVD;

        function new(string name = "ermu_eoyctcmp_reg");
            super.new(name, 32, UVM_NO_COVERAGE);
        endfunction

        virtual function void build();
            RSVD = uvm_reg_field::type_id::create("RSVD");
            RSVD.configure(this, 16, 16, "RO", 0, 16'h0, 1, 0, 1);
            CMP  = uvm_reg_field::type_id::create("CMP");
            CMP.configure (this, 16, 0,  "RW", 0, 16'h0, 1, 1, 1);
        endfunction
    endclass : ermu_eoyctcmp_reg

    // ==========================================================================
    //  Register: ERMU_EOyTTC — Error Output y Toggle Timer Control
    //  Offset: y × 0x0080 + 0x0010   Reset: 0x0000_0000
    // ==========================================================================
    class ermu_eoyttc_reg extends uvm_reg;
        `uvm_object_utils(ermu_eoyttc_reg)

        rand uvm_reg_field TTE; // [0] Toggle Timer Enable, RW
        uvm_reg_field       RSVD;

        function new(string name = "ermu_eoyttc_reg");
            super.new(name, 32, UVM_NO_COVERAGE);
        endfunction

        virtual function void build();
            RSVD = uvm_reg_field::type_id::create("RSVD");
            RSVD.configure(this, 31, 1, "RO", 0, 31'h0, 1, 0, 1);
            TTE  = uvm_reg_field::type_id::create("TTE");
            TTE.configure (this, 1,  0, "RW", 0, 1'b0,  1, 1, 1);
        endfunction
    endclass : ermu_eoyttc_reg

    // ==========================================================================
    //  Register: ERMU_EOyTTCNT — Toggle Timer Counter (RO)
    // ==========================================================================
    class ermu_eoyttcnt_reg extends uvm_reg;
        `uvm_object_utils(ermu_eoyttcnt_reg)

        uvm_reg_field CNT;
        uvm_reg_field RSVD;

        function new(string name = "ermu_eoyttcnt_reg");
            super.new(name, 32, UVM_NO_COVERAGE);
        endfunction
        virtual function void build();
            RSVD = uvm_reg_field::type_id::create("RSVD");
            RSVD.configure(this, 16, 16, "RO", 0, 16'h0, 1, 0, 1);
            CNT  = uvm_reg_field::type_id::create("CNT");
            CNT.configure (this, 16, 0,  "RO", 0, 16'h0, 1, 1, 0);
        endfunction
    endclass : ermu_eoyttcnt_reg

    // ==========================================================================
    //  Register: ERMU_EOyTTCMP — Toggle Timer Compare (RW)
    // ==========================================================================
    class ermu_eoyttcmp_reg extends uvm_reg;
        `uvm_object_utils(ermu_eoyttcmp_reg)

        rand uvm_reg_field CMP;
        uvm_reg_field       RSVD;

        function new(string name = "ermu_eoyttcmp_reg");
            super.new(name, 32, UVM_NO_COVERAGE);
        endfunction
        virtual function void build();
            RSVD = uvm_reg_field::type_id::create("RSVD");
            RSVD.configure(this, 16, 16, "RO", 0, 16'h0, 1, 0, 1);
            CMP  = uvm_reg_field::type_id::create("CMP");
            CMP.configure (this, 16, 0,  "RW", 0, 16'h0, 1, 1, 1);
        endfunction
    endclass : ermu_eoyttcmp_reg

    // ==========================================================================
    //  Register: ERMU_EOyOMj — Output Mask j (sources j*32 ~ j*32+31)
    //  Offset: y × 0x0080 + j × 0x0004 + 0x0040   Reset: 0x0000_0000
    //  j = 0..8 (9 groups per channel covering 288 error sources)
    // ==========================================================================
    class ermu_eoyom_reg extends uvm_reg;
        `uvm_object_utils(ermu_eoyom_reg)

        rand uvm_reg_field OM;  // [31:0] Output mask bits, RW

        function new(string name = "ermu_eoyom_reg");
            super.new(name, 32, UVM_NO_COVERAGE);
        endfunction
        virtual function void build();
            OM = uvm_reg_field::type_id::create("OM");
            OM.configure(this, 32, 0, "RW", 0, 32'h0, 1, 1, 1);
        endfunction
    endclass : ermu_eoyom_reg

    // ==========================================================================
    //  Register: ERMU_WTzC — Wait Timer z Control
    //  Offset: z × 0x0020 + 0x0200   Reset: 0x0000_0000
    // ==========================================================================
    class ermu_wtzc_reg extends uvm_reg;
        `uvm_object_utils(ermu_wtzc_reg)

        rand uvm_reg_field STP;     // [16] Stop wait timer, WO (read as 0)
        rand uvm_reg_field WTE;     // [0]  Wait Timer Enable, RW
        uvm_reg_field       RSVD;

        function new(string name = "ermu_wtzc_reg");
            super.new(name, 32, UVM_NO_COVERAGE);
        endfunction
        virtual function void build();
            RSVD = uvm_reg_field::type_id::create("RSVD_31_17");
            RSVD.configure(this, 15, 17, "RO", 0, 15'h0, 1, 0, 1);
            STP  = uvm_reg_field::type_id::create("STP");
            STP.configure (this, 1,  16, "WO", 0, 1'b0,  1, 1, 0); // WO: no read
            RSVD = uvm_reg_field::type_id::create("RSVD_15_1");
            RSVD.configure(this, 15, 1,  "RO", 0, 15'h0, 1, 0, 1);
            WTE  = uvm_reg_field::type_id::create("WTE");
            WTE.configure (this, 1,  0,  "RW", 0, 1'b0,  1, 1, 1);
        endfunction
    endclass : ermu_wtzc_reg

    // ==========================================================================
    //  Register: ERMU_WTzS — Wait Timer z Status (RO)
    //  Offset: z × 0x0020 + 0x0204   Reset: 0x0000_0000
    // ==========================================================================
    class ermu_wtzs_reg extends uvm_reg;
        `uvm_object_utils(ermu_wtzs_reg)

        uvm_reg_field WTS;      // [0] Wait Timer Status, RO
        uvm_reg_field RSVD;

        function new(string name = "ermu_wtzs_reg");
            super.new(name, 32, UVM_NO_COVERAGE);
        endfunction
        virtual function void build();
            RSVD = uvm_reg_field::type_id::create("RSVD");
            RSVD.configure(this, 31, 1, "RO", 0, 31'h0, 1, 0, 1);
            WTS  = uvm_reg_field::type_id::create("WTS");
            WTS.configure (this, 1,  0, "RO", 0, 1'b0, 1, 1, 0);
        endfunction
    endclass : ermu_wtzs_reg

    // ==========================================================================
    //  Register: ERMU_WTzCNT — Wait Timer z Counter (RO)
    // ==========================================================================
    class ermu_wtzcnt_reg extends uvm_reg;
        `uvm_object_utils(ermu_wtzcnt_reg)

        uvm_reg_field CNT;
        uvm_reg_field RSVD;

        function new(string name = "ermu_wtzcnt_reg");
            super.new(name, 32, UVM_NO_COVERAGE);
        endfunction
        virtual function void build();
            RSVD = uvm_reg_field::type_id::create("RSVD");
            RSVD.configure(this, 16, 16, "RO", 0, 16'h0, 1, 0, 1);
            CNT  = uvm_reg_field::type_id::create("CNT");
            CNT.configure (this, 16, 0,  "RO", 0, 16'h0, 1, 1, 0);
        endfunction
    endclass : ermu_wtzcnt_reg

    // ==========================================================================
    //  Register: ERMU_WTzCMP — Wait Timer z Compare (RW, cannot be 1)
    // ==========================================================================
    class ermu_wtzcmp_reg extends uvm_reg;
        `uvm_object_utils(ermu_wtzcmp_reg)

        rand uvm_reg_field CMP;
        uvm_reg_field       RSVD;

        function new(string name = "ermu_wtzcmp_reg");
            super.new(name, 32, UVM_NO_COVERAGE);
        endfunction
        virtual function void build();
            RSVD = uvm_reg_field::type_id::create("RSVD");
            RSVD.configure(this, 16, 16, "RO", 0, 16'h0, 1, 0, 1);
            CMP  = uvm_reg_field::type_id::create("CMP");
            CMP.configure (this, 16, 0,  "RW", 0, 16'h0, 1, 1, 1);
        endfunction
    endclass : ermu_wtzcmp_reg

    // ==========================================================================
    //  Register: ERMU_WTzSE — Wait Timer z Start Enable
    //  Offset: z × 0x0020 + 0x0210   Reset: 0x0000_0000
    //  HPIn[2:0] at [18:16]: HPI0/HPI1/HPI2 independent start enable
    //  LPIn[2:0] at [2:0]:   LPI0/LPI1/LPI2 independent start enable
    //  NOTE: DUT N_NUM=2, HPI2 (bit18) may not be implemented
    // ==========================================================================
    class ermu_wtzse_reg extends uvm_reg;
        `uvm_object_utils(ermu_wtzse_reg)

        rand uvm_reg_field HPI2;    // [18] HPI2 start enable (CPUSTBY, N/A when N_NUM=2)
        rand uvm_reg_field HPI1;    // [17] HPI1 start enable (CPU1)
        rand uvm_reg_field HPI0;    // [16] HPI0 start enable (CPU0)
        rand uvm_reg_field LPI2;    // [2]  LPI2 start enable
        rand uvm_reg_field LPI1;    // [1]  LPI1 start enable
        rand uvm_reg_field LPI0;    // [0]  LPI0 start enable
        uvm_reg_field       RSVD;

        function new(string name = "ermu_wtzse_reg");
            super.new(name, 32, UVM_NO_COVERAGE);
        endfunction
        virtual function void build();
            RSVD = uvm_reg_field::type_id::create("RSVD_31_19");
            RSVD.configure(this, 13, 19, "RO", 0, 13'h0, 1, 0, 1);
            HPI2 = uvm_reg_field::type_id::create("HPI2");
            HPI2.configure(this, 1, 18, "RW", 0, 1'b0, 1, 1, 1);
            HPI1 = uvm_reg_field::type_id::create("HPI1");
            HPI1.configure(this, 1, 17, "RW", 0, 1'b0, 1, 1, 1);
            HPI0 = uvm_reg_field::type_id::create("HPI0");
            HPI0.configure(this, 1, 16, "RW", 0, 1'b0, 1, 1, 1);
            RSVD = uvm_reg_field::type_id::create("RSVD_15_3");
            RSVD.configure(this, 13, 3,  "RO", 0, 13'h0, 1, 0, 1);
            LPI2 = uvm_reg_field::type_id::create("LPI2");
            LPI2.configure(this, 1, 2,  "RW", 0, 1'b0, 1, 1, 1);
            LPI1 = uvm_reg_field::type_id::create("LPI1");
            LPI1.configure(this, 1, 1,  "RW", 0, 1'b0, 1, 1, 1);
            LPI0 = uvm_reg_field::type_id::create("LPI0");
            LPI0.configure(this, 1, 0,  "RW", 0, 1'b0, 1, 1, 1);
        endfunction
    endclass : ermu_wtzse_reg

    // ==========================================================================
    //  Register: ERMU_ESSj — Error Source Status j (RO)
    //  Offset: j × 0x0004 + 0x0400   Reset: 0x0000_0000
    // ==========================================================================
    class ermu_essj_reg extends uvm_reg;
        `uvm_object_utils(ermu_essj_reg)

        uvm_reg_field ESS;      // [31:0] Error source status bits, RO

        function new(string name = "ermu_essj_reg");
            super.new(name, 32, UVM_NO_COVERAGE);
        endfunction
        virtual function void build();
            ESS = uvm_reg_field::type_id::create("ESS");
            ESS.configure(this, 32, 0, "RO", 0, 32'h0, 1, 1, 0);
        endfunction
    endclass : ermu_essj_reg

    // ==========================================================================
    //  Register: ERMU_ESSCj — Error Source Status Clear j (WO)
    //  Offset: j × 0x0004 + 0x0440   Reset: 0x0000_0000
    // ==========================================================================
    class ermu_esscj_reg extends uvm_reg;
        `uvm_object_utils(ermu_esscj_reg)

        rand uvm_reg_field ESSC;    // [31:0] Clear bits, WO (read as 0)

        function new(string name = "ermu_esscj_reg");
            super.new(name, 32, UVM_NO_COVERAGE);
        endfunction
        virtual function void build();
            ESSC = uvm_reg_field::type_id::create("ESSC");
            ESSC.configure(this, 32, 0, "WO", 0, 32'h0, 1, 1, 0); // WO: no read back
        endfunction
    endclass : ermu_esscj_reg

    // ==========================================================================
    //  Register: ERMU_PETj — Pseudo Error Trigger j (WO)
    //  Offset: j × 0x0004 + 0x0480   Reset: 0x0000_0000
    // ==========================================================================
    class ermu_petj_reg extends uvm_reg;
        `uvm_object_utils(ermu_petj_reg)

        rand uvm_reg_field PET;     // [31:0] Pseudo error trigger bits, WO

        function new(string name = "ermu_petj_reg");
            super.new(name, 32, UVM_NO_COVERAGE);
        endfunction
        virtual function void build();
            PET = uvm_reg_field::type_id::create("PET");
            PET.configure(this, 32, 0, "WO", 0, 32'h0, 1, 1, 0);
        endfunction
    endclass : ermu_petj_reg

    // ==========================================================================
    //  Register: ERMU_EGC — Error Global Configuration
    //  Offset: 0x04C0   Reset: 0x0000_0001 (HPIE_C0=1 by default)
    // ==========================================================================
    class ermu_egc_reg extends uvm_reg;
        `uvm_object_utils(ermu_egc_reg)

        rand uvm_reg_field PSSRS;   // [25:16] Port Safe State Request Select (10bit)
        rand uvm_reg_field HPIE_C1; // [1]     HPI enable to cm7_core
        rand uvm_reg_field HPIE_C0; // [0]     HPI enable to cm4_core (default=1)
        uvm_reg_field       RSVD;

        function new(string name = "ermu_egc_reg");
            super.new(name, 32, UVM_NO_COVERAGE);
        endfunction
        virtual function void build();
            RSVD = uvm_reg_field::type_id::create("RSVD_31_26");
            RSVD.configure(this, 6, 26, "RO", 0, 6'h0, 1, 0, 1);
            PSSRS = uvm_reg_field::type_id::create("PSSRS");
            PSSRS.configure(this, 10, 16, "RW", 0, 10'h0, 1, 1, 1);
            RSVD = uvm_reg_field::type_id::create("RSVD_15_2");
            RSVD.configure(this, 14, 2,  "RO", 0, 14'h0, 1, 0, 1);
            HPIE_C1 = uvm_reg_field::type_id::create("HPIE_C1");
            HPIE_C1.configure(this, 1, 1, "RW", 0, 1'b0, 1, 1, 1);
            HPIE_C0 = uvm_reg_field::type_id::create("HPIE_C0");
            HPIE_C0.configure(this, 1, 0, "RW", 0, 1'b1, 1, 1, 1); // default=1
        endfunction
    endclass : ermu_egc_reg

    // ==========================================================================
    //  Register: ERMU_ERCp — Error Response Control p (8 sources per register)
    //  Offset: p × 0x0004 + 0x0500   Reset: 0x0000_0000
    //  Each 3-bit field: 0=NA, 2=LPI0, 3=LPI1, 4=LPI2, 5=HPI, 6=APP_RST, 7=SYS_RST
    // ==========================================================================
    class ermu_ercp_reg extends uvm_reg;
        `uvm_object_utils(ermu_ercp_reg)

        // 8 error source groups, each 3-bit control + 1 reserved bit = 4 bits
        rand uvm_reg_field E7RC;    // [30:28]
        rand uvm_reg_field E6RC;    // [26:24]
        rand uvm_reg_field E5RC;    // [22:20]
        rand uvm_reg_field E4RC;    // [18:16]
        rand uvm_reg_field E3RC;    // [14:12]
        rand uvm_reg_field E2RC;    // [10:8]
        rand uvm_reg_field E1RC;    // [6:4]
        rand uvm_reg_field E0RC;    // [2:0]
        uvm_reg_field       RSVD;

        function new(string name = "ermu_ercp_reg");
            super.new(name, 32, UVM_NO_COVERAGE);
        endfunction
        virtual function void build();
            RSVD = uvm_reg_field::type_id::create("RSVD_31");
            RSVD.configure(this, 1, 31, "RO", 0, 1'b0, 1, 0, 1);
            E7RC = uvm_reg_field::type_id::create("E7RC");
            E7RC.configure(this, 3, 28, "RW", 0, 3'h0, 1, 1, 1);
            RSVD = uvm_reg_field::type_id::create("RSVD_27");
            RSVD.configure(this, 1, 27, "RO", 0, 1'b0, 1, 0, 1);
            E6RC = uvm_reg_field::type_id::create("E6RC");
            E6RC.configure(this, 3, 24, "RW", 0, 3'h0, 1, 1, 1);
            RSVD = uvm_reg_field::type_id::create("RSVD_23");
            RSVD.configure(this, 1, 23, "RO", 0, 1'b0, 1, 0, 1);
            E5RC = uvm_reg_field::type_id::create("E5RC");
            E5RC.configure(this, 3, 20, "RW", 0, 3'h0, 1, 1, 1);
            RSVD = uvm_reg_field::type_id::create("RSVD_19");
            RSVD.configure(this, 1, 19, "RO", 0, 1'b0, 1, 0, 1);
            E4RC = uvm_reg_field::type_id::create("E4RC");
            E4RC.configure(this, 3, 16, "RW", 0, 3'h0, 1, 1, 1);
            RSVD = uvm_reg_field::type_id::create("RSVD_15");
            RSVD.configure(this, 1, 15, "RO", 0, 1'b0, 1, 0, 1);
            E3RC = uvm_reg_field::type_id::create("E3RC");
            E3RC.configure(this, 3, 12, "RW", 0, 3'h0, 1, 1, 1);
            RSVD = uvm_reg_field::type_id::create("RSVD_11");
            RSVD.configure(this, 1, 11, "RO", 0, 1'b0, 1, 0, 1);
            E2RC = uvm_reg_field::type_id::create("E2RC");
            E2RC.configure(this, 3, 8,  "RW", 0, 3'h0, 1, 1, 1);
            RSVD = uvm_reg_field::type_id::create("RSVD_7");
            RSVD.configure(this, 1, 7,  "RO", 0, 1'b0, 1, 0, 1);
            E1RC = uvm_reg_field::type_id::create("E1RC");
            E1RC.configure(this, 3, 4,  "RW", 0, 3'h0, 1, 1, 1);
            RSVD = uvm_reg_field::type_id::create("RSVD_3");
            RSVD.configure(this, 1, 3,  "RO", 0, 1'b0, 1, 0, 1);
            E0RC = uvm_reg_field::type_id::create("E0RC");
            E0RC.configure(this, 3, 0,  "RW", 0, 3'h0, 1, 1, 1);
        endfunction
    endclass : ermu_ercp_reg

    // ==========================================================================
    //  Register: ERMU_CCPS — Counter Clock Pre-Scaler
    //  Offset: 0x0600   Reset: 0x0000_0000
    //  CC_PSC[7:0] at [23:16]; fcntclk = fCNT_MCLK / (PSC+1)
    // ==========================================================================
    class ermu_ccps_reg extends uvm_reg;
        `uvm_object_utils(ermu_ccps_reg)

        rand uvm_reg_field PSC;     // [23:16] Pre-scaler coefficient (CCPS_BW=8)
        rand uvm_reg_field PSE;     // [0]     Pre-scaler Enable
        uvm_reg_field       RSVD;

        function new(string name = "ermu_ccps_reg");
            super.new(name, 32, UVM_NO_COVERAGE);
        endfunction
        virtual function void build();
            RSVD = uvm_reg_field::type_id::create("RSVD_31_24");
            RSVD.configure(this, 8, 24, "RO", 0, 8'h0, 1, 0, 1);
            PSC  = uvm_reg_field::type_id::create("PSC");
            PSC.configure (this, 8, 16, "RW", 0, 8'h0, 1, 1, 1);
            RSVD = uvm_reg_field::type_id::create("RSVD_15_1");
            RSVD.configure(this, 15, 1,  "RO", 0, 15'h0, 1, 0, 1);
            PSE  = uvm_reg_field::type_id::create("PSE");
            PSE.configure (this, 1,  0,  "RW", 0, 1'b0,  1, 1, 1);
        endfunction
    endclass : ermu_ccps_reg

    // ==========================================================================
    //  Register: ERMU_EMSC — Emergency Stop Control
    //  Offset: 0x0604   Reset: 0x0000_0000
    // ==========================================================================
    class ermu_emsc_reg extends uvm_reg;
        `uvm_object_utils(ermu_emsc_reg)

        rand uvm_reg_field EMSEL;   // [21:20] EMS port selection: 00=EMSP0..11=EMSP3
        rand uvm_reg_field EMSPOL;  // [18]    Polarity: 0=same, 1=inverted
        rand uvm_reg_field EMSMOD;  // [17]    Mode: 0=sync, 1=async
        rand uvm_reg_field EMSEN;   // [16]    EMS enable
        rand uvm_reg_field EMSCLR;  // [1]     Clear EMS status, WO
        rand uvm_reg_field EMSSET;  // [0]     Software trigger/set EMS, WO
        uvm_reg_field       RSVD;

        function new(string name = "ermu_emsc_reg");
            super.new(name, 32, UVM_NO_COVERAGE);
        endfunction
        virtual function void build();
            RSVD = uvm_reg_field::type_id::create("RSVD_31_22");
            RSVD.configure(this, 10, 22, "RO", 0, 10'h0, 1, 0, 1);
            EMSEL = uvm_reg_field::type_id::create("EMSEL");
            EMSEL.configure(this, 2, 20, "RW", 0, 2'h0, 1, 1, 1);
            RSVD = uvm_reg_field::type_id::create("RSVD_19");
            RSVD.configure(this, 1, 19, "RO", 0, 1'b0, 1, 0, 1);
            EMSPOL = uvm_reg_field::type_id::create("EMSPOL");
            EMSPOL.configure(this, 1, 18, "RW", 0, 1'b0, 1, 1, 1);
            EMSMOD = uvm_reg_field::type_id::create("EMSMOD");
            EMSMOD.configure(this, 1, 17, "RW", 0, 1'b0, 1, 1, 1);
            EMSEN = uvm_reg_field::type_id::create("EMSEN");
            EMSEN.configure(this, 1, 16, "RW", 0, 1'b0, 1, 1, 1);
            RSVD = uvm_reg_field::type_id::create("RSVD_15_2");
            RSVD.configure(this, 14, 2, "RO", 0, 14'h0, 1, 0, 1);
            EMSCLR = uvm_reg_field::type_id::create("EMSCLR");
            EMSCLR.configure(this, 1, 1, "WO", 0, 1'b0, 1, 1, 0); // WO
            EMSSET = uvm_reg_field::type_id::create("EMSSET");
            EMSSET.configure(this, 1, 0, "WO", 0, 1'b0, 1, 1, 0); // WO
        endfunction
    endclass : ermu_emsc_reg

    // ==========================================================================
    //  Register: ERMU_EMSS — Emergency Stop Status
    //  Offset: 0x0608   Reset: 0x0000_0000
    // ==========================================================================
    class ermu_emss_reg extends uvm_reg;
        `uvm_object_utils(ermu_emss_reg)

        uvm_reg_field EMSS;     // [0] EMS input status: 0=not involved, 1=involved
        uvm_reg_field RSVD;

        function new(string name = "ermu_emss_reg");
            super.new(name, 32, UVM_NO_COVERAGE);
        endfunction
        virtual function void build();
            RSVD = uvm_reg_field::type_id::create("RSVD_31_1");
            RSVD.configure(this, 31, 1, "RO", 0, 31'h0, 1, 0, 1);
            EMSS = uvm_reg_field::type_id::create("EMSS");
            EMSS.configure(this, 1, 0, "RO", 0, 1'b0, 1, 1, 0);
        endfunction
    endclass : ermu_emss_reg

    // ==========================================================================
    //  Register: ERMU_CFGLOCK — Configuration Lock Register
    //  Offset: 0x0700   Reset: 0x0000_0001 (LOCKED by default!)
    //  Write 0xBC to key field to unlock; write any other value to lock
    // ==========================================================================
    class ermu_cfglock_reg extends uvm_reg;
        `uvm_object_utils(ermu_cfglock_reg)

        rand uvm_reg_field KEY;     // [15:8] Write-only key (0xBC = unlock)
        rand uvm_reg_field CFGLCK;  // [0]    Config lock status: 0=unlocked, 1=locked
        uvm_reg_field       RSVD;

        function new(string name = "ermu_cfglock_reg");
            super.new(name, 32, UVM_NO_COVERAGE);
        endfunction
        virtual function void build();
            RSVD = uvm_reg_field::type_id::create("RSVD_31_16");
            RSVD.configure(this, 16, 16, "RO", 0, 16'h0, 1, 0, 1);
            KEY  = uvm_reg_field::type_id::create("KEY");
            KEY.configure (this, 8,  8,  "WO", 0, 8'h0, 1, 1, 0); // WO
            RSVD = uvm_reg_field::type_id::create("RSVD_7_1");
            RSVD.configure(this, 7,  1,  "RO", 0, 7'h0, 1, 0, 1);
            CFGLCK = uvm_reg_field::type_id::create("CFGLCK");
            CFGLCK.configure(this, 1, 0, "RW", 0, 1'b1, 1, 1, 1); // DEFAULT=1 (locked)
        endfunction
    endclass : ermu_cfglock_reg

    // ==========================================================================
    //  Register: ERMU_PERLOCK — Permanent Lock Register
    //  Offset: 0x0704   Reset: 0x0000_0000
    //  Write 0xFF to key field to permanently lock; only POR can unlock
    // ==========================================================================
    class ermu_perlock_reg extends uvm_reg;
        `uvm_object_utils(ermu_perlock_reg)

        rand uvm_reg_field KEY;     // [15:8] Write-only key (0xFF = lock permanently)
        rand uvm_reg_field PERLCK;  // [0]    Permanent lock status
        uvm_reg_field       RSVD;

        function new(string name = "ermu_perlock_reg");
            super.new(name, 32, UVM_NO_COVERAGE);
        endfunction
        virtual function void build();
            RSVD = uvm_reg_field::type_id::create("RSVD_31_16");
            RSVD.configure(this, 16, 16, "RO", 0, 16'h0, 1, 0, 1);
            KEY  = uvm_reg_field::type_id::create("KEY");
            KEY.configure (this, 8,  8,  "WO", 0, 8'h0, 1, 1, 0);
            RSVD = uvm_reg_field::type_id::create("RSVD_7_1");
            RSVD.configure(this, 7,  1,  "RO", 0, 7'h0, 1, 0, 1);
            PERLCK = uvm_reg_field::type_id::create("PERLCK");
            PERLCK.configure(this, 1, 0, "RW", 0, 1'b0, 1, 1, 1);
        endfunction
    endclass : ermu_perlock_reg

    // ==========================================================================
    //  ERMU Register Block — Top-level container for all registers
    // ==========================================================================
    class ermu_reg_block extends uvm_reg_block;
        `uvm_object_utils(ermu_reg_block)

        // ---- Constants ----
        localparam int NUM_EO_CHANNELS = 4;   // y = 0..3
        localparam int NUM_WT_TIMERS  = 2;   // z = 0..1
        localparam int NUM_ESS_GROUPS = 9;   // j = 0..8 (288/32)
        localparam int NUM_OM_GROUPS  = 9;   // j = 0..8 (288/32 masks per channel)
        localparam int NUM_ERC_GROUPS = 36;  // p = 0..35 (288/8)

        // ---- ESS valid-source masks (1=implemented, 0=reserved) ----
        //  Based on C059 TS Table 18-10: Error sources for ERMU0
        //  Reserved bits always read 0; used to filter ESS read expectations
        localparam bit [31:0] ESS_VALID_MASK [9] = '{
            32'h0FFF_1F03,  // ESS0: ID 0-1,8-12,16-27 (IDs 2-7,13-15,28-31 reserved)
            32'h0000_0000,  // ESS1: ID 32-63 ALL RESERVED
            32'h0706_0703,  // ESS2: ID 64-65,72-74,81-82,88-90 (IDs 66-71,75-80,83-87,91-95 reserved)
            32'h0037_7777,  // ESS3: ID 96-98,100-102,104-106,108-110,112-114,116-117 (IDs 99,103,107,111,115,118-127 reserved)
            32'h0000_811F,  // ESS4: ID 128-132,136,143 (IDs 133-135,137-142,144-159 reserved)
            32'hFFFF_FFFF,  // ESS5: ID 160-191 ALL IMPLEMENTED (SFC_BEDE0-31)
            32'h0000_0FFF,  // ESS6: ID 192-203 (IDs 204-223 reserved)
            32'h0000_0000,  // ESS7: ID 224-255 ALL RESERVED
            32'h007F_007F   // ESS8: ID 256-262,272-278 (IDs 263-271,279-287 reserved)
        };

        // ---- EOy Channel register arrays ----
        ermu_eoyc_reg       EOyC       [NUM_EO_CHANNELS];
        ermu_eoys_reg       EOyS       [NUM_EO_CHANNELS];
        ermu_eoyctcnt_reg   EOyCTCNT   [NUM_EO_CHANNELS];
        ermu_eoyctcmp_reg   EOyCTCMP   [NUM_EO_CHANNELS];
        ermu_eoyttc_reg     EOyTTC     [NUM_EO_CHANNELS];
        ermu_eoyttcnt_reg   EOyTTCNT   [NUM_EO_CHANNELS];
        ermu_eoyttcmp_reg   EOyTTCMP   [NUM_EO_CHANNELS];
        ermu_eoyom_reg      EOyOM      [NUM_EO_CHANNELS][NUM_OM_GROUPS];

        // ---- WTz Timer register arrays ----
        ermu_wtzc_reg       WTzC       [NUM_WT_TIMERS];
        ermu_wtzs_reg       WTzS       [NUM_WT_TIMERS];
        ermu_wtzcnt_reg     WTzCNT     [NUM_WT_TIMERS];
        ermu_wtzcmp_reg     WTzCMP     [NUM_WT_TIMERS];
        ermu_wtzse_reg      WTzSE      [NUM_WT_TIMERS];

        // ---- ESS/ESSC/PET groups ----
        ermu_essj_reg       ESS        [NUM_ESS_GROUPS];
        ermu_esscj_reg      ESSC       [NUM_ESS_GROUPS];
        ermu_petj_reg       PET        [NUM_ESS_GROUPS];

        // ---- ERC groups ----
        ermu_ercp_reg       ERC        [NUM_ERC_GROUPS];

        // ---- Global registers ----
        ermu_egc_reg        EGC;
        ermu_ccps_reg       CCPS;
        ermu_emsc_reg       EMSC;
        ermu_emss_reg       EMSS;
        ermu_cfglock_reg    CFGLOCK;
        ermu_perlock_reg    PERLOCK;

        // ---- Register map (for auto-generation reference) ----
        uvm_reg_map          reg_map;

        function new(string name = "ermu_reg_block");
            super.new(name, UVM_NO_COVERAGE);
        endfunction

        virtual function void build();
            int y, z, j, p, m;

            // ---- Create default map ----
            reg_map = create_map("reg_map", 'h0, 4, UVM_LITTLE_ENDIAN);

            // ---- EOy Channels (y = 0..3) ----
            for (y = 0; y < NUM_EO_CHANNELS; y++) begin
                string s; s.itoa(y);
                EOyC[y]       = ermu_eoyc_reg    ::type_id::create({"EO", s, "C"});
                EOyS[y]       = ermu_eoys_reg    ::type_id::create({"EO", s, "S"});
                EOyCTCNT[y]   = ermu_eoyctcnt_reg::type_id::create({"EO", s, "CTCNT"});
                EOyCTCMP[y]   = ermu_eoyctcmp_reg::type_id::create({"EO", s, "CTCMP"});
                EOyTTC[y]     = ermu_eoyttc_reg  ::type_id::create({"EO", s, "TTC"});
                EOyTTCNT[y]   = ermu_eoyttcnt_reg::type_id::create({"EO", s, "TTCNT"});
                EOyTTCMP[y]   = ermu_eoyttcmp_reg::type_id::create({"EO", s, "TTCMP"});

                EOyC[y].configure    (this);
                EOyS[y].configure    (this);
                EOyCTCNT[y].configure(this);
                EOyCTCMP[y].configure(this);
                EOyTTC[y].configure  (this);
                EOyTTCNT[y].configure(this);
                EOyTTCMP[y].configure(this);

                EOyC[y].build    ();
                EOyS[y].build    ();
                EOyCTCNT[y].build();
                EOyCTCMP[y].build();
                EOyTTC[y].build  ();
                EOyTTCNT[y].build();
                EOyTTCMP[y].build();

                // EOyOMj (j=0..8 per channel)
                for (m = 0; m < NUM_OM_GROUPS; m++) begin
                    string ms; ms.itoa(m);
                    EOyOM[y][m] = ermu_eoyom_reg::type_id::create({"EO", s, "OM", ms});
                    EOyOM[y][m].configure(this);
                    EOyOM[y][m].build();
                end
            end

            // ---- WTz Timers (z = 0..1) ----
            for (z = 0; z < NUM_WT_TIMERS; z++) begin
                string s; s.itoa(z);
                WTzC[z]   = ermu_wtzc_reg  ::type_id::create({"WT", s, "C"});
                WTzS[z]   = ermu_wtzs_reg  ::type_id::create({"WT", s, "S"});
                WTzCNT[z] = ermu_wtzcnt_reg::type_id::create({"WT", s, "CNT"});
                WTzCMP[z] = ermu_wtzcmp_reg::type_id::create({"WT", s, "CMP"});
                WTzSE[z]  = ermu_wtzse_reg ::type_id::create({"WT", s, "SE"});

                WTzC[z].configure  (this);
                WTzS[z].configure  (this);
                WTzCNT[z].configure(this);
                WTzCMP[z].configure(this);
                WTzSE[z].configure (this);

                WTzC[z].build  ();
                WTzS[z].build  ();
                WTzCNT[z].build();
                WTzCMP[z].build();
                WTzSE[z].build ();
            end

            // ---- ESS/ESSC/PET groups (j = 0..8) ----
            for (j = 0; j < NUM_ESS_GROUPS; j++) begin
                string s; s.itoa(j);
                ESS[j]  = ermu_essj_reg ::type_id::create({"ESS", s});
                ESSC[j] = ermu_esscj_reg::type_id::create({"ESSC", s});
                PET[j]  = ermu_petj_reg ::type_id::create({"PET", s});

                ESS[j].configure (this);
                ESSC[j].configure(this);
                PET[j].configure (this);

                ESS[j].build ();
                ESSC[j].build();
                PET[j].build ();
            end

            // ---- ERC groups (p = 0..35) ----
            for (p = 0; p < NUM_ERC_GROUPS; p++) begin
                string s; s.itoa(p);
                ERC[p] = ermu_ercp_reg::type_id::create({"ERC", s});
                ERC[p].configure(this);
                ERC[p].build();
            end

            // ---- Global registers ----
            EGC      = ermu_egc_reg     ::type_id::create("EGC");
            CCPS     = ermu_ccps_reg    ::type_id::create("CCPS");
            EMSC     = ermu_emsc_reg    ::type_id::create("EMSC");
            EMSS     = ermu_emss_reg    ::type_id::create("EMSS");
            CFGLOCK  = ermu_cfglock_reg ::type_id::create("CFGLOCK");
            PERLOCK  = ermu_perlock_reg ::type_id::create("PERLOCK");

            EGC.configure     (this); EGC.build();
            CCPS.configure    (this); CCPS.build();
            EMSC.configure    (this); EMSC.build();
            EMSS.configure    (this); EMSS.build();
            CFGLOCK.configure (this); CFGLOCK.build();
            PERLOCK.configure (this); PERLOCK.build();

            // ==============================================================
            //  Register Map — Add registers with their offsets
            //  Base address offset from ERMU_BASE_ADDR (0x4006_2000)
            // ==============================================================

            // ---- EOy Channels (y=0..3, stride = 0x0080) ----
            for (y = 0; y < NUM_EO_CHANNELS; y++) begin
                reg_map.add_reg(EOyC[y],       y * 12'h080 + 12'h000, "RW");
                reg_map.add_reg(EOyS[y],       y * 12'h080 + 12'h004, "RO");
                reg_map.add_reg(EOyCTCNT[y],   y * 12'h080 + 12'h008, "RO");
                reg_map.add_reg(EOyCTCMP[y],   y * 12'h080 + 12'h00C, "RW");
                reg_map.add_reg(EOyTTC[y],     y * 12'h080 + 12'h010, "RW");
                reg_map.add_reg(EOyTTCNT[y],   y * 12'h080 + 12'h014, "RO");
                reg_map.add_reg(EOyTTCMP[y],   y * 12'h080 + 12'h018, "RW");
                // EOyOMj (j=0..8): y*0x80 + j*0x04 + 0x40
                for (m = 0; m < NUM_OM_GROUPS; m++) begin
                    reg_map.add_reg(EOyOM[y][m], y * 12'h080 + m * 12'h004 + 12'h040, "RW");
                end
            end

            // ---- WTz Timers (z=0..1, stride = 0x0020) ----
            for (z = 0; z < NUM_WT_TIMERS; z++) begin
                reg_map.add_reg(WTzC[z],       z * 12'h020 + 12'h200, "RW");
                reg_map.add_reg(WTzS[z],       z * 12'h020 + 12'h204, "RO");
                reg_map.add_reg(WTzCNT[z],     z * 12'h020 + 12'h208, "RO");
                reg_map.add_reg(WTzCMP[z],     z * 12'h020 + 12'h20C, "RW");
                reg_map.add_reg(WTzSE[z],      z * 12'h020 + 12'h210, "RW");
            end

            // ---- ESS/ESSC/PET (j=0..8, stride = 4) ----
            for (j = 0; j < NUM_ESS_GROUPS; j++) begin
                reg_map.add_reg(ESS[j],        j * 12'h004 + 12'h400, "RO");
                reg_map.add_reg(ESSC[j],       j * 12'h004 + 12'h440, "WO");
                reg_map.add_reg(PET[j],        j * 12'h004 + 12'h480, "WO");
            end

            // ---- EGC ----
            reg_map.add_reg(EGC, 12'h4C0, "RW");

            // ---- ERCp (p=0..35, stride = 4) ----
            for (p = 0; p < NUM_ERC_GROUPS; p++) begin
                reg_map.add_reg(ERC[p],        p * 12'h004 + 12'h500, "RW");
            end

            // ---- CCPS ----
            reg_map.add_reg(CCPS, 12'h600, "RW");

            // ---- EMSC / EMSS ----
            reg_map.add_reg(EMSC, 12'h604, "RW");
            reg_map.add_reg(EMSS, 12'h608, "RO");

            // ---- CFGLOCK / PERLOCK ----
            reg_map.add_reg(CFGLOCK, 12'h700, "RW");
            reg_map.add_reg(PERLOCK, 12'h704, "RW");

            // ---- Lock the model ----
            lock_model();
        endfunction : build

        // ---- Helper: check if a source ID is implemented (non-reserved) ----
        function bit is_valid_source(int src_id);
            int j = src_id / 32;
            int k = src_id % 32;
            if (j < 0 || j >= NUM_ESS_GROUPS) return 1'b0;
            return ESS_VALID_MASK[j][k];
        endfunction

        // ---- Helper: get ESS valid mask for a group ----
        function bit [31:0] get_ess_mask(int group);
            if (group < 0 || group >= NUM_ESS_GROUPS) return 32'h0;
            return ESS_VALID_MASK[group];
        endfunction

        // ---- Helper: unlock CFGLOCK (required before any config write) ----
        virtual task unlock_cfglock();
            uvm_status_e status;
            `uvm_info("REG_BLOCK", "Unlocking CFGLOCK (write 0xBC to key)", UVM_MEDIUM)
            CFGLOCK.write(status, 32'h0000_BC00, UVM_FRONTDOOR, reg_map, null);
        endtask : unlock_cfglock

        // ---- Helper: get error response code for a given source ID ----
        virtual function bit [2:0] get_error_response(int src_id);
            int p_idx = src_id / 8;
            int e_idx = src_id % 8;
            uvm_reg_data_t val;
            if (p_idx < NUM_ERC_GROUPS) begin
                val = ERC[p_idx].get();
                // Extract the appropriate 3-bit field
                case (e_idx)
                    0: return val[2:0];
                    1: return val[6:4];
                    2: return val[10:8];
                    3: return val[14:12];
                    4: return val[18:16];
                    5: return val[22:20];
                    6: return val[26:24];
                    7: return val[30:28];
                endcase
            end
            return 3'h0; // default: NA
        endfunction

    endclass : ermu_reg_block

    // ==========================================================================
    //  ERMU Register-to-APB Adapter
    //  Converts uvm_reg_bus_op ↔ apb_transaction for front-door access
endpackage : ermu_reg_pkg
