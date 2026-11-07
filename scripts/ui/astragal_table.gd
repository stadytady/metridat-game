class_name AstragalTable
extends SubViewportContainer
## The window over the game of knucklebones: a stone slab in a small 3D world
## of its own (like ItemViewer: a fixed light, the PS1 look), and the bones
## flying onto it. Each throw the player's five leave a hand at the near edge,
## tumble through the air, come down on the slab, kick up once and lie still;
## then the children's five do the same on the far half. A bone shows its
## count by the face it comes to rest on - pips cut in the four long faces.
## The counts (1, 3, 4, 6) come from AstragalGame; this only shows them falling.

signal landed(side: int)  # one hand has come to rest (0 the player, 1 the children)
signal settled            # both have

const INTERNAL := Vector2i(360, 180)
const SHRINK := 2
const BONE_SCALE := 1.6
## The slab, and where each side's bones come down on it.
const SLAB := Vector3(1.3, 0.06, 0.66)
const SPACING := 0.25
const ROW_Z := 0.15
const JITTER := 0.025
## Where each hand lets go: low over the near or far edge, a little to one side.
const HANDS := [Vector3(-0.35, 0.16, 0.36), Vector3(0.35, 0.16, -0.36)]
## The flight: seconds in the air, how high the arc goes, the little bounce
## at the end, the gap between one bone and the next and between the hands.
const FLY := 0.75
const ARC := 0.18
const BOUNCE := 0.035
const LAND_AT := 0.78  # share of the flight that is the arc; the rest is the bounce
const STAGGER := 0.05
const HAND_GAP := 0.45
## The bone's half sizes (as Knucklebones builds it, before BONE_SCALE).
const BONE_LEN := 0.09
const BONE_H := 0.042
const BONE_D := 0.048
const KNOB := 1.2  # the knobs stand this much proud of the bar
## Face -> the local axis that faces up when the bone shows it: the broad
## faces (3 and 4) are the bar's top and bottom, the narrow ones (1 and 6) its
## sides, as on a real knucklebone.
const FACE_AXES := {3: Vector3.UP, 1: Vector3.BACK, 4: Vector3.DOWN, 6: Vector3.FORWARD}
const FACE_ANGLES := {3: 0.0, 1: -PI / 2.0, 4: PI, 6: PI / 2.0}

var _vp: SubViewport
var _bones: Array[Array] = [[], []]
## Per side and bone: [start, spot, final basis, spin axis, spins, delay].
var _plans: Array[Array] = [[], []]
var _t := -1.0
var _landed := [false, false]
var _rest_y := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(INTERNAL * SHRINK)
	size = custom_minimum_size
	stretch = true
	stretch_shrink = SHRINK
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	material = preload("res://assets/materials/psx_post.tres")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.size = INTERNAL
	_vp.handle_input_locally = false
	_vp.gui_disable_input = true
	add_child(_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#14100c")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#8a7a68")
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.light_color = Color("#ffe2b8")
	key.light_energy = 1.25
	key.rotation_degrees = Vector3(-55, 30, 0)
	_vp.add_child(key)
	var cam := Camera3D.new()
	cam.fov = 40.0
	# high enough to read the face each bone lies on, low enough to see it fly
	cam.position = Vector3(0, 1.3, 0.72)
	_vp.add_child(cam)
	cam.look_at(Vector3(0, 0, 0.02), Vector3.UP)
	var kit := MeshKit.new()
	kit.box("paving", Vector3(0, -SLAB.y / 2.0, 0), SLAB, [])
	var slab := kit.build("Slab")
	_vp.add_child(slab)
	_rest_y = rest_height()
	var mesh := bone_mesh()
	for side in 2:
		for i in AstragalGame.BONES:
			var b := MeshInstance3D.new()
			b.mesh = mesh
			b.scale = Vector3.ONE * BONE_SCALE
			b.visible = false
			_vp.add_child(b)
			_bones[side].append(b)
	visibility_changed.connect(func() -> void:
		_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if is_visible_in_tree() else SubViewport.UPDATE_DISABLED)


## A knucklebone: a bar with a knob at each end, and on each of its four long
## faces as many pips as that face counts.
static func bone_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.box("bone", Vector3.ZERO, Vector3(BONE_LEN, BONE_H, BONE_D), [])
	for s: float in [1.0, -1.0]:
		kit.box("bone", Vector3(s * BONE_LEN * 0.5, 0.0, 0.0), Vector3(0.024, BONE_H * KNOB, BONE_D * KNOB), [])
	var pip := 0.008
	for v: int in FACE_AXES:
		var n: Vector3 = FACE_AXES[v]
		var half := (BONE_H if absf(n.y) > 0.5 else BONE_D) / 2.0
		# six is two rows of three: a row of six would run into the knobs
		var rows := 2 if v == 6 else 1
		var per := v / rows
		for k in v:
			var col := k % per
			var row := k / per
			var x := (float(col) - float(per - 1) / 2.0) * 0.014
			var across := (float(row) - float(rows - 1) / 2.0) * 0.016
			var off := Vector3(x, 0, across) if absf(n.y) > 0.5 else Vector3(x, across, 0)
			var c := off + n * (half + 0.0005)
			var sz := Vector3(pip, 0.002, pip) if absf(n.y) > 0.5 else Vector3(pip, pip, 0.002)
			kit.box("dark", c, sz, [])
	return kit.commit()


## How high a bone's middle lies over the slab when it rests on a long face:
## on its knobs, which stand proud of the bar on every side.
static func rest_height() -> float:
	return maxf(BONE_H, BONE_D) * KNOB * 0.5 * BONE_SCALE


## The bone's orientation showing face v, turned by yaw about the vertical.
static func face_basis(v: int, yaw: float) -> Basis:
	return Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, float(FACE_ANGLES[v]))


