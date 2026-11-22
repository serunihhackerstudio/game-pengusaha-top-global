class_name GameUI
extends CanvasLayer
## HUD dan semua panel keputusan. Logika ada di Sim; ini hanya tampilan.

signal customer_served(count: int)
signal time_changed(hour: float)
signal parked(spot_id: String)
signal setup_finished
signal day_started

const COL_GOLD := Color(1.0, 0.82, 0.3)
const COL_TEXT := Color(0.95, 0.93, 0.88)
const COL_DIM := Color(0.7, 0.68, 0.62)
const COL_GOOD := Color(0.55, 0.9, 0.55)
const COL_BAD := Color(1.0, 0.5, 0.45)
const TICK_REAL := 0.32
const CL_ORDER := ["modal", "hidup", "darurat"]

var root: Control
var modal: Control = null
var modal_open: bool = false

var _top_day: Label
var _top_phase: Label
var _top_clock: Label
var _top_weather: Label
var _stamina: ProgressBar
var _worth: Label
var _pools: Dictionary = {}
var _stock_lbl: Label
var _objective: Label
var _prompt: Button
var _skip: Button
var _toast: Label
var _toast_t: float = 0.0
var prompt_cb: Callable = Callable()

# jualan
var sell_running: bool = false
var sell_paused: bool = false
var _sell_speed: float = 1.0
var _sell_acc: float = 0.0
var _sell_lbls: Dictionary = {}
var _sell_done_btn: Button
var _sell_log: Label
var _sell_log_lines: Array = []

# harga (rencana & jualan)
var _price_lbl: Label

# setup
var _su_opts: Dictionary = {}
var _su_desc: Label
var _su_summary: Label
var _su_sl_modal: HSlider
var _su_sl_hidup: HSlider
var _su_lbl_modal: Label
var _su_lbl_hidup: Label
var _su_lbl_dar: Label
var _su_go: Button

# pasar
var _market_sup: String = "bejo"
var _market_rows: VBoxContainer
var _market_info: Label
var _market_msg: Label
var _market_supp_row: HBoxContainer

# tutup
var _cl_sl: Dictionary = {}
var _cl_lb: Dictionary = {}
var _cl_eks: Label
var _cl_alloc: int = 0


func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var th := Theme.new()
	th.default_font_size = 18
	root.theme = th
	add_child(root)
	_build_hud()
	Sim.changed.connect(_refresh)
	Sim.toast.connect(show_toast)
	_refresh()


# =====================================================
# Util UI
# =====================================================

func _style(bg: Color, border: Color = Color(0, 0, 0, 0), radius: int = 10, pad: int = 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2 if border.a > 0.0 else 0)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	return sb


func _label(text: String, size: int = 18, color: Color = COL_TEXT, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(10, 0)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _button(text: String, cb: Callable, min_w: int = 0, accent: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 40)
	var base := Color(0.85, 0.5, 0.2) if accent else Color(0.28, 0.3, 0.38)
	b.add_theme_stylebox_override("normal", _style(base, Color(1, 1, 1, 0.12), 8, 8))
	b.add_theme_stylebox_override("hover", _style(base.lightened(0.15), Color(1, 1, 1, 0.25), 8, 8))
	b.add_theme_stylebox_override("pressed", _style(base.darkened(0.2), Color(1, 1, 1, 0.12), 8, 8))
	b.add_theme_stylebox_override("disabled", _style(Color(0.2, 0.2, 0.24), Color(1, 1, 1, 0.05), 8, 8))
	b.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.55))
	b.pressed.connect(cb)
	return b


func _row(parent: Node) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	parent.add_child(h)
	return h


## side = panel di tepi kanan tanpa meredupkan layar (adegan tetap terlihat).
func _open_modal(title: String, width: int = 680, side: bool = false) -> VBoxContainer:
	_close_modal()
	modal = Control.new()
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(modal)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, 0)
	panel.add_theme_stylebox_override("panel", _style(Color(0.13, 0.11, 0.14, 0.97 if not side else 0.92), Color(0.84, 0.66, 0.29), 14, 22))
	if side:
		modal.add_child(panel)
		panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
		panel.offset_left = -(width + 16)
		panel.offset_right = -16
		panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	else:
		var dim := ColorRect.new()
		dim.color = Color(0, 0, 0, 0.55)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim.mouse_filter = Control.MOUSE_FILTER_STOP
		modal.add_child(dim)
		var center := CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		modal.add_child(center)
		center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	box.add_child(_label(title, 26, COL_GOLD))
	modal_open = true
	return box


