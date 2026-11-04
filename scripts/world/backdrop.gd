extends District
## The rest of the city as seen from the hill: terraces of simple houses on the
## slopes, batched into one mesh, and the city wall with towers on the ridges.
## Everything collides, but the walls also bound the play area north and south.
##
## Lived in: trodden lanes run between the rows down towards the main street,
## hearth smoke rises from some roofs through the day, and after dusk lamps
## show in some windows.

const WALL_Z := 78.0
const STEP := 9.0
## Lanes: east-west in every other gap between the rows, north-south every
## third; houses standing on a lane are nudged off it.
const LANES_Z := [-67.5, -49.5, -31.5, -13.5, 22.5, 40.5, 58.5]
const LANES_X := [-59.5, -32.5, -5.5, 21.5, 48.5]
const LANE_HALF := 0.9
const LANE_SEG := 1.5
## Hearths smoking: one roof in this many.
const SMOKE_EVERY := 7
## Windows lit from this hour (dusk).
const GLOW_FROM := 0.75

var _glow: Node3D
var _smoke: Array[GPUParticles3D] = []
var _atm: Node


## The houses, drawn from the city's seed in the order the city has always
## been built (so nothing moves): {pos, yaw, w, d, h, opts}. Houses on the
## walk-in house's plot keep their draws but are left out.
static func plan() -> Array:
	var out := []
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var x := -64.0
	while x < 60.0:
		var z := -72.0
		while z < 72.0:
			var px := x + rng.randf_range(-2.0, 2.0)
			var pz := z + rng.randf_range(-2.0, 2.0)
			z += STEP
			if absf(pz) < 12.0 or Topo.is_reserved(px, pz, 2.0) or rng.randf() < 0.18:
				continue
			if Topo.terrain(px, pz) < 2.2:
				continue  # keep the shore free
			var w := rng.randf_range(5.0, 8.0)
			var d := rng.randf_range(4.5, 7.0)
			# face downhill (east) or towards the street axis, with a little jitter
			var yaw := (PI / 2.0 if rng.randf() < 0.5 else (0.0 if pz < 0 else PI)) + rng.randf_range(-0.12, 0.12)
			var h := rng.randf_range(3.0, 4.3)
			var opts := {
				"roof": "gable" if rng.randf() < 0.65 else "flat",
				"door": rng.randf() < 0.6,
				"windows": rng.randi_range(0, 1),
				"seed": int(px * 10.0) * 1000 + int(pz * 10.0),
			}
			if not Topo.in_house(px, pz, 6.0):
				var p := clear_of_lanes(Vector2(px, pz), yaw, w, d)
				out.append({"pos": p, "yaw": yaw, "w": w, "d": d, "h": h, "opts": opts})
		x += STEP
	return out


## A house's centre moved just far enough that its footprint leaves the lanes free.
static func clear_of_lanes(p: Vector2, yaw: float, w: float, d: float) -> Vector2:
	var ex := absf(cos(yaw)) * w / 2.0 + absf(sin(yaw)) * d / 2.0
	var ez := absf(sin(yaw)) * w / 2.0 + absf(cos(yaw)) * d / 2.0
	for lz: float in LANES_Z:
		var need := ez + LANE_HALF + 0.3
		if absf(p.y - lz) < need:
			p.y = lz + need * (1.0 if p.y >= lz else -1.0)
	for lx: float in LANES_X:
		var need := ex + LANE_HALF + 0.3
		if absf(p.x - lx) < need:
			p.x = lx + need * (1.0 if p.x >= lx else -1.0)
	return p


## Is (x, z) on a house's footprint (with a margin)?
static func on_house(houses: Array, x: float, z: float, margin: float) -> bool:
	for hs: Dictionary in houses:
		var local := Basis.from_euler(Vector3(0, hs.yaw, 0)).inverse() * Vector3(x - hs.pos.x, 0, z - hs.pos.y)
		if absf(local.x) < hs.w / 2.0 + margin and absf(local.z) < hs.d / 2.0 + margin:
			return true
	return false


## Lane pieces [a, b] (on the ground plane) between the rows, cut wherever a
## house, the reserved city centre or the shore is in the way.
static func lanes(houses: Array) -> Array:
	var out := []
	var runs := []
	for z: float in LANES_Z:
		runs.append([Vector2(-66.0, z), Vector2(62.0, z)])
	for x: float in LANES_X:
		runs.append([Vector2(x, -74.0), Vector2(x, 74.0)])
	for r: Array in runs:
		var a: Vector2 = r[0]
		var b: Vector2 = r[1]
		var n := int(a.distance_to(b) / LANE_SEG)
		for k in n:
			var p0 := a.lerp(b, float(k) / n)
			var p1 := a.lerp(b, float(k + 1) / n)
			var m := (p0 + p1) / 2.0
			if on_house(houses, m.x, m.y, LANE_HALF + 0.2) or Topo.is_reserved(m.x, m.y, 1.0) \
					or Topo.in_house(m.x, m.y, 1.0) or Topo.terrain(m.x, m.y) < 2.4 or absf(m.y) > WALL_Z - 3.0:
				continue
			out.append([p0, p1])
	return out


