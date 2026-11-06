class_name Arch
extends RefCounted
## Architecture modules, built into a MeshKit. Greek, not Roman: stone socles
## with plastered upper walls, low-pitched terracotta roofs, Doric order,
## no arches or domes.

const FLOOR_STEP := 0.17


## Frame at a point with local +x along `dir` (horizontal) and +y up.
static func frame(origin: Vector3, dir: Vector3) -> Transform3D:
	var x := Vector3(dir.x, 0, dir.z).normalized()
	return Transform3D(Basis(x, Vector3.UP, x.cross(Vector3.UP)), origin)


## Town house. Local frame: origin at the middle of the front wall on the floor,
## +z points out of the front (to the street), the house extends to -z.
## opts: drop (foundation depth below floor), roof ("gable"/"flat"), door (bool),
## door_x, windows (int).
static func house(kit: MeshKit, xf: Transform3D, w: float, d: float, h: float, opts: Dictionary = {}) -> void:
	var drop: float = opts.get("drop", 1.5)
	var socle := 0.75
	kit.xform = xf
	kit.color = Color(1, 1, 1)
	kit.solid_box("limestone", Vector3(0, (socle - drop) / 2.0, -d / 2.0), Vector3(w, socle + drop, d), ["bottom", "top"])
	var roof: String = opts.get("roof", "gable")
	var wall_skip := ["bottom", "top"] if roof == "gable" else ["bottom"]
	kit.solid_box("plaster", Vector3(0, socle + (h - socle) / 2.0, -d / 2.0), Vector3(w, h - socle, d), wall_skip,
			{"top": "earth"})
	if roof == "gable":
		kit.xform = xf * Transform3D(Basis.IDENTITY, Vector3(0, h, -d / 2.0))
		kit.gable_roof("roof", "plaster", w, d, minf(d * 0.22, 1.4), 0.4)
		missing_tiles(kit, w, d, minf(d * 0.22, 1.4), 0.4, opts.get("missing_tiles", 0), opts.get("seed", 0))
		kit.xform = xf
	else:
		for e: Array in [[Vector3(0, h + 0.15, -0.12), Vector3(w, 0.3, 0.24)], [Vector3(0, h + 0.15, -d + 0.12), Vector3(w, 0.3, 0.24)],
				[Vector3(w / 2.0 - 0.12, h + 0.15, -d / 2.0), Vector3(0.24, 0.3, d)], [Vector3(-w / 2.0 + 0.12, h + 0.15, -d / 2.0), Vector3(0.24, 0.3, d)]]:
			kit.box("plaster", e[0], e[1], ["bottom"])
		# a few roof beams poking out of the wall, typical of flat mud roofs
		for bx in range(int(w / 1.2)):
			kit.box("wood", Vector3(-w / 2.0 + 0.6 + bx * 1.2, h - 0.25, 0.12), Vector3(0.14, 0.14, 0.3), ["bottom"])
	if opts.get("door", true):
		var dx: float = opts.get("door_x", 0.0)
		if opts.get("ajar", false):
			# an open door sells a street: the reveal, the dark of the room and
			# a leaf standing in it, instead of a painted rectangle
			_open_door(kit, dx, opts)
		else:
			kit.quad("door", Vector3(dx - 0.5, 0, 0.03), Vector3(dx + 0.5, 0, 0.03), Vector3(dx + 0.5, 1.95, 0.03), Vector3(dx - 0.5, 1.95, 0.03),
					PackedVector2Array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]))
			if opts.get("recess", false):
				_door_jambs(kit, dx, 2.0)
		kit.box("limestone", Vector3(dx, 2.05, 0.06), Vector3(1.4, 0.2, 0.14), ["bottom"])
		kit.box("limestone", Vector3(dx, -0.06, 0.25), Vector3(1.3, 0.12, 0.5), ["bottom"])
		# A house stands on the highest corner of its plot, so on a slope its door
		# can hang a step or two over the street: stone steps take the drop, as
		# they do in every hill town. Visual only - a step you can trip on the
		# pavement is worse than one you walk through.
		var steps: int = opts.get("steps", 0)
		for k in steps:
			kit.box("limestone", Vector3(dx, -0.12 - FLOOR_STEP * (k + 0.5), 0.5 + 0.32 * k),
					Vector3(1.34, FLOOR_STEP, 0.34), ["bottom"])
	var windows: int = opts.get("windows", 1)
	# opts.glow: a separate kit for windows lit at night (some of them, chosen
	# by the house's seed); its node is shown only after dusk
	var glow: MeshKit = opts.get("glow", null)
	for i in windows:
		var wx := (-w / 2.0 + 1.0) + i * (w - 2.0) / maxf(1.0, windows - 1.0) if windows > 1 else w / 2.0 - 1.0
		kit.quad("dark", Vector3(wx - 0.25, h - 1.1, 0.02), Vector3(wx + 0.25, h - 1.1, 0.02),
				Vector3(wx + 0.25, h - 0.7, 0.02), Vector3(wx - 0.25, h - 0.7, 0.02))
		if opts.get("frames", false):
			_window_frame(kit, wx, h - 0.7, opts.get("seed", 0) + i)
		if glow and window_lit(opts.get("seed", 0), i):
			glow.xform = xf
			glow.color = Color(1, 1, 1, lamp_phase(opts.get("seed", 0), i))
			# a touch larger than the opening: lamplight spills onto the plaster
			glow.quad("window_glow", Vector3(wx - 0.3, h - 1.15, 0.04), Vector3(wx + 0.3, h - 1.15, 0.04),
					Vector3(wx + 0.3, h - 0.65, 0.04), Vector3(wx - 0.3, h - 0.65, 0.04))
			glow.xform = Transform3D.IDENTITY
			glow.color = Color.WHITE
	kit.xform = Transform3D.IDENTITY


