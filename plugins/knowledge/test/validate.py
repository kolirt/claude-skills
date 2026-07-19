#!/usr/bin/env python3
"""Structural + reference-first validator for all knowledge* plugins (no app runtime to test).

Semantics: any ERROR fails the run (exit 1); WARNINGs are printed but keep exit 0.
Run the negative fixtures with:  python3 validate.py --self-test
"""
import json, re, sys, pathlib, posixpath

PLUGINS_DIR = pathlib.Path(__file__).resolve().parents[2]  # .../plugins
FIXTURES = pathlib.Path(__file__).resolve().parent / "fixtures"

# Plugins whose skills generate CODE — reference-first rules apply only to these.
# Policy plugins (knowledge-seo: principles, no code generation) are exempt by design;
# never infer "has a code block therefore code skill".
CODE_PLUGINS = {"knowledge-vue"}

# The etalon waves are complete: every non-skeleton code skill ships references/.
# Missing references/ on a code skill is now a blocking error, so the discipline
# cannot rot back into direction-style prose. Skeletons awaiting a capture session
# stay exempt (see is_skeleton).
REFERENCE_FIRST_ENFORCED = True

BODY_LINE_LIMIT = 250
STUB_LINE_LIMIT = 25

REF = re.compile(r"Read `([^`]+\.md)`")
TAG = re.compile(r"\[(invariant|preference|anti-pattern) · (desired|legacy)\]")
LOOSE_TAG = re.compile(r"\[\s*(?:invariant|preference|anti-pattern)\b[^\]]*\]")
FENCE = re.compile(r"^\s*```(\S*)")
INVENTORY_ITEM = re.compile(r"^\s*-\s+`([^`]+)`\s*$")
FILE_MARKER = re.compile(r"^\s*\*\*File:\*\*\s+`([^`]+)`\s*$")
# Every generated-file path in an etalon must START with a placement token — an
# etalon that writes `app/foo.ts` or `@/shared/x.ts` has hard-coded a real path
# instead of resolving it per-architecture, same defect as check_hardcoded_paths
# but for the `## Files` inventory / **File:** markers, which live outside code
# blocks and so are invisible to that scanner. This regex only recognises the
# *shape* of a token (`{word}`) — whether that word is an actually-defined
# placement token is checked separately against the vocabulary parsed from
# placement.md (see load_known_tokens), otherwise `{not-a-token}/x.ts` would
# pass just because it LOOKS like a token.
TOKEN_START = re.compile(r"^\{([a-z][a-z-]*)\}")
# `{...}` is reserved for a placement token (placement.md §1) — ANY specifier
# that starts with a brace group is a token reference by shape, regardless of
# what's inside the braces (`{APP}`, `{app_name}`, `{App}` are all malformed
# token references, not ordinary package imports). This is deliberately looser
# than TOKEN_START (lowercase-only): it is used to DECIDE whether a specifier
# is in-scope for token-grammar checking at all, not to validate the grammar
# itself — the grammar check (_is_known_token_path, via TOKEN_START) still
# rejects the malformed casing/characters. Without this broader gate, a
# malformed brace import silently falls through as an "ordinary external
# package import" and is never checked (see collect_token_imports).
BRACE_SHAPE = re.compile(r"^\{[^{}]*\}")

# placement.md is the single source of truth for the token vocabulary. We
# deliberately do NOT hard-code the token list here — another agent may be
# actively editing that table — so it is parsed fresh from disk every run.
PLACEMENT_MD = PLUGINS_DIR / "knowledge-vue" / "core" / "placement.md"
TOKEN_TABLE_ROW = re.compile(r"^\|\s*`\{([a-z][a-z-]*)\}`\s*\|", re.M)
# placement.md §1 names the file-valued exception in prose, not the table (the table
# only has bucket rows): "except `{pages-types}`, which resolves to\na single FILE".
# Parsed fresh, like KNOWN_TOKENS, so a future second file-valued token is picked up
# without touching this file — `{pages-types}` is hard-coded ONLY as the fallback in
# load_file_valued_tokens() below, in case the prose wording ever drifts.
FILE_VALUED_TOKEN_PROSE = re.compile(
    r"except\s+`\{([a-z][a-z-]*)\}`,\s*which resolves to\s+a single FILE", re.I)


def load_known_tokens():
    """Parse the `| \\`{token}\\` | role |` table out of placement.md.

    Fails loudly (raises) if the file is missing or the table cannot be
    parsed at all — a validator that silently fell back to "no known
    tokens" (or, worse, "any brace-shaped word is a token") would defeat
    the whole point of checking against an authoritative vocabulary.
    """
    if not PLACEMENT_MD.exists():
        raise RuntimeError(f"cannot load token vocabulary: {PLACEMENT_MD} does not exist")
    text = PLACEMENT_MD.read_text()
    tokens = {m.group(1) for m in TOKEN_TABLE_ROW.finditer(text)}
    if not tokens:
        raise RuntimeError(f"cannot parse any `{{token}}` rows out of {PLACEMENT_MD} — "
                            "table format may have changed")
    return tokens


def load_file_valued_tokens():
    """Parse the file-valued-token exception out of placement.md §1's prose
    ("except `{pages-types}`, which resolves to a single FILE"), rather than
    hard-coding the name `pages-types` — if placement.md ever grows a second
    file-valued token, this picks it up with no change here.

    If the prose can no longer be matched (wording drift), fall back to the
    single token placement.md documents today (`{pages-types}`) instead of
    raising — unlike load_known_tokens, a stale-but-correct fallback is safer
    here than hard-failing the whole validator over prose rewording elsewhere
    in the doc. NOTE for a future edit to placement.md: if you add a second
    file-valued token, either keep the "except `{token}`, which resolves to a
    single FILE" phrasing for each one, or update FILE_VALUED_TOKEN_PROSE and
    this fallback together.
    """
    text = PLACEMENT_MD.read_text() if PLACEMENT_MD.exists() else ""
    tokens = {m.group(1) for m in FILE_VALUED_TOKEN_PROSE.finditer(text)}
    return tokens or {"pages-types"}


KNOWN_TOKENS = load_known_tokens()
FILE_VALUED_TOKENS = load_file_valued_tokens()

# Explicit, hard-coded allow-list of umbrella/index skills — a skill that
# dispatches to other pattern skills but never itself generates code, so it
# has no etalon of its own to ship (e.g. `vue-work`, which indexes the other
# Vue pattern skills). Matched on the skill's frontmatter `name:`, never on
# body text: a text marker (the old `(umbrella)` heading suffix) can be
# planted by ANY skill to escape the reference-first requirement by simply
# renaming its heading, which is exactly the loophole this allow-list closes.
# Adding a name here is a deliberate, reviewable act — it shows up as a diff
# to this file, not as prose buried in a skill body.
UMBRELLA_SKILLS = {"vue-work"}
# A path-looking token; the char class admits `{}` so tokenised paths match too.
PATHISH = re.compile(r"(?:[@~]/[\w@./{}-]+|(?<![\w./{}-])src/[\w@./{}-]+)")
NAME_THEN_SKILL = re.compile(r"`([a-z0-9][a-z0-9-]*)`(?:'s)?\s+skill\b")
SKILL_THEN_NAME = re.compile(r"\bskills?\s+`([a-z0-9][a-z0-9-]*)`")


def split_code(text):
    """Yield (line, in_code_block, fence_lang) for every line."""
    in_code, lang = False, ""
    for line in text.splitlines():
        m = FENCE.match(line)
        if m:
            if in_code:
                in_code, lang = False, ""
                yield line, True, ""
            else:
                in_code, lang = True, m.group(1)
                yield line, True, lang
            continue
        yield line, in_code, lang


def prose(text):
    return "\n".join(l for l, in_code, _ in split_code(text) if not in_code)


def is_umbrella(name):
    """Explicit, hard-coded exemption for an umbrella/index skill, matched ONLY on
    the skill's frontmatter `name:` against UMBRELLA_SKILLS. Deliberately NOT a text
    marker in the body/heading: a heading marker can be planted by any skill to
    escape the reference-first requirement just by renaming itself, which defeats
    the whole point of the exemption. Adding a name to UMBRELLA_SKILLS is the only
    way in, and it is a one-line, reviewable diff to this file.
    """
    return name in UMBRELLA_SKILLS


def is_skeleton(text):
    """Deliberately-empty skill awaiting a capture session.

    Matched only on the explicit marker forms — a bare mention of "skeleton"
    is usually a skeleton *loader* in the code, not a skill status. The
    marker alone is not enough: a finished, full-length skill could plant
    the same text to claim the exemption, so the body must also actually be
    short (under the stub threshold) before the exemption applies.
    """
    has_marker = re.search(
        r"^(?:#.*—\s*skeleton\s*$|>\s*Skeleton[:\s]|description:.*\bSkeleton —)",
        text, re.M | re.I) is not None
    return has_marker and len(text.splitlines()) < STUB_LINE_LIMIT


# ---------------------------------------------------------------- detectors

def check_stub(text):
    n = len(text.splitlines())
    if n < STUB_LINE_LIMIT and not is_skeleton(text):
        return [("warning", "stub", f"only {n} lines and no skeleton marker — is this finished?")]
    return []


def check_body_length(text):
    n = len(text.splitlines())
    if n > BODY_LINE_LIMIT:
        return [("warning", "long-body", f"{n} lines > {BODY_LINE_LIMIT} — split full examples out to references/")]
    return []


