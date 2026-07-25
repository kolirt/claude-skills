Rule 4 (module-boundaries) in a Vue codebase.

**Reaching into another module's internals versus using its declared exports.** Importing a file
from inside another feature's folder instead of that feature's public entry point is a dependency on
structure, not contract — the internal file can move or split with no warning.

- ✅ do: `import { useCart } from '@/features/cart'` — the feature's declared surface.
- ❌ don't: `import { normalizeCartLine } from '@/features/cart/internal/helpers'` — a caller now
  breaks whenever that internal file is refactored.

**Reaching through an object chain in a template.** `{{ order.customer.address.city }}` inside a
component that only owns `order` is the Law-of-Demeter violation this rule names generally, applied
to a template expression instead of a statement.

- ✅ do: expose `order.shippingCity` (a getter, a computed prop passed down, or a method on whatever
  owns `order`) and bind to that.
- ❌ don't: walk three levels into a foreign object's shape from a template, so every layer of that
  shape is now a dependency of this component.

**A composable whose surface is wider than any consumer needs.** A `useUser()` composable that
returns every internal ref, setter, and cache-invalidation function — when every current consumer
only reads `user` and calls `refresh()` — is a public-by-default surface, and the extra exports are
promises nobody asked for yet.

- ✅ do: return `{ user, refresh }` and add more only when a real consumer needs it.
- ❌ don't: `return { user, setUser, _cache, _lastFetchedAt, invalidate, refresh, reset }` for a single
  read-only consumer.

**Props/emits as the actual contract.** A child component mutating a prop object's nested field
directly, instead of emitting an event for the parent to act on, depends on the parent's internal
data shape rather than the declared `emits` contract — the same "depend on structure, not promise"
break, expressed through Vue's own props-down/events-up idiom.

- ✅ do: `emit('update:status', newStatus)` and let the parent own the mutation of its own state.
- ❌ don't: `props.order.status = 'closed'` inside the child, silently reaching past the declared
  contract into the parent's data.

**A router route reaching into a page's internal store.** A route guard or a sibling route importing
a page component's local composable state directly, instead of going through a shared, declared
module, depends on where that state happens to live rather than on a promise anyone made about it.
