class_name WallWatch
extends Node3D
## The night watch on the town wall: a sentry with a spear on every tower, a
## fire on the roof beside him from dusk, and a torch in his hand. Now and then
## the post nearest the acropolis raises its torch and the others answer one by
## one along both walls, nearest first, so whoever keeps the watch can count the
## lights and see who is asleep. Every third round one post misses its turn: the
## first post calls again and the sleeper answers late.
## (Fires at the posts and the counted torch signal are from Aeneas Tacticus,
## On the Defence of Fortified Places, ch. 26; who stood on Panticapaeum's towers
## is this game's guess: the kings of the Bosporus kept paid troops, Greek and
## Thracian.)
## Everything moves from one clock (seconds since dusk), so no state: what each
## post shows at any moment is relay_lift(clock, rank, n).

const BACKDROP := preload("res://scripts/world/backdrop.gd")

## The round: the first call comes RELAY_LEAD after its start, each next post
## answers ANSWER later, a raised torch is held up HOLD and takes RAMP to go up
## or come down; every SLEEPY_EVERY-th round has a sleeper who answers LATE.
const RELAY_EVERY := 75.0
const RELAY_LEAD := 5.0
const ANSWER := 1.3
const HOLD := 2.0
const RAMP := 0.35
const SLEEPY_EVERY := 3
const LATE := 1.8
## Where the sentry stands on the roof (towards the field) and the fire (towards
## the town), from the middle of the roof.
const STAND_OUT := 1.9
const FIRE_IN := 2.5
const FIRE_SIDE := 1.0
## The brazier's flame: big enough to be a light on the skyline from the town.
const BRAZIER_FLAME := 0.5
## The torch's light held low and raised high.
const LOW_ENERGY := 1.3
const HIGH_ENERGY := 4.2
const LOW_RANGE := 6.0
const HIGH_RANGE := 13.0

## The Atmosphere whose hour lights the watch; the backdrop passes it in.
var atm: Node
var clock := 0.0
var lit := false
var _sentries: Array[Dictionary] = []  # {joints, light, flame, rank, t}
var _fires: Array[Node3D] = []  # the braziers; each holds its flame and light


## The posts, one per tower: {tower, stand, fire, yaw, rank}. rank 0 is the post
## nearest the acropolis, which calls; the rest answer in order of distance.
static func posts() -> Array[Dictionary]:
	var towers := BACKDROP.wall_towers()
	var order: Array[int] = []
	for i in towers.size():
		order.append(i)
	var hill := Vector3(Topo.HILL_CENTER.x, 0, Topo.HILL_CENTER.y)
	order.sort_custom(func(a: int, b: int) -> bool:
		return _flat(towers[a]).distance_to(hill) < _flat(towers[b]).distance_to(hill))
	var out: Array[Dictionary] = []
	for i in towers.size():
		var t: Vector3 = towers[i]
		var out_dir := signf(t.z)  # the field lies beyond the wall, away from z = 0
		out.append({
			"tower": t,
			"stand": t + Vector3(0, 0, out_dir * STAND_OUT),
			"fire": t + Vector3(FIRE_SIDE, 0, -out_dir * FIRE_IN),
			# a figure faces its local -z: look out over the field
			"yaw": 0.0 if out_dir < 0.0 else PI,
			"rank": order.find(i),
		})
	return out


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z)


## Which post sleeps through round r (-1: nobody does).
static func sleeper(r: int, n: int) -> int:
	if n < 2 or posmod(r, SLEEPY_EVERY) != SLEEPY_EVERY - 1:
		return -1
	return 1 + posmod(hash(r * 7919 + 3), n - 1)


## When, in seconds from the start of round r, the post of this rank raises its
## torch. The first post calls once, twice when someone sleeps; the sleeper
## answers only after the second call.
static func calls(r: int, rank: int, n: int) -> Array[float]:
	var asleep := sleeper(r, n)
	var again := RELAY_LEAD + float(n - 1) * ANSWER + HOLD + RAMP * 2.0 + LATE
	var out: Array[float] = []
	if rank == 0:
		out.append(RELAY_LEAD)
		if asleep >= 0:
			out.append(again)
	elif rank == asleep:
		out.append(again + ANSWER + LATE)
	else:
		out.append(RELAY_LEAD + float(rank) * ANSWER)
	return out


## How far the torch of the post of this rank is raised (0 held low .. 1 high)
## at this many seconds after dusk.
static func relay_lift(at: float, rank: int, n: int) -> float:
	var r := floori(at / RELAY_EVERY)
	var s := at - float(r) * RELAY_EVERY
	var lift := 0.0
	for start: float in calls(r, rank, n):
		var d := s - start
		var up := d / RAMP
		var down := (HOLD + RAMP * 2.0 - d) / RAMP
		lift = maxf(lift, clampf(minf(up, down), 0.0, 1.0))
	return lift


func _ready() -> void:
	var ps := posts()
	for p: Dictionary in ps:
		_fires.append(_brazier(p))
		_sentries.append(_sentry(p))
	step(0.0, 0.0)


