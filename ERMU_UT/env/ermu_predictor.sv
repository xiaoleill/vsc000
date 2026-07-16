// =============================================================================
//  ERMU Predictor — Behavioral reference model
//  2 analysis ports: APB writes + error inputs
// =============================================================================

`uvm_analysis_imp_decl(_pred_apb)
`uvm_analysis_imp_decl(_pred_input)

class ermu_predictor extends uvm_component;

    `uvm_component_utils(ermu_predictor)

    ermu_reg_block   reg_block;

    uvm_analysis_imp_pred_apb   #(apb_transaction,           ermu_predictor) apb_imp;
    uvm_analysis_imp_pred_input #(ermu_input_transaction,     ermu_predictor) input_imp;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        apb_imp   = new("apb_imp",   this);
        input_imp = new("input_imp", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(ermu_reg_block)::get(this, "", "reg_block", reg_block))
            `uvm_fatal("PREDICTOR", "Register block not found in config_db")
    endfunction

    function void write_pred_apb(apb_transaction tx);
        `uvm_info("PREDICTOR", $sformatf("APB: %s", tx.convert2string()), UVM_DEBUG)
    endfunction

    function void write_pred_input(ermu_input_transaction tx);
        `uvm_info("PREDICTOR", $sformatf("Input: %s", tx.convert2string()), UVM_DEBUG)
    endfunction

endclass : ermu_predictor
