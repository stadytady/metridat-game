extends District
## The dream that comes in Hecate's abaton. A separate small place far off the
## map (behind the fog no one sees it): a stony path through thick fog under a
## bright moon, a figure standing ahead that is gone when you come close,
## three times, and at the end a burial mound with a stone-lined entrance
## (dromos) and an altar before it, where a bronze mirror lies. Looking into
## the mirror opens the mound: its doors creak open on a long stair down to a
## corbel-vaulted chamber, where someone sleeps on a couch, lying as the
## dreamer lay down. Leaning over them: THE END, credits, waking in the abaton.
##
## Lying down and waking happen behind a fade to black; the hour jumps to
## DayCycle.DREAM and back, the city's sounds go quiet meanwhile.

const ORIGIN := Vector3(0, 60, 2600)
const LENGTH := 78.0
const HALF_WIDTH := 6.5
const FIGURES_Z := [22.0, 44.0, 63.0]
const VANISH_DIST := 9.0
const MOUND := Vector3(0, 0, 92)
const MOUND_R := 11.0
const MOUND_H := 5.0
const ALTAR := Vector3(0, 0, 76.5)
const ALTAR_TOP := 1.03  # top of the altar's crowning slab
const MIRROR_LIFT := 0.33  # disc centre above it: the handle (0.32) stands on the slab
const MIRROR_LEAN := 70.0  # degrees from lying flat
const ATM := preload("res://scripts/world/atmosphere.gd")

## The tomb under the mound. The doorway is in the dromos' front, between the
## jambs; inside, a stair goes down to a level passage and a square chamber.
## Vaults are corbelled, each course stepping in over the one below, as in the
## Bosporan kurgans of the 4th century BCE; the long stair is the dream's own.
const DOOR_Z := MOUND.z - MOUND_R - 0.4  # a stone portal at the mound's foot
const DOOR_HALF := 0.95
const DOOR_H := 2.38
const HALL_HALF := 0.95
const STEPS := 22
const STEP_RISE := 0.2
const STEP_RUN := 0.4
const STAIR_Z := DOOR_Z + 0.4  # a short landing behind the doors
const DEPTH := STEPS * STEP_RISE
const PASSAGE := 3.6  # level dromos between the stair foot and the chamber
const CHAMBER_HALF := 2.2
const WALL_H := 1.7  # dromos walls below the first corbel course
const COURSES := 4
const COURSE_H := 0.35
const COURSE_IN := 0.2
const CH_WALL_H := 2.2
const CH_COURSES := 6
const CH_COURSE_H := 0.4
const CH_COURSE_IN := 0.3
const DOOR_OPEN_DEG := 88.0  # back against the passage walls
const DOOR_SECONDS := 3.0

var figures: Array[Apparition] = []
## Sound of the dream: a low drone, and a dog howling somewhere ahead in the
## fog (the dog was Hecate's animal). Only while dreaming.
var howls := 0
var _drone: AudioStreamPlayer
var _howl: AudioStreamPlayer3D
var _howl_timer: Timer
var _rng := RandomNumberGenerator.new()
var vanished := 0
var ended := false

var doors_open := false
var _door_t := -1.0
var _leaves: Array[Node3D] = []
var _door_body: StaticBody3D
var _creak: AudioStreamPlayer3D
var sleeper: TombSleeper

var _fade: ColorRect
var _end: CanvasLayer
var _mirror_found := false
var _wake_at := Vector3.ZERO


## The mirror model lies face up with its handle along +z. Stood up: tipped
## about x so the face turns to +z and the handle points down, leaning back,
## then turned to face -z, back down the path.
static func mirror_basis() -> Basis:
	return Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, deg_to_rad(MIRROR_LEAN))


## How far the doors are open (0 shut .. 1 wide), t seconds after they start:
## eased out, stepped at 15 fps like everything that moves in the game.
static func door_open_at(t: float) -> float:
	var q := floorf(t * 15.0 + 0.001) / 15.0
	var u := clampf(q / DOOR_SECONDS, 0.0, 1.0)
	return 1.0 - (1.0 - u) * (1.0 - u)


## Floor height (local y) at local z inside the tomb: the landing, the stair
## (as a ramp through the step edges, which is what the player walks on), the
## passage and the chamber.
static func tomb_floor(z: float) -> float:
	if z <= STAIR_Z:
		return 0.0
	return -minf((z - STAIR_Z) / STEP_RUN * STEP_RISE, DEPTH)


static func stair_end() -> float:
	return STAIR_Z + STEPS * STEP_RUN


static func chamber_center() -> Vector3:
	return Vector3(0, -DEPTH, stair_end() + PASSAGE + CHAMBER_HALF)


## The path's centre line, gently winding (local x for a local z).
static func path_x(z: float) -> float:
	return 3.0 * sin(z / 14.0) * clampf(z / 10.0, 0.0, 1.0) * clampf((ALTAR.z - z) / 12.0, 0.0, 1.0)


