---
description: Stop agent-companion — leave manager mode.
---

# /agent-companion:off

First, record the deactivation intent so the hooks drop the persisted mode even if this slash
command never reaches `UserPromptSubmit`:
```bash
bash "${CLAUDE_PLUGIN_ROOT}/lib/state.sh" want-off
```

Stop acting under the agent-companion MANAGER protocol; work normally from here.

The activation marker is ordered and last-write-wins, so a `want-off` issued after a `want-on`
wins. Once the state is dropped, the hooks stop injecting protocol reminders for this session.

Confirm: "agent-companion disabled."
