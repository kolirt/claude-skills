#!/usr/bin/env python3
"""Stack detection for the `auditing` plugin: emit the snapshot as JSON.

Read-only. Walks the repository the audit was invoked in, records which SURFACES
exist per unit, and cites the marker that proved each one. It answers the only
questions the audit domains actually branch on — is there an interface, a server,
a data schema, an API contract — and never tries to catalogue frameworks for
their own sake.

Two facts are deliberately NOT detected here:

- which `knowledge-*` convention plugins are available: that is session state, not
  a file on disk, so the agent adds it to the snapshot itself;
- whether the project is publicly indexable, internal, or unreleased: that is
  intent, and the dispatcher asks.

Usage:  python3 detect-stack.py [ROOT]        # ROOT defaults to the cwd
        python3 detect-stack.py --self-test

Exit status is 0 whenever the walk completed, including when every surface is
absent — "nothing detected" is a valid snapshot, not an error.
"""
import json
import os
import re
import sys

SKIP_DIRS = {
    ".git", "node_modules", "vendor", "dist", "build", ".next", ".nuxt",
    ".output", "coverage", "__pycache__", ".venv", "venv", ".idea", ".vscode",
}
MANIFESTS = ("package.json", "composer.json")

FSD_LAYER = re.compile(r"^\d{1,2}-[a-z]")
OPENAPI_FILE = re.compile(r"^(openapi|swagger)[\w.-]*\.(json|ya?ml)$", re.I)
SQL_FILE = re.compile(r"\.sql$", re.I)
MD_FILE = re.compile(r"\.md$", re.I)

# Prose a project writes about ITSELF — what a new contributor or an agent is
# expected to read before writing code. `README.md` is deliberately NOT here:
# nearly every repository has one, so accepting it would make this fact true
# everywhere and worthless as a verdict input. A README still belongs to the
# evidence an audit reads — this fact decides applicability, not scope.
CONVENTION_FILES = ("AGENTS.md", "CLAUDE.md", "CONTRIBUTING.md", "CONVENTIONS.md")
ADR_DIRS = ("adr", "adrs", "decisions")
DOC_DIRS = ("docs", "doc")

UI_DEPS = ("vue", "nuxt")
I18N_DEPS = ("vue-i18n", "@nuxtjs/i18n")
TEST_DEPS = ("vitest", "jest", "@playwright/test", "playwright", "cypress",
             "@vue/test-utils", "phpunit/phpunit", "pestphp/pest")
# Script names are matched by the `test` PREFIX rather than against a fixed list,
# so `test`, `test:unit`, `test:integration` and any other `test*` all count.
TEST_SCRIPT_PREFIX = "test"


def _read_json(path):
    try:
        with open(path, encoding="utf-8") as fh:
            data = json.load(fh)
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError):
        return {}


def _deps(manifest, keys):
    """The declared dependency names under the given manifest keys."""
    out = set()
    for key in keys:
        block = manifest.get(key)
        if isinstance(block, dict):
            out |= set(block)
    return out


# A RUNTIME dependency is evidence that the project *is* the thing; anything else
# is evidence that it merely *works with* it. A package declaring
# `laravel/framework` under `require-dev` to run its own tests is not a Laravel
# application and has no server surface, and a component library declaring `vue`
# as a PEER dependency is not a Vue application either — it is a thing you use
# inside one. So framework identity and the surfaces derived from it read runtime
# keys only. In npm the runtime/dev split does not carry the PHP meaning —
# `nuxt` is conventionally a devDependency of the app it builds — so both of those
# keys count there, and `peerDependencies` does not.
JS_RUNTIME_KEYS = ("dependencies", "devDependencies")
PHP_RUNTIME_KEYS = ("require",)
ALL_KEYS = JS_RUNTIME_KEYS + PHP_RUNTIME_KEYS + ("peerDependencies", "require-dev")


