#!/usr/bin/env python3
"""
ERMU UVM Auto-Lint-Fix — Pattern-based SV/UVM checker + auto-fixer.
Does NOT require external tools.  Works on any Python 3.8+.

Usage:
    python auto_lint_fix.py --check-only    # report only
    python auto_lint_fix.py                 # auto-fix + show diff
"""

import sys, os, re, difflib, shutil, argparse
from pathlib import Path
from dataclasses import dataclass, field
from typing import Optional, Callable

PROJ_ROOT = Path(__file__).resolve().parent.parent
SRC_DIRS  = ["agent", "env", "if", "reg", "seq", "test", "tb", "cov"]


# ============================================================================
#  Checker — each Check defines a pattern to look for across all .sv/.v files
# ============================================================================

@dataclass
class Check:
    name: str
    description: str
    # Returns list of (file, line_no, context) tuples for each violation found
    scan: Callable[[Path], list]
    # Returns (new_content, fixed:bool) — None if auto-fix not possible
    fix:  Callable[[Path, str], tuple] = None


# ---------------------------------------------------------------------------
#  C1: Missing `include "uvm_macros.svh" in package files
# ---------------------------------------------------------------------------
def _c1_scan(f: Path) -> list:
    issues = []
    txt = f.read_text(encoding="utf-8")
    if "package " in txt and "import uvm_pkg" in txt:
        if '`include "uvm_macros.svh"' not in txt:
            # Find the import line
            for i, line in enumerate(txt.splitlines(), 1):
                if "import uvm_pkg::*" in line and "`include" not in line:
                    issues.append((f, i, line.strip()))
                    break
    return issues

def _c1_fix(f: Path, _ctx: str) -> tuple:
    txt = f.read_text(encoding="utf-8")
    new_txt = re.sub(
        r"(import\s+uvm_pkg::\*\s*;)",
        r"\1\n    `include \"uvm_macros.svh\"",
        txt, count=1,
    )
    return new_txt, (new_txt != txt)

CHECK_MISSING_UVM_MACROS = Check(
    "missing_uvm_macros",
    "Package files missing `include \"uvm_macros.svh\" after import uvm_pkg",
    _c1_scan, _c1_fix,
)


# ---------------------------------------------------------------------------
#  C2: Modport type on virtual interface declaration
#      (virtual xxx_if.master_mp → virtual xxx_if)
# ---------------------------------------------------------------------------
def _c2_scan(f: Path) -> list:
    issues = []
    for i, line in enumerate(f.read_text(encoding="utf-8").splitlines(), 1):
        if re.match(r"\s*virtual\s+\w+_if\.(master_mp|monitor_mp)\s+\w+", line):
            issues.append((f, i, line.strip()))
    return issues

def _c2_fix(f: Path, _ctx: str) -> tuple:
    txt = f.read_text(encoding="utf-8")
    new_txt = re.sub(
        r"virtual\s+(\w+_if)\.(master_mp|monitor_mp)\s+",
        r"virtual \1 ",
        txt,
    )
    return new_txt, (new_txt != txt)

CHECK_MODPORT_MISMATCH = Check(
    "modport_type_mismatch",
    "virtual interface declarations using .master_mp/.monitor_mp modport",
    _c2_scan, _c2_fix,
)


# ---------------------------------------------------------------------------
#  C3: Task-internal declaration + initialization on same line
#      (Some tools reject `Type var = expr;` inside tasks)
# ---------------------------------------------------------------------------
def _c3_scan(f: Path) -> list:
    issues = []
    in_task = False
    for i, line in enumerate(f.read_text(encoding="utf-8").splitlines(), 1):
        if re.match(r"\s*task\s+\w+", line):
            in_task = True
        elif re.match(r"\s*endtask", line):
            in_task = False
        elif in_task:
            # Match: <indent><Type> <var> = <Type>::type_id::create(...);
            m = re.match(r"(\s*)(\w+)\s+(\w+)\s*=\s*(\w+)::type_id::create\(.*\)\s*;", line)
            if m:
                issues.append((f, i, line.strip()))
            # Also match: <indent><Type> <var> = null;
            m2 = re.match(r"(\s*)(\w+)\s+(\w+)\s*=\s*null\s*;", line)
            if m2 and "prev_tx" not in line:  # prev_tx is fine
                issues.append((f, i, line.strip()))
    return issues