## A door that reads as a hole and not as a painted rectangle. The house behind
## it is a solid box - cutting a real opening would cost the wall its own faces -
## so the doorway is built on the street side of the plaster: a black panel
## between two stone reveals, and the leaf hung on one jamb, standing open out
## into the lane the way a Greek door did. What sells it is the shadow of the
## reveal and the dark beside the leaf, which is all a PS1 doorway ever had.
static func _open_door(kit: MeshKit, dx: float, opts: Dictionary) -> void:
	var base := kit.xform
	# the dark of the room, a hair proud of the plaster so it stays visible
	kit.quad("void", Vector3(dx - 0.5, 0, 0.045), Vector3(dx + 0.5, 0, 0.045),
			Vector3(dx + 0.5, 1.95, 0.045), Vector3(dx - 0.5, 1.95, 0.045))
	_door_jambs(kit, dx, 1.95)
	# the leaf, hinged at the left jamb and swung out into the street
	kit.xform = base * Transform3D(Basis(Vector3.UP, deg_to_rad(-38.0)), Vector3(dx - 0.48, 0, 0.06))
	kit.box("door", Vector3(0.47, 0.95, 0), Vector3(0.94, 1.9, 0.07), [])
	kit.box("wood", Vector3(0.82, 1.0, 0.05), Vector3(0.06, 0.12, 0.04), [])  # the ring on its face
	kit.xform = base


## The two stone reveals either side of a doorway, proud of the plaster.
static func _door_jambs(kit: MeshKit, dx: float, height: float) -> void:
	for s: float in [-1.0, 1.0]:
		kit.box("limestone", Vector3(dx + s * 0.57, height * 0.5, 0.01),
				Vector3(0.15, height, 0.2), ["bottom"])


## A window with a stone sill and its shutters: one folded back against the wall,
## or both pulled to. Nothing moves - it is the shape that says the house has
## people in it, and the sill is what stops the wall reading as a blanket.
static func _window_frame(kit: MeshKit, wx: float, top: float, seed: int) -> void:
	kit.box("limestone", Vector3(wx, top + 0.03, 0.06), Vector3(0.78, 0.1, 0.2), ["bottom"])
	var shut := hash(seed * 17 + 5)
	var both_closed := posmod(shut, 3) == 0
	for s: float in [-1.0, 1.0]:
		if both_closed or s < 0.0:
			# hanging over the opening
			kit.box("door", Vector3(wx + s * 0.19, top - 0.22, 0.045), Vector3(0.36, 0.42, 0.04), [])
		else:
			# folded back flat on the plaster beside it
			kit.box("door", Vector3(wx + 0.44, top - 0.22, 0.035), Vector3(0.34, 0.42, 0.03), [])



## Whether a house's window shows a lamp at night: one in two, by its seed.
static func window_lit(seed: int, i: int) -> bool:
	return posmod(hash(seed * 31 + i), 2) == 0


## A house you can walk into. Same shell as house() from the street, but the walls
## are boxes with a doorway left in the front one, the room has its own level floor
## and a ceiling, and the roof is the same gable. Returns where the wall lantern
## goes, in the house's own frame.
const COTTAGE_DOOR := 1.15
const COTTAGE_DOOR_H := 2.05
const COTTAGE_WALL := 0.32
## The room floor stands this much above the plinth: two faces at the same height
## flicker against each other, and the earth showed through in patches.
const FLOOR_LIFT := 0.06

## The two pieces of the front wall either side of the doorway, as [from, to] in x.
static func cottage_front_segments(w: float) -> Array[Vector2]:
	var half := COTTAGE_DOOR * 0.5
	var out: Array[Vector2] = []
	if w * 0.5 - half > 0.05:
		out.append(Vector2(-w * 0.5, -half))
		out.append(Vector2(half, w * 0.5))
	return out


