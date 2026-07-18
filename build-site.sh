#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
OUT="$ROOT/site/public/data.json"
mkdir -p "$(dirname "$OUT")"
python3 - "$ROOT" > "$OUT" <<'PY'
import json, os, re, sys
root = sys.argv[1]

def parse_frontmatter(path):
    """Minimal YAML-frontmatter reader: top-level `key: value` pairs where the
    value may spill onto following indented lines (folded/plain multi-line
    scalars). Returns a dict of str -> str with whitespace collapsed."""
    try:
        with open(path, encoding="utf-8") as fh:
            lines = fh.read().splitlines()
    except OSError:
        return {}
    if not lines or lines[0].strip() != "---":
        return {}
    body = []
    for line in lines[1:]:
        if line.strip() == "---":
            break
        body.append(line)
    fields, key = {}, None
    for line in body:
        m = re.match(r"^([A-Za-z0-9_-]+):\s*(.*)$", line)
        if m and not line[:1].isspace():
            key = m.group(1)
            fields[key] = [m.group(2)]
        elif key is not None and line.strip():
            fields[key].append(line.strip())
    out = {}
    for k, parts in fields.items():
        v = " ".join(p for p in parts if p)
        v = re.sub(r"\s+", " ", v).strip()
        if len(v) >= 2 and v[0] == v[-1] and v[0] in "\"'":
            v = v[1:-1].strip()
        out[k] = v
    return out

def collect_skills(plugin_dir):
    skills_dir = os.path.join(plugin_dir, "skills")
    if not os.path.isdir(skills_dir):
        return []
    skills = []
    for entry in sorted(os.listdir(skills_dir)):
        md = os.path.join(skills_dir, entry, "SKILL.md")
        if not os.path.isfile(md):
            continue
        fm = parse_frontmatter(md)
        skills.append({
            "name": fm.get("name") or entry,
            "description": fm.get("description", ""),
        })
    return sorted(skills, key=lambda s: s["name"])

mk = json.load(open(os.path.join(root, ".claude-plugin", "marketplace.json")))
mname = mk["name"]
# Repo slug for source links / the marketplace-add command (owner is the GitHub owner here).
owner = (mk.get("owner") or {}).get("name", "kolirt")
repo = f"{owner}/{mname}"
plugins = []
for e in mk.get("plugins", []):
    name = e["name"]; src = e["source"]
    rel = src[2:] if src.startswith("./") else src
    plugin_dir = os.path.join(root, rel)
    pj = os.path.join(plugin_dir, ".claude-plugin", "plugin.json")
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
        "source": f"https://github.com/{repo}/tree/master/{rel}",
        "skills": collect_skills(plugin_dir),
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