## Start, local to the origin: the player stands here, facing along the path.
static func start_point() -> Vector3:
	return ORIGIN + Vector3(0, 0.05, 1.0)


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1225
	var kit := MeshKit.new()
	kit.xform = Transform3D(Basis.IDENTITY, ORIGIN)
	_ground(kit, rng)
	_path(kit, rng)
	_mound(kit)
	_altar(kit)
	_walls(kit)
	add_child(kit.build("Dream", &"dirt"))
	var tk := MeshKit.new()
	tk.xform = Transform3D(Basis.IDENTITY, ORIGIN)
	_tomb(tk)
	var tomb := tk.build("Tomb", &"stone")
	add_child(tomb)
	_underground(tomb)
	_trees(rng)
	_olives()
	_figures()
	# The mirror stands on the altar, leaning back a little, its face to the
	# path and the handle down: seen from afar, catching the moon. (Lying flat
	# it sank into the altar's top and only the marker showed.)
	# Only the model is stood up: the find's collider and marker stay upright.
	var mirror := spawn_inspectable("bronze_mirror", ORIGIN + ALTAR + Vector3(0, ALTAR_TOP, -0.08), 0.0)
	var model := mirror.get_child(0) as Node3D
	model.transform = Transform3D(mirror_basis(), Vector3(0, MIRROR_LIFT, 0))
	_altar_lamp()
	_doors()
	_tomb_contents()
	var zone := Area3D.new()
	zone.set_script(preload("res://scripts/world/zone.gd"))
	zone.title = "LOC_DREAM"
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(20, 8, 12)
	cs.shape = sh
	cs.position = ORIGIN + Vector3(0, 2, 4)
	zone.add_child(cs)
	add_child(zone)
	_sound()
	Game.dream_requested.connect(enter)
	Game.discovered.connect(func(d: Discovery, _new: bool) -> void:
		if d.epilogue:
			_mirror_found = true)
	Game.inspect_closed.connect(func() -> void:
		if _mirror_found and Game.dreaming and not ended:
			open_doors())


## The meadow's one tint (vertex colour on the grass).
const GROUND_TINT := 0.85


