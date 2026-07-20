// =============================================================================
//  ERMU PSSR Test — Port Safe State Request + EMS verification
// =============================================================================

class ermu_pssr_test extends ermu_base_test;

    `uvm_component_utils(ermu_pssr_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        uvm_status_e   st;
        uvm_reg_data_t rd;

        phase.raise_objection(this);
        wait_reset_release();
        `uvm_info("PSSR", "=== ERMU PSSR/EMS Test Start ===", UVM_NONE)

        env.reg_block.CFGLOCK.write(st, 32'h0000_BC00, UVM_FRONTDOOR, env.reg_block.reg_map);

        // ====================================================================
        //  PSSR: EOS trigger source
        // ====================================================================
        `uvm_info("PSSR", "--- PSSRS: EOS0 trigger ---", UVM_NONE)
        // PSSRS[16]=1: EOS0 triggers PSSR
        env.reg_block.EGC.write(st, 32'h0001_0000, UVM_FRONTDOOR, env.reg_block.reg_map); // PSSRS0=1
        env.reg_block.EOyC[0].write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map); // SET EOS
        #2000;
        env.reg_block.EOyS[0].read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("PSSR", $sformatf("EO0S=0x%08h (check pssr_o)", rd), UVM_MEDIUM);

        // Cleanup
        env.reg_block.EOyC[0].write(st, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map); // CLR
        env.reg_block.EGC.write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map);

        // ====================================================================
        //  PSSR: All disabled → pssr_o stays 0
        // ====================================================================
        `uvm_info("PSSR", "--- PSSRS=all-0: PSSR disabled ---", UVM_NONE)
        env.reg_block.EOyC[0].write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map); // SET EOS
        #2000;
        env.reg_block.EOyC[0].write(st, 32'h0000_0002, UVM_FRONTDOOR, env.reg_block.reg_map); // CLR

        // ====================================================================
        //  EMS: Register reset values
        // ====================================================================
        `uvm_info("PSSR", "--- EMS Register Reset ---", UVM_NONE)
        env.reg_block.EMSC.read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("PSSR", $sformatf("EMSC reset: 0x%08h (expect 0)", rd), UVM_MEDIUM);
        env.reg_block.EMSS.read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("PSSR", $sformatf("EMSS reset: 0x%08h (expect 0)", rd), UVM_MEDIUM);

        // ====================================================================
        //  EMS: Sync mode software trigger (EMSSET)
        // ====================================================================
        `uvm_info("PSSR", "--- EMS Sync Mode (EMSMOD=0) ---", UVM_NONE)
        // Enable EMS, sync mode, no inversion
        env.reg_block.EMSC.write(st, 32'h0001_0000, UVM_FRONTDOOR, env.reg_block.reg_map); // EMSEN=1

        // Software trigger
        env.reg_block.EMSC.write(st, 32'h0001_0001, UVM_FRONTDOOR, env.reg_block.reg_map); // EMSEN+EMSSET
        #2000;
        env.reg_block.EMSS.read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("PSSR", $sformatf("After EMSSET: EMSS=0x%08h", rd), UVM_MEDIUM);

        // Software clear
        env.reg_block.EMSC.write(st, 32'h0001_0002, UVM_FRONTDOOR, env.reg_block.reg_map); // EMSEN+EMSCLR
        #2000;
        env.reg_block.EMSS.read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("PSSR", $sformatf("After EMSCLR: EMSS=0x%08h", rd), UVM_MEDIUM);

        // ====================================================================
        //  EMS: Async mode (EMSMOD=1)
        // ====================================================================
        `uvm_info("PSSR", "--- EMS Async Mode (EMSMOD=1) ---", UVM_NONE)
        env.reg_block.EMSC.write(st, 32'h0003_0000, UVM_FRONTDOOR, env.reg_block.reg_map); // EMSEN+EMSMOD=1

        // EMSSET should be ignored in async mode
        env.reg_block.EMSC.write(st, 32'h0003_0001, UVM_FRONTDOOR, env.reg_block.reg_map); // EMSSET in async
        #2000;
        env.reg_block.EMSS.read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("PSSR", $sformatf("Async mode EMSSET: EMSS=0x%08h (expect 0, EMSSET ignored)", rd), UVM_MEDIUM);

        // Disable EMS
        env.reg_block.EMSC.write(st, 32'h0, UVM_FRONTDOOR, env.reg_block.reg_map);

        // ====================================================================
        //  EMS: Enable/disable control
        // ====================================================================
        `uvm_info("PSSR", "--- EMS Disabled ---", UVM_NONE)
        env.reg_block.EMSC.write(st, 32'h0000_0001, UVM_FRONTDOOR, env.reg_block.reg_map); // EMSSET, EMSEN=0
        #2000;
        env.reg_block.EMSS.read(st, rd, UVM_FRONTDOOR, env.reg_block.reg_map);
        `uvm_info("PSSR", $sformatf("EMSEN=0 with EMSSET: EMSS=0x%08h (expect 0, EMS disabled)", rd), UVM_MEDIUM);

        `uvm_info("PSSR", "=== ERMU PSSR/EMS Test End ===", UVM_NONE)
        phase.drop_objection(this);
    endtask

endclass : ermu_pssr_test