static func cottage(kit: MeshKit, xf: Transform3D, w: float, d: float, h: float,
		opts: Dictionary = {}) -> Dictionary:
	var drop: float = opts.get("drop", 1.5)
	var socle := 0.75
	var t := COTTAGE_WALL
	var wall_h := h - socle
	var mid := socle + wall_h * 0.5
	kit.xform = xf
	kit.color = Color.WHITE
	# plinth, then a level floor for the room to stand on
	kit.solid_box("limestone", Vector3(0, (socle - drop) / 2.0, -d / 2.0), Vector3(w, socle + drop, d), ["bottom"])
	# the floor keeps its top face — skipping it leaves a hole to the sea — and it
	# sits a hair above the plinth so the two surfaces cannot z-fight
	kit.solid_box("plaster", Vector3(0, socle - 0.1 + FLOOR_LIFT, -d / 2.0),
			Vector3(w - 2.0 * t + 0.08, 0.2, d - 2.0 * t + 0.08), ["bottom"], {"top": "earth"})
	# front wall with the doorway, and the lintel over it
	for seg: Vector2 in cottage_front_segments(w):
		kit.solid_box("plaster", Vector3((seg.x + seg.y) * 0.5, mid, -t * 0.5),
				Vector3(seg.y - seg.x, wall_h, t), ["bottom", "top"])
	var over := wall_h - COTTAGE_DOOR_H  # the strip of wall above the door
	if over > 0.1:
		kit.solid_box("plaster", Vector3(0, socle + COTTAGE_DOOR_H + over * 0.5, -t * 0.5),
				Vector3(COTTAGE_DOOR, over, t), ["bottom", "top"])
	# back and side walls, and a ceiling so the room reads as a room
	kit.solid_box("plaster", Vector3(0, mid, -d + t * 0.5), Vector3(w, wall_h, t), ["bottom", "top"])
	for sx: float in [-1.0, 1.0]:
		kit.solid_box("plaster", Vector3(sx * (w * 0.5 - t * 0.5), mid, -d * 0.5),
				Vector3(t, wall_h, d - 2.0 * t), ["bottom", "top"])
	kit.box("wood", Vector3(0, h - 0.14, -d * 0.5), Vector3(w - t, 0.16, d - t), ["bottom"], {})
	# the roof, the same gable the street uses
	kit.xform = xf * Transform3D(Basis.IDENTITY, Vector3(0, h, -d / 2.0))
	kit.gable_roof("roof", "plaster", w, d, minf(d * 0.22, 1.4), 0.4)
	kit.xform = xf
	# steps from the sill down to the lane: the front of a house sits on the
	# highest corner of its plot, so the ground at the door may be lower
	# heights here are local to the house: a world height would lift the treads into
	# the sky by the height of the plot
	var treads: Array[float] = []
	for i in 4:
		var local := Vector3(0, 0, 0.5 + i * 0.42)
		var world := xf * local
		var ground := Topo.terrain(world.x, world.z) - xf.origin.y
		var high := socle + FLOOR_LIFT - (i + 1) * 0.26
		if high <= ground + 0.03:
			break
		kit.solid_box("limestone", Vector3(0, high - 0.13, 0.5 + i * 0.42), Vector3(COTTAGE_DOOR + 0.45, 0.26, 0.48), ["bottom", "top"])
		treads.append(high)
	# a stone threshold so the step onto the floor reads as intended
	kit.solid_box("limestone", Vector3(0, socle + FLOOR_LIFT - 0.03, -t * 0.5), Vector3(COTTAGE_DOOR, 0.12, t + 0.18), ["bottom", "top"])
	# the door: a leaf standing open against the inside wall
	kit.box("door", Vector3(-COTTAGE_DOOR * 0.5 + 0.06, socle + COTTAGE_DOOR_H * 0.5, -COTTAGE_DOOR),
			Vector3(0.08, COTTAGE_DOOR_H, COTTAGE_DOOR), ["bottom"], {})
	kit.box("limestone", Vector3(0, socle + COTTAGE_DOOR_H + 0.08, 0.06), Vector3(COTTAGE_DOOR + 0.3, 0.16, 0.16), ["bottom"], {})
	# inside: a bench, a shelf and a niche for the household lamp
	kit.box("wood", Vector3(w * 0.5 - t - 0.5, socle + 0.22, -d * 0.5), Vector3(0.9, 0.1, 2.0), ["bottom"], {})
	kit.box("wood", Vector3(-w * 0.5 + t + 0.3, socle + 0.9, -d * 0.35), Vector3(0.35, 0.08, 0.9), ["bottom"], {})
	kit.box("clay", Vector3(-w * 0.5 + t + 0.3, socle + 1.0, -d * 0.35), Vector3(0.18, 0.12, 0.18), ["bottom"], {})
	kit.xform = Transform3D.IDENTITY
	# the bracket hangs on the front wall beside the doorway, not past the corner
	# where a householder stands, on the floor and inside the walls
	var floor_y := socle + FLOOR_LIFT
	var inside := Rect2(-w * 0.5 + t, -d + t, w - 2.0 * t, d - 2.0 * t)
	return {
		"lamp": Vector3(COTTAGE_DOOR * 0.5 + 0.75, socle + 1.95, 0.02),
		"door": Vector3(0, socle, 0.0),
		"floor": floor_y,
		"woman": Vector3(inside.position.x + inside.size.x * 0.35, floor_y, inside.position.y + inside.size.y * 0.45),
		"inside": inside,
		"steps": treads,
	}


