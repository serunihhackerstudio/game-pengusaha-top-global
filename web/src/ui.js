// HUD dan panel keputusan (DOM). Logika ada di sim.js. (Port dari ui.gd)
import * as sim from './sim.js';
import {S, K, Phase, PHASE_NAMES, POOL_NAMES, data} from './sim.js';
import {clock, rp} from './fmt.js';

const root = document.getElementById('ui');

function h(tag, props = {}, ...kids) {
	const e = document.createElement(tag);
	for (const [k, v] of Object.entries(props)) {
		if (k === 'class') e.className = v;
		else if (k === 'text') e.textContent = v;
		else if (k.startsWith('on')) e.addEventListener(k.slice(2), v);
		else if (k === 'style') Object.assign(e.style, v);
		else if (v === true) e.setAttribute(k, '');
		else if (v !== false && v != null) e.setAttribute(k, v);
	}
	for (const c of kids.flat()) if (c != null) e.append(c.nodeType ? c : document.createTextNode(String(c)));
	return e;
}
const btn = (text, onclick, cls = '') => h('button', {class: `btn ${cls}`, text, onclick});

export const ui = {
	modalOpen: false,
	handlers: {},
	sellRunning: false,
	sellPaused: false,
	sellSpeed: 1,
	_acc: 0,
	_toastT: 0,
	_marketSup: 'bejo',
};

// ---------- HUD ----------
const el = {};
function buildHud() {
	el.day = h('span', {class: 'day'});
	el.phase = h('span');
	el.clock = h('span');
	el.weather = h('span');
	el.bar = h('i');
	el.worth = h('span', {class: 'worth'});
	const top = h('div', {class: 'panel hud-top'}, el.day, el.phase, el.clock, el.weather, h('span', {class: 'grow'}),
		h('span', {class: 'opt dim', text: 'Tenaga '}), h('span', {class: 'bar'}, el.bar), el.worth);
	el.pools = {};
	const pools = h('div', {class: 'panel pools'}, h('h4', {text: 'KANTONG UANG'}));
	for (const k of Object.keys(POOL_NAMES)) {
		el.pools[k] = h('div');
		pools.append(el.pools[k]);
	}
	el.stock = h('small');
	pools.append(h('hr'), el.stock);
	el.obj = h('div', {class: 'panel objective'});
	el.prompt = h('button', {class: 'btn accent prompt', style: {display: 'none'}, onclick: () => ui.handlers.interact && ui.handlers.interact()});
	el.skip = h('button', {class: 'btn skip', text: 'Lanjut ke fase berikut  >', style: {display: 'none'}, onclick: () => {
		if (S.phase === Phase.BELANJA) sim.advancePhase();
	}});
	el.toast = h('div', {class: 'toast', style: {display: 'none'}});
	root.append(top, pools, el.obj, el.prompt, el.skip, el.toast);
}

function phaseHour() {
	switch (S.phase) {
		case Phase.PAGI: return 7;
		case Phase.BELANJA: return 8.5;
		case Phase.PERSIAPAN: return 9.5;
		case Phase.JUALAN: return S.sell && S.sell.hour ? S.sell.hour : K.OPEN;
		default: return 21.5;
	}
}

const HINTS = [
	'Pagi. Pergi ke rumah kos (cincin hijau) untuk membuat rencana hari ini.',
	'Pergi ke pasar (sisi kanan) untuk membeli bahan. Tekan Lanjut jika tidak perlu belanja.',
	'Pergi ke gerobakmu untuk bersiap sebelum berangkat.',
	'Dorong gerobak ke salah satu titik jualan (cincin hijau): SD, Kantor, atau Pangkalan Ojol.',
	'Jualan selesai. Kembali ke rumah kos untuk mencatat dan membagi uang.',
];

