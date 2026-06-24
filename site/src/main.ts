import { createApp } from 'vue'
import { router } from './router'
import { loadCatalog } from './data'
import App from './App.vue'
import './style.css'

loadCatalog()
createApp(App).use(router).mount('#app')
