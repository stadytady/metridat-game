extends District
## Potter's workshop in the agora's south-west corner: lean-to shed, a wheel
## spun by hand by a boy while the potter shapes (as on Corinthian plaques and
## Attic vase paintings), an updraft kiln with smoke and a glowing firebox,
## shelves of drying pots, a heap of clay.

const NPC := preload("res://scripts/npc/npc.gd")

var _wheel: Node3D


func _ready() -> void:
	var y := Topo.AGORA_H
	var kit := MeshKit.new()
	# shed: back and side wall, two posts, lean-to roof
	kit.solid_box("mud", Vector3(13.4, y + 1.3, 10.6), Vector3(6.8, 2.6, 0.35), ["bottom"])
	kit.solid_box("mud", Vector3(10.15, y + 1.3, 8.9), Vector3(0.35, 2.6, 3.4), ["bottom"])
	for x: float in [10.3, 16.6]:
		kit.solid_box("wood", Vector3(x, y + 1.25, 7.2), Vector3(0.16, 2.5, 0.16), ["bottom"])
	kit.box("wood", Vector3(13.45, y + 2.5, 7.2), Vector3(6.6, 0.14, 0.18), [])
	var a := Vector3(9.9, y + 2.55, 6.8)
	var b := Vector3(16.9, y + 2.55, 6.8)
	var c := Vector3(16.9, y + 2.95, 10.9)
	var d := Vector3(9.9, y + 2.95, 10.9)
	kit.quad("roof", d, c, b, a)
	kit.quad("wood", c, d, a, b)
	# shelves with drying pots along the side wall
	for h: float in [0.55, 1.15]:
		kit.solid_box("wood", Vector3(10.6, y + h, 8.9), Vector3(0.5, 0.06, 3.0), [])
	kit.box("wood", Vector3(10.6, y + 0.58, 7.5), Vector3(0.45, 1.16, 0.06), [])
	kit.box("wood", Vector3(10.6, y + 0.58, 10.3), Vector3(0.45, 1.16, 0.06), [])
	# heap of clay and the potter's stool
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	kit.blob("mud", Vector3(15.8, y + 0.2, 9.9), Vector3(0.6, 0.3, 0.5), 0.25, rng)
	kit.solid_box("wood", Vector3(13.4, y + 0.2, 9.55), Vector3(0.4, 0.4, 0.35), ["bottom"])
	# kiln: domed updraft kiln of mud brick with a stoking channel to the north
	var k := Vector3(17.7, y, 9.5)
	kit.lathe("mud", PackedVector2Array([Vector2(1.0, 0), Vector2(1.05, 0.7), Vector2(0.85, 1.3), Vector2(0.45, 1.65),
		Vector2(0.25, 1.75)]), 9, k, 2.0, false, "dark", true)
	kit.solid_box("mud", k + Vector3(0, 0.3, -1.15), Vector3(0.7, 0.6, 0.6), ["bottom"])
	kit.quad("dark", k + Vector3(-0.22, 0.05, -1.46), k + Vector3(0.22, 0.05, -1.46), k + Vector3(0.22, 0.45, -1.46),
		k + Vector3(-0.22, 0.45, -1.46))
	kit.xform = Transform3D.IDENTITY
	add_child(kit.build("Workshop"))
	var kc := CollisionShape3D.new()
	var ks := CylinderShape3D.new()
	ks.radius = 1.05
	ks.height = 1.8
	kc.shape = ks
	kc.position = k + Vector3(0, 0.9, 0)
	props_body().add_child(kc)
	for i in 4:
		place("krater", Vector3(10.6, y + 1.18, 7.9 + i * 0.6), rng.randf_range(0, 360), Vector3.ONE * 0.45)
	for i in 3:
		place("amphora", Vector3(10.6, y + 0.58, 9.3 + i * 0.35), rng.randf_range(0, 360), Vector3.ONE * 0.55)
	_build_wheel(Vector3(13.4, y, 8.75))
	_kiln_fire(k)
	_people(y)
	spawn_inspectable("mould_figurine", Vector3(10.6, y + 0.58, 8.0), 90.0)


func _build_wheel(p: Vector3) -> void:
	var kit := MeshKit.new()
	kit.solid_box("wood", p + Vector3(0, 0.12, 0), Vector3(0.3, 0.24, 0.3), ["bottom"])
	add_child(kit.build("WheelBase"))
	_wheel = Node3D.new()
	_wheel.name = "Wheel"
	_wheel.position = p + Vector3(0, 0.24, 0)
	add_child(_wheel)
	var wk := MeshKit.new()
	wk.lathe("wood", PackedVector2Array([Vector2(0.34, 0.0), Vector2(0.34, 0.07)]), 10, Vector3.ZERO, 3.0, false, "wood", true)
	wk.lathe("clay", PackedVector2Array([Vector2(0.09, 0.07), Vector2(0.13, 0.17), Vector2(0.1, 0.28), Vector2(0.11, 0.31)]), 8,
			Vector3.ZERO, 1.0, true, "dark", true)
	var mi := MeshInstance3D.new()
	mi.mesh = wk.commit()
	_wheel.add_child(mi)


func _kiln_fire(k: Vector3) -> void:
	var glow := OmniLight3D.new()
	glow.position = k + Vector3(0, 0.3, -1.7)
	glow.light_color = Color(1, 0.5, 0.2)
	glow.omni_range = 4.0
	glow.set_script(preload("res://scripts/world/flicker.gd"))
	glow.base_energy = 0.9
	glow.amount = 0.3
	add_child(glow)
	var smoke := Lamp._make_flame(0.35)
	var pm: ParticleProcessMaterial = smoke.process_material
	var g := Gradient.new()
	g.set_color(0, Color(0.38, 0.35, 0.33))
	g.set_color(1, Color(0.2, 0.19, 0.18))
	(pm.color_ramp as GradientTexture1D).gradient = g
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 0.9
	pm.spread = 18.0
	(smoke.draw_pass_1.surface_get_material(0) as StandardMaterial3D).blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	smoke.amount = 14
	smoke.lifetime = 3.0
	smoke.position = k + Vector3(0, 1.8, 0)
	smoke.visibility_aabb = AABB(Vector3(-2, 0, -2), Vector3(4, 5, 4))
	smoke.emitting = true
	smoke.visible = true
	add_child(smoke)


func _people(y: float) -> void:
	var potter: Npc = NPC.new()
	potter.npc_id = "potter"
	potter.name_key = "NPC_POTTER_NAME"
	potter.dialogue = load("res://data/dialogues/potter.dialogue") as DialogueResource
	potter.pose = "potter"
	potter.position = Vector3(13.4, y, 9.4)
	add_child(potter)
	var boy: Npc = NPC.new()
	boy.npc_id = "turner"
	boy.name_key = "NPC_BOY_NAME"
	boy.pose = "turner"
	boy.body_mat = "chiton_dark"
	boy.figure_scale = 0.72
	boy.talkable = false
	boy.position = Vector3(12.75, y, 8.75)
	boy.rotation.y = deg_to_rad(-90.0)
	add_child(boy)


func _process(delta: float) -> void:
	# a hand-turned wheel: fast, a little uneven
	_wheel.rotation.y += delta * (5.5 + sin(Time.get_ticks_msec() / 400.0) * 1.2)
