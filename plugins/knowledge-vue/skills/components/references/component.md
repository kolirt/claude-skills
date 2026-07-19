# Etalon: components

Real examples for the `components` skill: a shared-ui primitive family
(`base-button` → `flat-button`), a compound component (`tab-button-group` →
`tab-button`), a standalone primitive (`chip`), and their `{shared-utils}`
helpers. Reproduced verbatim except two deliberate deviations from source:
`base-button/helpers.ts`'s CSS-variable table is trimmed to only the entries
used below (rest cut as out of scope), and `BaseButton.vue`'s `onMounted` call
plus the `interface.ts` prop types are written as corrected desired-state, not
copied as-is (the source had a bug). `delegatePrimitiveProps`/
`mergeDelegatedProps` live in `{shared-ui}/internal/` (Vue-reactive, so not
`{shared-utils}`-pure); `call()` is colocated with its sole consumer,
`tab-button`.

## Files

- `{shared-ui}/buttons/base-button/BaseButton.vue`
- `{shared-ui}/buttons/base-button/BaseButtonLabel.vue`
- `{shared-ui}/buttons/base-button/BaseButtonIcon.vue`
- `{shared-ui}/buttons/base-button/BaseButtonLink.vue`
- `{shared-ui}/buttons/base-button/helpers.ts`
- `{shared-ui}/buttons/base-button/interface.ts`
- `{shared-ui}/buttons/base-button/index.ts`
- `{shared-ui}/buttons/flat-button/FlatButton.vue`
- `{shared-ui}/buttons/flat-button/interface.ts`
- `{shared-ui}/buttons/flat-button/index.ts`
- `{shared-ui}/buttons/tab-button-group/TabButtonGroup.vue`
- `{shared-ui}/buttons/tab-button-group/context.ts`
- `{shared-ui}/buttons/tab-button-group/interface.ts`
- `{shared-ui}/buttons/tab-button-group/index.ts`
- `{shared-ui}/buttons/tab-button/TabButton.vue`
- `{shared-ui}/buttons/tab-button/interface.ts`
- `{shared-ui}/buttons/tab-button/index.ts`
- `{shared-ui}/buttons/index.ts`
- `{shared-ui}/chip/Chip.vue`
- `{shared-ui}/chip/interface.ts`
- `{shared-ui}/chip/index.ts`
- `{shared-ui}/internal/delegatePrimitiveProps.ts`
- `{shared-ui}/internal/mergeDelegatedProps.ts`
- `{shared-ui}/buttons/tab-button/call.ts`
- `{shared-utils}/cn.ts`
- `{shared-utils}/autoFocus.ts`
- `{shared-utils}/index.ts`

**File:** `{shared-ui}/buttons/base-button/BaseButton.vue`
```vue
<script lang="ts" setup>
import { reactivePick } from '@vueuse/core'
import { Primitive } from 'reka-ui'
import { computed, onMounted, useTemplateRef } from 'vue'

import { LoaderIcon } from '{shared-ui}/icons'
import { autoFocus, cn } from '{shared-utils}'

import BaseButtonIcon from './BaseButtonIcon.vue'
import BaseButtonLink from './BaseButtonLink.vue'
import type { BaseButtonProps } from './interface'

const props = withDefaults(defineProps<BaseButtonProps>(), {
  as: 'button',
  type: 'button',
  iconPosition: 'left',
  iconSize: 20
})

const primitiveRef = useTemplateRef('primitiveRef')

const as = computed(() => {
  if (props.to || props.href) return BaseButtonLink
  return props.as
})

const delegatedProps = reactivePick(props, 'as', 'asChild', 'to', 'href', 'disabled')

const showSpinnerOverlay = computed(() => props.loading && !props.icon)

onMounted(() => {
  if (props.autoFocus) autoFocus(primitiveRef.value)
})
</script>

<template>
  <Primitive
    ref="primitiveRef"
    v-bind="delegatedProps"
    :as="as"
    :class="
      cn(
        'btn',
        {
          loading: props.loading,
          'disable-active': props.disableActiveEffect,
          'is-active': props.active,
          'relative text-transparent': showSpinnerOverlay
        },
        props.class
      )
    "
  >
    <BaseButtonIcon
      v-if="props.icon && props.iconPosition === 'left'"
      :icon="props.icon"
      :loading="props.loading"
      :size="props.iconSize"
      :class="props.iconClass"
    />

    <slot />

    <BaseButtonIcon
      v-if="props.icon && props.iconPosition === 'right'"
      :icon="props.icon"
      :loading="props.loading"
      :size="props.iconSize"
      :class="props.iconClass"
    />

    <span v-if="showSpinnerOverlay" class="absolute inset-0 flex items-center justify-center text-(--foreground-color)">
      <LoaderIcon :size="props.iconSize" />
    </span>
  </Primitive>
</template>
```