## UVs for a ground cell from its plan position, metres scaled as MeshKit's
## own quads are, so neighbouring cells meet with the texture running on.
static func ground_uvs(corners: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector3 in corners:
		out.append(Vector2(p.x, -p.z))
	return out


func _ground(kit: MeshKit, rng: RandomNumberGenerator) -> void:
	# Flat where one walks, low dark hills beyond the walls; the fog eats the rest.
	var step := 4.0
	var hill := func(x: float, z: float) -> float:
		var off := absf(x - path_x(z)) - HALF_WIDTH
		return maxf(0.0, off) * 0.18 + sin(x * 0.21 + z * 0.13) * 0.5 * clampf(off / 6.0, 0.0, 1.0)
	for iz in range(-6, 30):
		for ix in range(-12, 12):
			var x0 := ix * step
			var z0 := iz * step
			if x0 >= -4.0 and x0 < 4.0 and z0 >= 80.0:
				continue  # the portal's forecourt and the mound: the tomb is dug here
			var a := Vector3(x0, hill.call(x0, z0), z0)
			var b := Vector3(x0 + step, hill.call(x0 + step, z0), z0)
			var c := Vector3(x0 + step, hill.call(x0 + step, z0 + step), z0 + step)
			var d := Vector3(x0, hill.call(x0, z0 + step), z0 + step)
			# One material, one tint, UVs laid on the plan (x, z): a cell of
			# its own colour, earth or grass, or its own UV frame left a 4 m
			# rectangle with a hard edge in the meadow. The two rng draws stay,
			# so the stones and trees placed after keep their spots.
			rng.randf_range(0.75, 0.95)
			rng.randf()
			kit.color = Color(GROUND_TINT, GROUND_TINT, GROUND_TINT, 1.0)
			kit.quad("grass", d, c, b, a, ground_uvs([d, c, b, a]))
	kit.color = Color.WHITE
	# a paved forecourt before the portal, open where the passage goes down
	var fz := 79.6
	for sx: float in [-1.0, 1.0]:
		var a := Vector3(sx * HALL_HALF, 0.0, fz)
		var b := Vector3(sx * 4.0, 0.0, fz)
		var c := Vector3(sx * 4.0, 0.0, 84.0)
		var d := Vector3(sx * HALL_HALF, 0.0, 84.0)
		if sx > 0:
			kit.quad("paving", d, c, b, a)
		else:
			kit.quad("paving", a, b, c, d)
	kit.quad("paving", Vector3(-HALL_HALF, 0.0, DOOR_Z), Vector3(HALL_HALF, 0.0, DOOR_Z), Vector3(HALL_HALF, 0.0, fz), Vector3(-HALL_HALF, 0.0, fz))
	# the ground, with a slot left open over the passage and the tomb below it
	var cut := DOOR_Z
	var side := HALL_HALF + 0.4
	kit.add_collider(Vector3(0, -0.5, (-30.0 + cut) / 2.0), Vector3(96, 1.0, cut + 30.0))
	for sx: float in [-1.0, 1.0]:
		kit.add_collider(Vector3(sx * (side + 48.0) / 2.0, -0.5, (cut + 110.0) / 2.0), Vector3(48.0 - side, 1.0, 110.0 - cut))
	var back := chamber_center().z + CHAMBER_HALF + 0.4
	kit.add_collider(Vector3(0, -0.5, (back + 110.0) / 2.0), Vector3(side * 2.0, 1.0, 110.0 - back))


func _path(kit: MeshKit, rng: RandomNumberGenerator) -> void:
	var z := -2.0
	while z < ALTAR.z - 2.0:
		var x := path_x(z) + rng.randf_range(-0.6, 0.6)
		var r := rng.randf_range(0.35, 0.6)
		kit.blob("rock", Vector3(x, 0.02, z), Vector3(r, 0.06, r * 0.8), 0.2, rng)
		z += rng.randf_range(0.9, 1.6)
	# standing stones along both sides, like a way of graves
	z = 6.0
	while z < ALTAR.z - 6.0:
		for side: float in [-1.0, 1.0]:
			if rng.randf() < 0.55:
				var x := path_x(z) + side * rng.randf_range(3.2, 5.0)
				var h := rng.randf_range(0.8, 1.8)
				kit.blob("rock", Vector3(x, h * 0.5, z + rng.randf_range(-1, 1)), Vector3(0.35, h * 0.6, 0.3), 0.25, rng)
		z += rng.randf_range(5.0, 8.0)


## The burial mound: a low cone of earth and grass, with a dromos (stone-lined
## entrance passage) facing the path, its doorway dark.
func _mound(kit: MeshKit) -> void:
	_mound_shell(kit)
	# hollow now: the mound's bulk either side of the tomb, and over the doorway
	var bulk := MOUND_R * 1.4
	for sx: float in [-1.0, 1.0]:
		var w := bulk / 2.0 - 1.25
		kit.add_collider(MOUND + Vector3(sx * (1.25 + w / 2.0), MOUND_H * 0.35, 0), Vector3(w, MOUND_H * 0.7, bulk))
	kit.add_collider(MOUND + Vector3(0, 2.83 + (MOUND_H * 0.7 - 2.83) / 2.0, 0), Vector3(2.5, MOUND_H * 0.7 - 2.83, bulk))
	# the portal: two jambs and a lintel at the mound's foot, a threshold slab;
	# the passage behind runs in under the earth
	for sx: float in [-1.0, 1.0]:
		kit.solid_box("limestone", Vector3(sx * (DOOR_HALF + 0.35), (DOOR_H + 0.1) / 2.0, DOOR_Z + 0.2), Vector3(0.7, DOOR_H + 0.1, 1.0), ["bottom"])
	kit.box("limestone", Vector3(0, DOOR_H + 0.3, DOOR_Z + 0.2), Vector3(DOOR_HALF * 2.0 + 1.6, 0.45, 1.2), [])
	kit.box("limestone", Vector3(0, DOOR_H + 0.62, DOOR_Z + 0.35), Vector3(DOOR_HALF * 2.0 + 1.0, 0.2, 0.9), [])
	kit.box("limestone", Vector3(0, 0.03, DOOR_Z - 0.35), Vector3(DOOR_HALF * 2.0 + 0.8, 0.06, 0.7), [])


## The mound's earth: a lathe of grass, but with the two lowest sectors facing
## the portal left out, so the passage can go in under it (its stone walls and
## vault close the cut). No bottom cap: the tomb is below it.
const MOUND_SEGMENTS := 56


static func mound_profile() -> PackedVector2Array:
	return PackedVector2Array([Vector2(MOUND_R, -0.2), Vector2(MOUND_R * 0.8, MOUND_H * 0.45), Vector2(MOUND_R * 0.45, MOUND_H * 0.85),
		Vector2(0.0, MOUND_H)])


## Is this sector of this ring cut away for the passage? Sectors straddling
## -z (the portal side) in the lowest ring only.
static func mound_cut(i: int, j: int) -> bool:
	var mid := TAU * (i + 0.5) / MOUND_SEGMENTS
	return j == 0 and absf(cos(mid)) * MOUND_R < HALL_HALF + 0.4 and sin(mid) < 0.0


func _mound_shell(kit: MeshKit) -> void:
	var prof := mound_profile()
	var n := MOUND_SEGMENTS
	var ring := func(r: float, y: float, i: int) -> Vector3:
		var ang := TAU * float(i) / float(n)
		return MOUND + Vector3(cos(ang) * r, y, sin(ang) * r)
	for i in n:
		var u0 := float(i) / n * 4.0
		var u1 := float(i + 1) / n * 4.0
		for j in prof.size() - 1:
			if mound_cut(i, j):
				continue
			var lo := prof[j]
			var hi := prof[j + 1]
			var a: Vector3 = ring.call(lo.x, lo.y, i)
			var b: Vector3 = ring.call(lo.x, lo.y, i + 1)
			var c: Vector3 = ring.call(hi.x, hi.y, i + 1)
			var d: Vector3 = ring.call(hi.x, hi.y, i)
			# as MeshKit.lathe: a,d,c,b is counter-clockwise seen from outside
			var ua := Vector2(u0, -lo.y)
			var ub := Vector2(u1, -lo.y)
			var uc := Vector2(u1, -hi.y)
			var ud := Vector2(u0, -hi.y)
			if hi.x < 0.0001:
				kit.tri("grass", a, d, b, ua, ud, ub)
			else:
				kit.tri("grass", a, d, c, ua, ud, uc)
				kit.tri("grass", a, c, b, ua, uc, ub)


## Inside the mound: walls and corbelled vaults of dressed stone, darker the
## deeper they go (baked into the vertex colour; the lamp below lights the
## chamber). Built with no affine cut-up: it is all small blocks already.
func _tomb(kit: MeshKit) -> void:
	var shade := func(y: float) -> Color:
		var c := Color.WHITE * lerpf(0.85, 0.4, clampf(-y / DEPTH, 0.0, 1.0))
		c.a = 1.0
		return c
	# the landing and the stair: one block per step, its vault stepping down with it
	kit.color = shade.call(0.0)
	kit.solid_box("limestone", Vector3(0, -0.1, (DOOR_Z - 0.3 + STAIR_Z) / 2.0), Vector3(HALL_HALF * 2.0, 0.2, STAIR_Z - DOOR_Z + 0.3), [])
	_passage_section(kit, DOOR_Z, STAIR_Z, 0.0, shade)
	for i in STEPS:
		var z0 := STAIR_Z + i * STEP_RUN
		var top := -(i + 1) * STEP_RISE
		kit.color = shade.call(top)
		kit.box("limestone", Vector3(0, top - 0.1, z0 + STEP_RUN / 2.0), Vector3(HALL_HALF * 2.0, 0.2 + STEP_RISE, STEP_RUN), [])
	# the walls and vault come down in stretches of two steps: one stretch per
	# step made a saw of the ceiling
	var i := 0
	while i < STEPS:
		var n := mini(2, STEPS - i)
		var z0 := STAIR_Z + i * STEP_RUN
		_passage_section(kit, z0, z0 + n * STEP_RUN, -(i + n) * STEP_RISE, shade, n * STEP_RISE)
		i += n
	# the stair as the player feels it: a ramp along the step edges
	var run := STEPS * STEP_RUN
	var slope := atan2(DEPTH, run)
	kit.xform = kit.xform * Transform3D(Basis(Vector3.RIGHT, slope), Vector3(0, -DEPTH / 2.0 - 0.1, STAIR_Z + run / 2.0))
	kit.add_collider(Vector3(0, -0.1, 0), Vector3(HALL_HALF * 2.0, 0.2, run / cos(slope)))
	kit.xform = Transform3D(Basis.IDENTITY, ORIGIN)
	# the level passage
	var p0 := stair_end()
	kit.color = shade.call(-DEPTH)
	kit.solid_box("limestone", Vector3(0, -DEPTH - 0.1, p0 + PASSAGE / 2.0), Vector3(HALL_HALF * 2.0, 0.2, PASSAGE), [])
	_passage_section(kit, p0, p0 + PASSAGE, -DEPTH, shade)
	# side walls along the whole run keep the player in the passage
	for sx: float in [-1.0, 1.0]:
		var zz := (DOOR_Z + p0 + PASSAGE) / 2.0
		kit.add_collider(Vector3(sx * (HALL_HALF + 0.2), -DEPTH / 2.0 + 1.0, zz), Vector3(0.4, DEPTH + 2.0, p0 + PASSAGE - DOOR_Z))
	_chamber(kit, shade)
	kit.color = Color.WHITE


## One stretch of the dromos: walls, four corbel courses closing in, a capstone.
func _passage_section(kit: MeshKit, z0: float, z1: float, floor_y: float, shade: Callable, drop: float = 0.0) -> void:
	var span := z1 - z0
	var zm := (z0 + z1) / 2.0
	kit.color = shade.call(floor_y)
	for sx: float in [-1.0, 1.0]:
		# down past the floor to the step below, so no gap shows under a wall
		var bottom := floor_y - STEP_RISE - 0.2
		var top := floor_y + WALL_H + drop
		kit.box("limestone", Vector3(sx * (HALL_HALF + 0.2), (bottom + top) / 2.0, zm), Vector3(0.4, top - bottom, span), [])
		for k in COURSES:
			var inner := HALL_HALF - COURSE_IN * (k + 1)
			var y := floor_y + drop + WALL_H + COURSE_H * (k + 0.5)
			var outer := HALL_HALF + 0.4
			kit.box("limestone", Vector3(sx * (inner + outer) / 2.0, y, zm), Vector3(outer - inner, COURSE_H, span), [])
	var gap := HALL_HALF - COURSE_IN * COURSES
	# a key block fills the slit between the top courses: where the vault
	# steps down to the next stretch, an open slit showed the sky beyond
	kit.box("limestone", Vector3(0, floor_y + drop + WALL_H + COURSE_H * (COURSES - 0.5), zm), Vector3(gap * 2.0 + 0.02, COURSE_H, span), [])
	kit.box("limestone", Vector3(0, floor_y + drop + WALL_H + COURSE_H * COURSES + 0.1, zm), Vector3(gap * 2.0 + 0.3, 0.2, span), [])
	# an unseen ceiling, so a jump on the stair does not end up in the vault
	kit.add_collider(Vector3(0, floor_y + drop + 2.5, zm), Vector3(HALL_HALF * 2.0, 0.2, span))


## The burial chamber: square, its walls rising into a corbelled dome of six
## courses, each stepping in over the one below, closed by a slab. A couch of
## stone with the sleeper, grave goods round it, a lamp burning in a niche.
func _chamber(kit: MeshKit, shade: Callable) -> void:
	var c := chamber_center()
	var h := CHAMBER_HALF
	var fy := c.y
	kit.color = shade.call(fy)
	kit.solid_box("limestone", Vector3(c.x, fy - 0.1, c.z), Vector3(h * 2.0, 0.2, h * 2.0), [])
	# walls; the front one has the passage's doorway, a lintel over it
	var front := c.z - h
	for sx: float in [-1.0, 1.0]:
		kit.solid_box("limestone", Vector3(sx * (h + 0.2), fy + CH_WALL_H / 2.0, c.z), Vector3(0.4, CH_WALL_H, h * 2.0 + 0.8), [])
		var w := h - HALL_HALF
		kit.solid_box("limestone", Vector3(sx * (HALL_HALF + w / 2.0), fy + CH_WALL_H / 2.0, front - 0.2), Vector3(w, CH_WALL_H, 0.4), [])
	kit.solid_box("limestone", Vector3(0, fy + CH_WALL_H / 2.0, c.z + h + 0.2), Vector3(h * 2.0, CH_WALL_H, 0.4), [])
	kit.box("limestone", Vector3(0, fy + (WALL_H + CH_WALL_H) / 2.0, front - 0.2), Vector3(HALL_HALF * 2.0, CH_WALL_H - WALL_H, 0.4), [])
	# the dome
	for k in CH_COURSES:
		var inner := h - CH_COURSE_IN * (k + 1)
		var outer := h + 0.4
		var y := fy + CH_WALL_H + CH_COURSE_H * (k + 0.5)
		for sx: float in [-1.0, 1.0]:
			kit.box("limestone", Vector3(sx * (inner + outer) / 2.0, y, c.z), Vector3(outer - inner, CH_COURSE_H, outer * 2.0), [])
			kit.box("limestone", Vector3(0, y, c.z + sx * (inner + outer) / 2.0), Vector3(inner * 2.0, CH_COURSE_H, outer - inner), [])
	var top := h - CH_COURSE_IN * CH_COURSES
	kit.box("limestone", Vector3(0, fy + CH_WALL_H + CH_COURSE_H * CH_COURSES + 0.1, c.z), Vector3(top * 2.0 + 0.3, 0.2, top * 2.0 + 0.3), [])
	# the couch against the back wall, a fleece on it and a stone headrest
	var couch := Vector3(0, fy, c.z + 0.9)
	kit.solid_box("limestone", couch + Vector3(0, 0.25, 0), Vector3(2.2, 0.5, 0.95), [])
	kit.box("fleece", couch + Vector3(0, 0.53, 0), Vector3(2.0, 0.06, 0.85), [])
	kit.box("limestone", couch + Vector3(-0.95, 0.62, 0), Vector3(0.25, 0.18, 0.7), [])
	# a niche in the side wall for the lamp
	kit.box("dark", Vector3(-h + 0.01, fy + 1.15, c.z + 0.2), Vector3(0.02, 0.45, 0.5), [])
	kit.box("limestone", Vector3(-h + 0.15, fy + 0.92, c.z + 0.2), Vector3(0.3, 0.06, 0.45), [])  # its sill
	kit.color = Color.WHITE


## Out of the sun's and the moon's reach (see ATM.UNDERGROUND).
static func _underground(n: Node) -> void:
	for g: GeometryInstance3D in n.find_children("*", "GeometryInstance3D", true, false):
		g.layers = ATM.UNDERGROUND
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).layers = ATM.UNDERGROUND


