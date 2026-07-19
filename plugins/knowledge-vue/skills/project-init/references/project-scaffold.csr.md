# project-init (Vue) — CSR/SPA project scaffold etalon

Variant: projectType=csr

Scope: root config/scripts only, for a CSR/SPA project (`core/project-types/csr.md`). Bootstrap entry files/`createApp` are owned by `core/references/bootstrap-csr.md`; robots.txt conventions/policy by the `robots` skill. `vite.config.ts` is reproduced in full, not truncated. This is the SSR `project-scaffold.md` etalon with every SSR-only script/dependency/build step removed — nothing new invented; pick `project-scaffold.md` instead when `projectType` is SSR. FSD (`{app}` = `01-app`; non-FSD resolves via `core/architectures/<a>.md`).

## Files

- `{project-root}/package.json`
- `{project-root}/vite.config.ts`
- `{project-root}/tsconfig.json`
- `{project-root}/tsconfig.app.json`
- `{project-root}/tsconfig.node.json`
- `{app}/types/env.d.ts`
- `{project-root}/eslint.config.ts`
- `{project-root}/.env.development`
- `{project-root}/.env.production`
- `{project-root}/.gitignore`
- `{project-root}/.gitattributes`
- `{project-root}/.prettierignore`

**File:** `{project-root}/package.json`

```json
{
  "name": "<your-app-name>",
  "version": "0.0.0",
  "private": true,
  "type": "module",
  "scripts": {
    "build:dev": "run-s type-check lint build:dev:only",
    "build:prod": "run-s type-check lint build:prod:only",
    "build:dev:only": "vite build --mode development",
    "build:prod:only": "vite build --mode production",
    "dev": "vite",
    "format": "run-s format:packagejson format:organize-attributes format:sort-imports format:sort-re-exports format:tailwindcss",
    "format:organize-attributes": "prettier --write \"**/*.{ts,js,cjs,vue,json,prettierrc}\" --plugin=prettier-plugin-organize-attributes",
    "format:packagejson": "prettier --write \"**/*.{ts,js,cjs,vue,json,prettierrc}\" --plugin=prettier-plugin-packagejson",
    "format:sort-imports": "prettier --write \"**/*.{ts,js,cjs,vue,json,prettierrc}\" --plugin=@trivago/prettier-plugin-sort-imports",
    "format:sort-re-exports": "prettier --write \"**/*.{ts,js,cjs,vue,json,prettierrc}\" --plugin=prettier-plugin-sort-re-exports",
    "format:tailwindcss": "prettier --write \"**/*.{ts,js,cjs,vue,json,prettierrc}\" --plugin=prettier-plugin-tailwindcss",
    "lint": "eslint . --fix --cache --ignore-pattern html-template",
    "preview": "vite preview",
    "storybook:build": "storybook build -c storybook",
    "storybook:dev": "storybook dev -p 6006 -c storybook --no-open",
    "type-check": "vue-tsc --build"
  },
  "dependencies": {
    "@kolirt/vue-modal": "^2.3.0",
    "@kolirt/vue-validation-kit": "^1.0.6",
    "@lukemorales/query-key-factory": "^1.3.4",
    "@tailwindcss/vite": "^4.1.18",
    "@tanstack/query-broadcast-client-experimental": "^5.100.14",
    "@tanstack/vue-query": "^5.100.0",
    "@unhead/vue": "^3.1.0",
    "@vueuse/core": "^14.1.0",
    "class-variance-authority": "^0.7.1",
    "clsx": "^2.1.1",
    "laravel-echo": "^2.3.4",
    "localforage": "^1.10.0",
    "lucide-vue-next": "^0.561.0",
    "object-to-formdata": "^4.5.1",
    "pusher-js": "^8.5.0",
    "reka-ui": "^2.8.2",
    "tailwind-merge": "^3.4.0",
    "tailwindcss": "^4.1.18",
    "unhead": "^3.1.0",
    "vue": "^3.5.25",
    "vue-router": "^4.6.3",
    "vue-sonner": "^2.0.9"
  },
  "devDependencies": {
    "@chromatic-com/storybook": "^4.1.3",
    "@storybook/addon-a11y": "^10.1.10",
    "@storybook/addon-docs": "^10.1.10",
    "@storybook/addon-vitest": "^10.1.10",
    "@storybook/vue3-vite": "^10.1.10",
    "@tsconfig/node24": "^24.0.3",
    "@types/node": "^24.10.1",
    "@vitejs/plugin-vue": "^6.0.2",
    "@vitest/browser-playwright": "^4.0.16",
    "@vitest/coverage-v8": "^4.0.16",
    "@vue/eslint-config-prettier": "^10.2.0",
    "@vue/eslint-config-typescript": "^14.6.0",
    "@vue/tsconfig": "^0.8.1",
    "autoprefixer": "^10.4.22",
    "eslint": "^9.39.1",
    "eslint-plugin-storybook": "^10.1.10",
    "eslint-plugin-vue": "~10.5.1",
    "internal-ip": "^8.0.1",
    "jiti": "^2.6.1",
    "npm-run-all2": "^8.0.4",
    "playwright": "^1.57.0",
    "sass": "^1.96.0",
    "storybook": "^10.1.10",
    "tw-animate-css": "^1.4.0",
    "typescript": "~5.9.3",
    "vite": "^7.3.2",
    "vite-imagetools": "^9.0.2",
    "vite-plugin-image-optimizer": "^2.0.3",
    "vite-plugin-require": "^1.2.14",
    "vite-plugin-robots": "^1.0.5",
    "vite-svg-loader": "^5.1.0",
    "vitest": "^4.0.16",
    "vue-tsc": "^3.1.5"
  },
  "packageManager": "yarn@1.22.22",
  "engines": {
    "node": "=22.21.1"
  }
}
```

