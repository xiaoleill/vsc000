// =============================================================================
//  ERMU Predictor — Behavioral reference model
//  Tracks ERC configuration per source and predicts expected responses
// =============================================================================

`uvm_analysis_imp_decl(_pred_apb)
`uvm_analysis_imp_decl(_pred_input)

class ermu_predictor extends uvm_component;

    `uvm_component_utils(ermu_predictor)

    uvm_analysis_imp_pred_apb   #(apb_transaction,           ermu_predictor) apb_imp;
    uvm_analysis_imp_pred_input #(ermu_input_transaction,     ermu_predictor) input_imp;

    // ---- ERC response table (288 sources × 3-bit config) ----
    protected bit [2:0] erc_config [288];

    // ---- Register address decode ----
    protected bit [11:0] ERC_BASE = 12'h500;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        apb_imp   = new("apb_imp",   this);
        input_imp = new("input_imp", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        for (int i = 0; i < 288; i++) erc_config[i] = 3'h0;
        `uvm_info("PREDICTOR", "Reference model initialized (288 ERC entries)", UVM_MEDIUM)
    endfunction

    // ---- APB: track ERC writes ----
    function void write_pred_apb(apb_transaction tx);
        bit [11:0] addr = tx.paddr;
        if (addr >= ERC_BASE && addr < (ERC_BASE + 36 * 4) && tx.pwrite) begin
            int p = (addr - ERC_BASE) / 4;
            // Each ERC register configures 8 sources (3 bits + 1 reserved per source)
            for (int e = 0; e < 8; e++) begin
                int src_id = p * 8 + e;
                if (src_id < 288)
                    erc_config[src_id] = tx.pwdata[e*4 +: 3];
            end
            `uvm_info("PREDICTOR", $sformatf("ERC[%0d] configured: 0x%08h", p, tx.pwdata), UVM_HIGH)
        end
    endfunction

    // ---- Input: predict expected response ----
    function void write_pred_input(ermu_input_transaction tx);
        int    src_id = tx.src_id;
        bit [2:0] erc;
        string    resp_str;
        if (src_id < 0 || src_id > 287) return;
        erc = erc_config[src_id];
        case (erc)
            3'h0: resp_str = "NA";
            3'h1: resp_str = "RSV";
            3'h2: resp_str = "LPI0";
            3'h3: resp_str = "LPI1";
            3'h4: resp_str = "LPI2";
            3'h5: resp_str = "HPI";
            3'h6: resp_str = "APP_RST";
            3'h7: resp_str = "SYS_RST";
            default: resp_str = "UNKNOWN";
        endcase
        `uvm_info("PREDICTOR", $sformatf("Injection ID=%0d -> ERC=0x%0h (%s)",
                                          src_id, erc, resp_str), UVM_MEDIUM)
    endfunction

    // ---- Helper: get ERC config for a source ----
    function bit [2:0] get_erc(int src_id);
        if (src_id < 0 || src_id > 287) return 3'h0;
        return erc_config[src_id];
    endfunction

    // ---- Report ----
    function void report_phase(uvm_phase phase);
        int na_cnt, lpi_cnt, hpi_cnt, rst_cnt;
        super.report_phase(phase);
        na_cnt = 0; lpi_cnt = 0; hpi_cnt = 0; rst_cnt = 0;
        for (int i = 0; i < 288; i++) begin
            case (erc_config[i])
                3'h0, 3'h1: na_cnt++;
                3'h2, 3'h3, 3'h4: lpi_cnt++;
                3'h5: hpi_cnt++;
                3'h6, 3'h7: rst_cnt++;
            endcase
        end
        `uvm_info("PREDICTOR", $sformatf(
            "ERC summary: NA=%0d LPI=%0d HPI=%0d RST=%0d", na_cnt, lpi_cnt, hpi_cnt, rst_cnt), UVM_NONE)
    endfunction

endclass : ermu_predictor