export function refresh() {
	el.day.textContent = `Hari ${S.day}`;
	el.phase.textContent = PHASE_NAMES[S.phase];
	const hr = phaseHour();
	el.clock.textContent = clock(hr);
	el.weather.textContent = {cerah: 'Cerah', mendung: 'Mendung', hujan: 'Hujan'}[S.weather];
	el.bar.style.width = `${S.stamina}%`;
	el.worth.textContent = `Aset ${rp(sim.netWorth())} / ${rp(K.GOAL)}`;
	for (const k of Object.keys(POOL_NAMES)) el.pools[k].textContent = `${POOL_NAMES[k]}  ${rp(S.pools[k])}`;
	el.stock.textContent = S.setupDone ? 'Stok: ' + data.ingredients.map((i) => `${i.name} ${S.stock[i.id]}`).join(', ') : '';
	el.skip.style.display = S.setupDone && S.phase === Phase.BELANJA && !ui.modalOpen ? '' : 'none';
	if (!S.setupDone) el.obj.textContent = 'Belanja modal awal dulu.';
	else if (S.phase === Phase.JUALAN && S.sell && S.sell.hour) el.obj.textContent = 'Sedang berjualan. Atur harga kalau perlu; tutup lapak saat sudah malam.';
	else el.obj.textContent = HINTS[S.phase];
	ui.handlers.onTime && ui.handlers.onTime(hr);
}

export function toast(msg) {
	el.toast.textContent = msg;
	el.toast.style.display = '';
	ui._toastT = 4.5;
}

export function setPrompt(text) {
	if (!text || ui.modalOpen) el.prompt.style.display = 'none';
	else {
		el.prompt.textContent = text;
		el.prompt.style.display = '';
	}
}

// ---------- modal ----------
let modalEl = null;
function openModal(title, width = 700, side = false) {
	closeModal();
	const body = h('div', {class: 'panel', style: {'--w': `${width}px`}}, h('h2', {text: title}));
	modalEl = h('div', {class: `modal ${side ? 'side' : ''}`}, body);
	root.append(modalEl);
	ui.modalOpen = true;
	setPrompt('');
	return body;
}
export function closeModal() {
	if (modalEl) modalEl.remove();
	modalEl = null;
	ui.modalOpen = false;
	ui.sellRunning = false;
	refresh();
}

function priceRow(parent, caption) {
	const lbl = h('b', {class: 'gold', text: rp(S.price)});
	const chg = (d) => {
		S.price = Math.min(25000, Math.max(6500, S.price + d));
		lbl.textContent = rp(S.price);
	};
	parent.append(h('div', {class: 'row'}, h('span', {text: caption}), btn('-500', () => chg(-500), 'sm'), lbl, btn('+500', () => chg(500), 'sm')));
}

const nextPhase = () => {
	closeModal();
	sim.advancePhase();
};

