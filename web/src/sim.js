// Simulasi inti: sumber daya, fase hari, ekonomi. Tanpa UI. (Port dari sim.gd)
import data from './game.json';
import {rp} from './fmt.js';

export {data};
export const Phase = {PAGI: 0, BELANJA: 1, PERSIAPAN: 2, JUALAN: 3, TUTUP: 4};
export const PHASE_NAMES = ['Rencana Pagi', 'Belanja', 'Persiapan', 'Berjualan', 'Tutup & Catat'];
export const POOL_NAMES = {modal: 'Modal Kerja', hidup: 'Biaya Hidup', darurat: 'Dana Darurat', ekspansi: 'Dana Ekspansi'};
export const K = {
	START_CASH: 500000, LIVING: 25000, GAS: 8000, OPEN: 10, CLOSE: 21, TICK: 0.25,
	QRIS_SHARE: 0.35, QRIS_FEE: 0.007, GOAL: 5000000, DEMAND: 0.4,
};

export const S = {};
const L = {changed: [], toast: []};
export const on = (e, f) => L[e].push(f);
const emit = (e, ...a) => L[e].forEach((f) => f(...a));
export const changed = () => emit('changed');
export const toast = (m) => emit('toast', m);

const rand = Math.random;

export function newGame() {
	Object.assign(S, {
		day: 1, phase: Phase.PAGI, setupDone: false,
		pools: {modal: 0, hidup: 0, darurat: 0, ekspansi: 0},
		owned: {}, stock: {}, stockCost: {}, quality: 0.8, price: 12000, stamina: 100,
		weather: 'cerah', rep: {kualitas: 50, etika: 50, koneksi: 5}, journal: [],
		spotId: '', dayCash: 0, today: {}, sell: {}, bab1Done: false,
	});
	for (const i of data.ingredients) {
		S.stock[i.id] = 0;
		S.stockCost[i.id] = 0;
	}
	rollWeather();
	changed();
}

// ---------- data helper ----------
export const equipmentOption = (eid, oid) => {
	const e = data.equipment.find((x) => x.id === eid);
	return (e && e.options.find((o) => o.id === oid)) || {};
};
export const chosen = (eid) => equipmentOption(eid, S.owned[eid] || '');
export const ingredient = (id) => data.ingredients.find((i) => i.id === id);
export const supplier = (id) => data.suppliers.find((s) => s.id === id);
export const spot = (id) => data.spots.find((s) => s.id === id);

// ---------- modal awal ----------
export const setupCost = (sel) => Object.keys(sel).reduce((t, k) => t + (equipmentOption(k, sel[k]).buy || 0), 0);

export function finishSetup(sel, modal, hidup, darurat) {
	const left = K.START_CASH - setupCost(sel);
	if (left < 0 || modal < 0 || hidup < 0 || darurat < 0 || modal + hidup + darurat > left) return false;
	S.owned = {...sel};
	S.pools = {modal, hidup, darurat, ekspansi: left - modal - hidup - darurat};
	S.setupDone = true;
	changed();
	return true;
}

// ---------- belanja & stok ----------
export const unitPrice = (iid, sid) => Math.round((ingredient(iid).price * supplier(sid).price_mult) / 50) * 50;
export const totalUnits = () => Object.values(S.stock).reduce((a, b) => a + b, 0);
export const dailyCapacity = () => chosen('gerobak').cap || 0;

export function buyIngredient(iid, qty, sid) {
	const cost = unitPrice(iid, sid) * qty;
	if (qty <= 0 || S.pools.modal < cost) return false;
	if (S.stock[iid] + qty > dailyCapacity()) return false;
	const prev = totalUnits();
	S.quality = (S.quality * prev + supplier(sid).quality * qty) / (prev + qty);
	S.pools.modal -= cost;
	S.stock[iid] += qty;
	S.stockCost[iid] += cost;
	changed();
	return true;
}

export const servable = () => Math.min(...Object.values(S.stock));
export const stockValue = () => Object.values(S.stockCost).reduce((a, b) => a + b, 0);
export const avgUnitCost = (iid) => (S.stock[iid] > 0 ? S.stockCost[iid] / S.stock[iid] : 0);

