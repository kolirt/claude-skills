export interface Plugin {
  name: string
  version: string
  description: string
  install: string
  source: string
}

export interface Catalog {
  marketplace: string
  repo: string
  add: string
  plugins: Plugin[]
}
