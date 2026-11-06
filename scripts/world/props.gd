class_name Props
extends RefCounted
## Low-poly prop geometry. Baked to assets/models/*.glb by tools/bake_models.gd;
## the game loads the GLBs (see instance()). Units are meters, origin at the base.

## Baked to GLB. EXTRA kinds are small one-off models built at runtime.
const MODELS := ["amphora", "pithos", "krater", "column_doric", "olive_tree", "cypress", "ship", "tripod", "figurine"]
const EXTRA := ["coins", "sherds", "stele", "grain", "votive", "lampstand", "torch_post", "mould", "boat", "sinkers", "hekataion", "mirror", "marble_head", "loom_weights", "oil_lamp", "anchor_stock"]


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
		"mould":
			mould(kit)
		"boat":
			boat(kit)
		"sinkers":
			sinkers(kit)
		"hekataion":
			hekataion(kit)
		"mirror":
			mirror(kit)
		"marble_head":
			marble_head(kit)
		"loom_weights":
			loom_weights(kit)
		"oil_lamp":
			oil_lamp(kit)
		"anchor_stock":
			anchor_stock(kit)
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


## Olive at the origin, written into the kit. `xf` places (and scales) it, so a
## whole grove can go into one mesh instead of a node per tree.
static func olive_tree(kit: MeshKit, seed: int, xf: Transform3D = Transform3D.IDENTITY) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	# Gnarled trunk: stacked, offset frustums.
	var pts := [Vector3.ZERO, Vector3(0.15, 0.7, 0.05), Vector3(-0.05, 1.3, 0.12), Vector3(0.1, 1.8, -0.05)]
	var radii := [0.2, 0.15, 0.12, 0.09]
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		kit.xform = xf * align_y(a, b)
		kit.lathe("bark", PackedVector2Array([Vector2(radii[i], 0), Vector2(radii[i + 1], a.distance_to(b))]), 5,
				Vector3.ZERO, 1.0, false)
	kit.xform = xf
	for c: Array in [[Vector3(0.1, 2.3, 0), Vector3(1.3, 0.75, 1.2)], [Vector3(-0.6, 2.0, 0.4), Vector3(0.8, 0.55, 0.8)],
			[Vector3(0.7, 2.1, -0.5), Vector3(0.85, 0.6, 0.8)], [Vector3(0.0, 2.75, -0.2), Vector3(0.8, 0.5, 0.7)]]:
		kit.blob("foliage", c[0], c[1], 0.22, rng)
	kit.xform = Transform3D.IDENTITY


static func cypress(kit: MeshKit) -> void:
	kit.lathe("bark", PackedVector2Array([Vector2(0.12, 0), Vector2(0.1, 0.5)]), 5)
	kit.lathe("cypress", PackedVector2Array([
		Vector2(0.25, 0.3), Vector2(0.55, 1.4), Vector2(0.5, 3.2), Vector2(0.32, 4.8), Vector2(0.0, 6.2)]), 6,
		Vector3.ZERO, 2.0, false)