func _ready() -> void:
	_atm = get_parent().get_node_or_null("Atmosphere")
	var kit := MeshKit.new()
	var glow := MeshKit.new()
	var houses := plan()
	for hs: Dictionary in houses:
		_house(kit, glow, hs)
	_walls(kit)
	add_child(kit.build("Backdrop"))
	_glow = glow.build("WindowGlow")
	add_child(_glow)
	_lanes(houses)
	_hearths(houses)


func _house(kit: MeshKit, glow: MeshKit, hs: Dictionary) -> void:
	var basis := Basis.from_euler(Vector3(0, hs.yaw, 0))
	var center := Vector3(hs.pos.x, 0, hs.pos.y)
	var lo := INF
	var hi := -INF
	for sx in [-0.5, 0.5]:
		for sz in [-0.5, 0.5]:
			var q := center + basis * Vector3(sx * hs.w, 0, sz * hs.d)
			var t := Topo.terrain(q.x, q.z)
			lo = minf(lo, t)
			hi = maxf(hi, t)
	var front := center + basis * Vector3(0, 0, hs.d / 2.0)
	front.y = hi
	var opts: Dictionary = hs.opts.duplicate()
	opts["drop"] = hi - lo + 1.0
	opts["glow"] = glow
	hs["front"] = front
	Arch.house(kit, Transform3D(basis, front), hs.w, hs.d, hs.h, opts)


## Trodden earth between the rows, hugging the ground.
func _lanes(houses: Array) -> void:
	var kit := MeshKit.new()
	for seg: Array in lanes(houses):
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		var side := (b - a).normalized().orthogonal() * LANE_HALF
		var pts := [a - side, b - side, b + side, a + side]  # counter-clockwise seen from above
		var v := []
		for p: Vector2 in pts:
			v.append(Vector3(p.x, Topo.terrain(p.x, p.y) + 0.08, p.y))
		kit.quad("path", v[0], v[1], v[2], v[3])
	var node := kit.build("Lanes")
	add_child(node)
	(node.get_node("Mesh") as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Smoke from the hearths under some roofs, through the day.
func _hearths(houses: Array) -> void:
	for i in houses.size():
		if i % SMOKE_EVERY != 3:
			continue
		var hs: Dictionary = houses[i]
		var basis := Basis.from_euler(Vector3(0, hs.yaw, 0))
		var ridge := minf(hs.d * 0.22, 1.4) if hs.opts.roof == "gable" else 0.3
		var top: Vector3 = hs.front + basis * Vector3(hs.w * 0.25, hs.h + ridge, -hs.d / 2.0)
		var smoke := Lamp._make_flame(0.9)
		var pm: ParticleProcessMaterial = smoke.process_material
		var g := Gradient.new()
		g.set_color(0, Color(0.36, 0.34, 0.32))
		g.set_color(1, Color(0.27, 0.26, 0.25))
		(pm.color_ramp as GradientTexture1D).gradient = g
		pm.initial_velocity_min = 0.25
		pm.initial_velocity_max = 0.45
		pm.spread = 30.0
		pm.gravity = Vector3(0.2, 0.1, 0)  # the breeze off the strait leans it a little
		pm.scale_min = 0.5
		pm.scale_max = 1.0
		# each puff swells as it rises, then shrinks away: a ragged plume, not a column
		var curve := Curve.new()
		curve.add_point(Vector2(0.0, 0.4))
		curve.add_point(Vector2(0.5, 1.0))
		curve.add_point(Vector2(1.0, 0.2))
		var ct := CurveTexture.new()
		ct.curve = curve
		pm.scale_curve = ct
		(smoke.draw_pass_1.surface_get_material(0) as StandardMaterial3D).blend_mode = BaseMaterial3D.BLEND_MODE_MIX
		smoke.amount = 5
		smoke.lifetime = 5.0
		smoke.position = top
		smoke.visibility_aabb = AABB(Vector3(-3, 0, -3), Vector3(6, 6, 6))
		smoke.emitting = true
		smoke.visible = true
		add_child(smoke)
		_smoke.append(smoke)


func _process(_delta: float) -> void:
	var hour: float = _atm.t if _atm else 0.0
	_glow.visible = hour >= GLOW_FROM
	var day := hour < 0.95
	for s in _smoke:
		if s.emitting != day:
			s.emitting = day


func _walls(kit: MeshKit) -> void:
	for side: float in [1.0, -1.0]:
		var x := -110.0
		var seg := 0
		while x < 62.0:
			var x2 := x + 10.0
			var a := Vector3(x, Topo.terrain(x, side * WALL_Z), side * WALL_Z)
			var b := Vector3(x2, Topo.terrain(x2, side * WALL_Z), side * WALL_Z)
			var base := minf(a.y, b.y) - 1.5
			var top := maxf(a.y, b.y) + 4.0
			kit.solid_box("limestone", Vector3((x + x2) / 2.0, (base + top) / 2.0, side * WALL_Z), Vector3(10.2, top - base, 1.8), ["bottom"])
			if seg % 4 == 0:
				var tb := a.y - 1.5
				kit.solid_box("limestone", Vector3(x, tb + 3.6, side * WALL_Z), Vector3(6.0, 7.2, 6.0), ["bottom"])
				kit.box("roof", Vector3(x, tb + 7.3, side * WALL_Z), Vector3(6.4, 0.25, 6.4), ["bottom"])
			x = x2
			seg += 1
