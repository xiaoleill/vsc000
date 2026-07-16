// =============================================================================
//  ERMU Input Transaction — Error source injection item
// =============================================================================

class ermu_input_transaction extends uvm_sequence_item;

    `uvm_object_utils(ermu_input_transaction)

    rand int          src_id;           // Error source ID (0~287)
    rand int          pulse_duration;   // Duration in clk_hrc cycles
         bit [283:0]  err_src_mask;     // Actual bus value to drive

    constraint valid_src_id {
        src_id inside {[0:287]};
    }
    constraint pulse_range {
        pulse_duration inside {[1:1000]};
    }

    function new(string name = "ermu_input_transaction");
        super.new(name);
    endfunction

    function string convert2string();
        return $sformatf("ErrorSrc id=%0d pulse=%0d cycles", src_id, pulse_duration);
    endfunction

endclass : ermu_input_transaction
