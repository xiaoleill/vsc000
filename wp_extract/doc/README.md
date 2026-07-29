# WP Extract — 功能安全 WP 文档信息自动提取工具

从 ISO 26262 Safety Plan 中提取 Output WP 关键词，在项目目录中搜索匹配文档，自动抽取元数据（Document No./Revision/Author 等），生成 Technical Review 审查报告。

## 快速开始

```bash
# 安装依赖
pip install -r requirements.txt

# 运行（默认 log-only 模式：仅输出目录树和匹配结果，不生成 Excel）
python extract_wp.py C044_Safety_plan.xlsx -d ./documents

# 生成 TR 报告
python extract_wp.py C044_Safety_plan.xlsx -d ./documents -tr -o report.xlsx

# 生成 Safety Case 报告
python extract_wp.py C044_Safety_plan.xlsx -d ./documents -sc -o C044_safetycase.xlsx

# 同时生成两者
python extract_wp.py C044_Safety_plan.xlsx -d ./documents -b
```

## 命令行参考

```
python extract_wp.py <safety_plan.xlsx> --doc-dir <目录> [选项]
```

### 模式选择

| 参数 | 简写 | 行为 |
|------|------|------|
| （默认） | — | 仅 log 输出，不生成 Excel |
| `--technical_review` | `-tr` | 生成 TR 审查报告（PAC_01~05） |
| `--safetycase` | `-sc` | 生成 Safety Case 报告 |
| `--both` | `-b` | 同时生成 TR + Safety Case |

### 其他参数

| 参数 | 简写 | 说明 |
|------|------|------|
| `--output` | `-o` | 输出路径 |
| `--min-score` | `-s` | 匹配阈值 (0.0~1.0)，默认 0.5 |
| `--phase` | `-p` | 阶段过滤（仅 -tr 模式） |
| `--new` | — | 全新生成（不做增量 diff，仅 -tr 模式） |
| `--delete-unmatched` | — | 删除不再匹配的整行（仅 -tr 模式） |
| `--synonym-config` | — | 同义词配置文件路径 |
| `--log-file` | `-l` | 日志输出到文件 |

### `--phase` 语法

| 命令 | 含义 |
|------|------|
| `--phase=PAC_02` | 仅 PAC_02 |
| `--phase=-PAC_02` | PAC_01 → PAC_02 |
| `--phase=PAC_03-` | PAC_03 → 末尾 |
| `--phase=PAC_01,PAC_03` | PAC_01 + PAC_03 |
| `--phase=PAC_02-PAC_04` | PAC_02 → PAC_04 |

## 输入要求

| 文件 | 说明 |
|------|------|
| `<project>_safety plan.xlsx` | Safety Plan，需包含 `Safety Plan (schedule)` sheet |
| 文档目录 | 支持 `.xlsx/.xlsm/.docx/.pptx/.pdf/.md` 格式 |

## 输出说明

### TR 报告（`-tr`）

一个 Excel 文件，包含 5 个阶段 Sheet + Statistics：

- 可见列：No. / Work Products / Applicable? / Document No. / Revision / Author / Reviewer / Approver / Status / Date / Note / Matched File
- 隐藏列：Phase / Task ID / FS Phase / Sub Flow / 计划时间 / 实际时间
- 增量模式：值变化 → 淡绿标注；未匹配 → 淡黄；元数据缺失 → `NA` 淡红

### Safety Case 报告（`-sc`）

基于 `Safety case_template.xlsx` 模板填充生成，填充 Title / Revision History / Safety Case 三个 sheet。

## 同义词配置

编辑 `synonym_config.json` 可自定义：

- **`project_meta`**：项目名、FSM、FSE、Approver、Teams
- **`groups`**：同义词组，同一组内 token 匹配时等价。单 token 组用于模块标识符注册（不匹配时惩罚降权）

```json
{
  "groups": [
    { "name": "flash_memory", "tokens": ["efm", "flash", "fmc"] },
    { "name": "can_bus",     "tokens": ["can", "can-fd", "mcan"] },
    { "name": "rmu",         "tokens": ["rmu"] }
  ]
}
```

不同项目使用不同配置：`--synonym-config=synonym_config_c031.json`

## 注意事项

- 模板文件 `Safety case_template.xlsx` 为只读，脚本不会修改或删除它
- 增量模式下自动比较旧报告，变更单元格淡绿标注并在 log 中输出 WARNING
- 日期自动统一为 `YYYY-MM-DD` 格式
- 找不到的元数据字段显示 `NA`（淡红背景）
