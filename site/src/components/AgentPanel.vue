<script setup lang="ts">
import { t } from '../i18n'
// Schematic of the agent-companion model: one manager (Claude) fanning out to
// several verifier agents in parallel, aggregated any-blocks.
const verifiers = [
  { id: 'codex', state: 'pass' },
  { id: 'agy', state: 'pass' },
  { id: 'grok', state: 'pass' },
] as const
</script>

<template>
  <div class="panel" aria-hidden="true">
    <div class="panel__mgr reveal" style="animation-delay: 0.05s">
      <span class="tag">{{ t('ap.manager') }}</span>
      <span class="node node--mgr">claude</span>
      <span class="dim node__sub">/agent-companion:on</span>
    </div>

    <div class="panel__bus">
      <svg class="bus" viewBox="0 0 120 120" preserveAspectRatio="none">
        <path d="M0 60 H50" />
        <path d="M50 60 V12 H120" />
        <path d="M50 60 H120" />
        <path d="M50 60 V108 H120" />
      </svg>
    </div>

    <div class="panel__lanes">
      <div
        v-for="(v, i) in verifiers"
        :key="v.id"
        class="lane reveal"
        :class="`lane--${v.state}`"
        :style="{ animationDelay: `${0.25 + i * 0.12}s` }"
      >
        <span class="lane__dot" />
        <span class="node">{{ v.id }}</span>
        <span class="lane__state">{{ v.state }}</span>
        <span class="lane__scan" />
      </div>
    </div>

    <div class="panel__agg reveal" style="animation-delay: 0.7s">
      <span class="faint">└─</span> {{ t('ap.aggregate') }} <span class="accent">any-blocks</span>
      <span class="dim">{{ t('ap.aggNote') }}</span>
    </div>
  </div>
</template>

<style scoped>
.panel {
  display: grid;
  grid-template-columns: minmax(140px, 0.9fr) 64px minmax(160px, 1fr);
  grid-template-areas:
    'mgr bus lanes'
    'agg agg agg';
  align-items: center;
  gap: 10px 0;
  padding: 22px;
  border: 1px solid var(--border-bright);
  border-radius: var(--radius);
  background:
    radial-gradient(80% 120% at 0% 0%, rgba(77, 255, 160, 0.06), transparent 60%),
    var(--panel);
  box-shadow: var(--shadow);
}
.tag {
  display: block;
  font-size: 10px;
  text-transform: uppercase;
  letter-spacing: 0.2em;
  color: var(--fg-dim);
  margin-bottom: 6px;
}
.node {
  font-weight: 700;
}
.node--mgr {
  font-size: 22px;
  color: var(--accent);
  text-shadow: 0 0 14px var(--accent-glow);
}
.node__sub {
  display: block;
  font-size: 11px;
  margin-top: 4px;
}
.panel__mgr {
  grid-area: mgr;
}
.panel__bus {
  grid-area: bus;
  align-self: stretch;
  display: flex;
}
.bus {
  width: 100%;
  height: 100%;
  min-height: 96px;
}
.bus path {
  fill: none;
  stroke: var(--border-bright);
  stroke-width: 1.2;
  vector-effect: non-scaling-stroke;
  stroke-dasharray: 3 4;
  animation: flow 3s linear infinite;
}
@keyframes flow {
  to {
    stroke-dashoffset: -28;
  }
}
.panel__lanes {
  grid-area: lanes;
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.lane {
  position: relative;
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 8px 12px;
  border: 1px solid var(--border);
  border-radius: var(--radius);
  background: #070a08;
  overflow: hidden;
}
.lane__dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  flex: none;
  background: var(--fg-faint);
}
.lane--pass .lane__dot {
  background: var(--accent);
  box-shadow: 0 0 10px var(--accent);
  animation: pulse 1.8s ease-in-out infinite;
}
@keyframes pulse {
  50% {
    opacity: 0.4;
  }
}
.lane__state {
  margin-left: auto;
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 0.14em;
  color: var(--fg-dim);
}
.lane--pass .lane__state {
  color: var(--accent);
}
.lane--idle {
  border-style: dashed;
  opacity: 0.7;
}
.lane__scan {
  position: absolute;
  inset: 0 -100% 0 auto;
  width: 40%;
  background: linear-gradient(90deg, transparent, rgba(77, 255, 160, 0.08), transparent);
}
.lane--pass .lane__scan {
  animation: scan 4.5s ease-in-out infinite;
}
@keyframes scan {
  0% {
    transform: translateX(0);
  }
  60%,
  100% {
    transform: translateX(-260%);
  }
}
.panel__agg {
  grid-area: agg;
  border-top: 1px solid var(--border);
  padding-top: 12px;
  font-size: 12.5px;
}

@media (max-width: 640px) {
  .panel {
    grid-template-columns: 1fr;
    grid-template-areas: 'mgr' 'lanes' 'agg';
  }
  .panel__bus {
    display: none;
  }
}
</style>