## Merchant ship silhouette (~16 m): lofted hull, raised stern, mast, square sail.
## Plank hull, bow along +x, keel at y = 0. Each section is keel, bilge and
## sheer: two bands of quads per side, so the hull has a rounded belly and not
## a V. The sheer rises towards both ends. `inner` != "" adds the inside skin
## (open boats, the hold). Returns the sections [x, half-beam, bilge y, sheer y]
## for decks and fittings.
static func hull(kit: MeshKit, length: float, beam: float, depth: float, sheer_mid: float, sheer_end: float,
		n: int, low: String, high: String, inner: String = "", rail: float = 0.0) -> Array:
	var sec := []
	for i in n:
		var t := float(i) / (n - 1)
		var e := absf(t * 2.0 - 1.0)  # 0 amidships, 1 at the ends
		# zero beam at the very ends: the planks close on the stem and stern posts
		var w := beam * pow(maxf(sin(PI * t), 0.0), 0.55)
		if w < 1e-3:
			w = 0.0  # sin(PI) is not exactly 0: keep the bow edge shared by both sides
		sec.append([lerpf(-length / 2.0, length / 2.0, t), w, depth * (0.55 + 0.25 * e), depth + sheer_mid + sheer_end * pow(e, 2.4)])
	for i in n - 1:
		var a: Array = sec[i]
		var b: Array = sec[i + 1]
		for s: float in [1.0, -1.0]:
			var ka := Vector3(a[0], 0.0, 0.0)
			var kb := Vector3(b[0], 0.0, 0.0)
			var ba := Vector3(a[0], a[2], a[1] * 0.82 * s)
			var bb := Vector3(b[0], b[2], b[1] * 0.82 * s)
			var ta := Vector3(a[0], a[3], a[1] * s)
			var tb := Vector3(b[0], b[3], b[1] * s)
			# Both sides and both skins split each quad on the same diagonal, the
			# one leaving the zero-beam end section; the other diagonal would make
			# a flat fin in the centre plane where the hull closes.
			var outer_low := [ka, kb, bb, ba] if s > 0 else [ka, ba, bb, kb]
			var outer_high := [ba, bb, tb, ta] if s > 0 else [ba, ta, tb, bb]
			if b[0] > 0.0:  # bow half: start the cycle at b's keel
				outer_low = [kb, bb, ba, ka] if s > 0 else [kb, ka, ba, bb]
				outer_high = [bb, tb, ta, ba] if s > 0 else [bb, ba, ta, tb]
			kit.quad(low, outer_low[0], outer_low[1], outer_low[2], outer_low[3])
			kit.quad(high, outer_high[0], outer_high[1], outer_high[2], outer_high[3])
			if inner != "":
				# reversed winding: [a, d, c, b] keeps the same a-c diagonal
				kit.quad(inner, outer_low[0], outer_low[3], outer_low[2], outer_low[1])
				kit.quad(inner, outer_high[0], outer_high[3], outer_high[2], outer_high[1])
	if rail > 0.0:  # gunwale: gives the sheer strake a visible thickness
		for s: float in [1.0, -1.0]:
			var pts := []
			for a: Array in sec:
				pts.append(Vector3(a[0], a[3], a[1] * s))
			beam_chain(kit, high, pts, rail)
	return sec


## A chain of boxes through `pts` (stem posts, the curling stern, rigging).
static func beam_chain(kit: MeshKit, mat: String, pts: Array, thick: float) -> void:
	var keep := kit.xform
	for i in pts.size() - 1:
		var p0: Vector3 = pts[i]
		var p1: Vector3 = pts[i + 1]
		var d := p0.distance_to(p1)
		kit.xform = keep * align_y(p0, p1)
		kit.box(mat, Vector3(0, d / 2.0, 0), Vector3(thick, d + thick * 0.5, thick), [])
	kit.xform = keep


## Half-beam of a hull at x, from the sections hull() returned.
static func hull_width(sec: Array, x: float) -> Vector2:
	for i in sec.size() - 1:
		var a: Array = sec[i]
		var b: Array = sec[i + 1]
		if x <= b[0]:
			var f := clampf((x - a[0]) / (b[0] - a[0]), 0.0, 1.0)
			return Vector2(lerpf(a[1], b[1], f), lerpf(a[3], b[3], f))
	return Vector2(sec[-1][1], sec[-1][3])


