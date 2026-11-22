extends Node
## Autoload "Sim": simulasi inti (sumber daya, fase hari, ekonomi). Tanpa UI.

signal changed
signal toast(msg: String)

enum Phase { PAGI, BELANJA, PERSIAPAN, JUALAN, TUTUP }
const PHASE_NAMES := ["Rencana Pagi", "Belanja", "Persiapan", "Berjualan", "Tutup & Catat"]
const POOL_NAMES := {"modal": "Modal Kerja", "hidup": "Biaya Hidup", "darurat": "Dana Darurat", "ekspansi": "Dana Ekspansi"}
const START_CASH := 500000
const LIVING_COST := 25000
const GAS_COST := 8000
const OPEN_HOUR := 10.0
const CLOSE_HOUR := 21.0
const TICK_HOURS := 0.25
const QRIS_SHARE := 0.35
const QRIS_FEE := 0.007
const BAB1_GOAL := 5000000
const DEMAND_SCALE := 0.4

var data: Dictionary = {}
var rng := RandomNumberGenerator.new()

var day: int = 1
var phase: int = Phase.PAGI
var setup_done: bool = false
var pools: Dictionary = {"modal": 0, "hidup": 0, "darurat": 0, "ekspansi": 0}
var owned: Dictionary = {}
var stock: Dictionary = {}
var stock_cost: Dictionary = {}
var stock_quality: float = 0.8
var price: int = 12000
var stamina: float = 100.0
var weather: String = "cerah"
var rep: Dictionary = {"kualitas": 50.0, "etika": 50.0, "koneksi": 5.0}
var journal: Array = []
var spot_id: String = ""
var day_cash: int = 0
var today: Dictionary = {}
var sell: Dictionary = {}
var bab1_done: bool = false


func _ready() -> void:
	var f := FileAccess.open("res://data/game.json", FileAccess.READ)
	if f == null:
		push_error("data/game.json tidak ditemukan")
		return
	data = JSON.parse_string(f.get_as_text())
	rng.randomize()
	new_game()


func new_game() -> void:
	day = 1
	phase = Phase.PAGI
	setup_done = false
	pools = {"modal": 0, "hidup": 0, "darurat": 0, "ekspansi": 0}
	owned = {}
	stock = {}
	stock_cost = {}
	for ing in data.get("ingredients", []):
		stock[ing["id"]] = 0
		stock_cost[ing["id"]] = 0
	stock_quality = 0.8
	price = 12000
	stamina = 100.0
	rep = {"kualitas": 50.0, "etika": 50.0, "koneksi": 5.0}
	journal = []
	spot_id = ""
	day_cash = 0
	today = {}
	sell = {}
	bab1_done = false
	roll_weather()
	changed.emit()


# ---------- Data helper ----------

func equipment_option(eid: String, oid: String) -> Dictionary:
	for e in data["equipment"]:
		if e["id"] == eid:
			for o in e["options"]:
				if o["id"] == oid:
					return o
	return {}


func chosen(eid: String) -> Dictionary:
	return equipment_option(eid, String(owned.get(eid, "")))


func ingredient(iid: String) -> Dictionary:
	for i in data["ingredients"]:
		if i["id"] == iid:
			return i
	return {}


func supplier(sid: String) -> Dictionary:
	for s in data["suppliers"]:
		if s["id"] == sid:
			return s
	return {}


func spot(sid: String) -> Dictionary:
	for s in data["spots"]:
		if s["id"] == sid:
			return s
	return {}


# ---------- Modal awal ----------

func setup_cost(selection: Dictionary) -> int:
	var total := 0
	for eid in selection:
		total += int(equipment_option(eid, String(selection[eid])).get("buy", 0))
	return total


func finish_setup(selection: Dictionary, modal: int, hidup: int, darurat: int) -> bool:
	var cost := setup_cost(selection)
	var left := START_CASH - cost
	if left < 0 or modal < 0 or hidup < 0 or darurat < 0 or modal + hidup + darurat > left:
		return false
	owned = selection.duplicate()
	pools = {"modal": modal, "hidup": hidup, "darurat": darurat, "ekspansi": left - modal - hidup - darurat}
	setup_done = true
	changed.emit()
	return true


