class_name World
extends RefCounted
## Pembangun lokasi "Gang Mawar" (vertical slice). Geometri sederhana + material PBR foto-nyata (CC0).

static var _mat_cache: Dictionary = {}


## Material PBR dari assets/textures/<name>/{diff,nor,arm}.jpg, dipetakan triplanar dunia.
static func pbr(tex_name: String, scale: float = 0.5, tint: Color = Color.WHITE) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [tex_name, scale, tint.to_html()]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	var base := "res://assets/textures/%s/" % tex_name
	m.albedo_texture = load(base + "diff.jpg")
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = load(base + "nor.jpg")
	var arm: Texture2D = load(base + "arm.jpg")
	m.ao_enabled = true
	m.ao_texture = arm
	m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.roughness_texture = arm
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	m.metallic_texture = arm
	m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	m.metallic = 1.0
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	_mat_cache[key] = m
	return m


static func flat(c: Color, rough: float = 0.8, metal: float = 0.0, emit: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m


static func glass(c: Color = Color(0.15, 0.22, 0.3)) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.08
	m.metallic = 0.9
	return m


## Kotak dengan pos = tengah-bawah.
static func box(parent: Node, size: Vector3, pos: Vector3, mat: Material, solid: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos + Vector3(0, size.y / 2.0, 0)
	parent.add_child(mi)
	if solid:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		sb.add_child(cs)
		mi.add_child(sb)
	return mi


static func cyl(parent: Node, r: float, h: float, pos: Vector3, mat: Material, r2: float = -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r if r2 < 0.0 else r2
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 20
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos + Vector3(0, h / 2.0, 0)
	parent.add_child(mi)
	return mi


static func sphere(parent: Node, r: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


## Atap pelana: bubungan sejajar sumbu X.
static func gable(parent: Node, w: float, d: float, h: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(d, h, w)
	mi.mesh = pm
	mi.material_override = mat
	mi.rotation_degrees = Vector3(0, 90, 0)
	mi.position = pos + Vector3(0, h / 2.0, 0)
	parent.add_child(mi)
	return mi


# ---------- Bangunan ----------

static func ruko(parent: Node, pos: Vector3, w: float, floors: int, wall_tint: Color, awning: Color) -> void:
	var fh := 3.0
	var h := floors * fh
	var d := 7.0
	box(parent, Vector3(w, h, d), pos, pbr("beige_wall_001", 0.35, wall_tint), true)
	gable(parent, w + 0.6, d + 1.0, 1.8, pos + Vector3(0, h, 0), pbr("clay_roof_tiles", 0.4, Color(1.0, 0.85, 0.8)))
	box(parent, Vector3(w * 0.84, 2.3, 0.12), pos + Vector3(0, 0.1, d / 2.0 + 0.02), flat(Color(1.0, 0.83, 0.5), 0.5, 0.0, 1.2))
	var aw := box(parent, Vector3(w * 0.94, 0.12, 1.5), pos + Vector3(0, 2.7, d / 2.0 + 0.7), flat(awning, 0.7))
	aw.rotation_degrees.x = 12
	for f in range(1, floors):
		var n := maxi(2, int(w / 2.4))
		for k in n:
			var x := -w / 2.0 + (w / n) * (k + 0.5)
			box(parent, Vector3(1.3, 1.6, 0.12), pos + Vector3(x, f * fh + 0.7, d / 2.0 + 0.04), glass())
			box(parent, Vector3(1.6, 0.14, 0.4), pos + Vector3(x, f * fh + 0.55, d / 2.0 + 0.12), flat(Color(0.88, 0.85, 0.78)))


static func tree(parent: Node, pos: Vector3, s: float = 1.0) -> void:
	var g := Node3D.new()
	g.position = pos
	g.scale = Vector3.ONE * s
	parent.add_child(g)
	cyl(g, 0.22, 2.4, Vector3.ZERO, pbr("wood_plank_wall", 0.6, Color(0.6, 0.5, 0.4)), 0.15)
	var leaf := flat(Color(0.22, 0.46, 0.2), 0.9)
	sphere(g, 1.7, Vector3(0, 3.6, 0), leaf)
	sphere(g, 1.2, Vector3(1.1, 3.0, 0.4), flat(Color(0.28, 0.52, 0.22), 0.9))
	sphere(g, 1.3, Vector3(-1.0, 3.2, -0.5), leaf)


static func lamp(parent: Node, pos: Vector3) -> void:
	var g := Node3D.new()
	g.position = pos
	parent.add_child(g)
	cyl(g, 0.08, 5.2, Vector3.ZERO, flat(Color(0.2, 0.2, 0.22), 0.5, 0.6), 0.06)
	box(g, Vector3(1.2, 0.1, 0.12), Vector3(0.55, 5.2, 0), flat(Color(0.2, 0.2, 0.22), 0.5, 0.6))
	sphere(g, 0.22, Vector3(1.1, 5.1, 0), flat(Color(1.0, 0.9, 0.65), 0.4, 0.0, 3.0))
	var l := OmniLight3D.new()
	l.position = Vector3(1.1, 4.8, 0)
	l.light_color = Color(1.0, 0.85, 0.6)
	l.light_energy = 1.2
	l.omni_range = 9.0
	g.add_child(l)


static func pole(parent: Node, pos: Vector3) -> void:
	var g := Node3D.new()
	g.position = pos
	parent.add_child(g)
	cyl(g, 0.16, 9.0, Vector3.ZERO, pbr("grey_plaster", 0.5, Color(0.7, 0.7, 0.7)), 0.12)
	box(g, Vector3(0.14, 0.12, 2.8), Vector3(0, 8.4, 0), flat(Color(0.3, 0.27, 0.24)))
	box(g, Vector3(0.14, 0.12, 2.2), Vector3(0, 7.5, 0), flat(Color(0.3, 0.27, 0.24)))


# ---------- Manusia sederhana (pengganti model nyata) ----------

static func person_old(shirt: Color, pants: Color, skin: Color = Color(0.74, 0.52, 0.36), hair: Color = Color(0.08, 0.06, 0.05)) -> Node3D:
	var g := Node3D.new()
	var cm := flat(shirt, 0.85)
	var pm := flat(pants, 0.85)
	var sk := flat(skin, 0.7)
	var legs := Node3D.new()
	legs.name = "Legs"
	g.add_child(legs)
	for x in [-0.12, 0.12]:
		var leg := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 0.09
		cap.height = 0.85
		leg.mesh = cap
		leg.material_override = pm
		leg.position = Vector3(x, 0.45, 0)
		legs.add_child(leg)
	var torso := MeshInstance3D.new()
	var tc := CapsuleMesh.new()
	tc.radius = 0.2
	tc.height = 0.78
	torso.mesh = tc
	torso.material_override = cm
	torso.position = Vector3(0, 1.1, 0)
	torso.scale = Vector3(1.15, 1, 0.7)
	g.add_child(torso)
	for x in [-0.3, 0.3]:
		var arm := MeshInstance3D.new()
		var ac := CapsuleMesh.new()
		ac.radius = 0.06
		ac.height = 0.7
		arm.mesh = ac
		arm.material_override = cm
		arm.position = Vector3(x, 1.12, 0)
		g.add_child(arm)
		sphere(g, 0.055, Vector3(x, 0.74, 0), sk)
	sphere(g, 0.16, Vector3(0, 1.62, 0), sk).scale = Vector3(0.92, 1.08, 1.0)
	var hs := sphere(g, 0.165, Vector3(0, 1.69, -0.015), flat(hair, 0.6))
	hs.scale = Vector3(1.0, 0.72, 1.04)
	return g


# ---------- Manusia bersendi ----------

## Mesh bantu berpusat di `center` (bukan di dasar).
static func _bx(parent: Node, size: Vector3, center: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = center
	parent.add_child(mi)
	return mi


static func _cap(parent: Node, length: float, r: float, center: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = r
	cm.height = maxf(length + r * 1.2, r * 2.0)
	cm.radial_segments = 14
	cm.rings = 6
	mi.mesh = cm
	mi.material_override = mat
	mi.position = center
	parent.add_child(mi)
	return mi


static func _ball(parent: Node, r: float, center: Vector3, mat: Material, sc: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 20
	sm.rings = 12
	mi.mesh = sm
	mi.material_override = mat
	mi.position = center
	mi.scale = sc
	parent.add_child(mi)
	return mi


## Satu lengan: bahu -> siku -> pergelangan -> tangan berjari. Mengembalikan {shoulder, elbow}.
static func _arm(parent: Node, side: float, sleeve_mat: Material, fore_mat: Material, skin_mat: Material) -> Dictionary:
	var sh := Node3D.new()
	sh.position = Vector3(0.235 * side, 1.4, 0)
	parent.add_child(sh)
	_ball(sh, 0.056, Vector3.ZERO, sleeve_mat)
	_cap(sh, 0.3, 0.05, Vector3(0, -0.15, 0), sleeve_mat)
	var el := Node3D.new()
	el.position = Vector3(0, -0.3, 0)
	sh.add_child(el)
	_ball(el, 0.048, Vector3.ZERO, fore_mat)
	_cap(el, 0.26, 0.043, Vector3(0, -0.14, 0), fore_mat)
	var hand := Node3D.new()
	hand.position = Vector3(0, -0.3, 0)
	el.add_child(hand)
	_bx(hand, Vector3(0.075, 0.085, 0.036), Vector3(0, -0.03, 0), skin_mat)
	_bx(hand, Vector3(0.07, 0.06, 0.028), Vector3(0, -0.095, 0.002), skin_mat)
	for i in 4:
		_bx(hand, Vector3(0.012, 0.045, 0.02), Vector3(-0.027 + i * 0.018, -0.14, 0.004), skin_mat)
	var th := _cap(hand, 0.04, 0.012, Vector3(0.045 * side * -1.0, -0.05, 0.012), skin_mat)
	th.rotation_degrees.z = 25 * side
	return {"shoulder": sh, "elbow": el}


## Manusia bersendi dengan wajah, tangan, kaki. opts: hair (short|side|long|none), hat (peci|hijab|cap|helmet),
## long_sleeve, sit, shoes (Color), hat_color (Color).
static func person(shirt: Color, pants: Color, skin: Color = Color(0.74, 0.52, 0.36), hair: Color = Color(0.08, 0.06, 0.05), opts: Dictionary = {}) -> Node3D:
	var g := Node3D.new()
	var style: String = opts.get("hair", "short")
	var hat: String = opts.get("hat", "")
	var long_sleeve: bool = opts.get("long_sleeve", false)
	var sit: bool = opts.get("sit", false)
	var shoe_col: Color = opts.get("shoes", Color(0.12, 0.12, 0.14))
	var hat_col: Color = opts.get("hat_color", Color(0.1, 0.1, 0.12))
	var m_shirt := flat(shirt, 0.85)
	var m_pants := flat(pants, 0.85)
	var m_skin := flat(skin, 0.62)
	var m_skin_d := flat(skin.darkened(0.14), 0.7)
	var m_hair := flat(hair, 0.55)
	var m_shoe := flat(shoe_col, 0.6)
	var body := Node3D.new()
	body.name = "Body"
	g.add_child(body)
	if sit:
		body.position.y = -0.42

	# kaki
	var legs := {}
	for side in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(0.1 * side, 0.92, 0)
		body.add_child(hip)
		_ball(hip, 0.092, Vector3.ZERO, m_pants)
		_cap(hip, 0.44, 0.085, Vector3(0, -0.22, 0), m_pants)
		var knee := Node3D.new()
		knee.position = Vector3(0, -0.44, 0)
		hip.add_child(knee)
		_ball(knee, 0.068, Vector3.ZERO, m_pants)
		_cap(knee, 0.42, 0.064, Vector3(0, -0.22, 0), m_pants)
		var foot := Node3D.new()
		foot.position = Vector3(0, -0.45, 0)
		knee.add_child(foot)
		_bx(foot, Vector3(0.105, 0.075, 0.27), Vector3(0, -0.02, 0.06), m_shoe)
		_bx(foot, Vector3(0.105, 0.02, 0.27), Vector3(0, -0.062, 0.06), flat(Color(0.85, 0.85, 0.85), 0.8))
		legs[side] = {"hip": hip, "knee": knee}

	# panggul, badan, leher
	_bx(body, Vector3(0.36, 0.18, 0.22), Vector3(0, 0.93, 0), m_pants)
	var torso := _cap(body, 0.34, 0.18, Vector3(0, 1.17, 0), m_shirt)
	torso.scale = Vector3(1.18, 1.0, 0.72)
	_bx(body, Vector3(0.38, 0.045, 0.25), Vector3(0, 0.98, 0), flat(Color(0.1, 0.09, 0.09), 0.5))
	_bx(body, Vector3(0.2, 0.045, 0.17), Vector3(0, 1.43, 0.0), flat(shirt.darkened(0.12), 0.85))
	_cap(body, 0.08, 0.05, Vector3(0, 1.49, 0), m_skin_d)

	# lengan
	var sleeve_fore: Material = m_shirt if long_sleeve else m_skin
	var arm_l := _arm(body, -1.0, m_shirt, sleeve_fore, m_skin)
	var arm_r := _arm(body, 1.0, m_shirt, sleeve_fore, m_skin)

	# kepala
	var head := Node3D.new()
	head.position = Vector3(0, 1.64, 0)
	body.add_child(head)
	_ball(head, 0.125, Vector3.ZERO, m_skin, Vector3(0.92, 1.1, 1.0))
	for s in [-1.0, 1.0]:
		_ball(head, 0.03, Vector3(0.115 * s, -0.01, 0), m_skin_d, Vector3(0.55, 1.0, 0.8))
		_ball(head, 0.021, Vector3(0.046 * s, 0.02, 0.108), flat(Color(0.97, 0.96, 0.93), 0.4), Vector3(1.2, 0.8, 0.5))
		_ball(head, 0.011, Vector3(0.046 * s, 0.019, 0.117), flat(Color(0.06, 0.04, 0.03), 0.3))
		_bx(head, Vector3(0.05, 0.011, 0.012), Vector3(0.048 * s, 0.056, 0.108), m_hair if style != "none" else flat(Color(0.1, 0.08, 0.07)))
	_ball(head, 0.02, Vector3(0, -0.02, 0.122), flat(skin.lightened(0.05), 0.6), Vector3(0.9, 1.1, 1.0))
	_bx(head, Vector3(0.05, 0.009, 0.012), Vector3(0, -0.07, 0.108), flat(Color(0.5, 0.18, 0.16), 0.5))
	# rambut
	if style != "none" and hat != "hijab":
		_ball(head, 0.13, Vector3(0, 0.082, -0.022), m_hair, Vector3(1.0, 0.64, 1.04))
		if style == "side":
			var fr := _bx(head, Vector3(0.17, 0.035, 0.07), Vector3(0.03, 0.118, 0.07), m_hair)
			fr.rotation_degrees = Vector3(18, 0, -10)
		elif style == "long":
			_bx(head, Vector3(0.27, 0.34, 0.07), Vector3(0, -0.12, -0.085), m_hair)
	# penutup kepala
	if hat == "peci":
		var pm := cyl(head, 0.1, 0.1, Vector3(0, 0.07, 0), flat(hat_col, 0.7), 0.118)
		pm.position.y = 0.12
	elif hat == "hijab":
		var hj := flat(hat_col, 0.85)
		_ball(head, 0.142, Vector3(0, 0.025, -0.04), hj, Vector3(1.05, 1.15, 1.05))
		_cap(head, 0.1, 0.15, Vector3(0, -0.15, -0.035), hj).scale = Vector3(1.15, 1.0, 0.8)
		_bx(head, Vector3(0.18, 0.025, 0.06), Vector3(0, 0.1, 0.085), hj).rotation_degrees.x = 20
	elif hat == "cap":
		var cp := _ball(head, 0.13, Vector3(0, 0.07, -0.005), flat(hat_col, 0.7), Vector3(1.0, 0.6, 1.06))
		cp.name = "Cap"
		_bx(head, Vector3(0.17, 0.018, 0.12), Vector3(0, 0.07, 0.115), flat(hat_col.darkened(0.15), 0.7))
	elif hat == "helmet":
		_ball(head, 0.158, Vector3(0, 0.035, -0.005), flat(hat_col, 0.28, 0.4), Vector3(1.0, 0.92, 1.08))
		_bx(head, Vector3(0.2, 0.035, 0.09), Vector3(0, 0.075, 0.115), glass(Color(0.1, 0.13, 0.18)))

	g.set_meta("rig", {
		"body": body, "sit": sit,
		"hl": legs[-1.0]["hip"], "hr": legs[1.0]["hip"], "kl": legs[-1.0]["knee"], "kr": legs[1.0]["knee"],
		"al": arm_l["shoulder"], "ar": arm_r["shoulder"], "el": arm_l["elbow"], "er": arm_r["elbow"],
		"head": head,
	})
	if sit:
		(legs[-1.0]["hip"] as Node3D).rotation.x = -1.45
		(legs[1.0]["hip"] as Node3D).rotation.x = -1.45
		(legs[-1.0]["knee"] as Node3D).rotation.x = 1.5
		(legs[1.0]["knee"] as Node3D).rotation.x = 1.5
		(arm_l["shoulder"] as Node3D).rotation.x = -0.9
		(arm_r["shoulder"] as Node3D).rotation.x = -0.9
		(arm_l["elbow"] as Node3D).rotation.x = -0.5
		(arm_r["elbow"] as Node3D).rotation.x = -0.5
	return g


## Animasi jalan: phase = fase gerak, amount 0 (diam) .. 1 (jalan penuh). Aman dipanggil tiap frame.
static func animate_person(p: Node3D, phase: float, amount: float) -> void:
	if not p.has_meta("rig"):
		return
	var r: Dictionary = p.get_meta("rig")
	if bool(r["sit"]):
		return
	var s := sin(phase)
	(r["hl"] as Node3D).rotation.x = s * 0.62 * amount
	(r["hr"] as Node3D).rotation.x = -s * 0.62 * amount
	(r["kl"] as Node3D).rotation.x = maxf(0.0, s) * 0.85 * amount
	(r["kr"] as Node3D).rotation.x = maxf(0.0, -s) * 0.85 * amount
	(r["al"] as Node3D).rotation.x = -s * 0.5 * amount
	(r["ar"] as Node3D).rotation.x = s * 0.5 * amount
	(r["el"] as Node3D).rotation.x = -0.12 - maxf(0.0, s) * 0.35 * amount
	(r["er"] as Node3D).rotation.x = -0.12 - maxf(0.0, -s) * 0.35 * amount
	var b: Node3D = r["body"]
	b.position.y = absf(sin(phase)) * 0.035 * amount
	(r["head"] as Node3D).rotation.y = sin(phase * 0.5) * 0.06 * amount


# ---------- Kendaraan (panjang di sumbu X, menghadap +X) ----------

static func _wheel(parent: Node, pos: Vector3, r: float, w: float) -> void:
	var tire := cyl(parent, r, w, Vector3.ZERO, flat(Color(0.06, 0.06, 0.07), 0.9))
	tire.position = pos
	tire.rotation_degrees.x = 90
	var rim := cyl(parent, r * 0.55, w + 0.02, Vector3.ZERO, flat(Color(0.7, 0.7, 0.72), 0.3, 0.9))
	rim.position = pos
	rim.rotation_degrees.x = 90


static func _lights(parent: Node, front_x: float, back_x: float, y: float, z: float, size: float = 0.12) -> void:
	for s in [-1.0, 1.0]:
		sphere(parent, size, Vector3(front_x, y, z * s), flat(Color(1.0, 0.95, 0.75), 0.3, 0.0, 2.6))
		sphere(parent, size * 0.8, Vector3(back_x, y, z * s), flat(Color(1.0, 0.15, 0.1), 0.3, 0.0, 2.0))


static func car(color: Color) -> Node3D:
	var g := Node3D.new()
	var paint := flat(color, 0.28, 0.6)
	box(g, Vector3(4.2, 0.7, 1.8), Vector3(0, 0.35, 0), paint)
	box(g, Vector3(2.3, 0.62, 1.6), Vector3(-0.2, 1.05, 0), paint)
	box(g, Vector3(2.0, 0.42, 1.64), Vector3(-0.2, 1.12, 0), glass())
	box(g, Vector3(1.0, 0.1, 1.62), Vector3(1.55, 1.0, 0), paint)
	for x in [-1.35, 1.35]:
		for z in [-0.92, 0.92]:
			_wheel(g, Vector3(x, 0.36, z), 0.36, 0.22)
	_lights(g, 2.1, -2.1, 0.62, 0.62)
	return g


static func van(color: Color) -> Node3D:
	var g := Node3D.new()
	var paint := flat(color, 0.35, 0.5)
	box(g, Vector3(4.8, 1.5, 1.9), Vector3(0, 0.35, 0), paint)
	box(g, Vector3(3.7, 0.55, 1.94), Vector3(-0.3, 1.2, 0), glass())
	box(g, Vector3(4.8, 0.14, 1.95), Vector3(0, 0.9, 0), flat(Color(0.95, 0.95, 0.9), 0.5))
	box(g, Vector3(2.6, 0.08, 1.4), Vector3(-0.5, 1.9, 0), flat(Color(0.3, 0.3, 0.33), 0.6, 0.6))
	for x in [-1.5, 1.5]:
		for z in [-0.95, 0.95]:
			_wheel(g, Vector3(x, 0.38, z), 0.38, 0.24)
	_lights(g, 2.4, -2.4, 0.7, 0.65)
	return g


static func truck(cab_color: Color, box_color: Color) -> Node3D:
	var g := Node3D.new()
	box(g, Vector3(2.0, 2.0, 2.3), Vector3(2.4, 0.5, 0), flat(cab_color, 0.4, 0.4))
	box(g, Vector3(0.12, 0.9, 2.0), Vector3(3.43, 1.35, 0), glass())
	box(g, Vector3(6.2, 0.35, 2.3), Vector3(-1.0, 0.5, 0), flat(Color(0.2, 0.2, 0.22), 0.7))
	box(g, Vector3(5.6, 2.6, 2.4), Vector3(-1.3, 0.85, 0), flat(box_color, 0.5, 0.2))
	for x in [-3.0, -1.8, 2.6]:
		for z in [-1.15, 1.15]:
			_wheel(g, Vector3(x, 0.5, z), 0.5, 0.3)
	_lights(g, 3.45, -4.15, 0.95, 0.8, 0.14)
	return g


static func bus(color: Color) -> Node3D:
	var g := Node3D.new()
	box(g, Vector3(9.2, 3.0, 2.5), Vector3(0, 0.5, 0), flat(color, 0.4, 0.4))
	box(g, Vector3(8.4, 1.0, 2.54), Vector3(-0.2, 1.9, 0), glass())
	box(g, Vector3(9.2, 0.16, 2.54), Vector3(0, 1.3, 0), flat(Color(0.95, 0.94, 0.88), 0.5))
	for x in [-3.0, 3.0]:
		for z in [-1.2, 1.2]:
			_wheel(g, Vector3(x, 0.55, z), 0.55, 0.3)
	_lights(g, 4.62, -4.62, 0.9, 0.9, 0.15)
	return g


static func motorbike(color: Color, rider_shirt: Color) -> Node3D:
	var g := Node3D.new()
	var paint := flat(color, 0.3, 0.5)
	box(g, Vector3(1.6, 0.4, 0.45), Vector3(0, 0.4, 0), paint)
	box(g, Vector3(0.9, 0.14, 0.42), Vector3(-0.25, 0.85, 0), flat(Color(0.07, 0.07, 0.08), 0.8))
	box(g, Vector3(0.12, 0.55, 0.5), Vector3(0.65, 0.8, 0), paint)
	box(g, Vector3(0.08, 0.06, 0.8), Vector3(0.62, 1.32, 0), flat(Color(0.1, 0.1, 0.12), 0.5, 0.7))
	sphere(g, 0.11, Vector3(0.78, 1.0, 0), flat(Color(1.0, 0.95, 0.75), 0.3, 0.0, 2.6))
	_wheel(g, Vector3(0.62, 0.33, 0), 0.33, 0.14)
	_wheel(g, Vector3(-0.62, 0.33, 0), 0.33, 0.16)
	var rider := person(rider_shirt, Color(0.15, 0.17, 0.25), Color(0.7, 0.5, 0.35), Color(0.08, 0.06, 0.05), {"sit": true, "hat": "helmet", "hat_color": rider_shirt.darkened(0.2), "long_sleeve": true})
	rider.position = Vector3(-0.15, 0.4, 0)
	rider.rotation_degrees.y = 90
	g.add_child(rider)
	return g


# ---------- Gerobak ----------

static func gerobak() -> Node3D:
	var g := Node3D.new()
	var wood := pbr("wood_plank_wall", 0.8, Color(0.85, 0.7, 0.5))
	var iron := pbr("corrugated_iron", 0.6, Color(0.35, 0.5, 0.75))
	box(g, Vector3(2.2, 0.9, 1.1), Vector3(0, 0.4, 0), wood, true)
	box(g, Vector3(2.3, 0.08, 1.2), Vector3(0, 1.3, 0), pbr("wood_plank_wall", 0.8, Color(1, 0.92, 0.8)))
	var disp := box(g, Vector3(1.7, 0.6, 0.9), Vector3(0.15, 1.38, 0.05), flat(Color(0.8, 0.9, 1.0), 0.05))
	var gm: StandardMaterial3D = disp.material_override
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.albedo_color = Color(0.8, 0.9, 1.0, 0.28)
	box(g, Vector3(0.28, 0.2, 0.28), Vector3(-0.3, 1.38, 0.05), flat(Color(0.9, 0.62, 0.22)))
	box(g, Vector3(0.28, 0.16, 0.28), Vector3(0.1, 1.38, 0.1), flat(Color(0.85, 0.54, 0.18)))
	cyl(g, 0.38, 0.14, Vector3(-1.4, 1.38, 0), flat(Color(0.12, 0.12, 0.13), 0.35, 0.8))
	cyl(g, 0.22, 0.7, Vector3(-1.4, 0.7, 0), flat(Color(0.3, 0.3, 0.32), 0.5, 0.6))
	for z in [-0.65, 0.65]:
		var w := cyl(g, 0.42, 0.1, Vector3(0.5, 0.0, z), flat(Color(0.08, 0.08, 0.09), 0.9))
		w.position.y = 0.42
		w.rotation_degrees.x = 90
	for p in [Vector3(-1.3, 0, 0.95), Vector3(1.3, 0, 0.95), Vector3(-1.3, 0, -0.95), Vector3(1.3, 0, -0.95)]:
		cyl(g, 0.045, 2.2, p, flat(Color(0.4, 0.28, 0.16), 0.8))
	var roof := box(g, Vector3(3.0, 0.1, 2.3), Vector3(0, 2.2, 0), iron)
	roof.rotation_degrees.z = 3
	sphere(g, 0.13, Vector3(0.2, 2.0, 0.4), flat(Color(1.0, 0.9, 0.65), 0.4, 0.0, 3.0))
	var l := OmniLight3D.new()
	l.position = Vector3(0.2, 1.9, 0.5)
	l.light_color = Color(1.0, 0.85, 0.6)
	l.light_energy = 0.9
	l.omni_range = 6.0
	g.add_child(l)
	return g


# ---------- Lokasi ----------

## Membangun seluruh lokasi di bawah `root`. Mengembalikan referensi penting.
static func build(root: Node3D) -> Dictionary:
	var out := {}
	var road_mat := pbr("asphalt_01", 0.18, Color(0.55, 0.55, 0.6))
	var side_mat := pbr("brick_pavement_02", 0.3, Color(0.8, 0.7, 0.62))
	var ground := pbr("concrete_floor_painted", 0.2, Color(0.5, 0.48, 0.45))

	var base := box(root, Vector3(140, 0.6, 90), Vector3(0, -0.6, -2), ground)
	var floor_body := StaticBody3D.new()
	base.add_child(floor_body)
	box(root, Vector3(100, 0.16, 7.5), Vector3(1, 0, 0.0), side_mat)           # trotoar z -3.75..3.75
	box(root, Vector3(100, 0.12, 9.0), Vector3(1, 0, 8.25), road_mat)         # jalan z 3.75..12.75
	box(root, Vector3(100, 0.22, 0.25), Vector3(1, 0, 3.8), flat(Color(0.9, 0.88, 0.82), 0.8))  # kerb
	for x in range(-45, 46, 4):
		box(root, Vector3(2.0, 0.015, 0.22), Vector3(x, 0.12, 8.25), flat(Color(0.95, 0.93, 0.85), 0.7))

	# Rumah kos
	var kos := Node3D.new()
	kos.position = Vector3(-8.5, 0, -8.0)
	root.add_child(kos)
	box(kos, Vector3(8.0, 5.5, 6.5), Vector3.ZERO, pbr("beige_wall_001", 0.35, Color(0.95, 0.88, 0.75)), true)
	gable(kos, 8.8, 7.6, 2.2, Vector3(0, 5.5, 0), pbr("clay_roof_tiles", 0.4, Color(1.0, 0.85, 0.8)))
	box(kos, Vector3(1.3, 2.4, 0.15), Vector3(0, 0, 3.3), pbr("wood_plank_wall", 0.6, Color(0.55, 0.38, 0.25)))
	for x in [-2.6, 2.6]:
		box(kos, Vector3(1.4, 1.5, 0.12), Vector3(x, 1.0, 3.28), glass())
		box(kos, Vector3(1.4, 1.5, 0.12), Vector3(x, 3.4, 3.28), glass())
	box(kos, Vector3(2.4, 0.5, 0.1), Vector3(0, 4.6, 3.3), flat(Color(0.18, 0.2, 0.25)))

	# Deretan ruko di antara
	ruko(root, Vector3(-1.0, 0, -8.0), 4.4, 2, Color(0.95, 0.85, 0.7), Color(0.75, 0.22, 0.2))

	# Kantor
	var kantor := Node3D.new()
	kantor.position = Vector3(4.5, 0, -10.0)
	root.add_child(kantor)
	box(kantor, Vector3(9.0, 15.0, 7.0), Vector3.ZERO, pbr("grey_plaster", 0.3, Color(0.8, 0.84, 0.9)), true)
	for row in 5:
		for col in 5:
			box(kantor, Vector3(1.3, 1.5, 0.12), Vector3(-3.4 + col * 1.7, 2.6 + row * 2.6, 3.54), glass(Color(0.2, 0.3, 0.42)))
	box(kantor, Vector3(5.0, 3.0, 0.2), Vector3(0, 0, 3.55), glass(Color(0.25, 0.34, 0.45)))
	box(kantor, Vector3(9.4, 0.4, 7.4), Vector3(0, 15.0, 0), flat(Color(0.35, 0.37, 0.4), 0.7))

	# Pasar kecil
	var pasar := Node3D.new()
	pasar.position = Vector3(16.5, 0, -6.0)
	root.add_child(pasar)
	var iron := pbr("corrugated_iron", 0.5, Color(0.45, 0.55, 0.7))
	var produce := [Color(0.8, 0.15, 0.1), Color(0.2, 0.55, 0.15), Color(0.9, 0.7, 0.1), Color(0.55, 0.35, 0.15)]
	for i in 3:
		var sx := -4.0 + i * 4.2
		box(pasar, Vector3(3.4, 0.9, 1.4), Vector3(sx, 0, 0), pbr("wood_plank_wall", 0.8, Color(0.8, 0.65, 0.45)), true)
		for k in 4:
			box(pasar, Vector3(0.6, 0.3, 0.6), Vector3(sx - 1.2 + k * 0.8, 0.9, 0.0), flat(produce[(i + k) % 4], 0.8))
		for sxo in [-1.7, 1.7]:
			cyl(pasar, 0.05, 2.8, Vector3(sx + sxo, 0, 0.7), flat(Color(0.4, 0.3, 0.2)))
		var r := box(pasar, Vector3(4.0, 0.1, 2.6), Vector3(sx, 2.8, 0.2), iron)
		r.rotation_degrees.x = -6
		sphere(pasar, 0.12, Vector3(sx, 2.5, 0.5), flat(Color(1.0, 0.9, 0.65), 0.4, 0.0, 2.5))
	box(pasar, Vector3(14.0, 4.0, 0.4), Vector3(0, 0, -3.4), pbr("grey_plaster", 0.3, Color(0.75, 0.72, 0.65)))

	# SD (kiri jauh)
	var sd := Node3D.new()
	sd.position = Vector3(-24.0, 0, -9.0)
	root.add_child(sd)
	box(sd, Vector3(12.0, 5.0, 7.0), Vector3.ZERO, pbr("beige_wall_001", 0.3, Color(0.95, 0.9, 0.7)), true)
	gable(sd, 13.0, 8.0, 2.4, Vector3(0, 5.0, 0), pbr("clay_roof_tiles", 0.4, Color(1.0, 0.85, 0.8)))
	box(sd, Vector3(4.0, 0.9, 0.15), Vector3(0, 3.6, 3.55), flat(Color(0.15, 0.3, 0.6)))
	for x in range(-4, 5, 2):
		box(sd, Vector3(1.3, 1.5, 0.12), Vector3(x, 1.2, 3.54), glass())
	box(sd, Vector3(10, 1.0, 0.2), Vector3(0, 0, 4.5), flat(Color(0.35, 0.34, 0.32)))  # pagar rendah

	# Pangkalan ojol (kanan jauh)
	var ojol := Node3D.new()
	ojol.position = Vector3(31.0, 0, -7.0)
	root.add_child(ojol)
	box(ojol, Vector3(7.0, 3.6, 5.0), Vector3.ZERO, pbr("beige_wall_001", 0.35, Color(0.85, 0.9, 0.8)), true)
	gable(ojol, 7.8, 5.8, 1.6, Vector3(0, 3.6, 0), pbr("clay_roof_tiles", 0.4, Color(0.95, 0.8, 0.75)))
	box(ojol, Vector3(5.6, 2.0, 0.1), Vector3(0, 0.2, 2.52), flat(Color(1.0, 0.83, 0.5), 0.5, 0.0, 1.2))
	box(ojol, Vector3(3.0, 0.5, 0.5), Vector3(-6.0, 0, 6.0), pbr("wood_plank_wall", 0.8, Color(0.7, 0.55, 0.4)))
	for i in 3:
		var moto := Node3D.new()
		moto.position = Vector3(24.0 + i * 1.9, 0, 3.0)
		moto.rotation_degrees.y = 90
		root.add_child(moto)
		box(moto, Vector3(1.9, 0.5, 0.45), Vector3(0, 0.45, 0), flat([Color(0.1, 0.55, 0.25), Color(0.6, 0.1, 0.1), Color(0.15, 0.2, 0.45)][i], 0.3, 0.4))
		box(moto, Vector3(0.9, 0.12, 0.4), Vector3(-0.2, 0.95, 0), flat(Color(0.08, 0.08, 0.09), 0.8))
		for x in [-0.7, 0.7]:
			var wh := cyl(moto, 0.34, 0.16, Vector3(x, 0.0, 0), flat(Color(0.06, 0.06, 0.07), 0.9))
			wh.position.y = 0.34
			wh.rotation_degrees.x = 90
	var p1 := person(Color(0.15, 0.55, 0.3), Color(0.15, 0.17, 0.25))
	p1.position = Vector3(27.0, 0, 1.0)
	p1.rotation_degrees.y = 200
	root.add_child(p1)
	var p2 := person(Color(0.15, 0.55, 0.3), Color(0.2, 0.2, 0.25), Color(0.62, 0.43, 0.3))
	p2.position = Vector3(28.5, 0, 0.4)
	p2.rotation_degrees.y = 160
	root.add_child(p2)

	# Warga yang berdiam: penjual dan pembeli di pasar, orang tua murid di depan SD, pegawai di kantor
	var idle := [
		[Vector3(13.0, 0.16, -4.4), 180.0, Color(0.85, 0.35, 0.3), Color(0.25, 0.2, 0.15)],
		[Vector3(16.8, 0.16, -4.4), 180.0, Color(0.3, 0.55, 0.4), Color(0.2, 0.2, 0.28)],
		[Vector3(20.5, 0.16, -4.4), 170.0, Color(0.9, 0.8, 0.3), Color(0.25, 0.25, 0.3)],
		[Vector3(15.0, 0.16, -2.6), 20.0, Color(0.6, 0.35, 0.65), Color(0.2, 0.2, 0.3)],
		[Vector3(18.4, 0.16, -2.9), -40.0, Color(0.25, 0.4, 0.7), Color(0.15, 0.17, 0.25)],
		[Vector3(-22.0, 0.16, -3.6), 160.0, Color(0.9, 0.9, 0.88), Color(0.15, 0.15, 0.4)],
		[Vector3(-19.4, 0.16, -3.4), 200.0, Color(0.9, 0.9, 0.88), Color(0.15, 0.15, 0.4)],
		[Vector3(-17.2, 0.16, -2.2), 60.0, Color(0.7, 0.3, 0.35), Color(0.2, 0.2, 0.28)],
		[Vector3(2.0, 0.16, -3.1), 170.0, Color(0.25, 0.3, 0.5), Color(0.12, 0.12, 0.18)],
		[Vector3(6.8, 0.16, -3.0), 190.0, Color(0.9, 0.9, 0.92), Color(0.15, 0.15, 0.2)],
	]
	for it in idle:
		var ip := person(it[2], it[3], Color(0.74, 0.52, 0.36).lerp(Color(0.5, 0.33, 0.22), randf()))
		ip.position = it[0]
		ip.rotation_degrees.y = it[1]
		root.add_child(ip)

	# Ruko latar belakang
	for x in [-14.0, 10.0, 22.0, 38.0, -34.0]:
		ruko(root, Vector3(x, 0, -17.0), 5.0, 3, Color(0.92, 0.82, 0.68), Color(0.2, 0.45, 0.5))

	# Pohon, lampu, tiang
	for x in [-16.0, -4.0, 12.0, 26.0, 35.0]:
		tree(root, Vector3(x, 0, -2.6), 1.0)
	for x in [-12.0, 0.0, 14.0, 28.0]:
		lamp(root, Vector3(x, 0, 3.0))
	for x in [-20.0, 8.0, 34.0]:
		pole(root, Vector3(x, 0, 3.4))

	out["gerobak"] = gerobak()
	root.add_child(out["gerobak"])
	out["gerobak"].position = Vector3(-3.5, 0.16, 1.2)
	out["spots"] = {
		"sd": Vector3(-20.0, 0.16, 1.6),
		"kantor": Vector3(4.5, 0.16, 1.6),
		"ojol": Vector3(25.0, 0.16, 1.6),
	}
	out["zones"] = {
		"rumah": Vector3(-8.5, 0, -3.5),
		"pasar": Vector3(16.5, 0, -2.6),
	}
	return out
