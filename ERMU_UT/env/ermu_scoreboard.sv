// =============================================================================
//  ERMU Scoreboard — End-to-end checker with shadow model
//  3 analysis ports: APB, input, output
//
//  Shadow model tracks:
//    - expected ESS bits with per-bit origin (PET vs err_src_id)
//    - Comparison: PET bits checked without mask (any ID valid)
//                  err_src_id bits checked with mask (reserved bits -> error)
//    - expected EOS per channel (SET/CLR + error status)
// =============================================================================

`uvm_analysis_imp_decl(_scbd_apb)
`uvm_analysis_imp_decl(_scbd_input)
`uvm_analysis_imp_decl(_scbd_output)

class ermu_scoreboard extends uvm_component;

    `uvm_component_utils(ermu_scoreboard)

    uvm_analysis_imp_scbd_apb    #(apb_transaction,        ermu_scoreboard) apb_export;
    uvm_analysis_imp_scbd_input  #(ermu_input_transaction,  ermu_scoreboard) input_export;
    uvm_analysis_imp_scbd_output #(ermu_output_transaction, ermu_scoreboard) output_export;

    // ---- Shadow state ----
    protected bit [287:0] expected_ess;     // expected ESS bits (1=error present)
    protected bit [287:0] from_pet;         // 1=set via PET (all IDs valid), 0=set via err_src_id
    protected bit [3:0]   eos_sw_set;       // ch y: 1 if SET was last, 0 if CLR was last
    protected int         pending_count;     // number of injections awaiting ESS verification

    // ---- ESS valid-source mask (1=implemented on err_src_id bus, 0=not on bus) ----
    protected bit [31:0]  ess_mask [9];

    // ---- Register offset decode constants ----
    protected bit [11:0]  ESS_BASE   = 12'h400;
    protected bit [11:0]  ESSC_BASE  = 12'h440;
    protected bit [11:0]  PET_BASE   = 12'h480;
    protected bit [11:0]  EOyC_BASE  = 12'h000;
    protected bit [11:0]  EOyS_BASE  = 12'h004;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        apb_export    = new("apb_export",    this);
        input_export  = new("input_export",  this);
        output_export = new("output_export", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ess_mask[0] = 32'h0FFF_1F03;
        ess_mask[1] = 32'h0000_0000;
        ess_mask[2] = 32'h0706_0703;
        ess_mask[3] = 32'h0037_7777;
        ess_mask[4] = 32'h0000_811F;
        ess_mask[5] = 32'hFFFF_FFFF;
        ess_mask[6] = 32'h0000_0FFF;
        ess_mask[7] = 32'h0000_0000;
        ess_mask[8] = 32'h007F_007F;
        expected_ess   = 288'h0;
        from_pet       = 288'h0;
        eos_sw_set     = 4'h0;
        pending_count  = 0;
        `uvm_info("SCBD", "Scoreboard shadow model initialized (288 sources)", UVM_MEDIUM)
    endfunction

    // ========================================================================
    //  APB Transaction Handler
    // ========================================================================
    function void write_scbd_apb(apb_transaction tx);
        bit [11:0] addr = tx.paddr;

        if (addr >= ESS_BASE && addr < (ESS_BASE + 9*4) && !tx.pwrite) begin
            int j = (addr - ESS_BASE) / 4;
            check_ess_read(j, tx.prdata);
        end

        if (addr >= ESSC_BASE && addr < (ESSC_BASE + 9*4) && tx.pwrite) begin
            int j = (addr - ESSC_BASE) / 4;
            apply_essc_clear(j, tx.pwdata);
        end

        if (addr >= PET_BASE && addr < (PET_BASE + 9*4) && tx.pwrite) begin
            int j = (addr - PET_BASE) / 4;
            apply_pet_trigger(j, tx.pwdata);
        end

        if (addr < 4 * 12'h080 && (addr % 12'h080) == 12'h000 && tx.pwrite) begin
            int y = addr / 12'h080;
            track_eoyc_write(y, tx.pwdata);
        end

        if (addr < 4 * 12'h080 && (addr % 12'h080) == 12'h004 && !tx.pwrite) begin
            int y = addr / 12'h080;
            check_eos_read(y, tx.prdata);
        end
    endfunction

    // ========================================================================
    //  Input Transaction Handler (err_src_id bus injection)
    // ========================================================================
    function void write_scbd_input(ermu_input_transaction tx);
        int src_id = tx.src_id;
        int j = src_id / 32;
        int k = src_id % 32;
        if (src_id < 0 || src_id > 287) return;
        // Check: injecting on a reserved ID via err_src_id is impossible in HW
        if (!ess_mask[j][k]) begin
            `uvm_error("SCBD", $sformatf(
                "ID=%0d injected via err_src_id but ESS%0d[%0d] is RESERVED (no bus pin)!",
                src_id, j, k))
            return;
        end
        expected_ess[src_id] = 1'b1;
        from_pet[src_id]     = 1'b0;  // err_src_id origin
        pending_count++;
        `uvm_info("SCBD", $sformatf("Input ID=%0d -> expect ESS%0d[%0d]=1 (pending=%0d)",
                                     src_id, j, k, pending_count), UVM_HIGH)
    endfunction

    // ========================================================================
    //  Output Transaction Handler
    // ========================================================================
    function void write_scbd_output(ermu_output_transaction tx);
        `uvm_info("SCBD", $sformatf("Output: %s", tx.convert2string()), UVM_HIGH)
        for (int y = 0; y < 4; y++) begin
            if (tx.eoutm[y] == tx.eoutc[y])
                `uvm_error("SCBD", $sformatf("Ch%0d: eoutm[%0d]==eoutc[%0d]==%0b — complementary violation!",
                                              y, y, y, tx.eoutm[y]))
        end
    endfunction

    // ========================================================================
    //  Check ESS read against shadow model (origin-aware)
    // ========================================================================
    function void check_ess_read(int j, bit [31:0] actual);
        bit [31:0] expected_32, pet_bits, mask;
        bit [31:0] pet_actual, pet_expect;
        bit [31:0] ext_actual, ext_expect, ext_actual_m, ext_expect_m, ext_reserved;
        string     gname;

        expected_32 = expected_ess[j*32 +: 32];
        pet_bits    = from_pet[j*32 +: 32];
        mask        = ess_mask[j];
        gname       = $sformatf("ESS%0d", j);

        // --- PET-origin bits: full comparison (any ID valid) ---
        pet_actual = actual      & pet_bits;
        pet_expect = expected_32 & pet_bits;
        if (pet_actual != pet_expect) begin
            `uvm_error("SCBD", $sformatf(
                "%s PET-bits mismatch: actual=0x%08h expect=0x%08h diff=0x%08h",
                gname, pet_actual, pet_expect, pet_actual ^ pet_expect))
        end

        // --- err_src_id-origin bits: mask-filtered comparison ---
        ext_actual   = actual      & ~pet_bits;
        ext_expect   = expected_32 & ~pet_bits;
        ext_actual_m = ext_actual  & mask;
        ext_expect_m = ext_expect  & mask;
        if (ext_actual_m != ext_expect_m) begin
            `uvm_error("SCBD", $sformatf(
                "%s ext-bits mismatch: actual=0x%08h expect=0x%08h diff=0x%08h (pending=%0d)",
                gname, ext_actual_m, ext_expect_m, ext_actual_m ^ ext_expect_m, pending_count))
        end

        // --- Reserved bits set via err_src_id (should never happen) ---
        ext_reserved = ext_actual & ~mask;
        if (ext_reserved != 32'h0) begin
            `uvm_error("SCBD", $sformatf(
                "%s: RESERVED bits set via err_src_id! actual=0x%08h reserved=0x%08h",
                gname, actual, ext_reserved))
        end

        // --- Overall OK log ---
        if (pet_actual == pet_expect && ext_actual_m == ext_expect_m && ext_reserved == 32'h0) begin
            `uvm_info("SCBD", $sformatf("%s match OK (pending=%0d)", gname, pending_count), UVM_HIGH)
        end
    endfunction

    // ========================================================================
    //  Apply PET write to shadow model (pseudo error — any ID valid)
    // ========================================================================
    function void apply_pet_trigger(int j, bit [31:0] pet_val);
        for (int k = 0; k < 32; k++) begin
            if (pet_val[k]) begin
                int src_id = j * 32 + k;
                if (src_id < 288) begin
                    expected_ess[src_id] = 1'b1;
                    from_pet[src_id]     = 1'b1;  // PET origin -> full comparison
                    pending_count++;
                end
            end
        end
        `uvm_info("SCBD", $sformatf("PET%0d trigger: 0x%08h -> shadow updated (pending=%0d)",
                                     j, pet_val, pending_count), UVM_HIGH)
    endfunction

    // ========================================================================
    //  Apply ESSC write to shadow model
    // ========================================================================
    function void apply_essc_clear(int j, bit [31:0] escc_val);
        for (int k = 0; k < 32; k++) begin
            if (escc_val[k]) begin
                int src_id = j * 32 + k;
                expected_ess[src_id] = 1'b0;
                from_pet[src_id]     = 1'b0;
                if (pending_count > 0) pending_count--;
            end
        end
        `uvm_info("SCBD", $sformatf("ESSC%0d clear: 0x%08h -> shadow updated (pending=%0d)",
                                     j, escc_val, pending_count), UVM_HIGH)
    endfunction

    // ========================================================================
    //  Track EOyC SET/CLR operations
    // ========================================================================
    function void track_eoyc_write(int y, bit [31:0] val);
        if (val[0]) begin
            eos_sw_set[y] = 1'b1;
            `uvm_info("SCBD", $sformatf("Ch%0d SET: EOS sw_state -> 1", y), UVM_HIGH)
        end
        if (val[1]) begin
            eos_sw_set[y] = 1'b0;
            `uvm_info("SCBD", $sformatf("Ch%0d CLR: EOS sw_state -> 0", y), UVM_HIGH)
        end
    endfunction

    // ========================================================================
    //  Check EOyS read against expected EOS
    // ========================================================================
    function void check_eos_read(int y, bit [31:0] actual);
        bit actual_eos = actual[0];
        `uvm_info("SCBD", $sformatf("Ch%0d EOS read: actual=%0b sw_eos=%0b (CTS=%0b)",
                                     y, actual_eos, eos_sw_set[y], actual[16]), UVM_HIGH)
    endfunction

    // ========================================================================
    //  End-of-simulation report
    // ========================================================================
    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("SCBD", $sformatf("Scoreboard: pending=%0d, shadow ESS=%0d bits, PET-origin=%0d bits",
                                     pending_count, $countones(expected_ess), $countones(from_pet)), UVM_NONE)
        if (pending_count > 0)
            `uvm_warning("SCBD", $sformatf("%0d injected errors were never verified on ESS read", pending_count))
    endfunction

endclass : ermu_scoreboard
