// Perekat game: renderer, kamera isometrik, kendali, interaksi, aliran fase. (Port dari main.gd + player.gd)
import * as THREE from 'three';
import {RGBELoader} from 'three/addons/loaders/RGBELoader.js';
import * as sim from './sim.js';
import {Phase, S} from './sim.js';
import {initUI, setPrompt, ui} from './ui.js';
import {buildWorld, colliders, setAniso} from './world.js';
import {animatePerson, makePerson} from './people.js';
import {Traffic} from './traffic.js';

const canvas = document.getElementById('game');
const coarse = matchMedia('(pointer: coarse)').matches;
const renderer = new THREE.WebGLRenderer({canvas, antialias: true, powerPreference: 'high-performance'});
renderer.setPixelRatio(Math.min(window.devicePixelRatio, coarse ? 1.5 : 2));
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.05;
setAniso(Math.min(8, renderer.capabilities.getMaxAnisotropy()));

const scene = new THREE.Scene();
const camera = new THREE.OrthographicCamera(-1, 1, 1, -1, 0.1, 400);
const CAM_OFF = new THREE.Vector3(18.4, 18.2, 18.4);

// ---------- langit & cahaya ----------
const sun = new THREE.DirectionalLight(0xfff2db, 2.4);
sun.castShadow = true;
sun.shadow.mapSize.set(coarse ? 1024 : 2048, coarse ? 1024 : 2048);
Object.assign(sun.shadow.camera, {left: -32, right: 32, top: 32, bottom: -32, near: 1, far: 140});
sun.shadow.bias = -0.0006;
sun.shadow.normalBias = 0.04;
const fill = new THREE.HemisphereLight(0xcfe3ff, 0x8a6a4a, 0.75);
scene.add(sun, sun.target, fill);

const hdr = {};
let skyIsDusk = false;
function loadHdr(name) {
	return new Promise((res) => {
		new RGBELoader().load(`${import.meta.env.BASE_URL}assets/hdri/${name}_1k.hdr`, (t) => {
			t.mapping = THREE.EquirectangularReflectionMapping;
			res(t);
		}, undefined, () => res(null));
	});
}
function setSky(dusk) {
	const t = dusk ? hdr.dusk : hdr.day;
	if (!t) return;
	scene.background = t;
	scene.environment = hdr.env[dusk ? 'dusk' : 'day'];
	skyIsDusk = dusk;
}

function applyTime(hour) {
	traffic && traffic.setHour(hour);
	const night = hour >= 19.3 || hour < 5.8;
	const t = Math.min(1, Math.max(0, (hour - 6) / 13));
	const elev = Math.sin(t * Math.PI) * 62 + 4;
	const el = (elev * Math.PI) / 180;
	const phi = ((20 + t * 140) * Math.PI) / 180;
	sunDir.set(Math.cos(phi) * Math.cos(el), Math.sin(el), Math.sin(phi) * Math.cos(el));
	const warm = 1 - Math.min(1, Math.max(0, elev / 40));
	sun.color.setRGB(1, 0.95, 0.88).lerp(new THREE.Color(1, 0.62, 0.35), warm);
	if (night) {
		sun.intensity = 0.25;
		sun.color.setRGB(0.55, 0.65, 1);
		renderer.toneMappingExposure = 0.55;
	} else {
		sun.intensity = 0.8 + 1.2 * Math.min(1, elev / 50);
		renderer.toneMappingExposure = 1.05;
	}
	const wantDusk = hour >= 17.5 || hour < 6.5;
	if (wantDusk !== skyIsDusk) setSky(wantDusk);
}
const sunDir = new THREE.Vector3(0.5, 0.8, 0.3);

// ---------- dunia ----------
const world = buildWorld(scene);
const gerobak = world.gerobak;
const HOME_GEROBAK = gerobak.position.clone();
let traffic = null;

