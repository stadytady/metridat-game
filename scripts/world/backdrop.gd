extends District
## The rest of the city on the slopes of the hill, built as Panticapaeum was:
## the slopes cut into terraces held up by stone retaining walls, a street
## along each terrace following the lie of the ground, rows of houses fronting
## it, wall to wall, and steep stepped lanes running straight down the slope
## between the terraces. On the flatter ground east of the agora the streets
## keep the same north-south run. Batched into one mesh; everything collides,
## and the city wall bounds the play area north and south.
##
## Lived in: hearth smoke rises from some roofs through the day, and after
## dusk lamps show in some windows.

const WALL_Z := 78.0
## Terrace streets: about every ten metres down the slope, each following the
## contour through that point; north-south runs at these x on the flatter
## ground east of the agora.
const TERRACES_X := [-58.0, -48.0, -38.0, -28.0, -18.0, -8.0]
const FLAT_STREETS_X := [14.0, 28.0, 42.0]
const TERRACE_SLOPE_END := 4.0
## Stepped lanes down the slope, at about these z.
const STAIRS_Z := [-64.0, -46.0, -28.0, 20.0, 37.0, 55.0]
const Z_SPAN := Vector2(-73.0, 73.0)
const Z_STEP := 2.5
const LANE_HALF := 0.9
const LANE_SEG := 1.5
## Hearths smoking: one roof in this many.
const SMOKE_EVERY := 7
## Windows lit from this hour, with the town's lamps.
const GLOW_FROM := DayCycle.LAMPS_ON

var _glow: Node3D
## The one house you can walk into, and the lamp beside its door.
var _cottage_lamp: WallLamp
var _cottage_at := Transform3D.IDENTITY
## The householder in the cottage: a woman with her hair under a kerchief.
var _woman: Npc
var _smoke: Array[GPUParticles3D] = []
var _atm: Node


## Where the ground falls through `level` going east (downhill) at z: the contour.
static func _contour_x(level: float, z: float) -> float:
	var x := -66.0
	while x < TERRACE_SLOPE_END:
		if Topo.terrain(x, z) <= level:
			var lo := x - 1.0
			var hi := x
			for i in 6:
				var mid := (lo + hi) / 2.0
				if Topo.terrain(mid, z) > level:
					lo = mid
				else:
					hi = mid
			return hi
		x += 1.0
	return NAN


## The terrace streets as polylines of (x, z), north to south. A contour that
## leaves the slope is broken there; each run is smoothed so the street bends
## with the hill, not with every bump in it.
static func streets() -> Array:
	var out := []
	for x_at: float in TERRACES_X:
		# the terrace's height: the ground at that x, either side of the street axis
		var level := (Topo.terrain(x_at, 30.0) + Topo.terrain(x_at, -30.0)) / 2.0
		var run := PackedVector2Array()
		var z := Z_SPAN.x
		while z <= Z_SPAN.y:
			var x := _contour_x(level, z)
			if is_nan(x):
				if run.size() > 3:
					out.append(_smooth(run))
				run = PackedVector2Array()
			else:
				run.append(Vector2(x, z))
			z += Z_STEP
		if run.size() > 3:
			out.append(_smooth(run))
	for x0: float in FLAT_STREETS_X:
		var run := PackedVector2Array()
		var z := Z_SPAN.x
		while z <= Z_SPAN.y:
			run.append(Vector2(x0 + 2.2 * sin(z * 0.045 + x0) + 1.2 * sin(z * 0.11), z))
			z += Z_STEP
		out.append(run)
	return out


