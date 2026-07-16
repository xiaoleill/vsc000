// =============================================================================
//  ERMU Output Coverage — Output signal behavior coverage
// =============================================================================

class ermu_output_coverage extends uvm_subscriber #(ermu_output_transaction);

    `uvm_component_utils(ermu_output_coverage)

    covergroup output_cg with function sample(bit [3:0] eoutm_val,
                                                bit [2:0] lpi_val,
                                                bit [1:0] hpi_val);
        coverpoint eoutm_val {
            bins all_zero  = {4'b0000};
            bins any_set   = {[4'b0001:4'b1111]};
        }
        coverpoint lpi_val {
            bins no_irq    = {3'b000};
            bins lpi0      = {3'b001};
            bins lpi1      = {3'b010};
            bins lpi2      = {3'b100};
        }
        coverpoint hpi_val {
            bins no_irq    = {2'b00};
            bins hpi0      = {2'b01};
            bins hpi1      = {2'b10};
        }
    endgroup : output_cg

    function new(string name, uvm_component parent);
        super.new(name, parent);
        output_cg = new();
    endfunction

    function void write(ermu_output_transaction t);
        output_cg.sample(t.eoutm, t.lpi_irq, t.hpi_irq);
    endfunction

endclass : ermu_output_coverage
