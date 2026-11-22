// Lokasi "Gang Mawar": material PBR (Poly Haven CC0), bangunan, kendaraan. (Port dari world.gd)
import * as THREE from 'three';
import {makePerson} from './people.js';

const loader = new THREE.TextureLoader();
const base = import.meta.env.BASE_URL + 'assets/textures/';
const texCache = new Map();
const matCache = new Map();
let maxAniso = 8;
export const setAniso = (n) => (maxAniso = n);

function loadTex(url, repeat, srgb) {
	const key = `${url}|${repeat}`;
	if (texCache.has(key)) return texCache.get(key);
	const t = loader.load(url);
	t.wrapS = t.wrapT = THREE.RepeatWrapping;
	t.repeat.set(repeat, repeat);
	t.anisotropy = maxAniso;
	if (srgb) t.colorSpace = THREE.SRGBColorSpace;
	texCache.set(key, t);
	return t;
}

/** Material PBR; `scale` = jumlah pengulangan tekstur per meter. */
export function pbr(name, scale = 0.5, tint = 0xffffff) {
	const key = `${name}|${scale}|${tint}`;
	if (matCache.has(key)) return matCache.get(key);
	const arm = loadTex(`${base}${name}/arm.jpg`, scale, false);
	const m = new THREE.MeshStandardMaterial({
		color: new THREE.Color(tint),
		map: loadTex(`${base}${name}/diff.jpg`, scale, true),
		normalMap: loadTex(`${base}${name}/nor.jpg`, scale, false),
		aoMap: arm,
		roughnessMap: arm,
		metalnessMap: arm,
		metalness: 1.0,
		roughness: 1.0,
	});
	matCache.set(key, m);
	return m;
}

export const flat = (c, rough = 0.8, metal = 0, emit = 0) => {
	const m = new THREE.MeshStandardMaterial({color: new THREE.Color(c), roughness: rough, metalness: metal});
	if (emit > 0) {
		m.emissive = new THREE.Color(c);
		m.emissiveIntensity = emit;
	}
	return m;
};
export const glass = (c = 0x26384c) => flat(c, 0.08, 0.9);

/** Geometri kotak dengan UV dalam meter agar tekstur PBR berukuran nyata. */
function boxGeo(w, h, d) {
	const g = new THREE.BoxGeometry(w, h, d);
	const uv = g.attributes.uv;
	const dims = [[d, h], [d, h], [w, d], [w, d], [w, h], [w, h]];
	for (let f = 0; f < 6; f++) {
		for (let v = 0; v < 4; v++) {
			const i = f * 4 + v;
			uv.setXY(i, uv.getX(i) * dims[f][0], uv.getY(i) * dims[f][1]);
		}
	}
	return g;
}

export const colliders = [];

/** Kotak dengan pos = tengah-bawah. */
export function box(parent, size, pos, mat, solid = false) {
	const mesh = new THREE.Mesh(boxGeo(...size), mat);
	mesh.position.set(pos[0], pos[1] + size[1] / 2, pos[2]);
	mesh.castShadow = true;
	mesh.receiveShadow = true;
	parent.add(mesh);
	if (solid) {
		parent.updateMatrixWorld(true);
		const wp = new THREE.Vector3();
		mesh.getWorldPosition(wp);
		colliders.push({minX: wp.x - size[0] / 2, maxX: wp.x + size[0] / 2, minZ: wp.z - size[2] / 2, maxZ: wp.z + size[2] / 2});
	}
	return mesh;
}

export function cyl(parent, r, h, pos, mat, r2 = r, seg = 20) {
	const m = new THREE.Mesh(new THREE.CylinderGeometry(r2, r, h, seg), mat);
	m.position.set(pos[0], pos[1] + h / 2, pos[2]);
	m.castShadow = true;
	parent.add(m);
	return m;
}

export function sphere(parent, r, pos, mat) {
	const m = new THREE.Mesh(new THREE.SphereGeometry(r, 18, 12), mat);
	m.position.set(...pos);
	m.castShadow = true;
	parent.add(m);
	return m;
}