static func _smooth(run: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in run.size():
		var sx := 0.0
		var n := 0
		for k in range(maxi(0, i - 2), mini(run.size(), i + 3)):
			sx += run[k].x
			n += 1
		out.append(Vector2(sx / n, run[i].y))
	return out


## The stepped lanes, straight down the slope (west to east), wandering a little.
static func stairs() -> Array:
	var out := []
	for z0: float in STAIRS_Z:
		var run := PackedVector2Array()
		var x := -66.0
		while x <= 56.0:
			run.append(Vector2(x, z0 + 2.0 * sin(x * 0.06 + z0) + 0.8 * sin(x * 0.17)))
			x += Z_STEP
		out.append(run)
	return out


static func _dist_to(runs: Array, p: Vector2) -> float:
	var best := INF
	for run: PackedVector2Array in runs:
		for i in run.size() - 1:
			var a := run[i]
			var b := run[i + 1]
			if minf(absf(p.x - a.x), absf(p.x - b.x)) > best + 4.0 and minf(absf(p.y - a.y), absf(p.y - b.y)) > best + 4.0:
				continue  # a segment (at most a few metres long) this far off cannot be nearer
			var ab := b - a
			var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
			best = minf(best, p.distance_to(a + ab * t))
	return best


static func _footprint(hs: Dictionary) -> Array[Vector2]:
	var basis := Basis.from_euler(Vector3(0, hs.yaw, 0))
	var out: Array[Vector2] = []
	for sx: float in [-0.5, 0.0, 0.5]:
		for sz: float in [-0.5, 0.0, 0.5]:
			var q := basis * Vector3(sx * hs.w, 0, sz * hs.d)
			out.append(hs.pos + Vector2(q.x, q.z))
	return out


## `others`: the street runs other than the one the house fronts (its own
## street bends under the corners of a straight house on a curve).
static func _site_ok(hs: Dictionary, houses: Array, stair_runs: Array, others: Array) -> bool:
	for p in _footprint(hs):
		if Topo.is_reserved(p.x, p.y, 1.0) or Topo.in_house(p.x, p.y, 2.0) or Topo.on_pier(p.x, p.y, 2.0):
			return false
		if Topo.terrain(p.x, p.y) < 2.2 or absf(p.y) > WALL_Z - 4.0:
			return false
		if _dist_to(stair_runs, p) < LANE_HALF + 0.4 or _dist_to(others, p) < LANE_HALF + 0.2:
			return false
		if on_house(houses, p.x, p.y, -0.15):  # neighbours may share a wall, not overlap
			return false
	return true


## The houses: rows along both sides of each street, fronts on the street,
## neighbours wall to wall with now and then a gap or a yard.
## {pos, yaw, w, d, h, opts}.
static func plan() -> Array:
	var out := []
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var street_runs := streets()
	var stair_runs := stairs()
	# every street gets a row on its uphill (west) side first, then a row on
	# its downhill side wherever the ground between the terraces is still free
	for r in street_runs.size() * 2:
		var run: PackedVector2Array = street_runs[r % street_runs.size()]
		var east := r >= street_runs.size()
		var others := street_runs.filter(func(o: PackedVector2Array) -> bool: return o != run)
		var i := 0
		var carry := rng.randf_range(0.0, 3.0)
		while i < run.size() - 1:
			var a := run[i]
			var b := run[i + 1]
			var seg := a.distance_to(b)
			if carry > seg:
				carry -= seg
				i += 1
				continue
			var w := rng.randf_range(4.5, 7.5)
			var d := rng.randf_range(4.5, 6.5)
			var p := a.lerp(b, carry / seg)
			var t := (b - a).normalized()
			var n := Vector2(-t.y, t.x)
			if (n.x > 0.0) != east:
				n = -n  # uphill (west) on the first pass, downhill (east) on the second
			var front := p + n * (LANE_HALF + 0.4)
			var hs := {
				"pos": front + n * (d / 2.0),
				"yaw": atan2(-n.x, -n.y),
				"w": w, "d": d,
				"h": rng.randf_range(3.0, 4.3),
				"opts": {
					"roof": "gable" if rng.randf() < 0.65 else "flat",
					"door": rng.randf() < 0.7,
					"door_x": rng.randf_range(-w / 2.0 + 1.0, w / 2.0 - 1.0),
					"windows": rng.randi_range(0, 2),
					"seed": int(p.x * 10.0) * 1000 + int(p.y * 10.0),
				},
			}
			# along the row: the next house about one width on, wall to wall,
			# sometimes after a gap (a yard, a passage)
			var step := w + (rng.randf_range(1.5, 3.5) if rng.randf() < 0.25 else 0.05)
			if _site_ok(hs, out, stair_runs, others):
				out.append(hs)
			else:
				step = 2.0
			carry += step
	return out


## Is (x, z) on a house's footprint (with a margin)?
static func on_house(houses: Array, x: float, z: float, margin: float) -> bool:
	for hs: Dictionary in houses:
		if absf(x - hs.pos.x) > 6.0 + margin or absf(z - hs.pos.y) > 6.0 + margin:
			continue  # far off: no house here is more than 12 m across
		var local := Basis.from_euler(Vector3(0, hs.yaw, 0)).inverse() * Vector3(x - hs.pos.x, 0, z - hs.pos.y)
		if absf(local.x) < hs.w / 2.0 + margin and absf(local.z) < hs.d / 2.0 + margin:
			return true
	return false


static func _lane_ok(houses: Array, m: Vector2) -> bool:
	return not (on_house(houses, m.x, m.y, LANE_HALF) or Topo.is_reserved(m.x, m.y, 1.0) or Topo.in_house(m.x, m.y, 1.0)
			or Topo.on_pier(m.x, m.y, 1.0) or Topo.terrain(m.x, m.y) < 2.4 or absf(m.y) > WALL_Z - 3.0)


## Lane pieces [a, b] along the terrace streets and down the stepped lanes,
## cut wherever a house, the city centre or the shore is in the way.
static func lanes(houses: Array) -> Array:
	var out := []
	for run: PackedVector2Array in streets() + stairs():
		for i in run.size() - 1:
			var a := run[i]
			var b := run[i + 1]
			var n := maxi(1, int(a.distance_to(b) / LANE_SEG))
			for k in n:
				var p0 := a.lerp(b, float(k) / n)
				var p1 := a.lerp(b, float(k + 1) / n)
				if _lane_ok(houses, (p0 + p1) / 2.0):
					out.append([p0, p1])
	return out


func _ready() -> void:
	_atm = get_parent().get_node_or_null("Atmosphere")
	var kit := MeshKit.new()
	var glow := MeshKit.new()
	var houses := plan()
	var cottage := _pick_cottage(houses)
	if cottage:
		cottage["opts"]["cottage"] = true
	for hs: Dictionary in houses:
		_house(kit, glow, hs)
	_walls(kit)
	add_child(kit.build("Backdrop"))
	_glow = glow.build("WindowGlow")
	add_child(_glow)
	_lanes(houses)
	_terraces(houses)
	_hearths(houses)
	if _cottage_lamp != null:
		_cottage_lamp.set_lit(false)


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
	var xf := Transform3D(basis, front)
	if opts.get("cottage", false):
		var info := Arch.cottage(kit, xf, hs.w, hs.d, hs.h, opts)
		_cottage_at = xf
		_cottage_lamp = WallLamp.new()
		_cottage_lamp.name = "DoorLamp"
		_cottage_lamp.position = xf * (info["lamp"] as Vector3)
		_cottage_lamp.rotation.y = hs.yaw
		add_child(_cottage_lamp)
		_place_woman(xf, info, hs.yaw)
		# the room is not a cellar: a small warm light of its own
		var room := OmniLight3D.new()
		room.position = xf * Vector3(0, 1.7, -hs.d * 0.5)
		room.light_color = Color(1.0, 0.66, 0.35)
		room.omni_range = 5.0
		room.light_energy = 0.0
		room.set_script(preload("res://scripts/world/flicker.gd"))
		room.base_energy = 0.85
		room.amount = 0.2
		add_child(room)
	else:
		Arch.house(kit, xf, hs.w, hs.d, hs.h, opts)


## The woman of the house, standing on the new floor between the bench and the
## shelf, spinning wool. Her look (Figure.LOOKS) dresses her as a woman: hair,
## kerchief, long chiton, because an empty room with a bench in it could be anyone's.
func _place_woman(xf: Transform3D, info: Dictionary, yaw: float) -> void:
	var woman := Npc.new()
	woman.name = "CottageWoman"
	woman.npc_id = "cottage_woman"
	woman.talkable = false
	woman.stops_for_player = false
	woman.pose = "spin"
	woman.body_mat = "chiton"  # her own dye from Figure.LOOKS
	woman.position = xf * (info["woman"] as Vector3)
	woman.rotation.y = yaw
	add_child(woman)
	# she spins: distaff in the left hand, the spindle hanging from the right
	Spindle.hold_distaff(woman.joints)
	var spindle := Spindle.new()
	spindle.name = "Spindle"
	spindle.hand = Spindle.right_hand(woman.joints)
	add_child(spindle)
	_woman = woman

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


## Retaining walls along the downhill edge of each terrace street (left open
## where a stepped lane comes through), and stone steps down the steep lanes.
func _terraces(houses: Array) -> void:
	var kit := MeshKit.new()
	var stair_runs := stairs()
	for run: PackedVector2Array in streets():
		for i in run.size() - 1:
			var a := run[i]
			var b := run[i + 1]
			var m := (a + b) / 2.0
			if not _lane_ok(houses, m) or _dist_to(stair_runs, m) < 2.2:
				continue
			var t := (b - a).normalized()
			var down := Vector2(t.y, -t.x)
			if down.x < 0.0:
				down = -down  # east, downhill
			var e := m + down * (LANE_HALF + 0.2)
			var top := Topo.terrain(m.x, m.y) + 0.35
			var foot := Topo.terrain(e.x + down.x * 0.8, e.y + down.y * 0.8)
			if top - foot < 0.5:
				continue  # the ground hardly falls here: no wall needed
			kit.xform = Transform3D(Basis(Vector3.UP, atan2(-t.y, t.x)), Vector3(e.x, (top + foot - 0.4) / 2.0, e.y))
			kit.solid_box("limestone", Vector3.ZERO, Vector3(a.distance_to(b) + 0.08, top - foot + 0.4, 0.45), ["bottom"])
	for run: PackedVector2Array in stair_runs:
		for i in run.size() - 1:
			var a := run[i]
			var b := run[i + 1]
			var t := (b - a).normalized()
			var n := int(a.distance_to(b) / 1.1)
			for k in n:
				var p := a.lerp(b, (k + 0.5) / n)
				var q := p + t * 1.1
				var drop := Topo.terrain(p.x, p.y) - Topo.terrain(q.x, q.y)
				if drop < 0.15 or not _lane_ok(houses, p):
					continue
				kit.xform = Transform3D(Basis(Vector3.UP, atan2(-t.y, t.x)), Vector3(p.x, Topo.terrain(p.x, p.y) + 0.02, p.y))
				kit.box("limestone", Vector3.ZERO, Vector3(0.3, 0.16, LANE_HALF * 2.0), ["bottom"])
	kit.xform = Transform3D.IDENTITY
	add_child(kit.build("Terraces"))


## Smoke from the hearths under some roofs, through the day.
func _hearths(houses: Array) -> void:
	var pots := MeshKit.new()
	for i in houses.size():
		if i % SMOKE_EVERY != 3:
			continue
		var hs: Dictionary = houses[i]
		var basis := Basis.from_euler(Vector3(0, hs.yaw, 0))
		var gable: bool = hs.opts.roof == "gable"
		var ridge := minf(hs.d * 0.22, 1.4) if gable else 0.0
		var base: Vector3 = hs.front + basis * Vector3(hs.w * 0.25, hs.h + ridge, -hs.d / 2.0)
		# no chimneys: a terracotta smoke pot astride the ridge tiles, or on a flat
		# roof a smoke hole with a clay rim; the smoke leaves from its mouth
		var mouth := 0.55 if gable else 0.16
		if gable:
			pots.lathe("clay", PackedVector2Array([Vector2(0.24, -0.15), Vector2(0.2, 0.3), Vector2(0.15, 0.5), Vector2(0.17, mouth)]), 7,
					base, 2.0, false, "dark", true)
		else:
			pots.lathe("clay", PackedVector2Array([Vector2(0.4, -0.05), Vector2(0.36, mouth)]), 8, base, 2.0, false, "dark", true)
		var top := base + Vector3(0, mouth, 0)
		var smoke := Lamp._make_flame(0.4)
		var pm: ParticleProcessMaterial = smoke.process_material
		var g := Gradient.new()
		g.set_color(0, Color(0.36, 0.34, 0.32))
		g.set_color(1, Color(0.27, 0.26, 0.25))
		(pm.color_ramp as GradientTexture1D).gradient = g
		pm.initial_velocity_min = 0.25
		pm.initial_velocity_max = 0.45
		pm.spread = 18.0
		pm.gravity = Vector3(0.2, 0.1, 0)  # the breeze off the strait leans it a little
		pm.scale_min = 0.6
		pm.scale_max = 1.3
		# each puff swells as it rises, then shrinks away: a ragged plume, not a column
		var curve := Curve.new()
		curve.add_point(Vector2(0.0, 0.4))
		curve.add_point(Vector2(0.5, 1.0))
		curve.add_point(Vector2(1.0, 0.2))
		var ct := CurveTexture.new()
		ct.curve = curve
		pm.scale_curve = ct
		(smoke.draw_pass_1.surface_get_material(0) as StandardMaterial3D).blend_mode = BaseMaterial3D.BLEND_MODE_MIX
		smoke.amount = 12
		smoke.lifetime = 4.5
		smoke.position = top
		smoke.visibility_aabb = AABB(Vector3(-3, 0, -3), Vector3(6, 6, 6))
		smoke.emitting = true
		smoke.visible = true
		add_child(smoke)
		_smoke.append(smoke)
	add_child(pots.build("SmokePots"))


## The house nearest the sea on the right hand as you come down: the one you can
## walk into. Chosen as the easternmost house on the +z side, so it is always the
## same house whatever the city grows into.
func _pick_cottage(houses: Array) -> Dictionary:
	var best: Dictionary = {}
	var best_x := -INF
	for hs: Dictionary in houses:
		var z: float = hs.pos.y
		if z < 0.0:
			continue
		if hs.pos.x > best_x:
			best_x = hs.pos.x
			best = hs
	return best


func _process(_delta: float) -> void:
	var hour: float = _atm.t if _atm else 0.0
	_glow.visible = hour >= GLOW_FROM
	if _cottage_lamp != null:
		_cottage_lamp.set_lit(hour >= WallLamp.DUSK)
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