func _close_modal() -> void:
	if modal != null and is_instance_valid(modal):
		modal.queue_free()
	modal = null
	modal_open = false
	sell_running = false


func show_toast(msg: String) -> void:
	_toast.text = msg
	_toast.visible = true
	_toast_t = 4.5


func _price_change(delta: int) -> void:
	Sim.price = clampi(Sim.price + delta, 6500, 25000)
	if _price_lbl != null and is_instance_valid(_price_lbl):
		_price_lbl.text = Fmt.rp(Sim.price)


func _price_row(parent: Node, caption: String) -> void:
	var pr := _row(parent)
	pr.add_child(_label(caption, 18))
	pr.add_child(_button("-500", _price_change.bind(-500), 70))
	_price_lbl = _label(Fmt.rp(Sim.price), 20, COL_GOLD)
	pr.add_child(_price_lbl)
	pr.add_child(_button("+500", _price_change.bind(500), 70))


func _go_next_phase() -> void:
	_close_modal()
	Sim.advance_phase()


# =====================================================
# HUD
# =====================================================

func _build_hud() -> void:
	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", _style(Color(0.1, 0.09, 0.12, 0.88), Color(0.84, 0.66, 0.29, 0.6), 10, 8))
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 12
	top.offset_right = -12
	top.offset_top = 10
	root.add_child(top)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 24)
	top.add_child(h)
	_top_day = _label("Hari 1", 22, COL_GOLD)
	h.add_child(_top_day)
	_top_phase = _label("", 20)
	h.add_child(_top_phase)
	_top_clock = _label("", 20)
	h.add_child(_top_clock)
	_top_weather = _label("", 20)
	h.add_child(_top_weather)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	h.add_child(_label("Tenaga", 16, COL_DIM))
	_stamina = ProgressBar.new()
	_stamina.custom_minimum_size = Vector2(120, 18)
	_stamina.max_value = 100.0
	_stamina.show_percentage = false
	_stamina.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_stamina.add_theme_stylebox_override("background", _style(Color(0.2, 0.2, 0.25), Color(0, 0, 0, 0), 6, 0))
	_stamina.add_theme_stylebox_override("fill", _style(Color(0.4, 0.85, 0.45), Color(0, 0, 0, 0), 6, 0))
	h.add_child(_stamina)
	_worth = _label("", 18, COL_GOOD)
	h.add_child(_worth)

	var left := PanelContainer.new()
	left.add_theme_stylebox_override("panel", _style(Color(0.1, 0.09, 0.12, 0.85), Color(0.84, 0.66, 0.29, 0.45), 10, 10))
	left.position = Vector2(12, 74)
	root.add_child(left)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 2)
	left.add_child(lv)
	lv.add_child(_label("KANTONG UANG", 14, COL_DIM))
	for k in Sim.POOL_NAMES:
		var l := _label("", 18)
		lv.add_child(l)
		_pools[k] = l
	lv.add_child(HSeparator.new())
	_stock_lbl = _label("", 16, COL_DIM)
	lv.add_child(_stock_lbl)

	_objective = _label("", 18, COL_TEXT, true)
	_objective.custom_minimum_size = Vector2(430, 0)
	var op := PanelContainer.new()
	op.add_theme_stylebox_override("panel", _style(Color(0.1, 0.09, 0.12, 0.85), Color(0.84, 0.66, 0.29, 0.45), 10, 10))
	op.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	op.offset_left = 12
	op.offset_bottom = -12
	op.offset_top = -92
	op.offset_right = 470
	op.grow_vertical = Control.GROW_DIRECTION_BEGIN
	op.add_child(_objective)
	root.add_child(op)

	_prompt = _button("", _on_prompt, 260, true)
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.offset_left = -170
	_prompt.offset_right = 170
	_prompt.offset_top = -140
	_prompt.offset_bottom = -90
	_prompt.visible = false
	root.add_child(_prompt)

	_skip = _button("Lanjut ke fase berikut  >", _on_skip, 220)
	_skip.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_skip.offset_left = -240
	_skip.offset_right = -12
	_skip.offset_top = -62
	_skip.offset_bottom = -14
	root.add_child(_skip)

	_toast = _label("", 20, COL_GOLD, true)
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_left = -300
	_toast.offset_right = 300
	_toast.offset_top = 82
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.visible = false
	root.add_child(_toast)


