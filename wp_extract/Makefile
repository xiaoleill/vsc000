# WP Extract Makefile
# Usage: make <target> [PLAN=...] [DIR=...] [OUT=...] [SC_OUT=...]
#
# Windows (\-separated) paths: wrap in SINGLE QUOTES, e.g. PLAN='D:\mywork\...\file.xlsx'
#   The Makefile normalizes backslashes to forward slashes automatically.
#   Forward-slash paths need no quoting: PLAN=D:/mywork/.../file.xlsx
#   Paths with spaces: always use quotes around the full assignment.

PYTHON := python3
SCRIPT := scripts/extract_wp.py
TEST_PLAN := test/FunctionalSafety/part2/C044_Safety plan.xlsx
TEST_DIR  := test/FunctionalSafety
OUT_DIR   := output

# Normalize backslash → forward slash (Windows copy-paste friendly)
_PLAN    := $(subst \,/,$(PLAN))
_DIR     := $(subst \,/,$(DIR))
_OUT     := $(subst \,/,$(OUT))
_SC_OUT  := $(subst \,/,$(SC_OUT))

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
	@echo "               OUT / SC_OUT are file paths (no -o prefix needed)"
	@echo "  Windows paths: use single quotes  PLAN='D:\\mywork\\...\\file.xlsx'"
	@echo "  Phase filter:  make tr-phase PHASE=PAC_01,PAC_03"

# ---- Log-only mode ----
.PHONY: log
log:
	$(PYTHON) $(SCRIPT) "$(or $(_PLAN),$(TEST_PLAN))" -d "$(or $(_DIR),$(TEST_DIR))"

# ---- TR report ----
# When OUT is not set, pass the output directory; Python auto-names <project>_TR_view.xlsx
.PHONY: tr
tr:
	$(PYTHON) $(SCRIPT) "$(or $(_PLAN),$(TEST_PLAN))" -d "$(or $(_DIR),$(TEST_DIR))" -tr -o $(or $(_OUT),$(OUT_DIR))

.PHONY: tr-new
tr-new:
	$(PYTHON) $(SCRIPT) "$(or $(_PLAN),$(TEST_PLAN))" -d "$(or $(_DIR),$(TEST_DIR))" -tr --new -o $(or $(_OUT),$(OUT_DIR))

.PHONY: tr-phase
tr-phase:
	$(PYTHON) $(SCRIPT) "$(or $(_PLAN),$(TEST_PLAN))" -d "$(or $(_DIR),$(TEST_DIR))" -tr -o $(or $(_OUT),$(OUT_DIR)) --phase=$(PHASE)

# ---- Safety Case ----
# When OUT is not set, pass the output directory; Python auto-names <project>_safetycase.xlsx
.PHONY: sc
sc:
	$(PYTHON) $(SCRIPT) "$(or $(_PLAN),$(TEST_PLAN))" -d "$(or $(_DIR),$(TEST_DIR))" -sc -o $(or $(_OUT),$(OUT_DIR))

.PHONY: sc-new
sc-new:
	$(PYTHON) $(SCRIPT) "$(or $(_PLAN),$(TEST_PLAN))" -d "$(or $(_DIR),$(TEST_DIR))" -sc --new -o $(or $(_OUT),$(OUT_DIR))

# ---- Both: TR + Safety Case ----
# When OUT is not set, pass the output directory; Python handles both file names
# When OUT is set but SC_OUT is not, Python derives SC path from TR output directory
.PHONY: both
both:
	$(PYTHON) $(SCRIPT) "$(or $(_PLAN),$(TEST_PLAN))" -d "$(or $(_DIR),$(TEST_DIR))" -b -o $(or $(_OUT),$(OUT_DIR)) $(if $(_SC_OUT),--sc-output $(_SC_OUT))

.PHONY: both-new
both-new:
	$(PYTHON) $(SCRIPT) "$(or $(_PLAN),$(TEST_PLAN))" -d "$(or $(_DIR),$(TEST_DIR))" -b --new -o $(or $(_OUT),$(OUT_DIR)) $(if $(_SC_OUT),--sc-output $(_SC_OUT))

# ---- Utility ----
.PHONY: clean
clean:
	rm -f $(OUT_DIR)/*.xlsx $(OUT_DIR)/*.log *.log *_safetycase.xlsx WP_Extract_*.xlsx C044_extract_*.log
	@echo "Cleaned output files."

.PHONY: install
install:
	pip install -r scripts/requirements.txt