REFERENCE_MENTION = re.compile(r"`references/([A-Za-z0-9_.-]+\.md)`")
REPRODUCE_WORD = re.compile(r"reproduc(?:e|es|ed|ing)\b", re.I)
# A negation cue immediately BEFORE a "reproduce" word turns the instruction
# into its opposite ("do not reproduce", "is **not** reproduced", "never
# reproduce", "rather than reproducing", "instead of reproducing"). Matched
# at the END of the preceding window only — "not" or "never" appearing
# earlier in the sentence for an unrelated reason must not poison a real,
# later "and reproduce it" instruction (see the plugin-registration.md /
# auth.md mixed-paragraph shape in _is_negated_reproduce's docstring).
NEGATION_TAIL = re.compile(r"(?:\bnot\b|\bnever\b|\brather than\b|\binstead of\b)\s*$", re.I)


def _is_negated_reproduce(para, match):
    """True if the REPRODUCE_WORD `match` (found in `para`) is negated —
    i.e. NOT a real instruction to reproduce whatever it refers to.

    Looks only at the ~40 characters immediately preceding the match,
    stripped of markdown emphasis markers (`**not**` reads the same as
    `not`) — the corpus's negated forms all put the negation cue directly
    in front of the verb ("do not reproduce", "is **not** reproduced",
    "never reproduce", "rather than reproducing", "instead of reproducing").
    A negation word appearing earlier in the paragraph but not immediately
    before THIS occurrence (e.g. a separate sentence) must not affect it —
    that is exactly what lets a single paragraph legitimately do both: point
    at its own etalon ("Read `references/plugin.md` and reproduce it ...")
    AND, later in the same paragraph, name a DIFFERENT etalon it does not
    duplicate ("... is **not** reproduced here; it is owned by the
    `http-request-module.md` etalon" — see plugin-registration/SKILL.md).
    """
    window = re.sub(r"[*_]+", "", para[max(0, match.start() - 40):match.start()])
    return NEGATION_TAIL.search(window) is not None


def extract_pointed_etalons(text):
    """Filenames (basenames, e.g. `store.ssr.md`) that this skill's own body
    names alongside a NON-NEGATED instruction to REPRODUCE that specific
    file — the established phrasing across the corpus is some variant of
    "Read `references/<file>.md` ... reproduce it" (see auth.md, modals.md,
    vue-router.md, ... the two-file "read X and reproduce it for SSR; read Y
    and reproduce it for CSR" shape in project-init.md, the "Read
    `references/a.md` (SSR) or `references/b.md` (CSR) and reproduce the one
    matching ..." shape in layouts.md/stores.md, and the "... in
    `references/routes.md`; reproduce them as written ..." shape in
    pages.md).

    Deliberately paragraph-scoped (blank-line-delimited), not whole-document:
    a `references/x.md` mention anywhere in the file (e.g. a `Related skills`
    list, or an unrelated aside) must not count as an instruction to
    reproduce it. Matched on prose only (`prose()` strips fenced/indented
    code), so a code sample that happens to contain the literal string
    `references/x.md` cannot masquerade as the pointer sentence.

    Per-mention, not per-paragraph: a bare "reproduce" substring anywhere in
    the paragraph used to be enough to qualify EVERY `references/x.md`
    mention in it, including one the same paragraph explicitly says NOT to
    reproduce ("Do not reproduce `references/x.md` here, it is owned by
    another skill" satisfied the old check just by containing the word).
    Each filename mention is instead paired with its NEAREST `reproduce`-word
    occurrence (by character distance) in the same paragraph, and only
    counts as "pointed" if that nearest occurrence is not negated
    (`_is_negated_reproduce`). This still lets one paragraph legitimately do
    both — point at its own etalon to reproduce, and separately name another
    etalon it must NOT duplicate — because each filename is judged against
    the reproduce instance closest to it, not against "does this paragraph
    contain the word anywhere."
    """
    body = prose(text)
    paragraphs = re.split(r"\n\s*\n", body)
    pointed = set()
    for para in paragraphs:
        reproduce_matches = list(REPRODUCE_WORD.finditer(para))
        if not reproduce_matches:
            continue
        for fm in REFERENCE_MENTION.finditer(para):
            nearest = min(reproduce_matches, key=lambda rm: abs(rm.start() - fm.start()))
            if not _is_negated_reproduce(para, nearest):
                pointed.add(fm.group(1))
    return pointed


def check_reference_pointer(text, own_etalon_names):
    """Second half of the reference-first contract (authoring-knowledge-skills
    SKILL.md §7): the etalon carries the code AND the SKILL.md body must send
    the reader to it BY NAME with an instruction to reproduce it. Passing
    `check_direction_style` only proves references/ holds *some* structurally
    valid etalon — it says nothing about whether THIS skill's own body ever
    points at it. A skill could satisfy check_direction_style merely by
    having an unrelated valid file sitting in its references/ directory while
    its body stays pure direction-style prose; this is the detector that
    catches that gap.

    `own_etalon_names` is the skill's own references/*.md basenames (not
    validity-checked here — check_etalon already owns that). If the skill
    ships no etalon at all, there is nothing to point at and this check does
    not apply (that gap is check_direction_style's job). Otherwise, at least
    ONE of those basenames must appear in extract_pointed_etalons(text) — a
    skill may legitimately point at only one of two variant files (project-
    init's `## Files` per-variant walkthrough) or both (stores/layouts' single
    "X or Y" sentence), but pointing at NEITHER, or at a name that doesn't
    match anything the skill itself ships, fails the contract.
    """
    if not own_etalon_names:
        return []
    pointed = extract_pointed_etalons(text)
    if not (pointed & own_etalon_names):
        return [("error", "missing-reference-pointer",
                 "ships references/*.md etalon(s) but the body never says "
                 "\"Read `references/<file>.md` ... reproduce it\" naming one of "
                 f"its own files ({', '.join(sorted(own_etalon_names))})")]
    return []


def check_orphan_etalon(own_etalon_names, text):
    """A references/*.md file that no paragraph in its own SKILL.md ever sends
    the reader to (see extract_pointed_etalons) is dead weight — authored,
    presumably once valid, but unreachable: an agent reading the skill body
    is never told it exists, so it can never influence what gets reproduced.

    WARNING, not error: unlike a missing pointer (check_reference_pointer,
    which means the skill produces ZERO guaranteed etalon-backed output and
    is functionally still direction-style), an orphan file alongside at least
    one properly-pointed-to sibling still lets the skill do its job — the
    orphan is wasted authoring effort and a maintenance trap (drifts silently
    since nothing exercises it), not a break in the reference-first
    guarantee itself. It should be cleaned up, but it does not justify
    failing the build.
    """
    pointed = extract_pointed_etalons(text)
    orphans = sorted(own_etalon_names - pointed)
    return [("warning", "orphan-etalon",
             f"`references/{o}` is never pointed at by a \"reproduce it\" instruction "
             "in this SKILL.md — dead weight, wire it in or delete it")
            for o in orphans]


def check_direction_style(text, has_valid_etalon, name=None):
    """`has_valid_etalon` must mean references/ holds at least one *.md that
    passes check_etalon with zero errors — an empty or invalid references/
    directory is not an etalon and must not grant the exemption.

    Reference-first is unconditional for a non-skeleton skill in a CODE_PLUGINS
    plugin: it must have a valid etalon regardless of whether its OWN body
    happens to contain a fenced/indented code fragment (see has_code_fragments,
    which is no longer consulted here — a prose-only skill ("do X, never Y") is
    still a direction the agent re-interprets every run unless a full-file
    etalon backs it). The only exemptions are an explicit skeleton marker
    (`is_skeleton`) and an explicit, hard-coded umbrella-skill allow-list
    (`is_umbrella`, matched on `name` — the frontmatter `name:`, never body
    text) — never the absence of code fragments, which is not evidence of
    anything.
    """
    if has_valid_etalon or is_skeleton(text) or is_umbrella(name):
        return []
    level = "error" if REFERENCE_FIRST_ENFORCED else "warning"
    return [(level, "direction-style", "code skill has no references/ etalon")]


INDENT = re.compile(r"^(?: {4,}|\t)\S")


def has_code_fragments(text, run_threshold=3):
    """True if the body contains a fenced code block, or a run of at least
    `run_threshold` consecutive lines indented by >=4 spaces (or a tab)
    outside any fenced block — the markdown convention for an indented code
    sample. A single indented line (e.g. a list continuation) must not
    count; only a sustained run does. This is NOT consulted by
    check_direction_style (reference-first is unconditional) — it exists so
    the indentation-detection logic itself has a dedicated regression test
    that fails honestly if the threshold rots.
    """
    run = 0
    for line, in_code, _ in split_code(text):
        if in_code:
            return True
        if INDENT.match(line):
            run += 1
            if run >= run_threshold:
                return True
        else:
            run = 0
    return False


def check_hardcoded_paths(text):
    """A match always begins with a literal alias prefix (`@/`, `~/`, or a
    bare `src/`) by construction of PATHISH — that is what makes it match at
    all. A token appearing later in the path (`@/shared/{entity}/x`) must
    not excuse it: only a path that STARTS with a token (which PATHISH never
    matches in the first place) is legal."""
    out = []
    for i, (line, in_code, _) in enumerate(split_code(text), 1):
        if not in_code or FENCE.match(line):
            continue
        for m in PATHISH.finditer(line):
            out.append(("error", "hardcoded-path",
                        f"line {i}: `{m.group(0)}` — use a placement token, not a literal path"))
    return out


