import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// GitHub Pages project site is served from /<repo>/.
// To host at a different base (e.g. a custom domain root), change `base` to '/'.
export default defineConfig({
  base: '/claude-skills/',
  plugins: [vue()],
})
