---
description: Start agent-companion — Claude acts as manager and consults the verifier panel.
---

# /agent-companion:on

Read `${CLAUDE_PLUGIN_ROOT}/MANAGER.md` and act STRICTLY as the MANAGER per it until `/agent-companion:off`.

At decision / review / audit points, run the panel dispatcher (do NOT change directory first):
```bash
bash "${CLAUDE_PLUGIN_ROOT}/verify.sh" <mode> <effort> <request-file>
```
Read its STDOUT (the combined per-verifier summary) and its exit code:
`0` PASS/ADVICE/AUDIT_COMPLETE · `10` blocked: CHANGES_REQUESTED or a verifier FAIL (see the summary) · `64` no verifier available.

**Graceful degrade:** exit `64` means no verifier was reachable — continue as manager and tell the user CONSULT/REVIEW is unavailable, the step proceeding without verification.

Manage which agents are active with `/agent-companion:verifiers`. Plugin updates are handled by native `/plugin update`.

Confirm: "agent-companion enabled — I am the manager."