## Where a window's lamp is in its flicker (psx_lamp reads it from the vertex
## alpha), so the lamps of a street never pulse in step.
static func lamp_phase(seed: int, i: int) -> float:
	return posmod(hash(seed * 131 + i * 17), 1024) / 1024.0


## Walled courtyard with a gate on the front (local frame as house()).
static func courtyard(kit: MeshKit, xf: Transform3D, w: float, d: float, wall_h: float, drop: float) -> void:
	kit.xform = xf
	var t := 0.45
	var gate := 1.6
	var side := (w - gate) / 2.0
	var y := (wall_h - drop) / 2.0
	var hh := wall_h + drop
	kit.solid_box("limestone", Vector3(-w / 2.0 + side / 2.0, y, -t / 2.0), Vector3(side, hh, t))
	kit.solid_box("limestone", Vector3(w / 2.0 - side / 2.0, y, -t / 2.0), Vector3(side, hh, t))
	kit.solid_box("limestone", Vector3(-w / 2.0 + t / 2.0, y, -d / 2.0), Vector3(t, hh, d - 2 * t))
	kit.solid_box("limestone", Vector3(w / 2.0 - t / 2.0, y, -d / 2.0), Vector3(t, hh, d - 2 * t))
	kit.solid_box("limestone", Vector3(0, y, -d + t / 2.0), Vector3(w, hh, t))
	kit.box("wood", Vector3(0, 2.3, -t / 2.0), Vector3(gate + 0.4, 0.18, t + 0.1), [])
	# beaten-earth floor
	kit.solid_box("earth", Vector3(0, -0.15, -d / 2.0), Vector3(w - 2 * t, 0.3, d - 2 * t), ["bottom"])
	kit.xform = Transform3D.IDENTITY


## Paved path with stairs where steep. Visual treads, but a smooth ramp
## collider: CharacterBody3D does not climb steps by itself.
## The collider is wider than the paving by `margin` on each side: the terrain
## next to a path is sunk a little below it (see Topo.terrain), and without the
## margin that lip becomes a curb the player cannot get back over.
static func path(kit: MeshKit, pts: Array[Vector3], half: float, mat: String = "paving", skirt: float = 0.7,
		margin: float = 1.5) -> void:
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var flat := Vector3(b.x - a.x, 0, b.z - a.z)
		var seg_len := flat.length()
		var dir := flat / seg_len
		var side := Vector3(-dir.z, 0, dir.x)
		var dh := b.y - a.y
		if absf(dh) / seg_len > Topo.STAIR_SLOPE:
			var n := ceili(absf(dh) / FLOOR_STEP)
			kit.xform = frame(a, dir)
			var bottom := minf(a.y, b.y) - a.y - skirt
			for k in n:
				var top := dh * (k + 0.5) / n
				var c := Vector3(seg_len * (k + 0.5) / n, (top + bottom) / 2.0, 0)
				kit.box("limestone", c, Vector3(seg_len / n + 0.02, top - bottom, half * 2.0), ["bottom"], {"top": mat})
			kit.xform = Transform3D.IDENTITY
		else:
			var l := Vector3(0, -skirt, 0)
			kit.quad(mat, a + side * half, b + side * half, b - side * half, a - side * half)
			kit.quad("limestone", a + side * half + l, b + side * half + l, b + side * half, a + side * half)
			kit.quad("limestone", b - side * half + l, a - side * half + l, a - side * half, b - side * half)
		# ramp collider whose top surface runs through a..b
		var x := (b - a).normalized()
		var y := side.cross(x)
		kit.xform = Transform3D(Basis(x, y, side), (a + b) / 2.0)
		kit.add_collider(Vector3(0, -0.2, 0), Vector3(a.distance_to(b) + 0.4, 0.4, (half + margin) * 2.0))
		kit.xform = Transform3D.IDENTITY
		if i > 0:
			kit.xform = frame(a, dir)
			kit.box(mat, Vector3(0, -skirt / 2.0, 0), Vector3(half * 2.0, skirt, half * 2.0), ["bottom"],
					{"px": "limestone", "nx": "limestone", "pz": "limestone", "nz": "limestone"})
			# Only plugs the seam between two ramps: short along the path, or its
			# flat top stands proud of a shallower ramp and blocks walking uphill.
			kit.add_collider(Vector3(0, -0.2, 0), Vector3(0.6, 0.4, (half + margin) * 2.0))
			kit.xform = Transform3D.IDENTITY


## Paved platform with stone retaining walls down to `bottom`.
static func platform(kit: MeshKit, center: Vector2, half: Vector2, top: float, bottom: float, mat: String = "paving") -> void:
	var walls := {"px": "limestone", "nx": "limestone", "pz": "limestone", "nz": "limestone"}
	kit.solid_box(mat, Vector3(center.x, (top + bottom) / 2.0, center.y), Vector3(half.x * 2, top - bottom, half.y * 2), ["bottom"], walls)


