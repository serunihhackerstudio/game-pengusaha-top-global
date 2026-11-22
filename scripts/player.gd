class_name Player
extends CharacterBody3D
## Pemain: jalan dengan WASD/panah atau klik/ketuk untuk berjalan ke titik.

const SPEED := 6.5

var model: Node3D
var _amount: float = 0.0
var target: Variant = null
var enabled: bool = true
var _bob: float = 0.0


func _ready() -> void:
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	cs.shape = cap
	cs.position = Vector3(0, 0.85, 0)
	add_child(cs)
	model = World.person(Color(0.92, 0.94, 0.96), Color(0.2, 0.3, 0.5), Color(0.74, 0.52, 0.36), Color(0.08, 0.06, 0.05), {"hair": "side"})
	add_child(model)


func move_to(p: Vector3) -> void:
	target = Vector3(p.x, 0.0, p.z)


func stop() -> void:
	target = null
	velocity = Vector3.ZERO


func _physics_process(delta: float) -> void:
	var dir := Vector3.ZERO
	if enabled:
		var inp := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		if Input.is_key_pressed(KEY_A):
			inp.x -= 1.0
		if Input.is_key_pressed(KEY_D):
			inp.x += 1.0
		if Input.is_key_pressed(KEY_W):
			inp.y -= 1.0
		if Input.is_key_pressed(KEY_S):
			inp.y += 1.0
		inp = inp.limit_length(1.0)
		if inp.length() > 0.05:
			target = null
			# kamera menghadap (-x, -z) pada yaw 45 derajat
			var fwd := Vector3(-0.7071, 0, -0.7071)
			var right := Vector3(0.7071, 0, -0.7071)
			dir = (right * inp.x + fwd * -inp.y).normalized()
		elif target != null:
			var to: Vector3 = (target as Vector3) - global_position
			to.y = 0.0
			if to.length() < 0.2:
				target = null
			else:
				dir = to.normalized()
	velocity = dir * SPEED
	move_and_slide()
	global_position.y = 0.16 if global_position.z < 3.75 else 0.12
	if dir.length() > 0.01:
		var yaw := atan2(dir.x, dir.z)
		model.rotation.y = lerp_angle(model.rotation.y, yaw, 12.0 * delta)
		_bob += delta * 10.0
		_amount = move_toward(_amount, 1.0, delta * 6.0)
	else:
		_amount = move_toward(_amount, 0.0, delta * 6.0)
	World.animate_person(model, _bob, _amount)
