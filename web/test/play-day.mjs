// Uji end-to-end: memainkan satu hari penuh di Chrome dan menyimpan screenshot.
// Pakai: node test/play-day.mjs <folder-keluaran>   (butuh `npm run build` dulu)
import puppeteer from 'puppeteer-core';
import {spawn} from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';

const out = process.argv[2] || 'test/out';
fs.mkdirSync(out, {recursive: true});
const chrome = ['C:/Program Files/Google/Chrome/Application/chrome.exe', 'C:/Program Files (x86)/Google/Chrome/Application/chrome.exe'].find((p) => fs.existsSync(p));
const PORT = 4173;

const server = spawn('npx', ['vite', 'preview', '--port', String(PORT), '--strictPort'], {shell: true, stdio: 'ignore'});
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const errors = [];

async function main() {
	await sleep(2500);
	const browser = await puppeteer.launch({
		executablePath: chrome,
		headless: 'new',
		args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--enable-webgl', '--no-sandbox'],
		defaultViewport: {width: 1280, height: 720},
	});
	const page = await browser.newPage();
	page.on('console', (m) => {
		if (['error', 'warning'].includes(m.type())) errors.push(`[${m.type()}] ${m.text()}`);
	});
	page.on('pageerror', (e) => errors.push(`[pageerror] ${e.message}`));
	const shot = (n) => page.screenshot({path: path.join(out, `${n}.png`)});
	const clickText = async (t) => {
		const ok = await page.evaluate((txt) => {
			const b = [...document.querySelectorAll('button')].find((x) => x.textContent.includes(txt) && x.offsetParent !== null);
			if (b) b.click();
			return !!b;
		}, t);
		if (!ok) errors.push(`[uji] tombol tidak ditemukan: ${t}`);
		await sleep(250);
	};
	const tp = (x, z) => page.evaluate((a, b) => __g.player.obj.position.set(a, 0.16, b), x, z);
	const pressE = async () => {
		await sleep(300);
		await page.keyboard.press('e');
		await sleep(300);
	};

	await page.goto(`http://localhost:${PORT}/`, {waitUntil: 'load'});
	await page.waitForSelector('#loading.hide', {timeout: 90000});
	await sleep(2500);
	await shot('1_setup');
	await clickText('Mulai Hari 1');
	await sleep(1500);
	await shot('2_dunia');
	await tp(-8.5, -2.5);
	await pressE();
	await shot('3_rencana');
	await clickText('Berangkat ke pasar');
	await tp(16.5, -1.5);
	await pressE();
	await page.evaluate(() => {
		for (const i of __g.sim.data.ingredients) __g.sim.buyIngredient(i.id, 20, 'bejo');
	});
	await clickText('+1');
	await shot('4_pasar');
	await clickText('Selesai belanja');
	await tp(-3.5, 3.2);
	await pressE();
	await shot('5_persiapan');
	await clickText('Berangkat: dorong');
	await tp(4.5, 3.2);
	await pressE();
	await clickText('Parkir di sini');
	await sleep(2200);
	await clickText('x8');
	await sleep(5000);
	await shot('6_jualan');
	await page.waitForFunction(() => __g.S.sell.done, {timeout: 60000});
	await clickText('Selesai berjualan');
	await tp(-8.5, -2.5);
	await pressE();
	await shot('7_tutup');
	await clickText('Tidur');
	await sleep(800);
	const info = await page.evaluate(() => ({day: __g.S.day, phase: __g.S.phase, pools: __g.S.pools, worth: __g.sim.netWorth(), veh: __g.traffic.vehicles.length, peds: __g.traffic.peds.length}));
	console.log('STATUS', JSON.stringify(info));
	await shot('8_hari2');
	await browser.close();
}

try {
	await main();
} catch (e) {
	errors.push(`[uji] ${e.message}`);
} finally {
	server.kill();
	spawn('taskkill', ['/F', '/T', '/PID', String(server.pid)], {shell: true, stdio: 'ignore'});
}
console.log('GALAT', errors.length ? '\n' + [...new Set(errors)].slice(0, 15).join('\n') : 'tidak ada');
process.exit(0);