## The post's fire: a bronze bowl on three legs at the town edge of the roof, a
## big flame (a torch's would be a dot from the streets) and a light that
## washes the top of the tower's town face.
func _brazier(p: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Brazier%d" % int(p.rank)
	root.position = p.fire
	add_child(root)
	var kit := MeshKit.new()
	for i in 3:
		var a := TAU * float(i) / 3.0
		kit.box("dark", Vector3(cos(a) * 0.22, 0.42, sin(a) * 0.22), Vector3(0.05, 0.84, 0.05), [])
	kit.box("bronze", Vector3(0, 0.9, 0), Vector3(0.56, 0.14, 0.56), [])
	kit.box("dark", Vector3(0, 0.98, 0), Vector3(0.44, 0.03, 0.44), [])
	var mi := MeshInstance3D.new()
	mi.mesh = kit.commit()
	root.add_child(mi)
	var flame := Lamp._make_flame(BRAZIER_FLAME)
	flame.name = "Flame"
	flame.position.y = 1.05
	root.add_child(flame)
	var light := OmniLight3D.new()
	light.name = "Light"
	light.position.y = 1.35
	light.light_color = Color(1.0, 0.58, 0.26)
	light.omni_range = 10.0
	light.shadow_enabled = false
	light.set_script(preload("res://scripts/world/flicker.gd"))
	light.base_energy = 2.4
	light.amount = 0.5
	light.visible = false
	root.add_child(light)
	return root


## A sentry: a figure on the roof with a spear in the left hand and a torch in
## the right, and a light of his own at the torch's head.
func _sentry(p: Dictionary) -> Dictionary:
	var root := Node3D.new()
	root.name = "Sentry%d" % int(p.rank)
	root.position = p.stand
	root.rotation.y = p.yaw
	add_child(root)
	var joints := Figure.build(root, "chiton", {"beard": 1 + posmod(int(p.rank), 2), "hair": posmod(int(p.rank), 3), "cloth": "chiton_dark"})
	var kit := MeshKit.new()
	# the spear: an ash shaft upright beside the left hand and a bronze head
	kit.box("wood", Vector3(0, 0.55, -0.07), Vector3(0.035, 1.9, 0.035), [])
	kit.box("bronze", Vector3(0, 1.58, -0.07), Vector3(0.05, 0.18, 0.02), [])
	var spear := MeshInstance3D.new()
	spear.mesh = kit.commit()
	spear.position = Vector3(0, -0.28, 0)
	(joints["l_elbow"] as Node3D).add_child(spear)
	# the torch: a stick on from the fist, the flame at its head
	var torch := Node3D.new()
	torch.position = Vector3(0, -0.28, 0)
	(joints["r_elbow"] as Node3D).add_child(torch)
	var tk := MeshKit.new()
	tk.box("wood", Vector3(0, -0.2, 0), Vector3(0.04, 0.45, 0.04), [])
	tk.box("dark", Vector3(0, -0.44, 0), Vector3(0.07, 0.08, 0.07), [])
	var stick := MeshInstance3D.new()
	stick.mesh = tk.commit()
	torch.add_child(stick)
	var flame := Lamp._make_flame(0.22)
	flame.position = Vector3(0, -0.5, 0)
	torch.add_child(flame)
	var light := OmniLight3D.new()
	light.position = Vector3(0, -0.55, 0)
	light.light_color = Color(1.0, 0.6, 0.28)
	light.shadow_enabled = false
	light.set_script(preload("res://scripts/world/flicker.gd"))
	light.amount = 0.4
	light.visible = false
	torch.add_child(light)
	return {"joints": joints, "light": light, "flame": flame, "rank": int(p.rank), "t": float(p.rank) * 1.7}


func _process(delta: float) -> void:
	step(atm.t if atm != null else 0.0, delta)


## One tick at this hour: dusk lights the fires and the torches and starts the
## clock; the sentries look about and raise their torches when it is their turn.
func step(hour: float, delta: float) -> void:
	var night := hour >= DayCycle.LAMPS_ON
	if night != lit:
		lit = night
		clock = 0.0
		for f in _fires:
			(f.get_node("Light") as OmniLight3D).visible = night
			var fl: GPUParticles3D = f.get_node("Flame")
			fl.visible = night
			fl.emitting = night
		for s in _sentries:
			(s.light as OmniLight3D).visible = night
			(s.flame as GPUParticles3D).visible = night
			(s.flame as GPUParticles3D).emitting = night
	if night:
		clock += delta
	# 15 frames a second, like every figure in town
	var q := floorf(clock * 15.0) / 15.0
	for s in _sentries:
		s.t = float(s.t) + delta
		var k := relay_lift(q, int(s.rank), _sentries.size()) if night else 0.0
		var look := sin(floorf(float(s.t) * 15.0) / 15.0 * 0.23) * 35.0 * (1.0 - k)
		Figure.apply_pose(s.joints, "stand", {
			"head": Vector3(0, look, 0),
			"r_shoulder": Vector3(lerpf(15.0, 168.0, k), 0, lerpf(-6.0, -12.0, k)),
			"r_elbow": Vector3(lerpf(100.0, 8.0, k), 0, 0),
			"l_shoulder": Vector3(6, 0, 4),
		})
		var light: OmniLight3D = s.light
		light.base_energy = lerpf(LOW_ENERGY, HIGH_ENERGY, k)
		light.omni_range = lerpf(LOW_RANGE, HIGH_RANGE, k)


## How many torches are raised right now (for tests and the walkthrough).
func raised() -> int:
	var c := 0
	for s in _sentries:
		if lit and relay_lift(floorf(clock * 15.0) / 15.0, int(s.rank), _sentries.size()) > 0.5:
			c += 1
	return c


## How many tower fires burn, and how many there are (the walkthrough checks
## every one has caught after dusk).
func fires_lit() -> int:
	return _fires.filter(func(f: Node3D) -> bool: return (f.get_node("Light") as OmniLight3D).visible).size()


func fire_count() -> int:
	return _fires.size()
