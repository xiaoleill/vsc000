# WP Extract — 功能安全 WP 文档信息自动提取系统

> Version: v0.01  
> 用途：从 ISO 26262 功能安全项目的 Safety Plan 中提取 Output WP 关键词，在指定目录中搜索匹配文档，抽取元数据并生成 TR 审查报告。

---

## 1. 系统架构

```
wp_extract/
├── extract_wp.py              # 主入口 CLI
├── safety_plan_parser.py       # Safety Plan Excel 解析
├── file_matcher.py             # 文件发现 + 关键词模糊匹配
├── metadata_extractor.py       # 多格式文档元数据提取
├── report_generator.py         # TR 格式 Excel 报告生成
├── diff_engine.py              # 增量 diff 引擎（新旧报告对比）
├── synonym_config.json         # 同义词 + 项目元数据配置
├── safetycase_generator.py     # Safety Case 模板填充引擎（待实现）
├── requirements.txt            # Python 依赖
├── Safety case_template.xlsx   # Safety Case 模板（只读）
├── output/                     # 报告输出目录
└── test/                       # 测试数据
```

---

## 2. 命令行接口

### 2.1 基本用法

```bash
python extract_wp.py <safety_plan.xlsx> --doc-dir <文档目录> [选项]
```

### 2.2 必选参数

| 参数 | 说明 |
|------|------|
| `safety_plan` | `<project>_safety plan.xlsx` 路径 |
| `--doc-dir` / `-d` | WP 文档搜索目录 |

### 2.3 模式选择

| 参数 | 简写 | 行为 |
|------|------|------|
| （默认） | — | **Log-only**：解析 → 目录树 → 匹配 → log 输出，不生成 Excel |
| `--technical_review` | `-tr` | 生成 TR 格式报告（PAC_01~PAC_05） |
| `--safetycase` | `-sc` | 生成 Safety Case 报告（读模板 → 搜目录 → 填充） |
| `--both` | `-b` | 同时生成 TR + Safety Case |

### 2.4 可选参数

| 参数 | 简写 | 生效模式 | 说明 |
|------|------|---------|------|
| `--output` | `-o` | 全部 | 输出路径，默认 `WP_Extract_<timestamp>.xlsx` |
| `--min-score` | `-s` | 全部 | 匹配阈值 (0.0~1.0)，默认 0.5 |
| `--phase` | `-p` | **-tr** | 阶段过滤，支持 5 种语法 |
| `--new` | — | **-tr** | 全新生成 TR 报告（不做增量 diff） |
| `--delete-unmatched` | — | **-tr** | 增量模式下删除不再匹配的整行 |
| `--synonym-config` | — | 全部 | 同义词配置文件路径，默认 `synonym_config.json` |
| `--log-file` | `-l` | 全部 | 日志输出到文件 |

### 2.5 `--phase` 语法

| 语法 | 示例 | 含义 |
|------|------|------|
| 单值 | `--phase=PAC_02` | 仅 PAC_02 |
| 前置 `-` | `--phase=-PAC_02` | PAC_01 → PAC_02 |
| 尾部 `-` | `--phase=PAC_03-` | PAC_03 → 末尾 |
| 逗号列表 | `--phase=PAC_01,PAC_03` | PAC_01 + PAC_03 |
| 范围 | `--phase=PAC_02-PAC_04` | PAC_02 → PAC_04 |

---

## 3. 核心功能详解

### 3.1 Safety Plan 解析 (`safety_plan_parser.py`)

**输入**：`<project>_safety plan.xlsx` → Sheet `Safety Plan (schedule)`

**提取信息**：
- B 列：开发阶段（Charter → PAC_01 ~ PAC_05），通过合并单元格识别
- C/D 列：Task ID / FS Phase 名称
- E 列：Sub development flow
- L 列：Input 文档关键词（`\n` 分隔）
- **M 列：Output WP 文档关键词（`\n` 分隔）← 核心输入**
- Q/R/S/T 列：计划/实际开始/完成时间