def _is_known_token_path(path, known_tokens, file_valued_tokens=None, require_path=True):
    """True only if `path` starts with `{word}` AND `word` is an entry in
    known_tokens (the vocabulary parsed from placement.md). Matching the
    `{word}` SHAPE alone is not enough — `{not-a-token}/x.ts` looks exactly
    like a real token but names nothing in placement.md, and must be
    rejected just as hard as a bare literal path.

    Beyond the token itself, what may follow it depends on the token's role
    (placement.md §1, "A token names a BUCKET, with one file-valued
    exception"):
    - A BUCKET token (the default) must be followed by `/` and a non-empty
      path — `{app}` alone, or `{app}evil/x.ts` (no separator at all), names
      a directory, not a finished file. This is enforced only when
      `require_path` is True (the default, used for `**File:**` markers and
      `## Files` inventory entries, which must name a complete FILE). Set
      `require_path=False` for an IMPORT specifier: `{shared-lib}` bare is a
      legitimate reference to that bucket's directory barrel (its `index.ts`),
      not a finished file, so the bare-token form is allowed there.
    - A FILE-valued token (`file_valued_tokens`, currently just
      `{pages-types}`) must stand ALONE with nothing appended — bare
      `{pages-types}` is the one legal complete path; `{pages-types}/extra.ts`
      treats a single file as if it were a bucket with a slice underneath it.

    An etalon writes files INSIDE the bucket its token names — a path that
    escapes its own bucket via a `.` or `..` segment (`{project-root}/../outside.ts`,
    `{app}/../evil.ts`) is never legitimate, so any `.` or `..` segment anywhere
    in the remainder is rejected outright, not just a normalised form that
    walks above the token's directory. No real etalon in this corpus needs
    such a segment; if one ever legitimately does, that should be reported
    and the rule reconsidered, not silently loosened here.
    """
    if file_valued_tokens is None:
        file_valued_tokens = FILE_VALUED_TOKENS
    m = TOKEN_START.match(path)
    if not m or m.group(1) not in known_tokens:
        return False
    token = m.group(1)
    rest = path[m.end():]
    # `{...}` is reserved for the ONE leading placement token (placement.md §1) —
    # any additional `{...}` group later in the path (`{app}/{not-a-token}/main.ts`)
    # is not a second legitimate token, it's a placeholder that should have used
    # `<...>` instead. A path has exactly one token, at its start.
    if re.search(r"\{[^}]*\}", rest):
        return False
    if token in file_valued_tokens:
        return rest == ""
    if rest == "" and not require_path:
        return True
    if not (rest.startswith("/") and len(rest) > 1):
        return False
    segments = rest.split("/")[1:]
    # Every segment must be a real, non-empty path component: `.`/`..` escape
    # the token's own bucket (checked above already), but an EMPTY segment is
    # just as illegitimate — `{app}//x` (doubled slash), `{app}/foo/` (trailing
    # slash), and `{app}/foo//bar.ts` (doubled slash mid-path) all produce an
    # empty string in `segments` and must be rejected exactly like a `.`/`..`
    # escape, not silently accepted because the surrounding segments look fine.
    if any(seg in ("", ".", "..") for seg in segments):
        return False
    return True


def check_etalon(text, known_tokens=KNOWN_TOKENS):
    """references/<artifact>.md must satisfy the etalon contract.

    An etalon holds complete files, so every **File:** marker gets exactly
    one fenced block, no path appears twice (in the inventory or as a
    marker), no fence is left unclosed, and no fenced snippet floats free of
    a marker. `known_tokens` is the placement-token vocabulary parsed from
    placement.md (see load_known_tokens) — every inventory entry and every
    **File:** marker must start with a token drawn from it, not merely
    something brace-shaped.
    """
    raw = list(split_code(text))
    inventory, out = [], []

    in_files_section = False
    files_heading_idx = None
    for idx, (line, in_code, _) in enumerate(raw):
        if in_code:
            continue
        if line.startswith("#"):
            # The contract specifies exactly `## Files` — a level-1 (`# Files`) or
            # level-3+ (`### Files`) heading satisfies neither the contract's wording
            # nor the reader's expectation of where the inventory lives, so only the
            # exact two-hash form opens the section.
            is_files = re.match(r"^##\s+Files\s*$", line.strip()) is not None
            if is_files and files_heading_idx is None:
                files_heading_idx = idx
            in_files_section = is_files
            continue
        if in_files_section:
            m = INVENTORY_ITEM.match(line)
            if m:
                inventory.append(m.group(1))

    if not inventory:
        out.append(("error", "etalon-contract", "missing a `## Files` inventory listing every generated file"))
    else:
        dup_inventory = sorted({p for p in inventory if inventory.count(p) > 1})
        if dup_inventory:
            out.append(("error", "etalon-contract",
                        f"duplicate entries in `## Files` inventory: {', '.join(dup_inventory)}"))
        untokenised_inventory = sorted(p for p in set(inventory) if not _is_known_token_path(p, known_tokens))
        if untokenised_inventory:
            out.append(("error", "etalon-contract",
                        "`## Files` entry does not start with a known placement `{token}`: "
                        f"{', '.join(untokenised_inventory)}"))

    # Fence line indices, paired by position exactly like split_code's own
    # in_code toggle (open, close, open, close, ...). An odd count means a
    # fence was opened and never closed.
    fence_idxs = [i for i, (line, _, _) in enumerate(raw) if FENCE.match(line)]
    if len(fence_idxs) % 2 != 0:
        out.append(("error", "etalon-contract", "unclosed fenced code block — a ``` is opened but never closed"))
    fence_pairs = [(fence_idxs[k], fence_idxs[k + 1]) for k in range(0, len(fence_idxs) - 1, 2)]

    def blocks_in(lo, hi):
        return [(o, c) for o, c in fence_pairs if lo <= o < hi]

    marker_idxs = []
    for idx, (line, in_code, _) in enumerate(raw):
        if in_code:
            continue
        m = FILE_MARKER.match(line)
        if m:
            marker_idxs.append((m.group(1), idx))

    if not marker_idxs:
        out.append(("error", "etalon-contract", "no `**File:** `{token}/path`` markers — an etalon holds full files"))

    # The contract puts the inventory FIRST: a reader (or agent) scans `## Files`
    # to know what's coming before hitting the first full file. A `## Files`
    # heading that shows up AFTER the first **File:** marker still satisfies every
    # other check here (matching entries, no dupes, ...) but violates that
    # ordering, so it needs its own explicit check.
    if files_heading_idx is not None and marker_idxs and marker_idxs[0][1] < files_heading_idx:
        out.append(("error", "etalon-contract",
                    "`## Files` heading must appear before the first `**File:**` marker — "
                    "the inventory comes first"))

    markers = [p for p, _ in marker_idxs]
    dup_markers = sorted({p for p in markers if markers.count(p) > 1})
    if dup_markers:
        out.append(("error", "etalon-contract",
                    f"duplicate **File:** markers for the same path: {', '.join(dup_markers)}"))
    untokenised_markers = sorted(p for p in set(markers) if not _is_known_token_path(p, known_tokens))
    if untokenised_markers:
        out.append(("error", "etalon-contract",
                    "**File:** marker does not start with a known placement `{token}`: "
                    f"{', '.join(untokenised_markers)}"))

    first_marker_line = marker_idxs[0][1] if marker_idxs else len(raw)
    if blocks_in(0, first_marker_line):
        out.append(("error", "etalon-contract",
                    "fenced code block appears before any **File:** marker — "
                    "an etalon holds complete files, not loose snippets"))

    for k, (path, idx) in enumerate(marker_idxs):
        next_idx = marker_idxs[k + 1][1] if k + 1 < len(marker_idxs) else len(raw)
        blocks = blocks_in(idx, next_idx)
        if not blocks:
            out.append(("error", "etalon-contract",
                        f"`{path}`: no fenced code block directly after the **File:** marker"))
            continue
        first_open, first_close = blocks[0]
        between = raw[idx + 1:first_open]
        if any(l.strip() for l, _, _ in between):
            out.append(("error", "etalon-contract",
                        f"`{path}`: no fenced code block directly after the **File:** marker"))
        if not FENCE.match(raw[first_open][0]).group(1):
            out.append(("error", "etalon-contract",
                        f"`{path}`: fenced block has no language tag"))
        if len(blocks) > 1:
            out.append(("error", "etalon-contract",
                        f"`{path}`: more than one fenced code block before the next **File:** marker"))

    missing = sorted(set(inventory) - set(markers))
    extra = sorted(set(markers) - set(inventory))
    if missing:
        out.append(("error", "etalon-contract", f"listed in `## Files` but not written: {', '.join(missing)}"))
    if extra:
        out.append(("error", "etalon-contract", f"written but not listed in `## Files`: {', '.join(extra)}"))
    return out


IMPORT_SPEC = re.compile(
    r"""\bfrom\s+['"]([^'"]+)['"]              # named/default import
      | \bimport\s*\(\s*['"]([^'"]+)['"]        # dynamic import(...)
      | ^\s*import\s+['"]([^'"]+)['"]           # bare side-effect import './x'
    """, re.X | re.M)