// ---------- modal awal ----------
export function openSetup() {
	const b = openModal('Modal Awal: Rp500.000', 780);
	b.append(h('p', {class: 'dim', text: 'Uang warisan orang tuamu cuma Rp500.000. Belanja perlengkapan dulu; sisanya jadi modal kerja dan biaya hidup. Tidak semua bisa dibeli, pilih yang paling penting.'}));
	const selects = {};
	for (const e of data.equipment) {
		const sel = h('select');
		e.options.forEach((o) => sel.append(h('option', {value: o.id, text: `${o.label}  (${o.buy > 0 ? rp(o.buy) : 'gratis'})`})));
		sel.addEventListener('change', refreshSetup);
		selects[e.id] = sel;
		b.append(h('div', {class: 'row'}, h('label', {text: e.name}), sel));
	}
	const desc = h('div', {class: 'dim', style: {fontSize: '.88em'}});
	const summary = h('p', {class: 'gold'});
	const sm = h('input', {type: 'range', min: 0, max: 500000, step: 5000, value: 150000});
	const sh = h('input', {type: 'range', min: 0, max: 500000, step: 5000, value: 90000});
	const lm = h('label');
	const lh = h('label');
	const ld = h('p');
	const go = btn('Mulai Hari 1', () => {
		const sel = selection();
		const left = K.START_CASH - sim.setupCost(sel);
		const m = +sm.value;
		const hd = +sh.value;
		if (sim.finishSetup(sel, m, hd, Math.max(left - m - hd, 0))) {
			closeModal();
			ui.handlers.setupFinished && ui.handlers.setupFinished();
			toast('Hari 1 dimulai. Semoga untung!');
		}
	}, 'accent');
	b.append(desc, summary, h('div', {class: 'row'}, lm, sm), h('div', {class: 'row'}, lh, sh), ld, go);
	const selection = () => Object.fromEntries(Object.entries(selects).map(([k, s]) => [k, s.value]));
	function refreshSetup() {
		const hpOk = selects.hp.value === 'bekas';
		for (const o of selects.catat.options) if (o.value === 'aplikasi') o.disabled = !hpOk;
		if (!hpOk && selects.catat.value === 'aplikasi') selects.catat.value = 'buku';
		const sel = selection();
		const cost = sim.setupCost(sel);
		const left = K.START_CASH - cost;
		desc.innerHTML = data.equipment.map((e) => `- ${e.name}: ${sim.equipmentOption(e.id, sel[e.id]).desc || ''}`).join('<br>');
		summary.textContent = `Belanja perlengkapan ${rp(cost)}   |   Sisa uang ${rp(left)}`;
		summary.className = left < 0 ? 'bad' : 'gold';
		const avail = Math.max(left, 0);
		sm.max = sh.max = avail;
		if (+sm.value > avail) sm.value = avail;
		if (+sm.value + +sh.value > avail) sh.value = Math.max(0, avail - +sm.value);
		lm.textContent = `Modal kerja (belanja bahan)  ${rp(+sm.value)}`;
		lh.textContent = `Biaya hidup (makan, kos)  ${rp(+sh.value)}`;
		ld.textContent = `Sisanya ke Dana Darurat  ${rp(Math.max(avail - +sm.value - +sh.value, 0))}`;
		go.disabled = left < 0 || +sm.value < 30000;
	}
	sm.addEventListener('input', refreshSetup);
	sh.addEventListener('input', refreshSetup);
	refreshSetup();
}

// ---------- rencana pagi ----------
export function openPlan() {
	const b = openModal(`Rencana Pagi - Hari ${S.day}`, 700);
	const w = {cerah: 'Cerah. Pembeli normal.', mendung: 'Mendung. Pembeli sedikit berkurang.', hujan: 'Hujan. Pembeli jauh berkurang; pertimbangkan beli bahan lebih sedikit.'};
	b.append(h('p', {text: 'Prakiraan hari ini: ' + w[S.weather]}), h('p', {class: 'dim', text: `Tenaga ${Math.round(S.stamina)}/100   |   Modal kerja ${rp(S.pools.modal)}`}));
	if (S.journal.length) {
		const j = S.journal[S.journal.length - 1];
		b.append(h('p', {class: 'dim', text: `Kemarin: terjual ${j.served} porsi, ${j.lost} pelanggan pergi, laba ${rp(j.profit)}.`}));
	} else b.append(h('p', {class: 'dim', text: 'Ini hari pertamamu. Tip: beli bahan secukupnya; bahan segar cepat busuk.'}));
	priceRow(b, 'Harga mie goreng per porsi');
	b.append(h('p', {class: 'dim', text: 'HPP kira-kira Rp6.500 per porsi. Terlalu murah rugi, terlalu mahal sepi.'}), btn('Berangkat ke pasar', nextPhase, 'accent'));
}

