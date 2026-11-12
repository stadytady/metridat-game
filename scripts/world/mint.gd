class_name Mint
extends District
## The coin striker's room, on the open ground uphill of the mule's pen: a small
## house you can walk into (Arch.cottage), its door on the street. Inside, a
## man on a stool at a stone anvil holds the punch upright on the die with his
## left hand and brings the hammer down with his right (he is an Npc: Sosias,
## who puts the hammer down to talk); a little clay furnace
## keeps the bronze blanks hot, a tray of struck coins waits on the bench.
## Struck coins were made this way - a hot blank between a fixed die in the
## anvil and a punch die struck by hand - but who struck Panticapaeum's coins
## and where is not known: this room and its man are the game's.
## By day he strikes, a hit a little over each second, and the street hears it;
## from the town's dusk the hammer rests and the lamps by the door and on the
## shelf are lit.

## The plot: the front wall's middle, facing the street (-z), and the room.
const FRONT := Vector2(-1.0, 4.6)
const W := 5.2
const D := 5.0
const H := 3.4
## Inside, in the room's own frame (x across, -z into the room; the door at 0):
## the anvil, the stool behind it, the furnace in the back corner, the coin tray
## on the cottage's bench.
const ANVIL := Vector2(-0.35, -2.85)
const STOOL := Vector2(-0.35, -3.6)
const FURNACE := Vector2(-1.55, -4.15)
const TRAY := Vector2(1.78, -2.2)
## One blow every STRIKE_EVERY seconds: the hammer rises for most of it and
## falls fast, landing at the end of the cycle.
const STRIKE_EVERY := 1.1
const RISE := 0.75
## How far the right arm comes up at the top of a swing (degrees on the pose).
const SWING_SHOULDER := 70.0
const SWING_ELBOW := -30.0

var _atm: Node
var _joints := {}
var _npc: Npc
var _xf := Transform3D.IDENTITY
var _floor := 0.0
var _t := 0.0
var _night := false
var _hammer_sound: AudioStreamPlayer3D
var _door_lamp: WallLamp
var _shelf_light: OmniLight3D
var _shelf_flame: GPUParticles3D
var hits := 0


## The room's frame: origin at the middle of the front wall on the ground,
## local +z out to the street.
static func frame() -> Transform3D:
	var y := Topo.terrain(FRONT.x, FRONT.y)
	var z_axis := Vector3(0, 0, -1)  # faces the street
	var x_axis := Vector3.UP.cross(z_axis)
	return Transform3D(Basis(x_axis, Vector3.UP, z_axis), Vector3(FRONT.x, y, FRONT.y))


## The room's corners on the ground plan, for checking it against its neighbours.
static func footprint() -> Rect2:
	var xf := frame()
	var a := xf * Vector3(-W / 2.0, 0, 0)
	var b := xf * Vector3(W / 2.0, 0, -D)
	return Rect2(Vector2(minf(a.x, b.x), minf(a.z, b.z)), Vector2(absf(a.x - b.x), absf(a.z - b.z)))


## How high the hammer is, 0 on the punch .. 1 at the top, at time t.
## Stepped at 15 fps like every figure in town.
static func hammer_lift(t: float) -> float:
	var q := floorf(t * 15.0) / 15.0
	var p := fposmod(q / STRIKE_EVERY, 1.0)
	if p < RISE:
		return sin(p / RISE * PI * 0.5)
	return 1.0 - (p - RISE) / (1.0 - RISE)


## How many blows land between t0 and t1 (each at the end of a cycle).
static func blows(t0: float, t1: float) -> int:
	return maxi(0, floori(t1 / STRIKE_EVERY) - floori(t0 / STRIKE_EVERY))


## The pose's swing for a lift: the right arm up and back.
static func swing(lift: float) -> Dictionary:
	return {"r_shoulder": Vector3(SWING_SHOULDER * lift, 0, 0), "r_elbow": Vector3(SWING_ELBOW * lift, 0, 0)}


func _ready() -> void:
	process_priority = 1  # after the striker's Npc has posed him, add the swing
	_atm = get_parent().get_node_or_null("Atmosphere")
	_xf = frame()
	var kit := MeshKit.new()
	var lowest := _xf.origin.y
	for c: Vector3 in [Vector3(-W / 2.0, 0, 0), Vector3(W / 2.0, 0, 0), Vector3(-W / 2.0, 0, -D), Vector3(W / 2.0, 0, -D)]:
		var p := _xf * c
		lowest = minf(lowest, Topo.terrain(p.x, p.z))
	var info := Arch.cottage(kit, _xf, W, D, H, {"drop": _xf.origin.y - lowest + 1.2})
	_floor = info.floor
	_striker()
	_furniture(kit)
	add_child(kit.build("Mint"))
	_lamps(info)
	_step(0.0)


