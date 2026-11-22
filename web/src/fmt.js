/** 1250000 -> "Rp1.250.000" */
export const rp = (n) => {
	const s = Math.abs(Math.round(n)).toString().replace(/\B(?=(\d{3})+(?!\d))/g, '.');
	return (n < 0 ? '-' : '') + 'Rp' + s;
};

/** 13.5 -> "13.30" */
export const clock = (h) => {
	let hh = Math.floor(h);
	let m = Math.round((h - hh) * 60);
	if (m >= 60) {
		hh += 1;
		m = 0;
	}
	return String(hh).padStart(2, '0') + '.' + String(m).padStart(2, '0');
};
