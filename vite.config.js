import path from "path"
import { defineConfig, loadEnv } from 'vite'
import react from '@vitejs/plugin-react-swc'

// https://vitejs.dev/config/
export default defineConfig(({ mode }) => {
  // Add process back
  const env = loadEnv(mode, process.cwd(), '');
  return {
    define: {
      "process.env": env,
      global: "window",
    },    
    plugins: [react()],
    resolve: {
      alias: {
        "@": path.resolve(__dirname, "./src"),
      },
    },  
  }
})
