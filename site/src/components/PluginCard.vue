<script setup lang="ts">
import type { Plugin } from '../types'
import { t } from '../i18n'
defineProps<{ plugin: Plugin; index: number }>()
</script>

<template>
  <RouterLink
    :to="`/skill/${plugin.name}`"
    class="card reveal"
    :style="{ animationDelay: `${0.1 + index * 0.08}s` }"
  >
    <span class="card__br card__br--tl" />
    <span class="card__br card__br--br" />

    <div class="card__head">
      <h3 class="card__name">{{ plugin.name }}</h3>
      <span class="card__ver">v{{ plugin.version }}</span>
    </div>
    <p class="card__desc">{{ plugin.description }}</p>
    <div class="card__foot">
      <span class="dim">{{ plugin.install }}</span>
      <span class="card__go">{{ t('card.open') }}</span>
    </div>
  </RouterLink>
</template>

<style scoped>
.card {
  position: relative;
  display: block;
  padding: 20px;
  border: 1px solid var(--border);
  border-radius: var(--radius);
  background: linear-gradient(180deg, #0a0e0c, #070a08);
  color: var(--fg);
  transition:
    border-color 0.2s ease,
    transform 0.2s ease,
    box-shadow 0.2s ease;
}
.card:hover {
  border-color: var(--accent-deep);
  transform: translateY(-3px);
  box-shadow: 0 0 0 1px var(--accent-deep), 0 22px 50px -28px var(--accent-glow);
  text-decoration: none;
}
.card__br {
  position: absolute;
  width: 10px;
  height: 10px;
  border: 1px solid var(--fg-faint);
  transition: border-color 0.2s ease;
}
.card__br--tl {
  top: 7px;
  left: 7px;
  border-right: 0;
  border-bottom: 0;
}
.card__br--br {
  right: 7px;
  bottom: 7px;
  border-left: 0;
  border-top: 0;
}
.card:hover .card__br {
  border-color: var(--accent);
}
.card__head {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 10px;
}
.card__name {
  font-size: 17px;
  color: var(--accent);
}
.card__ver {
  font-size: 12px;
  color: var(--fg-dim);
  border: 1px solid var(--border-bright);
  border-radius: 99px;
  padding: 1px 9px;
}
.card__desc {
  margin: 12px 0 18px;
  color: var(--fg);
  font-size: 13.5px;
  line-height: 1.65;
}
.card__foot {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  font-size: 12px;
  border-top: 1px solid var(--border);
  padding-top: 12px;
}
.card__foot .dim {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.card__go {
  flex: none;
  color: var(--fg-dim);
  transition: color 0.2s ease;
}
.card:hover .card__go {
  color: var(--accent);
}
</style>
