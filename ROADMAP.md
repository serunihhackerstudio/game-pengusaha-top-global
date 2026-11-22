# ROADMAP — Pengusaha Elit Global

Peta jalan dari prototipe sekarang sampai rilis 1.0 (HP dan PC) dan pembaruan sesudahnya.
Semua durasi adalah **perkiraan kasar untuk pembuat tunggal dengan bantuan AI koding**; geser bila tim bertambah. Anggaplah sebagai urutan prioritas, bukan janji tanggal.

## Posisi sekarang (Fase 0, selesai)
- Konsep terkunci: simulasi sumber daya, per fase, kendali karakter langsung, Godot 4, fotorealistis dimulai dari satu lokasi.
- Prototipe jalan: dilema Rp500 ribu, satu hari lima fase, jualan langsung, tutup buku, empat kantong uang.
- Lingkungan bertekstur PBR dan langit HDRI foto-nyata (CC0). Karakter dan benda masih sederhana.
- **Belum ada:** simpan, hari kedua yang matang, kontrol sentuh, suara, tutorial, model detail, uji main.

## Ringkasan jalur

| Fase | Nama | Perkiraan | Hasil akhir fase |
|---|---|---|---|
| 1 | Fondasi & kualitas inti | 4–6 minggu | Bisa dimainkan berhari-hari dengan nyaman di PC dan HP |
| 2 | Vertical slice fotorealistis | 8–12 minggu | Satu lokasi dengan seni akhir dan animasi |
| 3 | Kedalaman sistem Bab 1–3 | 8–10 minggu | Seluruh mekanik Bab 1–3 |
| 4 | Cerita & karakter | 4–6 minggu | Dialog, misi, tokoh pendukung |
| 5 | Alpha → Beta | 8–10 minggu | Konten lengkap, seimbang, stabil |
| 6 | Rilis 1.0 | 3–4 minggu | PC dan Android dirilis |
| 7+ | Pasca rilis | berkelanjutan | Bab 4–10, mode tambahan |

**Total sampai rilis 1.0: sekitar 35–48 minggu (8–11 bulan).** Fase 2 dan 3 bisa berjalan tumpang tindih sebagian karena seni dan sistem terpisah.

---

## Fase 1 — Fondasi & kualitas inti (4–6 minggu)
Tujuan: game yang sudah ada menjadi **nyaman dimainkan lama**, sebelum menambah isi.

- **Simpan/muat** otomatis tiap akhir hari + beberapa slot.
- **Hari kedua dan seterusnya** matang: laporan harian, tren, jurnal riwayat, kondisi kritis (modal habis, sakit) dan jalur pemulihan.
- **Tutorial bertahap** hari 1–3 (tanpa dinding teks).
- **Kontrol HP:** ketuk-untuk-jalan, joystick virtual, tombol interaksi besar, UI skala layar, mode potret/lanskap.
- **Kontrol PC:** pengaturan tombol, resolusi, kualitas grafis.
- **Menu:** judul, jeda, pengaturan, keluar.
- **Audio dasar:** ambience jalan/pasar, suara wajan, koin, notifikasi QRIS, musik latar.
- **Balancing awal:** uji main 10+ hari, setel harga, permintaan, biaya hidup, kapasitas.
- **Pengujian otomatis** untuk simulasi (lanjutan skrip uji ekonomi) agar perubahan angka aman.

**Selesai bila:** orang baru bisa memulai, memainkan 10 hari, menutup game, dan melanjutkan lagi di HP maupun PC tanpa bantuan; ekonomi terasa menantang tapi adil.

## Fase 2 — Vertical slice fotorealistis (8–12 minggu)
Tujuan: satu lokasi ("Gang Mawar") dengan **kualitas seni akhir** sebagai standar untuk seluruh game.

- **Pipeline aset 3D tanpa AI gambar:** model dibuat di Blender dan/atau Three.js → ekspor `.glb` → impor Godot; tekstur CC0 (Poly Haven, ambientCG) dan tekstur buatan sendiri.
- **Karakter:** pemain (bisa dipilih), Pak Darmo, Adrian, ±10 variasi pelanggan; pakaian khas (jaket ojol, sarung, peci, hijab, seragam sekolah).
- **Animasi:** jalan, berdiri, memasak, melayani, membayar (tunai/QRIS), mendorong gerobak.
- **Benda khas Indonesia:** gerobak, wajan dan kompor, angkot, ojol, ruko, warung, pasar, kabel listrik, spanduk, motor.
- **Pencahayaan:** siang-malam penuh, hujan dan genangan, mendung, lampu jalan, lampu gerobak.
- **Optimasi:** anggaran poligon dan tekstur, LOD, bayangan terpanggang, profil di HP kelas menengah dan bawah.
- **UI akhir:** panel kayu dan kertas bertekstur, ikon produk 3D, font final.

**Selesai bila:** tangkapan layar dan klip satu hari terlihat layak sebagai materi rilis; berjalan ≥30 fps di HP menengah dan ≥60 fps di PC.

**Risiko terbesar fase ini:** jumlah aset detail. Mitigasi: tetapkan anggaran (mis. ≤150 model), prioritaskan yang selalu terlihat dekat, gunakan ulang tekstur.

## Fase 3 — Kedalaman sistem Bab 1–3 (8–10 minggu)
Tujuan: mekanik yang membuat tiap hari terasa berbeda dan berpikir.

