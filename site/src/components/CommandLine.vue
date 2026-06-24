<script setup lang="ts">
import { ref } from 'vue'
import { t } from '../i18n'

const props = defineProps<{ cmd: string; label?: string }>()
const copied = ref(false)
let timer: ReturnType<typeof setTimeout> | undefined

async function copy() {
  try {
    await navigator.clipboard.writeText(props.cmd)
  } catch {
    // clipboard may be unavailable (non-secure context) — select fallback
    const ta = document.createElement('textarea')
    ta.value = props.cmd
    document.body.appendChild(ta)
    ta.select()
    document.execCommand('copy')
    ta.remove()
  }
  copied.value = true
  clearTimeout(timer)
  timer = setTimeout(() => (copied.value = false), 1400)
}
</script>

<template>
  <div class="cl">
    <span v-if="label" class="cl__label dim">{{ label }}</span>
    <div class="cl__row">
      <code class="cl__code"><span class="cl__sigil">$</span>{{ cmd }}</code>
      <button class="cl__btn" :class="{ ok: copied }" @click="copy" :aria-label="`Copy: ${cmd}`">
        {{ copied ? t('cmd.copied') : t('cmd.copy') }}
      </button>
    </div>
  </div>
</template>

<style scoped>
.cl__label {
  display: block;
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 0.18em;
  margin-bottom: 6px;
}
.cl__row {
  display: flex;
  align-items: stretch;
  gap: 0;
  border: 1px solid var(--border-bright);
  border-radius: var(--radius);
  background: linear-gradient(180deg, #0b0f0d, #070a08);
  overflow: hidden;
}
.cl__code {
  flex: 1;
  min-width: 0;
  padding: 12px 14px;
  font-size: 13.5px;
  color: var(--fg);
  white-space: nowrap;
  overflow-x: auto;
  scrollbar-width: none;
}
.cl__code::-webkit-scrollbar {
  display: none;
}
.cl__sigil {
  color: var(--accent);
  margin-right: 8px;
  user-select: none;
}
.cl__btn {
  flex: none;
  border: 0;
  border-left: 1px solid var(--border-bright);
  background: #0e1411;
  color: var(--fg-dim);
  padding: 0 16px;
  font-size: 12px;
  text-transform: uppercase;
  letter-spacing: 0.12em;
  transition:
    color 0.18s ease,
    background 0.18s ease;
}
.cl__btn:hover {
  color: var(--accent);
  background: #111a15;
}
.cl__btn.ok {
  color: #04130b;
  background: var(--accent);
}
</style>
