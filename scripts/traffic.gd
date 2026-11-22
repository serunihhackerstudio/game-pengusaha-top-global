class_name Traffic
extends Node3D
## Kehidupan jalan: kendaraan lewat di dua lajur dan pejalan kaki di trotoar.
## Kepadatan mengikuti jam (ramai di jam sibuk, sepi di malam hari).

const X_MIN := -52.0
const X_MAX := 52.0
const MAX_VEHICLES := 16
const MAX_PEDS := 14
## Lajur: z jalan dan arah gerak (+1 = ke kanan layar-dunia +X).
const LANES := [{"z": 6.0, "dir": 1.0}, {"z": 10.6, "dir": -1.0}]
## Jalur pejalan kaki (z): dekat bangunan dan dekat kerb.
const PED_ZS := [-2.6, -1.8, 2.9, 3.3]

var hour: float = 7.0
var enabled: bool = true
var rng := RandomNumberGenerator.new()

var _vehicles: Array = []   # {node, speed, base, dir, lane, len}
var _peds: Array = []       # {node, dir, speed, legs, phase}
var _vt: float = 0.5
var _pt: float = 0.5

const CAR_COLORS := [Color(0.75, 0.1, 0.1), Color(0.9, 0.9, 0.92), Color(0.12, 0.14, 0.2), Color(0.2, 0.35, 0.6), Color(0.55, 0.55, 0.58), Color(0.85, 0.7, 0.15)]
const SHIRTS := [Color(0.7, 0.25, 0.2), Color(0.2, 0.4, 0.65), Color(0.85, 0.65, 0.2), Color(0.3, 0.55, 0.35), Color(0.55, 0.35, 0.6), Color(0.9, 0.9, 0.88), Color(0.2, 0.2, 0.25)]


func _ready() -> void:
	rng.randomize()
	# isi awal agar jalan tidak kosong saat game dibuka
	for i in 5:
		_spawn_vehicle(rng.randf_range(-40.0, 40.0))
	for i in 6:
		_spawn_ped(rng.randf_range(-40.0, 40.0))


func set_hour(h: float) -> void:
	hour = h


## Pengali jarak antar kedatangan (lebih kecil = lebih ramai).
func _interval_factor() -> float:
	if hour >= 19.5 or hour < 5.5:
		return 2.8
	if (hour >= 6.8 and hour < 9.0) or (hour >= 16.5 and hour < 19.0):
		return 0.6
	if hour >= 12.0 and hour < 13.5:
		return 0.8
	return 1.0


func _process(delta: float) -> void:
	if not enabled:
		return
	_vt -= delta
	if _vt <= 0.0:
		_vt = rng.randf_range(1.6, 3.4) * _interval_factor()
		if _vehicles.size() < MAX_VEHICLES:
			_spawn_vehicle(NAN)
	_pt -= delta
	if _pt <= 0.0:
		_pt = rng.randf_range(2.0, 5.0) * (0.7 if (hour >= 11.5 and hour < 14.0) or (hour >= 16.0 and hour < 19.0) else 1.0) * (2.0 if hour >= 20.0 else 1.0)
		if _peds.size() < MAX_PEDS:
			_spawn_ped(NAN)
	_update_vehicles(delta)
	_update_peds(delta)


# ---------- Kendaraan ----------

func _build_vehicle() -> Dictionary:
	var r := rng.randf()
	var node: Node3D
	var base := 7.0
	var length := 4.2
	if r < 0.40:
		node = World.motorbike(CAR_COLORS[rng.randi() % CAR_COLORS.size()], SHIRTS[rng.randi() % SHIRTS.size()])
		base = rng.randf_range(7.5, 10.5)
		length = 1.8
	elif r < 0.68:
		node = World.car(CAR_COLORS[rng.randi() % CAR_COLORS.size()])
		base = rng.randf_range(6.0, 8.5)
		length = 4.4
	elif r < 0.80:
		node = World.van([Color(0.85, 0.5, 0.15), Color(0.2, 0.55, 0.7), Color(0.75, 0.2, 0.2)][rng.randi() % 3])
		base = rng.randf_range(5.0, 7.0)
		length = 5.0
	elif r < 0.92:
		node = World.truck([Color(0.9, 0.9, 0.9), Color(0.8, 0.15, 0.1), Color(0.15, 0.3, 0.6)][rng.randi() % 3], [Color(0.85, 0.85, 0.82), Color(0.2, 0.45, 0.3), Color(0.8, 0.6, 0.15)][rng.randi() % 3])
		base = rng.randf_range(4.0, 5.5)
		length = 7.6
	else:
		node = World.bus([Color(0.8, 0.2, 0.15), Color(0.15, 0.4, 0.7)][rng.randi() % 2])
		base = rng.randf_range(4.5, 5.5)
		length = 9.4
	return {"node": node, "base": base, "len": length}


