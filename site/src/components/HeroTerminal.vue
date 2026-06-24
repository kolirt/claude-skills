<script setup lang="ts">
import { catalog } from '../data'
import { t } from '../i18n'
// Marketplace-level (plugin-agnostic) flow — no specific plugin details here.
</script>

<template>
  <div class="term" aria-hidden="true">
    <div class="term__bar">
      <span class="dot" /><span class="dot" /><span class="dot" />
      <span class="term__title dim">{{ t('hero.title') }}</span>
    </div>
    <div class="term__body">
      <p class="ln reveal" style="animation-delay: 0.15s">
        <span class="sig">$</span> /plugin marketplace add <span class="accent">{{ catalog.repo || 'kolirt/claude-skills' }}</span>
      </p>
      <p class="ln out reveal" style="animation-delay: 0.3s">
        <span class="ok">✓</span> {{ t('hero.added.pre') }} <span class="dim">“{{ catalog.marketplace || 'claude-skills' }}”</span> {{ t('hero.added.post') }}
      </p>
      <p class="ln reveal" style="animation-delay: 0.5s">
        <span class="sig">$</span> /plugin install <span class="cyan">&lt;plugin&gt;</span><span class="dim">@{{ catalog.marketplace || 'claude-skills' }}</span>
      </p>
      <p class="ln out reveal" style="animation-delay: 0.65s">
        <span class="ok">✓</span> {{ t('hero.installed') }}
      </p>
      <p class="ln reveal" style="animation-delay: 0.85s">
        <span class="sig">$</span> /plugin update
      </p>
      <p class="ln out reveal" style="animation-delay: 1s">
        <span class="ok">✓</span> {{ t('hero.uptodate') }}<span class="caret" />
      </p>
    </div>
  </div>
</template>

<style scoped>
.term {
  border: 1px solid var(--border-bright);
  border-radius: var(--radius);
  background:
    radial-gradient(90% 120% at 100% 0%, rgba(91, 214, 255, 0.05), transparent 60%),
    var(--panel);
  box-shadow: var(--shadow);
  overflow: hidden;
}
.term__bar {
  display: flex;
  align-items: center;
  gap: 7px;
  padding: 10px 14px;
  border-bottom: 1px solid var(--border);
  background: #0b0f0d;
}
.dot {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  background: var(--border-bright);
}
.dot:first-child {
  background: #34201f;
}
.term__title {
  margin-left: auto;
  font-size: 11px;
}
.term__body {
  padding: 18px;
  font-size: 13.5px;
  line-height: 1.95;
}
.ln {
  margin: 0;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.out {
  color: var(--fg-dim);
}
.sig {
  color: var(--accent);
  margin-right: 8px;
  user-select: none;
}
.ok {
  color: var(--accent);
  margin-right: 8px;
}
.cyan {
  color: var(--cyan);
}
</style>