## Stoa: a portico with a row of Doric columns in front, solid back wall,
## entablature and a single-pitch roof. Local frame: +z is the open front,
## origin at the stylobate's front-center. Returns column positions (local).
static func stoa(kit: MeshKit, xf: Transform3D, length: float, depth: float, columns: int, col_h: float) -> Array[Vector3]:
	kit.xform = xf
	var step_h := 0.32
	kit.solid_box("limestone", Vector3(0, step_h / 2.0 - 0.4, -depth / 2.0), Vector3(length + 0.6, step_h + 0.8, depth + 0.6), ["bottom"])
	var floor_y := step_h
	var top := floor_y + col_h
	kit.solid_box("limestone", Vector3(0, (floor_y + top + 1.0) / 2.0, -depth + 0.3), Vector3(length, top + 1.0 - floor_y, 0.6), ["bottom"],
			{"pz": "plaster"})
	for sx: float in [1.0, -1.0]:
		kit.solid_box("limestone", Vector3(sx * (length / 2.0 - 0.3), (floor_y + top) / 2.0, -depth / 2.0 - 0.6),
				Vector3(0.6, col_h, depth - 1.2), ["bottom"], {"px": "plaster", "nx": "plaster"})
	# architrave + frieze band
	kit.box("limestone", Vector3(0, top + 0.25, -0.1), Vector3(length + 0.2, 0.5, 0.9), [])
	kit.box("plaster", Vector3(0, top + 0.72, -0.1), Vector3(length + 0.2, 0.44, 0.85), ["bottom"])
	# triglyphs: dark vertical slots on the frieze
	var n := columns * 2 - 1
	for i in n:
		var x := -length / 2.0 + 0.6 + i * (length - 1.2) / (n - 1)
		kit.quad("dark", Vector3(x - 0.12, top + 0.55, 0.335), Vector3(x + 0.12, top + 0.55, 0.335),
				Vector3(x + 0.12, top + 0.9, 0.335), Vector3(x - 0.12, top + 0.9, 0.335))
	# lean-to roof sloping down to the front
	var r0 := Vector3(0, top + 0.95, 0.6)
	var r1 := Vector3(0, top + 2.0, -depth)
	var hl := length / 2.0 + 0.4
	var a := Vector3(-hl, r0.y, r0.z)
	var b := Vector3(hl, r0.y, r0.z)
	var c := Vector3(hl, r1.y, r1.z)
	var d := Vector3(-hl, r1.y, r1.z)
	kit.quad("roof", a, b, c, d)
	kit.quad("wood", b, a, d, c)
	kit.tri("plaster", Vector3(hl, top + 0.95, 0.6), Vector3(hl, top + 0.95, -depth), Vector3(hl, top + 2.0, -depth),
			Vector2(0.6, 0), Vector2(-depth, 0), Vector2(-depth, -1.05))
	kit.tri("plaster", Vector3(-hl, top + 0.95, -depth), Vector3(-hl, top + 0.95, 0.6), Vector3(-hl, top + 2.0, -depth),
			Vector2(-depth, 0), Vector2(0.6, 0), Vector2(-depth, -1.05))
	kit.xform = Transform3D.IDENTITY
	var cols: Array[Vector3] = []
	for i in columns:
		cols.append(Vector3(-length / 2.0 + 0.7 + i * (length - 1.4) / (columns - 1), floor_y, -0.1))
	return cols


## Small temple "in antis": cella walls with two columns between the antae,
## pediment roof. Local +z is the front. Returns the two column positions.
static func naiskos(kit: MeshKit, xf: Transform3D, w: float, d: float, col_h: float) -> Array[Vector3]:
	kit.xform = xf
	var base := 0.5
	kit.solid_box("limestone", Vector3(0, base / 2.0 - 0.3, -d / 2.0), Vector3(w + 0.8, base + 0.6, d + 0.8), ["bottom"])
	# crepidoma: two more steps around the top one, three in all
	for i in 2:
		var grow := 0.8 + 0.6 * (i + 1)
		var h := base - 0.17 * (i + 1)
		kit.solid_box("limestone", Vector3(0, h / 2.0 - 0.3, -d / 2.0), Vector3(w + grow, h + 0.6, d + grow), ["bottom"])
	var top := base + col_h
	var t := 0.45
	var porch := 1.6
	for sx: float in [1.0, -1.0]:
		kit.solid_box("limestone", Vector3(sx * (w / 2.0 - t / 2.0), (base + top) / 2.0, -d / 2.0), Vector3(t, col_h, d), ["bottom"],
				{"px": "plaster", "nx": "plaster"} if sx > 0 else {"px": "plaster", "nx": "plaster"})
	kit.solid_box("limestone", Vector3(0, (base + top) / 2.0, -d + t / 2.0), Vector3(w, col_h, t), ["bottom"])
	# front wall of the cella with a dark doorway
	var fz := -porch
	var side := (w - 1.4) / 2.0 - t
	for sx: float in [1.0, -1.0]:
		kit.solid_box("plaster", Vector3(sx * (0.7 + side / 2.0), (base + top) / 2.0, fz), Vector3(side, col_h, t), ["bottom"])
	kit.box("plaster", Vector3(0, top - 0.5, fz), Vector3(1.4, 1.0, t), ["bottom"])
	# the doors stand open, folded back against the cella's front wall inside
	for sx: float in [1.0, -1.0]:
		kit.box("door", Vector3(sx * 0.95, (base + top - 1.0) / 2.0, fz - t / 2.0 - 0.05), Vector3(0.5, top - 1.0 - base, 0.06), [])
	kit.box("limestone", Vector3(0, top + 0.22, -d / 2.0), Vector3(w + 0.2, 0.44, d + 0.2), ["bottom"])
	# painted frieze band across the front
	kit.box("redfigure", Vector3(0, top + 0.22, 0.111), Vector3(w + 0.1, 0.3, 0.02), ["bottom", "top"])
	kit.xform = xf * Transform3D(Basis(Vector3(0, 0, 1), Vector3.UP, Vector3(-1, 0, 0)), Vector3(0, top + 0.44, -d / 2.0))
	kit.gable_roof("roof", "plaster", d + 0.2, w + 0.2, 1.0, 0.35, "wood", true)
	# acroteria: a palmette at the apex and at the corners of the front gable
	kit.xform = xf
	var ridge := top + 0.44 + 1.0
	kit.box("clay", Vector3(0, ridge + 0.22, 0.12), Vector3(0.18, 0.45, 0.08), [])
	kit.box("clay", Vector3(0, ridge + 0.38, 0.12), Vector3(0.36, 0.14, 0.08), [])
	for sx: float in [1.0, -1.0]:
		kit.box("clay", Vector3(sx * (w / 2.0 + 0.2), top + 0.6, 0.12), Vector3(0.14, 0.32, 0.08), [])
	kit.xform = Transform3D.IDENTITY
	return [Vector3(-0.75, base, -0.1), Vector3(0.75, base, -0.1)] as Array[Vector3]


