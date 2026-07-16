// =============================================================================
//  ERMU Environment Package
// =============================================================================

package ermu_env_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import apb_agent_pkg::*;
    import ermu_reg_pkg::*;
    import ermu_input_agent_pkg::*;
    import ermu_output_agent_pkg::*;

    // ---- Register-to-APB Adapter (placed here because it needs both
    //      apb_agent_pkg::apb_transaction and ermu_reg_pkg::ermu_reg_block) ----
    class ermu_reg2apb_adapter extends uvm_reg_adapter;

        `uvm_object_utils(ermu_reg2apb_adapter)

        function new(string name = "ermu_reg2apb_adapter");
            super.new(name);
            supports_byte_enable = 1;
            provides_responses   = 0;
        endfunction

        virtual function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
            apb_transaction tx = apb_transaction::type_id::create("tx");
            tx.paddr  = rw.addr[11:0];
            tx.pwdata = rw.data;
            tx.pwrite = (rw.kind == UVM_WRITE) ? 1'b1 : 1'b0;
            tx.pstrb  = 4'b1111;
            return tx;
        endfunction

        virtual function void bus2reg(uvm_sequence_item bus_item, ref uvm_reg_bus_op rw);
            apb_transaction tx;
            if (!$cast(tx, bus_item))
                `uvm_fatal("REG2APB", "Failed to cast bus_item to apb_transaction")
            rw.kind  = tx.pwrite ? UVM_WRITE : UVM_READ;
            rw.addr  = tx.paddr;
            rw.data  = tx.pwrite ? tx.pwdata : tx.prdata;
            rw.status = tx.pslverr ? UVM_NOT_OK : UVM_IS_OK;
        endfunction

    endclass : ermu_reg2apb_adapter

    `include "ermu_env_cfg.sv"
    `include "ermu_virtual_sequencer.sv"
    `include "ermu_predictor.sv"
    `include "ermu_scoreboard.sv"
    `include "ermu_coverage.sv"
    `include "ermu_env.sv"

endpackage : ermu_env_pkg
