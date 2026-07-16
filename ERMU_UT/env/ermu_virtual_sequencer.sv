// =============================================================================
//  ERMU Virtual Sequencer — Coordinates APB + Input sequencers
// =============================================================================

class ermu_virtual_sequencer extends uvm_sequencer;

    `uvm_component_utils(ermu_virtual_sequencer)

    apb_sequencer                apb_sqr;
    ermu_input_sequencer         input_sqr;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

endclass : ermu_virtual_sequencer