// ---------- pemain ----------
const player = {
	obj: makePerson(0xebeff5, 0x334d80, 0xbd855c, 0x14100d, {hair: 'side'}),
	vel: new THREE.Vector3(),
	target: null,
	amount: 0,
	phase: 0,
	enabled: true,
};
player.obj.position.set(-6.5, 0.16, 1.0);
scene.add(player.obj);

const keys = new Set();
addEventListener('keydown', (e) => {
	const k = e.key.toLowerCase();
	keys.add(k);
	if (k === 'e') interact();
});
addEventListener('keyup', (e) => keys.delete(e.key.toLowerCase()));

const joy = {x: 0, y: 0, id: null};
if (coarse) {
	const base = document.createElement('div');
	base.id = 'joy';
	const knob = document.createElement('i');
	base.append(knob);
	document.body.append(base);
	const move = (e) => {
		const r = base.getBoundingClientRect();
		let dx = (e.clientX - (r.left + r.width / 2)) / (r.width / 2);
		let dy = (e.clientY - (r.top + r.height / 2)) / (r.height / 2);
		const len = Math.hypot(dx, dy);
		if (len > 1) {
			dx /= len;
			dy /= len;
		}
		joy.x = dx;
		joy.y = dy;
		knob.style.transform = `translate(${dx * 38}px, ${dy * 38}px)`;
	};
	base.addEventListener('pointerdown', (e) => {
		joy.id = e.pointerId;
		base.setPointerCapture(e.pointerId);
		move(e);
	});
	base.addEventListener('pointermove', (e) => e.pointerId === joy.id && move(e));
	const end = () => {
		joy.id = null;
		joy.x = joy.y = 0;
		knob.style.transform = '';
	};
	base.addEventListener('pointerup', end);
	base.addEventListener('pointercancel', end);
}

const ray = new THREE.Raycaster();
const plane = new THREE.Plane(new THREE.Vector3(0, 1, 0), 0);
canvas.addEventListener('pointerdown', (e) => {
	if (ui.modalOpen) return;
	const ndc = new THREE.Vector2((e.clientX / innerWidth) * 2 - 1, -(e.clientY / innerHeight) * 2 + 1);
	ray.setFromCamera(ndc, camera);
	const p = new THREE.Vector3();
	if (ray.ray.intersectPlane(plane, p)) player.target = p;
});

const FWD = new THREE.Vector3(-0.7071, 0, -0.7071);
const RIGHT = new THREE.Vector3(0.7071, 0, -0.7071);

function updatePlayer(dt) {
	const o = player.obj;
	const dir = new THREE.Vector3();
	if (player.enabled && !ui.modalOpen) {
		let ix = (keys.has('d') || keys.has('arrowright') ? 1 : 0) - (keys.has('a') || keys.has('arrowleft') ? 1 : 0) + joy.x;
		let iy = (keys.has('s') || keys.has('arrowdown') ? 1 : 0) - (keys.has('w') || keys.has('arrowup') ? 1 : 0) + joy.y;
		const il = Math.hypot(ix, iy);
		if (il > 0.12) {
			if (il > 1) {
				ix /= il;
				iy /= il;
			}
			player.target = null;
			dir.copy(RIGHT).multiplyScalar(ix).addScaledVector(FWD, -iy);
		} else if (player.target) {
			const to = player.target.clone().sub(o.position);
			to.y = 0;
			if (to.length() < 0.2) player.target = null;
			else dir.copy(to).normalize();
		}
	}
	const speed = 6.5;
	o.position.x += dir.x * speed * dt;
	o.position.z += dir.z * speed * dt;
	// tabrakan lingkaran terhadap kotak bangunan
	for (const c of colliders) {
		const cx = Math.max(c.minX, Math.min(o.position.x, c.maxX));
		const cz = Math.max(c.minZ, Math.min(o.position.z, c.maxZ));
		const dx = o.position.x - cx;
		const dz = o.position.z - cz;
		const d = Math.hypot(dx, dz);
		if (d < 0.45) {
			if (d > 1e-4) {
				o.position.x = cx + (dx / d) * 0.45;
				o.position.z = cz + (dz / d) * 0.45;
			} else o.position.z = c.maxZ + 0.45;
		}
	}
	o.position.x = Math.max(-46, Math.min(46, o.position.x));
	o.position.z = Math.max(-4.4, Math.min(12.2, o.position.z));
	o.position.y = o.position.z < 3.75 ? 0.16 : 0.12;
	if (dir.lengthSq() > 1e-4) {
		const yaw = Math.atan2(dir.x, dir.z);
		let d = yaw - o.rotation.y;
		d = Math.atan2(Math.sin(d), Math.cos(d));
		o.rotation.y += d * Math.min(1, 12 * dt);
		player.phase += dt * 10;
		player.amount = Math.min(1, player.amount + dt * 6);
	} else player.amount = Math.max(0, player.amount - dt * 6);
	animatePerson(o, player.phase, player.amount);
}