export function netWorth() {
	let t = Object.values(S.pools).reduce((a, b) => a + b, 0) + stockValue() + S.dayCash;
	for (const eid of Object.keys(S.owned)) t += Math.floor((equipmentOption(eid, S.owned[eid]).buy || 0) * 0.5);
	return t;
}

// ---------- cuaca & fase ----------
export function rollWeather() {
	const r = rand();
	S.weather = r < 0.6 ? 'cerah' : r < 0.85 ? 'mendung' : 'hujan';
}
export const weatherFactor = () => ({cerah: 1.0, mendung: 0.85, hujan: 0.5}[S.weather]);

export function advancePhase() {
	if (S.phase < Phase.TUTUP) {
		S.phase += 1;
		changed();
	}
}

// ---------- berjualan ----------
export const qrisAvailable = () => (chosen('hp').reliab || 0) > 0;
export const qrisUsable = () => qrisAvailable() && !S.sell.batteryDead;

export function beginSelling(sid) {
	S.spotId = sid;
	S.sell = {hour: K.OPEN, queue: 0, served: 0, lost: 0, cash: 0, qris: 0, qrisFail: 0, tick: 0, svcAcc: 0, batteryDead: false, soldCost: 0, done: false, arrived: 0};
	changed();
}

function arrivalRate(hour) {
	const sp = spot(S.spotId);
	const perHour = sp.profile[String(Math.floor(hour))] || 0;
	const perTick = perHour * K.TICK * K.DEMAND;
	const pf = Math.min(2.2, Math.max(0.15, Math.pow(12000 / S.price, 1.6)));
	const qf = 0.65 + 0.7 * S.quality * (0.6 + (0.4 * S.rep.kualitas) / 100);
	const qr = qrisUsable() ? 1.12 : 1.0;
	const rf = 0.8 + (0.4 * S.rep.kualitas) / 100;
	return perTick * pf * qf * weatherFactor() * qr * rf;
}

function poisson(lambda) {
	if (lambda <= 0) return 0;
	const l = Math.exp(-lambda);
	let k = 0;
	let p = 1;
	do {
		k += 1;
		p *= rand();
	} while (p > l && k <= 60);
	return k - 1;
}

export function tickSell() {
	const res = {arrived: 0, served: 0, lost: 0, habis: false};
	const s = S.sell;
	if (s.done) return res;
	const arrive = poisson(arrivalRate(s.hour));
	res.arrived = arrive;
	s.arrived += arrive;
	s.queue += arrive;
	if (s.queue > 8) {
		const over = s.queue - 8;
		s.lost += over;
		res.lost += over;
		s.queue = 8;
	}
	const speed = chosen('kompor').speed || 0.7;
	const batch = chosen('wajan').batch || 1;
	s.svcAcc += 2.0 * speed * batch * (0.6 + (0.4 * S.stamina) / 100);
	const can = Math.floor(s.svcAcc);
	s.svcAcc -= can;
	for (let i = 0; i < can; i++) {
		if (s.queue <= 0) break;
		const r = serveOne();
		res.served += r.served;
		res.lost += r.lost;
		if (r.habis) res.habis = true;
	}
	if (s.queue > 5 && rand() < 0.3) {
		s.queue -= 1;
		s.lost += 1;
		res.lost += 1;
	}
	s.tick += 1;
	const limit = S.owned.powerbank === 'ada' || S.owned.hp === 'bekas' ? 44 : 28;
	if (s.tick >= limit && qrisAvailable()) s.batteryDead = true;
	S.stamina = Math.max(0, S.stamina - 0.4);
	s.hour += K.TICK;
	if (s.hour >= K.CLOSE) s.done = true;
	changed();
	return res;
}

function serveOne() {
	const r = {served: 0, lost: 0, habis: false};
	const s = S.sell;
	if (servable() <= 0) {
		r.lost = s.queue;
		r.habis = true;
		s.lost += s.queue;
		s.queue = 0;
		return r;
	}
	const wantsQris = rand() < K.QRIS_SHARE;
	let paidQris = false;
	if (wantsQris) {
		if (qrisUsable() && rand() < (chosen('hp').reliab || 0)) {
			paidQris = true;
		} else {
			s.qrisFail += 1;
			if (rand() < 0.5) {
				s.queue -= 1;
				s.lost += 1;
				r.lost = 1;
				return r;
			}
		}
	}
	let cost = 0;
	for (const k of Object.keys(S.stock)) {
		const avg = avgUnitCost(k);
		cost += avg;
		S.stockCost[k] -= Math.round(avg);
		S.stock[k] -= 1;
	}
	s.soldCost += cost;
	s.queue -= 1;
	s.served += 1;
	r.served = 1;
	if (paidQris) s.qris += Math.round(S.price * (1 - K.QRIS_FEE));
	else s.cash += S.price;
	return r;
}