def collect_shipped(text):
    """The set of **File:** token paths an etalon ships. Used both to build the
    corpus-wide index (see check_unresolved_relative_import) and, per-etalon, to
    know which markers are the importing files."""
    shipped = set()
    for line, in_code, _ in split_code(text):
        if in_code:
            continue
        m = FILE_MARKER.match(line)
        if m:
            shipped.add(m.group(1))
    return shipped


def check_unresolved_relative_import(text):
    """An etalon reproduces ONE artifact, not the whole app (authoring-knowledge-skills
    SKILL.md §7 "Where an etalon ends") — and per that section, a RELATIVE import
    (`./x`, `../x`) means "inside the etalon's OWN module": the etalon MUST ship that
    file itself. A file owned by a DIFFERENT etalon is reached by a TOKEN import
    (`{shared-lib}/toast`), never a relative one — so a relative specifier is resolved
    ONLY against this etalon's own **File:** markers, never against the rest of the
    corpus. Two etalons splitting ownership of neighbouring files is still allowed, but
    the importing side must use a token import to reach the other etalon's file, not a
    relative path. A TOKEN import or a bare package import is an external reference by
    design and is out of scope entirely — never flagged here.

    Import forms checked: `from '...'`, dynamic `import('...')`, and bare side-effect
    `import '...'` (no bindings, no `from` — e.g. a stylesheet or a polyfill). All three
    are equally real module-graph edges; a side-effect import used to be invisible here
    because IMPORT_SPEC only recognised the first two forms.

    Resolution forms accepted, mirroring real bundler resolution:
    - an exact path match,
    - an extension-less specifier resolving to `.ts` / `.vue` / `.js`,
    - a directory specifier resolving to that directory's `index.ts`.

    `import.meta.glob(...)` calls and any line marked `// @arch-relative` are
    deliberately architecture-relative literals, not module imports — skipped.

    The scan runs against the WHOLE code block for a marker's span, not line
    by line — a specifier split across lines (a dynamic `import(\n './x'\n)`,
    or a multi-line `import { a, b }\n  from './x'`) never has its complete
    form on any single line, so a per-line regex pass silently misses it and
    the strict same-etalon rule is bypassed. Lines carrying the glob/skip
    markers are dropped BEFORE the block is joined, so those exclusions still
    apply per-line exactly as before.
    """
    raw = list(split_code(text))
    marker_idxs = []
    for idx, (line, in_code, _) in enumerate(raw):
        if in_code:
            continue
        m = FILE_MARKER.match(line)
        if m:
            marker_idxs.append((m.group(1), idx))
    if not marker_idxs:
        return []

    shipped = {p for p, _ in marker_idxs}
    out = []
    for k, (path, idx) in enumerate(marker_idxs):
        next_idx = marker_idxs[k + 1][1] if k + 1 < len(marker_idxs) else len(raw)
        directory = posixpath.dirname(path)
        code_lines = [
            line for line, in_code, _ in raw[idx + 1:next_idx]
            if in_code and not FENCE.match(line)
            and "import.meta.glob" not in line and "@arch-relative" not in line
        ]
        block = "\n".join(code_lines)
        for m in IMPORT_SPEC.finditer(block):
            spec = m.group(1) or m.group(2) or m.group(3)
            if not (spec.startswith("./") or spec.startswith("../")):
                continue  # token import or bare package import — out of scope
            resolved = posixpath.normpath(posixpath.join(directory, spec))
            candidates = {resolved, resolved + ".ts", resolved + ".vue", resolved + ".js",
                          resolved + "/index.ts"}
            # NodeNext/ESM TypeScript: the source is authored with a `./foo.js`
            # (or `.mjs`/`.cjs`) specifier that the compiler resolves against the
            # `.ts`/`.mts`/`.cts` source file; the emitted JS really does import
            # `.js`. Both extensions name the same file — accept the sibling ext.
            JS_TO_TS = {".js": ".ts", ".mjs": ".mts", ".cjs": ".cts"}
            for js_ext, ts_ext in JS_TO_TS.items():
                if resolved.endswith(js_ext):
                    candidates.add(resolved[: -len(js_ext)] + ts_ext)
            if not (candidates & shipped):
                out.append(("error", "unresolved-relative-import",
                            f"`{path}`: unresolved relative import `{spec}` "
                            f"(resolved `{resolved}`) — this etalon does not ship it; "
                            "a file owned by another etalon must be reached by a "
                            "TOKEN import, not a relative one"))
    return out


def collect_token_imports(text):
    """Yield (importing_path, spec) for every TOKEN import (`{token}/...`) found
    in this etalon's fenced code, scanning the same marker spans and import
    forms as check_unresolved_relative_import — but keeping exactly the specs
    that function deliberately skips (anything NOT starting with `./` or
    `../`), since those are the ones under scope here.

    A specifier is collected here whenever it has the brace SHAPE (`{...}/x`),
    regardless of the casing/characters inside the braces — `{APP}/x`,
    `{app_name}/x`, and `{App}/x` are just as much a token reference as
    `{app}/x`, because `{...}` is reserved for placement tokens. Collecting
    only well-formed lowercase tokens here would let a malformed one slip
    through as an "ordinary package import" and skip grammar checking
    entirely; downstream checks (check_invalid_token_import) are what decide
    whether the collected specifier is actually valid.

    Scans the WHOLE joined code block for a marker's span, exactly like
    check_unresolved_relative_import — a per-line regex pass silently misses a
    specifier split across lines (a multiline `import {\n  a\n} from\n  '{token}/x'`),
    letting a malformed token import bypass validation entirely.
    """
    raw = list(split_code(text))
    marker_idxs = []
    for idx, (line, in_code, _) in enumerate(raw):
        if in_code:
            continue
        m = FILE_MARKER.match(line)
        if m:
            marker_idxs.append((m.group(1), idx))
    out = []
    for k, (path, idx) in enumerate(marker_idxs):
        next_idx = marker_idxs[k + 1][1] if k + 1 < len(marker_idxs) else len(raw)
        code_lines = [
            line for line, in_code, _ in raw[idx + 1:next_idx]
            if in_code and not FENCE.match(line)
            and "import.meta.glob" not in line and "@arch-relative" not in line
        ]
        block = "\n".join(code_lines)
        for m in IMPORT_SPEC.finditer(block):
            spec = m.group(1) or m.group(2) or m.group(3)
            if spec.startswith("./") or spec.startswith("../"):
                continue
            if BRACE_SHAPE.match(spec):
                out.append((path, spec))
    return out


def check_invalid_token_import(text, known_tokens=KNOWN_TOKENS):
    """A token import (`{token}/...`) must resolve against the SAME token
    vocabulary and path rules as a `**File:**` marker (`_is_known_token_path`)
    — an unknown token (`{not-a-token}/x`) or a bucket-escaping specifier
    (`{app}/../evil`) is exactly as invalid written as an import as it would
    be written as a marker, but until now only the marker form was checked.

    One deliberate difference from the marker check: an import specifier
    legitimately has no file extension (`{shared-lib}/toast`) and may address
    a directory barrel — `_is_known_token_path` already permits this (it never
    required an extension to begin with), so no extension carve-out is needed
    here beyond reusing that same function.

    A bare package import or relative import is out of scope (see
    collect_token_imports) — only specifiers that already have the `{token}`
    SHAPE are checked; anything else is an external reference by design.
    """
    out = []
    for path, spec in collect_token_imports(text):
        if not _is_known_token_path(spec, known_tokens, require_path=False):
            out.append(("error", "invalid-token-import",
                        f"`{path}`: imports `{spec}` — not a valid placement-token path "
                        "(unknown token, or escapes the token's own bucket)"))
    return out


def check_near_miss_token_import(text, corpus):
    """A token import (`{token}/path`) is an external reference by design
    (authoring-knowledge-skills SKILL.md §7 "Where an etalon ends") — the corpus
    is not the whole application, so an unresolved token import must NEVER be
    flagged on its own (see `unresolved-relative-import/token-import-ok.md`).

    But one narrower shape IS a real, corpus-internal defect: a token import
    whose TOKEN and FILENAME exactly match a path some etalon in this same
    plugin actually ships, at a DIFFERENT directory. That is not an external
    reference — it is two etalons disagreeing about where, inside the same
    token's namespace, a file lives (e.g. importing `{pages-ui}/HomePage.vue`
    while some etalon ships `{pages-ui}/home/HomePage.vue`). `corpus` is the
    variant-blind, whole-plugin set of shipped paths (see `full_corpus` in
    validate()) — this check is about path-shape consistency across the
    corpus, not per-etalon ownership.

    An EXACT match (the import already resolves against a shipped path) is
    silent — that is a resolved internal reference, not a near miss. A token
    whose filename appears nowhere in its own namespace is a true external
    and stays silent too, exactly as before.
    """
    by_token = {}
    for p in corpus:
        m = TOKEN_START.match(p)
        if m:
            by_token.setdefault(m.group(1), set()).add(p)

    out = []
    for path, spec in collect_token_imports(text):
        if spec in corpus:
            continue  # exact match — already a resolved internal reference
        m = TOKEN_START.match(spec)
        if not m:
            # Malformed casing/characters (`{APP}/x`, `{app_name}/x`) — not a
            # real token, so there is no token namespace to near-miss against.
            # check_invalid_token_import is what reports this specifier.
            continue
        token = m.group(1)
        basename = posixpath.basename(spec)
        near = sorted(p for p in by_token.get(token, ()) if posixpath.basename(p) == basename)
        if near:
            out.append(("warning", "near-miss-token-import",
                        f"`{path}`: imports `{spec}`, but the corpus ships "
                        f"{', '.join(near)} — same token and filename at a different "
                        "directory; fix the import path or the shipped path"))
    return out


