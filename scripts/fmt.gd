class_name Fmt
extends RefCounted
## Pemformat angka ala Indonesia.

## 1250000 -> "Rp1.250.000"
static func rp(n: int) -> String:
	var neg := n < 0
	var s := str(absi(n))
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "." + out
	return ("-" if neg else "") + "Rp" + out


## 13.5 -> "13.30"
static func clock(hour: float) -> String:
	var h := int(floor(hour))
	var m := int(round((hour - h) * 60.0))
	if m >= 60:
		h += 1
		m = 0
	return "%02d.%02d" % [h, m]