func _tomb_contents() -> void:
	var c := ORIGIN + chamber_center()
	sleeper = TombSleeper.new()
	sleeper.name = "TombSleeper"
	sleeper.position = c + Vector3(0, 0, 0.9)
	add_child(sleeper)
	sleeper.leaned.connect(func() -> void:
		if Game.dreaming and not ended:
			the_end())
	# grave goods: an amphora in each back corner, a krater by the couch's foot,
	# a gold wreath laid by the sleeper's head
	for sx: float in [-1.0, 1.0]:
		_underground(place("amphora", c + Vector3(sx * 1.75, 0, 1.75), sx * 30.0, Vector3.ONE * 0.9))
	_underground(place("krater", c + Vector3(1.55, 0, 0.0), 20.0))
	_underground(sleeper)
	var wk := MeshKit.new()
	for i in 10:
		var a := TAU * i / 10.0
		wk.box("gold", c + Vector3(-0.55 + cos(a) * 0.14, 0.57, 0.55 + sin(a) * 0.14), Vector3(0.07, 0.02, 0.04), [])
	var wreath := wk.build("Wreath")
	add_child(wreath)
	_underground(wreath)
	# the lamp in its niche lights the chamber; another, on a ledge halfway
	# down the stair, keeps the way from being black
	_tomb_lamp("TombLamp", c + Vector3(-CHAMBER_HALF + 0.12, 0.95, 0.2), 6.5, 1.4)
	var mid := STAIR_Z + STEPS * STEP_RUN * 0.5
	var ledge := ORIGIN + Vector3(-HALL_HALF + 0.12, tomb_floor(mid) + 1.25, mid)
	var lk := MeshKit.new()
	lk.box("limestone", ledge + Vector3(0.0, -0.04, 0), Vector3(0.24, 0.08, 0.36), [])
	var shelf := lk.build("StairLedge")
	add_child(shelf)
	_underground(shelf)
	_tomb_lamp("StairLamp", ledge, 5.0, 0.9)