def _c3_fix(f: Path, ctx: str) -> tuple:
    txt = f.read_text(encoding="utf-8")
    m = re.match(r"(\s*)(\w+)\s+(\w+)\s*=\s*(\w+::type_id::create\(.*\))\s*;", ctx)
    if m:
        indent, vtype, vname, init = m.groups()
        old = f"{indent}{vtype} {vname} = {init};"
        new = f"{indent}{vtype} {vname};\n{indent}{vname} = {init};"
        return txt.replace(old, new, 1), True
    m2 = re.match(r"(\s*)(\w+)\s+(\w+)\s*=\s*null\s*;", ctx)
    if m2:
        indent, vtype, vname = m2.groups()
        old = f"{indent}{vtype} {vname} = null;"
        new = f"{indent}{vtype} {vname};\n{indent}{vname} = null;"
        return txt.replace(old, new, 1), True
    return txt, False

CHECK_TASK_DECL_INIT = Check(
    "task_decl_init",
    "Declaration + initialization on one line inside task body",
    _c3_scan, _c3_fix,
)


# ---------------------------------------------------------------------------
#  C4: Duplicate include of interface (.sv included in both filelist and top)
#      → check if hdl_top.sv has `include of interface files
# ---------------------------------------------------------------------------
def _c4_scan(f: Path) -> list:
    issues = []
    if f.name in ("hdl_top.sv", "hvl_top.sv"):
        for i, line in enumerate(f.read_text(encoding="utf-8").splitlines(), 1):
            if line.strip().startswith("`include") and "_if.sv" in line:
                issues.append((f, i, line.strip()))
    return issues

def _c4_fix(f: Path, _ctx: str) -> tuple:
    txt = f.read_text(encoding="utf-8")
    new_txt = re.sub(r'`include\s+"\w+_if\.sv"\s*\n', '', txt)
    return new_txt, (new_txt != txt)

CHECK_DUP_INCLUDE = Check(
    "duplicate_interface_include",
    "Interface `include inside top-level .sv (also in compile filelist)",
    _c4_scan, _c4_fix,
)


# ---------------------------------------------------------------------------
#  C5: `uvm_analysis_imp` without matching `uvm_analysis_imp_decl` prefix
#      (check for multiple uvm_analysis_imp uses with same suffix)
# ---------------------------------------------------------------------------
def _c5_scan(f: Path) -> list:
    issues = []
    txt = f.read_text(encoding="utf-8")
    # Find all uvm_analysis_imp_decl lines
    decls = set()
    for m in re.finditer(r"`uvm_analysis_imp_decl\((\w+)\)", txt):
        decls.add(m.group(1))
    # Find all uvm_analysis_imp_XXX uses
    used = set()
    for m in re.finditer(r"uvm_analysis_imp_(\w+)\s", txt):
        suffix = m.group(1)
        used.add(suffix)
        if suffix not in decls:
            # Find which file defines this macro
            for d in SRC_DIRS:
                for other_f in (PROJ_ROOT / d).rglob("*.sv"):
                    if other_f == f:
                        continue
                    otxt = other_f.read_text(encoding="utf-8")
                    if f"`uvm_analysis_imp_decl({suffix})" in otxt:
                        # same suffix defined in another file → conflict
                        for i, line in enumerate(txt.splitlines(), 1):
                            if f"uvm_analysis_imp_{suffix}" in line:
                                issues.append((f, i, line.strip()))
    return issues

CHECK_DUP_IMP_DECL = Check(
    "dup_analysis_imp_decl",
    "uvm_analysis_imp_decl with same suffix in multiple files",
    _c5_scan, None,  # auto-fix too complex, report only
)


