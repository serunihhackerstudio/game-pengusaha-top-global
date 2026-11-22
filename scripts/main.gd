extends Node3D
## Perekat game: lingkungan, kamera isometrik, interaksi, aliran fase.

const HOME_GEROBAK := Vector3(-3.5, 0.16, 1.2)

var env: Environment
var sun: DirectionalLight3D
var sky_mat: PanoramaSkyMaterial
var tex_day: Texture2D
var tex_dusk: Texture2D
var player: Player
var traffic: Traffic
var cam_rig: Node3D
var cam: Camera3D
var ui: GameUI
var gerobak: Node3D
var spots: Dictionary = {}
var zone_pos: Dictionary = {}
var markers: Dictionary = {}
var _prev_phase: int = -1
var _pulse: float = 0.0
var _sky_is_dusk: bool = false


func _ready() -> void:
	_build_env()
	var info := World.build(self)
	gerobak = info["gerobak"]
	spots = info["spots"]
	zone_pos = info["zones"]

	traffic = Traffic.new()
	add_child(traffic)

	player = Player.new()
	player.position = Vector3(-6.5, 0.16, 1.0)
	add_child(player)

	cam_rig = Node3D.new()
	cam_rig.rotation_degrees.y = 45
	add_child(cam_rig)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 15.0
	cam.near = 0.1
	cam.far = 200.0
	cam.position = Vector3(0, 18.2, 26.0)
	cam.rotation_degrees.x = -35.26
	cam_rig.add_child(cam)
	cam_rig.position = player.position

	ui = GameUI.new()
	add_child(ui)
	ui.setup_finished.connect(_on_setup_finished)
	ui.parked.connect(_on_parked)
	ui.customer_served.connect(_on_customer_served)
	ui.time_changed.connect(_apply_time)
	ui.day_started.connect(_on_day_started)
	Sim.changed.connect(_on_sim_changed)

	_make_markers()
	_apply_time(7.0)
	ui.open_setup()


# =====================================================
# Lingkungan & cahaya
# =====================================================

func _build_env() -> void:
	tex_day = load("res://assets/hdri/kloofendal_48d_partly_cloudy_puresky_1k.hdr")
	tex_dusk = load("res://assets/hdri/aarfontein_dusk_1k.hdr")
	env = Environment.new()
	var sky := Sky.new()
	sky_mat = PanoramaSkyMaterial.new()
	sky_mat.panorama = tex_day
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.85
	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 2.4
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.02
	env.fog_enabled = false
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.12
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.light_energy = 2.4
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.shadow_blur = 1.5
	add_child(sun)


## Mengatur matahari, langit, dan suasana menurut jam.
func _apply_time(hour: float) -> void:
	if sun == null:
		return
	if traffic != null:
		traffic.set_hour(hour)
	var night := hour >= 19.3 or hour < 5.8
	var t := clampf((hour - 6.0) / 13.0, 0.0, 1.0)
	var elev := sin(t * PI) * 62.0 + 4.0
	sun.rotation_degrees = Vector3(-elev, -50.0 + t * 100.0, 0)
	var warm := 1.0 - clampf(elev / 40.0, 0.0, 1.0)
	sun.light_color = Color(1.0, 0.95, 0.88).lerp(Color(1.0, 0.62, 0.35), warm)
	if night:
		sun.light_energy = 0.25
		sun.light_color = Color(0.55, 0.65, 1.0)
		env.ambient_light_energy = 0.25
		env.tonemap_exposure = 0.9
	else:
		sun.light_energy = lerpf(0.8, 2.0, clampf(elev / 50.0, 0.0, 1.0))
		env.ambient_light_energy = lerpf(0.4, 0.6, clampf(elev / 50.0, 0.0, 1.0))
		env.tonemap_exposure = 0.85
	var want_dusk := hour >= 17.5 or hour < 6.5
	if want_dusk != _sky_is_dusk:
		_sky_is_dusk = want_dusk
		sky_mat.panorama = tex_dusk if want_dusk else tex_day


# =====================================================
# Penanda zona
# =====================================================