def _walk(root):
    """Relative paths of files and directories under root, skipping SKIP_DIRS."""
    files, dirs = [], []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = sorted(d for d in dirnames if d not in SKIP_DIRS)
        rel = os.path.relpath(dirpath, root)
        rel = "" if rel == "." else rel
        for d in dirnames:
            dirs.append(os.path.join(rel, d) if rel else d)
        # Sorted so that where several files could serve as the marker for one
        # surface, the cited one is the same on every run and every filesystem —
        # readdir order is not stable, and a snapshot that cites a different file
        # each run is not the deterministic artifact this script promises.
        for f in sorted(filenames):
            files.append(os.path.join(rel, f) if rel else f)
    return files, dirs


def _first(paths, predicate):
    for p in paths:
        if predicate(p):
            return p
    return None


def _fact(marker):
    """A fact is present only when a marker can be cited for it."""
    return {"present": marker is not None, "marker": marker}


def _unit_paths(files, dirs, unit):
    """The files and dirs belonging to a unit, as unit-relative paths.

    A nested unit's own tree is excluded from its parent, so a monorepo root
    does not inherit its packages' surfaces and report them as its own.
    """
    if unit == ".":
        prefix = ""
    else:
        prefix = unit.rstrip("/") + "/"
    take = lambda paths: [p[len(prefix):] for p in paths if p.startswith(prefix)]
    return take(files), take(dirs)


def find_units(files, dirs):
    """Every directory holding its own manifest, plus the root.

    The root is always a unit even with no manifest: a repository can be a
    documentation or configuration tree with real surfaces and no package file.

    There is deliberately NO depth limit. A cap would drop a deeply nested
    package from the snapshot entirely AND leave its files counted as its
    ancestor's, so one arbitrary number would produce both a false negative and a
    false positive. The walk already skips vendored and build directories, which
    is what a depth cap was really guarding against.
    """
    fileset = set(files)
    units = ["."]
    for d in dirs:
        if any(os.path.join(d, m) in fileset for m in MANIFESTS):
            units.append(d)
    return units