func _on_prompt() -> void:
	if prompt_cb.is_valid():
		prompt_cb.call()


func _on_skip() -> void:
	if Sim.phase == Sim.Phase.BELANJA:
		Sim.advance_phase()


func set_prompt(text: String, cb: Callable) -> void:
	if text == "" or modal_open:
		_prompt.visible = false
		prompt_cb = Callable()
		return
	_prompt.text = text
	_prompt.visible = true
	prompt_cb = cb


func _phase_hour() -> float:
	match Sim.phase:
		Sim.Phase.PAGI:
			return 7.0
		Sim.Phase.BELANJA:
			return 8.5
		Sim.Phase.PERSIAPAN:
			return 9.5
		Sim.Phase.JUALAN:
			if Sim.sell.is_empty():
				return Sim.OPEN_HOUR
			return float(Sim.sell["hour"])
		_:
			return 21.5


func _refresh() -> void:
	if _top_day == null:
		return
	_top_day.text = "Hari %d" % Sim.day
	_top_phase.text = Sim.PHASE_NAMES[Sim.phase]
	var hr := _phase_hour()
	_top_clock.text = Fmt.clock(hr)
	_top_weather.text = {"cerah": "Cerah", "mendung": "Mendung", "hujan": "Hujan"}[Sim.weather]
	_stamina.value = Sim.stamina
	_worth.text = "Aset %s / %s" % [Fmt.rp(Sim.net_worth()), Fmt.rp(Sim.BAB1_GOAL)]
	for k in _pools:
		var l: Label = _pools[k]
		l.text = "%s  %s" % [Sim.POOL_NAMES[k], Fmt.rp(int(Sim.pools[k]))]
	if Sim.setup_done:
		var parts: Array = []
		for ing in Sim.data["ingredients"]:
			parts.append("%s %d" % [ing["name"], int(Sim.stock[ing["id"]])])
		_stock_lbl.text = "Stok: " + ", ".join(parts)
	else:
		_stock_lbl.text = ""
	_skip.visible = Sim.setup_done and Sim.phase == Sim.Phase.BELANJA and not modal_open
	var hints := [
		"Pagi. Pergi ke rumah kos (pintu bercahaya) untuk membuat rencana hari ini.",
		"Pergi ke pasar (sisi kanan) untuk membeli bahan. Tekan Lanjut jika tidak perlu belanja.",
		"Pergi ke gerobakmu untuk bersiap sebelum berangkat.",
		"Dorong gerobak ke salah satu titik jualan (cincin hijau): SD, Kantor, atau Pangkalan Ojol.",
		"Jualan selesai. Kembali ke rumah kos untuk mencatat dan membagi uang.",
	]
	if not Sim.setup_done:
		_objective.text = "Belanja modal awal dulu."
	elif Sim.phase == Sim.Phase.JUALAN and not Sim.sell.is_empty():
		_objective.text = "Sedang berjualan. Atur harga kalau perlu; tutup lapak saat sudah malam."
	else:
		_objective.text = String(hints[Sim.phase])
	time_changed.emit(hr)


func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0:
			_toast.visible = false
	if sell_running and not sell_paused:
		_sell_acc += delta * _sell_speed
		while _sell_acc >= TICK_REAL and sell_running:
			_sell_acc -= TICK_REAL
			_sell_step()


# =====================================================
# Panel: modal awal
# =====================================================