func _tomb_lamp(name_: String, at: Vector3, reach: float, energy: float) -> void:
	var lk := MeshKit.new()
	lk.lathe("clay", PackedVector2Array([Vector2(0.05, 0.0), Vector2(0.08, 0.03), Vector2(0.06, 0.07)]), 6, at, 1.0, true, "dark", true)
	lk.box("flame", at + Vector3(0.09, 0.1, 0), Vector3(0.04, 0.07, 0.04), [])
	var lamp := lk.build(name_)
	add_child(lamp)
	_underground(lamp)
	var glow := OmniLight3D.new()
	glow.position = at + Vector3(0.4, 0.3, 0)
	glow.light_color = Color(1, 0.66, 0.36)
	glow.omni_range = reach
	glow.set_script(preload("res://scripts/world/flicker.gd"))
	glow.base_energy = energy
	glow.amount = 0.3
	glow.shadow_enabled = true  # keep the lamp's light inside the mound
	add_child(glow)


## Two wooden leaves in the doorway, hinged on the jambs, opening inward.
func _doors() -> void:
	for sx: float in [-1.0, 1.0]:
		var hinge := Node3D.new()
		hinge.name = "DoorLeaf%s" % ("L" if sx < 0 else "R")
		hinge.position = ORIGIN + Vector3(sx * DOOR_HALF, 0, DOOR_Z)
		add_child(hinge)
		var k := MeshKit.new()
		k.box("door", Vector3(-sx * DOOR_HALF / 2.0, DOOR_H / 2.0, 0.04), Vector3(DOOR_HALF - 0.02, DOOR_H - 0.02, 0.08), [])
		for y: float in [0.45, DOOR_H - 0.45]:
			k.box("bronze", Vector3(-sx * DOOR_HALF / 2.0, y, -0.01), Vector3(DOOR_HALF - 0.1, 0.06, 0.02), [])  # straps
		var mi := MeshInstance3D.new()
		mi.mesh = k.commit()
		hinge.add_child(mi)
		_leaves.append(hinge)
	_door_body = StaticBody3D.new()
	_door_body.name = "DoorStop"
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(DOOR_HALF * 2.0, DOOR_H, 0.2)
	cs.shape = sh
	cs.position = ORIGIN + Vector3(0, DOOR_H / 2.0, DOOR_Z + 0.05)
	_door_body.add_child(cs)
	add_child(_door_body)
	_creak = AudioStreamPlayer3D.new()
	_creak.name = "DoorCreak"
	_creak.stream = preload("res://assets/audio/door_creak.wav")
	_creak.position = ORIGIN + Vector3(0, 1.4, DOOR_Z)
	_creak.unit_size = 12.0
	_creak.volume_db = -2.0
	add_child(_creak)
	_set_doors(0.0)


