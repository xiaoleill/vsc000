# WP Extract — Functional Safety WP Document Information Extractor

Extract Output WP keywords from ISO 26262 Safety Plan, search project directories for matching documents, auto-extract metadata (Document No./Revision/Author etc.), and generate Technical Review / Safety Case reports.

## Quick Start

```bash
# Install dependencies
pip install -r scripts/requirements.txt

# Log-only mode (dir tree + match results, no Excel output)
make log

# Generate TR report
make tr

# Generate Safety Case report
make sc

# Generate both
make both
```

## Project Structure

```
wp_extract/
├── Makefile
├── .gitignore
├── scripts/                    # Python source
│   ├── extract_wp.py           # CLI entry point
│   ├── safety_plan_parser.py   # Safety Plan parser
│   ├── file_matcher.py         # Keyword matching engine
│   ├── metadata_extractor.py   # Multi-format metadata extractor
│   ├── report_generator.py     # TR report generator
│   ├── diff_engine.py          # Incremental diff engine
│   ├── safetycase_generator.py # Safety Case template filler
│   └── requirements.txt
├── doc/                        # Documentation
│   ├── README.md
│   └── DESIGN_SPEC.md
├── settings/                   # Configuration & templates
│   ├── synonym_config.json
│   ├── Safety case_template.xlsx
│   └── ref_C044_Safety case.xlsx
├── output/                     # Generated reports (gitignored)
└── test/                       # Test data (gitignored)
```

## CLI Reference

```
python scripts/extract_wp.py <safety_plan.xlsx> --doc-dir <dir> [options]
```

### Mode Selection

| Flag | Short | Behavior |
|------|-------|----------|
| (default) | — | Log-only: dir tree + match results, no Excel |
| `--technical_review` | `-tr` | Generate TR report (PAC_01~PAC_05) |
| `--safetycase` | `-sc` | Generate Safety Case report from template |
| `--both` | `-b` | Generate both TR + Safety Case |

### Options

| Flag | Short | Modes | Description |
|------|-------|-------|-------------|
| `--output` | `-o` | all | TR output path (`-tr`/`-b`), SC output path (`-sc` only) |
| `--sc-output` | — | `-b` | Safety Case output path (when using `-b`) |
| `--min-score` | `-s` | all | Matching threshold (0.0~1.0), default 0.5 |
| `--phase` | `-p` | `-tr` | Phase filter (5 syntaxes supported) |
| `--new` | — | `-tr`/`-sc` | Fresh generation (skip incremental diff) |
| `--delete-unmatched` | — | `-tr` | Delete rows when previously-matched WP becomes unmatched |
| `--synonym-config` | — | all | Path to synonym config JSON (default: `settings/synonym_config.json`) |
| `--log-file` | `-l` | all | Log output file (auto-generated if not specified) |

### `--phase` Syntax

| Example | Meaning |
|---------|---------|
| `--phase=PAC_02` | Only PAC_02 |
| `--phase=-PAC_02` | PAC_01 → PAC_02 |
| `--phase=PAC_03-` | PAC_03 → end |
| `--phase=PAC_01,PAC_03` | PAC_01 + PAC_03 |
| `--phase=PAC_02-PAC_04` | PAC_02 → PAC_04 |

## Makefile Targets

| Command | Description |
|---------|-------------|
| `make log` | Log-only mode |
| `make tr` | TR report (incremental) |
| `make tr-new` | TR report (fresh) |
| `make sc` | Safety Case (incremental) |
| `make sc-new` | Safety Case (fresh) |
| `make both` | Both reports (incremental) |
| `make both-new` | Both reports (fresh) |
| `make tr-phase PHASE=PAC_01` | TR with phase filter |
| `make clean` | Remove generated files |
| `make install` | Install Python dependencies |

Custom args: `make tr PLAN=<path> DIR=<path> OUT="output/report.xlsx"`

## Input Requirements

| File | Description |
|------|-------------|
| `<project>_safety plan.xlsx` | Safety Plan with `Safety Plan (schedule)` sheet |
| Document directory | Supports `.xlsx/.xlsm/.docx/.pptx/.pdf/.md` |

## Output

### TR Report (`-tr`)

One Excel file with per-phase sheets (PAC_01~PAC_05) + Statistics:

- Visible columns: No. / Work Products / Applicable? / Document No. / Revision / Author / Reviewer / Approver / Status / Date / Note / Matched File
- Hidden columns: Phase / Task ID / FS Phase / Sub Flow / Plan dates / Actual dates
- Cell coloring: changed → light green, unmatched row → light yellow, `NA` → light red

### Safety Case Report (`-sc`)

Copies template, fills three sheets:

- **Title**: project name, revision, FSM, Approver
- **Revision History**: appends new version row (increments 0.01→0.02→... in incremental mode)
- **Safety Case**: fills H-L columns for F="No" rows (matched files + metadata)
- Cell coloring: new/changed → light green, `NA` → light red (priority over green)

### Incremental Diff

Both `-tr` and `-sc` support incremental mode by default. When an existing output file is found, the script compares new results against the old report and highlights changes.

## Synonym Configuration

Edit `settings/synonym_config.json`:

- **`project_meta`**: project name, FSM, FSE, Approver, Teams
- **`groups`**: token equivalence groups. Multi-token groups enable synonym matching; single-token groups register module identifiers for penalty on mismatch.

```json
{
  "project_meta": { "project": "C044", "FSM": "Yaozongfu", ... },
  "groups": [
    { "name": "flash_memory", "tokens": ["efm", "flash", "fmc"] },
    { "name": "can_bus",     "tokens": ["can", "can-fd", "mcan"] },
    { "name": "rmu",         "tokens": ["rmu"] }
  ]
}
```

Per-project config: `--synonym-config=settings/synonym_config_c031.json`

## Notes

- Template `settings/Safety case_template.xlsx` is read-only — the script never modifies it
- Incremental mode compares against previous output, highlights changed cells in light green
- Dates are normalized to `YYYY-MM-DD` format
- Missing metadata fields display `NA` with light red background
