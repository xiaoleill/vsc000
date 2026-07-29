"""
File Matcher Module
Discovers files in a directory and matches them against output WP keywords
from the safety plan schedule.

Matching rules:
- Case insensitive, underscores/spaces treated as equivalent
- Acronym tokens (all-caps like DFA, FMEDA, FMEA) get boosted weight as
  primary match keys — one acronym match is worth more than many
  descriptive-word misses.
- When a keyword contains multiple comma-separated acronyms (e.g.
  "DFMEA, FMEA and DFA"), each acronym is matched independently and all
  matching files are returned (one-to-many).
- Score >= min_score threshold triggers a match.
"""

import json
import os
import re
import sys
from dataclasses import dataclass, field
from typing import Optional

# Supported file extensions
SUPPORTED_EXTENSIONS = {'.xlsx', '.xlsm', '.docx', '.pptx', '.pdf', '.md'}

# Words to ignore in tokenization (common noise words)
# NOTE: 'can' is NOT a stop word — in automotive functional safety context
# it refers to "Controller Area Network" (CAN bus), not the English verb.
STOP_WORDS = {
    'the', 'a', 'an', 'and', 'or', 'for', 'of', 'in', 'to', 'with',
    'is', 'are', 'was', 'were', 'be', 'been', 'being', 'have', 'has',
    'had', 'do', 'does', 'did', 'will', 'would', 'shall', 'should',
    'may', 'might', 'must', 'could', 'not', 'no', 'nor',
    'from', 'on', 'at', 'by', 'as', 'if', 'into', 'per',
    'pre', 'post', 'same', 'wps', 'wp', 'phase', 'optional',
}

# Domain synonym map — equivalent terms in the company's project context.
# Loaded from synonym_config.json at runtime via load_synonym_config().
# When a keyword token matches any synonym of a filename token (or vice versa),
# it counts as a match (0.8 weight: slight discount vs exact match).
_synonym_map: dict[str, set[str]] = {}
_synonym_loaded: bool = False

# Default config path (relative to this module's directory)
_DEFAULT_CONFIG = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                '..', 'settings', 'synonym_config.json')


def load_synonym_config(config_path: str = None) -> dict[str, set[str]]:
    """
    Load synonym equivalence rules from a JSON config file.

    Config format:
    {
      "groups": [
        {
          "name": "flash_memory",
          "description": "EFM = FLASH",
          "tokens": ["efm", "flash"]
        }
      ]
    }

    All tokens in the same group are considered equivalent during matching.
    Returns the synonym map: {token: {token, synonym1, synonym2, ...}}.
    """
    global _synonym_map, _synonym_loaded

    path = config_path or _DEFAULT_CONFIG

    if not os.path.exists(path):
        if config_path:
            print(f"WARNING: synonym config not found: {path}", file=sys.stderr)
        _synonym_map = {}
        _synonym_loaded = True
        return _synonym_map

    try:
        with open(path, 'r', encoding='utf-8') as f:
            config = json.load(f)
    except Exception as e:
        print(f"WARNING: failed to load synonym config {path}: {e}", file=sys.stderr)
        _synonym_map = {}
        _synonym_loaded = True
        return _synonym_map

    new_map: dict[str, set[str]] = {}

    for group in config.get('groups', []):
        tokens = group.get('tokens', [])
        if not tokens:
            continue

        # Build the full synonym set for this group
        syn_set = set(t.lower() for t in tokens)

        # Each token maps to the full group set (including itself)
        for t in syn_set:
            if t not in new_map:
                new_map[t] = syn_set
            else:
                new_map[t] = new_map[t] | syn_set

    _synonym_map = new_map
    _synonym_loaded = True
    return _synonym_map


def _expand_synonyms(token: str) -> set[str]:
    """Return the set of equivalent tokens for matching purposes."""
    if not _synonym_loaded:
        load_synonym_config()
    return _synonym_map.get(token, {token})


@dataclass
class MatchResult:
    """Result of matching a keyword to files."""
    keyword: str
    matched_files: list[str] = field(default_factory=list)  # full paths
    scores: list[float] = field(default_factory=list)        # per-file scores
    best_score: float = 0.0                                   # highest score
    extension_mismatch: bool = False   # True if fallback matched different extension
    extension_expected: str = ""       # extension from keyword (e.g. ".docx")

    @property
    def is_matched(self) -> bool:
        return len(self.matched_files) > 0

    @property
    def matched_file(self) -> Optional[str]:
        """Backward-compat: return first matched file."""
        return self.matched_files[0] if self.matched_files else None


