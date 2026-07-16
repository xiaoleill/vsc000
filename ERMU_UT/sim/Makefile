# =============================================================================
#  ERMU UVM Verification Makefile
#  Run from: ERMU_UT/sim/
#  All paths are relative to this directory
# =============================================================================

# ---- Tool Configuration ----
XRUN      ?= xrun
IMC       ?= imc
UVMHOME   ?= CDNS-1.2
VERDI_HOME ?= /eda/synopsys/verdi
PLI_LIB    ?= $(VERDI_HOME)/share/PLI/IUS/linux64/boot/debpli.so

# ---- Project Paths (relative to sim/) ----
SCRIPTS_DIR  = ../scripts
RTL_DIR      = ..
LOG_DIR      = log
COV_DIR      = cov_results
WAVE_DIR     = waves
COMPILE_F    = $(SCRIPTS_DIR)/compile_ermu.f
COV_CONFIG   = ../cov/cov_config.tcl

# ---- Simulation Options ----
TOP_MODULE   = hdl_top
TIMESCALE    = 1ns/10ps
XRUN_OPTS    = -f $(COMPILE_F) -uvmhome $(UVMHOME) -uvm \
               -top $(TOP_MODULE) -timescale $(TIMESCALE) \
               -linedebug -access +rwc -assert -nowarn UEXPSC

# ---- Test List (all 16 tests) ----
TESTS = ermu_smoke_test       \
        ermu_reg_test         \
        ermu_cfglock_test     \
        ermu_error_src_test   \
        ermu_error_rsp_test   \
        ermu_error_mask_test  \
        ermu_pseudo_err_test  \
        ermu_hpi_test         \
        ermu_output_chan_test \
        ermu_timer_test       \
        ermu_prescaler_test   \
        ermu_pssr_test        \
        ermu_concurrent_test  \
        ermu_reset_test       \
        ermu_stress_test      \
        ermu_func_full_test

# ---- Default: help ----
.DEFAULT_GOAL := help

# ==============================================================================
#  PHASE 0: Help & Infrastructure
# ==============================================================================
.PHONY: help
help:
	@echo "====================================================================="
	@echo " ERMU UVM Verification — Makefile Targets"
	@echo "====================================================================="
	@echo ""
	@echo " Phase 0 — Infrastructure:"
	@echo "   make compile        : Compile & elaborate only (no simulation)"
	@echo "   make lint           : Run lint check only (slang + verible)"
	@echo "   make lint-fix       : Auto-fix common SV/UVM issues"
	@echo "   make dirs           : Create output directories"
	@echo "   make clean          : Remove all generated files"
	@echo ""
	@echo " Phase 1 — Sanity & Register:"
	@echo "   make smoke          : Run smoke test (quick sanity check)"
	@echo "   make reg_test       : Run register access test"
	@echo "   make cfglock        : Run config/permanent lock test"
	@echo ""
	@echo " Phase 2 — Error Source & Response:"
	@echo "   make err_src        : Run error source injection test (288 sources)"
	@echo "   make err_rsp        : Run error response type test"
	@echo "   make err_mask       : Run output mask test"
	@echo "   make pseudo         : Run pseudo error trigger test"
	@echo "   make hpi            : Run HPI routing test"
	@echo ""
	@echo " Phase 3 — Output Channels & Timers:"
	@echo "   make out_chan       : Run output channel test (4 channels)"
	@echo "   make timer          : Run clear/toggle/wait timer test"
	@echo "   make prescaler      : Run clock prescaler test"
	@echo "   make pssr           : Run port safe state request test"
	@echo ""
	@echo " Phase 4 — Stress & Corner:"
	@echo "   make concurrent     : Run multi-source concurrent test"
	@echo "   make reset_test     : Run reset-during-operation test"
	@echo "   make stress         : Run randomized stress test"
	@echo "   make full           : Run full functional test"
	@echo ""
	@echo " General:"
	@echo "   make test TEST=name : Run a specific test"
	@echo "   make test TEST=name SEED=123 : Run with specific seed"
	@echo "   make test TEST=name VERB=UVM_DEBUG : Run with max verbosity"
	@echo "   make test TEST=name GUI=1 : Run with SimVision GUI"
	@echo "   make wave TEST=name : Run with SHM waveform (SimVision)"
	@echo "   make wave_fsdb TEST=name : Run with FSDB waveform (Verdi)"
	@echo ""
	@echo " Regression:"
	@echo "   make regress        : Run all tests x 5 seeds (80 simulations)"
	@echo "   make regress_fast   : Run all tests x 1 seed (16 simulations)"
	@echo ""
	@echo " Coverage (IMC):"
	@echo "   make cov_test TEST=name : Run single test with coverage"
	@echo "   make cov_merge      : Merge all coverage databases"
	@echo "   make cov_report     : Generate line/toggle/condition reports"
	@echo "   make cov_gui        : Open IMC GUI on merged coverage"
	@echo "   make cov_grades     : Grade coverage (line>=95, toggle>=90, cond>=95)"
	@echo ""
	@echo " Results:"
	@echo "   make check          : Check all logs for UVM_ERROR / UVM_FATAL"
	@echo "   make check_fail     : Show only failing tests"
	@echo "   make check_pass     : Show only passing tests"
	@echo "   make summary        : Print test result summary table"
	@echo ""
	@echo " Variables (override with make VAR=value):"
	@echo "   TEST  = test name        (default: ermu_smoke_test)"
	@echo "   SEED  = random seed      (default: random)"
	@echo "   VERB  = UVM verbosity    (default: UVM_MEDIUM)"
	@echo "   GUI   = 1 to launch GUI  (default: 0)"
	@echo "   COV   = 1 to enable IMC  (default: 0)"
	@echo "====================================================================="

