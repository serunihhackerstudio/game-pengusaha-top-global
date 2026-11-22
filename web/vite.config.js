import {defineConfig} from 'vite';

// base relatif agar hasil build bisa ditaruh di folder/hosting mana pun.
export default defineConfig({
	base: './',
	build: {chunkSizeWarningLimit: 1500},
});