**特殊处理**：
- 跳过 Charter 阶段本身，从 PAC_01 开始
- 独立括号行（如 `(specification phase)`）合并到前一个关键词
- 尾部 `"` 字符自动清理

### 3.2 文件匹配 (`file_matcher.py`)

**支持格式**：`.xlsx` / `.xlsm` / `.docx` / `.pptx` / `.pdf` / `.md`

**匹配规则**（按优先级）：

| 层级 | 规则 | 权重 |
|------|------|------|
| 精确匹配 | token 在文件名 token 列表中 | 1.0 |
| 同义词匹配 | token 与文件名 token 在同一同义词组 | 0.8 |
| 子串匹配 | token 是文件名 token 的子串（或反之） | 0.3 |
| 缩写词加权 | 括号中的缩写词（如 `(DFA)`）占最终分 70% 权重 | — |
| 模块标识符惩罚 | 同义词 map 中的 token 不匹配 → 分数 ×0.5 | — |
| 扩展名回退 | 关键词指定 `.docx` 但找不到 → 回退搜所有扩展名 | — |
| 特异性加分 | 同缩写匹配时，短文件名优先 | — |

**多缩写词拆分**：关键词含逗号/and 分隔的多个缩写（如 `"DFMEA, FMEA and DFA"`）→ 自动拆分为多个独立搜索，返回所有匹配文件。

**停用词过滤**：`and`、`the`、`pre`、`post` 等常见词不参与匹配。`can` **不是**停用词（CAN 是汽车总线协议名）。

### 3.3 元数据提取 (`metadata_extractor.py`)

| 格式 | 提取策略（优先级从高到低） |
|------|--------------------------|
| **Excel** | ① Title/Cover sheet 的 B/C 列键值对 ② Change History sheet 的 Revision 表格 ③ `read_only=True` 回退（处理 XML 损坏文件） |
| **Word** | ① SDT 内容控件（封面元数据卡片） ② 前 2 个表格（含 SDT 穿透读取） ③ 前 30 段落 `Label: Value` ④ docProps（兜底） |
| **PPT** | ① 第一张幻灯片（表格 → 文本框） ② docProps（兜底） |
| **PDF** | ① pdfplumber 首页文本+表格 ② PyMuPDF 首页文本 |
| **Markdown** | ① YAML frontmatter ② 前 50 行 `**Label:** Value` |

**提取字段**：Document No. / Revision / Author / Reviewer / Approver / Status / Date

**缺失标注**：找不到的字段统一显示 `NA`，单元格淡红背景。

### 3.4 TR 报告生成 (`report_generator.py`)

**输出格式**：每个 PAC 阶段一个 Sheet：

```
PAC_01 (FS-TR1)  ~  PAC_05 (FS-TR5)  +  Statistics
```

**可见列**：

| 列 | 内容 |
|----|------|
| A | No.（序号） |
| B | Work Products（WP 文档名/关键词） |
| C | Applicable?（Yes/Check/No） |
| D | Rational if not applicable |
| E | Document No. |
| F | Revision |
| G | Author |
| H | Reviewer |
| I | Approver |
| J | Status |
| K | Date |
| L | Note（匹配备注/格式警告） |
| M | Matched File（匹配文件路径） |

**隐藏列**（N~U）：Phase / Task ID / FS Phase / Sub Flow / Plan时间 ×4 / Actual时间 ×4

**Applicable? 判断逻辑**：

| 条件 | Applicable? |
|------|------------|
| 匹配到文件 + Status 含 Released | Yes |
| 匹配到文件 + Status 非 Released | Yes（Note 注明） |
| 未匹配 + 看起来是真实文档名 | Check |
| 未匹配 + 是描述性备注 | No（Rational 说明） |

**颜色标注**：

| 场景 | 颜色 |
|------|------|
| 默认 | 无背景 |
| 增量 diff 变更 | 淡绿 `#C6EFCE` |
| 值为 `NA` | 淡红 `#FFC7CE` |
| 未匹配行 | 淡黄 `#FFF2CC` |