# ---------------------------------------------------------------------------
#  C6: Covergroup using bare signal names instead of sample() args
#      Look for: `coverpoint eoutm` inside a covergroup without `with function sample`
# ---------------------------------------------------------------------------
def _c6_scan(f: Path) -> list:
    issues = []
    txt = f.read_text(encoding="utf-8")
    # Find covergroup blocks that don't use `with function sample`
    cg_blocks = list(re.finditer(r"covergroup\s+(\w+)(\s+with\s+function\s+sample\(.*?\))?\s*;", txt))
    for m in cg_blocks:
        cg_name = m.group(1)
        has_sample = m.group(2) is not None
        if not has_sample:
            # Find the corresponding endgroup
            start = m.start()
            end = txt.find("endgroup", start)
            if end > 0:
                cg_body = txt[start:end]
                # Look for bare coverpoints that reference struct members
                for cp in re.finditer(r"coverpoint\s+(\w+)\s*\{", cg_body):
                    name = cp.group(1)
                    # Check if this is a name that might be undeclared in scope
                    if name not in ("pwrite", "pslverr", "eoutm", "eoutc",
                                    "hpi_irq", "lpi_irq", "srst_req", "arst_req",
                                    "pssr", "ems_event", "status"):
                        continue
                    # Find line number
                    lineno = txt[:start + cp.start()].count('\n') + 1
                    # Check if this identifier appears as a variable in the enclosing class
                    class_start = txt.rfind("class ", 0, start)
                    class_body = txt[class_start:start] if class_start > 0 else ""
                    if name not in class_body:
                        issues.append((f, lineno, f"covergroup '{cg_name}': bare coverpoint '{name}' without sample args"))
    return issues

CHECK_COV_BARE = Check(
    "coverage_bare_coverpoint",
    "Covergroup coverpoint referencing undeclared variable name",
    _c6_scan, None,  # needs manual rewrite
)


# ---------------------------------------------------------------------------
#  C7: Interface signal name compatibility
#      .ready vs .pready in DUT connections and APB interface
# ---------------------------------------------------------------------------
def _c7_scan(f: Path) -> list:
    issues = []
    if f.name in ("ermu.v", "hdl_top.sv", "ermu_apb_if.sv"):
        txt = f.read_text(encoding="utf-8")
        for i, line in enumerate(txt.splitlines(), 1):
            if re.search(r'\bready\b', line) and f.name != "ermu.v":
                # In non-DUT files, warn about 'ready' vs 'pready'
                if 'ready' in line and 'pready' not in line:
                    if '//' not in line.split('ready')[0]:  # not in comment
                        issues.append((f, i, line.strip()))
            # Check DUT has 'pready' not 'ready'
            if f.name == "ermu.v" and re.search(r'\boutput.*\bready\b', line):
                if 'pready' not in line:
                    issues.append((f, i, line.strip()))
    return issues

def _c7_fix(f: Path, _ctx: str) -> tuple:
    txt = f.read_text(encoding="utf-8")
    # In non-DUT files: change bare `ready` to `pready` in interface references
    if f.name != "ermu.v":
        new_txt = re.sub(r'(\W)ready(\W)', r'\1pready\2', txt)
        new_txt = new_txt.replace('.pready_y', '.ready')  # don't change .ready in comments
        return new_txt, (new_txt != txt)
    return txt, False

CHECK_READY_VS_PREADY = Check(
    "ready_vs_pready",
    "Signal name mismatch: ready vs pready between DUT and interface",
    _c7_scan, _c7_fix,
)


# ---------------------------------------------------------------------------
#  ALL CHECKS
# ---------------------------------------------------------------------------
ALL_CHECKS = [
    CHECK_MISSING_UVM_MACROS,
    CHECK_MODPORT_MISMATCH,
    CHECK_TASK_DECL_INIT,
    CHECK_DUP_INCLUDE,
    CHECK_DUP_IMP_DECL,
    CHECK_COV_BARE,
    CHECK_READY_VS_PREADY,
]