def _normalize(text: str) -> str:
    """
    Normalize text for comparison:
    - Convert to lowercase
    - Replace underscores, hyphens, dots with spaces
    - Extract parenthesized content as extra tokens (e.g. "(DFA)" -> " DFA")
    - Collapse whitespace
    """
    text = text.lower()
    # Replace common separators with space
    text = re.sub(r'[_\-\.]', ' ', text)

    # Extract parenthesized content before removing parentheses
    paren_content = re.findall(r'\(([^)]*)\)', text)
    paren_content += re.findall(r'（([^）]*)）', text)

    # Remove parentheses and their content
    text = re.sub(r'\([^)]*\)', '', text)
    text = re.sub(r'（[^）]*）', '', text)

    # Append extracted parenthetical content as additional tokens
    for content in paren_content:
        text += ' ' + content

    # Remove other punctuation
    text = re.sub(r'[,"\'":;!@#$%^&*+=<>\[\]{}|\\/~`]', ' ', text)
    text = re.sub(r'\s+', ' ', text).strip()
    return text


def _extract_acronyms(original_text: str) -> list[str]:
    """
    Extract document-type acronym tokens from keyword text.
    Returns lowercase versions for matching.

    Priority: parenthesized acronyms first (e.g., "(DFA)", "(FMEDA)").
    These are canonical abbreviations intentionally placed in the keyword.
    Non-parenthesized all-caps tokens are only used if there are no
    parenthesized ones (avoids false positives like "FS" in task IDs).

    E.g., "Dependent failure analysis (DFA)" -> ["dfa"]
          "DFMEA, FMEA and DFA" -> ["dfmea", "fmea", "dfa"]
    """
    # Extract parenthesized acronyms (highest confidence)
    paren_acronyms = re.findall(r'\(([A-Z]{2,})\)', original_text)
    paren_acronyms += re.findall(r'（([A-Z]{2,})）', original_text)

    if paren_acronyms:
        return [a.lower() for a in paren_acronyms]

    # No parenthesized acronyms: extract all-caps tokens from the text
    # but exclude common 2-letter noise (like "FS", "HW", "SW", "IP", "QM")
    COMMON_2LETTER = {'fs', 'hw', 'sw', 'ip', 'qm', 'ts', 'ds', 'rm', 'pm'}
    all_acronyms = re.findall(r'\b([A-Z]{2,})\b', original_text)
    result = []
    for a in all_acronyms:
        a_lower = a.lower()
        if len(a) == 2 and a_lower in COMMON_2LETTER:
            continue
        result.append(a_lower)
    return result


def _tokenize(text: str) -> list[str]:
    """
    Tokenize normalized text into significant words.
    Filters out stop words, file extensions (used for candidate filtering),
    and very short tokens.
    """
    normalized = _normalize(text)
    tokens = normalized.split()
    # Filter: stop words, file extensions, and single-char tokens
    result = []
    for t in tokens:
        if t in STOP_WORDS:
            continue
        if len(t) < 1:
            continue
        # Strip file extensions — they're used for candidate filtering, not scoring
        if t in ('xlsx', 'xlsm', 'docx', 'pptx', 'pdf', 'md'):
            continue
        result.append(t)
    return result


def _get_keyword_extension(keyword: str) -> Optional[str]:
    """Extract file extension from keyword if present."""
    kw_lower = keyword.lower().strip()
    for ext in SUPPORTED_EXTENSIONS:
        if kw_lower.endswith(ext):
            return ext
    return None