## Gaps in the street-facing slope of a gable roof where tiles have slipped:
## the battens show through. Same frame as gable_roof (ridge at y = h, z = 0,
## the slope runs down to the eave at +z). Patches lie a hair above the tiles.
static func missing_tiles(kit: MeshKit, w: float, d: float, h: float, overhang: float, count: int, seed: int) -> void:
	if count <= 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var hw := w / 2.0 + overhang
	var od := d / 2.0 + overhang
	var drop := -h * overhang / (d / 2.0)
	var on_slope := func(u: float, v: float) -> Vector3:
		# u across the roof (-1..1), v from the eave (0) to the ridge (1)
		var p := Vector3(u * hw, lerpf(drop, h, v), lerpf(od, 0.0, v))
		return p + Vector3(0, 0.03, 0.01)
	for i in count:
		var u := rng.randf_range(-0.7, 0.6)
		var v := rng.randf_range(0.2, 0.7)
		var du := rng.randf_range(0.35, 0.6) / hw
		var dv := rng.randf_range(0.18, 0.3)
		# the dark gap under the tiles, crossed by two pale battens
		kit.quad("dark", on_slope.call(u, v), on_slope.call(u + du, v), on_slope.call(u + du, v + dv), on_slope.call(u, v + dv))
		for b: float in [0.3, 0.7]:
			var vb := v + dv * b
			var lift := Vector3(0, 0.01, 0)
			kit.quad("wood", on_slope.call(u, vb) + lift, on_slope.call(u + du, vb) + lift,
					on_slope.call(u + du, vb + 0.035) + lift, on_slope.call(u, vb + 0.035) + lift)


## Stepped altar, fire on top. Local origin at ground center.
static func altar(kit: MeshKit, xf: Transform3D) -> void:
	kit.xform = xf
	kit.solid_box("limestone", Vector3(0, 0.1, 0), Vector3(2.6, 0.2, 1.8), ["bottom"])
	kit.solid_box("limestone", Vector3(0, 0.55, 0), Vector3(2.0, 0.7, 1.2), ["bottom"], {"pz": "plaster", "nz": "plaster"})
	kit.box("limestone", Vector3(0, 0.98, 0), Vector3(2.2, 0.16, 1.35), ["bottom"])
	for sx: float in [1.0, -1.0]:
		kit.box("limestone", Vector3(sx * 0.95, 1.12, 0), Vector3(0.3, 0.14, 1.35), ["bottom"])
	kit.box("dark", Vector3(0, 1.08, 0), Vector3(1.2, 0.03, 0.8), ["bottom"])
	kit.xform = Transform3D.IDENTITY


