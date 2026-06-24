import { ref } from 'vue'
import type { Catalog } from './types'

const empty: Catalog = { marketplace: '', repo: '', add: '', plugins: [] }

export const catalog = ref<Catalog>(empty)
export const loaded = ref(false)
export const loadError = ref<string | null>(null)

let started = false

export async function loadCatalog(): Promise<void> {
  if (started) return
  started = true
  try {
    const res = await fetch(`${import.meta.env.BASE_URL}data.json`, { cache: 'no-cache' })
    if (!res.ok) throw new Error(`HTTP ${res.status}`)
    catalog.value = (await res.json()) as Catalog
  } catch (e) {
    loadError.value = e instanceof Error ? e.message : String(e)
  } finally {
    loaded.value = true
  }
}

export function findPlugin(name: string) {
  return catalog.value.plugins.find((p) => p.name === name)
}