## Merchant ship (holkas) of the 4th century BCE: round hull pitched black below
## the wale, short decks fore and aft with an open hold of amphorae, a stem post,
## the stern curling up and forward (aphlaston), two steering oars, a mast with a
## yard and a square sail bellied by the wind from astern, fore- and backstay.
## Keel at y = 0; it floats with the waterline at about y = 1.
static func ship(kit: MeshKit) -> void:
	var L := 16.0
	var sec := hull(kit, L, 2.4, 1.3, 0.9, 1.3, 13, "dark", "hull", "wood", 0.16)
	var deck := func(x0: float, x1: float, y: float) -> void:
		var w0 := hull_width(sec, x0).x * 0.95
		var w1 := hull_width(sec, x1).x * 0.95
		kit.quad("wood", Vector3(x0, y, w0), Vector3(x1, y, w1), Vector3(x1, y, -w1), Vector3(x0, y, -w0))
	deck.call(-7.0, -4.2, 2.25)
	deck.call(4.6, 7.0, 2.25)
	# wale: a painted strake along the sheer
	for i in sec.size() - 1:
		var a: Array = sec[i]
		var b: Array = sec[i + 1]
		for s: float in [1.0, -1.0]:
			var pa := Vector3(a[0], a[3] - 0.3, a[1] * s * 1.01)
			var pb := Vector3(b[0], b[3] - 0.3, b[1] * s * 1.01)
			var qa := pa + Vector3(0, 0.18, 0)
			var qb := pb + Vector3(0, 0.18, 0)
			if s > 0:
				kit.quad("clay", pa, pb, qb, qa)
			else:
				kit.quad("clay", pb, pa, qa, qb)
	var bow: Array = sec[-1]
	var stern: Array = sec[0]
	beam_chain(kit, "hull", [Vector3(bow[0] - 0.4, 0.0, 0), Vector3(bow[0] + 0.3, 1.6, 0), Vector3(bow[0] + 0.5, bow[3] + 0.5, 0)], 0.3)
	beam_chain(kit, "hull", [Vector3(stern[0] + 0.4, 0.0, 0), Vector3(stern[0] - 0.3, 1.8, 0), Vector3(stern[0] - 0.4, stern[3] + 0.6, 0),
		Vector3(stern[0] - 0.1, stern[3] + 1.5, 0), Vector3(stern[0] + 0.5, stern[3] + 1.9, 0), Vector3(stern[0] + 0.9, stern[3] + 1.6, 0)], 0.28)
	for s: float in [1.0, -1.0]:
		beam_chain(kit, "wood", [Vector3(-5.6, 3.0, 2.0 * s), Vector3(-6.9, -0.6, 2.6 * s)], 0.14)
		kit.xform = align_y(Vector3(-6.9, -0.6, 2.6 * s), Vector3(-5.6, 3.0, 2.0 * s))
		kit.box("wood", Vector3(0, 0.6, 0), Vector3(0.06, 1.2, 0.4), [])
		kit.xform = Transform3D.IDENTITY
	# hold: rows of amphorae lying in the open waist
	for ix in 5:
		for iz in 3:
			var x := -3.0 + ix * 1.4
			kit.xform = Transform3D(Basis(Vector3.FORWARD, PI / 2.0) * Basis().scaled(Vector3.ONE * 1.3), Vector3(x + 0.5, 1.05, (iz - 1) * 0.7))
			amphora(kit)
	kit.xform = Transform3D.IDENTITY
	# mast, yard, sail (both faces), stays
	kit.lathe("hull", PackedVector2Array([Vector2(0.13, 0.4), Vector2(0.09, 11.0)]), 5, Vector3(0.6, 0, 0))
	var yard := 10.2
	kit.box("hull", Vector3(0.75, yard, 0), Vector3(0.16, 0.16, 9.4), [])
	var top_l := Vector3(0.82, yard - 0.05, 4.4)
	var top_r := Vector3(0.82, yard - 0.05, -4.4)
	var mid_l := Vector3(1.5, yard - 3.0, 4.3)
	var mid_r := Vector3(1.5, yard - 3.0, -4.3)
	var bot_l := Vector3(1.4, yard - 6.0, 4.0)
	var bot_r := Vector3(1.4, yard - 6.0, -4.0)
	for q: Array in [[top_l, top_r, mid_r, mid_l], [mid_l, mid_r, bot_r, bot_l]]:
		kit.quad("sail", q[0], q[1], q[2], q[3])
		kit.quad("sail", q[1], q[0], q[3], q[2])
	beam_chain(kit, "dark", [Vector3(0.6, 10.9, 0), Vector3(bow[0] + 0.5, bow[3] + 0.4, 0)], 0.05)
	beam_chain(kit, "dark", [Vector3(0.6, 10.9, 0), Vector3(stern[0] + 0.6, stern[3] + 0.2, 0)], 0.05)
	for s: float in [1.0, -1.0]:
		beam_chain(kit, "dark", [Vector3(0.6, 10.6, 0), Vector3(0.0, 2.4, 2.3 * s)], 0.04)


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