func _lane_clear(lane: int, x: float, length: float) -> bool:
	for v in _vehicles:
		if int(v["lane"]) != lane:
			continue
		var n: Node3D = v["node"]
		if absf(n.position.x - x) < (float(v["len"]) + length) * 0.5 + 6.0:
			return false
	return true


func _spawn_vehicle(at_x: float) -> void:
	var lane := rng.randi() % LANES.size()
	var info := _build_vehicle()
	var dir: float = LANES[lane]["dir"]
	var x := at_x if not is_nan(at_x) else (X_MIN if dir > 0.0 else X_MAX)
	if not _lane_clear(lane, x, float(info["len"])):
		(info["node"] as Node3D).queue_free()
		return
	var n: Node3D = info["node"]
	n.position = Vector3(x, 0.12, float(LANES[lane]["z"]) + rng.randf_range(-0.4, 0.4))
	n.rotation.y = 0.0 if dir > 0.0 else PI
	add_child(n)
	_vehicles.append({"node": n, "speed": info["base"], "base": info["base"], "dir": dir, "lane": lane, "len": info["len"]})


func _update_vehicles(delta: float) -> void:
	for i in range(_vehicles.size() - 1, -1, -1):
		var v: Dictionary = _vehicles[i]
		var n: Node3D = v["node"]
		var dir: float = v["dir"]
		# ikuti kendaraan di depan agar tidak menabrak
		var target: float = v["base"]
		for o in _vehicles:
			if o == v or int(o["lane"]) != int(v["lane"]):
				continue
			var on: Node3D = o["node"]
			var gap := (on.position.x - n.position.x) * dir - (float(o["len"]) + float(v["len"])) * 0.5
			if gap > -1.0 and gap < 7.0:
				target = minf(target, float(o["speed"]) * clampf(gap / 7.0, 0.0, 1.0))
		v["speed"] = lerpf(float(v["speed"]), target, minf(1.0, 3.0 * delta))
		n.position.x += dir * float(v["speed"]) * delta
		if n.position.x > X_MAX + 6.0 or n.position.x < X_MIN - 6.0:
			n.queue_free()
			_vehicles.remove_at(i)


# ---------- Pejalan kaki ----------

func _spawn_ped(at_x: float) -> void:
	var dir := -1.0 if rng.randf() < 0.5 else 1.0
	var shirt: Color = SHIRTS[rng.randi() % SHIRTS.size()]
	var skin := Color(0.74, 0.52, 0.36).lerp(Color(0.5, 0.33, 0.22), rng.randf())
	var opts := {"long_sleeve": rng.randf() < 0.4}
	var roll := rng.randf()
	var hair_col := Color(0.08, 0.06, 0.05).lerp(Color(0.3, 0.2, 0.12), rng.randf() * 0.4)
	if roll < 0.2:
		opts["hat"] = "peci"
	elif roll < 0.4:
		opts["hat"] = "hijab"
		opts["hat_color"] = SHIRTS[rng.randi() % SHIRTS.size()].lightened(0.1)
		opts["long_sleeve"] = true
	elif roll < 0.5:
		opts["hat"] = "cap"
		opts["hat_color"] = SHIRTS[rng.randi() % SHIRTS.size()]
	else:
		opts["hair"] = ["short", "side", "short", "long"][rng.randi() % 4]
	var p := World.person(shirt, [Color(0.18, 0.2, 0.3), Color(0.25, 0.22, 0.18), Color(0.1, 0.1, 0.14)][rng.randi() % 3], skin, hair_col, opts)
	p.scale = Vector3.ONE * rng.randf_range(0.92, 1.05)
	var x := at_x if not is_nan(at_x) else (X_MIN if dir > 0.0 else X_MAX)
	p.position = Vector3(x, 0.16, PED_ZS[rng.randi() % PED_ZS.size()] + rng.randf_range(-0.2, 0.2))
	p.rotation.y = PI / 2.0 if dir > 0.0 else -PI / 2.0
	add_child(p)
	_peds.append({"node": p, "dir": dir, "speed": rng.randf_range(1.1, 1.8), "phase": rng.randf() * 6.0})


func _update_peds(delta: float) -> void:
	for i in range(_peds.size() - 1, -1, -1):
		var d: Dictionary = _peds[i]
		var n: Node3D = d["node"]
		n.position.x += float(d["dir"]) * float(d["speed"]) * delta
		d["phase"] = float(d["phase"]) + delta * float(d["speed"]) * 4.6
		World.animate_person(n, float(d["phase"]), 1.0)
		if n.position.x > X_MAX + 3.0 or n.position.x < X_MIN - 3.0:
			n.queue_free()
			_peds.remove_at(i)
