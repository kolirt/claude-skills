# Format gate — executable checks on publishable bodies (audit-pr)

Support file for `audit-pr` Steps 3 and 5. The format comes from SKILL §4.2/§4.4;
this gate verifies it **mechanically** (core §17) — a long thread of old-format
comments can anchor the drafting model, and the gate is what catches that. Run it
whenever a draft is (re)rendered, and again immediately before publishing. A body
that fails is rewritten — never shown to the user and never posted.

Write each publishable body to its own file, then:

```bash
# mode: issue (inline bodies + per-issue blocks) | summary (summary review body)
python3 - issue body-31.md body-32.md <<'EOF'
import re, sys
mode, files = sys.argv[1], sys.argv[2:]
EMOJI = re.compile(
    '[\u2300-\u23FF\u2600-\u27BF\u2B00-\u2BFF\uFE0F'
    '\U0001F000-\U0001FAFF]'
)
fail = False
for path in files:
    body = open(path, encoding='utf-8').read()
    errs = []
    m = EMOJI.search(body)
    if m:
        errs.append(f'emoji {m.group(0)!r}')
    if mode == 'issue':
        for label in ('**Problem**', '**Why**', '**Target**', '**Done when**'):
            if label not in body:
                errs.append(f'missing {label}')
    for line in body.splitlines():
        s = line.lstrip()
        if s.startswith('- [x]') and '~~' not in s:
            errs.append(f'checked row without strikethrough: {s[:60]}')
        if s.startswith('- [ ]') and '~~' in s:
            errs.append(f'open row with strikethrough: {s[:60]}')
    if errs:
        fail = True
        print(path + ': ' + '; '.join(errs))
print('FAIL' if fail else 'OK')
EOF
```

- `mode=issue` — inline comment bodies and each per-issue block of the summary:
  the §4.2 scaffold labels are mandatory in every one of them.
- `mode=summary` — the summary review body as a whole (prose + Follow-ups +
  Checklist): no scaffold requirement; the emoji and checkbox rules still apply.
- Checkbox semantics being enforced: `- [x]` appears ONLY together with
  strikethrough (`~~…~~`) and a fix-commit link; an open item is `- [ ]` and
  carries no strikethrough. An open issue marked `[x]` is exactly the drift this
  catches.
- The scan intentionally flags every pictographic character — the old scaffold's
  markers included. Plain arrows (`→`) and markdown punctuation pass.
- The disclosure prefix and the `### Issue N` heading are checked by the Step 5
  guard (SKILL §4.1); this gate does not duplicate that check.