// ---------- pasar ----------
export function openMarket() {
	const b = openModal('Pasar', 780);
	const info = h('p', {class: 'gold'});
	const sup = h('div', {class: 'row'});
	const rows = h('div');
	const msg = h('p', {class: 'bad'});
	const rebuild = () => {
		sup.replaceChildren(h('span', {text: 'Beli dari:'}), ...data.suppliers.map((s) => btn(`${s.name} (${s.desc})`, () => {
			ui._marketSup = s.id;
			rebuild();
		}, ui._marketSup === s.id ? 'accent' : '')));
		info.textContent = `Modal kerja: ${rp(S.pools.modal)}   |   Gerobak muat maks. ${sim.dailyCapacity()} porsi`;
		rows.replaceChildren(...data.ingredients.map((ing) => h('div', {class: 'row'},
			h('label', {text: ing.name, style: {minWidth: '150px'}}), h('span', {class: 'dim', text: `stok ${S.stock[ing.id]}`, style: {minWidth: '70px'}}),
			h('span', {class: 'gold', text: `${rp(sim.unitPrice(ing.id, ui._marketSup))}/unit`, style: {minWidth: '110px'}}),
			...[1, 5, 10].map((q) => btn(`+${q}`, () => {
				if (sim.buyIngredient(ing.id, q, ui._marketSup)) msg.textContent = '';
				else if (S.stock[ing.id] + q > sim.dailyCapacity()) msg.textContent = `Gerobakmu tidak muat lebih dari ${sim.dailyCapacity()} porsi.`;
				else msg.textContent = 'Modal kerja tidak cukup.';
				rebuild();
			}, 'sm')))));
	};
	b.append(info, sup, rows, msg, h('p', {class: 'dim', style: {fontSize: '.85em'}, text: 'Satu porsi = 1 mie + 1 telur + 1 bumbu + 1 sayur + 1 kemasan. Stok porsi ditentukan bahan yang paling sedikit.'}), btn('Selesai belanja', nextPhase, 'accent'));
	rebuild();
}

// ---------- persiapan ----------
export function openPrep() {
	const b = openModal('Persiapan di Gerobak', 700);
	const sv = sim.servable();
	b.append(h('p', {class: sv > 0 ? 'gold' : 'bad', style: {fontSize: '1.3em'}, text: `Porsi siap dimasak: ${sv}`}));
	if (sv <= 0) b.append(h('p', {class: 'bad', text: 'Kamu belum punya bahan lengkap. Tanpa bahan, tidak ada yang bisa dijual hari ini.'}));
	b.append(h('p', {class: 'dim', text: `Gerobak muat ${sim.dailyCapacity()} porsi. Kompor: ${sim.chosen('kompor').label}. Wajan: ${sim.chosen('wajan').label}.`}),
		h('p', {class: 'dim', text: `Mutu bahan: ${Math.round(S.quality * 100)}%. Harga jual: ${rp(S.price)}.`}),
		sim.qrisAvailable() ? h('p', {class: 'good', text: `QRIS siap (${sim.chosen('hp').label}).`}) : h('p', {class: 'bad', text: 'Tanpa QRIS: pembeli yang mau bayar non-tunai akan pergi.'}),
		btn('Berangkat: dorong gerobak ke titik jualan', nextPhase, 'accent'));
}

// ---------- pilih titik ----------
export function openSpot(sid) {
	const sp = sim.spot(sid);
	const b = openModal(sp.name, 700);
	let chart = '';
	for (let hh = 10; hh <= 20; hh++) chart += `${String(hh).padStart(2, '0')}.00  ${'#'.repeat(Math.min(9, Math.round((sp.profile[hh] || 0) / 4)))}\n`;
	b.append(h('p', {text: sp.desc}), h('pre', {class: 'chart', text: chart.trim()}),
		h('div', {class: 'row'}, btn('Parkir di sini & buka lapak', () => {
			closeModal();
			ui.handlers.parked && ui.handlers.parked(sid);
		}, 'accent'), btn('Pilih tempat lain', closeModal)));
}