func open_setup() -> void:
	var box := _open_modal("Modal Awal: Rp500.000", 780)
	box.add_child(_label("Uang warisan orang tuamu cuma Rp500.000. Belanja perlengkapan dulu; sisanya jadi modal kerja dan biaya hidup. Tidak semua bisa dibeli, pilih yang paling penting.", 17, COL_DIM, true))
	_su_opts = {}
	for e in Sim.data["equipment"]:
		var row := _row(box)
		var nm := _label(String(e["name"]), 18)
		nm.custom_minimum_size = Vector2(200, 0)
		row.add_child(nm)
		var ob := OptionButton.new()
		ob.custom_minimum_size = Vector2(430, 36)
		var idx := 0
		for o in e["options"]:
			var price_txt := "  (%s)" % Fmt.rp(int(o["buy"])) if int(o["buy"]) > 0 else "  (gratis)"
			ob.add_item(String(o["label"]) + price_txt)
			ob.set_item_metadata(idx, o["id"])
			idx += 1
		ob.item_selected.connect(_setup_changed_i)
		row.add_child(ob)
		_su_opts[e["id"]] = ob
	_su_desc = _label("", 16, COL_DIM, true)
	box.add_child(_su_desc)
	_su_summary = _label("", 20, COL_GOLD)
	box.add_child(_su_summary)
	_su_sl_modal = HSlider.new()
	_su_sl_hidup = HSlider.new()
	for sl in [_su_sl_modal, _su_sl_hidup]:
		sl.step = 5000
		sl.min_value = 0
		sl.custom_minimum_size = Vector2(380, 24)
		sl.value_changed.connect(_setup_changed_v)
	_su_lbl_modal = _label("", 17)
	_su_lbl_hidup = _label("", 17)
	_su_lbl_modal.custom_minimum_size = Vector2(330, 0)
	_su_lbl_hidup.custom_minimum_size = Vector2(330, 0)
	var r1 := _row(box)
	r1.add_child(_su_lbl_modal)
	r1.add_child(_su_sl_modal)
	var r2 := _row(box)
	r2.add_child(_su_lbl_hidup)
	r2.add_child(_su_sl_hidup)
	_su_lbl_dar = _label("", 17)
	box.add_child(_su_lbl_dar)
	_su_go = _button("Mulai Hari 1", _setup_start, 260, true)
	box.add_child(_su_go)
	_su_sl_modal.max_value = 500000
	_su_sl_hidup.max_value = 500000
	_su_sl_modal.value = 150000
	_su_sl_hidup.value = 90000
	_setup_refresh()


func _setup_changed_i(_i: int) -> void:
	_setup_refresh()


func _setup_changed_v(_v: float) -> void:
	_setup_refresh()


func _setup_selection() -> Dictionary:
	var sel := {}
	for eid in _su_opts:
		var ob: OptionButton = _su_opts[eid]
		sel[eid] = String(ob.get_item_metadata(ob.selected))
	return sel


func _setup_refresh() -> void:
	if _su_go == null or not is_instance_valid(_su_go):
		return
	var sel0 := _setup_selection()
	var cb: OptionButton = _su_opts["catat"]
	for i in cb.item_count:
		if String(cb.get_item_metadata(i)) == "aplikasi":
			cb.set_item_disabled(i, String(sel0["hp"]) != "bekas")
			if String(sel0["hp"]) != "bekas" and cb.selected == i:
				cb.select(0)
	var sel := _setup_selection()
	var cost := Sim.setup_cost(sel)
	var left := Sim.START_CASH - cost
	var ds := ""
	for e in Sim.data["equipment"]:
		var o := Sim.equipment_option(String(e["id"]), String(sel[e["id"]]))
		ds += "- %s: %s\n" % [e["name"], String(o.get("desc", ""))]
	_su_desc.text = ds.strip_edges()
	_su_summary.text = "Belanja perlengkapan %s   |   Sisa uang %s" % [Fmt.rp(cost), Fmt.rp(left)]
	_su_summary.add_theme_color_override("font_color", COL_BAD if left < 0 else COL_GOLD)
	var avail := maxi(left, 0)
	_su_sl_modal.set_block_signals(true)
	_su_sl_hidup.set_block_signals(true)
	_su_sl_modal.max_value = avail
	_su_sl_hidup.max_value = avail
	if _su_sl_modal.value > avail:
		_su_sl_modal.value = avail
	if _su_sl_modal.value + _su_sl_hidup.value > avail:
		_su_sl_hidup.value = maxf(0.0, avail - _su_sl_modal.value)
	_su_sl_modal.set_block_signals(false)
	_su_sl_hidup.set_block_signals(false)
	_su_lbl_modal.text = "Modal kerja (belanja bahan)  %s" % Fmt.rp(int(_su_sl_modal.value))
	_su_lbl_hidup.text = "Biaya hidup (makan, kos)  %s" % Fmt.rp(int(_su_sl_hidup.value))
	var dar := avail - int(_su_sl_modal.value) - int(_su_sl_hidup.value)
	_su_lbl_dar.text = "Sisanya ke Dana Darurat  %s" % Fmt.rp(maxi(dar, 0))
	_su_go.disabled = left < 0 or _su_sl_modal.value < 30000


