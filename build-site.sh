#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
OUT="$ROOT/site/public/data.json"
mkdir -p "$(dirname "$OUT")"
python3 - "$ROOT" > "$OUT" <<'PY'
import json, os, sys
root = sys.argv[1]
mk = json.load(open(os.path.join(root, ".claude-plugin", "marketplace.json")))
mname = mk["name"]
# Repo slug for source links / the marketplace-add command (owner is the GitHub owner here).
owner = (mk.get("owner") or {}).get("name", "kolirt")
repo = f"{owner}/{mname}"
plugins = []
for e in mk.get("plugins", []):
    name = e["name"]; src = e["source"]
    pj = os.path.join(root, src[2:] if src.startswith("./") else src, ".claude-plugin", "plugin.json")
    man = json.load(open(pj))
    if not man.get("version"):
        sys.stderr.write(f"missing version for {name}\n"); sys.exit(1)
    if man.get("version") != e.get("version"):
        sys.stderr.write(f"version mismatch for {name}: plugin.json={man.get('version')} marketplace={e.get('version')}\n")
        sys.exit(1)
    plugins.append({
        "name": name,
        "version": man["version"],
        "description": e.get("description", man.get("description", "")),
        "install": f"/plugin install {name}@{mname}",
        "source": f"https://github.com/{repo}/tree/master/{src[2:] if src.startswith('./') else src}",
    })
data = {
    "marketplace": mname,
    "repo": repo,
    "add": f"/plugin marketplace add {repo}",
    "plugins": plugins,
}
print(json.dumps(data, indent=2))
PY
echo "wrote site/public/data.json"
