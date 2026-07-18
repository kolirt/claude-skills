export interface Skill {
  name: string
  description: string
}

export interface Plugin {
  name: string
  version: string
  description: string
  install: string
  source: string
  skills: Skill[]
}

export interface Catalog {
  marketplace: string
  repo: string
  add: string
  plugins: Plugin[]
}