func _setup_start() -> void:
	var sel := _setup_selection()
	var left := Sim.START_CASH - Sim.setup_cost(sel)
	var m := int(_su_sl_modal.value)
	var hd := int(_su_sl_hidup.value)
	if Sim.finish_setup(sel, m, hd, maxi(left - m - hd, 0)):
		_close_modal()
		setup_finished.emit()
		show_toast("Hari 1 dimulai. Semoga untung!")


# =====================================================
# Panel: rencana pagi (di rumah)
# =====================================================

func open_plan() -> void:
	var box := _open_modal("Rencana Pagi - Hari %d" % Sim.day, 700)
	var wtxt := {"cerah": "Cerah. Pembeli normal.", "mendung": "Mendung. Pembeli sedikit berkurang.", "hujan": "Hujan. Pembeli jauh berkurang; pertimbangkan beli bahan lebih sedikit."}
	box.add_child(_label("Prakiraan hari ini: " + String(wtxt[Sim.weather]), 19, COL_TEXT, true))
	box.add_child(_label("Tenaga %d/100   |   Modal kerja %s" % [int(Sim.stamina), Fmt.rp(int(Sim.pools["modal"]))], 18, COL_DIM))
	if not Sim.journal.is_empty():
		var j: Dictionary = Sim.journal[Sim.journal.size() - 1]
		box.add_child(_label("Kemarin: terjual %d porsi, %d pelanggan pergi, laba %s." % [int(j["served"]), int(j["lost"]), Fmt.rp(int(j["profit"]))], 17, COL_DIM, true))
	else:
		box.add_child(_label("Ini hari pertamamu. Tip: beli bahan secukupnya; bahan segar cepat busuk.", 17, COL_DIM, true))
	_price_row(box, "Harga mie goreng per porsi")
	box.add_child(_label("HPP kira-kira Rp6.500 per porsi. Terlalu murah rugi, terlalu mahal sepi.", 16, COL_DIM, true))
	box.add_child(_button("Berangkat ke pasar", _go_next_phase, 280, true))


# =====================================================
# Panel: pasar
# =====================================================

func open_market() -> void:
	var box := _open_modal("Pasar", 780)
	_market_info = _label("", 18, COL_GOLD)
	box.add_child(_market_info)
	_market_supp_row = _row(box)
	_market_rows = VBoxContainer.new()
	_market_rows.add_theme_constant_override("separation", 6)
	box.add_child(_market_rows)
	_market_msg = _label("", 16, COL_BAD)
	box.add_child(_market_msg)
	box.add_child(_label("Satu porsi = 1 mie + 1 telur + 1 bumbu + 1 sayur + 1 kemasan. Stok porsi ditentukan bahan yang paling sedikit.", 15, COL_DIM, true))
	box.add_child(_button("Selesai belanja", _go_next_phase, 260, true))
	_market_rebuild()


func _market_pick(sid: String) -> void:
	_market_sup = sid
	_market_rebuild()


func _market_buy(iid: String, qty: int) -> void:
	if Sim.buy_ingredient(iid, qty, _market_sup):
		_market_msg.text = ""
	elif int(Sim.stock[iid]) + qty > Sim.daily_capacity():
		_market_msg.text = "Gerobakmu tidak muat lebih dari %d porsi." % Sim.daily_capacity()
	else:
		_market_msg.text = "Modal kerja tidak cukup."
	_market_rebuild()


