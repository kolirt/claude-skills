Rule 9 (security by default) in Vue.

**Authorisation enforced in the UI only while the endpoint stays open.** Hiding a delete button behind
`v-if="user.isAdmin"` controls what a legitimate user sees; it does nothing to a request sent directly
to the API. The check must exist server-side regardless of what the component renders.

```
❌ <button v-if="user.isAdmin" @click="deleteUser(id)">  // only client-side gate
✅ same v-if for UX, plus the server rejects the request if the caller lacks the role
```

**Secrets in client-exposed config or build-time env.** Any value bundled through `import.meta.env` (or
equivalent build-time injection) ships in the built JavaScript and is readable by anyone who opens the
bundle. An API secret, a signing key, or a service-role credential placed there is disclosed, not
protected — a prefix convention that marks a variable public-safe is the framework's mechanism, but
this rule requires nothing not meant for the client ever reaches that prefix.

**Rendering unsanitised HTML.** `v-html` renders whatever string it is given, including
attacker-supplied markup, as live HTML — the framework's default text interpolation escapes; `v-html`
deliberately opts out.

```
❌ <div v-html="comment.body"></div>  // comment.body came from another user
✅ <div>{{ comment.body }}</div>  // escaped by default, or sanitize before v-html
```

**A client-side route guard mistaken for an access control.** A navigation guard that redirects an
unauthenticated visitor away from a route improves UX and stops nothing: the guarded page's data still
comes from an API that must independently reject the same unauthenticated request.

```
❌ router.beforeEach((to) => { if (to.meta.admin && !user.isAdmin) return '/'; })  // UI-only gate
✅ same guard for UX, plus the endpoint behind the route rejects a non-admin caller independently
```

A guard is worth keeping for the redirect it gives a legitimate user; it is never the reason the
server-side check can be skipped.