/** Atap pelana: bubungan sejajar sumbu X, pos = tengah-bawah. */
export function gable(parent, w, d, h, pos, mat) {
	const s = new THREE.Shape();
	s.moveTo(-d / 2, 0);
	s.lineTo(d / 2, 0);
	s.lineTo(0, h);
	s.closePath();
	const g = new THREE.ExtrudeGeometry(s, {depth: w, bevelEnabled: false});
	g.translate(0, 0, -w / 2);
	g.rotateY(Math.PI / 2);
	const m = new THREE.Mesh(g, mat);
	m.position.set(...pos);
	m.castShadow = true;
	m.receiveShadow = true;
	parent.add(m);
	return m;
}

function ruko(root, pos, w, floors, wallTint, awning) {
	const fh = 3;
	const h = floors * fh;
	const d = 7;
	const g = new THREE.Group();
	g.position.set(...pos);
	root.add(g);
	box(g, [w, h, d], [0, 0, 0], pbr('beige_wall_001', 0.35, wallTint), true);
	gable(g, w + 0.6, d + 1, 1.8, [0, h, 0], pbr('clay_roof_tiles', 0.4, 0xffd9cc));
	box(g, [w * 0.84, 2.3, 0.12], [0, 0.1, d / 2 + 0.02], flat(0xffd480, 0.5, 0, 1.2));
	const aw = box(g, [w * 0.94, 0.12, 1.5], [0, 2.7, d / 2 + 0.7], flat(awning, 0.7));
	aw.rotation.x = (12 * Math.PI) / 180;
	for (let f = 1; f < floors; f++) {
		const n = Math.max(2, Math.floor(w / 2.4));
		for (let k = 0; k < n; k++) {
			const x = -w / 2 + (w / n) * (k + 0.5);
			box(g, [1.3, 1.6, 0.12], [x, f * fh + 0.7, d / 2 + 0.04], glass());
			box(g, [1.6, 0.14, 0.4], [x, f * fh + 0.55, d / 2 + 0.12], flat(0xe0d9c7));
		}
	}
}

function tree(root, pos, s = 1) {
	const g = new THREE.Group();
	g.position.set(...pos);
	g.scale.setScalar(s);
	root.add(g);
	cyl(g, 0.22, 2.4, [0, 0, 0], pbr('wood_plank_wall', 0.6, 0x998066), 0.15);
	const leaf = flat(0x387533, 0.9);
	sphere(g, 1.7, [0, 3.6, 0], leaf);
	sphere(g, 1.2, [1.1, 3.0, 0.4], flat(0x478538, 0.9));
	sphere(g, 1.3, [-1.0, 3.2, -0.5], leaf);
}

function lamp(root, pos) {
	const g = new THREE.Group();
	g.position.set(...pos);
	root.add(g);
	const metal = flat(0x333338, 0.5, 0.6);
	cyl(g, 0.08, 5.2, [0, 0, 0], metal, 0.06);
	box(g, [1.2, 0.1, 0.12], [0.55, 5.2, 0], metal);
	sphere(g, 0.22, [1.1, 5.1, 0], flat(0xffe6a6, 0.4, 0, 3.0));
	const l = new THREE.PointLight(0xffd999, 14, 12, 2);
	l.position.set(1.1, 4.8, 0);
	g.add(l);
}

function pole(root, pos) {
	const g = new THREE.Group();
	g.position.set(...pos);
	root.add(g);
	cyl(g, 0.16, 9.0, [0, 0, 0], pbr('grey_plaster', 0.5, 0xb3b3b3), 0.12);
	box(g, [0.14, 0.12, 2.8], [0, 8.4, 0], flat(0x4d453d));
	box(g, [0.14, 0.12, 2.2], [0, 7.5, 0], flat(0x4d453d));
}

// ---------- Kendaraan (panjang di sumbu X, menghadap +X) ----------

