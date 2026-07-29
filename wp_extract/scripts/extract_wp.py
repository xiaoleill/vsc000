#!/usr/bin/env python3
"""
WP Document Information Extractor
==================================
Extracts text information from Work Product (WP) documents referenced in a
functional safety plan Excel file.

Usage:
    python extract_wp.py <safety_plan.xlsx> --doc-dir <directory> [--output <output.xlsx>]
                          [--min-score <0.0-1.0>]

Example:
    python extract_wp.py test/FunctionalSafety/part2/C044_Safety_plan.xlsx
           --doc-dir test/FunctionalSafety
           --output output/C044_WP_extract.xlsx
"""

import argparse
import os
import sys
from datetime import datetime

# Add current directory to path for module imports
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from safety_plan_parser import parse_safety_plan, WorkItem
from file_matcher import match_all_keywords, discover_files, MatchResult, load_synonym_config
from report_generator import generate_tr_report
from safetycase_generator import print_directory_tree, fill_safety_case_report


class TeeWriter:
    """Write to stdout and a log file simultaneously."""
    def __init__(self, *files):
        self.files = files

    def write(self, text):
        for f in self.files:
            try:
                f.write(text)
                f.flush()
            except (ValueError, OSError):
                pass

    def flush(self):
        for f in self.files:
            try:
                f.flush()
            except (ValueError, OSError):
                pass


# Standard phase order for range resolution
PHASE_ORDER = ['PAC_01', 'PAC_02', 'PAC_03', 'PAC_04', 'PAC_05']


def parse_phase_filter(phase_str: str) -> list[str]:
    """
    Parse the --phase argument into a list of phase names.

    Syntax:
        PAC_02            -> exact:                               ['PAC_02']
        -PAC_02           -> from first to PAC_02 (inclusive):    ['PAC_01', 'PAC_02']
        PAC_03-           -> from PAC_03 to last:                 ['PAC_03', 'PAC_04', 'PAC_05']
        PAC_01,PAC_03     -> exact list:                          ['PAC_01', 'PAC_03']
        PAC_02-PAC_04     -> range:                               ['PAC_02', 'PAC_03', 'PAC_04']
    """
    phase_str = phase_str.strip()

    # Leading dash: "-PAC_02" -> from first phase to PAC_02
    if phase_str.startswith('-') and not phase_str.startswith('--'):
        end = phase_str[1:].strip()
        if end in PHASE_ORDER:
            idx = PHASE_ORDER.index(end)
            return PHASE_ORDER[:idx + 1]
        return [end]

    # Comma-separated exact list: "PAC_01,PAC_03"
    if ',' in phase_str:
        return [p.strip() for p in phase_str.split(',') if p.strip()]

    # Trailing dash: "PAC_03-" -> from PAC_03 to end
    if phase_str.endswith('-'):
        start = phase_str[:-1].strip()
        if start in PHASE_ORDER:
            idx = PHASE_ORDER.index(start)
            return PHASE_ORDER[idx:]
        return [start]

    # Range: "PAC_02-PAC_04" (must have '-' but not at start or end)
    if '-' in phase_str:
        parts = phase_str.split('-', 1)
        start, end = parts[0].strip(), parts[1].strip()
        if start in PHASE_ORDER and end in PHASE_ORDER:
            si = PHASE_ORDER.index(start)
            ei = PHASE_ORDER.index(end)
            if si <= ei:
                return PHASE_ORDER[si:ei + 1]
            else:
                return PHASE_ORDER[ei:si + 1][::-1]
        return [start, end]

    # Single value: "PAC_02" -> exact match
    if phase_str in PHASE_ORDER:
        return [phase_str]

    # Unknown format, return as-is
    return [phase_str]


def filter_work_items(work_items: list[WorkItem], phases: list[str]) -> list[WorkItem]:
    """Filter work items to only include specified phases."""
    phase_set = set(phases)
    return [wi for wi in work_items if wi.phase in phase_set]