def collect_shipped_blocks(text):
    """Map every **File:** token path this etalon ships to the content of the
    fenced code block directly after its marker (same resolution check_etalon
    uses: the first fenced block in the marker's span). Used to build the
    corpus-wide path -> [(etalon, content), ...] index for
    check_duplicate_file_owner, which needs actual file CONTENT — not just
    the path, unlike collect_shipped — to tell a pure duplicate (identical
    content, delete one) from a divergent copy (different content, the worse
    failure)."""
    raw = list(split_code(text))
    fence_idxs = [i for i, (line, _, _) in enumerate(raw) if FENCE.match(line)]
    fence_pairs = [(fence_idxs[k], fence_idxs[k + 1]) for k in range(0, len(fence_idxs) - 1, 2)]

    marker_idxs = []
    for idx, (line, in_code, _) in enumerate(raw):
        if in_code:
            continue
        m = FILE_MARKER.match(line)
        if m:
            marker_idxs.append((m.group(1), idx))

    blocks = {}
    for k, (path, idx) in enumerate(marker_idxs):
        next_idx = marker_idxs[k + 1][1] if k + 1 < len(marker_idxs) else len(raw)
        candidates = [(o, c) for o, c in fence_pairs if idx <= o < next_idx]
        if not candidates:
            continue
        open_i, close_i = candidates[0]
        blocks[path] = "\n".join(l for l, _, _ in raw[open_i + 1:close_i])
    return blocks


VARIANT_LINE = re.compile(r"^\s*Variant:\s*([A-Za-z][A-Za-z0-9_]*)\s*=\s*(\S+)\s*$")
# authoring-knowledge-skills SKILL.md §7 "The one exception — VARIANTS": the
# project-model constants fixed by the `vue-work` skill's step 0. A `Variant:`
# key outside this set cannot be a real project-model dimension — most likely
# a typo — and must not silently grant the duplicate-file-owner exemption.
KNOWN_VARIANT_KEYS = {"projectType", "architecture", "runtime"}

# Per-key allowed values — the actual branches of each project-model dimension
# fixed by the `vue-work` skill's step 0. Validating only the KEY (as before)
# let `Variant: projectType=banana` through unchallenged, and
# `_variants_complementary` would then treat it as a legitimate alternative to
# `projectType=csr`, silently granting a duplicate-ownership exemption to a typo.
VARIANT_VALUES = {
    "projectType": {"csr", "ssr"},
    "architecture": {"fsd", "non-fsd"},
    "runtime": {"vite-vue", "nuxt"},
}


FILES_HEADING = re.compile(r"^##\s+Files\s*$")


def _header_lines(text):
    """The (line, in_code, lang) tuples for lines BEFORE the first exact `## Files`
    heading — the header region a `Variant:` declaration must live in. Mirrors
    check_etalon's own heading match exactly (same regex, same "first occurrence
    wins" rule) so the two never disagree about where the header ends. If no such
    heading exists at all, the whole document counts as header — check_etalon
    already reports the missing-inventory error separately in that case."""
    out = []
    for line, in_code, lang in split_code(text):
        if not in_code and FILES_HEADING.match(line.strip()):
            break
        out.append((line, in_code, lang))
    return out


def parse_variant_declarations(text):
    """Every `Variant: key=value` declaration found in the header region (before
    the first `## Files` heading), outside fenced code. A `Variant:` line buried
    AFTER that heading is not a header declaration — it is prose or leftover
    content further down the file — and is deliberately excluded here, not just
    de-prioritised, so it can never silently grant a variant exemption it wasn't
    declared to have. Returns a list so callers can tell "no declaration" (empty),
    "one declaration" (single item), and "conflicting declarations" (2+ items)
    apart — the last of which is itself a contract violation, see
    check_variant_declaration."""
    out = []
    for line, in_code, _ in _header_lines(text):
        if in_code:
            continue
        m = VARIANT_LINE.match(line)
        if m:
            out.append((m.group(1), m.group(2)))
    return out


def parse_variant(text):
    """The single Variant declaration for callers (build_shipped_corpus) that just
    need "the" variant for the duplicate-file-owner exemption, not full validation.
    Returns the FIRST header-region declaration, or None. A second, conflicting
    declaration is a contract violation reported separately by
    check_variant_declaration — this function stays lenient (first one, not a
    raise) so a broken etalon doesn't crash the corpus-wide indexing pass; the
    error still surfaces through check_variant_declaration for that same etalon."""
    decls = parse_variant_declarations(text)
    return decls[0] if decls else None


def check_variant_declaration(text):
    """A declared `Variant:` key must be one of the recognised project-model
    constants, AND its value must be one of that key's recognised branches.
    An unknown key (typo, made-up dimension) or an unknown value (e.g.
    `projectType=banana`) must not be silently accepted — either would let a
    typo grant the duplicate-file-owner exemption it isn't entitled to,
    because `_variants_complementary` only checks that two declared variants
    disagree on value, not that the value is a real branch.

    A second requirement enforced here, not by parse_variant: exactly ONE
    declaration is allowed in the header region (before the `## Files`
    heading). Two conflicting `Variant:` lines there must not silently
    resolve to "the first one wins" — that is exactly as much a defect as an
    unrecognised key or value, so it is reported the same way, as an error.
    A `Variant:` line buried AFTER `## Files` is not a header declaration at
    all (see parse_variant_declarations) and never reaches this function."""
    decls = parse_variant_declarations(text)
    if not decls:
        return []
    if len(decls) > 1:
        return [("error", "invalid-variant",
                 "multiple `Variant:` declarations in the header region — exactly one "
                 f"is allowed: {', '.join(f'{k}={v}' for k, v in decls)}")]
    key, value = decls[0]
    if key not in KNOWN_VARIANT_KEYS:
        return [("error", "invalid-variant",
                 f"`Variant: {key}=...` — unknown key, must be one of "
                 f"{', '.join(sorted(KNOWN_VARIANT_KEYS))}")]
    allowed = VARIANT_VALUES[key]
    if value not in allowed:
        return [("error", "invalid-variant",
                 f"`Variant: {key}={value}` — unknown value, must be one of "
                 f"{', '.join(sorted(allowed))}")]
    return []


def build_shipped_corpus(labeled_texts):
    """labeled_texts: iterable of (label, text) — label identifies the owning
    etalon (its relative path). Returns path -> [(label, content, variant), ...]
    merged across every given etalon via collect_shipped_blocks, where variant
    is parse_variant(text) (None, or a (key, value) tuple). Shared by the real
    driver (validate(), which labels with the etalon's relpath) and the
    duplicate-file-owner self-test fixture pairing (which labels with the
    fixture filenames)."""
    corpus = {}
    for label, text in labeled_texts:
        variant = parse_variant(text)
        for path, content in collect_shipped_blocks(text).items():
            corpus.setdefault(path, []).append((label, content, variant))
    return corpus


def _variants_complementary(v1, v2):
    """True only when both etalons declare a Variant, with the SAME key and a
    DIFFERENT value — the one shape that means "alternatives, not a
    conflict" (authoring-knowledge-skills SKILL.md §7). No variant at all,
    the same key AND same value, or two different keys are all still a
    conflict — a variant declaration only excuses a same-path collision when
    it actually names two branches of one project-model choice."""
    return v1 is not None and v2 is not None and v1[0] == v2[0] and v1[1] != v2[1]


def check_duplicate_file_owner(corpus):
    """authoring-knowledge-skills SKILL.md §7 "Where an etalon ends": when two
    etalons need the same file, EXACTLY ONE ships it and the other imports it
    by token. The `unresolved-relative-import` corpus collapses shipped paths
    into a plain set, so two etalons shipping the SAME token path go
    unnoticed — this detector is the missing other half, built from
    `build_shipped_corpus` (path -> [(etalon, content, variant), ...]) instead.

    Exception (§7 "The one exception — VARIANTS"): two etalons sharing a path
    do NOT conflict when they form a complementary variant pair (see
    `_variants_complementary`) — mutually exclusive alternatives a reader
    chooses between via a project-model constant, never both. Checked
    pairwise, so three-or-more owners on one path still flag whichever pairs
    are NOT complementary (e.g. a third, variant-less etalon squatting on a
    path two others have legitimately split into variants).

    For every path with at least one non-exempt pair, every owner involved in
    such a pair is named in the message, which distinguishes two cases
    because they are fixed differently:
    - identical content -> pure duplication, delete one.
    - different content -> divergent copies, the worse failure: a reader
      reproduces whichever they read last, not necessarily the "real" owner.
    """
    out = []
    for path, owners in sorted(corpus.items()):
        if len(owners) < 2:
            continue
        conflicting_pairs = [
            (a, b) for i, a in enumerate(owners) for b in owners[i + 1:]
            if not _variants_complementary(a[2], b[2])
        ]
        if not conflicting_pairs:
            continue
        involved = sorted({label for pair in conflicting_pairs for label, _, _ in pair})
        contents = {content for label, content, _ in owners if label in involved}
        if len(contents) == 1:
            out.append(("error", "duplicate-file-owner",
                        f"`{path}` is shipped identically by {', '.join(involved)} — "
                        "pure duplication: delete it from all but one and let the others "
                        "import it by token"))
        else:
            out.append(("error", "duplicate-file-owner",
                        f"`{path}` is shipped with DIFFERENT content by {', '.join(involved)} — "
                        "divergent copies: worse than duplication, a reader reproduces "
                        "whichever copy they read last; pick one owner and have the rest "
                        "import it by token"))
    return out


