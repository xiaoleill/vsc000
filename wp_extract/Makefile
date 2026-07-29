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
	@echo "WP Extract — 功能安全 WP 文档信息自动提取"
	@echo ""
	@echo "  make log        仅日志输出 (目录树+匹配结果, 无Excel)"
	@echo "  make tr         生成 TR 报告"
	@echo "  make sc         生成 Safety Case 报告"
	@echo "  make both       同时生成 TR + Safety Case"
	@echo "  make tr-new     全新生成 TR 报告 (不做增量 diff)"
	@echo "  make sc-new     全新生成 Safety Case 报告"
	@echo "  make tr-phase   指定阶段生成 TR 报告 (需 PHASE= 参数)"
	@echo "  make clean      清理输出文件"
	@echo "  make install    安装 Python 依赖"
	@echo ""
	@echo "  自定义参数: make tr PLAN=<path> DIR=<path> OUT=<path>"
	@echo "  阶段过滤:   make tr-phase PHASE=PAC_01,PAC_03"

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
	$(PYTHON) $(SCRIPT) $(or $(PLAN),$(TEST_PLAN)) -d $(or $(DIR),$(TEST_DIR)) -sc

.PHONY: sc-new
sc-new:
	$(PYTHON) $(SCRIPT) $(or $(PLAN),$(TEST_PLAN)) -d $(or $(DIR),$(TEST_DIR)) -sc --new

# ---- Both ----
.PHONY: both
both:
	$(PYTHON) $(SCRIPT) $(or $(PLAN),$(TEST_PLAN)) -d $(or $(DIR),$(TEST_DIR)) -b $(or $(OUT),-o $(OUT_DIR)/report.xlsx)

# ---- Utility ----
.PHONY: clean
clean:
	rm -f $(OUT_DIR)/*.xlsx $(OUT_DIR)/*.log *.log *_safetycase.xlsx WP_Extract_*.xlsx C044_extract_*.log
	@echo "Cleaned output files."

.PHONY: install
install:
	pip install -r scripts/requirements.txt