**File:** `{shared-ui}/buttons/base-button/BaseButtonLabel.vue`
```vue
<script lang="ts" setup>
import { cn } from '{shared-utils}'

import type { BaseButtonLabelProps } from './interface'

const props = defineProps<BaseButtonLabelProps>()
</script>

<template>
  <span :class="cn('block min-w-0 overflow-hidden text-ellipsis whitespace-nowrap', props.class)">
    <slot />
  </span>
</template>
```

**File:** `{shared-ui}/buttons/base-button/BaseButtonIcon.vue`
```vue
<script lang="ts" setup>
import { LoaderIcon } from '{shared-ui}/icons'

import type { BaseButtonIconProps } from './interface'

const props = withDefaults(defineProps<BaseButtonIconProps>(), {
  size: 20
})
</script>

<template>
  <component :is="props.loading ? LoaderIcon : props.icon" :size="props.size" />
</template>
```

**File:** `{shared-ui}/buttons/base-button/BaseButtonLink.vue`
```vue
<script lang="ts" setup>
import { computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'

import type { BaseButtonProps } from './interface'

const props = defineProps<Pick<BaseButtonProps, 'to' | 'href'>>()
const route = useRoute()
const router = useRouter()

const isActive = computed(() => {
  if (!props.to) return false

  const resolved = router.resolve(props.to)

  if (resolved.path !== route.path) return false

  const resolvedQuery = resolved.query
  const resolvedKeys = Object.keys(resolvedQuery)

  if (resolvedKeys.length !== Object.keys(route.query).length) return false

  return resolvedKeys.every((key) => resolvedQuery[key] === route.query[key])
})
</script>

<template>
  <RouterLink v-if="props.to" v-slot="{ href: resolvedHref, navigate }" :to="props.to" custom>
    <a @click="navigate" :href="resolvedHref" :class="{ 'is-active': isActive }">
      <slot />
    </a>
  </RouterLink>

  <a v-else :href="props.href" rel="noopener noreferrer" target="_blank">
    <slot />
  </a>
</template>
```

**File:** `{shared-ui}/buttons/base-button/helpers.ts`
```ts
import { reactivePick } from '@vueuse/core'

import type { PublicBaseButtonProps } from './interface'

const buttonVariableClasses = {
  foregroundColor: {
    'var(--card)': '[--foreground-color:var(--card)]',
    'var(--foreground)': '[--foreground-color:var(--foreground)]',
    'var(--foreground-accent)': '[--foreground-color:var(--foreground-accent)]'
  },
  foregroundHoverColor: {
    'var(--card)': '[--foreground-hover-color:var(--card)]'
  },
  backgroundColor: {
    'var(--foreground-accent)': '[--background-color:var(--foreground-accent)]',
    'var(--color-black)/17': '[--background-color:color-mix(in_srgb,var(--color-black)17%,transparent)]'
  },
  backgroundHoverColor: {
    'var(--foreground-accent)': '[--background-hover-color:var(--foreground-accent)]',
    'var(--input)': '[--background-hover-color:var(--input)]',
    'var(--background)': '[--background-hover-color:var(--background)]'
  },
  backgroundActiveColor: {
    'var(--input)': '[--background-active-color:var(--input)]',
    'var(--background)': '[--background-active-color:var(--background)]'
  },
  borderColor: {
    transparent: '[--border-color:transparent]',
    'var(--border-accent)': '[--border-color:var(--border-accent)]'
  },
  borderActiveColor: {
    'var(--border)': '[--border-active-color:var(--border)]',
    'var(--border-accent)': '[--border-active-color:var(--border-accent)]'
  }
}

type ButtonVariableKey = keyof typeof buttonVariableClasses
type ButtonVariables = {
  [K in ButtonVariableKey]?: keyof (typeof buttonVariableClasses)[K]
}

function setButtonVariables(variables: ButtonVariables): string {
  const classes: string[] = []

  for (const [key, value] of Object.entries(variables)) {
    if (value && key in buttonVariableClasses) {
      const mapping = buttonVariableClasses[key as ButtonVariableKey]
      const className = mapping[value as keyof typeof mapping]
      if (className) classes.push(className)
    }
  }

  return classes.join(' ')
}

function delegateBaseButtonProps(props: PublicBaseButtonProps) {
  return reactivePick(
    props,
    'as',
    'asChild',
    'type',
    'to',
    'href',
    'disabled',
    'loading',
    'active',
    'icon',
    'iconPosition',
    'disableActiveEffect',
    'autoFocus'
  )
}

export { type ButtonVariables, setButtonVariables, delegateBaseButtonProps }
```

