// =============================================================================
//  APB Transaction — Sequence Item for APB-like Bus
//  Constraint: pstrb == 4'b1111 for Word-only DUT access
// =============================================================================

class apb_transaction extends uvm_sequence_item;

    // ---- APB signal fields ----
    rand bit [11:0]  paddr;
    rand bit [31:0]  pwdata;
         bit [31:0]  prdata;
    rand bit         pwrite;       // 1=write, 0=read
    rand bit [3:0]   pstrb;        // byte strobes
         bit         pslverr;      // slave error response

    // ---- Meta-data ----
    string           op_name;      // "READ" or "WRITE" for logging

    `uvm_object_utils_begin(apb_transaction)
        `uvm_field_int (paddr,   UVM_ALL_ON)
        `uvm_field_int (pwdata,  UVM_ALL_ON)
        `uvm_field_int (prdata,  UVM_ALL_ON)
        `uvm_field_int (pwrite,  UVM_ALL_ON)
        `uvm_field_int (pstrb,   UVM_ALL_ON)
        `uvm_field_int (pslverr, UVM_ALL_ON)
    `uvm_object_utils_end

    // ---- Constraints ----
    constraint word_access_only {
        // DUT only supports Word (32-bit) write
        if (pwrite) pstrb == 4'b1111;
    }

    // ---- Constructor ----
    function new(string name = "apb_transaction");
        super.new(name);
    endfunction

    // ---- Helper methods ----
    function string convert2string();
        if (pwrite)
            return $sformatf("APB WRITE @ addr=0x%03h data=0x%08h strb=%0b",
                             paddr, pwdata, pstrb);
        else
            return $sformatf("APB READ  @ addr=0x%03h data=0x%08h slverr=%0b",
                             paddr, prdata, pslverr);
    endfunction

endclass : apb_transaction