func _market_rebuild() -> void:
	if _market_rows == null or not is_instance_valid(_market_rows):
		return
	for c in _market_rows.get_children():
		c.queue_free()
	for c in _market_supp_row.get_children():
		c.queue_free()
	_market_supp_row.add_child(_label("Beli dari:", 18))
	for s in Sim.data["suppliers"]:
		var sid: String = s["id"]
		_market_supp_row.add_child(_button("%s (%s)" % [s["name"], s["desc"]], _market_pick.bind(sid), 0, _market_sup == sid))
	_market_info.text = "Modal kerja: %s   |   Gerobak muat maks. %d porsi" % [Fmt.rp(int(Sim.pools["modal"])), Sim.daily_capacity()]
	for ing in Sim.data["ingredients"]:
		var iid: String = ing["id"]
		var row := _row(_market_rows)
		var nm := _label(String(ing["name"]), 18)
		nm.custom_minimum_size = Vector2(170, 0)
		row.add_child(nm)
		var st := _label("stok %d" % int(Sim.stock[iid]), 17, COL_DIM)
		st.custom_minimum_size = Vector2(90, 0)
		row.add_child(st)
		var pl := _label("%s/unit" % Fmt.rp(Sim.unit_price(iid, _market_sup)), 17, COL_GOLD)
		pl.custom_minimum_size = Vector2(130, 0)
		row.add_child(pl)
		for q in [1, 5, 10]:
			row.add_child(_button("+%d" % q, _market_buy.bind(iid, q), 56))


# =====================================================
# Panel: persiapan
# =====================================================

func open_prep() -> void:
	var box := _open_modal("Persiapan di Gerobak", 700)
	var sv := Sim.servable()
	box.add_child(_label("Porsi siap dimasak: %d" % sv, 22, COL_GOLD if sv > 0 else COL_BAD))
	if sv <= 0:
		box.add_child(_label("Kamu belum punya bahan lengkap. Tanpa bahan, tidak ada yang bisa dijual hari ini.", 17, COL_BAD, true))
	box.add_child(_label("Gerobak muat %d porsi. Kompor: %s. Wajan: %s." % [
		Sim.daily_capacity(), String(Sim.chosen("kompor").get("label", "")), String(Sim.chosen("wajan").get("label", ""))], 17, COL_DIM, true))
	box.add_child(_label("Mutu bahan: %d%%. Harga jual: %s." % [int(Sim.stock_quality * 100), Fmt.rp(Sim.price)], 17, COL_DIM))
	if Sim.qris_available():
		box.add_child(_label("QRIS siap (%s)." % String(Sim.chosen("hp").get("label", "")), 17, COL_GOOD))
	else:
		box.add_child(_label("Tanpa QRIS: pembeli yang mau bayar non-tunai akan pergi.", 17, COL_BAD))
	box.add_child(_button("Berangkat: dorong gerobak ke titik jualan", _go_next_phase, 380, true))


# =====================================================
# Panel: pilih titik jualan
# =====================================================

func open_spot(sid: String) -> void:
	var sp := Sim.spot(sid)
	var box := _open_modal(String(sp["name"]), 700)
	box.add_child(_label(String(sp["desc"]), 18, COL_TEXT, true))
	var prof: Dictionary = sp["profile"]
	var line := ""
	for h in range(10, 21):
		var v: int = int(prof.get(str(h), 0))
		line += "%02d.00  %s\n" % [h, "#".repeat(clampi(int(round(v / 4.0)), 0, 9))]
	box.add_child(_label(line.strip_edges(), 15, COL_DIM))
	var row := _row(box)
	row.add_child(_button("Parkir di sini & buka lapak", _spot_go.bind(sid), 300, true))
	row.add_child(_button("Pilih tempat lain", _close_modal, 0))


func _spot_go(sid: String) -> void:
	_close_modal()
	parked.emit(sid)


# =====================================================
# Panel: jualan langsung
# =====================================================

func open_sell() -> void:
	var box := _open_modal("Berjualan - %s" % String(Sim.spot(Sim.spot_id)["name"]), 470, true)
	_sell_lbls = {}
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 4)
	box.add_child(grid)
	for k in ["jam", "antre", "terlayani", "hilang", "kas", "qris", "stok", "tenaga"]:
		var l := _label("", 19)
		grid.add_child(l)
		_sell_lbls[k] = l
	_price_row(box, "Harga")
	var sr := _row(box)
	sr.add_child(_label("Kecepatan", 18))
	sr.add_child(_button("Jeda", _toggle_pause, 80))
	for spd in [1.0, 3.0, 8.0]:
		sr.add_child(_button("x%d" % int(spd), _set_speed.bind(spd), 60))
	_sell_log = _label("", 15, COL_DIM, true)
	_sell_log.custom_minimum_size = Vector2(10, 80)
	box.add_child(_sell_log)
	_sell_log_lines = []
	var fr := _row(box)
	fr.add_child(_button("Tutup lapak lebih awal", _finish_sell.bind(true), 240))
	_sell_done_btn = _button("Selesai berjualan", _finish_sell.bind(false), 240, true)
	_sell_done_btn.visible = false
	fr.add_child(_sell_done_btn)
	sell_running = true
	sell_paused = false
	_sell_speed = 1.0
	_sell_acc = 0.0
	_update_sell_labels()


