class_name Props
extends RefCounted
## Low-poly prop geometry. Baked to assets/models/*.glb by tools/bake_models.gd;
## the game loads the GLBs (see instance()). Units are meters, origin at the base.

## Baked to GLB. EXTRA kinds are small one-off models built at runtime.
const MODELS := ["amphora", "pithos", "krater", "column_doric", "olive_tree", "cypress", "ship", "tripod", "figurine"]
const EXTRA := ["coins", "sherds", "stele", "grain", "votive", "lampstand", "torch_post"]


static func build(name: String) -> MeshKit:
	var kit := MeshKit.new()
	match name:
		"amphora":
			amphora(kit)
		"pithos":
			kit.lathe("clay", PackedVector2Array([
				Vector2(0.18, 0), Vector2(0.38, 0.2), Vector2(0.5, 0.6), Vector2(0.46, 1.0),
				Vector2(0.3, 1.2), Vector2(0.33, 1.3)]), 8, Vector3.ZERO, 2.0, true, "dark", true)
		"krater":
			kit.lathe("redfigure", PackedVector2Array([
				Vector2(0.11, 0), Vector2(0.13, 0.05), Vector2(0.08, 0.1), Vector2(0.17, 0.2),
				Vector2(0.23, 0.42), Vector2(0.26, 0.5)]), 8, Vector3.ZERO, 2.0, true, "dark", true)
		"column_doric":
			column_doric(kit, 3.6)
		"olive_tree":
			olive_tree(kit, 3)
		"cypress":
			cypress(kit)
		"ship":
			ship(kit)
		"tripod":
			tripod(kit)
		"figurine":
			figurine(kit)
		"coins":
			coins(kit)
		"sherds":
			sherds(kit)
		"stele":
			Arch.stele(kit, Transform3D.IDENTITY)
		"grain":
			grain(kit)
		"lampstand":
			lampstand(kit)
		"torch_post":
			torch_post(kit)
		"votive":
			kit.xform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 1.3), Vector3.ZERO)
			figurine(kit)
			kit.xform = Transform3D.IDENTITY
			kit.lathe("bronze", PackedVector2Array([Vector2(0.02, 0.0), Vector2(0.09, 0.02), Vector2(0.1, 0.035)]), 8,
					Vector3(0.18, 0, 0.05), 1.0, true, "bronze", true)
		_:
			push_error("unknown prop " + name)
	return kit


## Transport amphora (~0.8 m): pointed toe, ovoid body, narrow neck, two handles.
static func amphora(kit: MeshKit) -> void:
	kit.lathe("clay", PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(0.035, 0.03), Vector2(0.07, 0.1), Vector2(0.15, 0.3),
		Vector2(0.17, 0.46), Vector2(0.14, 0.58), Vector2(0.07, 0.64), Vector2(0.055, 0.74),
		Vector2(0.07, 0.78)]), 8, Vector3.ZERO, 2.0, true, "dark", true)
	for s: float in [1.0, -1.0]:
		kit.box("clay", Vector3(0.1 * s, 0.73, 0), Vector3(0.05, 0.03, 0.035), [])
		kit.box("clay", Vector3(0.12 * s, 0.67, 0), Vector3(0.03, 0.12, 0.035), [])


## Doric column: entasis shaft (8 flutes in the texture), echinus, abacus.
static func column_doric(kit: MeshKit, h: float) -> void:
	var shaft := h - 0.36
	kit.lathe("column", PackedVector2Array([
		Vector2(0.3, 0.0), Vector2(0.3, shaft * 0.35), Vector2(0.27, shaft * 0.8), Vector2(0.25, shaft)]),
		8, Vector3.ZERO, 1.0, false)
	kit.lathe("limestone", PackedVector2Array([
		Vector2(0.25, shaft), Vector2(0.24, shaft + 0.06), Vector2(0.36, shaft + 0.2)]), 8)
	kit.box("limestone", Vector3(0, h - 0.08, 0), Vector3(0.8, 0.16, 0.8), [])