def main():
    parser = argparse.ArgumentParser(
        description='Extract WP document information from a safety plan Excel file.',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python extract_wp.py C044_Safety_plan.xlsx --doc-dir ./documents
  python extract_wp.py C044_Safety_plan.xlsx --doc-dir ./documents -o report.xlsx
  python extract_wp.py C044_Safety_plan.xlsx --doc-dir ./documents --phase=PAC_02
  python extract_wp.py C044_Safety_plan.xlsx --doc-dir ./documents --phase=-PAC_02
  python extract_wp.py C044_Safety_plan.xlsx --doc-dir ./documents --phase=PAC_03-
  python extract_wp.py C044_Safety_plan.xlsx --doc-dir ./documents --phase=PAC_02-PAC_04
        """,
    )

    parser.add_argument(
        'safety_plan',
        help='Path to the <project>_safety plan.xlsx file.',
    )
    parser.add_argument(
        '--doc-dir', '-d',
        required=True,
        help='Directory containing WP documents to search.',
    )
    parser.add_argument(
        '--output', '-o',
        default=None,
        help='Output Excel report path. Default: ./WP_Extract_<timestamp>.xlsx',
    )
    parser.add_argument(
        '--min-score', '-s',
        type=float,
        default=0.5,
        help='Minimum keyword matching score (0.0-1.0). Default: 0.5',
    )
    parser.add_argument(
        '--phase', '-p',
        default=None,
        help=(
            'Filter by development phase. Use --phase=<value> syntax.\n'
            '  --phase=PAC_02           -> only PAC_02\n'
            '  --phase=-PAC_02          -> PAC_01 through PAC_02\n'
            '  --phase=PAC_03-          -> PAC_03 through end\n'
            '  --phase=PAC_01,PAC_03    -> exact list (comma-separated)\n'
            '  --phase=PAC_02-PAC_04    -> range from PAC_02 to PAC_04'
        ),
    )
    parser.add_argument(
        '--technical_review', '-tr', action='store_true',
        help='Generate TR-format per-phase report (PAC_01~PAC_05).',
    )
    parser.add_argument(
        '--safetycase', '-sc', action='store_true',
        help='Generate Safety Case report from template.',
    )
    parser.add_argument(
        '--both', '-b', action='store_true',
        help='Generate both TR report and Safety Case report.',
    )
    parser.add_argument(
        '--new', action='store_true',
        help='(TR mode only) Generate a fresh report (disable incremental diff).',
    )
    parser.add_argument(
        '--delete-unmatched', action='store_true',
        help='(TR mode only) Delete entire row when a previously-matched WP is now unmatched.',
    )
    parser.add_argument(
        '--synonym-config',
        default=None,
        help='Path to synonym equivalence config JSON file. '
             'Default: ./settings/synonym_config.json',
    )
    parser.add_argument(
        '--log-file', '-l',
        default=None,
        help='Write console log to a text file in addition to stdout.',
    )

    args = parser.parse_args()

    # Validate inputs
    if not os.path.exists(args.safety_plan):
        print(f"ERROR: Safety plan file not found: {args.safety_plan}")
        sys.exit(1)

    if not os.path.isdir(args.doc_dir):
        print(f"ERROR: Document directory not found: {args.doc_dir}")
        sys.exit(1)

    if not 0.0 <= args.min_score <= 1.0:
        print("ERROR: --min-score must be between 0.0 and 1.0")
        sys.exit(1)

    # Default output path
    if args.output is None:
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        args.output = f'WP_Extract_{timestamp}.xlsx'

    # Ensure output directory exists
    output_dir = os.path.dirname(os.path.abspath(args.output))
    if output_dir and not os.path.exists(output_dir):
        os.makedirs(output_dir, exist_ok=True)

    # Setup log file (tee stdout + stderr to file)
    log_fh = None
    if not args.log_file:
        # Auto-generate default log name: <project>_extract_<timestamp>.log
        import json as _json
        cfg_path = args.synonym_config or os.path.join(
            os.path.dirname(os.path.abspath(__file__)), '..', 'settings', 'synonym_config.json')
        proj = 'WP'
        try:
            with open(cfg_path, 'r', encoding='utf-8') as _f:
                proj = _json.load(_f).get('project_meta', {}).get('project', 'WP')
        except Exception:
            pass
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        args.log_file = f'{proj}_extract_{timestamp}.log'

    log_dir = os.path.dirname(os.path.abspath(args.log_file))
    if log_dir and not os.path.exists(log_dir):
        os.makedirs(log_dir, exist_ok=True)
    log_fh = open(args.log_file, 'w', encoding='utf-8')
    sys.stdout = TeeWriter(sys.stdout, log_fh)
    sys.stderr = TeeWriter(sys.stderr, log_fh)

    doc_dir = os.path.abspath(args.doc_dir)

    print("=" * 60)
    print("WP Document Information Extractor")
    print("=" * 60)
    print(f"Safety Plan:  {args.safety_plan}")
    print(f"Doc Dir:      {doc_dir}")
    print(f"Output:       {args.output}")
    print(f"Min Score:    {args.min_score}")
    print(f"Mode:         {'Fresh' if args.new else 'Incremental'}")
    if args.delete_unmatched:
        print(f"              --delete-unmatched: ON")
    print()

    # Step 1: Parse safety plan
    print("[1/4] Parsing safety plan schedule...")
    all_work_items = parse_safety_plan(args.safety_plan)
    print(f"      Found {len(all_work_items)} work items across phases.")

    # Collect unique phases
    all_phases = sorted(set(wi.phase for wi in all_work_items))
    print(f"      All phases: {', '.join(all_phases)}")

    # Apply phase filter if specified
    if args.phase:
        target_phases = parse_phase_filter(args.phase)
        work_items = filter_work_items(all_work_items, target_phases)
        actual_phases = sorted(set(wi.phase for wi in work_items))
        print(f"      Phase filter: {args.phase} -> phases: {', '.join(actual_phases)}")
        print(f"      Filtered to {len(work_items)} work items.")
    else:
        work_items = all_work_items

    # Collect all unique keywords
    all_keywords = []
    seen_kw = set()
    for wi in work_items:
        for kw in wi.output_wps:
            kw_lower = kw.strip().lower()
            if kw_lower and kw_lower not in seen_kw:
                seen_kw.add(kw_lower)
                all_keywords.append(kw.strip())

    print(f"      Unique output WP keywords: {len(all_keywords)}")

    # Step 2: Discover files
    print()
    print("[2/4] Discovering document files...")
    all_files = discover_files(doc_dir)
    print(f"      Found {len(all_files)} supported files.")

    # Count by extension
    ext_counts = {}
    for f in all_files:
        ext = os.path.splitext(f)[1].lower()
        ext_counts[ext] = ext_counts.get(ext, 0) + 1
    for ext, count in sorted(ext_counts.items()):
        print(f"        {ext}: {count}")

    # Load synonym config
    synonym_map = load_synonym_config(args.synonym_config)
    config_display = args.synonym_config or 'settings/synonym_config.json (default)'
    # Count unique groups
    unique_sets = set(frozenset(v) for v in synonym_map.values()) if synonym_map else set()
    print(f"      Synonym config: {config_display} ({len(unique_sets)} groups)")

    # Step 3: Match keywords to files
    print()
    print("[3/4] Matching keywords to files...")
    match_results = match_all_keywords(all_keywords, doc_dir, args.min_score)
    matched_count = 0
    unmatched_count = 0
    total_files_matched = 0

    for kw in all_keywords:
        result = match_results.get(kw)
        if result and result.is_matched:
            matched_count += 1
            total_files_matched += len(result.matched_files)
            for i, fp in enumerate(result.matched_files):
                rel_path = os.path.relpath(fp, doc_dir)
                score = result.scores[i] if i < len(result.scores) else 0
                marker = "+" if i == 0 else " "
                mismatch_warn = ""
                if result.extension_mismatch and result.extension_expected:
                    actual_ext = os.path.splitext(fp)[1]
                    if actual_ext != result.extension_expected:
                        mismatch_warn = (f"  [!EXT] format mismatch: expected "
                                        f"{result.extension_expected}, got {actual_ext}")
                if len(result.matched_files) > 1:
                    print(f"  [{marker}MATCHED {score:.2f}] {kw[:55]:<55} -> {rel_path[:80]}")
                else:
                    print(f"  [MATCHED {score:.2f}] {kw[:55]:<55} -> {rel_path[:80]}")
                if mismatch_warn:
                    print(mismatch_warn)
        else:
            unmatched_count += 1
            score = result.best_score if result else 0
            if score > 0:
                print(f"  [LOW {score:.2f}] {kw[:55]:<55} -> (best score below threshold)")
            else:
                print(f"  [UNMATCHED]   {kw[:55]:<55} -> (no match found)")

    print(f"\n      Matched keywords: {matched_count}, Unmatched: {unmatched_count}")
    print(f"      Total file matches: {total_files_matched} (incl. multi-file keywords)")

    # Determine modes
    do_tr = args.technical_review or args.both
    do_sc = args.safetycase or args.both
    log_only = not do_tr and not do_sc

    # --- Directory Tree ---
    print()
    print("[4/4] Directory tree:")
    tree = print_directory_tree(doc_dir)
    print(tree)
    print(f"      ({len(all_files)} files)")

    # --- Log-only mode: skip Excel generation ---
    if log_only:
        print()
        print("=" * 60)
        print("Extraction complete! (log-only mode, no Excel output)")
        print(f"  Work items processed:   {len(work_items)}")
        print(f"  Keywords matched:       {matched_count}/{len(all_keywords)}")
        print(f"  Total file matches:     {total_files_matched}")
        if args.log_file:
            print(f"  Log file:               {args.log_file}")
        print("=" * 60)
        if log_fh:
            log_fh.close()
        return

    # --- TR mode ---
    if do_tr:
        print()
        print("[TR] Generating Technical Review report...")
        old_path = None
        if not args.new and args.output and os.path.exists(args.output):
            old_path = args.output
            print(f"      Incremental mode: comparing against {args.output}")

        tr_output = args.output or f'WP_Extract_{datetime.now().strftime("%Y%m%d_%H%M%S")}.xlsx'
        output_path = generate_tr_report(
            work_items, match_results, tr_output, doc_dir,
            old_report_path=old_path,
            delete_unmatched=args.delete_unmatched,
        )
        print(f"      TR Report saved to: {output_path}")

    # --- Safety Case mode ---
    if do_sc:
        print()
        print("[SC] Generating Safety Case report...")
        template_path = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                     '..', 'settings', 'Safety case_template.xlsx')
        if not os.path.exists(template_path):
            print(f"ERROR: Template not found: {template_path}")
            sys.exit(1)

        # Read project name from synonym config
        import json
        cfg_path = args.synonym_config or os.path.join(
            os.path.dirname(os.path.abspath(__file__)), '..', 'settings', 'synonym_config.json')
        project_name = 'C044'
        try:
            with open(cfg_path, 'r', encoding='utf-8') as f:
                cfg = json.load(f)
            project_name = cfg.get('project_meta', {}).get('project', 'C044')
        except Exception:
            pass
        sc_output = f'{project_name}_safetycase.xlsx'

        sc_path = fill_safety_case_report(
            template_path, doc_dir, sc_output,
            config_path=args.synonym_config,
            min_score=args.min_score,
            fresh=args.new,
        )
        print(f"      Safety Case saved to: {sc_path}")

    print()
    print("=" * 60)
    print("Extraction complete!")
    if args.phase:
        print(f"  Phase filter:           {args.phase}")
    print(f"  Work items processed:   {len(work_items)}")
    print(f"  Keywords matched:       {matched_count}/{len(all_keywords)}")
    print(f"  Total file matches:     {total_files_matched}")
    if do_tr:
        print(f"  TR Report:              {tr_output}")
    if do_sc:
        print(f"  Safety Case:            {sc_path}")
    if args.log_file:
        print(f"  Log file:               {args.log_file}")
    print("=" * 60)

    # Cleanup
    if log_fh:
        log_fh.close()


if __name__ == '__main__':
    main()