// ---------- jualan langsung (panel samping) ----------
export function openSell() {
	const b = openModal(`Berjualan - ${sim.spot(S.spotId).name}`, 470, true);
	const L = {};
	const grid = h('div', {class: 'grid2'});
	for (const k of ['jam', 'antre', 'terlayani', 'hilang', 'kas', 'qris', 'stok', 'tenaga']) {
		L[k] = h('span');
		grid.append(L[k]);
	}
	const log = h('div', {class: 'log'});
	const done = btn('Selesai berjualan', () => finishSell(false), 'accent');
	done.style.display = 'none';
	b.append(grid);
	priceRow(b, 'Harga');
	b.append(h('div', {class: 'row'}, h('span', {text: 'Kecepatan'}), btn('Jeda', () => (ui.sellPaused = !ui.sellPaused), 'sm'),
		...[1, 3, 8].map((s) => btn(`x${s}`, () => (ui.sellSpeed = s), 'sm'))), log,
		h('div', {class: 'row'}, btn('Tutup lapak lebih awal', () => finishSell(true)), done));
	ui._sell = {L, log, done, lines: []};
	ui.sellRunning = true;
	ui.sellPaused = false;
	ui.sellSpeed = 1;
	ui._acc = 0;
	updateSell();
}

function updateSell() {
	const s = S.sell;
	const {L} = ui._sell;
	L.jam.textContent = `Jam ${clock(s.hour)}`;
	L.antre.textContent = `Antrean ${s.queue}`;
	L.terlayani.textContent = `Terlayani ${s.served} porsi`;
	L.hilang.textContent = `Pelanggan pergi ${s.lost}`;
	L.kas.textContent = `Kas tunai ${rp(s.cash)}`;
	L.qris.textContent = !sim.qrisAvailable() ? 'QRIS: tidak ada' : s.batteryDead ? 'QRIS mati (baterai habis)' : `QRIS ${rp(s.qris)}`;
	L.stok.textContent = `Stok ${sim.servable()} porsi`;
	L.tenaga.textContent = `Tenaga ${Math.round(S.stamina)}`;
}

function sellStep() {
	const res = sim.tickSell();
	if (res.served > 0 && ui.handlers.customerServed) ui.handlers.customerServed(res.served);
	const {log, done, lines} = ui._sell;
	let line = '';
	if (res.habis) line = 'Bahan habis! Pelanggan pulang.';
	else if (res.arrived > 0) line = `${clock(S.sell.hour)}: ${res.arrived} datang, ${res.served} dilayani${res.lost > 0 ? `, ${res.lost} pergi` : ''}`;
	if (line) {
		lines.push(line);
		if (lines.length > 4) lines.shift();
		log.textContent = lines.join('\n');
		log.style.whiteSpace = 'pre-line';
	}
	updateSell();
	ui.handlers.onTime && ui.handlers.onTime(S.sell.hour);
	if (S.sell.done) {
		ui.sellRunning = false;
		done.style.display = '';
		lines.push('Sudah malam. Waktunya tutup.');
		log.textContent = lines.join('\n');
	}
}

function finishSell(early) {
	if (early) S.sell.done = true;
	ui.sellRunning = false;
	closeModal();
	sim.endSelling();
}