Removed vs. the SSR etalon: `express` dependency; `@types/express`/`tsx` devDependencies;
the `build:*:bundles`/`build:*:client`/`build:*:server`/`build:server-bootstrap`/`build-only:*`
script fan-out; `dev` runs `vite` directly instead of booting Express via `tsx`; `preview`
uses `vite preview` instead of a compiled Node server bootstrap.

**File:** `{project-root}/vite.config.ts`

```ts
import tailwindcss from '@tailwindcss/vite'
import vue from '@vitejs/plugin-vue'
import autoprefixer from 'autoprefixer'
import { URL, fileURLToPath } from 'node:url'
import { defineConfig } from 'vite'
import { imagetools } from 'vite-imagetools'
import { ViteImageOptimizer } from 'vite-plugin-image-optimizer'
import vitePluginRequire from 'vite-plugin-require'
import { robots } from 'vite-plugin-robots'
import svgLoader from 'vite-svg-loader'

export default defineConfig({
  plugins: [
    vue(),
    tailwindcss(),
    // @ts-expect-error
    vitePluginRequire.default(),
    ViteImageOptimizer(),
    imagetools(),
    svgLoader({
      svgo: false
    }),
    // Bare call — policy/file conventions owned by the `robots` skill.
    robots()
  ],
  server: {
    host: '0.0.0.0',
    port: 5177,
    allowedHosts: ['<your-local-domain>.test']
  },
  css: {
    postcss: {
      plugins: [autoprefixer()]
    }
  },
  resolve: {
    // Alias definition, not consumption — kept literal.
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url))
    }
  }
})
```

**File:** `{project-root}/tsconfig.json`

```json
{
  "files": [],
  "references": [
    {
      "path": "./tsconfig.node.json"
    },
    {
      "path": "./tsconfig.app.json"
    }
  ],
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@/*": ["./src/*"]
    }
  }
}
```

**File:** `{project-root}/tsconfig.app.json`