export function endSelling() {
	const s = S.sell;
	const revenue = s.cash + s.qris;
	S.dayCash += revenue;
	S.today = {revenue, cogs: Math.round(s.soldCost), served: s.served, lost: s.lost, qrisFail: s.qrisFail, spot: S.spotId};
	S.stamina = Math.max(0, S.stamina - 12);
	if (s.served > 0) S.rep.kualitas = Math.min(100, Math.max(0, S.rep.kualitas + (S.quality - 0.7) * 6));
	if (s.lost > s.served && s.lost > 4) S.rep.kualitas = Math.max(0, S.rep.kualitas - 1.5);
	S.phase = Phase.TUTUP;
	prepareClose();
	changed();
}

function prepareClose() {
	const t = S.today;
	const rent = chosen('gerobak').daily || 0;
	const gas = t.served > 0 ? K.GAS : 0;
	let spoil = 0;
	for (const ing of data.ingredients) {
		const lostUnits = Math.floor(S.stock[ing.id] * ing.perish);
		spoil += Math.round(avgUnitCost(ing.id) * lostUnits);
	}
	const acc = chosen('catat').accuracy || 0.6;
	const err = (rand() * 2 - 1) * (1 - acc);
	const recorded = Math.round(t.revenue * (1 + err));
	Object.assign(t, {rent, gas, spoil, profit: t.revenue - t.cogs - rent - gas - spoil, alloc: t.revenue - rent - gas, recorded, gap: recorded - t.revenue});
}

/** Saran pembagian: isi modal kerja dulu, lalu biaya hidup, darurat, sisanya ekspansi. */
export function suggestSplit(amount) {
	let left = Math.max(amount, 0);
	const res = {modal: 0, hidup: 0, darurat: 0, ekspansi: 0};
	res.modal = Math.min(left, Math.max(0, 70000 - S.pools.modal));
	left -= res.modal;
	res.hidup = Math.min(left, Math.max(0, K.LIVING * 3 - S.pools.hidup));
	left -= res.hidup;
	res.darurat = Math.min(left, Math.floor(left * 0.4));
	left -= res.darurat;
	res.ekspansi = left;
	return res;
}

export function confirmClose(split) {
	const alloc = S.today.alloc;
	if (alloc >= 0) for (const k of Object.keys(split)) S.pools[k] += split[k];
	else S.pools.modal += alloc;
	for (const ing of data.ingredients) {
		const lostUnits = Math.floor(S.stock[ing.id] * ing.perish);
		const lostValue = Math.round(avgUnitCost(ing.id) * lostUnits);
		S.stock[ing.id] -= lostUnits;
		S.stockCost[ing.id] = Math.max(0, S.stockCost[ing.id] - lostValue);
	}
	S.journal.push({day: S.day, revenue: S.today.revenue, profit: S.today.profit, served: S.today.served, lost: S.today.lost, recorded: S.today.recorded});
	S.dayCash = 0;
	nextDay();
}

function nextDay() {
	S.day += 1;
	S.phase = Phase.PAGI;
	const paid = Math.min(S.pools.hidup, K.LIVING);
	S.pools.hidup -= paid;
	const short = K.LIVING - paid;
	S.stamina = Math.min(100, Math.max(10, S.stamina + 55 - (short / K.LIVING) * 45));
	if (short > 0) toast(`Biaya hidup kurang ${rp(short)}. Tenagamu turun.`);
	rollWeather();
	S.today = {};
	S.sell = {};
	S.spotId = '';
	if (!S.bab1Done && netWorth() >= K.GOAL) {
		S.bab1Done = true;
		toast(`Bab 1 selesai! Aset bersihmu sudah ${rp(netWorth())}.`);
	}
	changed();
}

newGame();