## A point inside, in the room's frame, on its floor.
func _at(p: Vector2, up: float = 0.0) -> Vector3:
	return _xf * Vector3(p.x, _floor + up, p.y)


func _striker() -> void:
	# an Npc, so he can be talked to; Mint drives his hammer arm on top of the
	# pose (after the Npc's own _process: see process_priority in _ready)
	var npc: Npc = Npc.new()
	npc.name = "Striker"
	npc.npc_id = "striker"
	npc.name_key = "NPC_STRIKER_NAME"
	npc.dialogue = load("res://data/dialogues/striker.dialogue") as DialogueResource
	npc.pose = "strike"
	npc.look = {"beard": 2, "hair": 2, "cloth": "chiton_dark"}
	# a figure faces its own -z; he sits facing the anvil and the door (+z of the room)
	npc.position = _at(STOOL)
	npc.rotation.y = (_xf.basis * Basis(Vector3.UP, PI)).get_euler().y
	add_child(npc)
	_npc = npc
	_joints = npc.joints
	Figure.apply_pose(_joints, "strike")
	# the punch: a short bronze rod upright in the left fist
	var punch := MeshInstance3D.new()
	var pk := MeshKit.new()
	pk.box("bronze", Vector3(0, 0, 0.06), Vector3(0.035, 0.035, 0.16), [])
	punch.mesh = pk.commit()
	punch.name = "Punch"
	punch.position = Vector3(0, -0.28, 0)
	(_joints["l_elbow"] as Node3D).add_child(punch)
	# the hammer: a wooden haft forward from the right fist, an iron head across it
	var hammer := MeshInstance3D.new()
	var hk := MeshKit.new()
	hk.box("wood", Vector3(0, 0, -0.14), Vector3(0.03, 0.03, 0.28), [])
	hk.box("dark", Vector3(0, 0, -0.29), Vector3(0.06, 0.15, 0.06), [])
	hammer.mesh = hk.commit()
	hammer.name = "Hammer"
	hammer.position = Vector3(0, -0.28, 0)
	(_joints["r_elbow"] as Node3D).add_child(hammer)
	_hammer_sound = AudioStreamPlayer3D.new()
	_hammer_sound.stream = preload("res://assets/audio/hammer.wav")
	_hammer_sound.position = _at(ANVIL, 0.6)
	_hammer_sound.volume_db = -14.0
	_hammer_sound.unit_size = 2.0
	_hammer_sound.max_distance = 22.0
	add_child(_hammer_sound)


## The punch's tip, where the die is: the anvil is built up to meet it.
func punch_tip() -> Vector3:
	var punch: Node3D = (_joints["l_elbow"] as Node3D).get_node("Punch")
	return punch.global_transform * Vector3(0, 0, 0.14)


## The hammer's face, where it lands.
func hammer_face() -> Vector3:
	var hammer: Node3D = (_joints["r_elbow"] as Node3D).get_node("Hammer")
	return hammer.global_transform * Vector3(0, -0.075, -0.29)


## The top of the punch, where the hammer must land.
func punch_head() -> Vector3:
	var punch: Node3D = (_joints["l_elbow"] as Node3D).get_node("Punch")
	return punch.global_transform * Vector3(0, 0, -0.02)