```json
{
  "extends": "@vue/tsconfig/tsconfig.dom.json",
  "include": ["{app}/types/env.d.ts", "src/**/*", "src/**/*.vue", "storybook/**/*"],
  "exclude": ["src/**/__tests__/*"],
  "compilerOptions": {
    "tsBuildInfoFile": "./node_modules/.tmp/tsconfig.app.tsbuildinfo",
    "baseUrl": ".",
    "paths": {
      "@/*": ["./src/*"]
    },
    "noEmit": true
  }
}
```

**File:** `{app}/types/env.d.ts`

```ts
/// <reference types="vite/client" />
```

**File:** `{project-root}/tsconfig.node.json`

```json
{
  "extends": "@tsconfig/node24/tsconfig.json",
  "include": [
    "vite.config.*",
    "vitest.config.*",
    "cypress.config.*",
    "nightwatch.conf.*",
    "playwright.config.*",
    "eslint.config.*"
  ],
  "compilerOptions": {
    "noEmit": true,
    "tsBuildInfoFile": "./node_modules/.tmp/tsconfig.node.tsbuildinfo",

    "module": "ESNext",
    "moduleResolution": "Bundler",
    "types": ["node"]
  }
}
```

**File:** `{project-root}/eslint.config.ts`

```ts
import skipFormatting from '@vue/eslint-config-prettier/skip-formatting'
import { defineConfigWithVueTs, vueTsConfigs } from '@vue/eslint-config-typescript'
import pluginVue from 'eslint-plugin-vue'
import { globalIgnores } from 'eslint/config'

export default defineConfigWithVueTs(
  {
    name: 'app/files-to-lint',
    files: ['**/*.{vue,ts,mts,tsx}']
  },
  globalIgnores(['**/dist/**', '**/coverage/**']),
  ...pluginVue.configs['flat/essential'],
  vueTsConfigs.recommended,
  skipFormatting
)
```

**File:** `{project-root}/.env.development`

```text
VITE_API_URL=<API_BASE>
VITE_APP_ORIGIN=<APP_ORIGIN>

VITE_REVERB_APP_KEY=<REVERB_APP_KEY>
VITE_REVERB_HOST=<REVERB_HOST>
VITE_REVERB_PORT=443
VITE_REVERB_SCHEME=https
VITE_REVERB_WS_PATH=/ws
VITE_REVERB_AUTH_PATH=/r/broadcasting/auth

VITE_OAUTH_CLIENT_ID=<OAUTH_CLIENT_ID>
```

**File:** `{project-root}/.env.production`

```text
VITE_API_URL=<API_BASE>
VITE_APP_ORIGIN=<APP_ORIGIN>

VITE_REVERB_APP_KEY=<REVERB_APP_KEY>
VITE_REVERB_HOST=<REVERB_HOST>
VITE_REVERB_PORT=443
VITE_REVERB_SCHEME=https
VITE_REVERB_WS_PATH=/ws
VITE_REVERB_AUTH_PATH=/r/broadcasting/auth

VITE_OAUTH_CLIENT_ID=<OAUTH_CLIENT_ID>
```

**File:** `{project-root}/.gitignore`

```text
# Logs
logs
*.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*
pnpm-debug.log*
lerna-debug.log*

node_modules
.DS_Store
dist
!html-template/dist
coverage
*.local

# Editor directories and files
.vscode/*
!.vscode/extensions.json
.idea
*.suo
*.ntvs*
*.njsproj
*.sl
*.sw?

*.tsbuildinfo

.eslintcache

# Cypress
/cypress/videos/
/cypress/screenshots/

# Vitest
__screenshots__/

# capacitor
capacitor.config.ts

*storybook.log
storybook-static
```

**File:** `{project-root}/.gitattributes`

```text
* text=auto eol=lf
```

**File:** `{project-root}/.prettierignore`

```text
html-template
```
