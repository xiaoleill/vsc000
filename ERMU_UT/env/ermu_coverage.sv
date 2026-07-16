// =============================================================================
//  ERMU Functional Coverage Collector
// =============================================================================

class ermu_coverage extends uvm_subscriber #(ermu_output_transaction);

    `uvm_component_utils(ermu_coverage)

    // ---- Covergroup: Error output states ----
    covergroup eo_cg with function sample(int ch, bit eos_state);
        coverpoint ch {
            bins ch0 = {0}; bins ch1 = {1}; bins ch2 = {2}; bins ch3 = {3};
        }
        coverpoint eos_state {
            bins asserted  = {1};
            bins deasserted = {0};
        }
        cross ch, eos_state;
    endgroup : eo_cg

    // ---- Covergroup: Interrupt response types ----
    covergroup irq_cg with function sample(bit [2:0] lpi, bit [1:0] hpi,
                                           bit srst, bit arst);
        coverpoint lpi { bins lpi0={3'b001}; bins lpi1={3'b010}; bins lpi2={3'b100}; bins multi={[3'b011:3'b111]}; }
        coverpoint hpi { bins hpi0={2'b01}; bins hpi1={2'b10}; }
        coverpoint srst { bins req={1}; }
        coverpoint arst { bins req={1}; }
    endgroup : irq_cg

    function new(string name, uvm_component parent);
        super.new(name, parent);
        eo_cg  = new();
        irq_cg = new();
    endfunction

    function void write(ermu_output_transaction t);
        // Sample EOS state per channel (eoutm low = error = EOS asserted)
        for (int i = 0; i < 4; i++) begin
            eo_cg.sample(i, ~t.eoutm[i]); // eoutm=0 → EOS=1 (error asserted)
        end
        irq_cg.sample(t.lpi_irq, t.hpi_irq, t.srst_req, t.arst_req);
    endfunction

endclass : ermu_coverage