// ---------- zona & penanda ----------
const zoneDefs = {
	rumah: 'Rumah Kos', pasar: 'Pasar', gerobak: 'Gerobak', sd: 'Depan SD', kantor: 'Depan Kantor', ojol: 'Pangkalan Ojol',
};
const markers = {};
function labelSprite(text) {
	const c = document.createElement('canvas');
	c.width = 512;
	c.height = 96;
	const g = c.getContext('2d');
	g.font = 'bold 58px Segoe UI, sans-serif';
	g.textAlign = 'center';
	g.lineWidth = 10;
	g.strokeStyle = 'rgba(0,0,0,.85)';
	g.strokeText(text, 256, 66);
	g.fillStyle = '#fff3b8';
	g.fillText(text, 256, 66);
	const t = new THREE.CanvasTexture(c);
	t.colorSpace = THREE.SRGBColorSpace;
	const s = new THREE.Sprite(new THREE.SpriteMaterial({map: t, depthTest: false, transparent: true}));
	s.scale.set(5.2, 0.98, 1);
	s.renderOrder = 10;
	return s;
}
for (const [id, name] of Object.entries(zoneDefs)) {
	const g = new THREE.Group();
	const ring = new THREE.Mesh(new THREE.CylinderGeometry(1.5, 1.5, 0.05, 32), new THREE.MeshBasicMaterial({color: 0x66ff80, transparent: true, opacity: 0.35}));
	g.add(ring);
	const lb = labelSprite(name);
	lb.position.y = 2.4;
	g.add(lb);
	g.visible = false;
	scene.add(g);
	markers[id] = g;
}
markers.rumah.position.copy(world.zones.rumah);
markers.pasar.position.copy(world.zones.pasar);
for (const sid of ['sd', 'kantor', 'ojol']) markers[sid].position.copy(world.spots[sid]).add(new THREE.Vector3(0, 0.02, 1.8));

function activeZones() {
	if (!S.setupDone) return [];
	switch (S.phase) {
		case Phase.PAGI: return [{id: 'rumah', pos: world.zones.rumah, r: 2.8, text: '[E] Rencana pagi'}];
		case Phase.BELANJA: return [{id: 'pasar', pos: world.zones.pasar, r: 3.6, text: '[E] Belanja di pasar'}];
		case Phase.PERSIAPAN: return [{id: 'gerobak', pos: gerobak.position.clone().add(new THREE.Vector3(0, 0, 2.4)), r: 3, text: '[E] Bersiap di gerobak'}];
		case Phase.JUALAN:
			return S.sell && S.sell.hour ? [] : ['sd', 'kantor', 'ojol'].map((sid) => ({id: sid, pos: world.spots[sid].clone().add(new THREE.Vector3(0, 0, 1.8)), r: 3.2, text: `[E] Jualan di ${sim.spot(sid).name}`}));
		default: return [{id: 'rumah', pos: world.zones.rumah, r: 2.8, text: '[E] Tutup & catat'}];
	}
}

