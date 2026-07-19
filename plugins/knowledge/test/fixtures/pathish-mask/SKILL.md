---
name: pathish-mask-fixture
description: Negative fixture — a literal alias path hidden by a token later in the path.
---

# Pathish mask fixture

The import paths below start with a literal alias prefix even though a token
appears later in the path — that must still be flagged. Only a path that
STARTS with a token is legal.

```ts
// {shared-lib}/seo/index.ts — this one is fine, starts with a token
import { useSeoMeta } from '@/shared/{entity}/seo'
import { useProductStore } from 'src/{entity}/store'
```

Filler text so the stub detector does not fire on this fixture instead of the one under
test. Prose outside code blocks is never scanned for paths, only fenced content is.
