// Lalu lintas dua lajur dan pejalan kaki; kepadatan mengikuti jam. (Port dari traffic.gd)
import * as THREE from 'three';
import {makeBus, makeCar, makeMotorbike, makeTruck, makeVan} from './world.js';
import {animatePerson, makePerson} from './people.js';

const X_MIN = -52;
const X_MAX = 52;
const MAX_VEHICLES = 16;
const MAX_PEDS = 14;
const LANES = [{z: 6.0, dir: 1}, {z: 10.6, dir: -1}];
const PED_ZS = [-2.6, -1.8, 2.9, 3.3];
const CAR_COLORS = [0xbf1a1a, 0xe6e6eb, 0x1f2433, 0x335999, 0x8c8c94, 0xd9b326];
const SHIRTS = [0xb34033, 0x3366a6, 0xd9a633, 0x4d8c59, 0x8c59a6, 0xe6e6e0, 0x33333f];
const pick = (a) => a[Math.floor(Math.random() * a.length)];
const rr = (a, b) => a + Math.random() * (b - a);

export class Traffic {
	constructor(scene) {
		this.scene = scene;
		this.hour = 7;
		this.enabled = true;
		this.vehicles = [];
		this.peds = [];
		this.vt = 0.5;
		this.pt = 0.5;
		for (let i = 0; i < 5; i++) this.spawnVehicle(rr(-40, 40));
		for (let i = 0; i < 6; i++) this.spawnPed(rr(-40, 40));
	}

	setHour(h) {
		this.hour = h;
	}

	intervalFactor() {
		const h = this.hour;
		if (h >= 19.5 || h < 5.5) return 2.8;
		if ((h >= 6.8 && h < 9) || (h >= 16.5 && h < 19)) return 0.6;
		if (h >= 12 && h < 13.5) return 0.8;
		return 1;
	}

	update(dt) {
		if (!this.enabled) return;
		this.vt -= dt;
		if (this.vt <= 0) {
			this.vt = rr(1.6, 3.4) * this.intervalFactor();
			if (this.vehicles.length < MAX_VEHICLES) this.spawnVehicle(null);
		}
		this.pt -= dt;
		if (this.pt <= 0) {
			const busy = (this.hour >= 11.5 && this.hour < 14) || (this.hour >= 16 && this.hour < 19);
			this.pt = rr(2, 5) * (busy ? 0.7 : 1) * (this.hour >= 20 ? 2 : 1);
			if (this.peds.length < MAX_PEDS) this.spawnPed(null);
		}
		this.updateVehicles(dt);
		this.updatePeds(dt);
	}

	buildVehicle() {
		const r = Math.random();
		if (r < 0.4) return {node: makeMotorbike(pick(CAR_COLORS), pick(SHIRTS)), base: rr(7.5, 10.5), len: 1.8};
		if (r < 0.68) return {node: makeCar(pick(CAR_COLORS)), base: rr(6, 8.5), len: 4.4};
		if (r < 0.8) return {node: makeVan(pick([0xd98026, 0x338cb3, 0xbf3333])), base: rr(5, 7), len: 5};
		if (r < 0.92) return {node: makeTruck(pick([0xe6e6e6, 0xcc2619, 0x264d99]), pick([0xd9d9d1, 0x33734d, 0xcc9926])), base: rr(4, 5.5), len: 7.6};
		return {node: makeBus(pick([0xcc3326, 0x266bb3])), base: rr(4.5, 5.5), len: 9.4};
	}

	laneClear(lane, x, len) {
		return !this.vehicles.some((v) => v.lane === lane && Math.abs(v.node.position.x - x) < (v.len + len) * 0.5 + 6);
	}

	spawnVehicle(atX) {
		const lane = Math.floor(Math.random() * LANES.length);
		const info = this.buildVehicle();
		const dir = LANES[lane].dir;
		const x = atX ?? (dir > 0 ? X_MIN : X_MAX);
		if (!this.laneClear(lane, x, info.len)) return;
		info.node.position.set(x, 0.12, LANES[lane].z + rr(-0.4, 0.4));
		info.node.rotation.y = dir > 0 ? 0 : Math.PI;
		this.scene.add(info.node);
		this.vehicles.push({node: info.node, speed: info.base, base: info.base, dir, lane, len: info.len});
	}

	updateVehicles(dt) {
		for (let i = this.vehicles.length - 1; i >= 0; i--) {
			const v = this.vehicles[i];
			let target = v.base;
			for (const o of this.vehicles) {
				if (o === v || o.lane !== v.lane) continue;
				const gap = (o.node.position.x - v.node.position.x) * v.dir - (o.len + v.len) * 0.5;
				if (gap > -1 && gap < 7) target = Math.min(target, o.speed * Math.min(1, Math.max(0, gap / 7)));
			}
			v.speed += (target - v.speed) * Math.min(1, 3 * dt);
			v.node.position.x += v.dir * v.speed * dt;
			if (v.node.position.x > X_MAX + 6 || v.node.position.x < X_MIN - 6) {
				this.scene.remove(v.node);
				this.vehicles.splice(i, 1);
			}
		}
	}

	spawnPed(atX) {
		const dir = Math.random() < 0.5 ? -1 : 1;
		const opts = {longSleeve: Math.random() < 0.4};
		const roll = Math.random();
		if (roll < 0.2) opts.hat = 'peci';
		else if (roll < 0.4) Object.assign(opts, {hat: 'hijab', hatColor: new THREE.Color(pick(SHIRTS)).multiplyScalar(1.15), longSleeve: true});
		else if (roll < 0.5) Object.assign(opts, {hat: 'cap', hatColor: pick(SHIRTS)});
		else opts.hair = pick(['short', 'side', 'short', 'long']);
		const skin = new THREE.Color(0xbd855c).lerp(new THREE.Color(0x80543a), Math.random());
		const p = makePerson(pick(SHIRTS), pick([0x2e334d, 0x403829, 0x1a1a24]), skin, 0x14100d, opts);
		p.scale.setScalar(rr(0.92, 1.05));
		const x = atX ?? (dir > 0 ? X_MIN : X_MAX);
		p.position.set(x, 0.16, pick(PED_ZS) + rr(-0.2, 0.2));
		p.rotation.y = dir > 0 ? Math.PI / 2 : -Math.PI / 2;
		this.scene.add(p);
		this.peds.push({node: p, dir, speed: rr(1.1, 1.8), phase: Math.random() * 6});
	}

	updatePeds(dt) {
		for (let i = this.peds.length - 1; i >= 0; i--) {
			const d = this.peds[i];
			d.node.position.x += d.dir * d.speed * dt;
			d.phase += dt * d.speed * 4.6;
			animatePerson(d.node, d.phase, 1);
			if (d.node.position.x > X_MAX + 3 || d.node.position.x < X_MIN - 3) {
				this.scene.remove(d.node);
				this.peds.splice(i, 1);
			}
		}
	}
}