let curZone = null;
function updateZones(t) {
	const zones = activeZones();
	const ids = zones.map((z) => z.id);
	curZone = null;
	let best = 1e9;
	for (const z of zones) {
		const d = Math.hypot(player.obj.position.x - z.pos.x, player.obj.position.z - z.pos.z);
		if (d < z.r && d < best) {
			best = d;
			curZone = z;
		}
	}
	for (const [id, m] of Object.entries(markers)) {
		m.visible = ids.includes(id);
		if (m.visible) m.scale.set(1 + Math.sin(t * 3) * 0.06, 1, 1 + Math.sin(t * 3) * 0.06);
	}
	if (S.phase === Phase.PERSIAPAN && S.setupDone) markers.gerobak.position.copy(gerobak.position).add(new THREE.Vector3(0, 0.02, 2.4));
	setPrompt(curZone ? curZone.text : '');
}

function interact() {
	if (ui.modalOpen) return;
	updateZones(clockT);
	if (!curZone) return;
	player.target = null;
	switch (curZone.id) {
		case 'rumah': S.phase === Phase.PAGI ? ui.openPlan() : ui.openClose(); break;
		case 'pasar': ui.openMarket(); break;
		case 'gerobak': ui.openPrep(); break;
		default: ui.openSpot(curZone.id);
	}
}
ui.handlers.interact = interact;
ui.handlers.onTime = applyTime;

// ---------- aliran game ----------
const tweens = [];
ui.handlers.parked = (sid) => {
	sim.beginSelling(sid);
	const dest = world.spots[sid];
	tweens.push({obj: gerobak, from: gerobak.position.clone(), to: dest.clone(), t: 0, dur: 0.9});
	player.obj.position.copy(dest).add(new THREE.Vector3(-1, 0, 2.3));
	player.target = null;
	setTimeout(() => ui.openSell(), 1200);
};
ui.handlers.dayStarted = () => {
	gerobak.position.copy(HOME_GEROBAK);
	player.obj.position.set(-8.5, 0.16, -2);
	player.target = null;
	applyTime(7);
	ui.toast(`Hari ${S.day} dimulai.`);
};
ui.handlers.setupFinished = () => applyTime(7);
let prevPhase = -1;
sim.on('changed', () => {
	if (prevPhase === Phase.JUALAN && S.phase === Phase.TUTUP) ui.toast('Lapak tutup. Kembali ke rumah kos untuk mencatat.');
	prevPhase = S.phase;
});

