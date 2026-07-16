// =============================================================================
//  ERMU Scoreboard — End-to-end checker
//  3 analysis ports: APB, input, output
// =============================================================================

`uvm_analysis_imp_decl(_scbd_apb)
`uvm_analysis_imp_decl(_scbd_input)
`uvm_analysis_imp_decl(_scbd_output)

class ermu_scoreboard extends uvm_component;

    `uvm_component_utils(ermu_scoreboard)

    uvm_analysis_imp_scbd_apb    #(apb_transaction,        ermu_scoreboard) apb_export;
    uvm_analysis_imp_scbd_input  #(ermu_input_transaction,  ermu_scoreboard) input_export;
    uvm_analysis_imp_scbd_output #(ermu_output_transaction, ermu_scoreboard) output_export;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        apb_export    = new("apb_export",    this);
        input_export  = new("input_export",  this);
        output_export = new("output_export", this);
    endfunction

    function void write_scbd_apb(apb_transaction tx);
        `uvm_info("SCBD", $sformatf("APB: %s", tx.convert2string()), UVM_DEBUG)
    endfunction

    function void write_scbd_input(ermu_input_transaction tx);
        `uvm_info("SCBD", $sformatf("Input: %s", tx.convert2string()), UVM_DEBUG)
    endfunction

    function void write_scbd_output(ermu_output_transaction tx);
        `uvm_info("SCBD", $sformatf("Output: %s", tx.convert2string()), UVM_DEBUG)
    endfunction

endclass : ermu_scoreboard
