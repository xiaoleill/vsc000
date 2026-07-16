// =============================================================================
//  APB Protocol Coverage — Covers APB bus protocol behavior
// =============================================================================

class apb_coverage extends uvm_subscriber #(apb_transaction);

    `uvm_component_utils(apb_coverage)

    // ---- Covergroup: APB access types ----
    covergroup apb_access_cg with function sample(bit pwrite_val, bit slverr_val);
        coverpoint pwrite_val {
            bins write = {1'b1};
            bins read  = {1'b0};
        }
        coverpoint slverr_val {
            bins no_error  = {1'b0};
            bins has_error = {1'b1};
        }
        cross pwrite_val, slverr_val;
    endgroup : apb_access_cg

    function new(string name, uvm_component parent);
        super.new(name, parent);
        apb_access_cg = new();
    endfunction

    function void write(apb_transaction t);
        apb_access_cg.sample(t.pwrite, t.pslverr);
    endfunction

endclass : apb_coverage