## Merchant stall: table on trestles, four posts, sloping cloth canopy. With a
## `stripes` palette the canopy is built stripe by stripe, the way dyed cloth
## reads on the vases; an empty palette keeps the plain cloth.
static func stall(kit: MeshKit, xf: Transform3D, stripes: Array = []) -> void:
	kit.xform = xf
	kit.solid_box("wood", Vector3(0, 0.85, 0), Vector3(2.6, 0.08, 1.0), [])
	for sx: float in [1.0, -1.0]:
		kit.box("wood", Vector3(sx * 1.1, 0.42, 0), Vector3(0.1, 0.84, 0.8), [])
	for p: Vector3 in [Vector3(-1.5, 0, 0.75), Vector3(1.5, 0, 0.75), Vector3(-1.5, 0, -0.95), Vector3(1.5, 0, -0.95)]:
		var h := 2.35 if p.z > 0 else 2.75
		kit.solid_box("wood", p + Vector3(0, h / 2.0, 0), Vector3(0.12, h, 0.12), [])
	var palette: Array = stripes if not stripes.is_empty() else ["cloth"]
	var n := 7
	for i in n:
		var mat: String = palette[i % palette.size()]
		var x0 := -1.75 + 3.5 * i / n
		var x1 := -1.75 + 3.5 * (i + 1) / n
		var a := Vector3(x0, 2.3, 1.05)
		var b := Vector3(x1, 2.3, 1.05)
		var c := Vector3(x1, 2.8, -1.15)
		var d := Vector3(x0, 2.8, -1.15)
		kit.quad(mat, a, b, c, d)
		kit.quad(mat, b, a, d, c)
	# scalloped front edge of the awning, in the same colours
	for i in n:
		var mat: String = palette[i % palette.size()]
		var x := -1.75 + 0.25 + i * 0.5
		kit.quad(mat, Vector3(x - 0.25, 2.1, 1.05), Vector3(x + 0.25, 2.1, 1.05), Vector3(x + 0.25, 2.3, 1.05), Vector3(x - 0.25, 2.3, 1.05))
		kit.quad(mat, Vector3(x + 0.25, 2.1, 1.05), Vector3(x - 0.25, 2.1, 1.05), Vector3(x - 0.25, 2.3, 1.05), Vector3(x + 0.25, 2.3, 1.05))
	kit.xform = Transform3D.IDENTITY


static func bench(kit: MeshKit, xf: Transform3D, length: float) -> void:
	kit.xform = xf
	kit.solid_box("limestone", Vector3(0, 0.42, 0), Vector3(length, 0.14, 0.5), ["bottom"])
	for sx: float in [1.0, -1.0]:
		kit.box("limestone", Vector3(sx * (length / 2.0 - 0.3), 0.18, 0), Vector3(0.3, 0.36, 0.42), ["bottom"])
	kit.xform = Transform3D.IDENTITY


## Fallen column drum lying on its side.
static func drum(kit: MeshKit, xf: Transform3D, r: float, length: float) -> void:
	kit.xform = xf * Transform3D(Basis(Vector3(0, 1, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1)), Vector3(length / 2.0, r * 0.92, 0))
	kit.lathe("column", PackedVector2Array([Vector2(r, 0), Vector2(r, length)]), 8, Vector3.ZERO, 1.0, false, "limestone", true)
	kit.xform = xf
	kit.add_collider(Vector3(0, r * 0.9, 0), Vector3(length, r * 1.8, r * 1.8))
	kit.xform = Transform3D.IDENTITY


## Standing stele with an inscription face on +z.
static func stele(kit: MeshKit, xf: Transform3D) -> void:
	kit.xform = xf
	kit.solid_box("limestone", Vector3(0, 0.15, 0), Vector3(1.0, 0.3, 0.6), ["bottom"])
	kit.box("limestone", Vector3(0, 1.05, 0), Vector3(0.8, 1.5, 0.22), ["bottom", "pz"])
	# Inscribed band at the top: the texture is 2:1, so the band is 0.8 x 0.4 m.
	kit.quad("limestone", Vector3(-0.4, 0.3, 0.11), Vector3(0.4, 0.3, 0.11), Vector3(0.4, 1.36, 0.11), Vector3(-0.4, 1.36, 0.11))
	kit.quad("inscription", Vector3(-0.4, 1.36, 0.11), Vector3(0.4, 1.36, 0.11), Vector3(0.4, 1.76, 0.11), Vector3(-0.4, 1.76, 0.11),
			PackedVector2Array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]))
	# small pediment crown
	kit.box("limestone", Vector3(0, 1.86, 0), Vector3(0.9, 0.12, 0.28), ["bottom"])
	kit.tri("limestone", Vector3(-0.45, 1.92, 0.14), Vector3(0.45, 1.92, 0.14), Vector3(0, 2.15, 0.14),
			Vector2(0, 0), Vector2(1, 0), Vector2(0.5, -0.3))
	kit.xform = xf
	kit.add_collider(Vector3(0, 1.0, 0), Vector3(0.8, 2.0, 0.3))
	kit.xform = Transform3D.IDENTITY