// ---------- pelanggan ----------
const walkers = [];
const SHIRTS = [0xb34033, 0x3366a6, 0xd9a633, 0x4d8c59, 0x8c59a6, 0xe6e6e0];
ui.handlers.customerServed = (n) => {
	for (let i = 0; i < n; i++) spawnCustomer();
};
function spawnCustomer() {
	const opts = {hair: ['short', 'side', 'long', 'short'][Math.floor(Math.random() * 4)]};
	if (Math.random() < 0.2) opts.hat = 'peci';
	else if (Math.random() < 0.25) Object.assign(opts, {hat: 'hijab', hatColor: 0x804d8c, longSleeve: true});
	const skin = new THREE.Color(0xbd855c).lerp(new THREE.Color(0x80543a), Math.random());
	const p = makePerson(SHIRTS[Math.floor(Math.random() * SHIRTS.length)], 0x33384d, skin, 0x14100d, opts);
	const cart = gerobak.position;
	const side = Math.random() < 0.5 ? -1 : 1;
	const start = new THREE.Vector3(cart.x + side * 9, 0.16, 2.9 + (Math.random() - 0.5) * 0.8);
	const dest = new THREE.Vector3(cart.x + (Math.random() - 0.5) * 1.4, 0.16, cart.z + 2.0);
	const out = new THREE.Vector3(cart.x - side * 9, 0.16, 3.0);
	p.position.copy(start);
	p.rotation.y = Math.atan2(dest.x - start.x, dest.z - start.z);
	scene.add(p);
	walkers.push({p, start, dest, out, leg: 0, t: 0, phase: 0});
}
function updateWalkers(dt) {
	for (let i = walkers.length - 1; i >= 0; i--) {
		const w = walkers[i];
		w.t += dt;
		if (w.leg === 0) {
			const k = Math.min(1, w.t / 2);
			w.p.position.lerpVectors(w.start, w.dest, k);
			w.phase += dt * 10;
			animatePerson(w.p, w.phase, 1);
			if (k >= 1) {
				w.leg = 1;
				w.t = 0;
				w.p.rotation.y = Math.PI;
				animatePerson(w.p, 0, 0);
			}
		} else if (w.leg === 1) {
			if (w.t >= 0.9) {
				w.leg = 2;
				w.t = 0;
				w.p.rotation.y = Math.atan2(w.out.x - w.dest.x, w.out.z - w.dest.z);
			}
		} else {
			const k = Math.min(1, w.t / 2.6);
			w.p.position.lerpVectors(w.dest, w.out, k);
			w.phase += dt * 10;
			animatePerson(w.p, w.phase, 1);
			if (k >= 1) {
				scene.remove(w.p);
				walkers.splice(i, 1);
			}
		}
	}
}

// ---------- ukuran & loop ----------
function resize() {
	renderer.setSize(innerWidth, innerHeight, false);
	const aspect = innerWidth / innerHeight;
	const halfH = Math.max(7.5, 13.3 / aspect);
	camera.left = -halfH * aspect;
	camera.right = halfH * aspect;
	camera.top = halfH;
	camera.bottom = -halfH;
	camera.updateProjectionMatrix();
}
addEventListener('resize', resize);
resize();

const camTarget = player.obj.position.clone();
let last = performance.now();
let clockT = 0;
function frame(now) {
	const dt = Math.min(0.05, (now - last) / 1000);
	last = now;
	clockT += dt;
	updatePlayer(dt);
	traffic && traffic.update(dt);
	updateWalkers(dt);
	for (let i = tweens.length - 1; i >= 0; i--) {
		const tw = tweens[i];
		tw.t += dt;
		const k = Math.min(1, tw.t / tw.dur);
		tw.obj.position.lerpVectors(tw.from, tw.to, k * k * (3 - 2 * k));
		if (k >= 1) tweens.splice(i, 1);
	}
	ui.update(dt);
	updateZones(clockT);
	camTarget.lerp(player.obj.position, Math.min(1, 4.5 * dt));
	camera.position.copy(camTarget).add(CAM_OFF);
	camera.lookAt(camTarget);
	sun.position.copy(camTarget).addScaledVector(sunDir, 60);
	sun.target.position.copy(camTarget);
	renderer.render(scene, camera);
	requestAnimationFrame(frame);
}

async function start() {
	initUI();
	const [day, dusk] = await Promise.all([loadHdr('kloofendal_48d_partly_cloudy_puresky'), loadHdr('aarfontein_dusk')]);
	const pm = new THREE.PMREMGenerator(renderer);
	hdr.day = day;
	hdr.dusk = dusk;
	hdr.env = {day: day && pm.fromEquirectangular(day).texture, dusk: dusk && pm.fromEquirectangular(dusk).texture};
	if (!day) scene.background = new THREE.Color(0x9fc4e8);
	setSky(false);
	traffic = new Traffic(scene);
	applyTime(7);
	ui.openSetup();
	document.getElementById('loading').classList.add('hide');
	requestAnimationFrame(frame);
}
start();

window.__g = {sim, S, ui, player, scene, camera, get traffic() { return traffic; }, applyTime, gerobak, world};