# ---------- Belanja & stok ----------

func unit_price(iid: String, sid: String) -> int:
	var base: float = float(ingredient(iid)["price"])
	var p: float = base * float(supplier(sid)["price_mult"])
	return int(round(p / 50.0) * 50.0)


func total_units() -> int:
	var t := 0
	for k in stock:
		t += int(stock[k])
	return t


func buy_ingredient(iid: String, qty: int, sid: String) -> bool:
	var cost := unit_price(iid, sid) * qty
	if qty <= 0 or int(pools["modal"]) < cost:
		return false
	if int(stock[iid]) + qty > daily_capacity():
		return false  # gerobak tidak muat
	var q: float = float(supplier(sid)["quality"])
	var prev := total_units()
	stock_quality = (stock_quality * prev + q * qty) / float(prev + qty)
	pools["modal"] = int(pools["modal"]) - cost
	stock[iid] = int(stock[iid]) + qty
	stock_cost[iid] = int(stock_cost[iid]) + cost
	changed.emit()
	return true


func servable() -> int:
	var m := 1000000
	for k in stock:
		m = mini(m, int(stock[k]))
	return m


func stock_value() -> int:
	var t := 0
	for k in stock_cost:
		t += int(stock_cost[k])
	return t


func avg_unit_cost(iid: String) -> float:
	var n := int(stock[iid])
	return float(stock_cost[iid]) / float(n) if n > 0 else 0.0


func daily_capacity() -> int:
	return int(chosen("gerobak").get("cap", 0))


func net_worth() -> int:
	var t := 0
	for k in pools:
		t += int(pools[k])
	t += stock_value() + day_cash
	for eid in owned:
		t += int(int(equipment_option(eid, String(owned[eid])).get("buy", 0)) * 0.5)
	return t


# ---------- Cuaca ----------

func roll_weather() -> void:
	var r := rng.randf()
	weather = "cerah" if r < 0.6 else ("mendung" if r < 0.85 else "hujan")


func weather_factor() -> float:
	return {"cerah": 1.0, "mendung": 0.85, "hujan": 0.5}[weather]


# ---------- Fase ----------

func advance_phase() -> void:
	if phase < Phase.TUTUP:
		phase += 1
		changed.emit()


# ---------- Berjualan ----------

func qris_available() -> bool:
	return float(chosen("hp").get("reliab", 0.0)) > 0.0


func qris_usable() -> bool:
	return qris_available() and not bool(sell.get("battery_dead", false))


func begin_selling(sid: String) -> void:
	spot_id = sid
	sell = {
		"hour": OPEN_HOUR, "queue": 0, "served": 0, "lost": 0, "cash": 0, "qris": 0,
		"qris_fail": 0, "tick": 0, "svc_acc": 0.0, "battery_dead": false, "sold_cost": 0.0,
		"done": false, "arrived": 0,
	}
	changed.emit()


func arrival_rate(hour: float) -> float:
	var sp := spot(spot_id)
	var per_hour: float = float(sp["profile"].get(str(int(floor(hour))), 0))
	var per_tick := per_hour * TICK_HOURS * DEMAND_SCALE
	var pf := clampf(pow(12000.0 / float(price), 1.6), 0.15, 2.2)
	var qf := 0.65 + 0.7 * stock_quality * (0.6 + 0.4 * float(rep["kualitas"]) / 100.0)
	var qr := 1.12 if qris_usable() else 1.0
	var rf := 0.8 + 0.4 * float(rep["kualitas"]) / 100.0
	return per_tick * pf * qf * weather_factor() * qr * rf


func _poisson(lambda: float) -> int:
	if lambda <= 0.0:
		return 0
	var l := exp(-lambda)
	var k := 0
	var p := 1.0
	while true:
		k += 1
		p *= rng.randf()
		if p <= l or k > 60:
			break
	return k - 1