## Two-piece clay mould for a figurine, opened: the front half shows the
## hollow of a seated goddess, the back half lies beside it.
static func mould(kit: MeshKit) -> void:
	kit.box("clay", Vector3(-0.09, 0.05, 0), Vector3(0.15, 0.1, 0.24), [])
	kit.box("dark", Vector3(-0.09, 0.101, 0.01), Vector3(0.07, 0.002, 0.16), ["bottom"])
	kit.box("dark", Vector3(-0.09, 0.101, -0.08), Vector3(0.04, 0.002, 0.04), ["bottom"])
	kit.box("clay", Vector3(0.09, 0.05, 0.01), Vector3(0.15, 0.1, 0.24), [])
	kit.blob("figurine", Vector3(0.0, 0.03, 0.2), Vector3(0.05, 0.03, 0.05), 0.2, RandomNumberGenerator.new())


## Small open fishing boat, bow along +x, keel at y = 0: the ship's hull in
## small, open, with stem and stern posts, two thwarts and the oars shipped.
static func boat(kit: MeshKit) -> void:
	var sec := hull(kit, 4.6, 0.82, 0.42, 0.14, 0.32, 11, "hull", "wood", "wood", 0.06)
	var bow: Array = sec[-1]
	var stern: Array = sec[0]
	beam_chain(kit, "hull", [Vector3(bow[0] - 0.15, 0.0, 0), Vector3(bow[0] + 0.12, bow[3] * 0.6, 0), Vector3(bow[0] + 0.18, bow[3] + 0.15, 0)], 0.09)
	beam_chain(kit, "hull", [Vector3(stern[0] + 0.15, 0.0, 0), Vector3(stern[0] - 0.1, stern[3] * 0.6, 0), Vector3(stern[0] - 0.14, stern[3] + 0.1, 0)], 0.09)
	for x: float in [-0.9, 0.6]:
		var w := hull_width(sec, x)
		kit.box("wood", Vector3(x, w.y - 0.12, 0), Vector3(0.2, 0.05, w.x * 1.9), [])
	for s: float in [1.0, -1.0]:
		beam_chain(kit, "wood", [Vector3(-1.7, 0.42, 0.18 * s), Vector3(1.9, 0.5, 0.3 * s)], 0.05)
		kit.box("wood", Vector3(1.75, 0.5, 0.3 * s), Vector3(0.5, 0.025, 0.13), [])


## Net weights: pierced clay discs cut from broken pots, and two pyramidal
## loom-weight-like sinkers, lying on a scrap of net.
static func sinkers(kit: MeshKit) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	kit.quad("net", Vector3(-0.2, 0.004, 0.16), Vector3(0.2, 0.004, 0.16), Vector3(0.2, 0.004, -0.16), Vector3(-0.2, 0.004, -0.16))
	for i in 5:
		var p := Vector3(-0.13 + i * 0.065, 0.0, rng.randf_range(-0.08, 0.08))
		kit.lathe("clay", PackedVector2Array([Vector2(0.03, 0.0), Vector2(0.03, 0.014)]), 6, p, 1.0, true, "clay", true)
		kit.box("dark", p + Vector3(0, 0.0145, 0), Vector3(0.008, 0.001, 0.008), ["bottom"])
	for x: float in [-0.08, 0.1]:
		var p := Vector3(x, 0.0, 0.11 * signf(x))
		kit.lathe("clay", PackedVector2Array([Vector2(0.035, 0.0), Vector2(0.015, 0.07)]), 4, p, 1.0, true, "clay", true)


