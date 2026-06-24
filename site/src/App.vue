<script setup lang="ts">
import { catalog } from './data'
import { t } from './i18n'
</script>

<template>
  <header class="hdr">
    <div class="wrap hdr__in">
      <RouterLink to="/" class="brand">
        <span class="brand__sigil">▮</span>
        <span class="brand__name">claude-skills</span>
        <span class="brand__tag dim">{{ t('nav.marketplace') }}</span>
      </RouterLink>
      <nav class="hdr__nav">
        <a
          v-if="catalog.repo"
          :href="`https://github.com/${catalog.repo}`"
          target="_blank"
          rel="noopener"
          >{{ t('nav.source') }}</a
        >
      </nav>
    </div>
  </header>

  <main class="wrap main">
    <RouterView v-slot="{ Component }">
      <Transition name="fade" mode="out-in">
        <component :is="Component" />
      </Transition>
    </RouterView>
  </main>

  <footer class="ftr">
    <div class="wrap ftr__in dim">
      <span>{{ t('footer.tagline') }}</span>
      <span class="faint">{{ t('footer.built') }}</span>
    </div>
  </footer>
</template>

<style scoped>
.hdr {
  position: sticky;
  top: 0;
  z-index: 20;
  backdrop-filter: blur(8px);
  background: rgba(5, 7, 6, 0.72);
  border-bottom: 1px solid var(--border);
}
.hdr__in {
  display: flex;
  align-items: center;
  justify-content: space-between;
  height: 58px;
}
.brand {
  display: flex;
  align-items: baseline;
  gap: 9px;
  color: var(--fg);
}
.brand:hover {
  text-decoration: none;
}
.brand__sigil {
  color: var(--accent);
  animation: blink 1.05s steps(1) infinite;
}
.brand__name {
  font-weight: 800;
  letter-spacing: -0.01em;
}
.brand__tag {
  font-size: 12px;
}
.hdr__nav {
  display: flex;
  align-items: center;
  gap: 16px;
  font-size: 13px;
}
.main {
  min-height: 70vh;
  padding: 0 0 80px;
}
.ftr {
  border-top: 1px solid var(--border);
}
.ftr__in {
  display: flex;
  flex-wrap: wrap;
  gap: 8px 24px;
  justify-content: space-between;
  padding: 22px 0;
  font-size: 12px;
}
@media (max-width: 560px) {
  .brand__tag {
    display: none;
  }
}
</style>