## Satu langkah 15 menit. Mengembalikan ringkasan untuk UI.
func tick_sell() -> Dictionary:
	var res := {"arrived": 0, "served": 0, "lost": 0, "habis": false}
	if bool(sell["done"]):
		return res
	var hour: float = sell["hour"]
	var arrive := _poisson(arrival_rate(hour))
	res["arrived"] = arrive
	sell["arrived"] = int(sell["arrived"]) + arrive
	sell["queue"] = int(sell["queue"]) + arrive
	if int(sell["queue"]) > 8:
		var over := int(sell["queue"]) - 8
		sell["lost"] = int(sell["lost"]) + over
		res["lost"] = int(res["lost"]) + over
		sell["queue"] = 8

	var speed: float = float(chosen("kompor").get("speed", 0.7))
	var batch: float = float(chosen("wajan").get("batch", 1))
	var svc := 2.0 * speed * batch * (0.6 + 0.4 * stamina / 100.0)
	sell["svc_acc"] = float(sell["svc_acc"]) + svc
	var can := int(sell["svc_acc"])
	sell["svc_acc"] = float(sell["svc_acc"]) - can
	for i in can:
		if int(sell["queue"]) <= 0:
			break
		var r := _serve_one()
		res["served"] = int(res["served"]) + int(r["served"])
		res["lost"] = int(res["lost"]) + int(r["lost"])
		if bool(r["habis"]):
			res["habis"] = true

	# antrean lama membuat pelanggan pergi
	if int(sell["queue"]) > 5 and rng.randf() < 0.3:
		sell["queue"] = int(sell["queue"]) - 1
		sell["lost"] = int(sell["lost"]) + 1
		res["lost"] = int(res["lost"]) + 1

	# baterai HP
	sell["tick"] = int(sell["tick"]) + 1
	var limit := 44 if String(owned.get("powerbank", "tidak")) == "ada" or String(owned.get("hp", "")) == "bekas" else 28
	if int(sell["tick"]) >= limit and qris_available():
		sell["battery_dead"] = true

	stamina = maxf(0.0, stamina - 0.4)
	sell["hour"] = hour + TICK_HOURS
	if float(sell["hour"]) >= CLOSE_HOUR:
		sell["done"] = true
	changed.emit()
	return res


func _serve_one() -> Dictionary:
	var r := {"served": 0, "lost": 0, "habis": false}
	if servable() <= 0:
		r["lost"] = int(sell["queue"])
		r["habis"] = true
		sell["lost"] = int(sell["lost"]) + int(sell["queue"])
		sell["queue"] = 0
		return r
	var wants_qris := rng.randf() < QRIS_SHARE
	var paid_qris := false
	if wants_qris:
		if qris_usable() and rng.randf() < float(chosen("hp").get("reliab", 0.0)):
			paid_qris = true
		else:
			sell["qris_fail"] = int(sell["qris_fail"]) + 1
			if rng.randf() < 0.5:
				sell["queue"] = int(sell["queue"]) - 1
				sell["lost"] = int(sell["lost"]) + 1
				r["lost"] = 1
				return r
	var cost := 0.0
	for k in stock:
		cost += avg_unit_cost(k)
		stock_cost[k] = int(stock_cost[k]) - int(round(avg_unit_cost(k)))
		stock[k] = int(stock[k]) - 1
	sell["sold_cost"] = float(sell["sold_cost"]) + cost
	sell["queue"] = int(sell["queue"]) - 1
	sell["served"] = int(sell["served"]) + 1
	r["served"] = 1
	if paid_qris:
		sell["qris"] = int(sell["qris"]) + int(round(price * (1.0 - QRIS_FEE)))
	else:
		sell["cash"] = int(sell["cash"]) + price
	return r


