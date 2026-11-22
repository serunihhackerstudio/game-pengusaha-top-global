// Manusia bersendi: kaki, tangan berjari, wajah, rambut, penutup kepala. (Port dari world.gd)
import * as THREE from 'three';

const M = (c, r = 0.8, m = 0) => new THREE.MeshStandardMaterial({color: new THREE.Color(c), roughness: r, metalness: m});
const add = (parent, geo, mat, pos, scale) => {
	const o = new THREE.Mesh(geo, mat);
	o.position.set(...pos);
	if (scale) o.scale.set(...scale);
	o.castShadow = true;
	parent.add(o);
	return o;
};
const ball = (p, r, pos, mat, sc) => add(p, new THREE.SphereGeometry(r, 18, 12), mat, pos, sc);
const cap = (p, len, r, pos, mat) => add(p, new THREE.CapsuleGeometry(r, Math.max(0.001, len - r * 0.8), 4, 12), mat, pos);
const bx = (p, size, pos, mat) => add(p, new THREE.BoxGeometry(...size), mat, pos);

function makeArm(parent, side, sleeve, fore, skin) {
	const sh = new THREE.Group();
	sh.position.set(0.235 * side, 1.4, 0);
	parent.add(sh);
	ball(sh, 0.056, [0, 0, 0], sleeve);
	cap(sh, 0.3, 0.05, [0, -0.15, 0], sleeve);
	const el = new THREE.Group();
	el.position.set(0, -0.3, 0);
	sh.add(el);
	ball(el, 0.048, [0, 0, 0], fore);
	cap(el, 0.26, 0.043, [0, -0.14, 0], fore);
	const hand = new THREE.Group();
	hand.position.set(0, -0.3, 0);
	el.add(hand);
	bx(hand, [0.075, 0.085, 0.036], [0, -0.03, 0], skin);
	bx(hand, [0.07, 0.06, 0.028], [0, -0.095, 0.002], skin);
	for (let i = 0; i < 4; i++) bx(hand, [0.012, 0.045, 0.02], [-0.027 + i * 0.018, -0.14, 0.004], skin);
	const th = cap(hand, 0.04, 0.012, [-0.045 * side, -0.05, 0.012], skin);
	th.rotation.z = (25 * side * Math.PI) / 180;
	return {sh, el};
}