// ---------- tutup & catat ----------
export function openClose() {
	const t = S.today;
	const b = openModal(`Tutup & Catat - Hari ${S.day}`, 760);
	const lines = [
		['Terjual', `${t.served} porsi (${t.lost} pelanggan pergi)`], ['Omzet', rp(t.revenue)], ['Harga pokok bahan', '-' + rp(t.cogs)],
		['Sewa gerobak', '-' + rp(t.rent)], ['Gas', '-' + rp(t.gas)], ['Bahan busuk', '-' + rp(t.spoil)],
	];
	const g = h('div', {class: 'grid2'});
	for (const [k, v] of lines) g.append(h('span', {class: 'dim', text: k}), h('span', {text: v}));
	g.append(h('b', {class: 'gold', text: 'LABA HARI INI'}), h('b', {class: t.profit >= 0 ? 'good' : 'bad', style: {fontSize: '1.2em'}, text: rp(t.profit)}));
	b.append(g);
	const cat = S.owned.catat;
	if (cat === 'tidak') b.append(h('p', {class: 'bad', text: `Kamu tidak mencatat. Catatan ngawur: tercatat ${rp(t.recorded)}.`}));
	else if (t.gap !== 0) b.append(h('p', {class: 'dim', text: `Catatan bukumu meleset: tercatat ${rp(t.recorded)}, sebenarnya ${rp(t.revenue)} (selisih ${rp(Math.abs(t.gap))}). Aplikasi akan lebih akurat.`}));
	else b.append(h('p', {class: 'good', text: 'Catatan cocok dengan kas. Rapi.'}));
	b.append(h('hr'));
	const alloc = t.alloc;
	const finish = (split) => {
		closeModal();
		sim.confirmClose(split);
		ui.handlers.dayStarted && ui.handlers.dayStarted();
	};
	if (alloc <= 0) {
		b.append(h('p', {class: 'bad', text: `Kas hari ini tidak cukup untuk dibagi. Kekurangan ${rp(Math.abs(alloc))} diambil dari Modal Kerja.`}),
			btn('Tidur & mulai hari berikutnya', () => finish({modal: 0, hidup: 0, darurat: 0, ekspansi: 0}), 'accent'));
		return;
	}
	b.append(h('p', {class: 'gold', text: `Bagi uang ${rp(alloc)} ke empat kantong:`}));
	const order = ['modal', 'hidup', 'darurat'];
	const sug = sim.suggestSplit(alloc);
	const sl = {};
	const lb = {};
	const eks = h('p', {class: 'good'});
	const upd = () => {
		let used = order.reduce((a, k) => a + +sl[k].value, 0);
		if (used > alloc) {
			const last = sl[order[order.length - 1]];
			last.value = Math.max(0, +last.value - (used - alloc));
			used = order.reduce((a, k) => a + +sl[k].value, 0);
		}
		for (const k of order) lb[k].textContent = `${POOL_NAMES[k]}  ${rp(+sl[k].value)}`;
		eks.textContent = `${POOL_NAMES.ekspansi}  ${rp(alloc - used)}`;
	};
	for (const k of order) {
		lb[k] = h('label', {style: {minWidth: '260px'}});
		sl[k] = h('input', {type: 'range', min: 0, max: alloc, step: 1000, value: sug[k]});
		sl[k].addEventListener('input', upd);
		b.append(h('div', {class: 'row'}, lb[k], sl[k]));
	}
	b.append(eks, h('div', {class: 'row'}, btn('Saran otomatis', () => {
		for (const k of order) sl[k].value = sug[k];
		upd();
	}), btn('Tidur & mulai hari berikutnya', () => {
		const split = {};
		let used = 0;
		for (const k of order) {
			split[k] = +sl[k].value;
			used += split[k];
		}
		split.ekspansi = alloc - used;
		finish(split);
	}, 'accent')));
	upd();
}

// ---------- siklus ----------
ui.update = (dt) => {
	if (ui._toastT > 0) {
		ui._toastT -= dt;
		if (ui._toastT <= 0) el.toast.style.display = 'none';
	}
	if (ui.sellRunning && !ui.sellPaused) {
		ui._acc += dt * ui.sellSpeed;
		while (ui._acc >= 0.32 && ui.sellRunning) {
			ui._acc -= 0.32;
			sellStep();
		}
	}
};

export function initUI() {
	buildHud();
	sim.on('changed', refresh);
	sim.on('toast', toast);
	refresh();
}

Object.assign(ui, {openSetup, openPlan, openMarket, openPrep, openSpot, openSell, openClose, closeModal, setPrompt, toast, refresh});
