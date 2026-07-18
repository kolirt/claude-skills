<script setup lang="ts">
import { computed, ref } from 'vue'
import { catalog, loaded, loadError } from '../data'
import { t } from '../i18n'
import HeroTerminal from '../components/HeroTerminal.vue'
import CommandLine from '../components/CommandLine.vue'
import PluginCard from '../components/PluginCard.vue'

const q = ref('')
const results = computed(() => {
  const needle = q.value.trim().toLowerCase()
  if (!needle) return catalog.value.plugins
  return catalog.value.plugins.filter((p) => {
    const skills = (p.skills ?? []).map((s) => `${s.name} ${s.description}`).join(' ')
    return `${p.name} ${p.description} ${skills}`.toLowerCase().includes(needle)
  })
})
</script>

<template>
  <div class="view">
  <section class="hero">
    <div class="hero__copy">
      <p class="boot reveal" style="animation-delay: 0.02s">
        <span class="faint">~/claude-skills</span> <span class="prompt"></span>{{ t('home.boot') }}
      </p>
      <h1 class="hero__title reveal" style="animation-delay: 0.12s">
        <span v-html="t('home.title')" /><span class="caret" />
      </h1>
      <p class="hero__lede reveal dim" style="animation-delay: 0.22s" v-html="t('home.lede')" />
      <div class="hero__cmd reveal" style="animation-delay: 0.32s">
        <CommandLine
          :cmd="catalog.add || '/plugin marketplace add kolirt/claude-skills'"
          :label="t('home.addLabel')"
        />
      </div>
    </div>
    <div class="hero__viz">
      <HeroTerminal />
    </div>
  </section>

  <section class="catalog">
    <div class="catalog__bar">
      <h2 class="catalog__h">
        <span class="faint">//</span> {{ t('home.plugins') }}
        <span class="dim" v-if="loaded">({{ results.length }})</span>
      </h2>
      <label class="search">
        <span class="search__sigil">/</span>
        <input
          v-model="q"
          type="search"
          :placeholder="t('home.search')"
          aria-label="Search plugins"
          spellcheck="false"
        />
      </label>
    </div>

    <p v-if="loadError" class="state danger">! {{ t('home.loadError') }} {{ loadError }}</p>
    <p v-else-if="!loaded" class="state dim">{{ t('home.loading') }}<span class="caret" /></p>
    <p v-else-if="!results.length" class="state dim">{{ t('home.noMatch') }} “{{ q }}”.</p>

    <div v-else class="grid">
      <PluginCard v-for="(p, i) in results" :key="p.name" :plugin="p" :index="i" />
    </div>
  </section>
  </div>
</template>

<style scoped>
.hero {
  display: grid;
  grid-template-columns: 1.05fr 0.95fr;
  gap: 44px;
  align-items: center;
  padding: 64px 0 56px;
}
.boot {
  font-size: 13px;
  margin: 0 0 18px;
}
.hero__title {
  font-size: clamp(30px, 5.2vw, 52px);
  line-height: 1.05;
  letter-spacing: -0.02em;
}
.hero__lede {
  margin: 20px 0 26px;
  max-width: 52ch;
  font-size: 14.5px;
  line-height: 1.7;
}
.hero__lede strong {
  font-weight: 700;
}
.catalog {
  padding-top: 8px;
}
.catalog__bar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  margin-bottom: 22px;
  border-bottom: 1px solid var(--border);
  padding-bottom: 14px;
}
.catalog__h {
  font-size: 14px;
  text-transform: uppercase;
  letter-spacing: 0.16em;
}
.search {
  display: flex;
  align-items: center;
  gap: 8px;
  border: 1px solid var(--border-bright);
  border-radius: var(--radius);
  padding: 8px 12px;
  background: #080b09;
  min-width: min(320px, 48vw);
  transition: border-color 0.18s ease;
}
.search:focus-within {
  border-color: var(--accent-deep);
}
.search__sigil {
  color: var(--accent);
}
.search input {
  border: 0;
  background: transparent;
  color: var(--fg);
  font: inherit;
  font-size: 13.5px;
  width: 100%;
  outline: none;
}
.grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: 16px;
}
.state {
  padding: 28px 2px;
  font-size: 14px;
}
.danger {
  color: var(--danger);
}

@media (max-width: 820px) {
  .hero {
    grid-template-columns: 1fr;
    gap: 32px;
    padding: 40px 0 36px;
  }
}
@media (max-width: 560px) {
  .catalog__bar {
    flex-direction: column;
    align-items: stretch;
  }
  .search {
    min-width: 0;
  }
}
</style>