**File:** `{shared-ui}/buttons/base-button/interface.ts`
```ts
import type { PrimitiveProps } from 'reka-ui'
import type { Component, HTMLAttributes } from 'vue'
import type { RouteLocationRaw } from 'vue-router'

interface PublicBaseButtonProps extends PrimitiveProps {
  type?: 'button' | 'submit'
  to?: RouteLocationRaw
  href?: string
  disabled?: boolean
  loading?: boolean
  active?: boolean

  icon?: Component
  iconPosition?: 'left' | 'right'

  disableActiveEffect?: boolean
  autoFocus?: boolean

  class?: HTMLAttributes['class']
}

interface BaseButtonProps extends PublicBaseButtonProps {
  iconSize?: number
  iconClass?: HTMLAttributes['class']
}

interface BaseButtonLabelProps {
  class?: HTMLAttributes['class']
}

interface BaseButtonIconProps {
  icon: Component
  size?: number
  loading?: boolean
}

export {
  type BaseButtonProps,
  type PublicBaseButtonProps,
  type BaseButtonLabelProps,
  type BaseButtonIconProps
}
```

**File:** `{shared-ui}/buttons/base-button/index.ts`
```ts
export { default as BaseButton } from './BaseButton.vue'
export { default as BaseButtonLabel } from './BaseButtonLabel.vue'
export { type ButtonVariables, setButtonVariables, delegateBaseButtonProps } from './helpers'
export {
  type BaseButtonProps,
  type PublicBaseButtonProps,
  type BaseButtonLabelProps,
  type BaseButtonIconProps
} from './interface'
```

**File:** `{shared-ui}/buttons/flat-button/FlatButton.vue`
```vue
<script lang="ts" setup>
import { cn } from '{shared-utils}'

import { BaseButton, BaseButtonLabel, delegateBaseButtonProps } from '../base-button'
import { type FlatButtonProps, flatButtonVariants } from './interface'

const props = withDefaults(defineProps<FlatButtonProps>(), {
  variant: 'normal'
})

const delegatedProps = delegateBaseButtonProps(props)
</script>

<template>
  <BaseButton
    v-bind="delegatedProps"
    :icon-size="20"
    :class="cn(flatButtonVariants({ variant: props.variant }), props.class)"
  >
    <BaseButtonLabel v-if="$slots.default">
      <slot />
    </BaseButtonLabel>
  </BaseButton>
</template>
```

**File:** `{shared-ui}/buttons/flat-button/interface.ts`
```ts
import { type VariantProps, cva } from 'class-variance-authority'

import { type PublicBaseButtonProps, setButtonVariables } from '../base-button'

const flatButtonVariants = cva('rounded-rg text-card flex h-7.5 items-center justify-center gap-1.25 text-sm', {
  variants: {
    variant: {
      normal: [
        setButtonVariables({
          foregroundColor: 'var(--card)',
          backgroundColor: 'var(--foreground-accent)',
          foregroundHoverColor: 'var(--card)',
          backgroundHoverColor: 'var(--foreground-accent)'
        })
      ]
    }
  },
  defaultVariants: {
    variant: 'normal'
  }
})

type FlatButtonVariants = VariantProps<typeof flatButtonVariants>

interface FlatButtonProps extends PublicBaseButtonProps {
  variant?: Exclude<FlatButtonVariants['variant'], null | undefined>
}

export { flatButtonVariants, type FlatButtonVariants, type FlatButtonProps }
```

**File:** `{shared-ui}/buttons/flat-button/index.ts`
```ts
export { default as FlatButton } from './FlatButton.vue'
export type { FlatButtonProps } from './interface'
```

**File:** `{shared-ui}/buttons/tab-button-group/TabButtonGroup.vue`
```vue
<script generic="T" lang="ts" setup>
import { Primitive } from 'reka-ui'

import { cn } from '{shared-utils}'
import { delegatePrimitiveProps } from '{shared-ui}/internal/delegatePrimitiveProps'

import { provideTabButtonGroup } from './context'
import { type TabButtonGroupProps, tabButtonGroupVariants } from './interface'

const props = withDefaults(defineProps<TabButtonGroupProps>(), {
  as: 'div',
  variant: 'page-tabs'
})

const delegatedProps = delegatePrimitiveProps(props)

const modelValue = defineModel<T | null>()

provideTabButtonGroup<T>({
  variant: props.variant,
  activeValue: modelValue,
  select: (value) => {
    modelValue.value = value
  }
})
</script>

<template>
  <Primitive v-bind="delegatedProps" :class="cn(tabButtonGroupVariants({ variant: props.variant }), props.class)">
    <slot />
  </Primitive>
</template>
```