# ==============================================================================
#  PHASE 0: Infrastructure
# ==============================================================================
.PHONY: dirs
dirs:
	@mkdir -p $(LOG_DIR) $(COV_DIR) $(WAVE_DIR)

.PHONY: compile
# ==============================================================================
#  Lint + Auto-Fix
# ==============================================================================
LINT_SCRIPT = $(SCRIPTS_DIR)/auto_lint_fix.py

.PHONY: lint
lint: dirs
	@echo "[LINT] Running slang + verible checks..."
	@python $(LINT_SCRIPT) --check-only; \
	if [ $$? -eq 0 ]; then \
		echo "[LINT] No issues found"; \
	else \
		echo "[LINT] Issues found (see above). Run 'make lint-fix' to auto-fix, then review."; \
	fi

.PHONY: lint-fix
lint-fix: dirs
	@echo "[LINT-FIX] Auto-fixing common SV/UVM issues..."
	@python $(LINT_SCRIPT) --diff
	@echo ""
	@echo "[LINT-FIX] Review the diffs above, then run 'make compile'."
	@echo "           Backup files saved as *.sv.bak"

compile: dirs
	@echo "[COMPILE] Checking compilation + elaboration..."
	@$(XRUN) $(XRUN_OPTS) -elaborate \
		-log $(LOG_DIR)/compile.log 2>&1
	@if grep -qE "(Error|Fatal)" $(LOG_DIR)/compile.log; then \
		echo "[COMPILE] FAILED — check $(LOG_DIR)/compile.log"; \
		grep -nE "(Error|Fatal)" $(LOG_DIR)/compile.log; \
		echo ""; \
		echo "  If the errors are not auto-fixable, edit files manually"; \
		echo "  then re-run: make compile"; \
		exit 1; \
	else \
		echo "[COMPILE] PASSED"; \
	fi

