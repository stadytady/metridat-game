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
		kit.quad("door", Vector3(dx - 0.5, 0, 0.03), Vector3(dx + 0.5, 0, 0.03), Vector3(dx + 0.5, 1.95, 0.03), Vector3(dx - 0.5, 1.95, 0.03),
				PackedVector2Array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]))
		kit.box("limestone", Vector3(dx, 2.05, 0.06), Vector3(1.4, 0.2, 0.14), ["bottom"])
		kit.box("limestone", Vector3(dx, -0.06, 0.25), Vector3(1.3, 0.12, 0.5), ["bottom"])
	var windows: int = opts.get("windows", 1)
	for i in windows:
		var wx := (-w / 2.0 + 1.0) + i * (w - 2.0) / maxf(1.0, windows - 1.0) if windows > 1 else w / 2.0 - 1.0
		kit.quad("dark", Vector3(wx - 0.25, h - 1.1, 0.02), Vector3(wx + 0.25, h - 1.1, 0.02),
				Vector3(wx + 0.25, h - 0.7, 0.02), Vector3(wx - 0.25, h - 0.7, 0.02))
	kit.xform = Transform3D.IDENTITY


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


## Merchant stall: table on trestles, four posts, sloping cloth canopy.
static func stall(kit: MeshKit, xf: Transform3D) -> void:
	kit.xform = xf
	kit.solid_box("wood", Vector3(0, 0.85, 0), Vector3(2.6, 0.08, 1.0), [])
	for sx: float in [1.0, -1.0]:
		kit.box("wood", Vector3(sx * 1.1, 0.42, 0), Vector3(0.1, 0.84, 0.8), [])
	for p: Vector3 in [Vector3(-1.5, 0, 0.75), Vector3(1.5, 0, 0.75), Vector3(-1.5, 0, -0.95), Vector3(1.5, 0, -0.95)]:
		var h := 2.35 if p.z > 0 else 2.75
		kit.solid_box("wood", p + Vector3(0, h / 2.0, 0), Vector3(0.12, h, 0.12), [])
	var a := Vector3(-1.75, 2.3, 1.05)
	var b := Vector3(1.75, 2.3, 1.05)
	var c := Vector3(1.75, 2.8, -1.15)
	var d := Vector3(-1.75, 2.8, -1.15)
	kit.quad("cloth", a, b, c, d)
	kit.quad("cloth", b, a, d, c)
	# scalloped front edge of the awning
	for i in 7:
		var x := -1.75 + 0.25 + i * 0.5
		kit.quad("cloth", Vector3(x - 0.25, 2.1, 1.05), Vector3(x + 0.25, 2.1, 1.05), Vector3(x + 0.25, 2.3, 1.05), Vector3(x - 0.25, 2.3, 1.05))
		kit.quad("cloth", Vector3(x + 0.25, 2.1, 1.05), Vector3(x - 0.25, 2.1, 1.05), Vector3(x - 0.25, 2.3, 1.05), Vector3(x + 0.25, 2.3, 1.05))
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
