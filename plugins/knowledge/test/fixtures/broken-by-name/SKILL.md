---
name: broken-by-name-fixture
description: Negative fixture — defers by name to skills that no longer exist.
---

# Broken by-name fixture

For placement rules defer to the `architecture-fsd` skill, and for server rendering
defer to the `ssr` skill. Both were retired, so the by-name detector must fire twice.

The `pages` skill exists in the registry passed by the self-test, so it must NOT fire —
that keeps the fixture honest about false positives.

Filler text so the stub detector does not fire on this fixture instead of the one under
test. By-name detection runs on prose only, never inside fenced code blocks.
