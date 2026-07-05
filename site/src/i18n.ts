// English-only string table. `t(key)` returns the string for a key (or the key
// itself as a fallback). Kept as a small indirection so copy lives in one place.

type Dict = Record<string, string>

const en: Dict = {
  'nav.marketplace': '// marketplace',
  'nav.source': 'source ↗',
  'footer.tagline': 'claude-skills · native Claude Code plugin marketplace',
  'footer.built': 'built with vite + vue · install via /plugin',

  'home.boot': 'plugin marketplace add',
  'home.title': "A marketplace for<br /><span class='accent'>Claude Code</span> plugins.",
  'home.lede':
    "Install agents, commands and skills straight into Claude Code with <span class='accent'>/plugin</span>. Each plugin is self-contained — <strong class='accent'>add the marketplace, install what you need</strong>, and it's ready to use.",
  'home.addLabel': 'add the marketplace',
  'home.plugins': 'plugins',
  'home.search': 'search plugins…',
  'home.loadError': 'failed to load catalog:',
  'home.loading': 'loading catalog',
  'home.noMatch': 'no plugins match',

  'hero.title': 'claude-code — /plugin',
  'hero.added.pre': 'marketplace',
  'hero.added.post': 'added',
  'hero.installed': 'installed — commands, skills & agents ready',
  'hero.uptodate': 'up to date',

  'card.open': 'open →',
  'cmd.copy': 'copy',
  'cmd.copied': 'copied ✓',

  'skill.notfound': 'no plugin named',
  'skill.h.install': 'install',
  'skill.h.check': 'how a check works',
  'skill.h.commands': 'commands',
  'skill.h.modes': 'modes of consultation',
  'skill.h.source': 'source',
  'skill.install1': '1 · add the marketplace',
  'skill.install2': '2 · install the plugin',
  'skill.installNote':
    "then run <span class='accent'>/plugin update</span> any time to upgrade.",
  'skill.checkProse':
    "Claude does the work and makes the calls. But at a real decision, or on a finished change, it doesn’t judge alone — it sends the same request to <strong class='accent'>several independent verifier agents at once</strong>. Each agent is its own CLI (e.g. <span class='cyan'>codex</span>), runs on its own, and returns its own verdict — <span class='accent'>pass</span>, <span class='amber'>changes</span>, or <span class='danger-t'>fail</span>. Claude then combines those verdicts. Think of it like getting your change reviewed by several reviewers at the same time instead of one.",
  'skill.checkCaption':
    'one manager (Claude) → several independent verifiers, in parallel → one combined result.',
  'skill.cmd.off': 'Stop managing; back to normal.',
  'skill.cmd.on': 'Claude starts acting as the manager (per the bundled MANAGER protocol).',
  'skill.cmd.verifiers':
    "Manage which verifier agents are active. <code>add</code> needs a matching adapter.",
  'skill.cmd.synth':
    "Choose the agent that consolidates the verifiers’ reports into one (so 2+ reports don’t flood the session), or turn it off.",
  'skill.mode.consult.tag': '— forward-looking',
  'skill.mode.consult':
    'At a decision fork, the verifier agents weigh in with advice; Claude synthesizes their input before choosing.',
  'skill.mode.review.tag': '— gating',
  'skill.mode.review':
    "A finished change is judged against acceptance criteria. <strong>any-blocks</strong>: it passes only if <em class='em'>every</em> active verifier passes — any “changes requested” or failure blocks.",
  'skill.mode.audit.tag': '— backward-looking',
  'skill.mode.audit':
    "Independent discovery of <em class='em'>unknown</em> issues across existing code; each agent’s findings are merged (union).",
  'skill.mode.diagnose.tag': '— root cause',
  'skill.mode.diagnose':
    "Root-cause analysis of a <em class='em'>known</em> symptom or bug — explains <strong>why</strong> it happens (not discovery like audit, not fix-choice like consult).",
  'skill.mode.research.tag': '— open question',
  'skill.mode.research':
    "Independent investigation of an open question — how something works, what the options are, feasibility (may reach beyond code); each agent’s findings are merged (union). Answers <em class='em'>what is true</em>, not <strong>which to pick</strong> like consult.",
  'skill.modesNote':
    'Graceful degrade: an agent that isn’t installed/authenticated is skipped; if none are available, Claude proceeds and tells you the review was skipped.',
  'skill.back': '← all plugins',

  'ap.manager': 'manager',
  'ap.add': '+ add',
  'ap.aggregate': 'aggregate',
  'ap.aggNote': '· review PASS only if every verifier passes',
}

export function t(key: string): string {
  return en[key] ?? key
}
