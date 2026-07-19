---
name: indented-code-fixture
description: Negative fixture — code indented by more than four spaces, with no fenced block and no references/ etalon.
---

# Indented code fixture

This skill shows a code fragment indented by eight spaces instead of a fenced
block. The old exactly-four-spaces check missed this; the threshold-based
check must still catch it as code and fire the direction-style detector,
since there is no `references/` directory here.

        export function useThing() {
          const value = compute()
          return { value }
        }
        // more indented lines to clear the run threshold

Filler so the stub detector does not fire on this fixture instead of the one under test.