func _make_markers() -> void:
	var defs := {
		"rumah": ["Rumah Kos", zone_pos["rumah"]],
		"pasar": ["Pasar", zone_pos["pasar"]],
		"gerobak": ["Gerobak", Vector3.ZERO],
		"sd": ["Depan SD", spots["sd"]],
		"kantor": ["Depan Kantor", spots["kantor"]],
		"ojol": ["Pangkalan Ojol", spots["ojol"]],
	}
	for id in defs:
		var g := Node3D.new()
		var ring := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 1.5
		cm.bottom_radius = 1.5
		cm.height = 0.05
		ring.mesh = cm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.4, 1.0, 0.5, 0.35)
		mat.emission_enabled = true
		mat.emission = Color(0.4, 1.0, 0.5)
		mat.emission_energy_multiplier = 1.4
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring.material_override = mat
		g.add_child(ring)
		var lb := Label3D.new()
		lb.text = String(defs[id][0])
		lb.font_size = 56
		lb.pixel_size = 0.012
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lb.no_depth_test = true
		lb.position = Vector3(0, 2.4, 0)
		lb.modulate = Color(1.0, 0.95, 0.7)
		lb.outline_modulate = Color(0, 0, 0, 0.9)
		lb.outline_size = 12
		g.add_child(lb)
		g.visible = false
		add_child(g)
		markers[id] = g
	(markers["rumah"] as Node3D).position = defs["rumah"][1]
	(markers["pasar"] as Node3D).position = defs["pasar"][1]
	for sid in ["sd", "kantor", "ojol"]:
		(markers[sid] as Node3D).position = defs[sid][1] + Vector3(0, 0.02, 1.8)


## Zona aktif menurut fase saat ini.
func _active_zones() -> Array:
	var z: Array = []
	if not Sim.setup_done:
		return z
	match Sim.phase:
		Sim.Phase.PAGI:
			z.append({"id": "rumah", "pos": zone_pos["rumah"], "r": 2.8, "text": "[E] Rencana pagi"})
		Sim.Phase.BELANJA:
			z.append({"id": "pasar", "pos": zone_pos["pasar"], "r": 3.6, "text": "[E] Belanja di pasar"})
		Sim.Phase.PERSIAPAN:
			z.append({"id": "gerobak", "pos": gerobak.global_position + Vector3(0, 0, 2.4), "r": 3.0, "text": "[E] Bersiap di gerobak"})
		Sim.Phase.JUALAN:
			if Sim.sell.is_empty():
				for sid in ["sd", "kantor", "ojol"]:
					z.append({"id": sid, "pos": (spots[sid] as Vector3) + Vector3(0, 0, 1.8), "r": 3.2, "text": "[E] Jualan di %s" % String(Sim.spot(sid)["name"])})
		Sim.Phase.TUTUP:
			z.append({"id": "rumah", "pos": zone_pos["rumah"], "r": 2.8, "text": "[E] Tutup & catat"})
	return z


var _cur_zone: Dictionary = {}


func _process(delta: float) -> void:
	cam_rig.position = cam_rig.position.lerp(player.position, minf(1.0, 4.5 * delta))
	player.enabled = not ui.modal_open
	_pulse += delta
	var zones := _active_zones()
	var active_ids: Array = []
	_cur_zone = {}
	var best := 1e9
	for zn in zones:
		active_ids.append(zn["id"])
		var d: float = Vector2(player.position.x - (zn["pos"] as Vector3).x, player.position.z - (zn["pos"] as Vector3).z).length()
		if d < float(zn["r"]) and d < best:
			best = d
			_cur_zone = zn
	for id in markers:
		var m: Node3D = markers[id]
		var on := active_ids.has(id)
		m.visible = on
		if on:
			var s := 1.0 + sin(_pulse * 3.0) * 0.06
			m.scale = Vector3(s, 1, s)
	if Sim.phase == Sim.Phase.PERSIAPAN and Sim.setup_done:
		(markers["gerobak"] as Node3D).position = gerobak.global_position + Vector3(0, 0.02, 2.4)
	if _cur_zone.is_empty():
		ui.set_prompt("", Callable())
	else:
		ui.set_prompt(String(_cur_zone["text"]), _interact)


