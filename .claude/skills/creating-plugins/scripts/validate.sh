#!/usr/bin/env bash
# Validate marketplace.json and every plugin it lists.
# Checks: required fields; each source path exists with a plugin.json;
# plugin.json name matches the entry; entry version matches plugin.json version.
# Usage: validate.sh   (run anywhere inside the marketplace repo)
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$ROOT" ] || { echo "run inside the marketplace git repo" >&2; exit 64; }
MKT="$ROOT/.claude-plugin/marketplace.json"
[ -f "$MKT" ] || { echo "missing .claude-plugin/marketplace.json" >&2; exit 1; }

python3 - "$ROOT" "$MKT" <<'PY'
import json, os, sys
root, mkt = sys.argv[1], sys.argv[2]
errs = []

try:
    with open(mkt) as f:
        data = json.load(f)
except Exception as e:
    print(f"marketplace.json is not valid JSON: {e}", file=sys.stderr); sys.exit(1)

for k in ("name", "owner", "plugins"):
    if k not in data:
        errs.append(f"marketplace.json missing top-level '{k}'")

for i, p in enumerate(data.get("plugins", [])):
    tag = p.get("name", f"#{i}")
    for k in ("name", "source", "description"):
        if not p.get(k):
            errs.append(f"plugin {tag}: missing '{k}'")
    src = p.get("source", "")
    if not src.startswith("./"):
        errs.append(f"plugin {tag}: source should be a relative './plugins/...' path")
        continue
    pdir = os.path.join(root, src[2:])
    pj = os.path.join(pdir, ".claude-plugin", "plugin.json")
    if not os.path.isdir(pdir):
        errs.append(f"plugin {tag}: source path does not exist: {src}")
        continue
    if not os.path.isfile(pj):
        errs.append(f"plugin {tag}: missing {src}/.claude-plugin/plugin.json")
        continue
    try:
        with open(pj) as f:
            man = json.load(f)
    except Exception as e:
        errs.append(f"plugin {tag}: plugin.json invalid JSON: {e}")
        continue
    if man.get("name") != p.get("name"):
        errs.append(f"plugin {tag}: plugin.json name '{man.get('name')}' != marketplace name '{p.get('name')}'")
    for k in ("description", "author"):
        if not man.get(k):
            errs.append(f"plugin {tag}: plugin.json missing required '{k}'")
    mv, ev = man.get("version"), p.get("version")
    if not mv:
        errs.append(f"plugin {tag}: plugin.json missing required 'version'")
    if not ev:
        errs.append(f"plugin {tag}: marketplace entry missing required 'version'")
    if mv and ev and mv != ev:
        errs.append(f"plugin {tag}: version mismatch plugin.json={mv} marketplace={ev}")

if errs:
    print("VALIDATION FAILED:", file=sys.stderr)
    for e in errs:
        print(f"  - {e}", file=sys.stderr)
    sys.exit(1)
print(f"OK: {len(data.get('plugins', []))} plugin(s) valid")
PY
