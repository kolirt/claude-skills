#!/usr/bin/env bash
# Scaffold a new plugin and register it in the marketplace.
# Usage: new-plugin.sh <name> [description]
set -euo pipefail

NAME="${1:?usage: new-plugin.sh <name> [description]}"
DESC="${2:-TODO: describe ${NAME}}"

case "$NAME" in
  *[!a-z0-9-]*|'') echo "name must be lowercase letters, digits, hyphens" >&2; exit 64;;
esac

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$ROOT" ] || { echo "run inside the marketplace git repo" >&2; exit 64; }

PDIR="$ROOT/plugins/$NAME"

# Idempotent: scaffold only what's missing, then ALWAYS (re)register. This lets a
# rerun finish registration if a previous run created the dir but failed before
# updating marketplace.json.
if [ -f "$PDIR/.claude-plugin/plugin.json" ]; then
  echo "plugins/$NAME already scaffolded; skipping file creation, ensuring registration"
else
mkdir -p "$PDIR/.claude-plugin" "$PDIR/commands"

# Emit plugin.json and the command starter via python3 so DESC is safely
# escaped for JSON and YAML frontmatter (quotes/newlines never break the files).
python3 - "$PDIR" "$NAME" "$DESC" <<'PY'
import json, os, sys
pdir, name, desc = sys.argv[1], sys.argv[2], sys.argv[3]
with open(os.path.join(pdir, ".claude-plugin", "plugin.json"), "w") as f:
    json.dump({
        "name": name,
        "version": "0.1.0",
        "description": desc,
        "author": {"name": "kolirt"},
    }, f, indent=2)
    f.write("\n")
# YAML-safe description: single line, escaped via JSON string quoting.
yaml_desc = json.dumps(" ".join(desc.split()))
with open(os.path.join(pdir, "commands", f"{name}.md"), "w") as f:
    f.write(
        f"---\ndescription: {yaml_desc}\n---\n\n"
        f"# /{name}\n\n"
        "TODO: command body. To run a bundled script, reference ${CLAUDE_PLUGIN_ROOT};\n"
        "to persist state, use ${CLAUDE_PLUGIN_DATA}. See the creating-plugins skill.\n"
    )
PY
fi

MKT="$ROOT/.claude-plugin/marketplace.json"
mkdir -p "$ROOT/.claude-plugin"
if [ ! -f "$MKT" ]; then
  cat > "$MKT" <<JSON
{
  "name": "claude-skills",
  "owner": { "name": "kolirt" },
  "plugins": []
}
JSON
fi

# Register the plugin in marketplace.json (idempotent) using python3.
python3 - "$MKT" "$NAME" "$DESC" <<'PY'
import json, sys
path, name, desc = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path) as f:
    data = json.load(f)
plugins = data.setdefault("plugins", [])
if any(p.get("name") == name for p in plugins):
    print(f"already registered: {name}")
else:
    plugins.append({
        "name": name,
        "source": f"./plugins/{name}",
        "description": desc,
        "version": "0.1.0",
    })
    with open(path, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    print(f"registered {name} in marketplace.json")
PY

echo "created plugins/$NAME (plugin.json, commands/$NAME.md)"
echo "next: edit plugin.json, write commands/$NAME.md, then scripts/validate.sh"