def detect_unit(root, unit, files, dirs):
    ufiles, udirs = _unit_paths(files, dirs, unit)
    fileset, dirset = set(ufiles), set(udirs)
    nested = [u for u in find_units(ufiles, udirs) if u != "."]

    def owned(rel):
        """A path inside this unit but not inside a nested unit.

        The nested unit's own directory entry is excluded too, not just its
        contents: otherwise a package directory that happens to be called `lang`,
        `locales` or `src` would set its PARENT's `i18n` or `architecture` fact.
        """
        return not any(rel == n or rel.startswith(n + os.sep) for n in nested)

    ufiles = [p for p in ufiles if owned(p)]
    udirs = [p for p in udirs if owned(p)]
    fileset, dirset = set(ufiles), set(udirs)

    def cite(rel):
        return rel if unit == "." else f"{unit}/{rel}"

    # Dependency facts come from THIS unit's own root manifest only — a nested
    # package's dependencies are its own unit's business, and a parent never
    # inherits them.
    pkg = _read_json(os.path.join(root, unit, "package.json")) if "package.json" in fileset else {}
    comp = _read_json(os.path.join(root, unit, "composer.json")) if "composer.json" in fileset else {}
    runtime = _deps(pkg, JS_RUNTIME_KEYS) | _deps(comp, PHP_RUNTIME_KEYS)
    declared = _deps(pkg, ALL_KEYS) | _deps(comp, ALL_KEYS)
    scripts = {}
    for manifest in (pkg, comp):
        block = manifest.get("scripts")
        if isinstance(block, dict):
            scripts.update(block)

    # --- framework identity: the manifest answers this on its own ------------
    # A config file (`nuxt.config.*`, `vite.config.*`, `artisan`) adds nothing a
    # declared dependency does not already prove, so no config file is a marker
    # here — not even as a fallback, which would contradict the documented rule
    # for a shape (a Nuxt app with no `package.json`) that cannot exist.
    laravel = "laravel/framework" in runtime

    framework = []
    if "nuxt" in runtime:
        framework.append({"name": "nuxt", "marker": f"`nuxt` in {cite('package.json')}"})
    elif "vue" in runtime:
        vite = "`vite`" if "vite" in runtime else None
        framework.append({"name": "vue-vite",
                          "marker": f"`vue`{' + ' + vite if vite else ''} in {cite('package.json')}"})
    if laravel:
        framework.append({"name": "laravel",
                          "marker": f"`laravel/framework` in {cite('composer.json')}"})

    # --- architecture --------------------------------------------------------
    src_children = [d.split(os.sep)[1] for d in udirs
                    if d.startswith("src" + os.sep) and d.count(os.sep) == 1]
    if any(FSD_LAYER.match(c) for c in src_children):
        layers = sorted(c for c in src_children if FSD_LAYER.match(c))
        architecture = {"name": "fsd", "marker": f"numbered layer dirs under {cite('src')}/: "
                                                 + ", ".join(layers[:3])}
    elif "src" in dirset:
        architecture = {"name": "flat", "marker": f"{cite('src')}/ without numbered layer dirs"}
    else:
        architecture = {"name": None, "marker": None}

    # --- surfaces ------------------------------------------------------------
    # A declared UI dependency settles this; the file probes below exist for the
    # cases a manifest CANNOT express — Blade ships inside `laravel/framework`
    # with no dependency of its own, and a hand-written page may have no manifest.
    blade = _first(ufiles, lambda p: p.endswith(".blade.php"))
    index_html = "index.html" if "index.html" in fileset else None
    ui_marker = None
    if any(d in runtime for d in UI_DEPS):
        ui_marker = f"`{next(d for d in UI_DEPS if d in runtime)}` in {cite('package.json')}"
    elif blade:
        ui_marker = f"{cite(blade)} (Blade ships inside the framework, not as a dependency)"
    elif index_html:
        ui_marker = cite(index_html)

    routes_php = _first(ufiles, lambda p: p.startswith("routes" + os.sep) and p.endswith(".php"))
    server_entry = _first(ufiles, lambda p: p.startswith("server" + os.sep)
                          and p.rsplit(".", 1)[-1] in ("ts", "js", "mjs"))
    server_marker = None
    if laravel:
        server_marker = f"`laravel/framework` in {cite('composer.json')}"
    elif "nuxt" in runtime:
        server_marker = f"`nuxt` in {cite('package.json')} (server-capable runtime)"
    elif routes_php:
        server_marker = cite(routes_php)
    elif server_entry:
        server_marker = cite(server_entry)

    # Matched on whole path COMPONENTS, never on a substring: `not_migrations/x.sql`
    # and `database/migrations_backup/x.php` are not schemas, and a substring test
    # accepts both.
    def _parts(rel):
        return rel.split(os.sep)

    php_migration = _first(ufiles, lambda p: _parts(p)[:2] == ["database", "migrations"]
                           and p.endswith(".php"))
    sql_migration = _first(ufiles, lambda p: SQL_FILE.search(p)
                           and "migrations" in _parts(p)[:-1])
    models_dir = os.path.join("app", "Models") in dirset
    schema_marker = None
    if php_migration:
        schema_marker = cite(php_migration) + (f" + {cite(os.path.join('app', 'Models'))}/"
                                               if models_dir else "")
    elif sql_migration:
        schema_marker = cite(sql_migration)

    openapi = _first(ufiles, lambda p: OPENAPI_FILE.match(os.path.basename(p)))
    api_marker = cite(openapi) if openapi else None

    lang_dir = _first(udirs, lambda d: d in ("lang", "locales")
                      or d.endswith(os.sep + "lang") or d.endswith(os.sep + "locales"))
    i18n_marker = None
    if any(d in runtime for d in I18N_DEPS):
        i18n_marker = f"`{next(d for d in I18N_DEPS if d in runtime)}` in {cite('package.json')}"
    elif lang_dir:
        i18n_marker = cite(lang_dir) + "/"

    # A dedicated convention document, an ADR tree, or a documentation tree is
    # what makes "did the project follow its own written rules" an answerable
    # question at all. Matched on whole path COMPONENTS like the schema probe, so
    # `documentation_backup/x.md` and a file merely NAMED `adr-notes` are not it.
    conv_file = _first(ufiles, lambda p: os.path.basename(p) in CONVENTION_FILES)
    adr_dir = _first(udirs, lambda d: _parts(d)[-1].lower() in ADR_DIRS)
    docs_md = _first(ufiles, lambda p: _parts(p)[0] in DOC_DIRS and MD_FILE.search(p))
    conventions_marker = None
    if conv_file:
        conventions_marker = cite(conv_file)
    elif adr_dir:
        conventions_marker = cite(adr_dir) + "/"
    elif docs_md:
        conventions_marker = cite(docs_md)

    # A test runner is legitimately a development-only dependency, so this one
    # surface reads every declared key. Script names are matched by PREFIX:
    # `test`, `test:unit`, `test:integration` and any other `test*` all count, in
    # either manifest.
    test_dep = next((d for d in TEST_DEPS if d in declared), None)
    test_script = next((s for s in sorted(scripts) if s.startswith(TEST_SCRIPT_PREFIX)), None)
    if test_dep:
        in_pkg = test_dep in _deps(pkg, ALL_KEYS)
        test_marker = (f"`{test_dep}` declared in "
                       f"{cite('package.json' if in_pkg else 'composer.json')}")
    elif test_script:
        test_marker = f"`{test_script}` script in a manifest of {cite('.') if unit == '.' else unit}"
    else:
        test_marker = None

    return {
        "path": unit,
        "manifests": [m for m in MANIFESTS if m in fileset],
        "framework": framework,
        "architecture": architecture,
        "surfaces": {
            "ui": _fact(ui_marker),
            "server": _fact(server_marker),
            "data_schema": _fact(schema_marker),
            "api_contract": _fact(api_marker),
            "i18n": _fact(i18n_marker),
            "test_harness": _fact(test_marker),
            "convention_docs": _fact(conventions_marker),
        },
    }


