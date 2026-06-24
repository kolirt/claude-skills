---
description: Pair-style manager that consults a panel of external verifier agents (any-blocks review).
---

# /agent-companion

Argument: `$ARGUMENTS` (expected `on`, `off`, or `verifiers …`).

If the argument starts with `verifiers` (manage the agent panel):
- Run and show the output of:
  ```bash
  bash "${CLAUDE_PLUGIN_ROOT}/verifiers.sh" <rest-of-arguments>
  ```
  e.g. `/agent-companion verifiers` (list), `/agent-companion verifiers add grok-build`,
  `/agent-companion verifiers remove claude`. This edits the persistent panel config in
  `${CLAUDE_PLUGIN_DATA}` for you — no need to find plugin paths by hand. `add` requires a
  matching `adapters/<name>.sh` to already exist (see the creating-plugins skill).

If `on` (or empty):
- Read `${CLAUDE_PLUGIN_ROOT}/MANAGER.md` and act STRICTLY as the MANAGER per it until `/agent-companion off`.
- At decision/review/audit points, run the panel dispatcher (do NOT change directory first):
  ```bash
  bash "${CLAUDE_PLUGIN_ROOT}/verify.sh" <mode> <effort> <request-file>
  ```
  Read its STDOUT (the combined per-verifier summary) and its exit code:
  `0` PASS/ADVICE/AUDIT_COMPLETE · `10` blocked: CHANGES_REQUESTED or verifier FAIL (see summary) · `64` no verifier available (graceful degrade).
- **Graceful degrade:** exit `64` means no verifier was reachable — continue as manager,
  tell the user CONSULT/REVIEW is unavailable and the step is proceeding without verification.
- Confirm: "agent-companion enabled — I am the manager."

If `off`:
- Stop acting under the protocol; confirm "agent-companion disabled."

Updates are handled by native `/plugin update` — there is no self-updater.
