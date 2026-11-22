# Panduan untuk Claude di repo ini

Game: **Pengusaha Elit Global** (simulasi sumber daya, modal Rp500 ribu). Bahasa komunikasi: **Indonesia**.

- `web/` = versi yang dikembangkan aktif (Three.js + Vite). Logika simulasi di `web/src/sim.js`.
- Godot (`scripts/`, `project.godot`) = prototipe awal; jangan ubah kecuali diminta.
- **Jangan memakai generator gambar AI.** Aset dibuat dari kode/Three.js atau berlisensi CC0 (lihat CREDITS.md).
- Setelah mengubah kode web: `cd web && npm ci && npm run build && npm run test:e2e` harus lulus.
- Buat perubahan lewat pull request, bukan langsung ke `main`.
- Rencana kerja ada di `ROADMAP.md`; konsep di `KONSEP_GAME.md`.