func _toggle_pause() -> void:
	sell_paused = not sell_paused


func _set_speed(s: float) -> void:
	_sell_speed = s


func _update_sell_labels() -> void:
	var s := Sim.sell
	if s.is_empty() or _sell_lbls.is_empty():
		return
	(_sell_lbls["jam"] as Label).text = "Jam %s" % Fmt.clock(float(s["hour"]))
	(_sell_lbls["antre"] as Label).text = "Antrean %d" % int(s["queue"])
	(_sell_lbls["terlayani"] as Label).text = "Terlayani %d porsi" % int(s["served"])
	(_sell_lbls["hilang"] as Label).text = "Pelanggan pergi %d" % int(s["lost"])
	(_sell_lbls["kas"] as Label).text = "Kas tunai %s" % Fmt.rp(int(s["cash"]))
	var qtxt := "QRIS %s" % Fmt.rp(int(s["qris"]))
	if not Sim.qris_available():
		qtxt = "QRIS: tidak ada"
	elif bool(s["battery_dead"]):
		qtxt = "QRIS mati (baterai habis)"
	(_sell_lbls["qris"] as Label).text = qtxt
	(_sell_lbls["stok"] as Label).text = "Stok %d porsi" % Sim.servable()
	(_sell_lbls["tenaga"] as Label).text = "Tenaga %d" % int(Sim.stamina)


func _sell_step() -> void:
	var res := Sim.tick_sell()
	if int(res["served"]) > 0:
		customer_served.emit(int(res["served"]))
	var line := ""
	if bool(res["habis"]):
		line = "Bahan habis! Pelanggan pulang."
	elif int(res["arrived"]) > 0:
		var gone := (", %d pergi" % int(res["lost"])) if int(res["lost"]) > 0 else ""
		line = "%s: %d datang, %d dilayani%s" % [Fmt.clock(float(Sim.sell["hour"])), int(res["arrived"]), int(res["served"]), gone]
	if line != "":
		_sell_log_lines.append(line)
		if _sell_log_lines.size() > 4:
			_sell_log_lines.pop_front()
		_sell_log.text = "\n".join(_sell_log_lines)
	_update_sell_labels()
	time_changed.emit(float(Sim.sell["hour"]))
	if bool(Sim.sell["done"]):
		sell_running = false
		_sell_done_btn.visible = true
		_sell_log_lines.append("Sudah malam. Waktunya tutup.")
		_sell_log.text = "\n".join(_sell_log_lines)


func _finish_sell(early: bool) -> void:
	if early:
		Sim.sell["done"] = true
	sell_running = false
	_close_modal()
	Sim.end_selling()


# =====================================================
# Panel: tutup & catat
# =====================================================

