# Fixtures

Inputs for `validate.py --self-test`. None of this is a real skill and none of it is
ever loaded by any plugin — `validate.py` only scans `plugins/knowledge*/`, and this
directory sits outside that glob.

Run them with:

    python3 plugins/knowledge/test/validate.py --self-test

## What a subdirectory holds

Most subdirectories hold one deliberately broken example that a single detector must
catch. But two shapes recur across the suite and are not "one broken example":

- **Paired helper files.** A few detectors are inherently about TWO etalons at once
  (duplicate ownership, a corpus-wide import). For those, the fixture directory holds
  both files, but only the one actually exercising the assertion gets a row in
  `SELF_TEST` — its sibling exists purely to be read as "the other etalon" and is never
  itself asserted against. Examples: `duplicate-file-owner/owner-a.md` (asserted) +
  `owner-b.md` (helper); `near-miss-token-import/importer.md` (asserted) + `shipper.md`
  (helper).
- **Positive guards.** Some fixtures are deliberately LEGITIMATE input that a detector
  must NOT flag — the regression they guard against is a false positive, not a missed
  true one. These are marked in `SELF_TEST` with the sentinel expected-code
  `"no-false-positive"` instead of a real detector code, and the lambda inverts the
  usual assertion: it collects only that one detector's hits and turns "found none" into
  a synthetic `("ok", "no-false-positive", "clean")` row so the normal "expected code
  present" check still applies. `self_test()` reports these separately from real
  negative cases in its final summary line, since "caught its violation" does not
  describe a fixture whose whole point is catching nothing.

Adding a detector, or a new bypass of an existing one, means adding a fixture here and a
row in `SELF_TEST`.

## Negative cases (each must be flagged)