def dir_has_valid_etalon(refs_dir):
    """True only if refs_dir exists and holds at least one *.md that passes
    check_etalon with zero errors. An empty directory, or one holding only
    invalid etalons, must not count as having an etalon."""
    if not refs_dir.is_dir():
        return False
    return any(not check_etalon(md.read_text()) for md in refs_dir.glob("*.md"))


def check_by_name(text, registry, own_name):
    """Backticked skill names referenced by name must exist."""
    out = []
    body = prose(text).replace("**", "")
    found = set()
    for rx in (NAME_THEN_SKILL, SKILL_THEN_NAME):
        for m in rx.finditer(body):
            found.add(m.group(1))
    for block in re.finditer(r"^#+\s+Related skills\s*$(.*?)(?=^#|\Z)", body, re.M | re.S):
        for m in re.finditer(r"^\s*[-*]\s+`([a-z0-9][a-z0-9-]*)`", block.group(1), re.M):
            found.add(m.group(1))
    for name in sorted(found):
        if name == own_name:
            continue
        owners = registry.get(name)
        if not owners:
            out.append(("error", "broken-by-name", f"references the `{name}` skill, which does not exist"))
        elif len(owners) > 1 and not re.search(rf"`{re.escape(name)}`[^.\n]*\bfrom\s+\S", body):
            out.append(("warning", "ambiguous-by-name",
                        f"`{name}` exists in {', '.join(sorted(owners))} — qualify it with \"from <plugin>\""))
    return out


# ---------------------------------------------------------------- driver

def skill_name(text):
    parts = text.split("---")
    fm = parts[1] if len(parts) >= 3 else ""
    m = re.search(r"^name:\s*(\S+)", fm, re.M)
    return m.group(1) if m else None


def build_registry(plugin_roots):
    reg = {}
    for root in plugin_roots:
        for sk in root.glob("skills/**/SKILL.md"):
            n = skill_name(sk.read_text())
            if n:
                reg.setdefault(n, set()).add(root.name)
    return reg


def validate():
    issues = []  # (level, plugin, relpath, code, message)
    roots = sorted(p for p in PLUGINS_DIR.glob("knowledge*") if p.is_dir())
    registry = build_registry(roots)

    for root in roots:
        rootr = root.resolve()
        mf = root / ".claude-plugin/plugin.json"
        if not mf.exists():
            issues.append(("error", root.name, ".claude-plugin/plugin.json", "manifest", "missing"))
            continue
        try:
            json.load(open(mf))
        except Exception as e:
            issues.append(("error", root.name, ".claude-plugin/plugin.json", "manifest", str(e)))

        is_code_plugin = root.name in CODE_PLUGINS

        for sk in sorted(root.glob("skills/**/SKILL.md")):
            rel = str(sk.relative_to(root))
            text = sk.read_text()
            name = skill_name(text)
            if not name or "description:" not in text.split("---")[1]:
                issues.append(("error", root.name, rel, "frontmatter", "missing name:/description:"))
            for lvl, code, msg in check_stub(text) + check_body_length(text):
                issues.append((lvl, root.name, rel, code, msg))
            for lvl, code, msg in check_by_name(text, registry, name):
                issues.append((lvl, root.name, rel, code, msg))
            if is_code_plugin:
                has_valid_etalon = dir_has_valid_etalon(sk.parent / "references")
                for lvl, code, msg in check_direction_style(text, has_valid_etalon, name):
                    issues.append((lvl, root.name, rel, code, msg))
                if not is_skeleton(text):
                    refs_dir = sk.parent / "references"
                    own_etalon_names = ({p.name for p in refs_dir.glob("*.md")}
                                         if refs_dir.is_dir() else set())
                    for lvl, code, msg in check_reference_pointer(text, own_etalon_names):
                        issues.append((lvl, root.name, rel, code, msg))
                    for lvl, code, msg in check_orphan_etalon(own_etalon_names, text):
                        issues.append((lvl, root.name, rel, code, msg))

        if is_code_plugin:
            etalons = sorted(root.glob("skills/**/references/*.md")) + sorted(root.glob("core/references/*.md"))
            etalon_texts = {etalon: etalon.read_text() for etalon in etalons}
            # Corpus-wide index: every **File:** path shipped by ANY etalon in this
            # plugin, not just the one under test. Used as-is (variant-blind) only by
            # the near-miss token-import check below, which is about path-shape
            # consistency across the WHOLE corpus, not per-etalon ownership.
            full_corpus = set()
            for t in etalon_texts.values():
                full_corpus |= collect_shipped(t)
            for etalon in etalons:
                rel = str(etalon.relative_to(root))
                etalon_text = etalon_texts[etalon]
                for lvl, code, msg in check_etalon(etalon_text):
                    issues.append((lvl, root.name, rel, code, msg))
                for lvl, code, msg in check_variant_declaration(etalon_text):
                    issues.append((lvl, root.name, rel, code, msg))
                # STRICT reading of authoring-knowledge-skills SKILL.md §7: a relative
                # import resolves ONLY against this etalon's own shipped files, never
                # against the rest of the corpus. A file owned by another etalon must
                # be reached by a TOKEN import instead.
                for lvl, code, msg in check_unresolved_relative_import(etalon_text):
                    issues.append((lvl, root.name, rel, code, msg))
                for lvl, code, msg in check_invalid_token_import(etalon_text):
                    issues.append((lvl, root.name, rel, code, msg))
                for lvl, code, msg in check_near_miss_token_import(etalon_text, full_corpus):
                    issues.append((lvl, root.name, rel, code, msg))

            # Corpus-wide, not per-etalon: two etalons shipping the SAME token
            # path is a plugin-level defect, not a property of either file alone.
            corpus_blocks = build_shipped_corpus(
                (str(etalon.relative_to(root)), etalon_texts[etalon]) for etalon in etalons)
            for lvl, code, msg in check_duplicate_file_owner(corpus_blocks):
                issues.append((lvl, root.name, "(corpus)", code, msg))

        for md in sorted(list(root.glob("skills/**/*.md")) + list(root.glob("core/**/*.md"))):
            rel = str(md.relative_to(root))
            text = md.read_text()
            for m in REF.finditer(text):
                target = (md.parent / m.group(1)).resolve()
                if not target.exists():
                    issues.append(("error", root.name, rel, "broken-ref", f"`{m.group(1)}`"))
                elif rootr not in target.parents:
                    issues.append(("error", root.name, rel, "cross-plugin-ref",
                                   f"`{m.group(1)}` must stay within the plugin"))
            for m in LOOSE_TAG.finditer(text):
                if not TAG.fullmatch(m.group(0)):
                    issues.append(("error", root.name, rel, "malformed-tag", m.group(0)))
            if is_code_plugin:
                for lvl, code, msg in check_hardcoded_paths(text):
                    issues.append((lvl, root.name, rel, code, msg))
    return issues


def report(issues):
    errors = [i for i in issues if i[0] == "error"]
    warnings = [i for i in issues if i[0] == "warning"]
    for lvl, plugin, rel, code, msg in warnings + errors:
        print(f"{lvl.upper()}: [{code}] {plugin}/{rel}: {msg}")
    if errors:
        print(f"\nfailed: {len(errors)} error(s), {len(warnings)} warning(s)")
        return 1
    print(f"ok: structure valid ({len(warnings)} warning(s))")
    return 0


# ---------------------------------------------------------------- self-test

