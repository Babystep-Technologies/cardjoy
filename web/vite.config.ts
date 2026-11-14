import { defineConfig } from 'vite';
import tailwindcss from '@tailwindcss/vite';
import react from '@vitejs/plugin-react';
import path from 'path';
import { fileURLToPath } from 'url';
import { VitePWA } from 'vite-plugin-pwa';

// ✅ ESM-compatible __dirname replacement
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// https://vite.dev/config/
export default defineConfig({
  plugins: [
    react(),
    tailwindcss(),
    VitePWA({
      registerType: 'autoUpdate',
      includeAssets: ['favicon.ico', 'icons/*'],
      manifest: {
        name: 'CardJoy',
        short_name: 'CardJoy',
        start_url: '/dashboard',
        display: 'standalone',
        background_color: '#ffffff',
        theme_color: '#000000',
        // Android Chrome lists the installed app in the share sheet; sharing a product page lands on
        // the add-item page (#300). iOS Safari doesn't support share targets. Android often puts the
        // link in `text` rather than `url`, so both are read.
        share_target: {
          action: '/registry/add',
          method: 'GET',
          params: { title: 'title', text: 'text', url: 'url' },
        },
        icons: [
          {
            src: '/icons/icon-192.png',
            sizes: '192x192',
            type: 'image/png',
          },
          {
            src: '/icons/icon-512.png',
            sizes: '512x512',
            type: 'image/png',
          },
        ],
      },
    }),
  ],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
  build: {
    rollupOptions: {
      output: {
        manualChunks: {
          // libphonenumber-js carries a few hundred KB of country metadata. Keeping it out of
          // the main chunk lets it cache separately and keeps that chunk under the 2 MiB
          // per-file limit the PWA plugin will precache.
          phone: ['libphonenumber-js'],
        },
      },
    },
  },
});