| fixture | detector |
|---|---|
| `direction-style/SKILL.md` | code fragments in a code-plugin skill with no `references/` etalon |
| `etalon-contract/references/bad-etalon.md` | `references/*.md` violating the etalon contract |
| `long-body/SKILL.md` | SKILL.md body over the line limit |
| `hardcoded-path/SKILL.md` | literal `@/…` path inside a code block instead of a placement token |
| `broken-by-name/SKILL.md` | defers by name to a skill that does not exist |
| `stub/SKILL.md` | too short, with no skeleton marker |
| `empty-references/SKILL.md` | `references/` dir exists but holds no valid etalon — must not exempt |
| `pathish-mask/SKILL.md` | literal alias prefix with a token later in the path — must still be flagged |
| `etalon-contract/references/dup-inventory.md` | duplicate entry in the `## Files` inventory |
| `etalon-contract/references/dup-marker.md` | duplicate `**File:**` marker for the same path |
| `etalon-contract/references/extra-block.md` | more than one fenced block after a single marker |
| `etalon-contract/references/unclosed-fence.md` | a fenced block opened but never closed |
| `etalon-contract/references/orphan-snippet.md` | a fenced block with no `**File:**` marker before it |
| `indented-code/SKILL.md` | code indented by more than four spaces, no fenced block (paired with `indented-code/references/etalon.md`, a valid etalon so the missing-etalon path can't mask the assertion) |
| `fake-skeleton/SKILL.md` | skeleton marker on a long, finished skill — must not exempt |
| `prose-only-no-etalon/SKILL.md` | code skill with prose-only rules (no code fragments) and no `references/` at all — reference-first is unconditional |
| `etalon-contract/references/untokenised-path.md` | inventory entry / `**File:**` marker that is a literal path, not a `{token}` |
| `etalon-contract/references/unknown-token.md` | inventory entry / `**File:**` marker using a brace-shaped word that names no row in placement.md |
| `etalon-contract/references/malformed-token-separator.md` | a bucket token immediately followed by more letters with no `/` separator (`{app}evil/x.ts`) |
| `etalon-contract/references/file-valued-token-with-path.md` | the FILE-valued token `{pages-types}` with a path appended, instead of standing alone |
| `umbrella-loophole/SKILL.md` | plants the old `(umbrella)` heading marker without being on the `UMBRELLA_SKILLS` allow-list — must still be flagged |
| `unresolved-relative-import/missing-relative.md` | relative import with no matching `**File:**` entry anywhere |
| `unresolved-relative-import/cross-etalon-a.md` | relative import resolving to a file a DIFFERENT etalon ships — under the strict same-etalon reading this is a defect (should have been a token import), not resolved against the whole corpus |
| `unresolved-relative-import/side-effect-missing.md` | bare side-effect `import './x'` (no `from`, no bindings) with no matching shipped file |
| `duplicate-file-owner/owner-a.md` + `owner-b.md` | same token path shipped by two etalons with DIFFERENT content (divergent copies) |
| `duplicate-file-owner/variant-same-a.md` + `variant-same-b.md` | same token path shipped by two etalons declaring the SAME variant key and value — not a legitimate alternative, still a conflict |
| `duplicate-file-owner/invalid-variant.md` | `Variant:` header using an unrecognised key |
| `duplicate-file-owner/invalid-variant-value.md` | `Variant:` header using a recognised key with an unrecognised value |
| `near-miss-token-import/importer.md` + `shipper.md` | token import whose token+filename matches a shipped path at a DIFFERENT directory |
| `etalon-contract/references/nested-brace-token.md` | a second `{...}` group later in the path (`{app}/{not-a-token}/main.ts`) — `{...}` is reserved for the one leading token |
| `etalon-contract/references/wrong-heading-level.md` | `# Files` (or `### Files`) must NOT open the inventory section — only exactly `## Files` |
| `etalon-contract/references/uppercase-token.md` | `{APP}/x` — token case must match placement.md's vocabulary EXACTLY |
| `etalon-contract/references/underscore-token.md` | `{app_name}/x` — underscore is not part of the lowercase-kebab token grammar, and names no row in placement.md |
| `etalon-contract/references/empty-segment.md` | `{app}//x` — a doubled slash right after the token produces an empty path segment |
| `etalon-contract/references/trailing-slash.md` | `{app}/foo/` — a trailing slash leaves the last segment empty |
| `etalon-contract/references/empty-segment-mid.md` | `{app}/foo//bar.ts` — an empty segment in the middle of the path |
| `etalon-contract/references/files-heading-after-marker.md` | `## Files` heading appearing AFTER the first `**File:**` marker — the inventory must come first |
| `variant-header/duplicate-header-declaration.md` | two conflicting `Variant:` declarations in the header region — must not silently resolve to "the first one wins" |
| `missing-reference-pointer/SKILL.md` (+ `references/widget.md`, a valid but unrelated etalon) | a structurally valid `references/*.md` etalon exists, but no paragraph in SKILL.md ever names it in a "reproduce it" instruction — the second half of the reference-first contract |
| `orphan-etalon/SKILL.md` (+ `references/pointed.md`, `references/unpointed.md`) | `unpointed.md` sits in the same directory as a correctly-pointed-at sibling but is never named by SKILL.md — dead weight (warning, not error) |

## Positive guards (each must stay clean)

| fixture | what it guards |
|---|---|
| `unresolved-relative-import/token-import-ok.md` | a TOKEN import (`{shared-lib}/toast`) must never be flagged by `unresolved-relative-import`, even though the etalon ships nothing for it — checked twice, and also guards `near-miss-token-import` staying silent when no filename in its own namespace matches |
| `unresolved-relative-import/js-extension-ts-source.md` | a `./foo.js` specifier resolving to a shipped `foo.ts` source (NodeNext/ESM extension mapping) must not be flagged |
| `duplicate-file-owner/variant-complementary-a.md` + `variant-complementary-b.md` | two etalons sharing a path but declaring a COMPLEMENTARY variant pair (same key, different value) are alternatives, not a conflict |
| `etalon-contract/references/project-root-file.md` | `{project-root}/package.json` is a LEGITIMATE path — a root file living directly under `{project-root}` with no intermediate segment |
| `variant-header/buried-variant.md` | a `Variant:` line buried AFTER `## Files` is not a header declaration and must be ignored entirely, not parsed and flagged |
| `reference-pointer-variants/SKILL.md` (+ `references/thing.md`, `references/thing.ssr.md`) | a skill correctly pointing at BOTH of its own variant etalons in one "Read X (CSR) or Y (SSR) … reproduce" sentence must trip neither `check_reference_pointer` nor `check_orphan_etalon` |