SELF_TEST = [
    ("direction-style/SKILL.md", "direction-style",
     lambda t: check_direction_style(t, has_valid_etalon=False)),
    ("etalon-contract/references/bad-etalon.md", "etalon-contract", check_etalon),
    ("long-body/SKILL.md", "long-body", check_body_length),
    ("hardcoded-path/SKILL.md", "hardcoded-path", check_hardcoded_paths),
    ("broken-by-name/SKILL.md", "broken-by-name",
     lambda t: check_by_name(t, {"pages": {"knowledge-vue"}}, "example")),
    ("stub/SKILL.md", "stub", check_stub),
    # Empty/invalid references/ must not grant a free pass (bypass #1): the
    # skill has code fragments and a references/ dir, but the dir holds no
    # *.md that passes check_etalon with zero errors.
    ("empty-references/SKILL.md", "direction-style",
     lambda t: check_direction_style(
         t, dir_has_valid_etalon(FIXTURES / "empty-references" / "references"))),
    # A literal alias prefix followed later by a token must still be caught
    # (bypass #2) — only a path that STARTS with a token is legal.
    ("pathish-mask/SKILL.md", "hardcoded-path", check_hardcoded_paths),
    # check_etalon must enforce the full-file contract, not just presence
    # of markers/inventory (bypass #3, five sub-checks).
    ("etalon-contract/references/dup-inventory.md", "etalon-contract", check_etalon),
    ("etalon-contract/references/dup-marker.md", "etalon-contract", check_etalon),
    ("etalon-contract/references/extra-block.md", "etalon-contract", check_etalon),
    ("etalon-contract/references/unclosed-fence.md", "etalon-contract", check_etalon),
    ("etalon-contract/references/orphan-snippet.md", "etalon-contract", check_etalon),
    # Code indented by MORE than four spaces must still be detected as code
    # (bypass #4) — the threshold is >=4 leading spaces/tab, not exactly 4.
    # This fixture ships a VALID references/ etalon precisely so the
    # missing-etalon path of check_direction_style cannot fire and mask a
    # regression in indentation detection — has_code_fragments() is asserted
    # directly on the fixture text instead.
    ("indented-code/SKILL.md", "code-fragment",
     lambda t: [("error", "code-fragment", "indented code detected")] if has_code_fragments(t) else []),
    # A skeleton marker alone must not exempt a long, finished skill
    # (bypass #5) — the body must also be short.
    ("fake-skeleton/SKILL.md", "direction-style",
     lambda t: check_direction_style(t, has_valid_etalon=False)),
    # Reference-first is unconditional (bypass #6): a code-producing skill whose
    # rules are pure prose (no fenced/indented code) and which ships no
    # references/ dir at all must still fail — has_code_fragments used to gate
    # this check and let such a skill through with no etalon whatsoever.
    ("prose-only-no-etalon/SKILL.md", "direction-style",
     lambda t: check_direction_style(t, has_valid_etalon=False)),
    # An etalon's `## Files` inventory and **File:** markers must START with a
    # placement token (bypass #7) — `app/foo.ts` / `@/shared/x.ts` must not pass
    # just because check_hardcoded_paths only scans inside fenced code blocks.
    ("etalon-contract/references/untokenised-path.md", "etalon-contract", check_etalon),
    # A brace-shaped word that is NOT a real placement token must still be
    # rejected (bypass #8) — `{not-a-token}/x.ts` has the right SHAPE but is
    # not a row in placement.md's token table, parsed fresh at run time.
    ("etalon-contract/references/unknown-token.md", "etalon-contract", check_etalon),
    # A recognised BUCKET token must be followed by `/` and a non-empty path
    # (bypass #10) — `{app}evil/x.ts` starts with the recognised prefix `{app}`
    # but has no separator at all, so it names no real bucket.
    ("etalon-contract/references/malformed-token-separator.md", "etalon-contract", check_etalon),
    # A FILE-valued token (`{pages-types}`) must stand ALONE with nothing
    # appended (bypass #11) — `{pages-types}/extra.ts` treats a single-file
    # token as if it were a bucket with a slice underneath it.
    ("etalon-contract/references/file-valued-token-with-path.md", "etalon-contract", check_etalon),
    # A `..` segment must not be allowed to walk a token path back out of its
    # own bucket (bypass #12) — `{project-root}/../outside.ts` has a real
    # token and a real-looking suffix, but escapes the directory the token
    # names, which an etalon must never do.
    ("etalon-contract/references/path-traversal.md", "etalon-contract", check_etalon),
    # The `(umbrella)` heading marker is no longer the exemption mechanism
    # (bypass #9) — only UMBRELLA_SKILLS (matched on frontmatter `name:`)
    # grants it. A skill that plants the marker but isn't on the allow-list
    # must still be flagged.
    ("umbrella-loophole/SKILL.md", "direction-style",
     lambda t: check_direction_style(t, has_valid_etalon=False, name=skill_name(t))),
    # A relative import with no matching **File:** entry is a real defect — the
    # reader cannot reproduce a working module (authoring-knowledge-skills SKILL.md
    # §7 "Where an etalon ends").
    ("unresolved-relative-import/missing-relative.md", "unresolved-relative-import",
     check_unresolved_relative_import),
    # Guard against regressing into the WRONG standard: a token import
    # (`{shared-lib}/toast`) is an external reference by design and must never be
    # flagged, even though the etalon ships nothing for it.
    ("unresolved-relative-import/token-import-ok.md", "no-false-positive",
     lambda t: ([("error", c, m) for _, c, m in check_unresolved_relative_import(t)
                 if c == "unresolved-relative-import"]
                or [("ok", "no-false-positive", "clean")])),
    # STRICT reading (authoring-knowledge-skills SKILL.md §7): a relative import
    # resolves ONLY against the IMPORTING etalon's own shipped files. This etalon
    # relatively imports a sibling that a DIFFERENT etalon ships (`cross-etalon-b.md`)
    # — that is exactly the shape §7 forbids for a relative specifier (it should be a
    # TOKEN import instead), so it must be flagged even though some etalon in the
    # corpus does ship the file.
    ("unresolved-relative-import/cross-etalon-a.md", "unresolved-relative-import",
     check_unresolved_relative_import),
    # NodeNext/ESM TypeScript: a `./foo.js` specifier legitimately resolves to a
    # shipped `foo.ts` source file — the compiler resolves the extension, the
    # emitted JS really does import `.js`. Must NOT be flagged.
    ("unresolved-relative-import/js-extension-ts-source.md", "no-false-positive",
     lambda t: ([("error", c, m) for _, c, m in check_unresolved_relative_import(t)
                 if c == "unresolved-relative-import"]
                or [("ok", "no-false-positive", "clean")])),
    # A bare side-effect import (`import './missing.css'` — no bindings, no
    # `from`) must be checked exactly like `from '...'`/`import('...')` — it
    # used to be invisible to IMPORT_SPEC entirely.
    ("unresolved-relative-import/side-effect-missing.md", "unresolved-relative-import",
     check_unresolved_relative_import),
    # A dynamic import specifier split across lines (`import(\n './missing'\n)`)
    # must still be caught — a per-line regex scan never sees the complete
    # `import( '...' )` shape on any single line and used to miss it entirely.
    ("unresolved-relative-import/multiline-dynamic-missing.md", "unresolved-relative-import",
     check_unresolved_relative_import),
    # Two etalons shipping the SAME token path with DIFFERENT content — the
    # divergent-copies case, worse than pure duplication because a reader
    # reproduces whichever one they read last.
    ("duplicate-file-owner/owner-a.md", "duplicate-file-owner",
     lambda t: check_duplicate_file_owner(build_shipped_corpus([
         ("owner-a.md", t),
         ("owner-b.md", (FIXTURES / "duplicate-file-owner" / "owner-b.md").read_text()),
     ]))),
    # Two etalons sharing a path but declaring a COMPLEMENTARY variant pair
    # (same key, different value) are alternatives, not a conflict — must NOT
    # be flagged (authoring-knowledge-skills SKILL.md §7 "The one exception —
    # VARIANTS").
    ("duplicate-file-owner/variant-complementary-a.md", "no-false-positive",
     lambda t: ([("error", c, m) for _, c, m in check_duplicate_file_owner(build_shipped_corpus([
         ("variant-complementary-a.md", t),
         ("variant-complementary-b.md",
          (FIXTURES / "duplicate-file-owner" / "variant-complementary-b.md").read_text()),
     ])) if c == "duplicate-file-owner"]
                or [("ok", "no-false-positive", "clean")])),
    # Two etalons sharing a path and declaring the SAME variant key AND value
    # are not alternatives — still a conflict.
    ("duplicate-file-owner/variant-same-a.md", "duplicate-file-owner",
     lambda t: check_duplicate_file_owner(build_shipped_corpus([
         ("variant-same-a.md", t),
         ("variant-same-b.md", (FIXTURES / "duplicate-file-owner" / "variant-same-b.md").read_text()),
     ]))),
    # A `Variant:` key outside the recognised project-model constants
    # (`projectType`, `architecture`, `runtime`) is an invalid declaration —
    # a typo must not silently grant the variant exemption.
    ("duplicate-file-owner/invalid-variant.md", "invalid-variant", check_variant_declaration),
    # A recognised KEY with an unrecognised VALUE (`projectType=banana`) must be
    # rejected just as hard as an unrecognised key — validating only the key let
    # a typo'd value through, and `_variants_complementary` would then treat it
    # as a legitimate alternative to `projectType=csr`.
    ("duplicate-file-owner/invalid-variant-value.md", "invalid-variant", check_variant_declaration),
    # A token import whose token+filename matches a shipped path at a DIFFERENT
    # directory is a corpus-internal inconsistency, not an external reference —
    # must be flagged (WARNING, not error: could still be coincidence).
    ("near-miss-token-import/importer.md", "near-miss-token-import",
     lambda t: check_near_miss_token_import(
         t, collect_shipped(t) | collect_shipped(
             (FIXTURES / "near-miss-token-import" / "shipper.md").read_text()))),
    # A true external token import (no matching filename anywhere in its own
    # namespace) must stay silent — regressing this into "any unresolved token
    # import is suspicious" would defeat the whole point of §7's external-by-
    # design exemption.
    ("unresolved-relative-import/token-import-ok.md", "no-false-positive",
     lambda t: ([("warning", c, m) for _, c, m in check_near_miss_token_import(t, collect_shipped(t))
                 if c == "near-miss-token-import"]
                or [("ok", "no-false-positive", "clean")])),
    # A token import must be validated against the SAME token vocabulary as a
    # **File:** marker — an unknown token (`{not-a-token}/x`) used only to pass
    # the near-miss check, never validated itself, must now be flagged.
    ("invalid-token-import/unknown-token.md", "invalid-token-import", check_invalid_token_import),
    # A token import that escapes its own bucket via a `..` segment
    # (`{app}/../evil`) is exactly as invalid as the same escape in a **File:**
    # marker, and must be flagged the same way.
    ("invalid-token-import/traversal.md", "invalid-token-import", check_invalid_token_import),
    # collect_token_imports used to gate collection on TOKEN_START (lowercase
    # only) — an uppercase brace-shaped import specifier (`{APP}/x`) failed
    # that gate and was never even collected, so it silently passed as an
    # "ordinary external package import" instead of being checked against the
    # token grammar. Must now be flagged, matching the marker-form check.
    ("invalid-token-import/uppercase-import.md", "invalid-token-import", check_invalid_token_import),
    # Same collection gap, underscore shape (`{app_name}/x`) — must now be
    # flagged instead of silently passing as an external package import.
    ("invalid-token-import/underscore-import.md", "invalid-token-import", check_invalid_token_import),
    # Guard against overcorrecting: broadening collection to brace SHAPE must
    # not flag an ordinary package import (`import { ref } from 'vue'`, no
    # brace shape at all) or a legitimate lowercase token import
    # (`{shared-lib}/toast`) — both must stay silent.
    ("invalid-token-import/no-false-positive.md", "no-false-positive",
     lambda t: ([("error", c, m) for _, c, m in check_invalid_token_import(t)]
                or [("ok", "no-false-positive", "clean")])),
    # `{...}` is reserved for the ONE leading placement token — a second
    # `{...}` group later in the path (`{app}/{not-a-token}/main.ts`) must be
    # rejected, not treated as if only the leading token mattered.
    ("etalon-contract/references/nested-brace-token.md", "etalon-contract", check_etalon),
    # The contract requires exactly `## Files` — a `# Files` (or `### Files`)
    # heading must NOT open the inventory section.
    ("etalon-contract/references/wrong-heading-level.md", "etalon-contract", check_etalon),
    # Token grammar (round-10 tightening): case must match placement.md's
    # vocabulary EXACTLY — `{APP}` has the right shape but the wrong case.
    ("etalon-contract/references/uppercase-token.md", "etalon-contract", check_etalon),
    # An underscore is not part of the lowercase-kebab token grammar, and
    # `app_name` names no row in placement.md regardless.
    ("etalon-contract/references/underscore-token.md", "etalon-contract", check_etalon),
    # A doubled slash right after the token produces an EMPTY path segment —
    # must be rejected exactly like a `.`/`..` escape.
    ("etalon-contract/references/empty-segment.md", "etalon-contract", check_etalon),
    # A trailing slash leaves the last segment empty, naming a directory
    # instead of the complete file an etalon path must name.
    ("etalon-contract/references/trailing-slash.md", "etalon-contract", check_etalon),
    # An empty segment in the MIDDLE of the path (doubled slash between two
    # real-looking segments) must be caught too, not just at the ends.
    ("etalon-contract/references/empty-segment-mid.md", "etalon-contract", check_etalon),
    # Positive guard: `{project-root}/package.json` is a LEGITIMATE path — a
    # root file living directly under the `{project-root}` bucket with no
    # intermediate segment. Must never be "fixed" into a false positive.
    ("etalon-contract/references/project-root-file.md", "no-false-positive",
     lambda t: ([("error", c, m) for _, c, m in check_etalon(t)]
                or [("ok", "no-false-positive", "clean")])),
    # The contract puts the inventory FIRST — a `## Files` heading appearing
    # AFTER the first **File:** marker must be flagged even though every other
    # check (matching entries, single block, language tag, ...) still passes.
    ("etalon-contract/references/files-heading-after-marker.md", "etalon-contract", check_etalon),
    # Two conflicting `Variant:` declarations in the header region must not
    # silently resolve to "the first one wins" — it's an error.
    ("variant-header/duplicate-header-declaration.md", "invalid-variant", check_variant_declaration),
    # A `Variant:` line buried AFTER `## Files` is not a header declaration —
    # it must be ignored entirely (not parsed and then flagged as invalid).
    ("variant-header/buried-variant.md", "no-false-positive",
     lambda t: ([("error", c, m) for _, c, m in check_variant_declaration(t)]
                or [("ok", "no-false-positive", "clean")])),
    # The other half of reference-first (authoring-knowledge-skills SKILL.md §7):
    # a structurally valid etalon sitting in references/ is not enough — the
    # skill's OWN body must point at it by name in a "reproduce it" sentence.
    # This fixture's references/widget.md is valid (passes check_direction_style)
    # but nothing in SKILL.md ever names it — must be flagged.
    ("missing-reference-pointer/SKILL.md", "missing-reference-pointer",
     lambda t: check_reference_pointer(
         t, {p.name for p in (FIXTURES / "missing-reference-pointer" / "references").glob("*.md")})),
    # An etalon that no SKILL.md paragraph ever points at is dead weight — the
    # reader is never sent to it. `pointed.md` IS correctly named; its sibling
    # `unpointed.md` is not, and must be flagged as an orphan (warning, not
    # error: see check_orphan_etalon's docstring for the severity rationale).
    ("orphan-etalon/SKILL.md", "orphan-etalon",
     lambda t: check_orphan_etalon(
         {p.name for p in (FIXTURES / "orphan-etalon" / "references").glob("*.md")}, t)),
    # Positive guard: a skill correctly pointing at BOTH of its own variant
    # etalons in one "Read X (CSR) or Y (SSR) ... reproduce" sentence (the
    # stores.md/layouts.md shape) must trip neither check_reference_pointer
    # nor check_orphan_etalon.
    ("reference-pointer-variants/SKILL.md", "no-false-positive",
     lambda t: ([("error", c, m) for _, c, m in check_reference_pointer(
                     t, {p.name for p in (FIXTURES / "reference-pointer-variants" / "references").glob("*.md")})
                 + check_orphan_etalon(
                     {p.name for p in (FIXTURES / "reference-pointer-variants" / "references").glob("*.md")}, t)]
                or [("ok", "no-false-positive", "clean")])),
    # Bypass: a paragraph mentioning both the filename AND the word "reproduce"
    # used to satisfy check_reference_pointer regardless of polarity — "Do not
    # reproduce `references/x.md` here" passed just as easily as a real
    # instruction. Must now be flagged as missing-reference-pointer.
    ("negated-reference-pointer-do-not/SKILL.md", "missing-reference-pointer",
     lambda t: check_reference_pointer(
         t, {p.name for p in (FIXTURES / "negated-reference-pointer-do-not" / "references").glob("*.md")})),
    # Same bypass, a second negated phrasing ("instead of reproducing") —
    # must also still be flagged.
    ("negated-reference-pointer-instead-of/SKILL.md", "missing-reference-pointer",
     lambda t: check_reference_pointer(
         t, {p.name for p in (FIXTURES / "negated-reference-pointer-instead-of" / "references").glob("*.md")})),
    # Positive guard, the real plugin-registration/SKILL.md shape: ONE paragraph
    # legitimately both points at its own etalon with a real "reproduce it"
    # instruction AND names a different etalon it must NOT duplicate, negated
    # ("is **not** reproduced here either"). Tightening the rule to reject
    # negated instructions must not also reject this — each filename mention is
    # judged against its OWN nearest reproduce occurrence, not the paragraph as
    # a whole.
    ("reference-pointer-mixed/SKILL.md", "no-false-positive",
     lambda t: ([("error", c, m) for _, c, m in check_reference_pointer(
                     t, {p.name for p in (FIXTURES / "reference-pointer-mixed" / "references").glob("*.md")})]
                or [("ok", "no-false-positive", "clean")])),
]