func end_selling() -> void:
	var revenue := int(sell["cash"]) + int(sell["qris"])
	var served := int(sell["served"])
	var lost := int(sell["lost"])
	day_cash += revenue
	today = {
		"revenue": revenue, "cogs": int(round(float(sell["sold_cost"]))), "served": served, "lost": lost,
		"qris_fail": int(sell["qris_fail"]), "spot": spot_id,
	}
	stamina = maxf(0.0, stamina - 12.0)
	if served > 0:
		rep["kualitas"] = clampf(float(rep["kualitas"]) + (stock_quality - 0.7) * 6.0, 0.0, 100.0)
	if lost > served and lost > 4:
		rep["kualitas"] = clampf(float(rep["kualitas"]) - 1.5, 0.0, 100.0)
	phase = Phase.TUTUP
	prepare_close()
	changed.emit()


func prepare_close() -> void:
	var rent := int(chosen("gerobak").get("daily", 0))
	var gas := GAS_COST if int(today.get("served", 0)) > 0 else 0
	var spoil := 0
	for ing in data["ingredients"]:
		var iid: String = ing["id"]
		var lost_units := int(floor(float(stock[iid]) * float(ing["perish"])))
		spoil += int(round(avg_unit_cost(iid) * lost_units))
	var revenue := int(today.get("revenue", 0))
	var acc: float = float(chosen("catat").get("accuracy", 0.6))
	var err := (rng.randf() * 2.0 - 1.0) * (1.0 - acc)
	var recorded := int(round(revenue * (1.0 + err)))
	today["rent"] = rent
	today["gas"] = gas
	today["spoil"] = spoil
	today["profit"] = revenue - int(today.get("cogs", 0)) - rent - gas - spoil
	today["alloc"] = revenue - rent - gas
	today["recorded"] = recorded
	today["gap"] = recorded - revenue


## Saran pembagian otomatis: isi modal kerja dulu, lalu biaya hidup, darurat, sisanya ekspansi.
func suggest_split(amount: int) -> Dictionary:
	var left := maxi(amount, 0)
	var res := {"modal": 0, "hidup": 0, "darurat": 0, "ekspansi": 0}
	var need_modal := maxi(0, 70000 - int(pools["modal"]))
	var m := mini(left, need_modal)
	res["modal"] = m
	left -= m
	var need_hidup := maxi(0, LIVING_COST * 3 - int(pools["hidup"]))
	var h := mini(left, need_hidup)
	res["hidup"] = h
	left -= h
	var d := mini(left, int(left * 0.4))
	res["darurat"] = d
	left -= d
	res["ekspansi"] = left
	return res


func confirm_close(split: Dictionary) -> void:
	var alloc: int = int(today.get("alloc", 0))
	if alloc >= 0:
		for k in split:
			pools[k] = int(pools[k]) + int(split[k])
	else:
		pools["modal"] = int(pools["modal"]) + alloc
	# kedaluwarsa
	for ing in data["ingredients"]:
		var iid: String = ing["id"]
		var lost_units := int(floor(float(stock[iid]) * float(ing["perish"])))
		var lost_value := int(round(avg_unit_cost(iid) * lost_units))
		stock[iid] = int(stock[iid]) - lost_units
		stock_cost[iid] = maxi(0, int(stock_cost[iid]) - lost_value)
	journal.append({
		"day": day, "revenue": int(today["revenue"]), "profit": int(today["profit"]),
		"served": int(today["served"]), "lost": int(today["lost"]), "recorded": int(today["recorded"]),
	})
	day_cash = 0
	_next_day()


func _next_day() -> void:
	day += 1
	phase = Phase.PAGI
	var paid := mini(int(pools["hidup"]), LIVING_COST)
	pools["hidup"] = int(pools["hidup"]) - paid
	var short := LIVING_COST - paid
	stamina = clampf(stamina + 55.0 - float(short) / float(LIVING_COST) * 45.0, 10.0, 100.0)
	if short > 0:
		toast.emit("Biaya hidup kurang %s. Tenagamu turun." % Fmt.rp(short))
	roll_weather()
	today = {}
	sell = {}
	spot_id = ""
	if not bab1_done and net_worth() >= BAB1_GOAL:
		bab1_done = true
		toast.emit("Bab 1 selesai! Aset bersihmu sudah %s." % Fmt.rp(net_worth()))
	changed.emit()