func _set_doors(open: float) -> void:
	var deg := DOOR_OPEN_DEG * open
	_leaves[0].rotation.y = deg_to_rad(-deg)  # the left leaf swings in (+z)
	_leaves[1].rotation.y = deg_to_rad(deg)


## The mirror seen: the mound opens.
func open_doors() -> void:
	if _door_t >= 0.0:
		return
	_door_t = 0.0
	_creak.play()
	(_door_body.get_child(0) as CollisionShape3D).disabled = true


func _shut_doors() -> void:
	_door_t = -1.0
	doors_open = false
	_set_doors(0.0)
	(_door_body.get_child(0) as CollisionShape3D).disabled = false


func _altar(kit: MeshKit) -> void:
	kit.solid_box("limestone", ALTAR + Vector3(0, 0.08, 0), Vector3(1.8, 0.16, 1.2), ["bottom"])
	kit.solid_box("limestone", ALTAR + Vector3(0, 0.55, 0), Vector3(1.3, 0.8, 0.8), ["bottom"], {"pz": "plaster", "nz": "plaster"})
	kit.box("limestone", ALTAR + Vector3(0, 0.98, 0), Vector3(1.45, 0.1, 0.9), ["bottom"])


func _sound() -> void:
	_rng.seed = 516
	_drone = AudioStreamPlayer.new()
	_drone.name = "DreamDrone"
	_drone.stream = preload("res://assets/audio/dream_drone.wav")
	_drone.volume_db = -10.0
	add_child(_drone)
	_howl = AudioStreamPlayer3D.new()
	_howl.name = "DreamHowl"
	_howl.stream = preload("res://assets/audio/dog_howl.wav")
	_howl.unit_size = 25.0
	_howl.max_distance = 200.0
	_howl.volume_db = -6.0
	add_child(_howl)
	_howl_timer = Timer.new()
	_howl_timer.one_shot = true
	_howl_timer.timeout.connect(_howl_once)
	add_child(_howl_timer)
	Game.dream_changed.connect(func(on: bool) -> void:
		if on:
			_drone.play()
			_howl_timer.start(5.0)
		else:
			_drone.stop()
			_howl.stop()
			_howl_timer.stop())