**File:** `{shared-ui}/buttons/tab-button-group/context.ts`
```ts
import { type InjectionKey, type Ref, inject, provide } from 'vue'

import { type TabButtonGroupProps } from './interface'

interface TabButtonGroupContext<T = unknown> {
  variant: TabButtonGroupProps['variant']
  activeValue?: Ref<T | null | undefined>
  select?: (value: T | null) => void
}

const TAB_BUTTON_GROUP_SYMBOL = Symbol('NavButtonGroup') as InjectionKey<TabButtonGroupContext>

function useTabButtonGroup<T = unknown>() {
  return inject<TabButtonGroupContext<T> | null>(TAB_BUTTON_GROUP_SYMBOL, null)
}

function provideTabButtonGroup<T = unknown>(context: TabButtonGroupContext<T>) {
  provide(TAB_BUTTON_GROUP_SYMBOL, context as TabButtonGroupContext)
}

export { type TabButtonGroupContext, useTabButtonGroup, provideTabButtonGroup }
```

**File:** `{shared-ui}/buttons/tab-button-group/interface.ts`
```ts
import { type VariantProps, cva } from 'class-variance-authority'
import type { PrimitiveProps } from 'reka-ui'
import type { HTMLAttributes } from 'vue'

const tabButtonGroupVariants = cva('flex h-10 shrink-0 items-center justify-start border border-solid', {
  variants: {
    variant: {
      'page-tabs': 'rounded-3lg bg-background/60 border-background/80 gap-0.5 p-1',
      transparent: 'bg-input border-border gap-1.25 rounded-lg p-1.25'
    }
  }
})

type TabButtonGroupVariants = VariantProps<typeof tabButtonGroupVariants>

interface TabButtonGroupProps extends PrimitiveProps {
  variant: Exclude<TabButtonGroupVariants['variant'], null | undefined>
  class?: HTMLAttributes['class']
}

export { tabButtonGroupVariants, type TabButtonGroupProps }
```

**File:** `{shared-ui}/buttons/tab-button-group/index.ts`
```ts
export { useTabButtonGroup } from './context'
export { type TabButtonGroupProps } from './interface'
export { default as TabButtonGroup } from './TabButtonGroup.vue'
```

**File:** `{shared-ui}/buttons/tab-button/TabButton.vue`
```vue
<script lang="ts" setup>
import { computed } from 'vue'

import { cn } from '{shared-utils}'
import { mergeDelegatedProps } from '{shared-ui}/internal/mergeDelegatedProps'

import { BaseButton, BaseButtonLabel, delegateBaseButtonProps } from '../base-button'
import { useTabButtonGroup } from '../tab-button-group'
import { call } from './call'
import { type TabButtonProps, tabButtonVariants } from './interface'

const props = defineProps<TabButtonProps>()

const group = useTabButtonGroup()

const context = computed<{
  variant: TabButtonProps['variant']
  active: TabButtonProps['active']
}>(() => {
  return {
    variant: props.variant || group?.variant,
    active: call(() => {
      if (group && group.activeValue && props.value !== undefined) {
        return group.activeValue.value === props.value
      }
      return props.active
    })
  }
})

const delegatedProps = delegateBaseButtonProps(mergeDelegatedProps(props, context))

function onClick() {
  if (props.disabled) return

  if (group && group.select && props.value !== undefined) {
    group.select(props.value)
  }
}
</script>

<template>
  <BaseButton
    @click="onClick"
    v-bind="delegatedProps"
    :class="cn(tabButtonVariants({ variant: context.variant }), props.class)"
  >
    <BaseButtonLabel v-if="$slots.default">
      <slot />
    </BaseButtonLabel>
  </BaseButton>
</template>
```