function wheel(parent, pos, r, w) {
	const tire = new THREE.Mesh(new THREE.CylinderGeometry(r, r, w, 18), flat(0x0f0f11, 0.9));
	tire.position.set(...pos);
	tire.rotation.x = Math.PI / 2;
	tire.castShadow = true;
	parent.add(tire);
	const rim = new THREE.Mesh(new THREE.CylinderGeometry(r * 0.55, r * 0.55, w + 0.02, 14), flat(0xb3b3b8, 0.3, 0.9));
	rim.position.set(...pos);
	rim.rotation.x = Math.PI / 2;
	parent.add(rim);
}

function lights(parent, fx, bx, y, z, size = 0.12) {
	for (const s of [-1, 1]) {
		sphere(parent, size, [fx, y, z * s], flat(0xfff2c2, 0.3, 0, 2.6));
		sphere(parent, size * 0.8, [bx, y, z * s], flat(0xff2619, 0.3, 0, 2.0));
	}
}

export function makeCar(color) {
	const g = new THREE.Group();
	const paint = flat(color, 0.28, 0.6);
	box(g, [4.2, 0.7, 1.8], [0, 0.35, 0], paint);
	box(g, [2.3, 0.62, 1.6], [-0.2, 1.05, 0], paint);
	box(g, [2.0, 0.42, 1.64], [-0.2, 1.12, 0], glass());
	box(g, [1.0, 0.1, 1.62], [1.55, 1.0, 0], paint);
	for (const x of [-1.35, 1.35]) for (const z of [-0.92, 0.92]) wheel(g, [x, 0.36, z], 0.36, 0.22);
	lights(g, 2.1, -2.1, 0.62, 0.62);
	return g;
}

export function makeVan(color) {
	const g = new THREE.Group();
	box(g, [4.8, 1.5, 1.9], [0, 0.35, 0], flat(color, 0.35, 0.5));
	box(g, [3.7, 0.55, 1.94], [-0.3, 1.2, 0], glass());
	box(g, [4.8, 0.14, 1.95], [0, 0.9, 0], flat(0xf2f2e6, 0.5));
	box(g, [2.6, 0.08, 1.4], [-0.5, 1.9, 0], flat(0x4d4d54, 0.6, 0.6));
	for (const x of [-1.5, 1.5]) for (const z of [-0.95, 0.95]) wheel(g, [x, 0.38, z], 0.38, 0.24);
	lights(g, 2.4, -2.4, 0.7, 0.65);
	return g;
}

export function makeTruck(cab, boxCol) {
	const g = new THREE.Group();
	box(g, [2.0, 2.0, 2.3], [2.4, 0.5, 0], flat(cab, 0.4, 0.4));
	box(g, [0.12, 0.9, 2.0], [3.43, 1.35, 0], glass());
	box(g, [6.2, 0.35, 2.3], [-1.0, 0.5, 0], flat(0x333338, 0.7));
	box(g, [5.6, 2.6, 2.4], [-1.3, 0.85, 0], flat(boxCol, 0.5, 0.2));
	for (const x of [-3.0, -1.8, 2.6]) for (const z of [-1.15, 1.15]) wheel(g, [x, 0.5, z], 0.5, 0.3);
	lights(g, 3.45, -4.15, 0.95, 0.8, 0.14);
	return g;
}

export function makeBus(color) {
	const g = new THREE.Group();
	box(g, [9.2, 3.0, 2.5], [0, 0.5, 0], flat(color, 0.4, 0.4));
	box(g, [8.4, 1.0, 2.54], [-0.2, 1.9, 0], glass());
	box(g, [9.2, 0.16, 2.54], [0, 1.3, 0], flat(0xf2f0e0, 0.5));
	for (const x of [-3.0, 3.0]) for (const z of [-1.2, 1.2]) wheel(g, [x, 0.55, z], 0.55, 0.3);
	lights(g, 4.62, -4.62, 0.9, 0.9, 0.15);
	return g;
}