func open_close() -> void:
	var t := Sim.today
	var box := _open_modal("Tutup & Catat - Hari %d" % Sim.day, 760)
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 50)
	box.add_child(g)
	var lines := [
		["Terjual", "%d porsi (%d pelanggan pergi)" % [int(t["served"]), int(t["lost"])]],
		["Omzet", Fmt.rp(int(t["revenue"]))],
		["Harga pokok bahan", "-" + Fmt.rp(int(t["cogs"]))],
		["Sewa gerobak", "-" + Fmt.rp(int(t["rent"]))],
		["Gas", "-" + Fmt.rp(int(t["gas"]))],
		["Bahan busuk", "-" + Fmt.rp(int(t["spoil"]))],
		["LABA HARI INI", Fmt.rp(int(t["profit"]))],
	]
	for ln in lines:
		var is_total: bool = ln[0] == "LABA HARI INI"
		g.add_child(_label(String(ln[0]), 18, COL_GOLD if is_total else COL_DIM))
		var col := COL_TEXT
		if is_total:
			col = COL_GOOD if int(t["profit"]) >= 0 else COL_BAD
		g.add_child(_label(String(ln[1]), 22 if is_total else 18, col))
	var cat := String(Sim.owned.get("catat", "tidak"))
	if cat == "tidak":
		box.add_child(_label("Kamu tidak mencatat. Catatan ngawur: tercatat %s." % Fmt.rp(int(t["recorded"])), 16, COL_BAD, true))
	elif int(t["gap"]) != 0:
		box.add_child(_label("Catatan bukumu meleset: tercatat %s, sebenarnya %s (selisih %s). Aplikasi akan lebih akurat." % [Fmt.rp(int(t["recorded"])), Fmt.rp(int(t["revenue"])), Fmt.rp(absi(int(t["gap"])))], 16, COL_DIM, true))
	else:
		box.add_child(_label("Catatan cocok dengan kas. Rapi.", 16, COL_GOOD))

	_cl_alloc = int(t["alloc"])
	box.add_child(HSeparator.new())
	if _cl_alloc <= 0:
		box.add_child(_label("Kas hari ini tidak cukup untuk dibagi. Kekurangan %s diambil dari Modal Kerja." % Fmt.rp(absi(_cl_alloc)), 17, COL_BAD, true))
		box.add_child(_button("Tidur & mulai hari berikutnya", _close_confirm_empty, 320, true))
		return
	box.add_child(_label("Bagi uang %s ke empat kantong:" % Fmt.rp(_cl_alloc), 19, COL_GOLD))
	var sug := Sim.suggest_split(_cl_alloc)
	_cl_sl = {}
	_cl_lb = {}
	for k in CL_ORDER:
		var r := _row(box)
		var l := _label("", 17)
		l.custom_minimum_size = Vector2(300, 0)
		r.add_child(l)
		var s := HSlider.new()
		s.min_value = 0
		s.max_value = _cl_alloc
		s.step = 1000
		s.custom_minimum_size = Vector2(340, 22)
		s.value_changed.connect(_close_changed)
		r.add_child(s)
		_cl_sl[k] = s
		_cl_lb[k] = l
	_cl_eks = _label("", 17, COL_GOOD)
	box.add_child(_cl_eks)
	for k in CL_ORDER:
		(_cl_sl[k] as HSlider).set_value_no_signal(float(int(sug[k])))
	_close_changed(0.0)
	var br := _row(box)
	br.add_child(_button("Saran otomatis", _close_suggest.bind(sug), 200))
	br.add_child(_button("Tidur & mulai hari berikutnya", _close_confirm, 320, true))


func _close_used() -> int:
	var used := 0
	for k in CL_ORDER:
		used += int((_cl_sl[k] as HSlider).value)
	return used


func _close_changed(_v: float) -> void:
	var used := _close_used()
	if used > _cl_alloc:
		var last: String = CL_ORDER[CL_ORDER.size() - 1]
		var sl: HSlider = _cl_sl[last]
		sl.set_value_no_signal(maxf(0.0, sl.value - (used - _cl_alloc)))
		used = _close_used()
	for k in CL_ORDER:
		(_cl_lb[k] as Label).text = "%s  %s" % [Sim.POOL_NAMES[k], Fmt.rp(int((_cl_sl[k] as HSlider).value))]
	_cl_eks.text = "%s  %s" % [Sim.POOL_NAMES["ekspansi"], Fmt.rp(_cl_alloc - used)]


func _close_suggest(sug: Dictionary) -> void:
	for k in CL_ORDER:
		(_cl_sl[k] as HSlider).set_value_no_signal(float(int(sug[k])))
	_close_changed(0.0)


func _close_confirm() -> void:
	var split := {}
	var used := 0
	for k in CL_ORDER:
		split[k] = int((_cl_sl[k] as HSlider).value)
		used += int(split[k])
	split["ekspansi"] = _cl_alloc - used
	_close_modal()
	Sim.confirm_close(split)
	day_started.emit()


func _close_confirm_empty() -> void:
	_close_modal()
	Sim.confirm_close({"modal": 0, "hidup": 0, "darurat": 0, "ekspansi": 0})
	day_started.emit()