## A marble head of a goddess, larger than life, broken at the neck, in a
## Corinthian helmet pushed up on the brow, its crest knocked off; on straw.
## Faces +z (towards the ItemViewer's camera), origin on the ground.
static func marble_head(kit: MeshKit) -> void:
	kit.box("steppe", Vector3(0, 0.015, 0), Vector3(0.62, 0.03, 0.5), [])  # the straw
	kit.lathe("column", PackedVector2Array([Vector2(0.075, 0.03), Vector2(0.07, 0.11)]), 8, Vector3.ZERO, 1.0, false, "column", true)  # neck, broken flat
	kit.box("column", Vector3(0, 0.25, 0), Vector3(0.22, 0.3, 0.25), [])  # head
	kit.box("column", Vector3(0, 0.22, 0.135), Vector3(0.04, 0.08, 0.035), [])  # nose
	kit.box("column", Vector3(0, 0.13, 0.1), Vector3(0.13, 0.06, 0.06), [])  # chin
	kit.box("column", Vector3(0, 0.27, -0.09), Vector3(0.2, 0.22, 0.1), [])  # hair drawn back
	# the helmet sits high, its face-guard tipped up over the brow
	kit.box("column", Vector3(0, 0.43, 0.01), Vector3(0.25, 0.08, 0.29), [])
	kit.box("column", Vector3(0, 0.4, 0.14), Vector3(0.24, 0.05, 0.06), [])
	kit.box("column", Vector3(0, 0.48, 0.0), Vector3(0.05, 0.03, 0.08), [])  # stump of the crest
	for sx: float in [-1.0, 1.0]:
		kit.box("dark", Vector3(0.055 * sx, 0.285, 0.127), Vector3(0.05, 0.016, 0.004), [])  # eyes, carved deep
	kit.box("dark", Vector3(0, 0.165, 0.127), Vector3(0.05, 0.01, 0.004), [])  # the line of the lips


## Pyramidal clay loom weights, pierced near the top, a dozen heaped by the
## loom: some standing, some on their sides, one with a stamp.
static func loom_weights(kit: MeshKit) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 12:
		var a := TAU * i / 12.0 + rng.randf_range(-0.2, 0.2)
		var r := 0.06 + 0.07 * float(i % 3)
		var p := Vector3(cos(a) * r, 0.0, sin(a) * r)
		var lying := i % 4 == 3
		kit.xform = Transform3D(Basis(Vector3.UP, rng.randf_range(0, TAU)) * (Basis(Vector3.RIGHT, PI / 2.0) if lying else Basis.IDENTITY),
				p + Vector3(0, 0.032 if lying else 0.0, 0))
		kit.frustum("clay", Vector3.ZERO, Vector2(0.064, 0.064), Vector2(0.028, 0.028), 0.1, ["bottom"])
		kit.box("dark", Vector3(0, 0.078, -0.02), Vector3(0.012, 0.012, 0.004), [])  # the hole for the string
		if i == 4:
			kit.box("dark", Vector3(0, 0.1005, 0), Vector3(0.014, 0.002, 0.014), [])  # a stamp on the top
	kit.xform = Transform3D.IDENTITY


## A wheel-made lamp in black glaze: round body, filling hole, short nozzle
## sooted at the tip. Nozzle along -z, origin on the surface it stands on.
static func oil_lamp(kit: MeshKit) -> void:
	kit.lathe("dark", PackedVector2Array([Vector2(0.035, 0.0), Vector2(0.05, 0.015), Vector2(0.045, 0.03), Vector2(0.02, 0.036)]), 10,
			Vector3.ZERO, 1.0, true, "dark", false)
	kit.box("dark", Vector3(0, 0.017, -0.07), Vector3(0.03, 0.022, 0.06), ["bottom"])  # nozzle
	kit.box("hair", Vector3(0, 0.029, -0.099), Vector3(0.02, 0.003, 0.008), ["bottom"])  # the soot at the wick hole
	kit.box("clay", Vector3(0, 0.0365, 0), Vector3(0.014, 0.001, 0.014), ["bottom"])  # filling hole, clay showing