export function makeMotorbike(color, riderShirt) {
	const g = new THREE.Group();
	const paint = flat(color, 0.3, 0.5);
	box(g, [1.6, 0.4, 0.45], [0, 0.4, 0], paint);
	box(g, [0.9, 0.14, 0.42], [-0.25, 0.85, 0], flat(0x121214, 0.8));
	box(g, [0.12, 0.55, 0.5], [0.65, 0.8, 0], paint);
	box(g, [0.08, 0.06, 0.8], [0.62, 1.32, 0], flat(0x1a1a1f, 0.5, 0.7));
	sphere(g, 0.11, [0.78, 1.0, 0], flat(0xfff2c2, 0.3, 0, 2.6));
	wheel(g, [0.62, 0.33, 0], 0.33, 0.14);
	wheel(g, [-0.62, 0.33, 0], 0.33, 0.16);
	const rider = makePerson(riderShirt, 0x262b40, 0xb38059, 0x14100d, {sit: true, hat: 'helmet', hatColor: new THREE.Color(riderShirt).multiplyScalar(0.8), longSleeve: true});
	rider.position.set(-0.15, 0.4, 0);
	rider.rotation.y = Math.PI / 2;
	g.add(rider);
	return g;
}

// ---------- Gerobak ----------

export function makeGerobak() {
	const g = new THREE.Group();
	const wood = pbr('wood_plank_wall', 0.8, 0xd9b280);
	const iron = pbr('corrugated_iron', 0.6, 0x5980bf);
	box(g, [2.2, 0.9, 1.1], [0, 0.4, 0], wood);
	box(g, [2.3, 0.08, 1.2], [0, 1.3, 0], pbr('wood_plank_wall', 0.8, 0xffebcc));
	const dm = flat(0xcce6ff, 0.05);
	dm.transparent = true;
	dm.opacity = 0.28;
	box(g, [1.7, 0.6, 0.9], [0.15, 1.38, 0.05], dm);
	box(g, [0.28, 0.2, 0.28], [-0.3, 1.38, 0.05], flat(0xe69e38));
	box(g, [0.28, 0.16, 0.28], [0.1, 1.38, 0.1], flat(0xd98a2e));
	cyl(g, 0.38, 0.14, [-1.4, 1.38, 0], flat(0x1f1f21, 0.35, 0.8));
	cyl(g, 0.22, 0.7, [-1.4, 0.7, 0], flat(0x4d4d52, 0.5, 0.6));
	for (const z of [-0.65, 0.65]) {
		const w = cyl(g, 0.42, 0.1, [0.5, 0, z], flat(0x141417, 0.9));
		w.position.y = 0.42;
		w.rotation.x = Math.PI / 2;
	}
	for (const p of [[-1.3, 0.95], [1.3, 0.95], [-1.3, -0.95], [1.3, -0.95]]) cyl(g, 0.045, 2.2, [p[0], 0, p[1]], flat(0x664729, 0.8));
	const roof = box(g, [3.0, 0.1, 2.3], [0, 2.2, 0], iron);
	roof.rotation.z = 0.05;
	sphere(g, 0.13, [0.2, 2.0, 0.4], flat(0xffe6a6, 0.4, 0, 3.0));
	const l = new THREE.PointLight(0xffd999, 8, 8, 2);
	l.position.set(0.2, 1.9, 0.5);
	g.add(l);
	return g;
}

// ---------- Lokasi ----------

