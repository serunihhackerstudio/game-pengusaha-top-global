# Pengusaha Elit Global

Simulasi manajemen sumber daya 3D isometrik: dari warisan Rp500.000 dan satu gerobak mie goreng sampai elit global.
Konsep lengkap: [KONSEP_GAME.md](KONSEP_GAME.md).

## Menjalankan
1. Pasang **Godot 4.x** (sudah terpasang lewat winget di komputer ini).
2. Impor aset sekali: `godot --headless --path . --import`
3. Buka `project.godot` di Godot lalu tekan **F5**.

**Kontrol:** WASD / panah atau klik di tanah untuk berjalan. **E** atau tombol oranye di bawah layar untuk berinteraksi.

## Versi web (dimainkan di browser)
Folder `web/` berisi port Three.js + Vite dari game ini (logika sama dengan `scripts/sim.gd`, tampilan dan kontrol ulang).

```
cd web
npm install
npm run dev        # server pengembangan
npm run build      # hasil di web/dist
node test/play-day.mjs   # uji end-to-end satu hari di Chrome (setelah build)
```
Kontrol: WASD/panah atau klik untuk berjalan, **E** untuk berinteraksi; di HP ada joystick virtual dan ketuk-untuk-jalan.

### Pratinjau di Vercel
`web/vercel.json` sudah disiapkan. Di Vercel: **Add New > Project > impor repo GitHub**, lalu atur **Root Directory = `web`** (Framework: Vite, otomatis terdeteksi). Setiap push dan pull request akan mendapat URL pratinjau sendiri.

## Cara bermain (vertical slice "Gang Mawar")
1. **Modal awal:** pilih perlengkapan dengan Rp500.000. Tidak semua bisa dibeli. Sisanya dibagi ke Modal Kerja dan Biaya Hidup.
2. **Satu hari = lima fase:** Rencana Pagi (rumah kos) → Belanja (pasar) → Persiapan (gerobak) → Berjualan (pilih titik: SD, Kantor, Pangkalan Ojol) → Tutup & Catat (rumah kos).
3. Bagi laba ke empat kantong: Modal Kerja, Biaya Hidup, Dana Darurat, Dana Ekspansi.
4. Target Bab 1: aset bersih Rp5.000.000.

## Struktur
```
project.godot
data/game.json        perlengkapan, bahan, supplier, titik jualan (angka balancing di sini)
scripts/sim.gd        autoload Sim: simulasi sumber daya, fase, ekonomi (tanpa UI)
scripts/world.gd      lokasi 3D + material PBR (tekstur Poly Haven CC0)
scripts/player.gd     karakter pemain (WASD / klik-untuk-jalan)
scripts/ui.gd         HUD dan panel keputusan
scripts/main.gd       lingkungan, kamera isometrik, interaksi, aliran game
assets/textures       tekstur PBR 1K (CC0)    assets/hdri  langit HDRI (CC0)
CREDITS.md            kredit aset
```

## Catatan
- Aset tanpa generator gambar AI. Tekstur dan HDRI dari Poly Haven (CC0).
- Karakter dan benda khas Indonesia masih berbentuk sederhana; model detail menyusul.
- Angka ekonomi masih awal dan belum diuji bermain lama.