def self_test():
    bad = []
    for rel, expected, fn in SELF_TEST:
        path = FIXTURES / rel
        if not path.exists():
            bad.append(f"missing fixture {rel}")
            continue
        codes = [c for _, c, _ in fn(path.read_text())]
        if expected in codes:
            print(f"ok: {expected} caught by fixtures/{rel}")
        else:
            bad.append(f"{expected} NOT caught by fixtures/{rel} (got: {codes or 'nothing'})")
    if bad:
        print("\n".join("FAIL: " + b for b in bad))
        return 1
    # Honest count: SELF_TEST mixes two different kinds of row, and neither
    # "catches their negative fixture" describes both. A NEGATIVE case is a real
    # violation that must be caught (`expected` is the defect's own code); a
    # POSITIVE GUARD (`expected == "no-false-positive"`) is legitimate input that
    # must NOT be flagged, which by definition catches nothing. Several negative
    # rows also re-test the same detector code against a different bypass, so
    # counting rows as "N detectors" was doubly misleading.
    negatives = [row for row in SELF_TEST if row[1] != "no-false-positive"]
    positives = [row for row in SELF_TEST if row[1] == "no-false-positive"]
    print(f"ok: {len(negatives)} negative case(s) each caught their real violation, "
          f"{len(positives)} positive guard(s) each stayed clean on legitimate input")
    return 0


if __name__ == "__main__":
    sys.exit(self_test() if "--self-test" in sys.argv else report(validate()))