def _score_single_match(query_tokens: list[str], acronym_tokens: list[str],
                        filename: str) -> float:
    """
    Score a filename against query tokens with acronym boosting.

    Token matching is done against filename TOKENS (not the raw string),
    so "fs" won't spuriously match "fsco" as an exact match.

    Algorithm:
    - Full score: fraction of query_tokens found as tokens in filename
      (exact token match = 1.0, substring within a token = 0.3)
    - Acronym score: fraction of acronym_tokens found in filename tokens
    - If acronyms exist: final = 0.7 * acronym_score + 0.3 * full_score
    - If no acronyms: final = full_score only

    Returns 0.0 ~ 1.0.
    """
    if not query_tokens:
        return 0.0

    fn_tokens = _normalize(filename).split()

    def _token_match(token: str) -> float:
        """Check if a token matches within filename tokens.
        Returns 1.0 for exact token match, 0.8 for synonym match,
        0.3 for substring match, 0.0 for no match."""
        # Exact token match
        if token in fn_tokens:
            return 1.0
        # Synonym match: token's synonym set overlaps with any filename token's set
        token_syns = _expand_synonyms(token)
        for ft in fn_tokens:
            ft_syns = _expand_synonyms(ft)
            if token_syns & ft_syns:
                return 0.8  # synonym match — high confidence, slight discount vs exact
        # Substring match within individual tokens
        for ft in fn_tokens:
            if token in ft or ft in token:
                return 0.3
        return 0.0

    # Full-text scoring
    full_matched = 0.0
    unmatched_synonym_tokens = 0
    for t in query_tokens:
        m = _token_match(t)
        full_matched += m
        # Track unmatched tokens that are known module/IP identifiers
        # (present in the synonym map — these are the critical differentiators)
        if m == 0.0 and t in _synonym_map:
            unmatched_synonym_tokens += 1

    full_score = full_matched / len(query_tokens) if query_tokens else 0.0

    # Acronym scoring
    if acronym_tokens:
        acro_matched = sum(_token_match(a) for a in acronym_tokens)
        acro_score = acro_matched / len(acronym_tokens)
        final_score = 0.7 * acro_score + 0.3 * full_score
    else:
        final_score = full_score

    # Penalty: if a synonym-mapped token (module/IP identifier like BUS, CMU, CRC)
    # doesn't match at all, the match is to a different module — heavily penalize.
    if unmatched_synonym_tokens > 0:
        final_score *= 0.5

    return final_score


def _split_multi_acronym_keyword(keyword: str) -> list[str]:
    """
    Detect if a keyword contains multiple comma/and-separated document types
    and split them into individual sub-keywords for independent matching.

    Strategy:
    1. Extract acronyms from the keyword
    2. If >= 2 acronyms separated by commas/and, split into parts
    3. Each part should contain ONE primary acronym
    4. Further split "FMEA and DFA" → ["FMEA", "DFA"]

    Returns list of sub-keywords (single element if no split needed).
    """
    original = keyword.strip()

    # Clean up: remove parenthesized qualifiers and trailing punctuation
    clean = re.sub(r'\([^)]*\)', '', original)
    clean = re.sub(r'（[^）]*）', '', clean)
    clean = clean.strip().rstrip('"').rstrip("'")

    acronyms = _extract_acronyms(clean)

    if len(acronyms) < 2:
        return [original]

    # Check if acronyms appear in a comma/and-separated context
    has_comma = ',' in clean
    has_and = bool(re.search(r'\band\b', clean, re.IGNORECASE))

    if not (has_comma or has_and):
        return [original]

    # Split by comma first, then by "and"
    parts = []
    if has_comma:
        for p in clean.split(','):
            p = p.strip()
            if p:
                parts.append(p)
    else:
        parts = [clean]

    # Further split each part by "and"
    final_parts = []
    for part in parts:
        if re.search(r'\band\b', part, re.IGNORECASE):
            sub = re.split(r'\s+and\s+', part, flags=re.IGNORECASE)
            for s in sub:
                s = s.strip()
                if s:
                    final_parts.append(s)
        else:
            final_parts.append(part)

    # Only return split result if we actually split into multiple parts
    # AND each part contains at least one acronym
    if len(final_parts) >= 2:
        valid_parts = []
        for p in final_parts:
            if _extract_acronyms(p):  # must have at least one acronym
                valid_parts.append(p)
        if len(valid_parts) >= 2:
            return valid_parts

    return [original]


def discover_files(directory: str) -> list[str]:
    """
    Recursively discover all supported files in the directory.
    """
    files = []
    for root, dirs, filenames in os.walk(directory):
        dirs[:] = [d for d in dirs if not d.startswith('.') and not d.startswith('~')]
        for fname in filenames:
            if fname.startswith('~$'):
                continue
            ext = os.path.splitext(fname)[1].lower()
            if ext in SUPPORTED_EXTENSIONS:
                files.append(os.path.join(root, fname))
    return files


