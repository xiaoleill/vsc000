// =============================================================================
//  ERMU Sequence Package — All virtual sequences + simple utility sequences
// =============================================================================

package ermu_seq_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import apb_agent_pkg::*;
    import ermu_reg_pkg::*;
    import ermu_input_agent_pkg::*;
    import ermu_output_agent_pkg::*;
    import ermu_env_pkg::*;

    // ---- Simple error injection sequence (single transaction) ----
    class ermu_simple_input_seq extends uvm_sequence #(ermu_input_transaction);

        `uvm_object_utils(ermu_simple_input_seq)

        int src_id         = 0;
        int pulse_duration = 5;

        function new(string name = "ermu_simple_input_seq");
            super.new(name);
        endfunction

        task body();
            ermu_input_transaction tx;
            tx = ermu_input_transaction::type_id::create("tx");
            tx.src_id = src_id;
            tx.pulse_duration = pulse_duration;
            start_item(tx);
            finish_item(tx);
        endtask

    endclass : ermu_simple_input_seq

    // ---- Base virtual sequence ----
    `include "ermu_base_vseq.sv"

endpackage : ermu_seq_pkg