## A mantle figure on its plinth, facing +z. Greek cities stood these around their
## squares and temples: most honorific statues were bronze, the marble ones were
## the costly exception (the Panticapaeum goddess was marble, more than 2.5 m).
## opts: h (figure height, m), mat ("bronze"/"column"), helmet (Corinthian, bool),
## plinth (base height, m), arm ("down"/"up"/"spear").
## Returns the total height of plinth and figure, for tests and layout.
##
## Proportions are the whole job here: a head narrower than a tenth of the height
## and a straight column of a body read as a post, not as a person, at any
## distance the player sees them.
static func statue(kit: MeshKit, xf: Transform3D, opts: Dictionary = {}) -> float:
	var h: float = opts.get("h", 1.7)
	var mat: String = opts.get("mat", "bronze")
	var plinth: float = opts.get("plinth", 0.38)
	var y := plinth
	kit.xform = xf
	# plinth: a foot block under a cap, cut in two mouldings, wider than the skirt
	kit.solid_box("limestone", Vector3(0, plinth * 0.22, 0), Vector3(h * 0.46, plinth * 0.44, h * 0.46), ["bottom"])
	kit.solid_box("limestone", Vector3(0, plinth * 0.72, 0), Vector3(h * 0.38, plinth * 0.56, h * 0.38), ["bottom"])
	# the fall of the mantle: a flared skirt from the feet to the waist
	kit.lathe(mat, PackedVector2Array([
		Vector2(h * 0.20, y), Vector2(h * 0.195, y + h * 0.04),
		Vector2(h * 0.155, y + h * 0.34), Vector2(h * 0.125, y + h * 0.62)]),
		10, Vector3.ZERO, 1.0, true, mat)
	# chest, then shoulders wider than the waist: the first thing the eye reads
	kit.box(mat, Vector3(0, y + h * 0.71, 0), Vector3(h * 0.26, h * 0.19, h * 0.19), ["bottom"])
	kit.box(mat, Vector3(0, y + h * 0.815, 0), Vector3(h * 0.34, h * 0.07, h * 0.21), ["bottom"])
	# arms: one hangs, the other answers the option
	var arm := String(opts.get("arm", "down"))
	for sx: float in [-1.0, 1.0]:
		if sx > 0.0 and arm == "up":
			kit.box(mat, Vector3(h * 0.16, y + h * 0.88, 0), Vector3(h * 0.10, h * 0.30, h * 0.13), ["bottom"])
		elif sx > 0.0 and arm == "spear":
			kit.box(mat, Vector3(h * 0.16, y + h * 0.71, h * 0.03), Vector3(h * 0.10, h * 0.34, h * 0.12), ["bottom"])
		else:
			kit.box(mat, Vector3(h * 0.16 * sx, y + h * 0.68, 0), Vector3(h * 0.10, h * 0.36, h * 0.13), ["bottom"])
	# neck, head, hair: the head is a seventh of the figure, not a tenth
	kit.box(mat, Vector3(0, y + h * 0.865, 0), Vector3(h * 0.07, h * 0.04, h * 0.07), ["bottom"])
	kit.box(mat, Vector3(0, y + h * 0.935, h * 0.005), Vector3(h * 0.125, h * 0.13, h * 0.13), ["bottom"])
	kit.box(mat, Vector3(0, y + h * 0.995, -h * 0.01), Vector3(h * 0.145, h * 0.06, h * 0.145), ["bottom"])
	if bool(opts.get("helmet", false)):
		# Corinthian helmet: dome over the brow, cheek pieces, crest front to back
		kit.box(mat, Vector3(0, y + h * 1.03, 0), Vector3(h * 0.15, h * 0.05, h * 0.16), ["bottom"])
		for sx: float in [-1.0, 1.0]:
			kit.box(mat, Vector3(h * 0.06 * sx, y + h * 0.965, h * 0.02), Vector3(h * 0.03, h * 0.10, h * 0.10), ["bottom"])
		kit.box(mat, Vector3(0, y + h * 1.075, -h * 0.01), Vector3(h * 0.03, h * 0.05, h * 0.20), ["bottom"])
	if arm == "spear":
		kit.box("wood", Vector3(h * 0.21, y + h * 0.72, h * 0.03), Vector3(0.03, h * 1.0, 0.03), [])
	kit.xform = xf
	kit.add_collider(Vector3(0, (plinth + h) * 0.5, 0), Vector3(h * 0.42, plinth + h, h * 0.34))
	kit.xform = Transform3D.IDENTITY
	return plinth + h * 1.10


## Herm: a square pillar with a bearded head and stubs of shoulders, the oldest
## piece of Greek garden furniture there is. Faces +z, returns its height.
static func herm(kit: MeshKit, xf: Transform3D, h: float = 1.5) -> float:
	var w := h * 0.22
	kit.xform = xf
	kit.solid_box("limestone", Vector3(0, h * 0.05, 0), Vector3(w * 1.8, h * 0.1, w * 1.8), ["bottom"])
	kit.solid_box("column", Vector3(0, h * 0.5, 0), Vector3(w, h * 0.8, w), ["bottom"])
	kit.box("column", Vector3(0, h * 0.92, 0), Vector3(w * 1.5, h * 0.05, w * 1.1), ["bottom"])   # shoulders
	kit.box("column", Vector3(0, h * 1.03, 0), Vector3(w * 0.85, h * 0.16, w * 0.85), ["bottom"])  # head
	kit.box("column", Vector3(0, h * 0.96, w * 0.3), Vector3(w * 0.9, h * 0.12, w * 0.4), ["bottom"])  # beard
	kit.xform = xf
	kit.add_collider(Vector3(0, h * 0.5, 0), Vector3(w * 1.4, h, w * 1.4))
	kit.xform = Transform3D.IDENTITY
	return h * 1.11