def detect(root):
    root = os.path.abspath(root)
    files, dirs = _walk(root)
    units = find_units(files, dirs)
    return {
        "schema": 1,
        "root": root,
        "skipped_dirs": sorted(SKIP_DIRS),
        "units": [detect_unit(root, u, files, dirs) for u in units],
        "agent_supplied": [
            "convention_plugins: which knowledge-* skills are available this session",
            "indexability: whether the project is public, internal, or unreleased",
        ],
    }


# ---------------------------------------------------------------- self-test

def _self_test():
    import tempfile
    import pathlib

    def build(spec):
        tmp = tempfile.mkdtemp()
        for rel, content in spec.items():
            p = pathlib.Path(tmp, rel)
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text(content)
        return tmp

    def snap(spec):
        return detect(build(spec))

    ok = 0

    def check(label, cond):
        nonlocal ok
        if not cond:
            print(f"FAIL: {label}", file=sys.stderr)
            sys.exit(1)
        ok += 1
        print(f"ok: {label}")

    # an empty tree detects nothing and still returns one unit
    s = snap({"README.md": "# x"})
    u = s["units"][0]
    check("empty tree: one unit, no surfaces",
          len(s["units"]) == 1 and not any(f["present"] for f in u["surfaces"].values()))

    # a vue+vite app: ui present with a cited marker, no server, no schema
    s = snap({
        "package.json": json.dumps({"dependencies": {"vue": "^3.5.0"}}),
        "vite.config.ts": "export default {}",
        "src/main.ts": "",
    })
    u = s["units"][0]
    check("vue+vite: ui present with marker", u["surfaces"]["ui"]["present"]
          and "vue" in u["surfaces"]["ui"]["marker"])
    check("vue+vite: framework vue-vite", [f["name"] for f in u["framework"]] == ["vue-vite"])
    check("vue+vite: no server surface", not u["surfaces"]["server"]["present"])
    check("vue+vite: flat architecture", u["architecture"]["name"] == "flat")

    # FSD numbered layers win over flat
    s = snap({"package.json": "{}", "src/01-app/x.ts": "", "src/02-processes/y.ts": ""})
    check("fsd: numbered layers detected", s["units"][0]["architecture"]["name"] == "fsd")

    # laravel: server + schema, both cited
    s = snap({
        "artisan": "#!/usr/bin/env php",
        "composer.json": json.dumps({"require": {"laravel/framework": "^11.0"}}),
        "database/migrations/2024_01_01_create_users.php": "<?php",
        "app/Models/User.php": "<?php",
        "routes/web.php": "<?php",
    })
    u = s["units"][0]
    check("laravel: server present", u["surfaces"]["server"]["present"])
    check("laravel: data_schema present", u["surfaces"]["data_schema"]["present"]
          and "migrations" in u["surfaces"]["data_schema"]["marker"])
    check("laravel: framework laravel", [f["name"] for f in u["framework"]] == ["laravel"])

    # api contract by openapi file
    s = snap({"package.json": "{}", "openapi.yaml": "openapi: 3.1.0"})
    check("openapi: api_contract present",
          s["units"][0]["surfaces"]["api_contract"]["present"])

    # monorepo: a nested manifest becomes its own unit and the root does not
    # inherit its surfaces
    s = snap({
        "package.json": json.dumps({"private": True}),
        "site/package.json": json.dumps({"dependencies": {"vue": "^3.5.0"}}),
        "site/vite.config.ts": "export default {}",
    })
    paths = [u["path"] for u in s["units"]]
    root_u = next(u for u in s["units"] if u["path"] == ".")
    site_u = next(u for u in s["units"] if u["path"] == "site")
    check("monorepo: both units found", paths == [".", "site"])
    check("monorepo: nested ui not inherited by root",
          site_u["surfaces"]["ui"]["present"] and not root_u["surfaces"]["ui"]["present"])
    check("monorepo: marker is repo-relative",
          site_u["surfaces"]["ui"]["marker"].startswith("`vue` in site/package.json"))

    # skipped dirs are not walked: a vendored manifest is not a unit
    s = snap({"package.json": "{}", "node_modules/foo/package.json": "{}"})
    check("skip dirs: vendored manifest ignored",
          [u["path"] for u in s["units"]] == ["."])

    # test harness by script and by dependency
    s = snap({"package.json": json.dumps({"scripts": {"test": "vitest"}})})
    check("test harness: script detected",
          s["units"][0]["surfaces"]["test_harness"]["present"])

    # --- convention documents ------------------------------------------------
    # A README is not a convention document: this check fails the moment
    # `README.md` is added to CONVENTION_FILES, which would set the fact for
    # nearly every repository on earth and make the dispatcher's verdict useless.
    s = snap({"README.md": "# x", "package.json": "{}"})
    check("conventions: a README alone is not a convention document",
          not s["units"][0]["surfaces"]["convention_docs"]["present"])

    s = snap({"CLAUDE.md": "Never commit without asking."})
    check("conventions: a named convention file is cited",
          s["units"][0]["surfaces"]["convention_docs"]["marker"] == "CLAUDE.md")

    s = snap({"package.json": "{}", "docs/architecture.md": "# how this is built"})
    check("conventions: a documentation tree counts",
          s["units"][0]["surfaces"]["convention_docs"]["present"])

    s = snap({"package.json": "{}", "docs/adr/0001-use-postgres.md": "# 1. Use Postgres"})
    check("conventions: an ADR tree counts",
          s["units"][0]["surfaces"]["convention_docs"]["present"])

    # path components again: a directory merely NAMED like a doc tree is not one
    s = snap({"package.json": "{}", "documentation_backup/notes.md": "# old"})
    check("conventions: `documentation_backup/` is not a documentation tree",
          not s["units"][0]["surfaces"]["convention_docs"]["present"])

    # a nested unit's convention file belongs to that unit, not to its parent
    s = snap({"package.json": "{}", "site/package.json": "{}", "site/CLAUDE.md": "rules"})
    root_u = next(u for u in s["units"] if u["path"] == ".")
    site_u = next(u for u in s["units"] if u["path"] == "site")
    check("conventions: a nested unit's convention file does not set the parent's fact",
          site_u["surfaces"]["convention_docs"]["present"]
          and not root_u["surfaces"]["convention_docs"]["present"])

    # --- the four facts a manifest alone cannot answer ----------------------
    # Each of these projects has a manifest that would mislead a manifest-only
    # reader, which is why the file probes exist at all.

    # 1. a Laravel app with no migrations yet: the framework is declared at
    #    runtime, and the manifest still says nothing about a schema
    s = snap({"composer.json": json.dumps({"require": {"laravel/framework": "^11.0"}}),
              "app/Service.php": "<?php"})
    u = s["units"][0]
    check("laravel app: framework declared but data_schema absent",
          [f["name"] for f in u["framework"]] == ["laravel"]
          and not u["surfaces"]["data_schema"]["present"])

    # 2. Blade-only app: no UI dependency exists to declare
    s = snap({"artisan": "#!/usr/bin/env php",
              "composer.json": json.dumps({"require": {"laravel/framework": "^11.0"}}),
              "resources/views/home.blade.php": "<x-layout/>"})
    u = s["units"][0]
    check("blade-only: ui present with no ui dependency",
          u["surfaces"]["ui"]["present"] and "blade" in u["surfaces"]["ui"]["marker"])

    # 3. an API contract is a file, never a dependency
    s = snap({"composer.json": json.dumps({"require": {"laravel/framework": "^11.0"}}),
              "docs/openapi.yml": "openapi: 3.1.0"})
    check("api contract: found outside any manifest",
          s["units"][0]["surfaces"]["api_contract"]["present"])

    # 4. architecture is directory shape, never a manifest field
    s = snap({"package.json": json.dumps({"dependencies": {"vue": "^3.5.0"}}),
              "src/01-app/main.ts": ""})
    check("architecture: fsd from directory shape only",
          s["units"][0]["architecture"]["name"] == "fsd")

    # manifest-first: no config file present, identity still resolved
    s = snap({"package.json": json.dumps({"devDependencies": {"nuxt": "^3.0.0"}})})
    u = s["units"][0]
    check("manifest-first: nuxt as a devDependency still resolves",
          [f["name"] for f in u["framework"]] == ["nuxt"]
          and u["surfaces"]["server"]["present"] and u["surfaces"]["ui"]["present"])

    # --- regressions ---------------------------------------------------------

    # a deeply nested package is a unit in its own right, and its files do not
    # count as its ancestor's
    s = snap({"package.json": "{}",
              "a/b/c/d/package.json": json.dumps({"dependencies": {"vue": "^3.5.0"}}),
              "a/b/c/d/index.html": "<div id=app></div>"})
    paths = [u["path"] for u in s["units"]]
    root_u = next(u for u in s["units"] if u["path"] == ".")
    deep = next((u for u in s["units"] if u["path"].endswith("d")), None)
    check("depth: a deeply nested manifest is its own unit",
          deep is not None and deep["surfaces"]["ui"]["present"])
    check("depth: the deep unit's files do not leak into the root",
          not root_u["surfaces"]["ui"]["present"])

    # a nested unit's own directory name must not set a parent fact
    s = snap({"package.json": "{}", "lang/package.json": "{}"})
    root_u = next(u for u in s["units"] if u["path"] == ".")
    check("nesting: a package called `lang` does not set the parent's i18n",
          not root_u["surfaces"]["i18n"]["present"])

    # a package that only TESTS against Laravel is not a Laravel application
    s = snap({"composer.json": json.dumps({"require-dev": {"laravel/framework": "^11.0"}}),
              "src/Service.php": "<?php"})
    u = s["units"][0]
    check("dev-only dependency: no framework identity",
          [f["name"] for f in u["framework"]] == [])
    check("dev-only dependency: no server surface",
          not u["surfaces"]["server"]["present"])

    # migration matching is by path component, not substring
    s = snap({"not_migrations/x.sql": "select 1"})
    check("path components: `not_migrations/` is not a schema",
          not s["units"][0]["surfaces"]["data_schema"]["present"])
    s = snap({"database/migrations_backup/x.php": "<?php"})
    check("path components: `migrations_backup/` is not a schema",
          not s["units"][0]["surfaces"]["data_schema"]["present"])
    s = snap({"db/migrations/0001_init.sql": "create table t (id int)"})
    check("path components: a real sql migrations dir IS a schema",
          s["units"][0]["surfaces"]["data_schema"]["present"])

    # composer scripts and suffixed test scripts both count
    s = snap({"composer.json": json.dumps({"scripts": {"test:integration": "phpunit"}})})
    check("test harness: a suffixed script in composer.json counts",
          s["units"][0]["surfaces"]["test_harness"]["present"])

    # a malformed manifest degrades to "no declared dependencies", never a crash
    s = snap({"package.json": "{not json at all"})
    check("robustness: a malformed manifest does not crash the walk",
          s["units"][0]["manifests"] == ["package.json"]
          and not s["units"][0]["surfaces"]["ui"]["present"])

    # a config file is NOT a marker: no manifest means no framework identity, and
    # this check fails the moment a config-file fallback is reintroduced
    s = snap({"nuxt.config.ts": "export default {}",
              "vite.config.ts": "export default {}",
              "artisan": "#!/usr/bin/env php"})
    u = s["units"][0]
    check("config files alone: no framework identity",
          u["framework"] == [] and not u["surfaces"]["server"]["present"])

    # a component library declares its framework as a PEER dependency: it works
    # with the framework, it is not an application built on it
    s = snap({"package.json": json.dumps({"peerDependencies": {"vue": "^3.5.0"}}),
              "src/index.ts": ""})
    u = s["units"][0]
    check("peer dependency: no framework identity and no ui surface",
          u["framework"] == [] and not u["surfaces"]["ui"]["present"])

    # i18n reads RUNTIME keys only, like every dependency-backed fact except
    # test_harness. Reverting it to the all-keys set makes the first check fail.
    s = snap({"package.json": json.dumps({"peerDependencies": {"vue-i18n": "^9.0.0"}})})
    check("i18n: a peer-only i18n package is not an i18n surface",
          not s["units"][0]["surfaces"]["i18n"]["present"])
    s = snap({"package.json": json.dumps({"dependencies": {"vue-i18n": "^9.0.0"}})})
    check("i18n: a runtime i18n package IS an i18n surface",
          s["units"][0]["surfaces"]["i18n"]["present"])

    # test_harness is the one exception that reads every declared key, including
    # the non-runtime ones — reverting THAT to runtime-only fails here
    s = snap({"package.json": json.dumps({"devDependencies": {"vitest": "^2.0.0"}}),
              "composer.json": json.dumps({"require-dev": {"phpunit/phpunit": "^11.0"}})})
    check("test_harness: a dev-only runner still counts",
          s["units"][0]["surfaces"]["test_harness"]["present"])

    # determinism, pinned to the actual mechanism: with several files eligible as
    # one surface's marker, the FIRST in sorted order is the cited one — sorted
    # across directories as well as within one. This fails if either the filename
    # sort or the directory sort is removed, which a same-tree-twice comparison
    # would not catch.
    s = snap({"artisan": "#!/usr/bin/env php",
              "composer.json": json.dumps({"require": {"laravel/framework": "^11.0"}}),
              "resources/views/z-last.blade.php": "",
              "resources/views/a-first.blade.php": ""})
    marker = s["units"][0]["surfaces"]["ui"]["marker"]
    check("determinism: within a directory the first filename is cited",
          "a-first.blade.php" in marker and "z-last" not in marker)
    s = snap({"artisan": "#!/usr/bin/env php",
              "composer.json": json.dumps({"require": {"laravel/framework": "^11.0"}}),
              "resources/views/zz/a.blade.php": "",
              "resources/views/aa/z.blade.php": ""})
    marker = s["units"][0]["surfaces"]["ui"]["marker"]
    check("determinism: across directories the first directory is cited",
          "aa/z.blade.php" in marker and "zz" not in marker)

    print(f"ok: {ok} check(s) passed")


def main(argv):
    if "--self-test" in argv:
        _self_test()
        return 0
    root = next((a for a in argv[1:] if not a.startswith("-")), ".")
    if not os.path.isdir(root):
        print(f"not a directory: {root}", file=sys.stderr)
        return 64
    json.dump(detect(root), sys.stdout, indent=2)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
