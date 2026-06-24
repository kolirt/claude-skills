<script setup lang="ts">
import { computed } from 'vue'
import { catalog, loaded, findPlugin } from '../data'
import { t } from '../i18n'
import CommandLine from '../components/CommandLine.vue'
import AgentPanel from '../components/AgentPanel.vue'

const props = defineProps<{ id: string }>()
const plugin = computed(() => findPlugin(props.id))
const isCompanion = computed(() => props.id === 'agent-companion')
</script>

<template>
  <div class="view">
  <div class="crumbs reveal">
    <RouterLink to="/">~/claude-skills</RouterLink>
    <span class="faint">/</span>
    <span class="dim">{{ id }}</span>
  </div>

  <p v-if="loaded && !plugin" class="state danger">! {{ t('skill.notfound') }} “{{ id }}”.</p>

  <article v-else-if="plugin" class="spec">
    <header class="spec__head reveal" style="animation-delay: 0.05s">
      <h1 class="spec__name">{{ plugin.name }}</h1>
      <span class="spec__ver">v{{ plugin.version }}</span>
    </header>
    <p class="spec__desc reveal" style="animation-delay: 0.12s">{{ plugin.description }}</p>

    <section class="block reveal" style="animation-delay: 0.2s">
      <h2 class="block__h"><span class="faint">01</span> {{ t('skill.h.install') }}</h2>
      <div class="cmds">
        <CommandLine :cmd="catalog.add" :label="t('skill.install1')" />
        <CommandLine :cmd="plugin.install" :label="t('skill.install2')" />
      </div>
      <p class="dim note" v-html="t('skill.installNote')" />
    </section>

    <template v-if="isCompanion">
      <section class="block reveal" style="animation-delay: 0.26s">
        <h2 class="block__h"><span class="faint">02</span> {{ t('skill.h.check') }}</h2>
        <p class="prose" v-html="t('skill.checkProse')" />
        <AgentPanel />
        <p class="prose dim note">{{ t('skill.checkCaption') }}</p>
      </section>

      <section class="block reveal" style="animation-delay: 0.32s">
        <h2 class="block__h"><span class="faint">03</span> {{ t('skill.h.commands') }}</h2>
        <dl class="defs">
          <dt><span class="accent">/agent-companion:on</span></dt>
          <dd>{{ t('skill.cmd.on') }}</dd>
          <dt><span class="accent">/agent-companion:off</span></dt>
          <dd>{{ t('skill.cmd.off') }}</dd>
          <dt><span class="accent">/agent-companion:verifiers</span> <span class="dim">[list | add &lt;name&gt; | remove &lt;name&gt;]</span></dt>
          <dd v-html="t('skill.cmd.verifiers')" />
        </dl>
      </section>

      <section class="block reveal" style="animation-delay: 0.38s">
        <h2 class="block__h"><span class="faint">04</span> {{ t('skill.h.modes') }}</h2>
        <dl class="defs">
          <dt><span class="accent">consult</span> <span class="dim">{{ t('skill.mode.consult.tag') }}</span></dt>
          <dd>{{ t('skill.mode.consult') }}</dd>
          <dt><span class="accent">review</span> <span class="dim">{{ t('skill.mode.review.tag') }}</span></dt>
          <dd v-html="t('skill.mode.review')" />
          <dt><span class="accent">audit</span> <span class="dim">{{ t('skill.mode.audit.tag') }}</span></dt>
          <dd v-html="t('skill.mode.audit')" />
          <dt><span class="accent">diagnose</span> <span class="dim">{{ t('skill.mode.diagnose.tag') }}</span></dt>
          <dd v-html="t('skill.mode.diagnose')" />
        </dl>
        <p class="prose dim note">{{ t('skill.modesNote') }}</p>
      </section>

      <section class="block reveal" style="animation-delay: 0.44s">
        <h2 class="block__h"><span class="faint">05</span> {{ t('skill.h.source') }}</h2>
        <a class="src" :href="plugin.source" target="_blank" rel="noopener">{{ plugin.source }} ↗</a>
      </section>
    </template>

    <section v-else class="block reveal" style="animation-delay: 0.28s">
      <h2 class="block__h"><span class="faint">02</span> {{ t('skill.h.source') }}</h2>
      <a class="src" :href="plugin.source" target="_blank" rel="noopener">{{ plugin.source }} ↗</a>
    </section>

    <RouterLink to="/" class="back reveal" style="animation-delay: 0.4s">{{ t('skill.back') }}</RouterLink>
  </article>
  </div>
</template>

<style scoped>
.crumbs {
  display: flex;
  gap: 10px;
  align-items: center;
  font-size: 13px;
  padding: 32px 0 26px;
}
.spec {
  max-width: 760px;
}
.spec__head {
  display: flex;
  align-items: baseline;
  gap: 14px;
}
.spec__name {
  font-size: clamp(28px, 6vw, 44px);
  color: var(--accent);
  letter-spacing: -0.02em;
  text-shadow: 0 0 22px var(--accent-glow);
}
.spec__ver {
  font-size: 13px;
  color: var(--fg-dim);
  border: 1px solid var(--border-bright);
  border-radius: 99px;
  padding: 2px 11px;
}
.spec__desc {
  margin: 18px 0 8px;
  font-size: 15px;
  line-height: 1.7;
  max-width: 60ch;
}
.block {
  margin-top: 40px;
}
.block__h {
  font-size: 13px;
  text-transform: uppercase;
  letter-spacing: 0.18em;
  color: var(--fg);
  margin-bottom: 16px;
}
.block__h .faint {
  margin-right: 10px;
}
.cmds {
  display: flex;
  flex-direction: column;
  gap: 14px;
}
.note {
  margin: 14px 0 0;
  font-size: 12.5px;
}
.prose {
  font-size: 14px;
  line-height: 1.75;
  max-width: 64ch;
  margin: 0 0 18px;
}
.prose strong {
  font-weight: 700;
}
.prose em {
  font-style: normal;
  color: var(--fg);
  border-bottom: 1px dotted var(--fg-faint);
}
.cyan {
  color: var(--cyan);
}
.amber {
  color: var(--amber);
}
.danger-t {
  color: var(--danger);
}
.defs {
  margin: 0;
  display: flex;
  flex-direction: column;
  gap: 14px;
}
.defs dt {
  font-weight: 700;
  font-size: 13.5px;
}
.defs dd {
  margin: 5px 0 0;
  padding-left: 16px;
  border-left: 2px solid var(--border-bright);
  color: var(--fg);
  font-size: 13.5px;
  line-height: 1.65;
}
.defs code {
  color: var(--cyan);
  font-size: 12.5px;
}
.defs dd em {
  font-style: normal;
  color: var(--fg);
  border-bottom: 1px dotted var(--fg-faint);
}
.src {
  word-break: break-all;
  font-size: 13.5px;
}
.back {
  display: inline-block;
  margin-top: 48px;
  color: var(--fg-dim);
}
.back:hover {
  color: var(--accent);
}
.state {
  padding: 40px 0;
  font-size: 15px;
}
.danger {
  color: var(--danger);
}
</style>
