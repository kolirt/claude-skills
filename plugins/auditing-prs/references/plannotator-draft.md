# Reviewing the audit draft in Plannotator (audit-pr)

Support file for `audit-pr` Step 3. Plannotator is a drop-in for the "present, then
WAIT" checkpoint — it changes *how* the user reacts, never *whether* they must
explicitly approve before Step 5.

## 1. Render the draft to a file

One markdown file in a temp location, e.g. `"$(mktemp -d)/pr-{N}-audit.md"`, holding
all three draft parts in the usual order (tracker context → review-state digest →
audit findings). The tracker block and the digest are still **chat-only** — never
published to GitHub — but they belong in the file because they help the user review.
Open the file with a title line (e.g. `# PR {N} — audit draft`), never a bare `---`,
which can parse as YAML front matter.

This file is **live Markdown, and is the explicit exception to the SKILL's "show
drafts as fenced markdown" rule** — that rule governs chat, which stays the
raw-source preview. Hard rules for the file:

- **No outer code fence around any part.** Plannotator renders a fence as a
  non-wrapping block, so long prose lines vanish behind a horizontal scrollbar.
- **Paste each publishable body verbatim** — byte-for-byte the same text that goes
  to chat and to GitHub, minus the outer fence. Never reflow, re-indent, re-quote,
  escape or regenerate it.
- **Fences *inside* a body stay fenced** (code quotes, ` ```suggestion `) and must
  be balanced — an unclosed inner fence swallows the rest of the document.
- **The review-state digest and the stacked-branch line may be reformatted**,
  because they are chat-only chrome: emit one Markdown list item per bucket instead
  of the whitespace-aligned columns (alignment does not survive live Markdown and is
  not needed for review). This freedom applies ONLY to chat-only blocks —
  publishable bodies stay verbatim.
- **Separate issues with `---`, preceded by the target as a bold line** (e.g.
  `**path/to/File.vue:8**`), not a heading — the body already carries its own
  `### Issue N`, and a second heading would duplicate it in the outline.
- **Everything the file adds around the drafts is Plannotator-only chrome** — the
  document title, the bold locator lines, the bold summary-review label and the
  `---` separators. None of it is ever part of a published comment body; only the
  verbatim body between them is publishable.
- **The summary review has no file:line** — label it with a plain bold line placed
  *outside* its verbatim body. Never invent a locator for it.

Skeleton of the finished file (`←` marks Plannotator-only chrome):

```markdown
# PR {N} — audit draft            ← chrome

## Task context (<ticket>)        ← chat-only, reformat freely
…tracker context…

## Review state @ HEAD <sha>      ← chat-only, reformat freely
- 🧬 Stacked on PR <parent-N> (<parent-branch>) — audited range <TRUE_BASE>..<head-sha>
- ✅ Closing — verified done: Issue 5 (<commit>), Issue 7 (<commit>)
- 🆕 New this review: Issue 8 — <one line>
- ⏳ Not fixed / partial / open: Issue 8 — partial: <one line>
- 🎯 Asks (<ticket>): <ask> ✅ · <ask> ❌
- 📮 Follow-ups (out of scope): <one line>
- 🏁 Convergence: not yet — <what remains>

---                               ← chrome
**src/components/Form.vue:42**    ← chrome

> _[Claude review] — automated audit published via Claude Code from account @<gh-username>_

### Issue 8
…verbatim publishable body, inner fences intact…

---                               ← chrome
**Summary review**                ← chrome

> _[Claude review] — automated audit published via Claude Code from account @<gh-username>_

### Issue 9
…verbatim publishable summary body, ending with the checklist (SKILL §4.8)…
```

## 2. Open the annotator and read its result

```bash
plannotator annotate "$FILE"
```

## 3. Act on the result — map it onto the Step 3 loop

- `The user approved.` / `"decision": "approved"` → treat as the explicit approval
  Step 5 requires. Proceed to publish.
- Empty / `"decision": "dismissed"` → the user closed without deciding. Do NOT
  publish and do NOT force a menu; hand control back with an open prompt, same as
  the chat checkpoint.
- Plaintext feedback / `"decision": "annotated"` with `"feedback"` → revise the
  draft per the annotations (including a brand-new issue raised there — Step 2.5),
  then re-render and re-open the annotator. This is the normal revise loop.
  Annotations that drop or add a finding renumber the surviving batch (SKILL §4.5)
  before the file is re-rendered — report the new numbers, not the old ones.

Fall back to the chat checkpoint whenever Plannotator is absent, the probe fails, or
the user prefers chat. Everything else about Step 3 — never publishing without
approval, the open iterative loop, treating new issues as normal — is unchanged.