.PHONY: clean
clean:
	@echo "[CLEAN] Removing generated files..."
	@rm -rf $(LOG_DIR)/* $(COV_DIR)/* $(WAVE_DIR)/* xcelium.d xrun.* .*.log
	@echo "[CLEAN] Done"

# ==============================================================================
#  GENERIC: Run a single test (with all options)
# ==============================================================================
TEST  ?= ermu_smoke_test
SEED  ?= random
VERB  ?= UVM_MEDIUM
GUI   ?= 0
COV   ?= 0
DUMP  ?= 0

.PHONY: test
test: dirs
	@echo "=================================================="
	@echo " TEST : $(TEST)"
	@echo " SEED : $(SEED)"
	@echo " VERB : $(VERB)"
	@echo "=================================================="
	@$(XRUN) $(XRUN_OPTS) \
		+UVM_TESTNAME=$(TEST) \
		+UVM_VERBOSITY=$(VERB) \
		-seed $(SEED) \
		$(if $(filter 1,$(COV)),-coverage all -covoverwrite -covtest $(TEST) -covfile $(COV_CONFIG) -covdir $(COV_DIR)/$(TEST)) \
		$(if $(filter 1,$(GUI)),-gui) \
		$(if $(filter 1,$(DUMP)),-input $(SCRIPTS_DIR)/dump_waves.tcl) \
		-log $(LOG_DIR)/$(TEST)_s$(SEED).log 2>&1; \
	EXIT_CODE=$$?; \
	if [ $$EXIT_CODE -ne 0 ]; then \
		echo ""; \
		echo "[RESULT] $(TEST) seed=$(SEED) : FAILED (exit $$EXIT_CODE)"; \
		echo "  Log: $(LOG_DIR)/$(TEST)_s$(SEED).log"; \
		echo ""; \
		echo "--- UVM_ERROR / UVM_FATAL ---"; \
		grep -nE "UVM_ERROR|UVM_FATAL" $(LOG_DIR)/$(TEST)_s$(SEED).log || true; \
		exit $$EXIT_CODE; \
	else \
		ERRORS=$$(grep -E "UVM_ERROR.*@" $(LOG_DIR)/$(TEST)_s$(SEED).log 2>/dev/null | wc -l); \
		FATALS=$$(grep -E "UVM_FATAL.*@" $(LOG_DIR)/$(TEST)_s$(SEED).log 2>/dev/null | wc -l); \
		if [ "$$ERRORS" -gt 0 ] || [ "$$FATALS" -gt 0 ]; then \
			echo "[RESULT] $(TEST) seed=$(SEED) : FAILED ($$ERRORS errors, $$FATALS fatals)"; \
			grep -nE "UVM_ERROR|UVM_FATAL" $(LOG_DIR)/$(TEST)_s$(SEED).log; \
			exit 1; \
		else \
			echo "[RESULT] $(TEST) seed=$(SEED) : PASSED"; \
		fi; \
	fi

# ---- Waveform debug (run + dump + optionally open GUI) ----
.PHONY: wave
wave:
	@$(MAKE) test TEST=$(TEST) DUMP=1 SEED=$(SEED) VERB=$(VERB)

# ---- FSDB waveform (Verdi PLI required) ----
# Prerequisite: export VERDI_HOME=/path/to/verdi
.PHONY: wave_fsdb
wave_fsdb: dirs
	@if [ -z "$(VERDI_HOME)" ]; then \
		echo "[ERROR] VERDI_HOME not set. Export it first:"; \
		echo "        export VERDI_HOME=/path/to/verdi_install"; \
		exit 1; \
	fi
	@echo "[WAVE_FSDB] Running $(TEST) with FSDB dump..."
	@export LD_LIBRARY_PATH=$(VERDI_HOME)/share/PLI/IUS/linux64/boot:$$LD_LIBRARY_PATH; \
	$(XRUN) $(XRUN_OPTS) \
		+UVM_TESTNAME=$(TEST) \
		+UVM_VERBOSITY=$(VERB) \
		-seed $(SEED) \
		-loadpli1 debpli:novas_pli_boot \
		-input $(SCRIPTS_DIR)/dump_fsdb.tcl \
		-log $(LOG_DIR)/$(TEST)_fsdb.log 2>&1
	@echo "[WAVE_FSDB] Done: waves/ermu.fsdb"
	@echo "  Open with: verdi -ssf waves/ermu.fsdb &"

# ==============================================================================
#  PHASE 1: Sanity & Register Tests
# ==============================================================================
.PHONY: smoke
smoke:
	@$(MAKE) test TEST=ermu_smoke_test

.PHONY: reg_test
reg_test:
	@$(MAKE) test TEST=ermu_reg_test

.PHONY: cfglock
cfglock:
	@$(MAKE) test TEST=ermu_cfglock_test

# ==============================================================================
#  PHASE 2: Error Source & Response Tests
# ==============================================================================
.PHONY: err_src
err_src:
	@$(MAKE) test TEST=ermu_error_src_test

.PHONY: err_rsp
err_rsp:
	@$(MAKE) test TEST=ermu_error_rsp_test

.PHONY: err_mask
err_mask:
	@$(MAKE) test TEST=ermu_error_mask_test

.PHONY: pseudo
pseudo:
	@$(MAKE) test TEST=ermu_pseudo_err_test

.PHONY: hpi
hpi:
	@$(MAKE) test TEST=ermu_hpi_test

# ==============================================================================
#  PHASE 3: Output Channels & Timers
# ==============================================================================
.PHONY: out_chan
out_chan:
	@$(MAKE) test TEST=ermu_output_chan_test

.PHONY: timer
timer:
	@$(MAKE) test TEST=ermu_timer_test

.PHONY: prescaler
prescaler:
	@$(MAKE) test TEST=ermu_prescaler_test

.PHONY: pssr
pssr:
	@$(MAKE) test TEST=ermu_pssr_test

# ==============================================================================
#  PHASE 4: Stress & Corner Cases
# ==============================================================================
.PHONY: concurrent
concurrent:
	@$(MAKE) test TEST=ermu_concurrent_test

.PHONY: reset_test
reset_test:
	@$(MAKE) test TEST=ermu_reset_test

.PHONY: stress
stress:
	@$(MAKE) test TEST=ermu_stress_test

.PHONY: full
full:
	@$(MAKE) test TEST=ermu_func_full_test

# ==============================================================================
#  REGRESSION
# ==============================================================================
REGRESS_SEEDS = 1 42 123 999 2048
REGRESS_SEED1 = 1

.PHONY: regress
regress: dirs
	@echo "============================================================"
	@echo " REGRESSION: $(words $(TESTS)) tests x $(words $(REGRESS_SEEDS)) seeds"
	@echo " Total: $(shell echo $$(( $(words $(TESTS)) * $(words $(REGRESS_SEEDS)) ))) simulations"
	@echo "============================================================"
	@PASS=0; FAIL=0; TOTAL=0; \
	for test in $(TESTS); do \
		for seed in $(REGRESS_SEEDS); do \
			TOTAL=$$((TOTAL + 1)); \
			echo "[$$TOTAL] $$test seed=$$seed ..."; \
			$(XRUN) $(XRUN_OPTS) \
				+UVM_TESTNAME=$$test \
				+UVM_VERBOSITY=UVM_LOW \
				-seed $$seed \
				-log $(LOG_DIR)/$${test}_s$${seed}.log \
				-xmlibdirname xcelium.d/$${test}_s$${seed} \
				> $(LOG_DIR)/$${test}_s$${seed}.stdout 2>&1; \
			RC=$$?; \
			ERRS=$$(grep -E "UVM_ERROR.*@" $(LOG_DIR)/$${test}_s$${seed}.log 2>/dev/null | wc -l); \
			FATS=$$(grep -E "UVM_FATAL.*@" $(LOG_DIR)/$${test}_s$${seed}.log 2>/dev/null | wc -l); \
			if [ $$RC -ne 0 ] || [ "$$ERRS" -gt 0 ] || [ "$$FATS" -gt 0 ]; then \
				echo "  => FAILED (exit=$$RC, errors=$$ERRS, fatals=$$FATS)"; \
				FAIL=$$((FAIL + 1)); \
			else \
				echo "  => PASSED"; \
				PASS=$$((PASS + 1)); \
			fi; \
		done; \
	done; \
	echo ""; \
	echo "============================================================"; \
	echo " REGRESSION COMPLETE"; \
	echo "   Total : $$TOTAL"; \
	echo "   Passed: $$PASS"; \
	echo "   Failed: $$FAIL"; \
	echo "============================================================"

.PHONY: regress_fast
regress_fast: dirs
	@echo "[REGRESS FAST] $(words $(TESTS)) tests x 1 seed"
	@PASS=0; FAIL=0; \
	for test in $(TESTS); do \
		echo "--- $$test ---"; \
		if $(MAKE) --no-print-directory test TEST=$$test SEED=$(REGRESS_SEED1) VERB=UVM_LOW; then \
			PASS=$$((PASS + 1)); \
		else \
			FAIL=$$((FAIL + 1)); \
		fi; \
	done; \
	echo "========================================"; \
	echo " FAST REGRESSION: $$PASS passed, $$FAIL failed"

# ==============================================================================
#  COVERAGE (IMC)
# ==============================================================================
.PHONY: cov_test
cov_test:
	@$(MAKE) test TEST=$(TEST) COV=1 SEED=$(SEED)

.PHONY: cov_regress
cov_regress: dirs
	@echo "[COV REGRESS] Running all tests with coverage enabled..."
	@for test in $(TESTS); do \
		$(MAKE) --no-print-directory test TEST=$$test COV=1 SEED=1 VERB=UVM_LOW; \
	done
	@$(MAKE) cov_merge
	@$(MAKE) cov_report

.PHONY: cov_merge
cov_merge:
	@echo "[IMC] Merging coverage databases..."
	@$(IMC) -batch -exec $(SCRIPTS_DIR)/imc_merge.tcl
	@echo "[IMC] Merge complete: $(COV_DIR)/merged_cov"

.PHONY: cov_report
cov_report:
	@echo "[IMC] Generating coverage reports..."
	@$(IMC) -batch -exec $(SCRIPTS_DIR)/imc_report.tcl
	@echo "[IMC] Reports generated in $(COV_DIR)/"
	@echo ""
	@echo "--- Line Coverage ---"
	@grep -A5 "Line" $(COV_DIR)/ermu_metrics.txt 2>/dev/null || echo "(run cov_merge first)"
	@echo ""
	@echo "--- Toggle Coverage ---"
	@grep -A5 "Toggle" $(COV_DIR)/ermu_metrics.txt 2>/dev/null || echo "(run cov_merge first)"
	@echo ""
	@echo "--- Condition Coverage ---"
	@grep -A5 "Condition" $(COV_DIR)/ermu_metrics.txt 2>/dev/null || echo "(run cov_merge first)"

.PHONY: cov_gui
cov_gui:
	@echo "[IMC] Launching GUI on merged coverage..."
	@$(IMC) -gui -load $(COV_DIR)/merged_cov &

.PHONY: cov_grades
cov_grades:
	@echo "[IMC] Grading coverage against goals (line>=95, toggle>=90, condition>=95)..."
	@$(IMC) -batch -exec $(SCRIPTS_DIR)/imc_report.tcl 2>&1 | grep -E "(grade|PASS|FAIL|metric)" || true

# ==============================================================================
#  RESULTS CHECKING
# ==============================================================================
.PHONY: check
check:
	@echo "============================================================"
	@echo " Checking all simulation logs for errors..."
	@echo "============================================================"
	@TOTAL=0; PASS=0; FAIL=0; \
	for log in $(LOG_DIR)/*.log; do \
		[ -f "$$log" ] || continue; \
		TOTAL=$$((TOTAL + 1)); \
		NAME=$$(basename $$log .log); \
		ERRS=$$(grep -E "UVM_ERROR.*@" $$log 2>/dev/null | wc -l); \
		FATS=$$(grep -E "UVM_FATAL.*@" $$log 2>/dev/null | wc -l); \
		if [ "$$ERRS" -gt 0 ] || [ "$$FATS" -gt 0 ]; then \
			echo "  [FAIL] $$NAME (errors=$$ERRS, fatals=$$FATS)"; \
			FAIL=$$((FAIL + 1)); \
		else \
			echo "  [PASS] $$NAME"; \
			PASS=$$((PASS + 1)); \
		fi; \
	done; \
	echo ""; \
	echo "  Total: $$TOTAL  Passed: $$PASS  Failed: $$FAIL"; \
	if [ $$FAIL -gt 0 ]; then exit 1; fi

.PHONY: check_fail
check_fail:
	@echo "=== FAILING TESTS ==="
	@for log in $(LOG_DIR)/*.log; do \
		[ -f "$$log" ] || continue; \
		NAME=$$(basename $$log .log); \
		ERRS=$$(grep -E "UVM_ERROR.*@" $$log 2>/dev/null | wc -l); \
		FATS=$$(grep -E "UVM_FATAL.*@" $$log 2>/dev/null | wc -l); \
		if [ "$$ERRS" -gt 0 ] || [ "$$FATS" -gt 0 ]; then \
			echo ""; \
			echo "--- $$NAME (errors=$$ERRS, fatals=$$FATS) ---"; \
			grep -nE "UVM_ERROR|UVM_FATAL" $$log; \
		fi; \
	done

.PHONY: check_pass
check_pass:
	@echo "=== PASSING TESTS ==="
	@for log in $(LOG_DIR)/*.log; do \
		[ -f "$$log" ] || continue; \
		NAME=$$(basename $$log .log); \
		ERRS=$$(grep -E "UVM_ERROR.*@" $$log 2>/dev/null | wc -l); \
		FATS=$$(grep -E "UVM_FATAL.*@" $$log 2>/dev/null | wc -l); \
		if [ "$$ERRS" -eq 0 ] && [ "$$FATS" -eq 0 ]; then \
			echo "  [PASS] $$NAME"; \
		fi; \
	done

.PHONY: summary
summary:
	@echo "============================================================"
	@echo "              ERMU UVM Regression Summary"
	@echo "============================================================"
	@printf "%-40s %-10s %-8s %-8s %s\n" "TEST" "SEED" "ERRORS" "FATALS" "RESULT"
	@echo "---------------------------------------------------------------------------"
	@for log in $(LOG_DIR)/*.log; do \
		[ -f "$$log" ] || continue; \
		FULL=$$(basename $$log .log); \
		TEST=$$(echo $$FULL | sed 's/_s[0-9]*$$//'); \
		SEED=$$(echo $$FULL | grep -oE 's[0-9]+$$' | sed 's/s//'); \
		ERRS=$$(grep -E "UVM_ERROR.*@" $$log 2>/dev/null | wc -l); \
		FATS=$$(grep -E "UVM_FATAL.*@" $$log 2>/dev/null | wc -l); \
		if [ "$$ERRS" -gt 0 ] || [ "$$FATS" -gt 0 ]; then \
			printf "%-40s %-10s %-8s %-8s \033[31m%s\033[0m\n" "$$TEST" "$$SEED" "$$ERRS" "$$FATS" "FAIL"; \
		else \
			printf "%-40s %-10s %-8s %-8s \033[32m%s\033[0m\n" "$$TEST" "$$SEED" "$$ERRS" "$$FATS" "PASS"; \
		fi; \
	done
	@echo "---------------------------------------------------------------------------"