## Somewhere off the path, ahead and to one side, never twice from the same place.
func _howl_once() -> void:
	if not Game.dreaming:
		return
	var cam := get_viewport().get_camera_3d()
	var ahead := cam.global_position.z - ORIGIN.z + _rng.randf_range(25.0, 45.0) if cam else 60.0
	_howl.global_position = ORIGIN + Vector3(_rng.randf_range(-30.0, 30.0), 2.0, ahead)
	_howl.pitch_scale = _rng.randf_range(0.9, 1.08)
	_howl.play()
	howls += 1
	_howl_timer.start(_rng.randf_range(13.0, 22.0))


## A small clay oil lamp burning beside the mirror: the polished face catches
## its glow, so the mirror shines out of the fog instead of standing dark.
func _altar_lamp() -> void:
	var at := ORIGIN + ALTAR + Vector3(0.45, ALTAR_TOP, -0.25)
	var k := MeshKit.new()
	k.lathe("clay", PackedVector2Array([Vector2(0.05, 0.0), Vector2(0.08, 0.03), Vector2(0.06, 0.07)]), 6, at, 1.0, true, "dark", true)
	k.box("clay", at + Vector3(0.09, 0.055, 0), Vector3(0.07, 0.025, 0.03), [])
	k.box("flame", at + Vector3(0.12, 0.1, 0), Vector3(0.04, 0.07, 0.04), [])
	add_child(k.build("AltarLamp"))
	var glow := OmniLight3D.new()
	glow.position = at + Vector3(0.1, 0.25, -0.35)
	glow.light_color = Color(1, 0.7, 0.4)
	glow.omni_range = 3.5
	glow.set_script(preload("res://scripts/world/flicker.gd"))
	glow.base_energy = 1.6
	glow.amount = 0.25
	add_child(glow)


## Invisible walls keep the dreamer on the path; the mound closes the end.
func _walls(kit: MeshKit) -> void:
	var z := -4.0
	while z < MOUND.z:
		for side: float in [-1.0, 1.0]:
			kit.add_collider(Vector3(path_x(z + 2.0) + side * (HALF_WIDTH + 0.5), 2.0, z + 2.0), Vector3(0.5, 4.0, 4.4))
		z += 4.0
	kit.add_collider(Vector3(0, 2.0, -4.5), Vector3(2 * HALF_WIDTH + 2.0, 4.0, 0.5))


