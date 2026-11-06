extends District
## Potter's workshop in the agora's south-west corner: lean-to shed, a wheel
## spun by hand by a boy (who now and then goes to feed the kiln, and the wheel
## runs down while he is away) while the potter shapes (as on Corinthian plaques and
## Attic vase paintings), an updraft kiln with smoke and a glowing firebox,
## shelves of drying pots, a heap of clay.

const NPC := preload("res://scripts/npc/npc.gd")

## The boy's round, on the agora floor: [x, z, pose, pause s, facing yaw deg or
## NAN]. He turns the wheel, goes out along the front of the shed (clear of the
## path people take to the potter), gathers an armful at the woodpile behind
## the kiln, kneels at the stoking mouth to feed it, and comes back to the wheel.
const BOY_HOME := Vector2(12.75, 8.75)
const BOY_ROUTE := [
	[12.75, 8.75, "turner", 16.0, -90.0],
	[12.75, 8.0, "walk", 0.0, NAN],
	[14.4, 7.85, "walk", 0.0, NAN],
	[18.95, 7.55, "walk", 0.0, NAN],
	[19.3, 9.05, "pick", 2.5, 180.0],
	[18.95, 7.55, "walk", 0.0, NAN],
	[17.7, 7.45, "stoke", 3.5, 180.0],
	[14.4, 7.85, "walk", 0.0, NAN],
	[12.75, 8.0, "walk", 0.0, NAN],
]
const PICK := 4
const STOKE := 6
## The logs go into the fire this long after he kneels.
const FEED_AFTER := 1.3
const WHEEL_SPEED := 5.5

var _wheel: Node3D
var _wheel_sound: AudioStreamPlayer3D
var _wheel_speed := WHEEL_SPEED
var _boy: Npc
var _logs: Node3D


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
	# the wheel itself: a soft thump each half turn, wet clay slapped on
	var sound := AudioStreamPlayer3D.new()
	_wheel_sound = sound
	sound.stream = preload("res://assets/audio/wheel.wav")
	sound.position = p + Vector3(0, 0.45, 0)
	sound.volume_db = -27.0
	sound.unit_size = 1.2
	sound.max_distance = 9.0
	sound.autoplay = true
	add_child(sound)


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
	boy.position = Vector3(BOY_HOME.x, y, BOY_HOME.y)
	boy.rotation.y = deg_to_rad(-90.0)
	set_round(boy)
	add_child(boy)
	_boy = boy
	# an armful of split logs, held against the chest on the way to the kiln
	_logs = Node3D.new()
	_logs.name = "Logs"
	_logs.position = Vector3(0, 0.1, -0.26)
	_logs.visible = false
	var lk := MeshKit.new()
	# four split logs across the forearms, the top two a little further out
	for i in 4:
		var at := Vector3(-0.07 + (i % 2) * 0.14, -0.04 + (i / 2) * 0.12, -0.04 * (i / 2))
		lk.xform = Transform3D(Basis(Vector3.FORWARD, PI / 2.0), at)
		lk.lathe("bark", PackedVector2Array([Vector2(0.075, -0.32), Vector2(0.075, 0.32)]), 5, Vector3.ZERO, 1.0, false, "wood", true)
	var lm := MeshInstance3D.new()
	lm.mesh = lk.commit()
	_logs.add_child(lm)
	(boy.joints["chest"] as Node3D).add_child(_logs)
	boy.reached.connect(_on_boy_reached)


## Gives a Npc the boy's round: waypoints as offsets from his home, with the
## pose, pause and facing of each. Static so the test can walk it without the
## workshop.
static func set_round(boy: Npc) -> void:
	var pts := PackedVector3Array()
	var poses := PackedStringArray()
	var pauses := PackedFloat32Array()
	var faces := PackedFloat32Array()
	for w: Array in BOY_ROUTE:
		pts.append(Vector3(float(w[0]) - BOY_HOME.x, 0, float(w[1]) - BOY_HOME.y))
		poses.append(w[2])
		pauses.append(w[3])
		faces.append(w[4])
	boy.patrol = pts
	boy.patrol_poses = poses
	boy.patrol_pauses = pauses
	boy.patrol_faces = faces
	boy.patrol_speed = 0.75
	# he has work to do: he walks on past the player instead of stopping to stare
	boy.stops_for_player = false


func _on_boy_reached(i: int) -> void:
	if i == PICK:
		_logs.visible = true
		_boy.carrying = true
	elif i == STOKE:
		_boy.carrying = false
		await get_tree().create_timer(FEED_AFTER).timeout
		_logs.visible = false


func _process(delta: float) -> void:
	# A hand-turned wheel: fast and a little uneven while the boy turns it; when
	# he goes for wood it runs down on its own weight and stands.
	var turning := _boy.pose_now() == "turner"
	var want := WHEEL_SPEED + sin(Time.get_ticks_msec() / 400.0) * 1.2 if turning else 0.0
	_wheel_speed = lerpf(_wheel_speed, want, 1.0 - exp(-(2.5 if turning else 0.45) * delta))
	_wheel.rotation.y += delta * _wheel_speed
	var quiet := _wheel_speed < 0.6
	if _wheel_sound.stream_paused != quiet:
		_wheel_sound.stream_paused = quiet