## Which face a bone so turned shows: the long face whose normal points most up.
static func face_up(b: Basis) -> int:
	var best := 1
	var most := -INF
	for v: int in FACE_AXES:
		var up := (b * (FACE_AXES[v] as Vector3)).y
		if up > most:
			most = up
			best = v
	return best


## Where bone i of a side comes down, for throw n: a row across that side's
## half of the slab, nudged a little each throw so no two throws look alike.
static func spot(side: int, i: int, n: int) -> Vector3:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7300 + n * 131 + side * 17 + i * 5
	var x := (float(i) - float(AstragalGame.BONES - 1) / 2.0) * SPACING + rng.randf_range(-JITTER, JITTER)
	var z := ROW_Z * (1.0 if side == 0 else -1.0) + rng.randf_range(-JITTER, JITTER)
	return Vector3(x, 0, z)


## The bone k (0..1) of the way through its flight: along the arc from the
## hand to the spot, a small kick on landing, and the tumble dying away into
## the face it will show.
static func pose(start: Vector3, at: Vector3, final: Basis, axis: Vector3, spins: float, k: float, rest_y: float) -> Transform3D:
	k = clampf(k, 0.0, 1.0)
	var p: Vector3
	if k < LAND_AT:
		var u := k / LAND_AT
		p = start.lerp(at + Vector3(0, rest_y, 0), u) + Vector3.UP * ARC * 4.0 * u * (1.0 - u)
	else:
		var u := (k - LAND_AT) / (1.0 - LAND_AT)
		p = at + Vector3(0, rest_y + BOUNCE * 4.0 * u * (1.0 - u), 0)
	var turn := spins * TAU * pow(1.0 - minf(k / LAND_AT, 1.0), 2.0)
	return Transform3D(final * Basis(axis.normalized(), turn), p)


## Throw both hands: the player's counts onto the near half, then the children's.
func throw_hands(mine: Array[int], theirs: Array[int], n: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 911 + n * 53
	for side in 2:
		var counts: Array[int] = mine if side == 0 else theirs
		_plans[side].clear()
		for i in counts.size():
			var axis := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.3, 0.3), rng.randf_range(-1, 1))
			if axis.length() < 0.2:
				axis = Vector3.RIGHT
			var start: Vector3 = HANDS[side] + Vector3(rng.randf_range(-0.04, 0.04), 0, rng.randf_range(-0.03, 0.03))
			_plans[side].append([start, spot(side, i, n), face_basis(counts[i], rng.randf_range(-0.6, 0.6)), axis,
					rng.randf_range(1.5, 3.0), float(i) * STAGGER + float(side) * (FLY + HAND_GAP)])
			(_bones[side][i] as MeshInstance3D).visible = false
	_landed = [false, false]
	_t = 0.0


## True while bones are in the air.
func busy() -> bool:
	return _t >= 0.0


## The bones off the slab, for a new game.
func clear() -> void:
	_t = -1.0
	for side in 2:
		for b: MeshInstance3D in _bones[side]:
			b.visible = false


## What each side's bones show now (for tests and the walkthrough).
func shown(side: int) -> Array[int]:
	var out: Array[int] = []
	for b: MeshInstance3D in _bones[side]:
		out.append(face_up(b.transform.basis.orthonormalized()))
	return out


func _process(delta: float) -> void:
	if _t < 0.0:
		return
	_t += delta
	var all_done := true
	for side in 2:
		var side_done := true
		for i in _plans[side].size():
			var plan: Array = _plans[side][i]
			var k: float = (_t - float(plan[5])) / (FLY + STAGGER * 0.0)
			var b: MeshInstance3D = _bones[side][i]
			if k < 0.0:
				side_done = false
				b.visible = false
				continue
			b.visible = true
			var xf := pose(plan[0], plan[1], plan[2], plan[3], plan[4], k, _rest_y)
			b.transform = Transform3D(xf.basis.scaled(Vector3.ONE * BONE_SCALE), xf.origin)
			if k < 1.0:
				side_done = false
		if side_done and not _landed[side]:
			_landed[side] = true
			landed.emit(side)
		all_done = all_done and side_done
	if all_done:
		_t = -1.0
		settled.emit()