static func olive_tree(kit: MeshKit, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	# Gnarled trunk: stacked, offset frustums.
	var pts := [Vector3.ZERO, Vector3(0.15, 0.7, 0.05), Vector3(-0.05, 1.3, 0.12), Vector3(0.1, 1.8, -0.05)]
	var radii := [0.2, 0.15, 0.12, 0.09]
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		kit.xform = align_y(a, b)
		kit.lathe("bark", PackedVector2Array([Vector2(radii[i], 0), Vector2(radii[i + 1], a.distance_to(b))]), 5,
				Vector3.ZERO, 1.0, false)
	kit.xform = Transform3D.IDENTITY
	for c: Array in [[Vector3(0.1, 2.3, 0), Vector3(1.3, 0.75, 1.2)], [Vector3(-0.6, 2.0, 0.4), Vector3(0.8, 0.55, 0.8)],
			[Vector3(0.7, 2.1, -0.5), Vector3(0.85, 0.6, 0.8)], [Vector3(0.0, 2.75, -0.2), Vector3(0.8, 0.5, 0.7)]]:
		kit.blob("foliage", c[0], c[1], 0.22, rng)


static func cypress(kit: MeshKit) -> void:
	kit.lathe("bark", PackedVector2Array([Vector2(0.12, 0), Vector2(0.1, 0.5)]), 5)
	kit.lathe("cypress", PackedVector2Array([
		Vector2(0.25, 0.3), Vector2(0.55, 1.4), Vector2(0.5, 3.2), Vector2(0.32, 4.8), Vector2(0.0, 6.2)]), 6,
		Vector3.ZERO, 2.0, false)


## Merchant ship silhouette (~16 m): lofted hull, raised stern, mast, square sail.
static func ship(kit: MeshKit) -> void:
	var sections := []
	var n := 9
	for i in n:
		var t := float(i) / (n - 1)
		var x := lerpf(-8.0, 8.0, t)
		var w := 2.2 * sin(PI * clampf(t * 1.02, 0.02, 0.98)) ** 0.7
		var sheer := 1.2 + 1.6 * pow(absf(t - 0.45) * 1.8, 3.0)
		sections.append([x, w, sheer])
	for i in n - 1:
		var a: Array = sections[i]
		var b: Array = sections[i + 1]
		for s: float in [1.0, -1.0]:
			var ka := Vector3(a[0], -0.6, 0)
			var kb := Vector3(b[0], -0.6, 0)
			var ta := Vector3(a[0], a[2], a[1] * s)
			var tb := Vector3(b[0], b[2], b[1] * s)
			if s > 0:
				kit.quad("hull", ka, kb, tb, ta)
			else:
				kit.quad("hull", kb, ka, ta, tb)
		kit.quad("wood", Vector3(a[0], a[2] - 0.3, a[1] * 0.9), Vector3(b[0], b[2] - 0.3, b[1] * 0.9),
				Vector3(b[0], b[2] - 0.3, -b[1] * 0.9), Vector3(a[0], a[2] - 0.3, -a[1] * 0.9))
	kit.lathe("hull", PackedVector2Array([Vector2(0.12, 0.8), Vector2(0.08, 10.0)]), 4)
	kit.box("hull", Vector3(0, 9.4, 0), Vector3(0.15, 0.15, 9.0), [])
	var sail := [Vector3(0.05, 9.3, 4.4), Vector3(0.05, 9.3, -4.4), Vector3(0.6, 3.6, -4.0), Vector3(0.6, 3.6, 4.0)]
	kit.quad("sail", sail[0], sail[1], sail[2], sail[3])
	kit.quad("sail", sail[1], sail[0], sail[3], sail[2])


## Bronze tripod with a cauldron: a classic dedication in Greek sanctuaries.
static func tripod(kit: MeshKit) -> void:
	for i in 3:
		var ang := TAU * i / 3.0
		var foot := Vector3(cos(ang) * 0.38, 0, sin(ang) * 0.38)
		var top := Vector3(cos(ang) * 0.24, 1.0, sin(ang) * 0.24)
		kit.xform = align_y(foot, top)
		kit.box("bronze", Vector3(0, foot.distance_to(top) / 2.0, 0), Vector3(0.05, foot.distance_to(top), 0.05), [])
	kit.xform = Transform3D.IDENTITY
	kit.lathe("bronze", PackedVector2Array([Vector2(0.05, 0.85), Vector2(0.28, 0.95), Vector2(0.33, 1.15), Vector2(0.3, 1.2)]),
			8, Vector3.ZERO, 1.0, true, "dark", true)
	for s: float in [1.0, -1.0]:
		kit.box("bronze", Vector3(0.2 * s, 1.32, 0), Vector3(0.03, 0.22, 0.18), [])


## Seated terracotta goddess figurine (~25 cm).
static func figurine(kit: MeshKit) -> void:
	kit.box("figurine", Vector3(0, 0.04, 0), Vector3(0.12, 0.08, 0.1), [])
	kit.box("figurine", Vector3(0, 0.12, 0.0), Vector3(0.1, 0.1, 0.09), [])
	kit.lathe("figurine", PackedVector2Array([Vector2(0.05, 0.16), Vector2(0.045, 0.22), Vector2(0.025, 0.24)]), 6)
	kit.lathe("figurine", PackedVector2Array([Vector2(0.018, 0.24), Vector2(0.025, 0.27), Vector2(0.0, 0.3)]), 6)
	kit.box("figurine", Vector3(0, 0.28, 0), Vector3(0.06, 0.025, 0.05), [])


## Transform whose local +Y runs from `from` to `to` (for lathing along a segment).
static func align_y(from: Vector3, to: Vector3) -> Transform3D:
	var y := (to - from).normalized()
	var ref := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.99 else Vector3.RIGHT
	var x := y.cross(ref).normalized()
	return Transform3D(Basis(x, y, x.cross(y)), from)


## A clay dish with a few gold staters (scaled up a little: at 640x360 a
## real 2 cm coin would be a single pixel).
static func coins(kit: MeshKit) -> void:
	kit.lathe("clay", PackedVector2Array([Vector2(0.06, 0), Vector2(0.15, 0.03), Vector2(0.16, 0.05)]), 8,
			Vector3.ZERO, 1.0, true, "clay", true)
	for c: Vector3 in [Vector3(0.0, 0.05, 0.0), Vector3(0.05, 0.058, 0.03), Vector3(-0.04, 0.055, 0.04)]:
		kit.lathe("gold", PackedVector2Array([Vector2(0.032, c.y), Vector2(0.032, c.y + 0.008)]), 8,
				Vector3(c.x, 0, c.z), 1.0, true, "gold", true)


static func sherds(kit: MeshKit) -> void:
	var pieces := [[Vector3(0, 0.01, 0), 0.0], [Vector3(0.14, 0.01, 0.05), 0.9], [Vector3(-0.1, 0.01, 0.1), 2.1]]
	for p: Array in pieces:
		kit.xform = Transform3D(Basis.from_euler(Vector3(0.15, p[1], 0.1)), p[0])
		var w := 0.12
		kit.quad("redfigure", Vector3(-w, 0, w), Vector3(w, 0, w * 0.7), Vector3(w * 0.8, 0.02, -w), Vector3(-w * 0.9, 0.03, -w * 0.8),
				PackedVector2Array([Vector2(0.1, 0.9), Vector2(0.6, 0.9), Vector2(0.6, 0.3), Vector2(0.1, 0.3)]))
		kit.quad("clay", Vector3(-w, -0.01, w), Vector3(-w * 0.9, 0.02, -w * 0.8), Vector3(w * 0.8, 0.01, -w), Vector3(w, -0.01, w * 0.7))
	kit.xform = Transform3D.IDENTITY


static func grain(kit: MeshKit) -> void:
	kit.lathe("clay", PackedVector2Array([
		Vector2(0.18, 0), Vector2(0.38, 0.2), Vector2(0.5, 0.6), Vector2(0.46, 1.0),
		Vector2(0.3, 1.2), Vector2(0.33, 1.3)]), 8, Vector3.ZERO, 2.0, true, "dark", true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for s: Vector3 in [Vector3(0.75, 0.3, 0.1), Vector3(0.6, 0.3, -0.5), Vector3(0.7, 0.75, -0.2)]:
		kit.blob("sail", s, Vector3(0.32, 0.3, 0.26), 0.15, rng)
	kit.color = Color(1.0, 0.85, 0.55)
	kit.blob("basket", Vector3(-0.15, 1.33, 0), Vector3(0.24, 0.08, 0.24), 0.2, rng)
	kit.color = Color.WHITE


## Bronze lampstand with a clay oil lamp on top (flame at FLAME_Y["lampstand"]).
static func lampstand(kit: MeshKit) -> void:
	for i in 3:
		var ang := TAU * i / 3.0
		kit.xform = align_y(Vector3(cos(ang) * 0.22, 0, sin(ang) * 0.22), Vector3(0, 0.18, 0))
		kit.box("bronze", Vector3(0, 0.13, 0), Vector3(0.04, 0.26, 0.04), [])
	kit.xform = Transform3D.IDENTITY
	kit.lathe("bronze", PackedVector2Array([Vector2(0.035, 0.15), Vector2(0.025, 1.25), Vector2(0.11, 1.3)]), 6,
			Vector3.ZERO, 1.0, true, "bronze", true)
	kit.lathe("clay", PackedVector2Array([Vector2(0.05, 1.3), Vector2(0.08, 1.33), Vector2(0.06, 1.37)]), 6,
			Vector3.ZERO, 1.0, true, "dark", true)
	kit.box("clay", Vector3(0.1, 1.355, 0), Vector3(0.07, 0.025, 0.03), [])


## Wooden post with a bronze torch cup (flame at FLAME_Y["torch_post"]).
static func torch_post(kit: MeshKit) -> void:
	kit.box("wood", Vector3(0, 0.9, 0), Vector3(0.11, 1.8, 0.11), ["bottom"])
	kit.lathe("bronze", PackedVector2Array([Vector2(0.05, 1.78), Vector2(0.12, 1.92)]), 6,
			Vector3.ZERO, 1.0, true, "dark", true)


const FLAME_Y := {"lampstand": 1.4, "torch_post": 1.96}


static var _scenes := {}


## Loads the baked GLB (imported as a scene) and assigns the project's PSX materials.
static func instance(name: String) -> Node3D:
	var ps: PackedScene = _scenes.get(name)
	if ps == null:
		ps = load("res://assets/models/%s.glb" % name)
		_scenes[name] = ps
	var node: Node3D = ps.instantiate()
	Mats.apply_to(node)
	return node


static func clear() -> void:
	_scenes.clear()