## The lead stock of an anchor: a bar tapering to both ends, a slot through
## its thick middle where the wooden shank went. Along x, origin on the ground.
static func anchor_stock(kit: MeshKit) -> void:
	for sx: float in [-1.0, 1.0]:
		kit.xform = Transform3D(Basis(Vector3.FORWARD, -sx * PI / 2.0), Vector3(0.06 * sx, 0.055, 0))
		kit.frustum("lead", Vector3.ZERO, Vector2(0.11, 0.1), Vector2(0.05, 0.05), 0.5, ["bottom"])
	kit.xform = Transform3D.IDENTITY
	kit.box("lead", Vector3(0, 0.055, 0), Vector3(0.14, 0.11, 0.1), ["bottom"])
	kit.box("dark", Vector3(0, 0.111, 0), Vector3(0.07, 0.002, 0.05), ["bottom"])  # the slot for the shank


## Hekataion: Hecate in triple form, three standing maidens back to back
## around a pillar, each in a long peplos and a tall polos, holding a torch,
## on a stepped base. Marble. About 1.9 m, origin at the foot of the base.
static func hekataion(kit: MeshKit) -> void:
	kit.box("column", Vector3(0, 0.12, 0), Vector3(0.95, 0.24, 0.95), ["bottom"])
	kit.box("column", Vector3(0, 0.33, 0), Vector3(0.75, 0.18, 0.75), ["bottom"])
	kit.lathe("column", PackedVector2Array([Vector2(0.11, 0.42), Vector2(0.1, 1.75)]), 6, Vector3.ZERO, 1.0, true, "column", true)
	for i in 3:
		var ang := TAU * i / 3.0
		kit.xform = Transform3D(Basis(Vector3.UP, ang), Vector3.ZERO)
		var z := 0.2  # each maiden stands against the pillar, facing out
		# long peplos, flaring to the feet
		kit.lathe("column", PackedVector2Array([Vector2(0.17, 0.42), Vector2(0.14, 0.8), Vector2(0.11, 1.15), Vector2(0.12, 1.32)]), 6,
				Vector3(0, 0, z), 1.0, true, "column", false)
		kit.box("column", Vector3(0, 1.4, z), Vector3(0.24, 0.16, 0.14), [])  # shoulders
		kit.box("column", Vector3(0, 1.55, z + 0.01), Vector3(0.12, 0.15, 0.13), [])  # head
		kit.lathe("column", PackedVector2Array([Vector2(0.07, 1.62), Vector2(0.09, 1.76)]), 6, Vector3(0, 0, z + 0.01), 1.0, true, "column", true)  # polos
		# a torch held upright in front
		kit.box("column", Vector3(0.1, 1.22, z + 0.12), Vector3(0.06, 0.06, 0.14), [])
		kit.box("bronze", Vector3(0.1, 1.33, z + 0.17), Vector3(0.04, 0.42, 0.04), [])
		kit.box("fire", Vector3(0.1, 1.57, z + 0.17), Vector3(0.07, 0.08, 0.07), [])
	kit.xform = Transform3D.IDENTITY


## Greek bronze hand mirror lying on its back: a polished disc with a raised
## rim and a turned handle ending in a knob. Origin under the disc's centre.
static func mirror(kit: MeshKit) -> void:
	# disc: back (bronze, greened) and polished face
	kit.lathe("bronze", PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.11, 0.004), Vector2(0.13, 0.012), Vector2(0.13, 0.02)]), 12,
			Vector3.ZERO, 1.0, true, "gold", true)
	kit.lathe("bronze", PackedVector2Array([Vector2(0.13, 0.02), Vector2(0.135, 0.026), Vector2(0.125, 0.026)]), 12)
	# handle: a tang with a moulded ring, a shaft and a knob, lying flat
	kit.box("bronze", Vector3(0, 0.012, 0.15), Vector3(0.05, 0.02, 0.05), [])
	kit.box("bronze", Vector3(0, 0.014, 0.19), Vector3(0.035, 0.024, 0.04), [])
	kit.box("bronze", Vector3(0, 0.012, 0.25), Vector3(0.026, 0.02, 0.09), [])
	kit.box("bronze", Vector3(0, 0.014, 0.305), Vector3(0.04, 0.026, 0.03), [])


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