func _furniture(kit: MeshKit) -> void:
	kit.xform = _xf
	var f := _floor
	# the stool
	kit.box("wood", Vector3(STOOL.x, f + 0.21, STOOL.y), Vector3(0.36, 0.42, 0.32), ["bottom"], {})
	# no collider of its own: the man sitting on it has one, and a second box
	# in the same place would take the interaction ray before he does
	# the anvil: a squared stone block up to the punch's tip, the bronze die set in it
	var tip := _xf.affine_inverse() * punch_tip()
	var top := tip.y - 0.03
	var block := top - f
	kit.box("limestone", Vector3(tip.x, f + block / 2.0, tip.z), Vector3(0.42, block, 0.42), ["bottom"], {})
	kit.box("bronze", Vector3(tip.x, top + 0.015, tip.z), Vector3(0.1, 0.03, 0.1), ["bottom"], {})
	kit.add_collider(Vector3(tip.x, f + block / 2.0, tip.z), Vector3(0.42, block, 0.42))
	# a basket of blanks by the anvil
	kit.box("basket", Vector3(tip.x + 0.5, f + 0.12, tip.z - 0.2), Vector3(0.3, 0.24, 0.3), ["bottom"], {})
	for i in 5:
		kit.box("bronze", Vector3(tip.x + 0.42 + 0.04 * i, f + 0.245, tip.z - 0.24 + 0.03 * (i % 2)), Vector3(0.035, 0.012, 0.035), [], {})
	# the furnace: a clay box with the fire showing in its mouth
	kit.box("clay", Vector3(FURNACE.x, f + 0.32, FURNACE.y), Vector3(0.7, 0.64, 0.6), ["bottom"], {})
	kit.box("fire", Vector3(FURNACE.x, f + 0.26, FURNACE.y + 0.301), Vector3(0.3, 0.2, 0.01), [], {})
	kit.box("dark", Vector3(FURNACE.x, f + 0.68, FURNACE.y), Vector3(0.3, 0.08, 0.3), ["bottom"], {})
	kit.add_collider(Vector3(FURNACE.x, f + 0.32, FURNACE.y), Vector3(0.7, 0.64, 0.6))
	# tongs leaning on it
	kit.box("dark", Vector3(FURNACE.x + 0.42, f + 0.3, FURNACE.y + 0.2), Vector3(0.03, 0.6, 0.03), [], {})
	# the tray of struck coins on the bench
	kit.box("wood", Vector3(TRAY.x, f + 0.29, TRAY.y), Vector3(0.5, 0.04, 0.36), ["bottom"], {})
	for i in 12:
		var cx := TRAY.x - 0.18 + 0.075 * float(i % 6)
		var cz := TRAY.y - 0.08 + 0.15 * float(i / 6)
		kit.box("bronze", Vector3(cx, f + 0.316, cz), Vector3(0.045, 0.012, 0.045), [], {})
	kit.xform = Transform3D.IDENTITY
	# the furnace glows day and night: it is his fire, not the town's lamps
	var glow := OmniLight3D.new()
	glow.position = _at(FURNACE + Vector2(0, 0.5), 0.3)
	glow.light_color = Color(1, 0.5, 0.2)
	glow.omni_range = 3.0
	glow.shadow_enabled = false
	glow.set_script(preload("res://scripts/world/flicker.gd"))
	glow.base_energy = 0.8
	glow.amount = 0.3
	add_child(glow)


func _lamps(info: Dictionary) -> void:
	_door_lamp = WallLamp.new()
	_door_lamp.position = _xf * (info.lamp as Vector3)
	_door_lamp.rotation.y = _xf.basis.get_euler().y
	add_child(_door_lamp)
	# the household lamp in the cottage's shelf niche
	var shelf := _xf * Vector3(-W * 0.5 + Arch.COTTAGE_WALL + 0.3, _floor + 0.25 - 0.06 + 0.95, -D * 0.35)
	_shelf_flame = Lamp._make_flame(0.05)
	_shelf_flame.position = shelf + Vector3(0, 0.06, 0)
	add_child(_shelf_flame)
	_shelf_light = OmniLight3D.new()
	_shelf_light.position = shelf + Vector3(0, 0.15, 0)
	_shelf_light.light_color = Color(1.0, 0.62, 0.3)
	_shelf_light.omni_range = 4.5
	_shelf_light.shadow_enabled = false
	_shelf_light.set_script(preload("res://scripts/world/flicker.gd"))
	_shelf_light.base_energy = 1.1
	_shelf_light.amount = 0.3
	add_child(_shelf_light)


func _process(delta: float) -> void:
	_step(delta)


## One tick: lamps follow the town's dusk; by day the hammer swings and every
## blow that lands is heard.
func _step(delta: float) -> void:
	var night := _atm != null and float(_atm.t) >= DayCycle.LAMPS_ON
	if night != _night or delta == 0.0:
		_night = night
		_door_lamp.set_lit(night)
		_shelf_light.visible = night
		_shelf_flame.visible = night
		_shelf_flame.emitting = night
	# he puts the hammer down to talk, and for the night
	var resting := _night or (Game.ui_blocking and _talking())
	if resting:
		_arm(0.0)
		return
	var t0 := _t
	_t += delta
	_arm(hammer_lift(_t))
	var n := blows(t0, _t)
	if n > 0 and delta > 0.0:
		hits += n
		if _hammer_sound.is_inside_tree():
			_hammer_sound.pitch_scale = 0.94 + 0.04 * float(hits % 3)
			_hammer_sound.play()


## The hammer arm for a lift, on top of whatever the Npc posed (head and all).
func _arm(lift: float) -> void:
	var base: Dictionary = Figure.POSES["strike"]
	var sw := swing(lift)
	for j: String in ["r_shoulder", "r_elbow"]:
		(_joints[j] as Node3D).rotation_degrees = (base[j] as Vector3) + (sw[j] as Vector3)


## True while a conversation is open and the player stands in the room.
func _talking() -> bool:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	return cam != null and cam.global_position.distance_to(_npc.global_position) < 4.0


## Whether the hammer is swinging now (for tests and the walkthrough).
func working() -> bool:
	return not _night


func striker() -> Npc:
	return _npc