def match_keyword_to_file(keyword: str, candidate_files: list[str],
                          min_score: float = 0.5) -> MatchResult:
    """
    Match a keyword against candidate files.

    Two modes:
    - Single-keyword (normal): returns only the BEST match above threshold.
    - Multi-acronym keyword (comma/and-separated like "DFMEA, FMEA and DFA"):
      each sub-keyword matched independently, ALL matches returned (one-to-many).

    Returns:
        MatchResult with matched files.
    """
    expected_ext = _get_keyword_extension(keyword)

    # Check if this is a multi-acronym keyword
    sub_keywords = _split_multi_acronym_keyword(keyword)
    is_multi = len(sub_keywords) > 1

    all_matched: dict[str, float] = {}  # filepath -> best score

    for sub_kw in sub_keywords:
        # Determine extension filter
        ext = _get_keyword_extension(sub_kw) or expected_ext

        query_tokens = _tokenize(sub_kw)
        acronym_tokens = _extract_acronyms(sub_kw)

        if not query_tokens:
            continue

        # Try extension-specific search first
        extension_fallback_used = False
        for use_ext_filter in (True, False):
            if use_ext_filter and ext:
                candidates = [f for f in candidate_files
                              if os.path.splitext(f)[1].lower() == ext]
            elif not ext:
                candidates = list(candidate_files)
            else:
                # Fallback: retry without extension filter
                # (plan says .docx but file might be .xlsx, etc.)
                candidates = list(candidate_files)
                if ext:  # Only flag if we actually had an extension constraint
                    extension_fallback_used = True

            if not candidates:
                continue

            round_matches = {}
            for filepath in candidates:
                fname = os.path.splitext(os.path.basename(filepath))[0]
                score = _score_single_match(query_tokens, acronym_tokens, fname)
                if score >= min_score:
                    round_matches[filepath] = score

            if round_matches:
                # Got matches with this filter — merge and stop
                for fp, s in round_matches.items():
                    if fp not in all_matched or s > all_matched[fp]:
                        all_matched[fp] = s
                break
            # No matches with this filter; if using extension filter, fallback to all

    # Sort by score descending
    sorted_matches = sorted(all_matched.items(), key=lambda x: -x[1])

    if is_multi:
        # Multi-acronym: return ALL matches
        result = MatchResult(
            keyword=keyword,
            matched_files=[f for f, _ in sorted_matches],
            scores=[s for _, s in sorted_matches],
            best_score=sorted_matches[0][1] if sorted_matches else 0.0,
            extension_mismatch=extension_fallback_used,
            extension_expected=ext or '',
        )
    else:
        # Single keyword: return ONLY the best match
        # Apply specificity bonus: when acronyms exist, shorter filenames
        # that match the acronym get a bonus (e.g., "C044_DFA" > "C044 Safety
        # analysis and DFA confirmation review checklist and report")
        if sorted_matches:
            # Re-score with specificity
            kw_acronyms = _extract_acronyms(keyword)
            best_file = None
            best_adjusted = -1.0

            for filepath, base_score in sorted_matches:
                fname = os.path.splitext(os.path.basename(filepath))[0]
                fn_tokens = _normalize(fname).split()
                fn_token_count = len(fn_tokens)

                # Specificity: reward shorter filenames when acronyms match
                if kw_acronyms and fn_token_count > 0:
                    # Bonus for each acronym that is an exact token in the filename
                    acro_in_fn = sum(1 for a in kw_acronyms
                                     if a in fn_tokens)
                    # Specificity factor: shorter files with acronyms get bonus
                    specificity_bonus = (acro_in_fn / max(len(kw_acronyms), 1)) * (1.0 / fn_token_count)
                    adjusted = base_score + specificity_bonus * 0.15
                else:
                    adjusted = base_score

                if adjusted > best_adjusted:
                    best_adjusted = adjusted
                    best_file = filepath
                elif abs(adjusted - best_adjusted) < 0.001 and best_file:
                    # Tiebreaker: prefer shorter filename (more specific match)
                    curr_len = len(os.path.splitext(os.path.basename(filepath))[0])
                    best_len = len(os.path.splitext(os.path.basename(best_file))[0])
                    if curr_len < best_len:
                        best_file = filepath

            final_score = best_adjusted if best_adjusted > 0 else sorted_matches[0][1]
            result = MatchResult(
                keyword=keyword,
                matched_files=[best_file],
                scores=[final_score],
                best_score=final_score,
                extension_mismatch=extension_fallback_used,
                extension_expected=ext or '',
            )
        else:
            result = MatchResult(
                keyword=keyword,
                extension_mismatch=extension_fallback_used,
                extension_expected=ext or '',
            )

    return result


def match_all_keywords(keywords: list[str], directory: str,
                       min_score: float = 0.5) -> dict[str, MatchResult]:
    """
    Match all keywords against files in a directory.

    Returns:
        Dict mapping keyword -> MatchResult.
    """
    all_files = discover_files(directory)
    results: dict[str, MatchResult] = {}

    for kw in keywords:
        if not kw or not kw.strip():
            results[kw] = MatchResult(keyword=kw)
            continue
        results[kw] = match_keyword_to_file(kw, all_files, min_score)

    return results