func _interact() -> void:
	if _cur_zone.is_empty() or ui.modal_open:
		return
	player.stop()
	match String(_cur_zone["id"]):
		"rumah":
			if Sim.phase == Sim.Phase.PAGI:
				ui.open_plan()
			else:
				ui.open_close()
		"pasar":
			ui.open_market()
		"gerobak":
			ui.open_prep()
		"sd", "kantor", "ojol":
			ui.open_spot(String(_cur_zone["id"]))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_interact()
		return
	if ui.modal_open:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var o := cam.project_ray_origin(event.position)
		var n := cam.project_ray_normal(event.position)
		if absf(n.y) > 0.001:
			var t := -o.y / n.y
			player.move_to(o + n * t)
	elif event is InputEventScreenTouch and event.pressed:
		var o2 := cam.project_ray_origin(event.position)
		var n2 := cam.project_ray_normal(event.position)
		if absf(n2.y) > 0.001:
			player.move_to(o2 + n2 * (-o2.y / n2.y))


# =====================================================
# Aliran game
# =====================================================

func _on_setup_finished() -> void:
	_apply_time(7.0)


func _on_sim_changed() -> void:
	if _prev_phase == Sim.Phase.JUALAN and Sim.phase == Sim.Phase.TUTUP:
		ui.show_toast("Lapak tutup. Kembali ke rumah kos untuk mencatat.")
	_prev_phase = Sim.phase


func _on_parked(sid: String) -> void:
	Sim.begin_selling(sid)
	var dest: Vector3 = spots[sid]
	var tw := create_tween()
	tw.tween_property(gerobak, "position", dest, 0.9).set_trans(Tween.TRANS_SINE)
	player.global_position = dest + Vector3(-1.0, 0, 2.3)
	player.stop()
	tw.tween_interval(0.3)
	tw.tween_callback(ui.open_sell)


func _on_day_started() -> void:
	gerobak.position = HOME_GEROBAK
	player.global_position = Vector3(-8.5, 0.16, -2.0)
	player.stop()
	_apply_time(7.0)
	ui.show_toast("Hari %d dimulai." % Sim.day)


func _on_customer_served(n: int) -> void:
	for i in n:
		_spawn_customer()


func _spawn_customer() -> void:
	var shirts := [Color(0.7, 0.25, 0.2), Color(0.2, 0.4, 0.65), Color(0.85, 0.65, 0.2), Color(0.3, 0.55, 0.35), Color(0.55, 0.35, 0.6), Color(0.9, 0.9, 0.88)]
	var cust_opts := {"hair": ["short", "side", "long", "short"].pick_random()}
	if randf() < 0.2:
		cust_opts["hat"] = "peci"
	elif randf() < 0.25:
		cust_opts["hat"] = "hijab"
		cust_opts["hat_color"] = Color(0.5, 0.3, 0.55)
	var p := World.person(shirts.pick_random(), Color(0.2, 0.22, 0.3), Color(0.74, 0.52, 0.36).lerp(Color(0.5, 0.33, 0.22), randf()), Color(0.08, 0.06, 0.05), cust_opts)
	add_child(p)
	var cart := gerobak.global_position
	var side := -1.0 if randf() < 0.5 else 1.0
	var start := Vector3(cart.x + side * 9.0, 0.16, 2.9 + randf_range(-0.4, 0.4))
	var dest := Vector3(cart.x + randf_range(-0.7, 0.7), 0.16, cart.z + 2.0)
	var out := Vector3(cart.x - side * 9.0, 0.16, 3.0)
	p.position = start
	p.rotation.y = atan2(dest.x - start.x, dest.z - start.z)
	var walk := func(v: float) -> void:
		if is_instance_valid(p):
			World.animate_person(p, v, 1.0)
	var idle := func(_v: float) -> void:
		if is_instance_valid(p):
			World.animate_person(p, 0.0, 0.0)
	var tw := p.create_tween()
	tw.set_parallel(true)
	tw.tween_property(p, "position", dest, 2.0)
	tw.tween_method(walk, 0.0, 22.0, 2.0)
	tw.set_parallel(false)
	tw.tween_callback(func(): p.rotation.y = PI)
	tw.tween_callback(func(): World.animate_person(p, 0.0, 0.0))
	tw.tween_interval(0.9)
	tw.tween_callback(func(): p.rotation.y = atan2(out.x - dest.x, out.z - dest.z))
	tw.set_parallel(true)
	tw.tween_property(p, "position", out, 2.6)
	tw.tween_method(walk, 0.0, 28.0, 2.6)
	tw.set_parallel(false)
	tw.tween_callback(p.queue_free)
