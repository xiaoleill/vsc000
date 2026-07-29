# WP Extract Makefile
# Usage: make <target> [ARGS="..."]

PYTHON := python3
SCRIPT := scripts/extract_wp.py
TEST_PLAN := "test/FunctionalSafety/part2/C044_Safety plan.xlsx"
TEST_DIR  := test/FunctionalSafety
OUT_DIR   := output

# ---- Default target ----
.PHONY: help
help:
	@echo "WP Extract — Functional Safety WP Document Information Extractor"
	@echo ""
	@echo "  make log        Log-only mode (dir tree + match results, no Excel)"
	@echo "  make tr         Generate TR report"
	@echo "  make sc         Generate Safety Case report"
	@echo "  make both       Generate both TR + Safety Case (incremental)"
	@echo "  make both-new   Generate both (fresh, skip incremental diff)"
	@echo "  make tr-new     Fresh TR report (skip incremental diff)"
	@echo "  make sc-new     Fresh Safety Case report"
	@echo "  make tr-phase   TR report for specific phases (requires PHASE=)"
	@echo "  make clean      Remove generated output files"
	@echo "  make install    Install Python dependencies"
	@echo ""
	@echo "  Custom args: make tr PLAN=<path> DIR=<path> OUT=<path>"
	@echo "               make sc PLAN=<path> DIR=<path> OUT=<path>"
	@echo "               make both PLAN=<path> DIR=<path> OUT=<path> SC_OUT=<path>"
	@echo "  Phase filter: make tr-phase PHASE=PAC_01,PAC_03"

# ---- Log-only mode ----
.PHONY: log
log:
	$(PYTHON) $(SCRIPT) $(or $(PLAN),$(TEST_PLAN)) -d $(or $(DIR),$(TEST_DIR))

# ---- TR report ----
.PHONY: tr
tr:
	$(PYTHON) $(SCRIPT) $(or $(PLAN),$(TEST_PLAN)) -d $(or $(DIR),$(TEST_DIR)) -tr $(or $(OUT),-o $(OUT_DIR)/report.xlsx)

.PHONY: tr-new
tr-new:
	$(PYTHON) $(SCRIPT) $(or $(PLAN),$(TEST_PLAN)) -d $(or $(DIR),$(TEST_DIR)) -tr --new $(or $(OUT),-o $(OUT_DIR)/report.xlsx)

.PHONY: tr-phase
tr-phase:
	$(PYTHON) $(SCRIPT) $(or $(PLAN),$(TEST_PLAN)) -d $(or $(DIR),$(TEST_DIR)) -tr $(or $(OUT),-o $(OUT_DIR)/report.xlsx) --phase=$(PHASE)

# ---- Safety Case ----
.PHONY: sc
sc:
	$(PYTHON) $(SCRIPT) $(or $(PLAN),$(TEST_PLAN)) -d $(or $(DIR),$(TEST_DIR)) -sc $(or $(OUT),-o $(OUT_DIR)/safetycase.xlsx)

.PHONY: sc-new
sc-new:
	$(PYTHON) $(SCRIPT) $(or $(PLAN),$(TEST_PLAN)) -d $(or $(DIR),$(TEST_DIR)) -sc --new $(or $(OUT),-o $(OUT_DIR)/safetycase.xlsx)

# ---- Both (incremental) ----
.PHONY: both
both:
	$(PYTHON) $(SCRIPT) $(or $(PLAN),$(TEST_PLAN)) -d $(or $(DIR),$(TEST_DIR)) -b -o $(or $(OUT),$(OUT_DIR)/report.xlsx) --sc-output $(or $(SC_OUT),$(OUT_DIR)/safetycase.xlsx)

.PHONY: both-new
both-new:
	$(PYTHON) $(SCRIPT) $(or $(PLAN),$(TEST_PLAN)) -d $(or $(DIR),$(TEST_DIR)) -b --new -o $(or $(OUT),$(OUT_DIR)/report.xlsx) --sc-output $(or $(SC_OUT),$(OUT_DIR)/safetycase.xlsx)

# ---- Utility ----
.PHONY: clean
clean:
	rm -f $(OUT_DIR)/*.xlsx $(OUT_DIR)/*.log *.log *_safetycase.xlsx WP_Extract_*.xlsx C044_extract_*.log
	@echo "Cleaned output files."

.PHONY: install
install:
	pip install -r scripts/requirements.txt
