---
name: hardcoded-path-fixture
description: Negative fixture — code block with literal alias paths instead of placement tokens.
---

# Hardcoded path fixture

The import paths below are literal instead of tokenised, so the hardcoded-path detector
must fire on each of them. The commented path is tokenised and must NOT fire.

```ts
// {shared-lib}/seo/index.ts — this one is fine
import { useSeoMeta } from '@/shared/lib/seo'
import { productSchema } from '~/shared/lib/seo/schemas/product'
import { useProductStore } from 'src/entities/product'
```

Filler text so the stub detector does not fire on this fixture instead of the one under
test. Prose outside code blocks is never scanned for paths, only fenced content is.