/** opts: hair (short|side|long|none), hat (peci|hijab|cap|helmet), longSleeve, sit, shoes, hatColor */
export function makePerson(shirt, pants, skin = 0xbd855c, hair = 0x14100d, opts = {}) {
	const g = new THREE.Group();
	const style = opts.hair || 'short';
	const hat = opts.hat || '';
	const sit = !!opts.sit;
	const hatCol = new THREE.Color(opts.hatColor ?? 0x1a1a1f);
	const mShirt = M(shirt, 0.85);
	const mPants = M(pants, 0.85);
	const skinC = new THREE.Color(skin);
	const mSkin = M(skinC, 0.62);
	const mSkinD = M(skinC.clone().multiplyScalar(0.86), 0.7);
	const mHair = M(hair, 0.55);
	const mShoe = M(opts.shoes ?? 0x1f1f23, 0.6);

	const body = new THREE.Group();
	g.add(body);
	if (sit) body.position.y = -0.42;

	const legs = {};
	for (const side of [-1, 1]) {
		const hip = new THREE.Group();
		hip.position.set(0.1 * side, 0.92, 0);
		body.add(hip);
		ball(hip, 0.092, [0, 0, 0], mPants);
		cap(hip, 0.44, 0.085, [0, -0.22, 0], mPants);
		const knee = new THREE.Group();
		knee.position.set(0, -0.44, 0);
		hip.add(knee);
		ball(knee, 0.068, [0, 0, 0], mPants);
		cap(knee, 0.42, 0.064, [0, -0.22, 0], mPants);
		const foot = new THREE.Group();
		foot.position.set(0, -0.45, 0);
		knee.add(foot);
		bx(foot, [0.105, 0.075, 0.27], [0, -0.02, 0.06], mShoe);
		bx(foot, [0.105, 0.02, 0.27], [0, -0.062, 0.06], M(0xd9d9d9, 0.8));
		legs[side] = {hip, knee};
	}

	bx(body, [0.36, 0.18, 0.22], [0, 0.93, 0], mPants);
	const torso = cap(body, 0.34, 0.18, [0, 1.17, 0], mShirt);
	torso.scale.set(1.18, 1.0, 0.72);
	bx(body, [0.38, 0.045, 0.25], [0, 0.98, 0], M(0x1a1717, 0.5));
	bx(body, [0.2, 0.045, 0.17], [0, 1.43, 0], M(new THREE.Color(shirt).multiplyScalar(0.88), 0.85));
	cap(body, 0.08, 0.05, [0, 1.49, 0], mSkinD);

	const fore = opts.longSleeve ? mShirt : mSkin;
	const armL = makeArm(body, -1, mShirt, fore, mSkin);
	const armR = makeArm(body, 1, mShirt, fore, mSkin);

	const head = new THREE.Group();
	head.position.set(0, 1.64, 0);
	body.add(head);
	ball(head, 0.125, [0, 0, 0], mSkin, [0.92, 1.1, 1.0]);
	for (const s of [-1, 1]) {
		ball(head, 0.03, [0.115 * s, -0.01, 0], mSkinD, [0.55, 1.0, 0.8]);
		ball(head, 0.021, [0.046 * s, 0.02, 0.108], M(0xf7f5ee, 0.4), [1.2, 0.8, 0.5]);
		ball(head, 0.011, [0.046 * s, 0.019, 0.117], M(0x0f0a08, 0.3));
		bx(head, [0.05, 0.011, 0.012], [0.048 * s, 0.056, 0.108], style !== 'none' ? mHair : M(0x1a1412));
	}
	ball(head, 0.02, [0, -0.02, 0.122], M(skinC.clone().multiplyScalar(1.05), 0.6), [0.9, 1.1, 1.0]);
	bx(head, [0.05, 0.009, 0.012], [0, -0.07, 0.108], M(0x802e29, 0.5));

	if (style !== 'none' && hat !== 'hijab') {
		ball(head, 0.13, [0, 0.082, -0.022], mHair, [1.0, 0.64, 1.04]);
		if (style === 'side') {
			const fr = bx(head, [0.17, 0.035, 0.07], [0.03, 0.118, 0.07], mHair);
			fr.rotation.set((18 * Math.PI) / 180, 0, (-10 * Math.PI) / 180);
		} else if (style === 'long') {
			bx(head, [0.27, 0.34, 0.07], [0, -0.12, -0.085], mHair);
		}
	}
	if (hat === 'peci') {
		add(head, new THREE.CylinderGeometry(0.118, 0.1, 0.1, 20), M(hatCol, 0.7), [0, 0.12, 0]);
	} else if (hat === 'hijab') {
		const hj = M(hatCol, 0.85);
		ball(head, 0.142, [0, 0.025, -0.04], hj, [1.05, 1.15, 1.05]);
		const dr = cap(head, 0.1, 0.15, [0, -0.15, -0.035], hj);
		dr.scale.set(1.15, 1, 0.8);
		const band = bx(head, [0.18, 0.025, 0.06], [0, 0.1, 0.085], hj);
		band.rotation.x = (20 * Math.PI) / 180;
	} else if (hat === 'cap') {
		ball(head, 0.13, [0, 0.07, -0.005], M(hatCol, 0.7), [1.0, 0.6, 1.06]);
		bx(head, [0.17, 0.018, 0.12], [0, 0.07, 0.115], M(hatCol.clone().multiplyScalar(0.85), 0.7));
	} else if (hat === 'helmet') {
		ball(head, 0.158, [0, 0.035, -0.005], M(hatCol, 0.28, 0.4), [1.0, 0.92, 1.08]);
		bx(head, [0.2, 0.035, 0.09], [0, 0.075, 0.115], M(0x1a2029, 0.1, 0.8));
	}

	g.userData.rig = {
		body, sit, head,
		hl: legs[-1].hip, hr: legs[1].hip, kl: legs[-1].knee, kr: legs[1].knee,
		al: armL.sh, ar: armR.sh, el: armL.el, er: armR.el,
	};
	if (sit) {
		legs[-1].hip.rotation.x = -1.45;
		legs[1].hip.rotation.x = -1.45;
		legs[-1].knee.rotation.x = 1.5;
		legs[1].knee.rotation.x = 1.5;
		armL.sh.rotation.x = -0.9;
		armR.sh.rotation.x = -0.9;
		armL.el.rotation.x = -0.5;
		armR.el.rotation.x = -0.5;
	}
	return g;
}

/** phase = fase gerak; amount 0 (diam) .. 1 (jalan penuh). */
export function animatePerson(p, phase, amount) {
	const r = p.userData.rig;
	if (!r || r.sit) return;
	const s = Math.sin(phase);
	r.hl.rotation.x = s * 0.62 * amount;
	r.hr.rotation.x = -s * 0.62 * amount;
	r.kl.rotation.x = Math.max(0, s) * 0.85 * amount;
	r.kr.rotation.x = Math.max(0, -s) * 0.85 * amount;
	r.al.rotation.x = -s * 0.5 * amount;
	r.ar.rotation.x = s * 0.5 * amount;
	r.el.rotation.x = -0.12 - Math.max(0, s) * 0.35 * amount;
	r.er.rotation.x = -0.12 - Math.max(0, -s) * 0.35 * amount;
	r.body.position.y = Math.abs(Math.sin(phase)) * 0.035 * amount;
	r.head.rotation.y = Math.sin(phase * 0.5) * 0.06 * amount;
}