**File:** `{shared-ui}/buttons/tab-button/interface.ts`
```ts
import { type VariantProps, cva } from 'class-variance-authority'

import { cn } from '{shared-utils}'

import { type PublicBaseButtonProps, setButtonVariables } from '../base-button'
import type { TabButtonGroupProps } from '../tab-button-group'

const tabButtonVariants = cva(cn('flex h-full items-center justify-center rounded-lg border border-solid'), {
  variants: {
    variant: {
      'page-tabs': [
        setButtonVariables({
          foregroundColor: 'var(--foreground)',
          backgroundHoverColor: 'var(--input)',
          backgroundActiveColor: 'var(--input)',
          borderColor: 'transparent',
          borderActiveColor: 'var(--border)'
        }),
        'px-2.5 text-sm'
      ],
      transparent: [
        setButtonVariables({
          foregroundColor: 'var(--foreground-accent)',
          backgroundColor: 'var(--color-black)/17',
          backgroundHoverColor: 'var(--background)',
          backgroundActiveColor: 'var(--background)',
          borderColor: 'var(--border-accent)',
          borderActiveColor: 'var(--border-accent)'
        }),
        'gap-1.25 px-2.5 text-sm'
      ]
    } satisfies Record<NonNullable<TabButtonGroupProps['variant']>, string | string[] | null>
  }
})

type TabButtonVariants = VariantProps<typeof tabButtonVariants>

interface TabButtonProps extends PublicBaseButtonProps {
  variant?: Exclude<TabButtonVariants['variant'], null | undefined>
  value?: string | number
}

export { tabButtonVariants, type TabButtonProps }
```

**File:** `{shared-ui}/buttons/tab-button/index.ts`
```ts
export type { TabButtonProps } from './interface'
export { default as TabButton } from './TabButton.vue'
```

**File:** `{shared-ui}/buttons/index.ts`
```ts
export * from './base-button'
export * from './flat-button'
export * from './tab-button'
export * from './tab-button-group'
```

**File:** `{shared-ui}/chip/Chip.vue`
```vue
<script lang="ts" setup>
import { Primitive } from 'reka-ui'

import { CloseIcon } from '{shared-ui}/icons'
import { cn } from '{shared-utils}'
import { delegatePrimitiveProps } from '{shared-ui}/internal/delegatePrimitiveProps'

import type { ChipEmits, ChipProps } from './interface'

const props = withDefaults(defineProps<ChipProps>(), {
  as: 'button'
})

const delegatedProps = delegatePrimitiveProps(props)

const emits = defineEmits<ChipEmits>()
</script>

<template>
  <Primitive
    @click="emits('remove')"
    v-bind="delegatedProps"
    type="button"
    :class="
      cn(
        'rounded-rg bg-accent hover:bg-border-accent flex h-7.5 items-center justify-center gap-0.5 px-1.5 transition-colors',
        props.class
      )
    "
  >
    <span class="font-inter text-foreground-accent text-base font-medium">
      <slot />
    </span>
    <CloseIcon :size="20" class="text-foreground-accent" />
  </Primitive>
</template>
```

**File:** `{shared-ui}/chip/interface.ts`
```ts
import type { PrimitiveProps } from 'reka-ui'
import type { HTMLAttributes } from 'vue'

interface ChipProps extends PrimitiveProps {
  class?: HTMLAttributes['class']
}

interface ChipEmits {
  remove: []
}

export type { ChipEmits, ChipProps }
```

**File:** `{shared-ui}/chip/index.ts`
```ts
export { default as Chip } from './Chip.vue'
export type { ChipEmits, ChipProps } from './interface'
```

**File:** `{shared-ui}/internal/delegatePrimitiveProps.ts`
```ts
import { reactivePick } from '@vueuse/core'
import type { PrimitiveProps } from 'reka-ui'

export function delegatePrimitiveProps(props: PrimitiveProps) {
  return reactivePick(props, 'as', 'asChild')
}
```

**File:** `{shared-ui}/internal/mergeDelegatedProps.ts`
```ts
import { reactiveComputed } from '@vueuse/core'
import { type MaybeRefOrGetter, toValue } from 'vue'

export function mergeDelegatedProps<T extends Record<string, unknown>, U extends Record<string, unknown>>(
  value1: MaybeRefOrGetter<T>,
  value2: MaybeRefOrGetter<U>
): T & U {
  return reactiveComputed(() => ({ ...toValue(value1), ...toValue(value2) })) as T & U
}
```

**File:** `{shared-ui}/buttons/tab-button/call.ts`
```ts
export function call<T>(fn: () => T) {
  return fn()
}
```

**File:** `{shared-utils}/cn.ts`
```ts
import type { ClassValue } from 'clsx'
import { clsx } from 'clsx'
import { twMerge } from 'tailwind-merge'

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}
```

**File:** `{shared-utils}/autoFocus.ts`
```ts
import { nextTick } from 'vue'
import type { ComponentPublicInstance } from 'vue'

export function autoFocus(target: Element | ComponentPublicInstance | null | undefined) {
  nextTick(() => {
    const el = target instanceof Element ? target : (target as ComponentPublicInstance | undefined)?.$el

    if (el instanceof HTMLElement) el.focus()
  })
}
```

**File:** `{shared-utils}/index.ts`
```ts
export { autoFocus } from './autoFocus'
export { cn } from './cn'
```
