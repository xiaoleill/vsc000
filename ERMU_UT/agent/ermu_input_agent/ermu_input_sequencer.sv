// =============================================================================
//  ERMU Input Sequencer
// =============================================================================

class ermu_input_sequencer extends uvm_sequencer #(ermu_input_transaction);

    `uvm_component_utils(ermu_input_sequencer)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

endclass : ermu_input_sequencer