# ============================================================================
#  Main Engine
# ============================================================================

def find_sv_files() -> list:
    files = []
    for d in SRC_DIRS:
        dp = PROJ_ROOT / d
        if dp.exists():
            files.extend(dp.rglob("*.sv"))
            files.extend(dp.rglob("*.svh"))
    files.extend(PROJ_ROOT.glob("*.sv"))
    files.extend(PROJ_ROOT.glob("*.v"))
    return sorted(set(f for f in files if f.is_file()))


def run_all_checks(files: list) -> list:
    """Run all checks and return list of (file, check, fix_info)"""
    results = []
    for f in files:
        for ck in ALL_CHECKS:
            for (filepath, lineno, ctx) in ck.scan(f):
                results.append((filepath, lineno, ck, ctx))
    return results


def apply_auto_fixes(results: list) -> dict:
    """Apply auto-fixes. Returns dict of {filepath: new_content}"""
    modified = {}
    applied_count = 0

    for (filepath, lineno, ck, ctx) in results:
        if ck.fix is None:
            continue  # manual-only check
        if filepath in modified:
            # Already modified this file, skip further fixes for safety
            continue
        try:
            new_content, fixed = ck.fix(filepath, ctx)
            if fixed:
                # Show diff
                original = filepath.read_text(encoding="utf-8")
                diff = "\n".join(difflib.unified_diff(
                    original.splitlines(), new_content.splitlines(),
                    fromfile=f"a/{filepath.name}", tofile=f"b/{filepath.name}",
                    lineterm="",
                ))
                print(f"\n{'─' * 60}")
                print(f"[FIX] {filepath.name}:{lineno} — {ck.description}")
                print(diff)
                modified[filepath] = new_content
                applied_count += 1
        except Exception as e:
            print(f"[ERR] Failed to fix {filepath.name}:{lineno}: {e}")

    return modified, applied_count


def main():
    ap = argparse.ArgumentParser(description="ERMU UVM Auto-Lint-Fix")
    ap.add_argument("--check-only", action="store_true",
                    help="Scan and report only; do not modify any files")
    ap.add_argument("--no-backup", action="store_true",
                    help="Skip .bak backup of modified files")
    args = ap.parse_args()

    print("=" * 60)
    print(" ERMU UVM Auto-Lint-Fix (pattern-based)")
    print("=" * 60)

    files = find_sv_files()
    print(f"\nFound {len(files)} SV files to scan")

    # ---- Run all checks ----
    results = run_all_checks(files)
    print(f"Found {len(results)} potential issue(s)")

    if not results:
        print("[OK] No issues found!")
        return 0

    # ---- Report ----
    manual_issues = []
    for (filepath, lineno, ck, ctx) in results:
        if ck.fix is None:
            manual_issues.append((filepath, lineno, ck, ctx))
            print(f"\n[MANUAL] {filepath.name}:{lineno} — {ck.description}")
            print(f"         {ctx[:120]}")
        else:
            print(f"\n[AUTO]   {filepath.name}:{lineno} — {ck.description}")

    if args.check_only:
        if manual_issues:
            print(f"\n[!] {len(manual_issues)} issue(s) require manual fixing.")
        return 1 if results else 0

    # ---- Auto-fix ----
    modified, fixed_count = apply_auto_fixes(results)

    if modified:
        for fpath, new_content in modified.items():
            if not args.no_backup:
                shutil.copy2(fpath, fpath.with_suffix(fpath.suffix + ".bak"))
            fpath.write_text(new_content, encoding="utf-8")
        print(f"\n[OK] Applied {fixed_count} fix(es) to {len(modified)} file(s).")
        if not args.no_backup:
            print("     Backups saved as *.sv.bak")

    if manual_issues:
        print(f"\n[!] {len(manual_issues)} issue(s) require manual review:")
        for (filepath, lineno, ck, ctx) in manual_issues:
            print(f"    {filepath.name}:{lineno} — {ck.description}")

    return 1 if manual_issues else 0


if __name__ == "__main__":
    sys.exit(main())