func _trees(rng: RandomNumberGenerator) -> void:
	# dead trees and a few cypresses: dark shapes in the fog
	for i in 14:
		var z := rng.randf_range(4.0, 74.0)
		var side := -1.0 if i % 2 == 0 else 1.0
		var x := path_x(z) + side * rng.randf_range(8.0, 16.0)
		if i % 3 == 0:
			place("cypress", ORIGIN + Vector3(x, 0, z), rng.randf_range(0, 360), Vector3.ONE * rng.randf_range(0.9, 1.3))
		else:
			var k := MeshKit.new()
			k.xform = Transform3D(Basis(Vector3.UP, rng.randf_range(0, TAU)), ORIGIN + Vector3(x, 0, z))
			var h := rng.randf_range(3.0, 5.0)
			k.box("bark", Vector3(0, h / 2.0, 0), Vector3(0.25, h, 0.25), [])
			for j in 3:
				var y := h * (0.5 + 0.15 * j)
				k.xform = k.xform * Transform3D(Basis(Vector3.UP, TAU / 3.0), Vector3.ZERO)
				k.box("bark", Vector3(0.5, y + 0.3, 0), Vector3(1.0, 0.1, 0.1), [])
			add_child(k.build("DeadTree%d" % i))


## Olive bushes by the path, low and grey in the fog. Their own seed, so the
## dead trees keep their places.
func _olives() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 16:
		var z := rng.randf_range(2.0, 70.0)
		var side := -1.0 if i % 2 == 0 else 1.0
		var x := path_x(z) + side * rng.randf_range(2.8, 6.0)
		var s := rng.randf_range(0.45, 0.7)
		place("olive_tree", ORIGIN + Vector3(x, 0, z), rng.randf_range(0, 360), Vector3(s * 1.3, s * 0.8, s * 1.3))


## The figure on the path: a hooded shape in black, who is there until you
## are close. A rigid Figure, not an Npc: nothing to talk to, nothing to hit.
func _figures() -> void:
	for z: float in FIGURES_Z:
		var root := Apparition.new()
		root.name = "Figure%d" % figures.size()
		root.position = ORIGIN + Vector3(path_x(z) + (0.8 if figures.size() % 2 == 0 else -0.8), 0, z)
		root.rotation.y = PI  # faces back down the path, towards the dreamer
		add_child(root)
		Figure.shrouded(root)
		figures.append(root)


func _process(delta: float) -> void:
	if _door_t >= 0.0 and not doors_open:
		_door_t += delta
		var f := door_open_at(_door_t)
		_set_doors(f)
		doors_open = f >= 1.0
	if not Game.dreaming:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	for f in figures:
		if not f.gone and Vector2(f.global_position.x - cam.global_position.x, f.global_position.z - cam.global_position.z).length() < VANISH_DIST:
			f.vanish()  # crumbles away over Apparition.DISSOLVE
			vanished += 1


func _main() -> Node:
	return get_tree().root.get_node_or_null("Main")


func _overlay() -> ColorRect:
	if _fade == null:
		var layer := CanvasLayer.new()
		layer.layer = 4
		_main().add_child(layer)
		_fade = ColorRect.new()
		_fade.color = Color.BLACK
		_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fade.modulate.a = 0.0
		layer.add_child(_fade)
	return _fade


func _fade_to(a: float, seconds: float) -> void:
	var tw := create_tween()
	tw.tween_property(_overlay(), "modulate:a", a, seconds)
	await tw.finished


## Lying down: fade out, carry the player into the dream, fade in.
func enter() -> void:
	if Game.dreaming:
		return
	var main := _main()
	var player: CharacterBody3D = main.player()
	_wake_at = player.global_position
	Game.ui_blocking = true
	await _fade_to(1.0, 1.4)
	Game.dreaming = true
	Game.dream_changed.emit(true)
	for f in figures:
		f.reset()
	_shut_doors()
	vanished = 0
	ended = false
	_mirror_found = Game.found.has(&"bronze_mirror")
	player.global_position = start_point()
	player.velocity = Vector3.ZERO
	player.look_at_point(ORIGIN + Vector3(path_x(12.0), 1.6, 12.0))
	await get_tree().create_timer(0.8).timeout
	Game.ui_blocking = false
	Game.mark_ui_closed()
	await _fade_to(0.0, 2.0)


func the_end() -> void:
	ended = true
	Game.ui_blocking = true
	await _fade_to(1.0, 2.0)
	_end = preload("res://scripts/ui/end_screen.gd").new()
	_end.name = "EndScreen"
	_main().add_child(_end)
	_end.woke.connect(wake)
	_end.play()


## Waking: back on the fleece in the abaton, at night, the lamps still lit.
func wake() -> void:
	var player: CharacterBody3D = _main().player()
	Game.dreaming = false
	Game.dream_changed.emit(false)
	player.global_position = _wake_at + Vector3(0, 0.1, 0)
	player.velocity = Vector3.ZERO
	if _end:
		_end.queue_free()
		_end = null
	await get_tree().create_timer(0.5).timeout
	Game.ui_blocking = false
	Game.mark_ui_closed()
	if not OS.has_feature("web"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await _fade_to(0.0, 2.0)
