// =============================================================================
//  ERMU Output Transaction — Captures DUT output signal state
// =============================================================================

class ermu_output_transaction extends uvm_sequence_item;

    `uvm_object_utils(ermu_output_transaction)

    // ---- Output signal state ----
    bit [3:0]   eoutm;          // EOUTyM state
    bit [3:0]   eoutc;          // EOUTyC state
    bit [1:0]   hpi_irq;        // HPI IRQ state
    bit [2:0]   lpi_irq;        // LPI IRQ state
    bit         srst_req;       // System reset request
    bit         arst_req;       // Application reset request
    bit         pssr;           // Port safe state request
    bit         ems_event;      // Emergency stop event
    bit [31:0]  status;         // Status output

    // ---- Event type for scoreboard matching ----
    typedef enum { EO_EVENT, HPI_EVENT, LPI_EVENT, RST_EVENT, PSSR_EVENT, EMS_EVENT } event_type_e;
    event_type_e event_type;

    function new(string name = "ermu_output_transaction");
        super.new(name);
    endfunction

    function string convert2string();
        return $sformatf("OUT: eoutm=%0b eoutc=%0b hpi=%0b lpi=%0b srst=%0b arst=%0b pssr=%0b ems=%0b",
                         eoutm, eoutc, hpi_irq, lpi_irq, srst_req, arst_req, pssr, ems_event);
    endfunction

endclass : ermu_output_transaction
