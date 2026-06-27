#!/usr/bin/env python3
"""Structural validator for all knowledge* plugins (no app runtime to test)."""
import json, re, sys, pathlib

plugins_dir = pathlib.Path(__file__).resolve().parents[2]  # .../plugins
fail = []
ref = re.compile(r"Read `([^`]+\.md)`")
tag = re.compile(r"\[(invariant|preference|anti-pattern) · (desired|legacy)\]")

for root in sorted(p for p in plugins_dir.glob("knowledge*") if p.is_dir()):
    rootr = root.resolve()
    # (a) manifest parses
    mf = root / ".claude-plugin/plugin.json"
    if not mf.exists():
        fail.append(f"{root.name}: missing .claude-plugin/plugin.json")
        continue
    try:
        json.load(open(mf))
    except Exception as e:
        fail.append(f"{root.name}: plugin.json: {e}")
    # (b) frontmatter on every SKILL.md
    for sk in sorted(root.glob("skills/**/SKILL.md")):
        parts = sk.read_text().split("---")
        fm = parts[1] if len(parts) >= 3 else ""
        if "name:" not in fm or "description:" not in fm:
            fail.append(f"{root.name}: frontmatter missing in {sk.relative_to(root)}")
    # (c) references resolve AND stay within this plugin
    for md in sorted(list(root.glob("skills/**/*.md")) + list(root.glob("core/**/*.md"))):
        for m in ref.finditer(md.read_text()):
            target = (md.parent / m.group(1)).resolve()
            if not target.exists():
                fail.append(f"{root.name}: broken ref `{m.group(1)}` in {md.relative_to(root)}")
            elif rootr not in target.parents:
                fail.append(f"{root.name}: cross-plugin ref `{m.group(1)}` in {md.relative_to(root)} (must stay within the plugin)")
    # (d) tagged rule present in the shared-wrapper invariant once it exists
    swd = root / "core/shared-wrapper-discipline.md"
    if swd.exists() and not tag.search(swd.read_text()):
        fail.append(f"{root.name}: no tagged rule in core/shared-wrapper-discipline.md")

if fail:
    print("\n".join("FAIL: " + x for x in fail))
    sys.exit(1)
print("ok: structure valid")
sys.exit(0)