### 3.5 增量 Diff (`diff_engine.py`)

默认行为：如果输出路径已存在旧报告 → 自动进入增量模式。

| 规则 | 触发条件 | 效果 |
|------|---------|------|
| 规则一 | 全部单元格 | 默认无背景 |
| 规则二 | 旧匹配 → 新未匹配 | 清空元数据（保留行骨架），log 报警 `[DROPPED]` |
| 规则三 | 值变化 | 单元格淡绿 + log 报警 `WARNING: updated CELL '<Sheet>'!<Ref> <old_value>` |

行匹配键：`(Sheet, Work Products, Document No., MatchedFile basename)` 四元组。

---

## 4. 同义词配置 (`synonym_config.json`)

### 4.1 项目元数据

```json
{
  "project_meta": {
    "project": "C044",
    "FSM": "Yaozongfu",
    "FSE": ["Sunxiaochun", "K. Takemura"],
    "Approver": "Niyongliang",
    "Teams": ["DesignTeam", "VerificationTeam", "FusaTeam"]
  }
}
```

### 4.2 同义词组

每组 `tokens` 内的所有词在匹配时等价。两个用途：

| 类型 | token 数 | 作用 | 示例 |
|------|---------|------|------|
| 同义词展开 | ≥2 | 匹配时互相替代 | `["efm", "flash", "fmc"]` |
| 模块标识符注册 | ≥1 | 不匹配时触发 ×0.5 惩罚 | `["rmu"]`, `["cmu"]` |

**修改方法**：编辑 `groups` 数组，增/删/改条目。单 token 的模块标识符也必须注册以确保惩罚生效。

---

## 5. 已解决的关键问题

| 问题 | 根因 | 修复 |
|------|------|------|
| docx 元数据全 NA | ① SDT 内容控件未被解析 ② docProps 优先级错置（模板作者≠文档作者） | 新增 SDT 解析，docProps 降为兜底 |
| docx Status 读不到 | 表格单元格内 SDT 下拉控件 `cell.text` 不解析 | `_cell_text_including_sdt()` 穿透 SDT 读取 |
| `"Approver"` 误匹配为 `"Revision"` | `re.search(r'ver\.?')` 匹配了 `"approver"` 内的 `"ver"` | 所有模式加 `\b` 词边界 |
| FMEA FMEDA.xlsx 全 NA | openpyxl XML 损坏（`pitchFamily` 负值） | `read_only=True` 回退 |
| PJ document number 匹配不到 | `re.match` 锚定在行首，`"PJ "` 前缀导致失败 | `re.match` → `re.search` |
| Production release report 只有 DocNo | Title sheet 找到 DocNo 后立即 break，跳过了 Change History | 跨 sheet 累积填充 + Change History 解析 |
| BUS→CMU 误匹配 | 扩展名 token + 模块标识符无惩罚 → 5/7=0.71>0.5 | ① 过滤扩展名 token ② 同义词 map token 不匹配 ×0.5 |
| RMU→CMU 仍误匹配 | 单 token 模块标识符被 `len(tokens)<2` 过滤跳过 | 移除 `len<2` 过滤，61 token 全部加载 |
| "can" 被停用词过滤 | `"can"` 在 STOP_WORDS 中 → CAN 协议名无法参与匹配 | 从 STOP_WORDS 移除 `"can"` |

---

## 6. 待实现功能（v0.02）

- [ ] `--technical_review / -tr` 模式
- [ ] `--safetycase / -sc` 模式（Safety Case 模板填充引擎）
- [ ] `--both / -b` 模式
- [ ] Log-only 模式（目录树输出）
- [ ] `project_meta` 集成

---

## 7. 依赖

```
openpyxl>=3.1.0
python-docx>=0.8.11
python-pptx>=0.6.21
pdfplumber>=0.10.0
PyMuPDF>=1.23.0
python-dateutil>=2.8.0
```