- **Bab 2 (Lapak tetap):** sewa lapak, pelanggan tetap, menu bertambah, dua produk atau lebih.
- **Bab 3 (Warung mie):** tempat usaha, 1–3 karyawan (sifat, gaji, pelatihan), jam operasional, NIB.
- **Supplier:** hubungan jangka panjang, kredit, harga berfluktuasi (Lebaran, cuaca).
- **Reputasi tiga sumbu:** Kualitas, Etika, Koneksi, yang memengaruhi harga dan peluang.
- **Event dilema:** target 30+ (suap, bahan murah kurang higienis, komplain, razia, tawaran investor).
- **Keuangan:** tabungan, KUR, bank, jebakan pinjol ilegal; laporan laba rugi dan titik impas.
- **Keahlian:** akuntansi, pemasaran, operasional, negosiasi, kepemimpinan.
- **Kompetitor:** pedagang lain berbasis AI sederhana.
- **Digital:** QRIS lanjutan, marketplace makanan, media sosial.

**Selesai bila:** Bab 1–3 bisa dimainkan 20–30 jam tanpa terasa berulang; setiap bab membuka mekanik baru tanpa membuang yang lama.

## Fase 4 — Cerita & karakter (4–6 minggu)
Porsi cerita sengaja kecil (simulasi dominan): bumbu, bukan inti.

- Dialog Pak Darmo (mentor), Adrian (rival), Kang Ohan, Bu Sari, supplier, penagih.
- Misi pendek per bab dan momen penting (pembuka, naik bab, krisis).
- Potret karakter dan adegan singkat; akhir sementara Bab 3.

**Selesai bila:** setiap bab punya tujuan naratif jelas dan minimal satu momen berkesan.

## Fase 5 — Alpha → Beta (8–10 minggu)
- **Alpha:** semua konten Bab 1–3 masuk; bug besar dibereskan; ekonomi seimbang.
- **Beta tertutup:** 15–30 penguji; kumpulkan data (hari berapa berhenti, di mana frustrasi); setel ulang kesulitan.
- **Kualitas:** uji HP kelas bawah, daya tahan baterai, penggunaan memori; aksesibilitas (ukuran teks, kontras, warna).
- **Lokalisasi:** Inggris menyusul Indonesia.
- **Angka regulasi** (biaya QRIS, pajak UMKM, izin) **diverifikasi** sebelum dipublikasikan.

**Selesai bila:** penguji baru menyelesaikan Bab 1 dengan lancar; tidak ada bug penghenti; performa memenuhi target.

## Fase 6 — Rilis 1.0 (3–4 minggu)
- **PC:** Steam (beli putus). **Android:** Google Play (gratis dengan iklan opsional atau versi berbayar).
- Halaman toko, tangkapan layar, **trailer (dibuat dengan Remotion + Three.js)**, kebijakan privasi, peringkat usia.
- Analitik opsional, pelaporan kerusakan, tambalan hari pertama.

**Selesai bila:** terbit di kedua platform; rencana tambalan 2 minggu pertama siap.

## Fase 7+ — Pasca rilis
Urutan usulan (tiap langkah ±6–8 minggu):
1. Bab 4–5: cabang dan merek regional, produk kemasan (PIRT, halal, BPOM).
2. Bab 6–7: pabrik, distribusi, perusahaan terbuka.
3. Mode **Tantangan Harian** dan papan peringkat.
4. Bab 8–10: konglomerat, ekspansi dunia, elit global; tiga akhir cerita.
5. Mode **Legacy** (penerus) dan Sandbox.

---

## Jalur kritis dan ketergantungan
1. **Simpan/muat dan kontrol HP** (Fase 1) harus ada sebelum beta.
2. **Pipeline aset dan kualitas seni** (Fase 2) menentukan seluruh biaya seni sesudahnya; tetapkan standar dulu.
3. **Balancing** berulang di Fase 1, 3, dan 5; jangan menunda ke akhir.
4. Fase 3 bisa mulai saat Fase 2 berjalan, karena logika di `sim.gd` terpisah dari tampilan.

## Risiko utama

| Risiko | Dampak | Mitigasi |
|---|---|---|
| Fotorealistis butuh aset sangat banyak | Jadwal molor | Anggaran model, gaya semi-realistis sebagai cadangan, mulai satu lokasi |
| Larangan AI gambar menambah kerja aset | Seni lebih lama | Pustaka CC0 + Blender/Three.js, pakai ulang tekstur |
| HP kelas bawah tersendat | Pemain hilang | Anggaran performa sejak awal, opsi kualitas, uji berkala |
| Ekonomi tidak seimbang | Frustrasi atau bosan | Data-driven, uji otomatis, beta |
| Cakupan membengkak | Tidak rilis | Disiplin: rilis 1.0 hanya Bab 1–3 |
| Terlalu rumit buat pemain awam | Retensi rendah | Tutorial bertahap, mode Santai, ringkasan harian jelas |
| Data regulasi tidak akurat | Reputasi buruk | Verifikasi dan beri catatan |

## Dua minggu ke depan (usulan sprint 1)
1. Simpan/muat otomatis + slot.
2. Hari 2–5 dimainkan penuh tanpa galat; uji ulang ekonomi dengan skrip.
3. Kontrol sentuh HP (joystick virtual + tombol interaksi besar) dan skala UI.
4. Tutorial hari 1–2.
5. Audio dasar (ambience + efek).
6. Keputusan anggaran aset (jumlah model, standar poligon) dan contoh satu karakter detail di Blender sebagai uji pipeline.

## Keputusan yang masih terbuka
- Pembuat model: sendiri di Blender, aset berlisensi, atau gabungan?
- Monetisasi HP: gratis beriklan atau berbayar?
- Seberapa realistis karakter (semi-realistis atau mendekati foto)?