export function buildWorld(scene) {
	const roadMat = pbr('asphalt_01', 0.18, 0x8c8c99);
	const sideMat = pbr('brick_pavement_02', 0.3, 0xccb39e);
	const ground = pbr('concrete_floor_painted', 0.2, 0x807870);

	box(scene, [140, 0.6, 90], [0, -0.6, -2], ground);
	box(scene, [100, 0.16, 7.5], [1, 0, 0], sideMat);
	box(scene, [100, 0.12, 9.0], [1, 0, 8.25], roadMat);
	box(scene, [100, 0.22, 0.25], [1, 0, 3.8], flat(0xe6e0d1, 0.8));
	for (let x = -45; x <= 45; x += 4) box(scene, [2.0, 0.015, 0.22], [x, 0.12, 8.25], flat(0xf2eeda, 0.7));

	// rumah kos
	const kos = new THREE.Group();
	kos.position.set(-8.5, 0, -8);
	scene.add(kos);
	box(kos, [8, 5.5, 6.5], [0, 0, 0], pbr('beige_wall_001', 0.35, 0xf2e0bf), true);
	gable(kos, 8.8, 7.6, 2.2, [0, 5.5, 0], pbr('clay_roof_tiles', 0.4, 0xffd9cc));
	box(kos, [1.3, 2.4, 0.15], [0, 0, 3.3], pbr('wood_plank_wall', 0.6, 0x8c6140));
	for (const x of [-2.6, 2.6]) {
		box(kos, [1.4, 1.5, 0.12], [x, 1.0, 3.28], glass());
		box(kos, [1.4, 1.5, 0.12], [x, 3.4, 3.28], glass());
	}
	box(kos, [2.4, 0.5, 0.1], [0, 4.6, 3.3], flat(0x2e333f));
	ruko(scene, [-1, 0, -8], 4.4, 2, 0xf2d9b3, 0xbf3833);

	// kantor
	const kantor = new THREE.Group();
	kantor.position.set(4.5, 0, -10);
	scene.add(kantor);
	box(kantor, [9, 15, 7], [0, 0, 0], pbr('grey_plaster', 0.3, 0xccd6e6), true);
	for (let row = 0; row < 5; row++) for (let col = 0; col < 5; col++) box(kantor, [1.3, 1.5, 0.12], [-3.4 + col * 1.7, 2.6 + row * 2.6, 3.54], glass(0x334d6b));
	box(kantor, [5, 3, 0.2], [0, 0, 3.55], glass(0x40566e));
	box(kantor, [9.4, 0.4, 7.4], [0, 15, 0], flat(0x595e66, 0.7));

	// pasar
	const pasar = new THREE.Group();
	pasar.position.set(16.5, 0, -6);
	scene.add(pasar);
	const iron = pbr('corrugated_iron', 0.5, 0x738cb3);
	const produce = [0xcc2619, 0x338c26, 0xe6b31a, 0x8c5926];
	for (let i = 0; i < 3; i++) {
		const sx = -4 + i * 4.2;
		box(pasar, [3.4, 0.9, 1.4], [sx, 0, 0], pbr('wood_plank_wall', 0.8, 0xccA673), true);
		for (let k = 0; k < 4; k++) box(pasar, [0.6, 0.3, 0.6], [sx - 1.2 + k * 0.8, 0.9, 0], flat(produce[(i + k) % 4], 0.8));
		for (const o of [-1.7, 1.7]) cyl(pasar, 0.05, 2.8, [sx + o, 0, 0.7], flat(0x664d33));
		const r = box(pasar, [4.0, 0.1, 2.6], [sx, 2.8, 0.2], iron);
		r.rotation.x = (-6 * Math.PI) / 180;
		sphere(pasar, 0.12, [sx, 2.5, 0.5], flat(0xffe6a6, 0.4, 0, 2.5));
	}
	box(pasar, [14, 4, 0.4], [0, 0, -3.4], pbr('grey_plaster', 0.3, 0xbfb8a6));

	// SD
	const sd = new THREE.Group();
	sd.position.set(-24, 0, -9);
	scene.add(sd);
	box(sd, [12, 5, 7], [0, 0, 0], pbr('beige_wall_001', 0.3, 0xf2e6b3), true);
	gable(sd, 13, 8, 2.4, [0, 5, 0], pbr('clay_roof_tiles', 0.4, 0xffd9cc));
	box(sd, [4, 0.9, 0.15], [0, 3.6, 3.55], flat(0x264d99));
	for (let x = -4; x <= 4; x += 2) box(sd, [1.3, 1.5, 0.12], [x, 1.2, 3.54], glass());
	box(sd, [10, 1.0, 0.2], [0, 0, 4.5], flat(0x595452));

	// pangkalan ojol
	const ojol = new THREE.Group();
	ojol.position.set(31, 0, -7);
	scene.add(ojol);
	box(ojol, [7, 3.6, 5], [0, 0, 0], pbr('beige_wall_001', 0.35, 0xd9e6cc), true);
	gable(ojol, 7.8, 5.8, 1.6, [0, 3.6, 0], pbr('clay_roof_tiles', 0.4, 0xf2ccbf));
	box(ojol, [5.6, 2, 0.1], [0, 0.2, 2.52], flat(0xffd480, 0.5, 0, 1.2));
	[0x1a8c40, 0x991a1a, 0x263373].forEach((c, i) => {
		const moto = new THREE.Group();
		moto.position.set(24 + i * 1.9, 0, 3);
		moto.rotation.y = Math.PI / 2;
		scene.add(moto);
		box(moto, [1.9, 0.5, 0.45], [0, 0.45, 0], flat(c, 0.3, 0.4));
		box(moto, [0.9, 0.12, 0.4], [-0.2, 0.95, 0], flat(0x141416, 0.8));
		for (const x of [-0.7, 0.7]) wheel(moto, [x, 0.34, 0], 0.34, 0.16);
	});
	const ojolMen = [[27, 1, 200, 0x268c4d], [28.5, 0.4, 160, 0x268c4d]];
	for (const [x, z, ry, c] of ojolMen) {
		const p = makePerson(c, 0x262940, 0xa06e4d, 0x14100d, {hat: 'helmet', hatColor: 0x1d7a3f});
		p.position.set(x, 0.16, z);
		p.rotation.y = (ry * Math.PI) / 180;
		scene.add(p);
	}

	// warga diam
	const idle = [
		[13.0, -4.4, 180, 0xd95a4d, 0x403326, {}], [16.8, -4.4, 180, 0x4d8c66, 0x33334a, {hat: 'peci'}],
		[20.5, -4.4, 170, 0xe6cc4d, 0x40404d, {}], [15.0, -2.6, 20, 0x9959a6, 0x33334d, {hat: 'hijab', hatColor: 0x7a4b8a, longSleeve: true}],
		[18.4, -2.9, -40, 0x4066b3, 0x262940, {hair: 'side'}], [-22.0, -3.6, 160, 0xe6e6e0, 0x262666, {hair: 'long'}],
		[-19.4, -3.4, 200, 0xe6e6e0, 0x262666, {}], [-17.2, -2.2, 60, 0xb34d59, 0x33334a, {hat: 'hijab', hatColor: 0x6b4a80, longSleeve: true}],
		[2.0, -3.1, 170, 0x404d80, 0x1f1f2e, {hair: 'side'}], [6.8, -3.0, 190, 0xe6e6eb, 0x262633, {}],
	];
	for (const [x, z, ry, c, p2, o] of idle) {
		const p = makePerson(c, p2, new THREE.Color(0xbd855c).lerp(new THREE.Color(0x80543a), Math.random()), 0x14100d, o);
		p.position.set(x, 0.16, z);
		p.rotation.y = (ry * Math.PI) / 180;
		scene.add(p);
	}

	for (const x of [-14, 10, 22, 38, -34]) ruko(scene, [x, 0, -17], 5, 3, 0xebd1ad, 0x337380);
	for (const x of [-16, -4, 12, 26, 35]) tree(scene, [x, 0, -2.6]);
	for (const x of [-12, 0, 14, 28]) lamp(scene, [x, 0, 3]);
	for (const x of [-20, 8, 34]) pole(scene, [x, 0, 3.4]);

	const gerobak = makeGerobak();
	gerobak.position.set(-3.5, 0.16, 1.2);
	scene.add(gerobak);

	return {
		gerobak,
		spots: {sd: new THREE.Vector3(-20, 0.16, 1.6), kantor: new THREE.Vector3(4.5, 0.16, 1.6), ojol: new THREE.Vector3(25, 0.16, 1.6)},
		zones: {rumah: new THREE.Vector3(-8.5, 0, -3.0), pasar: new THREE.Vector3(16.5, 0, -2.2)},
	};
}
